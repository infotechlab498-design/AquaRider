import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:riderfrontend/adminDashboard/data/admin_format.dart';
import 'package:riderfrontend/adminDashboard/presentation/admin_load.dart';
import 'package:riderfrontend/adminDashboard/presentation/admin_nav.dart';
import 'package:riderfrontend/adminDashboard/presentation/widgets/admin_shell.dart';
import 'package:riderfrontend/adminDashboard/theme/admin_tokens.dart';
import 'package:riderfrontend/api/route_api.dart';

class CollectionsManagementScreen extends StatefulWidget {
  const CollectionsManagementScreen({
    required this.onNavigate,
    this.session,
    this.refreshEvery = const Duration(seconds: 30),
    super.key,
  });

  final AuthSession? session;
  final ValueChanged<String> onNavigate;
  final Duration? refreshEvery;

  @override
  State<CollectionsManagementScreen> createState() =>
      _CollectionsManagementScreenState();
}

class _CollectionsManagementScreenState
    extends State<CollectionsManagementScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  Timer? _refresh;
  var _started = false;
  var _loading = true;
  var _page = 1;
  var _pageSize = 5;
  var _tab = 'All';
  var _listGeneration = 0;
  var _detailBusy = false;
  String? _selectedId;
  String? _riderId;
  DateTime _date = _today();
  List<RiderRecord> _riders = const [];

  AdminLoad<AdminCollectionsSummary>? _summary;
  AdminLoad<AdminCollectionPage>? _pageData;
  AdminLoad<AdminCollectionDetail>? _detail;
  AdminLoad<List<AdminReceivableExposure>>? _exposure;

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  String get _dateIso =>
      '${_date.year.toString().padLeft(4, '0')}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    _search.addListener(_scheduleSearch);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final every = widget.refreshEvery;
    if (every != null) {
      _refresh = Timer.periodic(every, (_) {
        if (!mounted || _loading) return;
        _reload();
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _reload();
    });
  }

  @override
  void dispose() {
    _listGeneration++;
    _debounce?.cancel();
    _refresh?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _scheduleSearch() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() => _page = 1);
      _reload();
    });
  }

  Future<void> _reload() async {
    final generation = ++_listGeneration;
    setState(() => _loading = true);
    final api = ApiScope.of(context);
    final summary = await guardAdminLoad(
      () => api.adminCollectionsSummary(date: _dateIso),
    );
    final page = await guardAdminLoad(
      () => api.adminCollections(
        date: _dateIso,
        type: _tab,
        riderId: _riderId,
        search: _search.text.trim().isEmpty ? null : _search.text.trim(),
        page: _page,
        pageSize: _pageSize,
      ),
    );
    final exposure = await guardAdminLoad(() => api.adminReceivablesExposure());
    var riders = _riders;
    try {
      riders = await api.riderOperationsRiders(date: _dateIso);
    } catch (_) {
      riders = _riders;
    }
    if (!mounted || generation != _listGeneration) return;
    setState(() {
      _summary = summary;
      _pageData = page;
      _exposure = exposure;
      _riders = riders;
      _loading = false;
    });
    final selected = _selectedId;
    final rows = page.value?.rows ?? const <AdminCollectionRow>[];
    if (selected != null && rows.any((row) => row.id == selected)) {
      await _loadDetail(selected);
    } else if (rows.isNotEmpty) {
      await _loadDetail(rows.first.id);
    } else {
      setState(() {
        _selectedId = null;
        _detail = null;
      });
    }
  }

  Future<void> _loadDetail(String id) async {
    setState(() {
      _selectedId = id;
      _detailBusy = true;
    });
    final detail = await guardAdminLoad(
      () => ApiScope.of(context).adminCollectionDetail(id),
    );
    if (!mounted || _selectedId != id) return;
    setState(() {
      _detail = detail;
      _detailBusy = false;
    });
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

  void _resetFilters() {
    setState(() {
      _search.clear();
      _tab = 'All';
      _riderId = null;
      _page = 1;
      _pageSize = 5;
      _date = _today();
    });
    _reload();
  }

  void _setTab(String tab) {
    if (_tab == tab) return;
    setState(() {
      _tab = tab;
      _page = 1;
    });
    _reload();
  }

  String? get _searchTerm {
    final text = _search.text.trim();
    return text.isEmpty ? null : text;
  }

  String get _dateLabel {
    final today = _today();
    final sameDay =
        _date.year == today.year && _date.month == today.month && _date.day == today.day;
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final label = '${_date.day} ${months[_date.month - 1]} ${_date.year}';
    return sameDay ? 'Today · $label' : label;
  }

  Future<void> _exportCsv() async {
    final api = ApiScope.of(context);
    final rows = <AdminCollectionRow>[];
    try {
      var page = 1;
      var totalPages = 1;
      while (page <= totalPages && page <= 20) {
        final result = await api.adminCollections(
          date: _dateIso,
          type: _tab,
          riderId: _riderId,
          search: _searchTerm,
          page: page,
          pageSize: 100,
        );
        rows.addAll(result.rows);
        totalPages = result.totalPages;
        if (result.rows.isEmpty) break;
        page++;
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      showAdminNotice(context, error.message);
      return;
    } catch (_) {
      if (!mounted) return;
      showAdminNotice(context, adminUnreachableMessage);
      return;
    }
    if (!mounted) return;
    if (rows.isEmpty) {
      showAdminNotice(context, 'No collections matched the filters to export.');
      return;
    }
    final csv = StringBuffer(
      'Reference,Time,Customer,Code,Area,Rider,Channel,Amount,Withholding,Before,After,Sync\n',
    );
    for (final row in rows) {
      csv.writeln([
        row.referenceNumber,
        formatAdminStamp(row.createdAtUtc),
        row.customerName,
        row.customerCode,
        row.customerArea,
        row.riderName,
        row.channelLabel,
        row.amount.toString(),
        row.withholdingTax.toString(),
        row.outstandingBefore.toString(),
        row.outstandingAfter.toString(),
        row.syncStatus,
      ].map((value) => '"${value.replaceAll('"', '""')}"').join(','));
    }
    await Clipboard.setData(ClipboardData(text: csv.toString()));
    if (!mounted) return;
    final noun = rows.length == 1 ? 'collection' : 'collections';
    showAdminNotice(context, 'Copied ${rows.length} $noun as CSV.');
  }

  String _slip(AdminCollectionDetail detail) {
    final buffer = StringBuffer()
      ..writeln(detail.referenceNumber)
      ..writeln(formatAdminStamp(detail.createdAtUtc))
      ..writeln(detail.syncStatus)
      ..writeln(detail.customerName)
      ..writeln(detail.customerCode);
    if (detail.customerAddress.trim().isNotEmpty) buffer.writeln(detail.customerAddress);
    if (detail.customerPhone.trim().isNotEmpty) buffer.writeln(detail.customerPhone);
    buffer
      ..writeln('${detail.riderName} ${detail.riderCode ?? ''}'.trim())
      ..writeln(detail.channelLabel)
      ..writeln('Collected ${formatPkr(detail.amount)}')
      ..writeln('Withholding ${formatPkr(detail.withholdingTax)}')
      ..writeln('Balance ${formatPkr(detail.outstandingBefore)} to ${formatPkr(detail.outstandingAfter)}');
    if (detail.signerName != null) {
      buffer.writeln('Signed by ${detail.signerName} ${detail.signerRole ?? ''}'.trim());
    }
    if (detail.notes != null) buffer.writeln(detail.notes);
    return buffer.toString().trim();
  }

  Future<void> _printSlip(AdminCollectionDetail detail) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('collections-slip-dialog'),
        title: Text(detail.referenceNumber),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No thermal printer is paired. Copy this slip to print it.',
                  style: adminType(12.5, FontWeight.w600, AdminTokens.textSecondary),
                ),
                const SizedBox(height: 12),
                SelectableText(_slip(detail)),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: _slip(detail)));
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('Copy slip'),
          ),
        ],
      ),
    );
  }

  Future<void> _copySlip(AdminCollectionDetail detail) async {
    await Clipboard.setData(ClipboardData(text: _slip(detail)));
    if (!mounted) return;
    showAdminNotice(context, 'Receipt text copied. This collection does not have a PDF file.');
  }

  Future<void> _whatsapp(String phone, String message) async {
    final digits = _whatsappDigits(phone);
    if (digits == null) {
      showAdminNotice(context, 'This account has no phone number.');
      return;
    }
    final uri = Uri.parse('https://wa.me/$digits?text=${Uri.encodeComponent(message)}');
    var opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }
    if (!mounted || opened) return;
    await Clipboard.setData(ClipboardData(text: message));
    if (!mounted) return;
    showAdminNotice(context, 'WhatsApp did not open. The message was copied instead.');
  }

  Future<void> _remind(AdminReceivableExposure row) async {
    try {
      final detail = await ApiScope.of(context).adminCustomerDetail(row.customerId);
      if (!mounted) return;
      await _whatsapp(
        detail.customer.phone,
        'Balance reminder for ${row.customerName} (${row.customerCode}): ${formatPkr(row.outstanding)} outstanding.',
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      showAdminNotice(context, error.message);
    } catch (_) {
      if (!mounted) return;
      showAdminNotice(context, adminUnreachableMessage);
    }
  }

  String? _whatsappDigits(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 8) return null;
    if (digits.startsWith('0')) return '92${digits.substring(1)}';
    return digits;
  }

  Future<void> _openManualSettlement() async {
    final created = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ManualSettlementDialog(api: ApiScope.of(context)),
    );
    if (created == true && mounted) await _reload();
  }

  Future<void> _handovers() async {
    List<CashHandover> rows = const [];
    try {
      rows = await ApiScope.of(context).cashHandovers(status: 'Submitted');
    } on ApiException catch (error) {
      if (!mounted) return;
      showAdminNotice(context, error.message);
      return;
    }
    if (!mounted) return;
    if (rows.isEmpty) {
      showAdminNotice(context, 'No rider cash handovers are waiting for warehouse confirmation.');
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cash handovers'),
        content: SizedBox(
          width: 460,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final row in rows)
                ListTile(
                  title: Text('${row.referenceNumber} · expected ${row.expectedAmount}'),
                  subtitle: Text('${row.businessDate} · ${row.collectionCount} collections'),
                  trailing: TextButton(
                    onPressed: () async {
                      final amount = TextEditingController(text: '${row.expectedAmount}');
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Confirm cash received'),
                          content: TextField(controller: amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Actual amount')),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm')),
                          ],
                        ),
                      );
                      final actual = num.tryParse(amount.text.trim());
                      amount.dispose();
                      if (confirmed != true || actual == null || !context.mounted) return;
                      try {
                        await ApiScope.of(context).confirmCashHandover(row.id, actualAmount: actual);
                        if (context.mounted) Navigator.pop(context);
                      } on ApiException catch (error) {
                        if (context.mounted) showAdminNotice(context, error.message);
                      }
                    },
                    child: const Text('Receive'),
                  ),
                ),
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loads = <AdminLoad<dynamic>>[
      ?_summary,
      ?_pageData,
      ?_detail,
      ?_exposure,
    ];
    final summary = _summary?.value;
    final page = _pageData?.value;
    final wide = MediaQuery.sizeOf(context).width >= 1180;
    return AdminShell(
      screenKey: const Key('collections-management-screen'),
      session: widget.session,
      activeKey: AdminNav.collectionsManagement,
      serverReachable: adminServerReachable(loads),
      search: _search,
      onSearch: (_) {},
      searchHint: 'Search reference #, store, customer code or rider…',
      onNavigate: widget.onNavigate,
      trailing: IconButton(
        tooltip: 'Refresh',
        onPressed: _loading ? null : _reload,
        icon: const Icon(Icons.refresh, color: AdminTokens.secondary),
      ),
      body: _loading && summary == null
          ? const AdminLoadingPane(label: 'Loading collections ledger…')
          : ListView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              children: [
                _header(),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton(onPressed: _handovers, child: const Text('Confirm cash handovers')),
                ),
                const SizedBox(height: 16),
                if (_summary?.error != null && summary == null)
                  _error(_summary!.error!)
                else if (summary != null) ...[
                  _kpiRow(summary),
                  const SizedBox(height: 16),
                  _tabs(summary),
                  const SizedBox(height: 12),
                  _filters(),
                  const SizedBox(height: 16),
                  if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: _ledger(page)),
                        const SizedBox(width: 16),
                        SizedBox(
                          width: 360,
                          child: Column(
                            children: [
                              _detailPanel(),
                              const SizedBox(height: 16),
                              _channelSplit(summary),
                            ],
                          ),
                        ),
                      ],
                    )
                  else ...[
                    _ledger(page),
                    const SizedBox(height: 16),
                    _detailPanel(),
                    const SizedBox(height: 16),
                    _channelSplit(summary),
                  ],
                  const SizedBox(height: 16),
                  _exposureSection(),
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
          'Financial Operations  ›  Collections & Recovery',
          style: adminType(12, FontWeight.w600, AdminTokens.textSecondary),
        ),
        const SizedBox(height: 6),
        Text(
          'Collections & Recovery Management',
          style: adminType(26, FontWeight.w700, AdminTokens.text, height: 1.2),
        ),
        const SizedBox(height: 6),
        Text(
          'Review doorstep collections, withholding, outstanding balances, and recorded settlement receipts.',
          style: adminType(13.5, FontWeight.w500, AdminTokens.textSecondary),
        ),
        if (note.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(note, style: adminType(11.5, FontWeight.w600, AdminTokens.textSecondary)),
        ],
      ],
    );
    final actions = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          key: const Key('collections-export'),
          style: adminOutlineButton(),
          onPressed: _exportCsv,
          icon: const Icon(Icons.download_outlined, size: 16),
          label: const Text('Export CSV'),
        ),
        FilledButton.icon(
          key: const Key('collections-manual'),
          style: FilledButton.styleFrom(
            backgroundColor: AdminTokens.button,
            foregroundColor: Colors.white,
            elevation: 0,
            minimumSize: const Size(0, 40),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: _openManualSettlement,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Record Manual Settlement'),
        ),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 860) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [title, const SizedBox(height: 12), actions],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [Expanded(child: title), actions],
        );
      },
    );
  }

  Widget _kpiRow(AdminCollectionsSummary summary) {
    final average = summary.fieldCollectionCount == 0
        ? 'No field collections this day'
        : 'Average ${formatPkr(summary.todaysCollections / summary.fieldCollectionCount)}';
    final cards = [
      _CollKpi(
        "Today's Collections",
        formatPkr(summary.todaysCollections),
        '${summary.todaysCollectionCount} settlements · ${summary.cashSharePercent.toStringAsFixed(0)}% cash',
        Icons.payments_outlined,
        hintColor: AdminTokens.success,
      ),
      _CollKpi(
        'Monthly Total',
        formatPkr(summary.monthlyCollections),
        'Calendar month through this day',
        Icons.calendar_month_outlined,
      ),
      _CollKpi(
        'Receivables Ledger',
        formatPkr(summary.receivablesLedger),
        '${summary.accountsOnCredit} accounts on credit',
        Icons.account_balance_outlined,
      ),
      _CollKpi(
        'High-Risk Aging',
        '${summary.highRiskAgingAccounts}',
        'Accounts 7 or more days past terms',
        Icons.warning_amber_outlined,
        emphasize: summary.highRiskAgingAccounts > 0,
      ),
      _CollKpi(
        'Field Collections',
        '${summary.fieldCollectionCount}',
        average,
        Icons.local_shipping_outlined,
      ),
      _CollKpi(
        'Pending Sync',
        '${summary.syncAttentionCount}',
        '${summary.pendingSyncCount} pending · ${summary.failedSyncCount} failed',
        Icons.sync_problem_outlined,
        emphasize: summary.syncAttentionCount > 0,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth >= 980
            ? 6
            : constraints.maxWidth >= 640
                ? 3
                : 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final card in cards)
              SizedBox(
                width: (constraints.maxWidth - (cols - 1) * 12) / cols,
                child: _kpiCard(card),
              ),
          ],
        );
      },
    );
  }

  Widget _kpiCard(_CollKpi card) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AdminTokens.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: card.emphasize ? AdminTokens.error : AdminTokens.line,
        ),
        boxShadow: AdminTokens.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  card.label.toUpperCase(),
                  style: adminType(11, FontWeight.w700, AdminTokens.textSecondary, letterSpacing: 0.3),
                ),
              ),
              Icon(
                card.icon,
                size: 18,
                color: card.emphasize ? AdminTokens.error : AdminTokens.secondary,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            card.value,
            style: adminType(
              22,
              FontWeight.w700,
              card.emphasize ? AdminTokens.error : AdminTokens.text,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            card.hint,
            style: adminType(
              11.5,
              FontWeight.w600,
              card.emphasize ? AdminTokens.error : (card.hintColor ?? AdminTokens.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _exposureSection() {
    if (_exposure?.error != null && _exposure?.value == null) {
      return _error(_exposure!.error!);
    }
    final rows = _exposure?.value ?? const <AdminReceivableExposure>[];
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: AdminTokens.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminTokens.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'High Exposure Outstanding Accounts',
            style: adminType(15, FontWeight.w700, AdminTokens.text),
          ),
          const SizedBox(height: 4),
          Text(
            rows.isEmpty
                ? 'No outstanding receivables were flagged.'
                : '${rows.length} accounts currently hold a balance.',
            style: adminType(12.5, FontWeight.w500, AdminTokens.textSecondary),
          ),
          const SizedBox(height: 12),
          if (rows.isEmpty)
            Text(
              'No outstanding receivables flagged.',
              style: adminType(13, FontWeight.w500, AdminTokens.textSecondary),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth >= 900 ? 280.0 : constraints.maxWidth;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final row in rows.take(12))
                      SizedBox(width: width, child: _exposureCard(row)),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _exposureCard(AdminReceivableExposure row) {
    final overdue = row.daysOverdue;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AdminTokens.field,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  row.customerCode,
                  style: adminType(11.5, FontWeight.w700, AdminTokens.textSecondary),
                ),
              ),
              if (overdue != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AdminTokens.errorBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$overdue days overdue',
                    style: adminType(11, FontWeight.w700, AdminTokens.error),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            row.customerName,
            style: adminType(14, FontWeight.w700, AdminTokens.text),
          ),
          if (row.area.isNotEmpty)
            Text(row.area, style: adminType(12, FontWeight.w500, AdminTokens.textSecondary)),
          if (row.riskLabel.isNotEmpty)
            Text(row.riskLabel, style: adminType(12, FontWeight.w600, AdminTokens.warning)),
          const SizedBox(height: 8),
          Text(
            formatPkr(row.outstanding),
            style: adminType(20, FontWeight.w700, AdminTokens.error, height: 1.1),
          ),
          Text('balance', style: adminType(11.5, FontWeight.w500, AdminTokens.textSecondary)),
          const SizedBox(height: 8),
          TextButton.icon(
            key: Key('collections-remind-${row.customerId}'),
            onPressed: () => _remind(row),
            icon: const Icon(Icons.chat_outlined, size: 16),
            label: const Text('WhatsApp reminder'),
          ),
        ],
      ),
    );
  }

  Widget _tabs(AdminCollectionsSummary summary) {
    final items = [
      ('All', 'All Collections', summary.todaysCollectionCount),
      ('Cash', 'Cash Spot', summary.fieldCollectionCount),
      ('PendingSync', 'Pending Sync', summary.syncAttentionCount),
    ];
    final every = widget.refreshEvery;
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AdminTokens.line)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final item in items)
                    InkWell(
                      key: Key('collections-tab-${item.$1}'),
                      onTap: () => _setTab(item.$1),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(4, 8, 16, 10),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: _tab == item.$1 ? AdminTokens.button : Colors.transparent,
                              width: 2,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(
                              item.$2,
                              style: adminType(
                                13.5,
                                FontWeight.w700,
                                _tab == item.$1 ? AdminTokens.button : AdminTokens.textSecondary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: item.$1 == 'PendingSync' && item.$3 > 0
                                    ? AdminTokens.errorBg
                                    : AdminTokens.field,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${item.$3}',
                                style: adminType(
                                  11.5,
                                  FontWeight.w700,
                                  item.$1 == 'PendingSync' && item.$3 > 0
                                      ? AdminTokens.error
                                      : AdminTokens.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (every != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10, left: 12),
              child: Text(
                'Refreshing every ${every.inSeconds}s',
                style: adminType(12, FontWeight.w600, AdminTokens.textSecondary),
              ),
            ),
        ],
      ),
    );
  }

  Widget _filters() {
    final riderItems = <DropdownMenuItem<String?>>[
      const DropdownMenuItem(value: null, child: Text('All field riders')),
      for (final rider in _riders)
        DropdownMenuItem(
          value: rider.id,
          child: Text(
            rider.riderCode.isEmpty ? rider.fullName : '${rider.fullName} · ${rider.riderCode}',
            overflow: TextOverflow.ellipsis,
          ),
        ),
    ];
    if (_riderId != null && _riders.every((rider) => rider.id != _riderId)) {
      riderItems.add(DropdownMenuItem(value: _riderId, child: Text(_riderId!)));
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 720;
        final fieldWidth = wide ? 320.0 : constraints.maxWidth;
        final menuWidth = wide ? 180.0 : constraints.maxWidth;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: fieldWidth,
              child: TextField(
                key: const Key('collections-search'),
                controller: _search,
                decoration: InputDecoration(
                  hintText: 'Search collection ref, store name, customer code, or rider...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  isDense: true,
                  filled: true,
                  fillColor: AdminTokens.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AdminTokens.line),
                  ),
                ),
              ),
            ),
            _menu<String>(
              keyName: 'collections-tender',
              width: menuWidth,
              value: _tab,
              items: const [
                DropdownMenuItem(value: 'All', child: Text('All tenders')),
                DropdownMenuItem(value: 'Cash', child: Text('Cash spot')),
                DropdownMenuItem(value: 'PendingSync', child: Text('Pending sync')),
              ],
              onChanged: (value) {
                if (value != null) _setTab(value);
              },
            ),
            _menu<String?>(
              keyName: 'collections-rider',
              width: menuWidth,
              value: _riderId,
              items: riderItems,
              onChanged: (value) {
                setState(() {
                  _riderId = value;
                  _page = 1;
                });
                _reload();
              },
            ),
            OutlinedButton.icon(
              key: const Key('collections-date'),
              style: adminOutlineButton(),
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_today_outlined, size: 16),
              label: Text(_dateLabel),
            ),
            OutlinedButton(
              key: const Key('collections-reset'),
              style: adminOutlineButton(),
              onPressed: _resetFilters,
              child: const Text('Reset'),
            ),
          ],
        );
      },
    );
  }

  Widget _menu<T>({
    required String keyName,
    required double width,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return SizedBox(
      width: width,
      child: DropdownButtonFormField<T>(
        key: ValueKey('$keyName-$value'),
        initialValue: value,
        isExpanded: true,
        isDense: true,
        items: items,
        onChanged: onChanged,
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: AdminTokens.surface,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AdminTokens.line),
          ),
        ),
      ),
    );
  }

  Widget _ledger(AdminCollectionPage? page) {
    if (_pageData?.error != null && page == null) {
      return _error(_pageData!.error!);
    }
    final rows = page?.rows ?? const <AdminCollectionRow>[];
    return Container(
      decoration: BoxDecoration(
        color: AdminTokens.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminTokens.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Live Collection Entries',
                  style: adminType(15, FontWeight.w700, AdminTokens.text),
                ),
                const SizedBox(height: 2),
                Text(
                  page == null
                      ? 'Recorded collections for this day'
                      : 'Showing ${_rangeStart(page, rows.length)}–${_rangeEnd(page, rows.length)} of ${page.totalRecords}',
                  style: adminType(12, FontWeight.w500, AdminTokens.textSecondary),
                ),
              ],
            ),
          ),
          _ledgerHead(),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No collections matched the filters for ${formatAdminDay(_date)}.',
                style: adminType(13.5, FontWeight.w500, AdminTokens.textSecondary),
              ),
            )
          else
            for (final row in rows) _ledgerRow(row),
          if (page != null) _pager(page, rows.length),
        ],
      ),
    );
  }

  int _rangeStart(AdminCollectionPage page, int shown) {
    if (page.totalRecords == 0 || shown == 0) return 0;
    return ((page.page - 1) * page.pageSize) + 1;
  }

  int _rangeEnd(AdminCollectionPage page, int shown) {
    final start = _rangeStart(page, shown);
    if (start == 0) return 0;
    return start + shown - 1;
  }

  Widget _ledgerHead() {
    return Container(
      color: AdminTokens.field,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          _head('Reference', 16),
          _head('Time', 12),
          _head('Customer', 18),
          _head('Rider', 14),
          _head('Channel', 12),
          _head('Collected', 12),
          _head('Balance', 12),
          _head('Sync', 10),
        ],
      ),
    );
  }

  Widget _head(String label, int flex) {
    return Expanded(
      flex: flex,
      child: Text(
        label.toUpperCase(),
        style: adminType(10.5, FontWeight.w700, AdminTokens.textSecondary, letterSpacing: 0.3),
      ),
    );
  }

  Widget _ledgerRow(AdminCollectionRow row) {
    final selected = row.id == _selectedId;
    return Material(
      color: selected ? AdminTokens.primarySoft : Colors.transparent,
      child: InkWell(
        key: Key('collections-row-${row.id}'),
        onTap: () => _loadDetail(row.id),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AdminTokens.line)),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 16,
                child: Text(
                  row.referenceNumber,
                  style: adminType(12.5, FontWeight.w700, AdminTokens.button),
                ),
              ),
              Expanded(
                flex: 12,
                child: Text(
                  formatAdminStamp(row.createdAtUtc),
                  style: adminType(11.5, FontWeight.w500, AdminTokens.textSecondary),
                ),
              ),
              Expanded(
                flex: 18,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(row.customerName, style: adminType(12.5, FontWeight.w600, AdminTokens.text)),
                    Text(
                      '${row.customerCode}${row.customerArea.isEmpty ? '' : ' · ${row.customerArea}'}',
                      style: adminType(11.5, FontWeight.w500, AdminTokens.textSecondary),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 14,
                child: Text(row.riderName, style: adminType(12.5, FontWeight.w500, AdminTokens.text)),
              ),
              Expanded(
                flex: 12,
                child: Text(row.channelLabel, style: adminType(12, FontWeight.w700, AdminTokens.secondary)),
              ),
              Expanded(
                flex: 12,
                child: Text(formatPkr(row.amount), style: adminType(12.5, FontWeight.w700, AdminTokens.text)),
              ),
              Expanded(
                flex: 12,
                child: Text(
                  formatPkr(row.outstandingAfter),
                  style: adminType(12.5, FontWeight.w600, AdminTokens.text),
                ),
              ),
              Expanded(flex: 10, child: _syncPill(row.syncStatus)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pager(AdminCollectionPage page, int shown) {
    final pages = page.totalPages < 1 ? 1 : page.totalPages;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('Rows per page', style: adminType(12.5, FontWeight.w500, AdminTokens.textSecondary)),
          SizedBox(
            width: 84,
            child: DropdownButtonFormField<int>(
              key: ValueKey('collections-page-size-$_pageSize'),
              initialValue: _pageSize,
              isDense: true,
              isExpanded: true,
              items: const [
                DropdownMenuItem(value: 5, child: Text('5')),
                DropdownMenuItem(value: 10, child: Text('10')),
                DropdownMenuItem(value: 20, child: Text('20')),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _pageSize = value;
                  _page = 1;
                });
                _reload();
              },
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Text(
            'Showing ${_rangeStart(page, shown)}–${_rangeEnd(page, shown)} of ${page.totalRecords}',
            style: adminType(12.5, FontWeight.w600, AdminTokens.text),
          ),
          IconButton(
            key: const Key('collections-prev'),
            onPressed: page.page <= 1
                ? null
                : () {
                    setState(() => _page = page.page - 1);
                    _reload();
                  },
            icon: const Icon(Icons.chevron_left),
          ),
          IconButton(
            key: const Key('collections-next'),
            onPressed: page.page >= pages
                ? null
                : () {
                    setState(() => _page = page.page + 1);
                    _reload();
                  },
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  Widget _detailPanel() {
    if (_detailBusy && _detail?.value == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    final detail = _detail?.value;
    if (_detail?.error != null && detail == null) {
      return _error(_detail!.error!);
    }
    if (detail == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AdminTokens.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AdminTokens.line),
        ),
        child: Text(
          'Select a collection to view settlement details.',
          style: adminType(13.5, FontWeight.w500, AdminTokens.textSecondary),
        ),
      );
    }
    final remaining = detail.outstandingAfter;
    return Container(
      decoration: BoxDecoration(
        color: AdminTokens.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminTokens.line),
        boxShadow: AdminTokens.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: const BoxDecoration(
              color: AdminTokens.navy,
              borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Collection audit',
                  style: adminType(11, FontWeight.w700, AdminTokens.promoMuted, letterSpacing: 0.4),
                ),
                const SizedBox(height: 6),
                Text(
                  detail.referenceNumber,
                  style: adminType(16, FontWeight.w700, Colors.white),
                ),
                const SizedBox(height: 8),
                Text(
                  detail.customerName,
                  style: adminType(15, FontWeight.w700, Colors.white),
                ),
                Text(
                  '${detail.customerCode}${detail.routeName == null ? '' : ' · ${detail.routeName}'}',
                  style: adminType(12, FontWeight.w500, AdminTokens.promoTitle),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _syncPill(detail.syncStatus),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        formatAdminStamp(detail.createdAtUtc),
                        textAlign: TextAlign.end,
                        overflow: TextOverflow.ellipsis,
                        style: adminType(11.5, FontWeight.w600, AdminTokens.textSecondary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _section('Rider', [
                  detail.riderName,
                  detail.riderCode ?? detail.riderId,
                  detail.vehicleLabel ?? '—',
                ]),
                Text(
                  'Settlement arithmetic',
                  style: adminType(13, FontWeight.w700, AdminTokens.text),
                ),
                const SizedBox(height: 8),
                _moneyRow('Outstanding before', formatPkr(detail.outstandingBefore)),
                _moneyRow('Collected · ${detail.channelLabel}', formatPkr(detail.amount)),
                _moneyRow('Withholding', formatPkr(detail.withholdingTax)),
                _moneyRow('Remaining balance', formatPkr(remaining), strong: true),
                if (detail.notes != null) ...[
                  const SizedBox(height: 6),
                  Text(detail.notes!, style: adminType(12.5, FontWeight.w500, AdminTokens.textSecondary)),
                ],
                const SizedBox(height: 12),
                _section(
                  'Proof of collection',
                  detail.signerName == null
                      ? const ['No signature was stored for this collection.']
                      : [
                          '${detail.signerName}${detail.signerRole == null ? '' : ' (${detail.signerRole})'}',
                          detail.hasSignatureImage
                              ? 'Signature image is on file.'
                              : 'No signature image is stored.',
                          if (detail.signatureNote != null) detail.signatureNote!,
                        ],
                ),
                if (detail.scopeNote.isNotEmpty)
                  Text(
                    detail.scopeNote,
                    style: adminType(11.5, FontWeight.w500, AdminTokens.textSecondary),
                  ),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const Key('collections-print'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AdminTokens.button,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 42),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => _printSlip(detail),
                    icon: const Icon(Icons.print_outlined, size: 18),
                    label: const Text('Print slip'),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const Key('collections-download'),
                        style: adminOutlineButton(),
                        onPressed: () => _copySlip(detail),
                        icon: const Icon(Icons.download_outlined, size: 16),
                        label: const Text('Copy receipt'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const Key('collections-whatsapp'),
                        style: adminOutlineButton(),
                        onPressed: () => _whatsapp(detail.customerPhone, _slip(detail)),
                        icon: const Icon(Icons.chat_outlined, size: 16),
                        label: const Text('WhatsApp'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _moneyRow(String label, String value, {bool strong = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: adminType(12.5, strong ? FontWeight.w700 : FontWeight.w500, AdminTokens.textSecondary),
            ),
          ),
          Text(
            value,
            style: adminType(12.5, strong ? FontWeight.w700 : FontWeight.w600, strong ? AdminTokens.error : AdminTokens.text),
          ),
        ],
      ),
    );
  }

  Widget _channelSplit(AdminCollectionsSummary summary) {
    final total = summary.todaysCollections;
    final cash = total * summary.cashSharePercent / 100;
    final other = total - cash;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdminTokens.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminTokens.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Collections by channel', style: adminType(15, FontWeight.w700, AdminTokens.text)),
          const SizedBox(height: 4),
          Text(
            total == 0 ? 'No collections were recorded for this day.' : formatPkr(total),
            style: adminType(12.5, FontWeight.w600, AdminTokens.textSecondary),
          ),
          const SizedBox(height: 12),
          if (total > 0) ...[
            _shareBar('Cash spot', cash, summary.cashSharePercent),
            if (other.abs() >= 0.5)
              _shareBar('Other recorded channels', other, 100 - summary.cashSharePercent),
          ],
        ],
      ),
    );
  }

  Widget _shareBar(String label, num amount, num percent) {
    final width = (percent.clamp(0, 100)) / 100;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: adminType(12.5, FontWeight.w600, AdminTokens.text))),
              Text(
                '${percent.toStringAsFixed(0)}% · ${formatPkr(amount)}',
                style: adminType(12, FontWeight.w700, AdminTokens.text),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: width.toDouble(),
              backgroundColor: AdminTokens.field,
              color: AdminTokens.button,
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String title, List<String> lines) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: adminType(13, FontWeight.w700, AdminTokens.text)),
          const SizedBox(height: 4),
          for (final line in lines)
            if (line.trim().isNotEmpty)
              Text(
                line,
                style: adminType(12.5, FontWeight.w500, AdminTokens.textSecondary),
              ),
        ],
      ),
    );
  }

  Widget _syncPill(String status) {
    final pending = status.toLowerCase() != 'synced';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: pending ? AdminTokens.errorBg : AdminTokens.field,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: adminType(
          11,
          FontWeight.w700,
          pending ? AdminTokens.error : AdminTokens.textSecondary,
        ),
      ),
    );
  }

  Widget _error(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdminTokens.errorBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(message, style: adminType(13.5, FontWeight.w600, AdminTokens.error)),
    );
  }
}

