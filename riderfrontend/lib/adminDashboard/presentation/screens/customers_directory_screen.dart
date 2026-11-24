import 'dart:async';

import 'package:flutter/material.dart';

import 'package:riderfrontend/adminDashboard/data/admin_format.dart';
import 'package:riderfrontend/adminDashboard/presentation/admin_load.dart';
import 'package:riderfrontend/adminDashboard/presentation/admin_nav.dart';
import 'package:riderfrontend/adminDashboard/presentation/widgets/admin_shell.dart';
import 'package:riderfrontend/adminDashboard/presentation/widgets/static_pins_map.dart';
import 'package:riderfrontend/adminDashboard/theme/admin_tokens.dart';
import 'package:riderfrontend/api/route_api.dart';

class CustomersDirectoryScreen extends StatefulWidget {
  const CustomersDirectoryScreen({
    required this.onNavigate,
    this.session,
    super.key,
  });

  final AuthSession? session;
  final ValueChanged<String> onNavigate;

  @override
  State<CustomersDirectoryScreen> createState() =>
      _CustomersDirectoryScreenState();
}

class _CustomersDirectoryScreenState extends State<CustomersDirectoryScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  var _started = false;
  var _loading = true;
  var _page = 1;
  var _status = 'all';
  var _outstandingOnly = false;
  String? _routeId;
  String? _selectedId;

  AdminLoad<AdminCustomersSummary>? _summary;
  AdminLoad<AdminCustomerPage>? _pageData;
  AdminLoad<AdminCustomerDetail>? _detail;
  AdminLoad<List<RouteListItem>>? _routes;

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
    _debounce?.cancel();
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
    setState(() => _loading = true);
    final api = ApiScope.of(context);
    final summary = await guardAdminLoad(api.adminCustomersSummary);
    final routes = await guardAdminLoad(() => api.listRoutes());
    final page = await guardAdminLoad(
      () => api.adminCustomers(
        search: _search.text.trim().isEmpty ? null : _search.text.trim(),
        status: _status == 'all' ? null : _status,
        routeId: _routeId,
        withOutstanding: _outstandingOnly ? true : null,
        page: _page,
        pageSize: 20,
      ),
    );
    if (!mounted) return;
    final rows = page.value?.rows ?? const <AdminCustomerRow>[];
    var selected = _selectedId;
    if (selected == null || !rows.any((item) => item.id == selected)) {
      selected = rows.isEmpty ? null : rows.first.id;
    }
    AdminLoad<AdminCustomerDetail>? detail;
    if (selected != null) {
      detail = await guardAdminLoad(() => api.adminCustomerDetail(selected!));
    }
    if (!mounted) return;
    setState(() {
      _summary = summary;
      _routes = routes;
      _pageData = page;
      _selectedId = selected;
      _detail = detail;
      _loading = false;
    });
  }

  Future<void> _select(String id) async {
    setState(() => _selectedId = id);
    final detail = await guardAdminLoad(
      () => ApiScope.of(context).adminCustomerDetail(id),
    );
    if (!mounted) return;
    setState(() => _detail = detail);
  }

  Future<void> _changeRoute() async {
    final detail = _detail?.value;
    final routes = _routes?.value ?? detail?.availableRoutes ?? const <RouteListItem>[];
    if (detail == null || routes.isEmpty) return;
    final chosen = await showDialog<RouteListItem>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Change route assignment'),
        children: [
          for (final route in routes)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, route),
              child: Text('${route.name} · ${route.zoneName}'),
            ),
        ],
      ),
    );
    if (chosen == null || !mounted) return;
    try {
      final api = ApiScope.of(context);
      await api.adminChangeCustomerRoute(
        detail.customer.id,
        routeId: chosen.id,
      );
      if (!mounted) return;
      showAdminNotice(context, 'Route assignment updated.');
      await _reload();
    } on ApiException catch (error) {
      if (mounted) showAdminNotice(context, error.message);
    }
  }

  Future<void> _setStatus(String status) async {
    final id = _selectedId;
    if (id == null) return;
    try {
      final api = ApiScope.of(context);
      await api.adminSetCustomerStatus(id, status: status);
      if (!mounted) return;
      showAdminNotice(context, 'Customer status updated.');
      await _reload();
    } on ApiException catch (error) {
      if (mounted) showAdminNotice(context, error.message);
    }
  }

  Future<void> _createCustomer() async {
    final routes = _routes?.value ?? const <RouteListItem>[];
    if (routes.isEmpty) {
      showAdminNotice(context, 'Create a route before adding customers.');
      return;
    }
    final name = TextEditingController();
    final phone = TextEditingController();
    final street = TextEditingController();
    final area = TextEditingController(text: 'Satellite Town');
    final city = TextEditingController(text: 'Rawalpindi');
    var routeId = routes.first.id;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Add customer'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Store name'),
                  ),
                  TextField(
                    controller: phone,
                    decoration: const InputDecoration(labelText: 'Primary mobile'),
                  ),
                  TextField(
                    controller: street,
                    decoration: const InputDecoration(labelText: 'Street'),
                  ),
                  TextField(
                    controller: area,
                    decoration: const InputDecoration(labelText: 'Area'),
                  ),
                  TextField(
                    controller: city,
                    decoration: const InputDecoration(labelText: 'City'),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: routeId,
                    decoration: const InputDecoration(labelText: 'Route'),
                    items: [
                      for (final route in routes)
                        DropdownMenuItem(
                          value: route.id,
                          child: Text(route.name),
                        ),
                    ],
                    onChanged: (value) =>
                        setLocal(() => routeId = value ?? routeId),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
    final payload = (
      name.text.trim(),
      phone.text.trim(),
      street.text.trim(),
      area.text.trim(),
      city.text.trim(),
      routeId,
    );
    name.dispose();
    phone.dispose();
    street.dispose();
    area.dispose();
    city.dispose();
    if (ok != true || !mounted) return;
    if (payload.$1.isEmpty || payload.$2.isEmpty || payload.$3.isEmpty) {
      showAdminNotice(context, 'Name, phone, and street are required.');
      return;
    }
    try {
      final created = await ApiScope.of(context).adminCreateCustomer(
        businessName: payload.$1,
        primaryMobile: payload.$2,
        category: 'Retail Store',
        street: payload.$3,
        area: payload.$4,
        city: payload.$5,
        routeId: payload.$6,
        bottleOwnership: 'Rented',
      );
      if (!mounted) return;
      setState(() => _selectedId = created.customer.id);
      showAdminNotice(context, 'Customer created.');
      await _reload();
    } on ApiException catch (error) {
      if (mounted) showAdminNotice(context, error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loads = <AdminLoad<dynamic>>[?_summary, ?_pageData, ?_detail];
    final summary = _summary?.value;
    final page = _pageData?.value;
    final detail = _detail?.value;
    final routes = _routes?.value ?? const <RouteListItem>[];

    return AdminShell(
      screenKey: const Key('customers-directory-screen'),
      session: widget.session,
      activeKey: AdminNav.customersParties,
      serverReachable: adminServerReachable(loads),
      search: _search,
      onSearch: (_) {},
      searchHint: 'Search code, store, phone, area',
      onNavigate: widget.onNavigate,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton.icon(
            onPressed: _loading ? null : _createCustomer,
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text('Add customer'),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _reload,
            icon: const Icon(Icons.refresh, color: AdminTokens.secondary),
          ),
        ],
      ),
      body: _loading && _summary == null
          ? const AdminLoadingPane(label: 'Loading customers…')
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
              children: [
                Text(
                  'Business Management  ›  Customers & Parties',
                  style: adminType(
                    12,
                    FontWeight.w600,
                    AdminTokens.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Customers & Parties Directory',
                  style: adminType(
                    28,
                    FontWeight.w700,
                    AdminTokens.text,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Browse SQL-backed merchant accounts, outstanding balances, bottle holdings, and route assignment.',
                  style: adminType(
                    14,
                    FontWeight.w500,
                    AdminTokens.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _Kpi('Total', '${summary?.totalCustomers ?? 0}', 'All accounts'),
                    _Kpi('Active', '${summary?.activeCustomers ?? 0}', 'Delivery-ready'),
                    _Kpi(
                      'Inactive / Hold',
                      '${summary?.inactiveCustomers ?? 0}',
                      'Not currently active',
                    ),
                    _Kpi(
                      'New this month',
                      '${summary?.newThisMonth ?? 0}',
                      'Created in UTC month',
                    ),
                    _Kpi(
                      'Outstanding',
                      formatPkr(summary?.totalOutstanding ?? 0),
                      '${summary?.withOutstanding ?? 0} with balance',
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    DropdownButton<String>(
                      value: _status,
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('All statuses')),
                        DropdownMenuItem(value: 'Active', child: Text('Active')),
                        DropdownMenuItem(value: 'Inactive', child: Text('Inactive')),
                        DropdownMenuItem(value: 'On-Hold', child: Text('On-Hold')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _status = value ?? 'all';
                          _page = 1;
                        });
                        _reload();
                      },
                    ),
                    DropdownButton<String?>(
                      value: _routeId,
                      hint: const Text('All routes'),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('All routes'),
                        ),
                        for (final route in routes)
                          DropdownMenuItem(
                            value: route.id,
                            child: Text(route.name),
                          ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _routeId = value;
                          _page = 1;
                        });
                        _reload();
                      },
                    ),
                    FilterChip(
                      label: const Text('With outstanding'),
                      selected: _outstandingOnly,
                      onSelected: (value) {
                        setState(() {
                          _outstandingOnly = value;
                          _page = 1;
                        });
                        _reload();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 1100;
                    final table = _CustomerTable(
                      rows: page?.rows ?? const [],
                      selectedId: _selectedId,
                      onSelect: _select,
                      page: page?.page ?? 1,
                      totalPages: page?.totalPages ?? 1,
                      totalRecords: page?.totalRecords ?? 0,
                      onPrev: _page <= 1
                          ? null
                          : () {
                              setState(() => _page -= 1);
                              _reload();
                            },
                      onNext: page == null || _page >= page.totalPages
                          ? null
                          : () {
                              setState(() => _page += 1);
                              _reload();
                            },
                    );
                    final drawer = _CustomerDrawer(
                      detail: detail,
                      onChangeRoute: _changeRoute,
                      onDeactivate: () => _setStatus('Inactive'),
                      onActivate: () => _setStatus('Active'),
                      onHold: () => _setStatus('On-Hold'),
                    );
                    if (wide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 3, child: table),
                          const SizedBox(width: 14),
                          Expanded(flex: 2, child: drawer),
                        ],
                      );
                    }
                    return Column(
                      children: [
                        table,
                        const SizedBox(height: 14),
                        drawer,
                      ],
                    );
                  },
                ),
              ],
            ),
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi(this.label, this.value, this.hint);

  final String label;
  final String value;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AdminTokens.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminTokens.line),
        boxShadow: AdminTokens.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: adminType(12, FontWeight.w600, AdminTokens.textSecondary),
          ),
          const SizedBox(height: 6),
          Text(value, style: adminType(18, FontWeight.w700, AdminTokens.text)),
          const SizedBox(height: 4),
          Text(
            hint,
            style: adminType(11, FontWeight.w500, AdminTokens.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _CustomerTable extends StatelessWidget {
  const _CustomerTable({
    required this.rows,
    required this.selectedId,
    required this.onSelect,
    required this.page,
    required this.totalPages,
    required this.totalRecords,
    required this.onPrev,
    required this.onNext,
  });

  final List<AdminCustomerRow> rows;
  final String? selectedId;
  final ValueChanged<String> onSelect;
  final int page;
  final int totalPages;
  final int totalRecords;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AdminTokens.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminTokens.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Directory',
                  style: adminType(15, FontWeight.w700, AdminTokens.text),
                ),
              ),
              Text(
                '$totalRecords records · page $page / $totalPages',
                style: adminType(12, FontWeight.w500, AdminTokens.textSecondary),
              ),
              IconButton(onPressed: onPrev, icon: const Icon(Icons.chevron_left)),
              IconButton(onPressed: onNext, icon: const Icon(Icons.chevron_right)),
            ],
          ),
          const SizedBox(height: 8),
          if (rows.isEmpty)
            Text(
              'No customers matched these filters.',
              style: adminType(13, FontWeight.w500, AdminTokens.textSecondary),
            )
          else
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: row.id == selectedId
                      ? AdminTokens.primarySoft
                      : AdminTokens.field,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => onSelect(row.id),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  row.businessName,
                                  style: adminType(
                                    13,
                                    FontWeight.w700,
                                    AdminTokens.text,
                                  ),
                                ),
                                Text(
                                  '${row.code} · ${row.category} · ${row.status}',
                                  style: adminType(
                                    11,
                                    FontWeight.w500,
                                    AdminTokens.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              row.routeName,
                              style: adminType(
                                12,
                                FontWeight.w500,
                                AdminTokens.textSecondary,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 110,
                            child: Text(
                              formatPkr(row.outstanding),
                              textAlign: TextAlign.right,
                              style: adminType(
                                12,
                                FontWeight.w700,
                                row.outstanding > 0
                                    ? AdminTokens.warning
                                    : AdminTokens.text,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _CustomerDrawer extends StatelessWidget {
  const _CustomerDrawer({
    required this.detail,
    required this.onChangeRoute,
    required this.onDeactivate,
    required this.onActivate,
    required this.onHold,
  });

  final AdminCustomerDetail? detail;
  final VoidCallback onChangeRoute;
  final VoidCallback onDeactivate;
  final VoidCallback onActivate;
  final VoidCallback onHold;

  @override
  Widget build(BuildContext context) {
    if (detail == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AdminTokens.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AdminTokens.line),
        ),
        child: Text(
          'Select a customer to inspect details and ledger activity.',
          style: adminType(13, FontWeight.w500, AdminTokens.textSecondary),
        ),
      );
    }

    final customer = detail!.customer;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdminTokens.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminTokens.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            customer.businessName,
            style: adminType(18, FontWeight.w700, AdminTokens.text),
          ),
          const SizedBox(height: 4),
          Text(
            '${customer.code} · ${customer.status} · ${customer.category}',
            style: adminType(12, FontWeight.w500, AdminTokens.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            '${customer.address}, ${customer.city}',
            style: adminType(12, FontWeight.w500, AdminTokens.textSecondary),
          ),
          Text(
            customer.phone,
            style: adminType(12, FontWeight.w500, AdminTokens.textSecondary),
          ),
          const SizedBox(height: 10),
          Text(
            'Route: ${customer.routeName}'
            '${customer.zoneName == null ? '' : ' · ${customer.zoneName}'}',
            style: adminType(12, FontWeight.w600, AdminTokens.text),
          ),
          Text(
            'Outstanding ${formatPkr(customer.outstanding)} · Bottles held ${customer.bottlesHeld}',
            style: adminType(12, FontWeight.w500, AdminTokens.textSecondary),
          ),
          Text(
            'Lifetime sales ${formatPkr(detail!.lifetimeSales)} · Collections ${formatPkr(detail!.lifetimeCollections)}',
            style: adminType(12, FontWeight.w500, AdminTokens.textSecondary),
          ),
          const SizedBox(height: 12),
          StaticPinsMap(
            height: 180,
            emptyLabel: 'No GPS pin captured for this customer.',
            pins: customer.hasGps &&
                    customer.latitude != null &&
                    customer.longitude != null
                ? [
                    StaticMapPin(
                      latitude: customer.latitude!.toDouble(),
                      longitude: customer.longitude!.toDouble(),
                      label: customer.businessName,
                      highlighted: true,
                    ),
                  ]
                : const [],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: onChangeRoute,
                child: const Text('Change route'),
              ),
              OutlinedButton(
                onPressed: onActivate,
                child: const Text('Activate'),
              ),
              OutlinedButton(
                onPressed: onHold,
                child: const Text('On-Hold'),
              ),
              OutlinedButton(
                onPressed: onDeactivate,
                child: const Text('Deactivate'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Recent ledger',
            style: adminType(14, FontWeight.w700, AdminTokens.text),
          ),
          const SizedBox(height: 8),
          if (detail!.recentLedger.isEmpty)
            Text(
              'No ledger entries yet.',
              style: adminType(12, FontWeight.w500, AdminTokens.textSecondary),
            )
          else
            for (final entry in detail!.recentLedger)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.description,
                            style: adminType(
                              12,
                              FontWeight.w700,
                              AdminTokens.text,
                            ),
                          ),
                          Text(
                            '${entry.kind}${entry.reference == null ? '' : ' · ${entry.reference}'} · ${formatAdminStamp(entry.occurredAt)}',
                            style: adminType(
                              11,
                              FontWeight.w500,
                              AdminTokens.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      formatPkr(entry.amount),
                      style: adminType(
                        12,
                        FontWeight.w700,
                        entry.amount < 0
                            ? AdminTokens.success
                            : AdminTokens.text,
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
