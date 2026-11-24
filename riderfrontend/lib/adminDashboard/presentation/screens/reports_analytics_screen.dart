import 'package:flutter/material.dart';

import 'package:riderfrontend/adminDashboard/data/admin_format.dart';
import 'package:riderfrontend/adminDashboard/presentation/admin_load.dart';
import 'package:riderfrontend/adminDashboard/presentation/admin_nav.dart';
import 'package:riderfrontend/adminDashboard/presentation/widgets/admin_shell.dart';
import 'package:riderfrontend/adminDashboard/theme/admin_tokens.dart';
import 'package:riderfrontend/api/route_api.dart';

class ReportsAnalyticsScreen extends StatefulWidget {
  const ReportsAnalyticsScreen({
    required this.onNavigate,
    this.session,
    super.key,
  });

  final AuthSession? session;
  final ValueChanged<String> onNavigate;

  @override
  State<ReportsAnalyticsScreen> createState() => _ReportsAnalyticsScreenState();
}

class _ReportsAnalyticsScreenState extends State<ReportsAnalyticsScreen> {
  final _search = TextEditingController();
  var _started = false;
  var _loading = true;
  var _timeline = 'Last 7';
  var _catalogCategory = 'All';
  String? _selectedReportKey;
  var _runBusy = false;
  var _exportBusy = false;

  AdminLoad<AdminReportsSummary>? _summary;
  AdminLoad<List<AdminReportCatalogItem>>? _catalog;
  AdminLoad<AdminReportTable>? _table;

