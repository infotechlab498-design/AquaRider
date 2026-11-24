import 'package:flutter/material.dart';

import 'package:riderfrontend/api/office_document.dart';

import 'package:riderfrontend/adminDashboard/data/admin_format.dart';
import 'package:riderfrontend/adminDashboard/presentation/admin_load.dart';
import 'package:riderfrontend/adminDashboard/presentation/admin_nav.dart';
import 'package:riderfrontend/adminDashboard/presentation/widgets/admin_shell.dart';
import 'package:riderfrontend/adminDashboard/theme/admin_tokens.dart';
import 'package:riderfrontend/api/route_api.dart';

class RouteManifestsScreen extends StatefulWidget {
  const RouteManifestsScreen({required this.onNavigate, this.session, super.key});

  final AuthSession? session;
  final ValueChanged<String> onNavigate;

  @override
  State<RouteManifestsScreen> createState() => _RouteManifestsScreenState();
}

class _RouteManifestsScreenState extends State<RouteManifestsScreen> {
  final _search = TextEditingController();
  var _started = false;
  var _loading = true;
  var _stopsBusy = false;
  String? _selectedId;
  DateTime _date = _today();

  AdminLoad<List<RouteListItem>>? _routes;
  AdminLoad<List<RouteStopRow>>? _stops;

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
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final search = _search.text.trim().isEmpty ? null : _search.text.trim();
    final routes = await guardAdminLoad(
      () => ApiScope.of(context).listRoutes(search: search),
    );
    if (!mounted) return;
    final rows = routes.value ?? const <RouteListItem>[];
    final keep = _selectedId != null && rows.any((row) => row.id == _selectedId)
        ? _selectedId
        : (rows.isEmpty ? null : rows.first.id);
    setState(() {
      _routes = routes;
      _selectedId = keep;
      _loading = false;
      if (keep == null) _stops = null;
    });
    if (keep != null) await _loadStops(keep);
  }

  Future<void> _loadStops(String routeId) async {
    setState(() => _stopsBusy = true);
    final stops = await guardAdminLoad(
      () => ApiScope.of(context).routeStops(routeId, date: _dateIso),
    );
    if (!mounted) return;
    setState(() {
      _stops = stops;
      _stopsBusy = false;
    });
  }

  Future<void> _printManifest() async {
    final id = _selectedId;
    if (id == null) return;
    try {
      final file = await ApiScope.of(context).manifestPdf(routeId: id, date: _dateIso);
      if (!mounted) return;
      if (file.contentBase64.isEmpty) {
        showAdminNotice(context, 'The manifest PDF could not be created.');
        return;
      }
      showAdminNotice(context, file.fileName);
      await shareOfficeDocument(file);
    } on ApiException catch (error) {
      if (!mounted) return;
      showAdminNotice(context, error.message);
    } catch (_) {
      if (!mounted) return;
      showAdminNotice(context, 'The manifest PDF could not be created.');
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 14)),
    );
    if (picked == null) return;
    setState(() => _date = DateTime(picked.year, picked.month, picked.day));
    final id = _selectedId;
    if (id != null) await _loadStops(id);
  }

  Future<void> _buildStops() async {
    final id = _selectedId;
    if (id == null) {
      showAdminNotice(context, 'Select a route first.');
      return;
    }
    setState(() => _stopsBusy = true);
    try {
      final stops = await ApiScope.of(context).ensureRouteStops(id, date: _dateIso);
      if (!mounted) return;
      setState(() => _stops = AdminLoad.ok(stops));
      showAdminNotice(context, 'Day stops were built from the route customers.');
      await _reload();
    } on ApiException catch (error) {
      if (mounted) showAdminNotice(context, error.message);
    } catch (_) {
      if (mounted) showAdminNotice(context, adminUnreachableMessage);
    } finally {
      if (mounted) setState(() => _stopsBusy = false);
    }
  }

  Future<void> _move(RouteStopRow stop, int delta) async {
    final id = _selectedId;
    final items = List<RouteStopRow>.of(_stops?.value ?? const []);
    final index = items.indexWhere((row) => row.id == stop.id);
    final next = index + delta;
    if (id == null || index < 0 || next < 0 || next >= items.length) return;
    final moved = items.removeAt(index);
    items.insert(next, moved);
    setState(() => _stopsBusy = true);
    try {
      final updated = await ApiScope.of(context).sequenceRouteStops(
        id,
        orderedStopIds: [for (final row in items) row.id],
      );
      if (!mounted) return;
      setState(() => _stops = AdminLoad.ok(updated));
    } on ApiException catch (error) {
      if (mounted) showAdminNotice(context, error.message);
    } catch (_) {
      if (mounted) showAdminNotice(context, adminUnreachableMessage);
    } finally {
      if (mounted) setState(() => _stopsBusy = false);
    }
  }

  ButtonStyle _button() {
    return FilledButton.styleFrom(
      backgroundColor: AdminTokens.button,
      foregroundColor: Colors.white,
      elevation: 0,
      minimumSize: const Size(0, 40),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final routes = _routes?.value ?? const <RouteListItem>[];
    final wide = MediaQuery.sizeOf(context).width >= 1180;
    return AdminShell(
      screenKey: const Key('route-manifests-screen'),
      session: widget.session,
      activeKey: AdminNav.manifests,
      serverReachable: adminServerReachable([?_routes, ?_stops]),
      search: _search,
      onSearch: (_) => _reload(),
      searchHint: 'Search route, zone or rider…',
      onNavigate: widget.onNavigate,
      trailing: IconButton(
        tooltip: 'Refresh',
        onPressed: _loading ? null : _reload,
        icon: const Icon(Icons.refresh, color: AdminTokens.secondary),
      ),
      body: _loading && _routes == null
          ? const AdminLoadingPane(label: 'Loading route manifests…')
          : ListView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              children: [
                _header(),
                const SizedBox(height: 16),
                if (_routes?.error != null && _routes?.value == null)
                  _error(_routes!.error!)
                else ...[
                  _kpis(routes),
                  const SizedBox(height: 16),
                  if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 4, child: _routeList(routes)),
                        const SizedBox(width: 16),
                        Expanded(flex: 6, child: _stopsPane()),
                      ],
                    )
                  else ...[
                    _routeList(routes),
                    const SizedBox(height: 16),
                    _stopsPane(),
                  ],
                ],
              ],
            ),
    );
  }

  Widget _header() {
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Operations  ›  Route Manifests',
          style: adminType(12, FontWeight.w600, AdminTokens.textSecondary),
        ),
        const SizedBox(height: 6),
        Text(
          'Route Manifests',
          style: adminType(26, FontWeight.w700, AdminTokens.text, height: 1.2),
        ),
        const SizedBox(height: 6),
        Text(
          'Stops saved for the selected service date, built from the customers on each route.',
          style: adminType(13.5, FontWeight.w500, AdminTokens.textSecondary),
        ),
        if (_routes?.error != null) ...[
          const SizedBox(height: 6),
          Text(
            _routes!.error!,
            style: adminType(12.5, FontWeight.w600, const Color(0xFFC62828)),
          ),
        ],
      ],
    );
    final actions = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          key: const Key('route-manifests-date'),
          onPressed: _pickDate,
          icon: const Icon(Icons.calendar_today_outlined, size: 16),
          label: Text(formatAdminDay(_date)),
        ),
        OutlinedButton(
          key: const Key('route-manifests-print'),
          onPressed: _selectedId == null ? null : _printManifest,
          child: const Text('Print'),
        ),
        FilledButton(
          key: const Key('route-manifests-build'),
          style: _button(),
          onPressed: _selectedId == null || _stopsBusy ? null : _buildStops,
          child: const Text('Build day stops'),
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

  Widget _kpis(List<RouteListItem> routes) {
    final withRider = routes.where((row) => row.hasRider).length;
    final customers = routes.fold<int>(0, (sum, row) => sum + row.customerCount);
    final todayStops = routes.fold<int>(0, (sum, row) => sum + row.stopCountToday);
    final cards = [
      _kpi('Routes', '${routes.length}'),
      _kpi('Routes with a rider', '$withRider'),
      _kpi('Customers on these routes', '$customers'),
      _kpi('Stops recorded today', '$todayStops'),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 900) {
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [for (final card in cards) SizedBox(width: 220, child: card)],
          );
        }
        return Row(
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              Expanded(child: cards[i]),
            ],
          ],
        );
      },
    );
  }

  Widget _kpi(String title, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminTokens.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: adminType(12, FontWeight.w600, AdminTokens.textSecondary)),
          const SizedBox(height: 8),
          Text(value, style: adminType(26, FontWeight.w700, AdminTokens.text)),
        ],
      ),
    );
  }

  Widget _routeList(List<RouteListItem> routes) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminTokens.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Routes', style: adminType(16, FontWeight.w700, AdminTokens.text)),
          const SizedBox(height: 12),
          if (routes.isEmpty)
            Text(
              'No routes were returned.',
              style: adminType(13, FontWeight.w500, AdminTokens.textSecondary),
            )
          else
            for (final route in routes)
              InkWell(
                key: Key('route-manifests-row-${route.id}'),
                onTap: () {
                  setState(() => _selectedId = route.id);
                  _loadStops(route.id);
                },
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: route.id == _selectedId
                        ? AdminTokens.primary.withValues(alpha: 0.08)
                        : const Color(0xFFF7F9FC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: route.id == _selectedId
                          ? AdminTokens.primary
                          : AdminTokens.line,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(route.name, style: adminType(14, FontWeight.w700, AdminTokens.text)),
                      const SizedBox(height: 4),
                      Text(
                        [
                          if (route.zoneName.isNotEmpty) route.zoneName,
                          if (route.depotName.isNotEmpty) route.depotName,
                        ].join(' · '),
                        style: adminType(12, FontWeight.w500, AdminTokens.textSecondary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        route.riders.isEmpty
                            ? 'No rider is assigned.'
                            : route.riders
                                .map((rider) => rider.riderCode == null || rider.riderCode!.isEmpty
                                    ? rider.fullName
                                    : '${rider.fullName} · ${rider.riderCode}')
                                .join(', '),
                        style: adminType(12.5, FontWeight.w600, AdminTokens.text),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Widget _stopsPane() {
    final stops = _stops?.value ?? const <RouteStopRow>[];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminTokens.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Stops for ${formatAdminDay(_date)}',
            style: adminType(16, FontWeight.w700, AdminTokens.text),
          ),
          const SizedBox(height: 12),
          if (_stops?.error != null)
            _error(_stops!.error!)
          else if (_selectedId == null)
            Text(
              'Select a route.',
              style: adminType(13, FontWeight.w500, AdminTokens.textSecondary),
            )
          else if (stops.isEmpty)
            Text(
              'No stops were returned for this date.',
              style: adminType(13, FontWeight.w500, AdminTokens.textSecondary),
            )
          else
            for (var i = 0; i < stops.length; i++)
              _stopRow(stops[i], i, stops.length),
        ],
      ),
    );
  }

  Widget _stopRow(RouteStopRow stop, int index, int count) {
    return Container(
      key: Key('route-manifests-stop-${stop.id}'),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FC),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text('${stop.sequence}', style: adminType(13, FontWeight.w700, AdminTokens.primary)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stop.customerName,
                  style: adminType(13.5, FontWeight.w700, AdminTokens.text),
                ),
                Text(
                  [
                    if (stop.customerCode.isNotEmpty) stop.customerCode,
                    if (stop.address.isNotEmpty) stop.address,
                    stop.status,
                  ].join(' · '),
                  style: adminType(12, FontWeight.w500, AdminTokens.textSecondary),
                ),
              ],
            ),
          ),
          IconButton(
            key: Key('route-manifests-up-${stop.id}'),
            tooltip: 'Move earlier',
            onPressed: _stopsBusy || index == 0 ? null : () => _move(stop, -1),
            icon: const Icon(Icons.arrow_upward, size: 18),
          ),
          IconButton(
            key: Key('route-manifests-down-${stop.id}'),
            tooltip: 'Move later',
            onPressed: _stopsBusy || index == count - 1 ? null : () => _move(stop, 1),
            icon: const Icon(Icons.arrow_downward, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _error(String message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(message, style: adminType(13, FontWeight.w600, const Color(0xFFC62828))),
    );
  }
}
