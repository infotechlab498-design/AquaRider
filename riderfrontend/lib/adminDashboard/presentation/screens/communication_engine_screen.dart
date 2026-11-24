import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:riderfrontend/adminDashboard/data/admin_format.dart';
import 'package:riderfrontend/adminDashboard/presentation/admin_load.dart';
import 'package:riderfrontend/adminDashboard/presentation/admin_nav.dart';
import 'package:riderfrontend/adminDashboard/presentation/widgets/admin_shell.dart';
import 'package:riderfrontend/adminDashboard/theme/admin_tokens.dart';
import 'package:riderfrontend/api/route_api.dart';

class CommunicationEngineScreen extends StatefulWidget {
  const CommunicationEngineScreen({
    required this.onNavigate,
    this.session,
    super.key,
  });

  final AuthSession? session;
  final ValueChanged<String> onNavigate;

  @override
  State<CommunicationEngineScreen> createState() =>
      _CommunicationEngineScreenState();
}

class _CommunicationEngineScreenState extends State<CommunicationEngineScreen> {
  final _search = TextEditingController();
  final _previewVars = <String, TextEditingController>{
    'customer_name': TextEditingController(),
    'order_id': TextEditingController(),
    'receipt_no': TextEditingController(),
    'amount': TextEditingController(),
    'remaining_balance': TextEditingController(),
    'rider_name': TextEditingController(),
    'delivery_status': TextEditingController(),
  };

  var _started = false;
  var _loading = true;
  var _tab = 0;
  var _page = 1;
  var _status = 'All';
  DateTime _date = _today();
  String? _selectedTemplateId;
  String? _selectedMessageId;
  var _gatewayBusy = false;
  var _exportBusy = false;
  var _previewBusy = false;

