import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:riderfrontend/adminDashboard/data/admin_format.dart';
import 'package:riderfrontend/adminDashboard/presentation/admin_load.dart';
import 'package:riderfrontend/adminDashboard/presentation/admin_nav.dart';
import 'package:riderfrontend/adminDashboard/presentation/widgets/admin_shell.dart';
import 'package:riderfrontend/adminDashboard/theme/admin_tokens.dart';
import 'package:riderfrontend/api/route_api.dart';

class SecurityAuditScreen extends StatefulWidget {
  const SecurityAuditScreen({
    required this.onNavigate,
    this.session,
    super.key,
  });

  final AuthSession? session;
  final ValueChanged<String> onNavigate;

  @override
  State<SecurityAuditScreen> createState() => _SecurityAuditScreenState();
}

class _SecurityAuditScreenState extends State<SecurityAuditScreen> {
  final _search = TextEditingController();
  var _started = false;
  var _loading = true;
  var _page = 1;
  var _category = 'All';
  var _outcome = 'All';
  DateTime _date = _today();
  String? _selectedId;
  var _verifyBusy = false;
  var _exportBusy = false;

  AdminLoad<AdminAuditSummary>? _summary;
  AdminLoad<AdminAuditEventPage>? _pageData;
  AdminLoad<AdminAuditEventDetail>? _detail;

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  String get _dateIso =>
      '${_date.year.toString().padLeft(4, '0')}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}';

