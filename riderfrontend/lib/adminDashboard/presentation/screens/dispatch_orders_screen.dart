import 'dart:async';

import 'package:flutter/material.dart';

import 'package:riderfrontend/adminDashboard/data/admin_format.dart';
import 'package:riderfrontend/adminDashboard/data/dashboard_period.dart';
import 'package:riderfrontend/adminDashboard/presentation/admin_load.dart';
import 'package:riderfrontend/adminDashboard/presentation/admin_nav.dart';
import 'package:riderfrontend/adminDashboard/presentation/widgets/admin_shell.dart';
import 'package:riderfrontend/adminDashboard/presentation/widgets/dashboard/create_order_dialog.dart';
import 'package:riderfrontend/adminDashboard/presentation/widgets/dispatch/dispatch_dialogs.dart';
import 'package:riderfrontend/adminDashboard/presentation/widgets/dispatch/dispatch_manifest.dart';
import 'package:riderfrontend/adminDashboard/presentation/widgets/dispatch/dispatch_manifest_preview.dart';
import 'package:riderfrontend/adminDashboard/presentation/widgets/dispatch/dispatch_kpi_row.dart';
import 'package:riderfrontend/adminDashboard/presentation/widgets/dispatch/dispatch_operational_cards.dart';
import 'package:riderfrontend/adminDashboard/presentation/widgets/dispatch/dispatch_order_panel.dart';
import 'package:riderfrontend/adminDashboard/presentation/widgets/dispatch/dispatch_orders_table.dart';
import 'package:riderfrontend/adminDashboard/theme/admin_tokens.dart';
import 'package:riderfrontend/api/route_api.dart';

class DispatchOrdersScreen extends StatefulWidget {
  const DispatchOrdersScreen({
    required this.onNavigate,
    this.session,
    super.key,
  });

  final AuthSession? session;
  final ValueChanged<String> onNavigate;

  @override
  State<DispatchOrdersScreen> createState() => _DispatchOrdersScreenState();
}

class _DispatchOrdersScreenState extends State<DispatchOrdersScreen> {
  static const _pageSize = 10;

  final _search = TextEditingController();
  Timer? _debounce;
  var _started = false;
  var _loading = true;
  var _refreshing = false;
  var _listGeneration = 0;
  var _detailGeneration = 0;
  var _page = 1;
  var _status = 'all';
  var _pickBusy = false;
  var _detailBusy = false;
  String? _openId;
  String? _pickActionError;
  DateTime _date = _today();
  final Map<String, DispatchOrderRow> _selected = {};
  var _manifestBusy = false;