  DateTime _from = _today().subtract(const Duration(days: 6));
  DateTime _to = _today();

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  String _iso(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

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

  void _applyTimeline(String label) {
    final today = _today();
    late DateTime from;
    final to = today;
    switch (label) {
      case 'Today':
        from = today;
      case 'Last 30':
        from = today.subtract(const Duration(days: 29));
      case 'This Month':
        from = DateTime(today.year, today.month, 1);
      case 'Last 7':
      default:
        from = today.subtract(const Duration(days: 6));
    }
    setState(() {
      _timeline = label;
      _from = from;
      _to = to;
      _table = null;
      _selectedReportKey = null;
    });
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final api = ApiScope.of(context);
    final summary = await guardAdminLoad(
      () => api.adminReportsSummary(from: _iso(_from), to: _iso(_to)),
    );
    final catalog = await guardAdminLoad(() => api.adminReportsCatalog());
    if (!mounted) return;
    setState(() {
      _summary = summary;
      _catalog = catalog;
      _loading = false;
    });
  }

  void _unavailable(String feature) {
    showAdminNotice(context, '$feature is not available in Locked V1.');
  }

  List<AdminReportCatalogItem> get _filteredCatalog {
    final items = _catalog?.value ?? const <AdminReportCatalogItem>[];
    final term = _search.text.trim().toLowerCase();
    return items.where((item) {
      final categoryOk =
          _catalogCategory == 'All' || item.category == _catalogCategory;
      final searchOk = term.isEmpty ||
          item.name.toLowerCase().contains(term) ||
          item.description.toLowerCase().contains(term) ||
          item.key.toLowerCase().contains(term);
      return categoryOk && searchOk;
    }).toList();
  }

  Set<String> get _categories {
    final items = _catalog?.value ?? const <AdminReportCatalogItem>[];
    return {'All', ...items.map((row) => row.category).where((c) => c.isNotEmpty)};
  }

  Future<void> _runReport(String key) async {
    setState(() {
      _selectedReportKey = key;
      _runBusy = true;
      _table = null;
    });
    final table = await guardAdminLoad(
      () => ApiScope.of(context).adminReportRun(
        key,
        from: _iso(_from),
        to: _iso(_to),
      ),
    );
    if (!mounted || _selectedReportKey != key) return;
    setState(() {
      _table = table;
      _runBusy = false;
    });
  }

  Future<void> _exportCsv(String key) async {
    setState(() => _exportBusy = true);
    try {
      final csv = await ApiScope.of(context).adminReportExportCsv(
        key,
        from: _iso(_from),
        to: _iso(_to),
      );
      if (!mounted) return;
      final bytes = csv.length;
      final lines = '\n'.allMatches(csv).length + (csv.isEmpty ? 0 : 1);
      showAdminNotice(
        context,
        'CSV export ready — $bytes bytes, $lines lines (not saved locally in V1).',
      );
    } on ApiException catch (error) {
      if (mounted) showAdminNotice(context, error.message);
    } catch (_) {
      if (mounted) showAdminNotice(context, adminUnreachableMessage);
    } finally {
      if (mounted) setState(() => _exportBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loads = <AdminLoad<dynamic>>[?_summary, ?_catalog, ?_table];
    final summary = _summary?.value;
    return AdminShell(
      screenKey: const Key('reports-analytics-screen'),
      session: widget.session,
      activeKey: AdminNav.reportsAnalytics,
      serverReachable: adminServerReachable(loads),
      search: _search,
      onSearch: (_) => setState(() {}),
      searchHint: 'Search report catalog…',
      onNavigate: widget.onNavigate,
      trailing: IconButton(
        tooltip: 'Refresh',
        onPressed: _loading ? null : _reload,
        icon: const Icon(Icons.refresh, color: AdminTokens.secondary),
      ),
      body: _loading && summary == null
          ? const AdminLoadingPane(label: 'Loading reports & analytics…')
          : ListView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              children: [
                _header(),
                const SizedBox(height: 16),
                _timelineRow(),
                const SizedBox(height: 16),
                if (_summary?.error != null && summary == null)
                  _error(_summary!.error!)
                else if (summary != null) ...[
                  _kpiRow(summary),
                  const SizedBox(height: 16),
                  _seriesSection(summary),
                  const SizedBox(height: 16),
                  _fulfillmentSection(summary),
                  const SizedBox(height: 16),
                  _leaderboardSection(summary),
                  const SizedBox(height: 16),
                  _assetSection(summary),
                  const SizedBox(height: 20),
                  _catalogSection(),
                  if (_table != null || _runBusy) ...[
                    const SizedBox(height: 16),
                    _tableSection(),
                  ],
                ],
              ],
            ),
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
                'Reports & Operational Analytics',
                style: adminType(26, FontWeight.w700, AdminTokens.text, height: 1.2),
              ),
              const SizedBox(height: 6),
              Text(
                '${formatAdminDay(_from)} – ${formatAdminDay(_to)}',
                style: adminType(13.5, FontWeight.w600, AdminTokens.textSecondary),
              ),
            ],
          ),
        ),
        OutlinedButton(
          onPressed: () => _unavailable('Schedule Auto-Export'),
          child: const Text('Schedule Auto-Export'),
        ),
        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: () => _unavailable('Generate Custom Report (PDF)'),
          child: const Text('Custom Report (PDF)'),
        ),
      ],
    );
  }

  Widget _timelineRow() {
    const options = ['Today', 'Last 7', 'Last 30', 'This Month'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final option in options)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                selected: _timeline == option,
                label: Text(option),
                onSelected: (_) => _applyTimeline(option),
              ),
            ),
        ],
      ),
    );
  }

  Widget _kpiRow(AdminReportsSummary summary) {
    String pct(num? value) =>
        value == null ? '—' : '${value >= 0 ? '+' : ''}${value.toStringAsFixed(1)}%';
    final cards = [
      _ReportKpi('Realized Sales', formatPkr(summary.totalRealizedSales), pct(summary.salesChangePercent)),
      _ReportKpi('Collections', formatPkr(summary.collectionsReceived), pct(summary.recoveryRatePercent)),
      _ReportKpi('Receivables Float', formatPkr(summary.receivablesFloat), '${summary.receivableAccounts} accounts'),
      _ReportKpi('Avg Receivable Age', summary.averageReceivableAgeDays == null ? '—' : '${summary.averageReceivableAgeDays!.toStringAsFixed(1)} days', 'Days on book'),
      _ReportKpi('Completed Drops', '${summary.completedDrops}', 'First-attempt SLA ${pct(summary.firstAttemptSlaPercent)}'),
      _ReportKpi('Customer Visits', '${summary.customerVisits}', '${summary.fleetCouriers} couriers'),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth >= 1100 ? 3 : 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final card in cards)
              SizedBox(
                width: (constraints.maxWidth - (cols - 1) * 12) / cols,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AdminTokens.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AdminTokens.line),
                    boxShadow: AdminTokens.softShadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(card.label, style: adminType(11.5, FontWeight.w600, AdminTokens.textSecondary)),
                      const SizedBox(height: 8),
                      Text(card.value, style: adminType(20, FontWeight.w700, AdminTokens.text)),
                      Text(card.hint, style: adminType(11.5, FontWeight.w500, AdminTokens.textSecondary)),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _seriesSection(AdminReportsSummary summary) {
    final sales = summary.salesSeries;
    final collections = summary.collectionsSeries;
    final length = sales.length > collections.length ? sales.length : collections.length;
    num maxVal = 1;
    for (var i = 0; i < length; i++) {
      if (i < sales.length) maxVal = sales[i].amount > maxVal ? sales[i].amount : maxVal;
      if (i < collections.length) {
        maxVal = collections[i].amount > maxVal ? collections[i].amount : maxVal;
      }
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdminTokens.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminTokens.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Sales vs Collections', style: adminType(15, FontWeight.w700, AdminTokens.text)),
          const SizedBox(height: 12),
          if (length == 0)
            Text('No series data for this window.', style: adminType(13, FontWeight.w500, AdminTokens.textSecondary))
          else
            for (var i = 0; i < length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      i < sales.length ? sales[i].day : (i < collections.length ? collections[i].day : '—'),
                      style: adminType(12, FontWeight.w600, AdminTokens.textSecondary),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: LinearProgressIndicator(
                            value: i < sales.length ? (sales[i].amount / maxVal).clamp(0.0, 1.0) : 0,
                            backgroundColor: AdminTokens.field,
                            color: AdminTokens.primary,
                            minHeight: 8,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          i < sales.length ? formatPkr(sales[i].amount) : '—',
                          style: adminType(11, FontWeight.w600, AdminTokens.text),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: LinearProgressIndicator(
                            value: i < collections.length
                                ? (collections[i].amount / maxVal).clamp(0.0, 1.0)
                                : 0,
                            backgroundColor: AdminTokens.field,
                            color: AdminTokens.secondary,
                            minHeight: 8,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          i < collections.length ? formatPkr(collections[i].amount) : '—',
                          style: adminType(11, FontWeight.w600, AdminTokens.text),
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

  Widget _fulfillmentSection(AdminReportsSummary summary) {
    return _panel(
      'Fulfillment Mix',
      summary.fulfillment.isEmpty
          ? [Text('No fulfillment breakdown.', style: adminType(13, FontWeight.w500, AdminTokens.textSecondary))]
          : [
              for (final slice in summary.fulfillment)
                ListTile(
                  dense: true,
                  title: Text(slice.label),
                  trailing: Text('${slice.count} · ${slice.percent.toStringAsFixed(1)}%'),
                ),
            ],
    );
  }

  Widget _leaderboardSection(AdminReportsSummary summary) {
    return _panel(
      'Rider Leaderboard',
      summary.riderLeaderboard.isEmpty
          ? [Text('No rider productivity data.', style: adminType(13, FontWeight.w500, AdminTokens.textSecondary))]
          : [
              for (final rider in summary.riderLeaderboard)
                ListTile(
                  dense: true,
                  title: Text(rider.riderName),
                  subtitle: Text(rider.routeName ?? rider.riderId),
                  trailing: Text(
                    '${formatPkr(rider.recoveryAmount)} · ${rider.stopsCompleted} stops',
                  ),
                ),
            ],
    );
  }

  Widget _assetSection(AdminReportsSummary summary) {
    final assets = summary.assetCirculation;
    return _panel(
      '19L Asset Circulation',
      [
        Text(
          'Issued ${assets.issued} · Recovered ${assets.recovered} · Store float ${assets.storeFloat} · Scrap ${assets.scrap}',
          style: adminType(13, FontWeight.w500, AdminTokens.text),
        ),
        Text(
          'Cleared ${assets.clearedPercent.toStringAsFixed(1)}%',
          style: adminType(12.5, FontWeight.w600, AdminTokens.textSecondary),
        ),
      ],
    );
  }

  Widget _panel(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdminTokens.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminTokens.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: adminType(15, FontWeight.w700, AdminTokens.text)),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _catalogSection() {
    if (_catalog?.error != null && _catalog?.value == null) {
      return _error(_catalog!.error!);
    }
    final items = _filteredCatalog;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Report Catalog', style: adminType(15, FontWeight.w700, AdminTokens.text)),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final category in _categories.toList()..sort())
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    selected: _catalogCategory == category,
                    label: Text(category),
                    onSelected: (_) => setState(() => _catalogCategory = category),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          Text('No catalog items match.', style: adminType(13, FontWeight.w500, AdminTokens.textSecondary))
        else
          for (final item in items)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(item.name),
                subtitle: Text('${item.category} · ${item.description}'),
                trailing: Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: _runBusy ? null : () => _runReport(item.key),
                      child: const Text('Run Now'),
                    ),
                    OutlinedButton(
                      onPressed: _exportBusy ? null : () => _exportCsv(item.key),
                      child: const Text('Export CSV'),
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }

  Widget _tableSection() {
    if (_runBusy && (_table?.value == null)) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final table = _table?.value;
    if (_table?.error != null && table == null) {
      return _error(_table!.error!);
    }
    if (table == null) return const SizedBox.shrink();
    return Container(
      decoration: BoxDecoration(
        color: AdminTokens.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminTokens.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '${table.name} · generated ${formatAdminStamp(table.generatedAtUtc)}',
              style: adminType(14, FontWeight.w700, AdminTokens.text),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: [
                for (final column in table.columns) DataColumn(label: Text(column)),
              ],
              rows: [
                for (final row in table.rows)
                  DataRow(
                    cells: [
                      for (final cell in row) DataCell(Text(cell)),
                    ],
                  ),
              ],
            ),
          ),
        ],
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

class _ReportKpi {
  const _ReportKpi(this.label, this.value, this.hint);
  final String label;
  final String value;
  final String hint;
}