  String? get _categoryQuery =>
      _category == 'All' ? null : _category;

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
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final api = ApiScope.of(context);
    final summary = await guardAdminLoad(
      () => api.adminAuditSummary(date: _dateIso),
    );
    final page = await guardAdminLoad(
      () => api.adminAuditEvents(
        date: _dateIso,
        category: _categoryQuery,
        search: _search.text.trim().isEmpty ? null : _search.text.trim(),
        outcome: _outcome == 'All' ? null : _outcome,
        page: _page,
      ),
    );
    if (!mounted) return;
    setState(() {
      _summary = summary;
      _pageData = page;
      _loading = false;
    });
    final items = page.value?.items ?? const <AdminAuditEventRow>[];
    if (items.isEmpty) {
      setState(() {
        _selectedId = null;
        _detail = null;
      });
      return;
    }
    final keep = _selectedId != null && items.any((row) => row.id == _selectedId)
        ? _selectedId!
        : items.first.id;
    await _select(keep);
  }

  Future<void> _select(String id) async {
    setState(() => _selectedId = id);
    final detail = await guardAdminLoad(
      () => ApiScope.of(context).adminAuditEvent(id),
    );
    if (!mounted) return;
    setState(() => _detail = detail);
  }

  Future<void> _verify() async {
    final id = _selectedId;
    if (id == null) {
      showAdminNotice(context, 'Select an audit event first.');
      return;
    }
    setState(() => _verifyBusy = true);
    try {
      final result = await ApiScope.of(context).adminAuditVerify(id);
      if (!mounted) return;
      showAdminNotice(context, '${result.status}: ${result.message}');
      await _select(id);
    } on ApiException catch (error) {
      if (mounted) showAdminNotice(context, error.message);
    } catch (_) {
      if (mounted) showAdminNotice(context, adminUnreachableMessage);
    } finally {
      if (mounted) setState(() => _verifyBusy = false);
    }
  }

  Future<void> _export() async {
    setState(() => _exportBusy = true);
    try {
      final csv = await ApiScope.of(context).adminAuditExportCsv(
        date: _dateIso,
        category: _categoryQuery,
        search: _search.text.trim().isEmpty ? null : _search.text.trim(),
      );
      if (!mounted) return;
      await Clipboard.setData(ClipboardData(text: csv));
      if (!mounted) return;
      showAdminNotice(
        context,
        'Tamper-proof CSV export copied to clipboard (${csv.split('\n').length - 1} data rows).',
      );
    } on ApiException catch (error) {
      if (mounted) showAdminNotice(context, error.message);
    } catch (_) {
      if (mounted) showAdminNotice(context, adminUnreachableMessage);
    } finally {
      if (mounted) setState(() => _exportBusy = false);
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
    final loads = <AdminLoad<dynamic>>[?_summary, ?_pageData, ?_detail];
    final summary = _summary?.value;
    final page = _pageData?.value;
    final wide = MediaQuery.sizeOf(context).width >= 1180;
    return AdminShell(
      screenKey: const Key('security-audit-screen'),
      session: widget.session,
      activeKey: AdminNav.securityAudit,
      serverReachable: adminServerReachable(loads),
      search: _search,
      onSearch: (_) {},
      searchHint: 'Search event id, actor, entity or reference…',
      onNavigate: widget.onNavigate,
      trailing: IconButton(
        tooltip: 'Refresh',
        onPressed: _loading ? null : _reload,
        icon: const Icon(Icons.refresh, color: AdminTokens.secondary),
      ),
      body: _loading && summary == null
          ? const AdminLoadingPane(label: 'Loading security audit trail…')
          : ListView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              children: [
                _header(),
                const SizedBox(height: 16),
                if (_summary?.error != null && summary == null)
                  _error(_summary!.error!)
                else if (summary != null) ...[
                  _kpiRow(summary),
                  const SizedBox(height: 12),
                  Text(
                    summary.integrityNote,
                    style: adminType(12, FontWeight.w600, AdminTokens.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  _tabs(summary),
                  const SizedBox(height: 12),
                  _filters(),
                  const SizedBox(height: 16),
                  if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 62, child: _stream(page)),
                        const SizedBox(width: 16),
                        Expanded(flex: 38, child: _dossier()),
                      ],
                    )
                  else ...[
                    _stream(page),
                    const SizedBox(height: 16),
                    _dossier(),
                  ],
                ],
              ],
            ),
    );
  }

  ButtonStyle _finiteButton() {
    return FilledButton.styleFrom(
      backgroundColor: AdminTokens.button,
      foregroundColor: Colors.white,
      elevation: 0,
      minimumSize: const Size(0, 40),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }

  Widget _header() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'System > Audit Log',
                style: adminType(12, FontWeight.w600, AdminTokens.textSecondary),
              ),
              const SizedBox(height: 6),
              Text(
                'Security & Operations Audit Trail',
                style: adminType(26, FontWeight.w700, AdminTokens.text, height: 1.2),
              ),
              const SizedBox(height: 6),
              Text(
                'Read-only records of administrative changes, financial journal entries, dispatcher assignments and authentication events.',
                style: adminType(13.5, FontWeight.w500, AdminTokens.textSecondary),
              ),
            ],
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: _verifyBusy ? null : _verify,
              icon: _verifyBusy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.verified_outlined, size: 18),
              label: const Text('Verify Ledger Hash'),
            ),
            FilledButton.icon(
              style: _finiteButton(),
              onPressed: _exportBusy ? null : _export,
              icon: _exportBusy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.download_outlined, size: 18),
              label: const Text('Export Tamper-Proof Audit Log'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _kpiRow(AdminAuditSummary summary) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1100;
        final cards = [
          _kpi('Total Recorded Events Today', '${summary.totalEventsToday}', 'Indexed AuditLogs', AdminTokens.primary),
          _kpi('User & Courier Actions', '${summary.userAndCourierActions}', 'Operational share', AdminTokens.secondary),
          _kpi('Administrative Mod.', '${summary.administrativeModifications}', 'HQ configuration', AdminTokens.primary),
          _kpi('Financial Journal Ops', '${summary.financialJournalOps}', 'Sales & collections', const Color(0xFF2E7D32)),
        ];
        if (wide) {
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
          children: [for (final card in cards) SizedBox(width: 260, child: card)],
        );
      },
    );
  }

  Widget _kpi(String title, String value, String subtitle, Color accent) {
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
          Text(title, style: adminType(12, FontWeight.w600, AdminTokens.textSecondary)),
          const SizedBox(height: 8),
          Text(value, style: adminType(28, FontWeight.w700, accent)),
          const SizedBox(height: 4),
          Text(subtitle, style: adminType(12, FontWeight.w500, AdminTokens.textSecondary)),
        ],
      ),
    );
  }

  Widget _tabs(AdminAuditSummary summary) {
    final tabs = <(String, String, int)>[
      ('All', 'All Events', summary.totalEventsToday),
      ('FinancialJournal', 'Financial Journal', summary.financialJournalOps),
      ('FieldOperations', 'Field Operations', summary.fieldOperations),
      ('AccessSecurity', 'Access & Security', summary.accessAndSecurity),
      ('MasterData', 'Master Data', summary.masterData),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final tab in tabs)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text('${tab.$2} (${tab.$3})'),
                selected: _category == tab.$1,
                onSelected: (_) {
                  setState(() {
                    _category = tab.$1;
                    _page = 1;
                  });
                  _reload();
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _filters() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 280,
          child: TextField(
            controller: _search,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Event ID, employee, receipt, transaction…',
              isDense: true,
            ),
            onSubmitted: (_) {
              setState(() => _page = 1);
              _reload();
            },
          ),
        ),
        DropdownButton<String>(
          value: _outcome,
          items: const [
            DropdownMenuItem(value: 'All', child: Text('All Outcomes')),
            DropdownMenuItem(value: 'Success', child: Text('Success')),
            DropdownMenuItem(value: 'Failed', child: Text('Failed')),
          ],
          onChanged: (value) {
            if (value == null) return;
            setState(() {
              _outcome = value;
              _page = 1;
            });
            _reload();
          },
        ),
        OutlinedButton.icon(
          onPressed: _pickDate,
          icon: const Icon(Icons.calendar_today_outlined, size: 16),
          label: Text(formatAdminDay(_date)),
        ),
        FilledButton(
          style: _finiteButton(),
          onPressed: () {
            setState(() => _page = 1);
            _reload();
          },
          child: const Text('Apply'),
        ),
      ],
    );
  }

  Widget _stream(AdminAuditEventPage? page) {
    final items = page?.items ?? const <AdminAuditEventRow>[];
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminTokens.border),
      ),
      child: Column(
        children: [
          if (_pageData?.error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: _error(_pageData!.error!),
            )
          else if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No audit events matched the filters.',
                style: adminType(14, FontWeight.w500, AdminTokens.textSecondary),
              ),
            )
          else
            for (final row in items)
              InkWell(
                onTap: () => _select(row.id),
                child: Container(
                  decoration: BoxDecoration(
                    color: row.id == _selectedId
                        ? AdminTokens.primary.withValues(alpha: 0.08)
                        : null,
                    border: Border(
                      left: BorderSide(
                        color: row.id == _selectedId
                            ? AdminTokens.primary
                            : Colors.transparent,
                        width: 3,
                      ),
                      bottom: BorderSide(color: AdminTokens.border.withValues(alpha: 0.7)),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 96,
                        child: Text(
                          row.occurredAtUtc == null
                              ? '—'
                              : TimeOfDay.fromDateTime(row.occurredAtUtc!).format(context),
                          style: adminType(12.5, FontWeight.w600, AdminTokens.text),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          '${row.actorName} · ${row.actorRole}',
                          style: adminType(13, FontWeight.w600, AdminTokens.text),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          row.description,
                          style: adminType(13, FontWeight.w500, AdminTokens.text),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          '${row.entityName} · ${row.entityId}',
                          style: adminType(12.5, FontWeight.w600, AdminTokens.primary),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          row.outcome,
                          style: adminType(11.5, FontWeight.w700, const Color(0xFF2E7D32)),
                        ),
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
  }

  Widget _dossier() {
    final detail = _detail?.value;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminTokens.border),
      ),
      child: _detail?.error != null && detail == null
          ? _error(_detail!.error!)
          : detail == null
              ? Text(
                  'Select an audit event to inspect the ledger dossier.',
                  style: adminType(13.5, FontWeight.w500, AdminTokens.textSecondary),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ledger Event Dossier',
                      style: adminType(16, FontWeight.w700, AdminTokens.text),
                    ),
                    const SizedBox(height: 8),
                    Text(detail.id, style: adminType(12, FontWeight.w600, AdminTokens.textSecondary)),
                    const SizedBox(height: 12),
                    _meta('Action', detail.action),
                    _meta('Actor', '${detail.actorName} (${detail.actorRole})'),
                    _meta('Module', '${detail.entityName} / ${detail.entityId}'),
                    _meta('Outcome', detail.outcome),
                    _meta('Verification', detail.verificationStatus),
                    if (detail.verificationMessage != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        detail.verificationMessage!,
                        style: adminType(12, FontWeight.w500, AdminTokens.textSecondary),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Text(
                      'Delta state diffs and client telemetry are not stored on AuditLog rows.',
                      style: adminType(12, FontWeight.w600, AdminTokens.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Associated timeline',
                      style: adminType(14, FontWeight.w700, AdminTokens.text),
                    ),
                    const SizedBox(height: 8),
                    if (detail.timeline.isEmpty)
                      Text(
                        'No related events.',
                        style: adminType(12.5, FontWeight.w500, AdminTokens.textSecondary),
                      )
                    else
                      for (final item in detail.timeline)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Icon(
                                item.isCurrent ? Icons.radio_button_checked : Icons.circle_outlined,
                                size: 14,
                                color: item.isCurrent ? AdminTokens.primary : AdminTokens.textSecondary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${item.action} · ${item.entityName}',
                                  style: adminType(
                                    12.5,
                                    item.isCurrent ? FontWeight.w700 : FontWeight.w500,
                                    AdminTokens.text,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    const SizedBox(height: 8),
                    Text(
                      detail.scopeNote,
                      style: adminType(11.5, FontWeight.w500, AdminTokens.textSecondary),
                    ),
                  ],
                ),
    );
  }

  Widget _meta(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: adminType(12, FontWeight.w600, AdminTokens.textSecondary)),
          ),
          Expanded(child: Text(value, style: adminType(13, FontWeight.w600, AdminTokens.text))),
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