class _CollKpi {
  const _CollKpi(
    this.label,
    this.value,
    this.hint,
    this.icon, {
    this.emphasize = false,
    this.hintColor,
  });

  final String label;
  final String value;
  final String hint;
  final IconData icon;
  final bool emphasize;
  final Color? hintColor;
}

class ManualSettlementDialog extends StatefulWidget {
  const ManualSettlementDialog({required this.api, super.key});

  final RouteApi api;

  @override
  State<ManualSettlementDialog> createState() => _ManualSettlementDialogState();
}

class _ManualSettlementDialogState extends State<ManualSettlementDialog> {
  final _amount = TextEditingController();
  final _tax = TextEditingController(text: '0');
  final _note = TextEditingController();
  final _signer = TextEditingController(text: 'Store Manager');
  var _busy = false;
  String? _error;
  String? _riderId;
  String? _customerId;
  List<StaffUser> _riders = const [];
  List<AdminCustomerRow> _customers = const [];

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _amount.dispose();
    _tax.dispose();
    _note.dispose();
    _signer.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() => _busy = true);
    try {
      final riders = await widget.api.staffUsers(
        role: 'Rider',
        isActive: true,
        pageSize: 100,
      );
      final customers = await widget.api.adminCustomers(
        status: 'Active',
        pageSize: 200,
      );
      if (!mounted) return;
      setState(() {
        _riders = riders.rows.where((row) => row.routeId != null).toList();
        _customers = customers.rows.where((row) => row.outstanding > 0).toList();
        _riderId = _riders.isEmpty ? null : _riders.first.id;
        _customerId = _customers.isEmpty ? null : _customers.first.id;
        if (_customerId != null) {
          final row = _customers.firstWhere((c) => c.id == _customerId);
          _amount.text = row.outstanding.toStringAsFixed(0);
        }
        _busy = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _busy = false;
      });
    }
  }

  void _onCustomerChanged(String? value) {
    setState(() {
      _customerId = value;
      AdminCustomerRow? row;
      for (final customer in _customers) {
        if (customer.id == value) {
          row = customer;
          break;
        }
      }
      if (row != null) {
        _amount.text = row.outstanding.toStringAsFixed(0);
      }
    });
  }

  Future<void> _submit() async {
    final riderId = _riderId;
    final customerId = _customerId;
    final amount = num.tryParse(_amount.text.trim());
    final tax = num.tryParse(_tax.text.trim()) ?? 0;
    final signer = _signer.text.trim();
    if (riderId == null ||
        customerId == null ||
        amount == null ||
        amount <= 0 ||
        signer.isEmpty) {
      setState(() => _error = 'Select rider and customer, enter a positive amount and signer.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.api.adminRecordCollection(
        riderUserId: riderId,
        customerId: customerId,
        amount: amount,
        signerName: signer,
        withholdingTax: tax > 0 ? tax : null,
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Manual Cash Settlement'),
      content: SizedBox(
        width: 480,
        child: _busy && _riders.isEmpty && _error == null
            ? const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()),
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          _error!,
                          style: adminType(13, FontWeight.w600, AdminTokens.error),
                        ),
                      ),
                    DropdownButtonFormField<String>(
                      // ignore: deprecated_member_use
                      value: _riderId,
                      decoration: const InputDecoration(labelText: 'Rider (requires route)'),
                      items: [
                        for (final rider in _riders)
                          DropdownMenuItem(
                            value: rider.id,
                            child: Text(
                              '${rider.fullName} · ${rider.routeName ?? rider.routeId ?? '—'}',
                            ),
                          ),
                      ],
                      onChanged: _busy ? null : (value) => setState(() => _riderId = value),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      // ignore: deprecated_member_use
                      value: _customerId,
                      decoration: const InputDecoration(labelText: 'Customer (with outstanding)'),
                      items: [
                        for (final customer in _customers)
                          DropdownMenuItem(
                            value: customer.id,
                            child: Text(
                              '${customer.businessName} · ${formatPkr(customer.outstanding)}',
                            ),
                          ),
                      ],
                      onChanged: _busy ? null : _onCustomerChanged,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _amount,
                      decoration: const InputDecoration(labelText: 'Collection amount (PKR)'),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _tax,
                      decoration: const InputDecoration(labelText: 'Withholding tax (optional)'),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _signer,
                      decoration: const InputDecoration(labelText: 'Signer name'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _note,
                      decoration: const InputDecoration(labelText: 'Note (optional)'),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Cash-only settlement in Locked V1. Server validates outstanding balance and route assignment.',
                      style: adminType(11.5, FontWeight.w500, AdminTokens.textSecondary),
                    ),
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: Text(_busy ? 'Posting…' : 'Post Collection'),
        ),
      ],
    );
  }
}