  AdminLoad<CommunicationDashboardSummary>? _summary;
  AdminLoad<List<CommunicationTemplate>>? _templates;
  AdminLoad<List<CommunicationTrigger>>? _triggers;
  AdminLoad<CommunicationMessagePage>? _messages;
  AdminLoad<CommunicationMessageDetail>? _messageDetail;
  AdminLoad<CommunicationPreview>? _preview;

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  String get _dateIso =>
      '${_date.year.toString().padLeft(4, '0')}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _reload();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    for (final controller in _previewVars.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final api = ApiScope.of(context);
    final summary = await guardAdminLoad(
      () => api.adminCommunicationSummary(date: _dateIso),
    );
    final templates = await guardAdminLoad(api.adminCommunicationTemplates);
    final triggers = await guardAdminLoad(api.adminCommunicationTriggers);
    final messages = await guardAdminLoad(
      () => api.adminCommunicationMessages(
        date: _dateIso,
        status: _status == 'All' ? null : _status,
        search: _search.text.trim().isEmpty ? null : _search.text.trim(),
        page: _page,
      ),
    );
    if (!mounted) return;
    setState(() {
      _summary = summary;
      _templates = templates;
      _triggers = triggers;
      _messages = messages;
      _loading = false;
      _selectedTemplateId ??= templates.value?.isNotEmpty == true
          ? templates.value!.first.id
          : null;
    });
    if (_selectedTemplateId != null) {
      await _refreshPreview();
    }
  }

  Future<void> _refreshPreview() async {
    final templateId = _selectedTemplateId;
    if (templateId == null) return;
    setState(() => _previewBusy = true);
    final vars = <String, String>{
      for (final entry in _previewVars.entries) entry.key: entry.value.text.trim(),
    };
    final preview = await guardAdminLoad(
      () => ApiScope.of(context).adminCommunicationPreview(
        templateId: templateId,
        variables: vars,
      ),
    );
    if (!mounted) return;
    setState(() {
      _preview = preview;
      _previewBusy = false;
    });
  }

  Future<void> _testGateway() async {
    setState(() => _gatewayBusy = true);
    try {
      final status = await ApiScope.of(context).adminCommunicationTestGateway();
      if (!mounted) return;
      showAdminNotice(context, status.message);
      await _reload();
    } on ApiException catch (error) {
      if (mounted) showAdminNotice(context, error.message);
    } catch (_) {
      if (mounted) showAdminNotice(context, adminUnreachableMessage);
    } finally {
      if (mounted) setState(() => _gatewayBusy = false);
    }
  }

  Future<void> _export() async {
    setState(() => _exportBusy = true);
    try {
      final csv = await ApiScope.of(context).adminCommunicationMessagesExportCsv(
        date: _dateIso,
        status: _status == 'All' ? null : _status,
      );
      if (!mounted) return;
      await Clipboard.setData(ClipboardData(text: csv));
      if (!mounted) return;
      showAdminNotice(context, 'Message CSV export copied to clipboard.');
    } on ApiException catch (error) {
      if (mounted) showAdminNotice(context, error.message);
    } catch (_) {
      if (mounted) showAdminNotice(context, adminUnreachableMessage);
    } finally {
      if (mounted) setState(() => _exportBusy = false);
    }
  }

  Future<void> _openTemplateEditor({CommunicationTemplate? existing}) async {
    final name = TextEditingController(text: existing?.name ?? '');
    final content = TextEditingController(text: existing?.content ?? '');
    var language = existing?.language ?? 'en';
    var trigger = existing?.triggerType ?? 'DeliveryCompleted';
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              title: Text(existing == null ? 'Create SMS Template' : 'Edit SMS Template'),
              content: SizedBox(
                width: 480,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: name,
                      decoration: const InputDecoration(labelText: 'Template name'),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      key: ValueKey('lang-$language'),
                      initialValue: language,
                      decoration: const InputDecoration(labelText: 'Language'),
                      items: const [
                        DropdownMenuItem(value: 'en', child: Text('English')),
                        DropdownMenuItem(value: 'ur', child: Text('Urdu')),
                      ],
                      onChanged: (value) => setLocal(() => language = value ?? 'en'),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      key: ValueKey('trigger-$trigger'),
                      initialValue: trigger,
                      decoration: const InputDecoration(labelText: 'Trigger event'),
                      items: const [
                        DropdownMenuItem(value: 'OrderConfirmed', child: Text('Order Confirmed')),
                        DropdownMenuItem(value: 'OrderDispatched', child: Text('Order Dispatched')),
                        DropdownMenuItem(value: 'DeliveryCompleted', child: Text('Delivery Completed')),
                        DropdownMenuItem(value: 'PaymentCollected', child: Text('Payment Collected')),
                        DropdownMenuItem(value: 'BalanceRecoveryReminder', child: Text('Balance Recovery Reminder')),
                      ],
                      onChanged: (value) =>
                          setLocal(() => trigger = value ?? 'DeliveryCompleted'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: content,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Message content',
                        hintText: 'Use {customer_name}, {amount}, …',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  style: adminPrimaryButton(),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
    if (saved != true || !mounted) {
      name.dispose();
      content.dispose();
      return;
    }
    try {
      final api = ApiScope.of(context);
      if (existing == null) {
        await api.adminCreateCommunicationTemplate(
          name: name.text.trim(),
          language: language,
          triggerType: trigger,
          content: content.text.trim(),
        );
      } else {
        await api.adminUpdateCommunicationTemplate(
          existing.id,
          name: name.text.trim(),
          language: language,
          triggerType: trigger,
          content: content.text.trim(),
        );
      }
      if (mounted) {
        showAdminNotice(context, 'Template saved.');
        await _reload();
      }
    } on ApiException catch (error) {
      if (mounted) showAdminNotice(context, error.message);
    } catch (_) {
      if (mounted) showAdminNotice(context, adminUnreachableMessage);
    } finally {
      name.dispose();
      content.dispose();
    }
  }

  Future<void> _toggleTemplate(CommunicationTemplate template) async {
    try {
      await ApiScope.of(context).adminSetCommunicationTemplateActive(
        template.id,
        isActive: !template.isActive,
      );
      if (mounted) await _reload();
    } on ApiException catch (error) {
      if (mounted) showAdminNotice(context, error.message);
    }
  }

  Future<void> _archiveTemplate(CommunicationTemplate template) async {
    try {
      await ApiScope.of(context).adminArchiveCommunicationTemplate(template.id);
      if (mounted) {
        showAdminNotice(context, 'Template archived.');
        await _reload();
      }
    } on ApiException catch (error) {
      if (mounted) showAdminNotice(context, error.message);
    }
  }

  Future<void> _openMessage(String id) async {
    setState(() => _selectedMessageId = id);
    final detail = await guardAdminLoad(
      () => ApiScope.of(context).adminCommunicationMessage(id),
    );
    if (!mounted) return;
    setState(() => _messageDetail = detail);
  }

  Future<void> _retrySelected() async {
    final id = _selectedMessageId;
    if (id == null) return;
    try {
      final detail = await ApiScope.of(context).adminRetryCommunicationMessage(id);
      if (!mounted) return;
      showAdminNotice(context, 'Retry recorded · ${detail.status}');
      await _reload();
      await _openMessage(id);
    } on ApiException catch (error) {
      if (mounted) showAdminNotice(context, error.message);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked == null) return;
    setState(() {
      _date = DateTime(picked.year, picked.month, picked.day);
      _page = 1;
    });
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final loads = <AdminLoad<dynamic>>[
      ?_summary,
      ?_templates,
      ?_triggers,
      ?_messages,
      ?_messageDetail,
      ?_preview,
    ];
    final summary = _summary?.value;
    final wide = MediaQuery.sizeOf(context).width >= 1180;
    return AdminShell(
      screenKey: const Key('communication-engine-screen'),
      session: widget.session,
      activeKey: AdminNav.communication,
      serverReachable: adminServerReachable(loads),
      search: _search,
      onSearch: (_) {},
      searchHint: 'Search message id, phone or transaction…',
      onNavigate: widget.onNavigate,
      trailing: IconButton(
        tooltip: 'Refresh',
        onPressed: _loading ? null : _reload,
        icon: const Icon(Icons.refresh, color: AdminTokens.secondary),
      ),
      body: _loading && summary == null
          ? const AdminLoadingPane(label: 'Loading transactional SMS engine…')
          : ListView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              children: [
                _header(),
                const SizedBox(height: 16),
                if (_summary?.error != null && summary == null)
                  _error(_summary!.error!)
                else if (summary != null) ...[
                  _gatewayCard(summary.gateway),
                  const SizedBox(height: 16),
                  _kpiRow(summary),
                  const SizedBox(height: 16),
                  _tabs(),
                  const SizedBox(height: 16),
                  if (_tab == 0) _templatesPane(wide),
                  if (_tab == 1) _historyPane(wide),
                  if (_tab == 2) _triggersPane(),
                  if (_tab == 3) _gatewaySettings(summary.gateway),
                ],
              ],
            ),
    );
  }

  Widget _header() {
    final note = _summary?.value?.scopeNote ?? '';
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Communication  ›  Notifications & Templates',
          style: adminType(12, FontWeight.w600, AdminTokens.textSecondary),
        ),
        const SizedBox(height: 6),
        Text(
          'Transactional Communication Engine',
          style: adminType(26, FontWeight.w700, AdminTokens.text, height: 1.2),
        ),
        const SizedBox(height: 6),
        Text(
          'Send a recorded template to a rider inbox, and review the SMS messages stored for this day.',
          style: adminType(13.5, FontWeight.w500, AdminTokens.textSecondary),
        ),
        if (note.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(note, style: adminType(12, FontWeight.w600, AdminTokens.textSecondary)),
        ],
      ],
    );
    final send = FilledButton.icon(
      key: const Key('communication-send-rider'),
      style: FilledButton.styleFrom(
        backgroundColor: AdminTokens.button,
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: _selectedTemplateId == null ? null : _sendToRider,
      icon: const Icon(Icons.send_outlined, size: 16),
      label: const Text('Send to rider'),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 860) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [title, const SizedBox(height: 12), send],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [Expanded(child: title), send],
        );
      },
    );
  }

  Future<void> _sendToRider() async {
    final templateId = _selectedTemplateId;
    if (templateId == null) {
      showAdminNotice(context, 'Choose a template first.');
      return;
    }
    final api = ApiScope.of(context);
    List<StaffUser> riders = const [];
    try {
      final page = await api.staffUsers(role: 'Rider', isActive: true, pageSize: 100);
      riders = page.rows;
    } on ApiException catch (error) {
      if (mounted) showAdminNotice(context, error.message);
      return;
    } catch (_) {
      if (mounted) showAdminNotice(context, adminUnreachableMessage);
      return;
    }
    if (!mounted) return;
    if (riders.isEmpty) {
      showAdminNotice(context, 'No active riders were returned.');
      return;
    }
    var riderId = riders.first.id;
    final sent = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          key: const Key('communication-send-dialog'),
          title: const Text('Send to rider inbox'),
          content: SizedBox(
            width: 420,
            child: DropdownButtonFormField<String>(
              key: ValueKey('communication-rider-$riderId'),
              initialValue: riderId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Rider'),
              items: [
                for (final rider in riders)
                  DropdownMenuItem(
                    value: rider.id,
                    child: Text(
                      rider.riderCode == null || rider.riderCode!.isEmpty
                          ? rider.fullName
                          : '${rider.fullName} · ${rider.riderCode}',
                    ),
                  ),
              ],
              onChanged: (value) {
                if (value == null) return;
                setLocal(() => riderId = value);
              },
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(
              key: const Key('communication-send-confirm'),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Send'),
            ),
          ],
        ),
      ),
    );
    if (sent != true || !mounted) return;
    final chosen = riders.firstWhere((rider) => rider.id == riderId);
    final vars = <String, String>{
      for (final entry in _previewVars.entries)
        if (entry.value.text.trim().isNotEmpty) entry.key: entry.value.text.trim(),
    };
    try {
      final detail = await api.adminEnqueueCommunicationMessage(
        templateId: templateId,
        destinationNumber: (chosen.phone ?? '').trim(),
        riderUserId: chosen.id,
        variables: vars,
        idempotencyKey: 'rider-${chosen.id}-${DateTime.now().microsecondsSinceEpoch}',
      );
      if (!mounted) return;
      showAdminNotice(
        context,
        'Recorded ${detail.messageReference} for ${chosen.fullName}. The rider inbox will show it.',
      );
      await _reload();
    } on ApiException catch (error) {
      if (mounted) showAdminNotice(context, error.message);
    } catch (_) {
      if (mounted) showAdminNotice(context, adminUnreachableMessage);
    }
  }

  Widget _gatewayCard(CommunicationGatewayStatus gateway) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminTokens.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final copy = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SMS Gateway · ${gateway.providerName}',
                style: adminType(15, FontWeight.w700, AdminTokens.text),
              ),
              const SizedBox(height: 4),
              Text(
                gateway.message,
                style: adminType(12.5, FontWeight.w500, AdminTokens.textSecondary),
              ),
              const SizedBox(height: 4),
              Text(
                'Status: ${gateway.status} · Messages today: ${gateway.messagesToday}',
                style: adminType(12, FontWeight.w600, AdminTokens.primary),
              ),
            ],
          );
          final actions = Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: () => showAdminNotice(
                  context,
                  'Gateway credentials are configured server-side only. Secrets are never returned to Flutter.',
                ),
                child: const Text('Configure Gateway'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AdminTokens.button,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _gatewayBusy ? null : _testGateway,
                child: Text(_gatewayBusy ? 'Testing…' : 'Test Connection'),
              ),
            ],
          );
          if (constraints.maxWidth < 760) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [copy, const SizedBox(height: 12), actions],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [Expanded(child: copy), actions],
          );
        },
      ),
    );
  }

  Widget _kpiRow(CommunicationDashboardSummary summary) {
    final cards = [
      _kpi('Messages Dispatched Today', '${summary.messagesDispatchedToday}', AdminTokens.primary),
      _kpi('Delivered Successfully', '${summary.deliveredSuccessfully}', const Color(0xFF2E7D32)),
      _kpi('Pending / Queue', '${summary.pendingOrQueued}', const Color(0xFFF9A825)),
      _kpi('Delivery Exceptions', '${summary.failedOrExceptions}', const Color(0xFFC62828)),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 1100) {
          return Row(
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                Expanded(child: cards[i]),
              ],
            ],
          );
        }
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [for (final card in cards) SizedBox(width: 240, child: card)],
        );
      },
    );
  }

  Widget _kpi(String title, String value, Color accent) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminTokens.line),
        boxShadow: AdminTokens.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: adminType(11, FontWeight.w700, AdminTokens.textSecondary, letterSpacing: 0.3),
          ),
          const SizedBox(height: 8),
          Text(value, style: adminType(28, FontWeight.w700, accent, height: 1.1)),
        ],
      ),
    );
  }

  Widget _tabs() {
    const labels = [
      'Message Templates',
      'Live Communication History',
      'Dispatch Rules & Triggers',
      'Gateway Settings',
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(labels[i]),
                selected: _tab == i,
                onSelected: (_) => setState(() => _tab = i),
              ),
            ),
        ],
      ),
    );
  }

  Widget _templatesPane(bool wide) {
    final templates = _templates?.value ?? const <CommunicationTemplate>[];
    final list = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Transactional templates',
                style: adminType(16, FontWeight.w700, AdminTokens.text),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AdminTokens.button,
                foregroundColor: Colors.white,
                elevation: 0,
                minimumSize: const Size(0, 40),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => _openTemplateEditor(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Create New Template'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_templates?.error != null)
          _error(_templates!.error!)
        else if (templates.isEmpty)
          Text(
            'No templates yet.',
            style: adminType(13, FontWeight.w500, AdminTokens.textSecondary),
          )
        else
          for (final template in templates)
            _templateCard(template),
      ],
    );
    final preview = _smsPreviewPanel();
    if (!wide) {
      return Column(children: [list, const SizedBox(height: 16), preview]);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 3, child: list),
        const SizedBox(width: 16),
        Expanded(flex: 2, child: preview),
      ],
    );
  }

  Widget _templateCard(CommunicationTemplate template) {
    final selected = template.id == _selectedTemplateId;
    return InkWell(
      onTap: () {
        setState(() => _selectedTemplateId = template.id);
        _refreshPreview();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? AdminTokens.primary.withValues(alpha: 0.06) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AdminTokens.primary : AdminTokens.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${template.templateCode} · ${template.name}',
                    style: adminType(14, FontWeight.w700, AdminTokens.text),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Switch(
                  value: template.isActive,
                  onChanged: (_) => _toggleTemplate(template),
                ),
              ],
            ),
            Text(
              '${template.language.toUpperCase()} · ${template.triggerType}',
              style: adminType(12, FontWeight.w600, AdminTokens.textSecondary),
            ),
            const SizedBox(height: 8),
            Directionality(
              textDirection: template.language == 'ur' ? TextDirection.rtl : TextDirection.ltr,
              child: Text(
                template.content,
                style: adminType(13, FontWeight.w500, AdminTokens.text),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton(
                  onPressed: () => _openTemplateEditor(existing: template),
                  child: const Text('Edit Template'),
                ),
                TextButton(
                  onPressed: () => _archiveTemplate(template),
                  child: const Text('Archive'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _smsPreviewPanel() {
    final preview = _preview?.value;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminTokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('SMS preview', style: adminType(16, FontWeight.w700, AdminTokens.text)),
          const SizedBox(height: 4),
          Text(
            'Preview only — does not send a message.',
            style: adminType(12, FontWeight.w600, AdminTokens.textSecondary),
          ),
          const SizedBox(height: 12),
          for (final entry in _previewVars.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TextField(
                controller: entry.value,
                decoration: InputDecoration(
                  labelText: '{${entry.key}}',
                  isDense: true,
                ),
                onChanged: (_) => _refreshPreview(),
              ),
            ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F7FA),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AdminTokens.border),
            ),
            child: _previewBusy
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : Directionality(
                    textDirection: preview?.language == 'ur'
                        ? TextDirection.rtl
                        : TextDirection.ltr,
                    child: Text(
                      preview?.renderedContent ?? 'Select a template to preview.',
                      style: adminType(14, FontWeight.w500, AdminTokens.text),
                    ),
                  ),
          ),
          if (preview?.destinationHint != null) ...[
            const SizedBox(height: 8),
            Text(
              preview!.destinationHint,
              style: adminType(11.5, FontWeight.w600, AdminTokens.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _historyPane(bool wide) {
    final page = _messages?.value;
    final items = page?.items ?? const <CommunicationMessageRow>[];
    final table = Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminTokens.border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                DropdownButton<String>(
                  value: _status,
                  items: const [
                    DropdownMenuItem(value: 'All', child: Text('All Statuses')),
                    DropdownMenuItem(value: 'Queued', child: Text('Queued')),
                    DropdownMenuItem(value: 'NotConfigured', child: Text('NotConfigured')),
                    DropdownMenuItem(value: 'Submitted', child: Text('Submitted')),
                    DropdownMenuItem(value: 'Delivered', child: Text('Delivered')),
                    DropdownMenuItem(value: 'Failed', child: Text('Failed')),
                    DropdownMenuItem(value: 'Suppressed', child: Text('Suppressed')),
                    DropdownMenuItem(value: 'InApp', child: Text('In-app')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _status = value;
                      _page = 1;
                    });
                    _reload();
                  },
                ),
                OutlinedButton(
                  onPressed: _pickDate,
                  child: Text(formatAdminDay(_date)),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AdminTokens.button,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    setState(() => _page = 1);
                    _reload();
                  },
                  child: const Text('Apply'),
                ),
                OutlinedButton(
                  onPressed: _exportBusy ? null : _export,
                  child: Text(_exportBusy ? 'Exporting…' : 'Export CSV'),
                ),
              ],
            ),
          ),
          if (_messages?.error != null)
            Padding(padding: const EdgeInsets.all(16), child: _error(_messages!.error!))
          else if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No messages matched the filters.',
                style: adminType(13, FontWeight.w500, AdminTokens.textSecondary),
              ),
            )
          else
            for (final row in items)
              InkWell(
                onTap: () => _openMessage(row.id),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: row.id == _selectedMessageId
                        ? AdminTokens.primary.withValues(alpha: 0.08)
                        : null,
                    border: Border(bottom: BorderSide(color: AdminTokens.border.withValues(alpha: 0.7))),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          row.messageReference,
                          style: adminType(12.5, FontWeight.w700, AdminTokens.text),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          row.customerName ?? row.destinationNumber,
                          style: adminType(12.5, FontWeight.w500, AdminTokens.text),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          '${row.channel} · ${row.triggerType}',
                          style: adminType(12, FontWeight.w600, AdminTokens.primary),
                        ),
                      ),
                      Text(
                        row.status,
                        style: adminType(12, FontWeight.w700, AdminTokens.secondary),
                      ),
                    ],
                  ),
                ),
              ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Text(
                  page == null
                      ? ''
                      : 'Page ${page.page} of ${page.totalPages} · ${page.totalRecords} items',
                  style: adminType(12, FontWeight.w500, AdminTokens.textSecondary),
                ),
                const Spacer(),
                TextButton(
                  onPressed: page != null && page.page > 1
                      ? () {
                          setState(() => _page = page.page - 1);
                          _reload();
                        }
                      : null,
                  child: const Text('Previous'),
                ),
                TextButton(
                  onPressed: page != null && page.page < page.totalPages
                      ? () {
                          setState(() => _page = page.page + 1);
                          _reload();
                        }
                      : null,
                  child: const Text('Next'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    final detail = _messageDetailPanel();
    if (!wide) return Column(children: [table, const SizedBox(height: 16), detail]);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 3, child: table),
        const SizedBox(width: 16),
        Expanded(flex: 2, child: detail),
      ],
    );
  }

  Widget _messageDetailPanel() {
    final detail = _messageDetail?.value;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminTokens.border),
      ),
      child: detail == null
          ? Text(
              'Select a message to inspect delivery state.',
              style: adminType(13, FontWeight.w500, AdminTokens.textSecondary),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Message detail', style: adminType(16, FontWeight.w700, AdminTokens.text)),
                const SizedBox(height: 8),
                Text(detail.messageReference, style: adminType(12, FontWeight.w600, AdminTokens.textSecondary)),
                const SizedBox(height: 8),
                Text(detail.renderedContent, style: adminType(14, FontWeight.w500, AdminTokens.text)),
                const SizedBox(height: 8),
                Text('Status: ${detail.status}', style: adminType(13, FontWeight.w700, AdminTokens.primary)),
                if (detail.failureReason != null) ...[
                  const SizedBox(height: 4),
                  Text(detail.failureReason!, style: adminType(12.5, FontWeight.w500, const Color(0xFFC62828))),
                ],
                const SizedBox(height: 8),
                Text(detail.scopeNote, style: adminType(11.5, FontWeight.w500, AdminTokens.textSecondary)),
                const SizedBox(height: 12),
                if (detail.status != 'Delivered')
                  FilledButton(
                    style: adminPrimaryButton(),
                    onPressed: _retrySelected,
                    child: const Text('Retry SMS'),
                  ),
              ],
            ),
    );
  }

  Widget _triggersPane() {
    final triggers = _triggers?.value ?? const <CommunicationTrigger>[];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminTokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Dispatch rules & triggers', style: adminType(16, FontWeight.w700, AdminTokens.text)),
          const SizedBox(height: 8),
          Text(
            'Triggers enqueue SMS only when consent, suppression and template checks pass on the server.',
            style: adminType(12.5, FontWeight.w500, AdminTokens.textSecondary),
          ),
          const SizedBox(height: 12),
          if (_triggers?.error != null)
            _error(_triggers!.error!)
          else
            for (final trigger in triggers)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(trigger.triggerType, style: adminType(14, FontWeight.w700, AdminTokens.text)),
                subtitle: Text(
                  '${trigger.description}\nTemplate: ${trigger.templateName ?? 'None'}',
                  style: adminType(12.5, FontWeight.w500, AdminTokens.textSecondary),
                ),
                trailing: Text(
                  trigger.enabled ? 'Enabled' : 'Disabled',
                  style: adminType(
                    12,
                    FontWeight.w700,
                    trigger.enabled ? const Color(0xFF2E7D32) : AdminTokens.textSecondary,
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Widget _gatewaySettings(CommunicationGatewayStatus gateway) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminTokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Gateway settings', style: adminType(16, FontWeight.w700, AdminTokens.text)),
          const SizedBox(height: 8),
          Text('Provider: ${gateway.providerName}'),
          Text('Status: ${gateway.status}'),
          Text('Configured: ${gateway.isConfigured ? 'Yes' : 'No'}'),
          Text('Sender ID: ${gateway.senderId ?? 'Not set'}'),
          const SizedBox(height: 8),
          Text(gateway.scopeNote, style: adminType(12, FontWeight.w500, AdminTokens.textSecondary)),
          const SizedBox(height: 12),
          FilledButton(
            style: adminPrimaryButton(),
            onPressed: _gatewayBusy ? null : _testGateway,
            child: const Text('Test Connection'),
          ),
        ],
      ),
    );
  }

  Widget _error(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(message, style: adminType(13, FontWeight.w600, const Color(0xFFC62828))),
    );
  }
}
