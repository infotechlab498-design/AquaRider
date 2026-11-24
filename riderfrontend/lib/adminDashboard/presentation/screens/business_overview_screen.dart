import 'dart:async';

import 'package:flutter/material.dart';

import '../../../api/route_api.dart';
import '../../data/dashboard_period.dart';
import '../../theme/admin_tokens.dart';
import '../admin_load.dart';
import '../admin_nav.dart';
import '../widgets/admin_shell.dart';
import '../widgets/dashboard/activity_ledger_table.dart';
import '../widgets/dashboard/attention_items_card.dart';
import '../widgets/dashboard/collections_summary_card.dart';
import '../widgets/dashboard/create_order_dialog.dart';
import '../widgets/dashboard/dashboard_header.dart';
import '../widgets/dashboard/dashboard_kpi_card.dart';
import '../widgets/dashboard/operational_summary_card.dart';
import '../widgets/dashboard/sales_summary_chart.dart';

class BusinessOverviewScreen extends StatefulWidget {
  const BusinessOverviewScreen({
    required this.onNavigate,
    this.session,
    super.key,
  });

  final AuthSession? session;
  final ValueChanged<String> onNavigate;

  @override
  State<BusinessOverviewScreen> createState() => _BusinessOverviewScreenState();
}

class _BusinessOverviewScreenState extends State<BusinessOverviewScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  var _started = false;
  var _loading = true;
  var _generation = 0;
  var _range = DashboardRange.today;
  var _page = 1;
  var _status = 'all';
  static const _pageSize = 8;

  AdminLoad<CommandOverview>? _overview;
  AdminLoad<DashboardKpiSet>? _kpis;
  AdminLoad<OperationalSummary>? _operational;
  AdminLoad<List<AttentionItem>>? _attention;
  AdminLoad<SalesSummary>? _sales;
  AdminLoad<CollectionsSummary>? _collections;
  AdminLoad<ActivityLedgerPage>? _ledger;

  DashboardPeriod get _period => DashboardPeriod.resolve(_range);

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _reload();
    });
  }

  @override
  void dispose() {
    _generation++;
    _debounce?.cancel();
    _search.removeListener(_scheduleSearch);
    _search.dispose();
    super.dispose();
  }

  void _scheduleSearch() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      _page = 1;
      _reload();
    });
  }

  Future<void> _reload() async {
    final generation = ++_generation;
    final period = _period;
    final page = _page;
    final status = _status == 'all' ? null : _status;
    final search = _search.text.trim();
    if (mounted && !_loading) setState(() => _loading = true);
    final api = ApiScope.of(context);
    final overviewF = guardAdminLoad(
      () => api.commandOverview(from: period.fromIso, to: period.toIso),
    );
    final kpisF = guardAdminLoad(
      () => api.commandKpis(from: period.fromIso, to: period.toIso),
    );
    final operationalF = guardAdminLoad(
      () => api.operationalSummary(from: period.fromIso, to: period.toIso),
    );
    final attentionF = guardAdminLoad(
      () => api.attentionItems(from: period.fromIso, to: period.toIso),
    );
    final salesF = guardAdminLoad(
      () => api.salesSummary(
        from: period.fromIso,
        to: period.toIso,
        bucket: period.bucket,
      ),
    );
    final collectionsF = guardAdminLoad(
      () => api.collectionsSummary(from: period.fromIso, to: period.toIso),
    );
    final ledgerF = guardAdminLoad(
      () => api.activityLedger(
        from: period.fromIso,
        to: period.toIso,
        search: search.isEmpty ? null : search,
        status: status,
        page: page,
        pageSize: _pageSize,
      ),
    );
    final overview = await overviewF;
    final kpis = await kpisF;
    final operational = await operationalF;
    final attention = await attentionF;
    final sales = await salesF;
    final collections = await collectionsF;
    final ledger = await ledgerF;
    if (!mounted || generation != _generation) return;
    setState(() {
      _overview = overview;
      _kpis = kpis;
      _operational = operational;
      _attention = attention;
      _sales = sales;
      _collections = collections;
      _ledger = ledger;
      _loading = false;
    });
  }

  List<AdminLoad<dynamic>> get _loads => [
    ?_overview,
    ?_kpis,
    ?_operational,
    ?_attention,
    ?_sales,
    ?_collections,
    ?_ledger,
  ];

  Future<void> _createOrder() async {
    final created = await showDialog<AdminOrderResult>(
      context: context,
      builder: (context) => const CreateOrderDialog(),
    );
    if (created == null || !mounted) return;
    showAdminNotice(context, created.notice);
    _reload();
  }

  void _setRange(DashboardRange range) {
    if (range == _range) return;
    _range = range;
    _page = 1;
    _reload();
  }

  void _setStatus(String status) {
    _status = status;
    _page = 1;
    _reload();
  }

  bool get _canGoForward {
    final ledger = _ledger?.value;
    if (ledger == null) return false;
    final pages = ledger.totalPages;
    if (pages != null) return _page < pages;
    return ledger.rows.length >= ledger.pageSize;
  }

  @override
  Widget build(BuildContext context) {
    final loads = _loads;
    final banner = adminErrorBanner(loads);
    final overview = _overview?.value;
    final businessName = overview?.businessName;
    final businessLine = overview?.subtitle?.trim().isNotEmpty == true
        ? overview!.subtitle!.trim()
        : (businessName == null || businessName.isEmpty)
        ? 'Business name was not returned for this account.'
        : 'Operational status for $businessName.';
    return AdminShell(
      screenKey: const Key('business-overview-screen'),
      activeKey: AdminNav.dashboard,
      session: widget.session,
      serverReachable: adminServerReachable(loads),
      search: _search,
      onSearch: (_) {},
      searchHint: 'Search activity, customers, or riders',
      onNavigate: widget.onNavigate,
      databaseLatencyMs: overview?.databaseLatencyMs,
      trailing: IconButton(
        key: const Key('dashboard-refresh'),
        tooltip: 'Refresh',
        onPressed: _reload,
        icon: const Icon(Icons.refresh, color: AdminTokens.secondary),
      ),
      body: _loading
          ? const AdminLoadingPane(label: 'Loading command dashboard…')
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
              children: [
                DashboardHeader(
                  greeting: commandGreeting(
                    widget.session,
                    fromApi: overview?.greeting,
                  ),
                  businessLine: businessLine,
                  facilityName: overview?.facilityName,
                  onDutyRiders: overview?.onDutyRiders,
                  period: _period,
                  onRange: _setRange,
                  onCreateOrder: _createOrder,
                ),
                const SizedBox(height: 16),
                if (banner != null) ...[
                  AdminSectionMessage(
                    key: const Key('admin-error-banner'),
                    message: banner,
                    onRetry: _reload,
                    error: true,
                  ),
                  const SizedBox(height: 16),
                ],
                _kpisBlock(),
                const SizedBox(height: 16),
                _activityRow(),
                const SizedBox(height: 16),
                _chartsRow(),
                const SizedBox(height: 16),
                _ledgerBlock(),
              ],
            ),
    );
  }

  Widget _kpisBlock() {
    final load = _kpis;
    if (load == null || load.failed) {
      return const AdminSectionMessage(
        message: 'KPI figures could not be loaded.',
        error: true,
      );
    }
    if (load.value!.cards.isEmpty) {
      return const AdminSectionMessage(
        message: 'No KPI figures were returned for this period.',
      );
    }
    return DashboardKpiWrap(cards: load.value!.cards);
  }

  Widget _activityRow() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final operational = _operationalBlock();
        final attention = _attentionBlock();
        if (constraints.maxWidth < 900) {
          return Column(
            children: [operational, const SizedBox(height: 16), attention],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: operational),
            const SizedBox(width: 16),
            Expanded(flex: 2, child: attention),
          ],
        );
      },
    );
  }

  Widget _operationalBlock() {
    final load = _operational;
    if (load == null || load.failed) {
      return const AdminSectionMessage(
        message: 'Operational activity could not be loaded.',
        error: true,
      );
    }
    return OperationalSummaryCard(summary: load.value!);
  }

  Widget _attentionBlock() {
    final load = _attention;
    if (load == null || load.failed) {
      return const AdminSectionMessage(
        message: 'Attention items could not be loaded.',
        error: true,
      );
    }
    return AttentionItemsCard(items: load.value!);
  }

  Widget _chartsRow() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final sales = _salesBlock();
        final collections = _collectionsBlock();
        if (constraints.maxWidth < 900) {
          return Column(
            children: [sales, const SizedBox(height: 16), collections],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: sales),
            const SizedBox(width: 16),
            Expanded(child: collections),
          ],
        );
      },
    );
  }

  Widget _salesBlock() {
    final load = _sales;
    if (load == null || load.failed) {
      return const AdminSectionMessage(
        message: 'Sales summary could not be loaded.',
        error: true,
      );
    }
    return SalesSummaryChart(summary: load.value!);
  }

  Widget _collectionsBlock() {
    final load = _collections;
    if (load == null || load.failed) {
      return const AdminSectionMessage(
        message: 'Collections summary could not be loaded.',
        error: true,
      );
    }
    return CollectionsSummaryCard(summary: load.value!);
  }

  Widget _ledgerBlock() {
    final load = _ledger;
    if (load == null || load.failed) {
      return AdminSectionMessage(
        message: 'The activity ledger could not be loaded.',
        onRetry: _reload,
        error: true,
      );
    }
    return ActivityLedgerTable(
      page: load.value,
      search: _search,
      status: _status,
      onStatus: _setStatus,
      onPrevious: _page <= 1
          ? null
          : () {
              _page -= 1;
              _reload();
            },
      onNext: !_canGoForward
          ? null
          : () {
              _page += 1;
              _reload();
            },
    );
  }
}