  AdminLoad<DispatchOrderSummary>? _summary;
  AdminLoad<DispatchStatusCounts>? _counts;
  AdminLoad<DispatchOrderPage>? _orders;
  AdminLoad<DispatchOperationalSummary>? _operational;
  AdminLoad<DispatchOrderDetail>? _detail;
  AdminLoad<List<DispatchOrderItem>>? _items;
  AdminLoad<List<DispatchLifecycleEvent>>? _events;
  AdminLoad<DispatchPickList>? _pick;

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

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
    _listGeneration++;
    _detailGeneration++;
    _debounce?.cancel();
    _search.removeListener(_scheduleSearch);
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
    final date = isoDate(_date);
    final query = _search.text.trim();
    if (mounted) setState(() => _refreshing = true);
    final api = ApiScope.of(context);
    final summaryF = guardAdminLoad(
      () => api.dispatchOrdersSummary(from: date, to: date),
    );
    final countsF = guardAdminLoad(
      () => api.dispatchStatusCounts(
        from: date,
        to: date,
        search: query.isEmpty ? null : query,
      ),
    );
    final ordersF = guardAdminLoad(
      () => api.dispatchOrders(
        page: _page,
        pageSize: _pageSize,
        search: query.isEmpty ? null : query,
        status: _status,
        from: date,
        to: date,
      ),
    );
    final operationalF = guardAdminLoad(
      () => api.dispatchOperationalSummary(from: date, to: date),
    );
    final summary = await summaryF;
    final counts = await countsF;
    final orders = await ordersF;
    final operational = await operationalF;
    if (!mounted || generation != _listGeneration) return;
    setState(() {
      _summary = summary;
      _counts = counts;
      _orders = orders;
      _operational = operational;
      _loading = false;
      _refreshing = false;
      final rows = orders.value?.rows ?? const <DispatchOrderRow>[];
      for (final row in rows) {
        if (_selected.containsKey(row.id)) _selected[row.id] = row;
      }
    });
    final open = _openId;
    if (open != null && generation == _listGeneration) {
      await _loadDetail(open);
    }
  }

  Future<void> _loadDetail(String id) async {
    if (id.isEmpty) return;
    final generation = ++_detailGeneration;
    setState(() {
      _openId = id;
      _detailBusy = true;
      _pickActionError = null;
      _pickBusy = false;
      _detail = null;
      _items = null;
      _events = null;
      _pick = null;
    });
    final api = ApiScope.of(context);
    final detailF = guardAdminLoad(() => api.dispatchOrder(id));
    final itemsF = guardAdminLoad(() => api.dispatchOrderItems(id));
    final eventsF = guardAdminLoad(() => api.dispatchOrderLifecycle(id));
    final pickF = guardAdminLoad(() => api.dispatchOrderPickList(id));
    final detail = await detailF;
    final items = await itemsF;
    final events = await eventsF;
    final pick = await pickF;
    if (!mounted || generation != _detailGeneration || _openId != id) return;
    setState(() {
      _detail = detail;
      _items = items;
      _events = events;
      _pick = pick;
      _detailBusy = false;
    });
  }

  String get _assignLabel {
    final orders = _selected.values;
    if (orders.isEmpty || orders.every((row) => !row.hasRider)) return 'Assign Rider';
    if (orders.every((row) => row.hasRider)) return 'Reassign Rider';
    return 'Assign / Reassign';
  }

  Future<void> _assignSelected() async {
    final orders = _selected.values.toList();
    if (orders.isEmpty) return;
    final notice = await showDispatchAssignmentDialog(context, orders: orders);
    if (!mounted || notice == null || notice.trim().isEmpty) return;
    showAdminNotice(context, notice);
    await _reload();
  }

  Future<void> _manifest({required bool download}) async {
    final orders = _selected.values.toList();
    if (orders.isEmpty || _manifestBusy) return;
    setState(() => _manifestBusy = true);
    final api = ApiScope.of(context);
    final sheets = <DispatchManifestSheet>[];
    for (final order in orders) {
      final items = await guardAdminLoad(() => api.dispatchOrderItems(order.id));
      if (!mounted) return;
      sheets.add(
        DispatchManifestSheet(
          order: order,
          lines: items.value ?? const [],
          linesError: items.failed ? items.error : null,
        ),
      );
    }
    final dateLabel = formatAdminDay(_date);
    setState(() => _manifestBusy = false);
    if (!mounted) return;
    if (download) {
      try {
        final bytes = await buildDispatchManifestPdf(sheets, dateLabel: dateLabel);
        await DispatchManifestPublisher.current.download(
          bytes,
          dispatchManifestFilename(dateLabel),
        );
        if (!mounted) return;
        showAdminNotice(context, 'Manifest downloaded.');
      } catch (error) {
        if (!mounted) return;
        showAdminNotice(context, '$error'.replaceFirst('Exception: ', '').trim());
      }
      return;
    }
    await showDispatchManifestPreview(context, sheets: sheets, dateLabel: dateLabel);
  }

  void _closeDetail() {
    _detailGeneration++;
    setState(() {
      _openId = null;
      _detail = null;
      _items = null;
      _events = null;
      _pick = null;
      _pickActionError = null;
      _pickBusy = false;
      _detailBusy = false;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _date = DateTime(picked.year, picked.month, picked.day);
      _page = 1;
    });
    await _reload();
  }

  void _clearFilters() {
    _debounce?.cancel();
    _search.removeListener(_scheduleSearch);
    _search.clear();
    _search.addListener(_scheduleSearch);
    setState(() {
      _status = 'all';
      _date = _today();
      _page = 1;
      _selected.clear();
    });
    _reload();
  }

  void _setStatus(String value) {
    if (value == _status) return;
    setState(() {
      _status = value;
      _page = 1;
    });
    _reload();
  }

  Future<void> _cancel() async {
    final id = _openId;
    if (id == null) return;
    final reason = await showDispatchCancelDialog(context);
    if (reason == null || !mounted) return;
    try {
      final result = await ApiScope.of(context).dispatchCancelOrder(
        id,
        reason: reason,
      );
      if (!mounted) return;
      showAdminNotice(context, result.notice);
      await _reload();
    } on ApiException catch (error) {
      if (!mounted) return;
      showAdminNotice(
        context,
        error.message.trim().isEmpty
            ? 'The order could not be cancelled.'
            : error.message.trim(),
      );
    } catch (_) {
      if (!mounted) return;
      showAdminNotice(context, adminUnreachableMessage);
    }
  }

  Future<void> _reassign() async {
    final id = _openId;
    if (id == null) return;
    final api = ApiScope.of(context);
    final message = await showDialog<String>(
      context: context,
      builder: (context) => ApiScope(
        api: api,
        child: DispatchReassignDialog(orderId: id),
      ),
    );
    if (message == null || !mounted) return;
    showAdminNotice(context, message);
    await _reload();
  }

  Future<void> _preparePickList() async {
    final id = _openId;
    if (id == null || _pickBusy) return;
    final generation = _detailGeneration;
    setState(() {
      _pickBusy = true;
      _pickActionError = null;
    });
    try {
      final result = await ApiScope.of(context).dispatchPreparePickList(id);
      if (!mounted || _openId != id || generation != _detailGeneration) return;
      setState(() {
        _pick = AdminLoad.ok(result);
        _pickBusy = false;
      });
      // Lifecycle changes on prepare; reload so the drawer is not stale.
      await _loadDetail(id);
    } on ApiException catch (error) {
      if (!mounted || _openId != id || generation != _detailGeneration) return;
      setState(() {
        _pickBusy = false;
        _pickActionError = error.message.trim().isEmpty
            ? 'Pick-list could not be prepared.'
            : error.message.trim();
      });
    } catch (_) {
      if (!mounted || _openId != id || generation != _detailGeneration) return;
      setState(() {
        _pickBusy = false;
        _pickActionError = adminUnreachableMessage;
      });
    }
  }

  DispatchOrderRow? get _openRow {
    final rows = _orders?.value?.rows ?? const <DispatchOrderRow>[];
    for (final row in rows) {
      if (row.id == _openId) return row;
    }
    return null;
  }

  bool get _detailLoading => _openId != null && _detailBusy;

  void _notice(String message) {
    showAdminNotice(context, message);
  }

  Future<void> _createOrder() async {
    final created = await showDialog<AdminOrderResult>(
      context: context,
      builder: (context) => const CreateOrderDialog(),
    );
    if (created == null || !mounted) return;
    showAdminNotice(context, created.notice);
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final loads = <AdminLoad<dynamic>>[
      ?_summary,
      ?_counts,
      ?_orders,
      ?_operational,
    ];
    final banner = adminErrorBanner(loads);
    return AdminShell(
      screenKey: const Key('dispatch-orders-screen'),
      activeKey: AdminNav.dispatch,
      session: widget.session,
      serverReachable: adminServerReachable(loads),
      search: _search,
      onSearch: (_) {},
      searchHint: 'Search order, customer, or rider',
      onNavigate: widget.onNavigate,
      trailing: IconButton(
        key: const Key('dispatch-refresh'),
        tooltip: 'Refresh',
        onPressed: _reload,
        icon: const Icon(Icons.refresh, color: AdminTokens.secondary),
      ),
      body: _loading
          ? const AdminLoadingPane(label: 'Loading dispatch orders…')
          : LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 960;
                if (!wide && _openId != null) {
                  return _panel(fullscreen: true);
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _pageBody(banner)),
                    if (wide && _openId != null)
                      SizedBox(
                        width: constraints.maxWidth * 0.4,
                        child: DecoratedBox(
                          decoration: const BoxDecoration(
                            border: Border(
                              left: BorderSide(color: AdminTokens.line),
                            ),
                          ),
                          child: _panel(),
                        ),
                      ),
                  ],
                );
              },
            ),
    );
  }

  Widget _pageBody(String? banner) {
    final page = _orders?.value;
    final label = dispatchPageLabel(
      page: page?.page ?? _page,
      pageSize: page?.pageSize ?? _pageSize,
      rowCount: page?.rows.length ?? 0,
      totalRecords: page?.totalRecords,
      totalPages: page?.totalPages,
    );
    final hasNext = page != null &&
        (page.totalPages != null
            ? (page.page) < (page.totalPages!)
            : page.rows.length >= page.pageSize);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      children: [
        _Header(
          onCreateOrder: _createOrder,
          onNotice: _notice,
          onSchedules: () => widget.onNavigate(AdminNav.recurringSchedules),
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
        DispatchKpiRow(
          summary: _summary?.value,
          failed: _summary?.failed == true,
        ),
        const SizedBox(height: 16),
        DispatchOrdersTable(
          counts: _counts?.value,
          countsFailed: _counts?.failed == true,
          status: _status,
          onStatus: _setStatus,
          search: _search,
          dateLabel: formatAdminDay(_date),
          onPickDate: _pickDate,
          onClear: _clearFilters,
          rows: page?.rows ?? const [],
          ordersFailed: _orders?.failed == true,
          selected: {
            for (final row in _selected.values) row.id: row.estimatedValue,
          },
          assignLabel: _assignLabel,
          onAssignRider: _assignSelected,
          onPrintManifest: () => _manifest(download: false),
          onExportSelected: () => _manifest(download: true),
          onToggle: (row, selected) {
            setState(() {
              if (selected) {
                _selected[row.id] = row;
              } else {
                _selected.remove(row.id);
              }
            });
          },
          onOpen: _loadDetail,
          openId: _openId,
          pageLabel: label,
          loading: _refreshing,
          onPrevious: _page > 1
              ? () {
                  setState(() => _page -= 1);
                  _reload();
                }
              : null,
          onNext: hasNext
              ? () {
                  setState(() => _page += 1);
                  _reload();
                }
              : null,
          onClearSelection: () => setState(_selected.clear),
        ),
        const SizedBox(height: 16),
        DispatchOperationalSection(
          summary: _operational?.value,
          failed: _operational?.failed == true,
        ),
      ],
    );
  }

  Widget _panel({bool fullscreen = false}) {
    final detail = _detail?.value;
    final row = _openRow;
    // While a detail fetch is in flight, do not paint the previous order's
    // hydrated fields (notes/phone/items/events). List-row identity is OK.
    final loading = _detailLoading;
    final order = loading ? row : (detail?.order ?? row);
    final itemLines = loading
        ? const <DispatchOrderItem>[]
        : (_items != null && _items!.failed
            ? (detail?.items ?? const <DispatchOrderItem>[])
            : (_items?.value ?? const <DispatchOrderItem>[]));
    final events = loading
        ? const <DispatchLifecycleEvent>[]
        : (_events != null && _events!.failed
            ? (detail?.events ?? const <DispatchLifecycleEvent>[])
            : (_events?.value ?? const <DispatchLifecycleEvent>[]));
    final status = order?.status ?? '';
    return DispatchOrderPanel(
      fullscreen: fullscreen,
      reference: order?.displayReference ?? 'Order',
      orderId: order?.id ?? '',
      loading: loading,
      onClose: _closeDetail,
      customerName: order?.customerName ?? '',
      customerCode: order?.customerCode ?? '',
      address: order?.address ?? '',
      scheduledDate: order?.scheduledDate ?? '',
      timeWindow: order?.timeWindow ?? '',
      riderName: order?.riderName ?? '',
      riderCode: order?.riderCode ?? '',
      scheduledByRider: order?.scheduledByRider ?? false,
      vehicleName: loading ? '' : (detail?.vehicleName ?? ''),
      phone: loading ? '' : (detail?.phone ?? ''),
      status: status,
      estimatedValue: order?.estimatedValue,
      notes: loading ? null : detail?.notes,
      detailError: !loading && _detail?.failed == true ? _detail!.error : null,
      items: itemLines,
      itemsError: !loading && _items?.failed == true && itemLines.isEmpty
          ? _items!.error
          : null,
      events: events,
      eventsError: !loading && _events?.failed == true && events.isEmpty
          ? _events!.error
          : null,
      pickLines: loading ? const [] : (_pick?.value?.lines ?? const []),
      pickMessage: loading ? null : _pick?.value?.message,
      pickError: loading
          ? null
          : (_pickActionError ??
              (_pick?.failed == true ? _pick!.error : null)),
      pickBusy: _pickBusy,
      closed: dispatchStatusIsClosed(status),
      onCancel: loading ? null : _cancel,
      onReassign: loading ? null : _reassign,
      onPreparePickList: loading ? null : _preparePickList,
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.onCreateOrder,
    required this.onNotice,
    required this.onSchedules,
  });

  final VoidCallback onCreateOrder;
  final ValueChanged<String> onNotice;
  final VoidCallback onSchedules;

  @override
  Widget build(BuildContext context) {
    final actions = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          onPressed: () => onNotice(
            'Order export is not available on this server yet.',
          ),
          style: adminOutlineButton(),
          icon: const Icon(Icons.upload_outlined, size: 16),
          label: const Text('Export Orders (CSV)'),
        ),
        OutlinedButton.icon(
          onPressed: () =>
              onNotice('ERP sync is not available on this server yet.'),
          style: adminOutlineButton(),
          icon: const Icon(Icons.sync, size: 16),
          label: const Text('Sync ERP'),
        ),
        OutlinedButton.icon(
          key: const Key('open-recurring-schedules'),
          onPressed: onSchedules,
          style: adminOutlineButton(),
          icon: const Icon(Icons.event_repeat_outlined, size: 16),
          label: const Text('Recurring Schedules'),
        ),
        FilledButton.icon(
          onPressed: onCreateOrder,
          style: FilledButton.styleFrom(
            backgroundColor: AdminTokens.button,
            foregroundColor: Colors.white,
            elevation: 0,
            minimumSize: const Size(0, 40),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            textStyle: adminType(13, FontWeight.w700, Colors.white),
          ),
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Create Order'),
        ),
      ],
    );
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Field Operations  ›  Dispatch & Orders',
          style: adminType(
            12,
            FontWeight.w600,
            AdminTokens.textSecondary,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Dispatch & Order Management',
          style: adminType(28, FontWeight.w700, AdminTokens.text, height: 1.1),
        ),
        const SizedBox(height: 6),
        Text(
          'Manage scheduled deliveries, fleet allocations, rider manifests, and fulfillment ledgers.',
          style: adminType(
            14,
            FontWeight.w500,
            AdminTokens.textSecondary,
            height: 1.4,
          ),
        ),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 860) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [copy, const SizedBox(height: 14), actions],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: copy),
            const SizedBox(width: 16),
            actions,
          ],
        );
      },
    );
  }
}
