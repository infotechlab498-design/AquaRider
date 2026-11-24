import 'dart:async';

import 'package:flutter/material.dart';

import 'package:riderfrontend/adminDashboard/data/admin_format.dart';
import 'package:riderfrontend/adminDashboard/presentation/admin_load.dart';
import 'package:riderfrontend/adminDashboard/presentation/admin_nav.dart';
import 'package:riderfrontend/adminDashboard/presentation/widgets/admin_shell.dart';
import 'package:riderfrontend/adminDashboard/presentation/widgets/static_pins_map.dart';
import 'package:riderfrontend/adminDashboard/theme/admin_tokens.dart';
import 'package:riderfrontend/api/route_api.dart';

class ZonesRoutesScreen extends StatefulWidget {
  const ZonesRoutesScreen({required this.onNavigate, this.session, super.key});

  final AuthSession? session;
  final ValueChanged<String> onNavigate;

  @override
  State<ZonesRoutesScreen> createState() => _ZonesRoutesScreenState();
}

class _ZonesRoutesScreenState extends State<ZonesRoutesScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  var _started = false;
  var _loading = true;
  String? _selectedZoneId;
  String? _selectedRouteId;

  AdminLoad<ZonesRoutesSummary>? _summary;
  AdminLoad<List<ZoneListItem>>? _zones;
  AdminLoad<ZoneDetail>? _zoneDetail;
  AdminLoad<RouteDetail>? _routeDetail;
  AdminLoad<List<RouteStopRow>>? _stops;
  AdminLoad<RouteMapData>? _map;
  AdminLoad<List<EligibleRouteRider>>? _riders;

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
      _reload();
    });
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final api = ApiScope.of(context);
    final search = _search.text.trim().isEmpty ? null : _search.text.trim();
    final summary = await guardAdminLoad(api.zonesRoutesSummary);
    final zones = await guardAdminLoad(() => api.listZones(search: search));
    if (!mounted) return;

    final zoneRows = zones.value ?? const <ZoneListItem>[];
    var zoneId = _selectedZoneId;
    if (zoneId == null || !zoneRows.any((item) => item.id == zoneId)) {
      zoneId = zoneRows.isEmpty ? null : zoneRows.first.id;
    }

    AdminLoad<ZoneDetail>? zoneDetail;
    if (zoneId != null) {
      zoneDetail = await guardAdminLoad(() => api.zoneDetail(zoneId!));
    }

    final routes = zoneDetail?.value?.routes ?? const <RouteListItem>[];
    var routeId = _selectedRouteId;
    if (routeId == null || !routes.any((item) => item.id == routeId)) {
      routeId = routes.isEmpty ? null : routes.first.id;
    }

    AdminLoad<RouteDetail>? routeDetail;
    AdminLoad<List<RouteStopRow>>? stops;
    AdminLoad<RouteMapData>? map;
    if (routeId != null) {
      routeDetail = await guardAdminLoad(() => api.routeDetail(routeId!));
      stops = await guardAdminLoad(() => api.routeStops(routeId!));
      map = await guardAdminLoad(() => api.routeMapPins(routeId!));
    }

    final riders = await guardAdminLoad(api.eligibleRouteRiders);
    if (!mounted) return;
    setState(() {
      _summary = summary;
      _zones = zones;
      _selectedZoneId = zoneId;
      _zoneDetail = zoneDetail;
      _selectedRouteId = routeId;
      _routeDetail = routeDetail;
      _stops = stops;
      _map = map;
      _riders = riders;
      _loading = false;
    });
  }

  Future<void> _selectZone(String id) async {
    if (id == _selectedZoneId) return;
    setState(() {
      _selectedZoneId = id;
      _selectedRouteId = null;
    });
    await _reload();
  }

  Future<void> _selectRoute(String id) async {
    if (id == _selectedRouteId) return;
    setState(() => _selectedRouteId = id);
    await _reload();
  }

  Future<void> _createZone() async {
    final draft = await _zoneDialog();
    if (draft == null || !mounted) return;
    try {
      final api = ApiScope.of(context);
      await api.createZone(
        name: draft.$1,
        sector: draft.$2,
        city: draft.$3,
      );
      if (!mounted) return;
      showAdminNotice(context, 'Zone created.');
      await _reload();
    } on ApiException catch (error) {
      if (mounted) showAdminNotice(context, error.message);
    }
  }

  Future<void> _createRoute() async {
    final zoneId = _selectedZoneId;
    if (zoneId == null) {
      showAdminNotice(context, 'Select a zone first.');
      return;
    }
    final name = await _textDialog(
      title: 'Create route',
      label: 'Route name',
      hint: 'Sector – Route NN',
    );
    if (name == null || name.trim().isEmpty || !mounted) return;
    try {
      final api = ApiScope.of(context);
      final created = await api.createRoute(name: name.trim(), zoneId: zoneId);
      if (!mounted) return;
      setState(() => _selectedRouteId = created.id);
      showAdminNotice(context, 'Route created.');
      await _reload();
    } on ApiException catch (error) {
      if (mounted) showAdminNotice(context, error.message);
    }
  }

  Future<void> _assignRider() async {
    final routeId = _selectedRouteId;
    final riders = _riders?.value ?? const <EligibleRouteRider>[];
    if (routeId == null) return;
    final active = riders.where((item) => item.isActive).toList();
    if (active.isEmpty) {
      showAdminNotice(context, 'No active riders are available.');
      return;
    }
    final chosen = await showDialog<EligibleRouteRider>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Assign courier'),
        children: [
          for (final rider in active)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, rider),
              child: Text(
                '${rider.fullName}${rider.riderCode == null ? '' : ' (${rider.riderCode})'}'
                '${rider.currentRouteName == null ? '' : ' · ${rider.currentRouteName}'}',
              ),
            ),
        ],
      ),
    );
    if (chosen == null || !mounted) return;
    try {
      final api = ApiScope.of(context);
      await api.assignRouteRider(routeId, riderUserId: chosen.userId);
      if (!mounted) return;
      showAdminNotice(context, 'Rider assigned.');
      await _reload();
    } on ApiException catch (error) {
      if (mounted) showAdminNotice(context, error.message);
    }
  }

  Future<void> _ensureStops() async {
    final routeId = _selectedRouteId;
    if (routeId == null) return;
    try {
      final api = ApiScope.of(context);
      await api.ensureRouteStops(routeId);
      if (!mounted) return;
      showAdminNotice(context, 'Day stops ensured from route customers.');
      await _reload();
    } on ApiException catch (error) {
      if (mounted) showAdminNotice(context, error.message);
    }
  }

  Future<void> _moveStop(int index, int delta) async {
    final routeId = _selectedRouteId;
    final stops = [...(_stops?.value ?? const <RouteStopRow>[])];
    final next = index + delta;
    if (routeId == null || next < 0 || next >= stops.length) return;
    final item = stops.removeAt(index);
    stops.insert(next, item);
    try {
      await ApiScope.of(context).sequenceRouteStops(
        routeId,
        orderedStopIds: [for (final stop in stops) stop.id],
      );
      await _reload();
    } on ApiException catch (error) {
      if (mounted) showAdminNotice(context, error.message);
    }
  }

  Future<void> _moveCustomer(int index, int delta) async {
    final routeId = _selectedRouteId;
    final customers = [
      ...(_routeDetail?.value?.customers ?? const <RouteCustomerRow>[]),
    ];
    final next = index + delta;
    if (routeId == null || next < 0 || next >= customers.length) return;
    final item = customers.removeAt(index);
    customers.insert(next, item);
    try {
      await ApiScope.of(context).sequenceRouteCustomers(
        routeId,
        orderedCustomerIds: [for (final row in customers) row.id],
      );
      await _reload();
    } on ApiException catch (error) {
      if (mounted) showAdminNotice(context, error.message);
    }
  }

  Future<(String, String, String)?> _zoneDialog() async {
    final name = TextEditingController();
    final sector = TextEditingController();
    final city = TextEditingController(text: 'Rawalpindi');
    final result = await showDialog<(String, String, String)>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create delivery zone'),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Zone name'),
              ),
              TextField(
                controller: sector,
                decoration: const InputDecoration(labelText: 'Sector'),
              ),
              TextField(
                controller: city,
                decoration: const InputDecoration(labelText: 'City'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, (
              name.text.trim(),
              sector.text.trim(),
              city.text.trim(),
            )),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    name.dispose();
    sector.dispose();
    city.dispose();
    if (result == null) return null;
    if (result.$1.isEmpty || result.$2.isEmpty || result.$3.isEmpty) {
      return null;
    }
    return result;
  }

  Future<String?> _textDialog({
    required String title,
    required String label,
    String? hint,
  }) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(labelText: label, hintText: hint),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final loads = <AdminLoad<dynamic>>[
      ?_summary,
      ?_zones,
      ?_zoneDetail,
      ?_routeDetail,
    ];
    final summary = _summary?.value;
    final zones = _zones?.value ?? const <ZoneListItem>[];
    final zoneDetail = _zoneDetail?.value;
    final routeDetail = _routeDetail?.value;
    final stops = _stops?.value ?? const <RouteStopRow>[];
    final map = _map?.value;

    return AdminShell(
      screenKey: const Key('zones-routes-screen'),
      session: widget.session,
      activeKey: AdminNav.zonesRoutes,
      serverReachable: adminServerReachable(loads),
      search: _search,
      onSearch: (_) {},
      searchHint: 'Search zones, sectors, cities',
      onNavigate: widget.onNavigate,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton.icon(
            onPressed: _loading ? null : _createZone,
            icon: const Icon(Icons.add),
            label: const Text('Zone'),
          ),
          TextButton.icon(
            onPressed: _loading ? null : _createRoute,
            icon: const Icon(Icons.alt_route),
            label: const Text('Route'),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _reload,
            icon: const Icon(Icons.refresh, color: AdminTokens.secondary),
          ),
        ],
      ),
      body: _loading && _summary == null
          ? const AdminLoadingPane(label: 'Loading zones and routes…')
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
              children: [
                Text(
                  'Business Management  ›  Zones & Routes',
                  style: adminType(
                    12,
                    FontWeight.w600,
                    AdminTokens.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Zones & Routes Management',
                  style: adminType(
                    28,
                    FontWeight.w700,
                    AdminTokens.text,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Manage delivery sectors, routes, rider assignment, customer sequence, and static stop pins.',
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
                    _Kpi(
                      'Total Zones',
                      '${summary?.totalZones ?? 0}',
                      summary?.depotName == null
                          ? 'Active ${summary?.activeZones ?? 0}'
                          : summary!.depotName!,
                    ),
                    _Kpi(
                      'Active Routes',
                      '${summary?.activeRoutes ?? 0}',
                      'Linked to zones',
                    ),
                    _Kpi(
                      'Assigned Riders',
                      '${summary?.assignedRiders ?? 0}',
                      'Active courier bindings',
                    ),
                    _Kpi(
                      'Assigned Stores',
                      '${summary?.assignedStores ?? 0}',
                      'Missing GPS ${summary?.customersMissingGps ?? 0}',
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 1100;
                    final zonePane = _ZoneList(
                      zones: zones,
                      selectedId: _selectedZoneId,
                      onSelect: _selectZone,
                    );
                    final detailPane = _DetailPane(
                      zone: zoneDetail,
                      route: routeDetail,
                      stops: stops,
                      map: map,
                      onSelectRoute: _selectRoute,
                      onAssignRider: _assignRider,
                      onEnsureStops: _ensureStops,
                      onMoveStop: _moveStop,
                      onMoveCustomer: _moveCustomer,
                    );
                    if (wide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(width: 320, child: zonePane),
                          const SizedBox(width: 16),
                          Expanded(child: detailPane),
                        ],
                      );
                    }
                    return Column(
                      children: [
                        zonePane,
                        const SizedBox(height: 16),
                        detailPane,
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
      width: 200,
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
          Text(value, style: adminType(22, FontWeight.w700, AdminTokens.text)),
          const SizedBox(height: 4),
          Text(
            hint,
            style: adminType(12, FontWeight.w500, AdminTokens.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _ZoneList extends StatelessWidget {
  const _ZoneList({
    required this.zones,
    required this.selectedId,
    required this.onSelect,
  });

  final List<ZoneListItem> zones;
  final String? selectedId;
  final ValueChanged<String> onSelect;

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
          Text(
            'Delivery sectors',
            style: adminType(15, FontWeight.w700, AdminTokens.text),
          ),
          const SizedBox(height: 10),
          if (zones.isEmpty)
            Text(
              'No zones in SQL yet. Create a zone to begin.',
              style: adminType(13, FontWeight.w500, AdminTokens.textSecondary),
            )
          else
            for (final zone in zones)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: zone.id == selectedId
                      ? AdminTokens.primarySoft
                      : AdminTokens.field,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => onSelect(zone.id),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            zone.name,
                            style: adminType(
                              14,
                              FontWeight.w700,
                              AdminTokens.text,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Sector ${zone.sector} · ${zone.city}',
                            style: adminType(
                              12,
                              FontWeight.w500,
                              AdminTokens.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${zone.routeCount} routes · ${zone.customerCount} stores · ${zone.assignedRiderCount} riders',
                            style: adminType(
                              12,
                              FontWeight.w500,
                              AdminTokens.textSecondary,
                            ),
                          ),
                          if (!zone.isActive)
                            Text(
                              'Inactive',
                              style: adminType(
                                12,
                                FontWeight.w600,
                                AdminTokens.warning,
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

class _DetailPane extends StatelessWidget {
  const _DetailPane({
    required this.zone,
    required this.route,
    required this.stops,
    required this.map,
    required this.onSelectRoute,
    required this.onAssignRider,
    required this.onEnsureStops,
    required this.onMoveStop,
    required this.onMoveCustomer,
  });

  final ZoneDetail? zone;
  final RouteDetail? route;
  final List<RouteStopRow> stops;
  final RouteMapData? map;
  final ValueChanged<String> onSelectRoute;
  final VoidCallback onAssignRider;
  final VoidCallback onEnsureStops;
  final void Function(int index, int delta) onMoveStop;
  final void Function(int index, int delta) onMoveCustomer;

  @override
  Widget build(BuildContext context) {
    if (zone == null) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AdminTokens.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AdminTokens.line),
        ),
        child: Text(
          'Select a zone to manage routes.',
          style: adminType(14, FontWeight.w500, AdminTokens.textSecondary),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AdminTokens.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AdminTokens.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                zone!.name,
                style: adminType(18, FontWeight.w700, AdminTokens.text),
              ),
              const SizedBox(height: 4),
              Text(
                'Sector ${zone!.sector} · ${zone!.city} · ${zone!.depotName}',
                style: adminType(
                  13,
                  FontWeight.w500,
                  AdminTokens.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final item in zone!.routes)
                    ChoiceChip(
                      label: Text(
                        '${item.name} (${item.customerCount})'
                        '${item.hasRider ? '' : ' · No rider'}',
                      ),
                      selected: route?.id == item.id,
                      onSelected: (_) => onSelectRoute(item.id),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (route == null)
          Text(
            'Create a route in this zone to continue.',
            style: adminType(13, FontWeight.w500, AdminTokens.textSecondary),
          )
        else ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AdminTokens.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AdminTokens.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        route!.name,
                        style: adminType(
                          17,
                          FontWeight.w700,
                          AdminTokens.text,
                        ),
                      ),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AdminTokens.button,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: onAssignRider,
                      child: Text(
                        route!.riders.isEmpty
                            ? 'Assign courier'
                            : 'Reassign courier',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  route!.riders.isEmpty
                      ? 'No rider assigned'
                      : route!.riders
                            .map(
                              (item) =>
                                  '${item.fullName}${item.riderCode == null ? '' : ' (${item.riderCode})'}'
                                  '${item.vehiclePlate == null ? '' : ' · ${item.vehiclePlate}'}',
                            )
                            .join(' · '),
                  style: adminType(
                    13,
                    FontWeight.w500,
                    route!.riders.isEmpty
                        ? AdminTokens.error
                        : AdminTokens.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${route!.customerCount} stores · ${route!.customersWithGps} with GPS · ${route!.stopCountToday} stops today',
                  style: adminType(
                    12,
                    FontWeight.w500,
                    AdminTokens.textSecondary,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Static geospatial pins',
                  style: adminType(14, FontWeight.w700, AdminTokens.text),
                ),
                const SizedBox(height: 8),
                StaticPinsMap(
                  pins: [
                    for (final pin in map?.pins ?? const <RouteMapPin>[])
                      StaticMapPin(
                        latitude: pin.latitude.toDouble(),
                        longitude: pin.longitude.toDouble(),
                        label: pin.label,
                        highlighted: pin.sequence == 1,
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _TableCard(
            title: 'Customer allocation & master sequence',
            trailing: Text(
              '${route!.customers.length} accounts',
              style: adminType(12, FontWeight.w600, AdminTokens.textSecondary),
            ),
            child: route!.customers.isEmpty
                ? Text(
                    'No customers on this route.',
                    style: adminType(
                      13,
                      FontWeight.w500,
                      AdminTokens.textSecondary,
                    ),
                  )
                : Column(
                    children: [
                      for (var i = 0; i < route!.customers.length; i++)
                        _SeqRow(
                          seq: route!.customers[i].routeSortOrder,
                          title: route!.customers[i].businessName,
                          subtitle:
                              '${route!.customers[i].code} · ${route!.customers[i].address}'
                              '${route!.customers[i].hasGps ? '' : ' · No GPS'}',
                          meta: formatPkr(route!.customers[i].outstanding),
                          onUp: i == 0 ? null : () => onMoveCustomer(i, -1),
                          onDown: i == route!.customers.length - 1
                              ? null
                              : () => onMoveCustomer(i, 1),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 14),
          _TableCard(
            title: 'Day stop sequence',
            trailing: TextButton(
              onPressed: onEnsureStops,
              child: const Text('Ensure today\'s stops'),
            ),
            child: stops.isEmpty
                ? Text(
                    'No RouteStops for today. Ensure stops from allocated customers.',
                    style: adminType(
                      13,
                      FontWeight.w500,
                      AdminTokens.textSecondary,
                    ),
                  )
                : Column(
                    children: [
                      for (var i = 0; i < stops.length; i++)
                        _SeqRow(
                          seq: stops[i].sequence,
                          title: stops[i].customerName,
                          subtitle:
                              '${stops[i].customerCode} · ${stops[i].address}',
                          meta: stops[i].status,
                          onUp: i == 0 ? null : () => onMoveStop(i, -1),
                          onDown: i == stops.length - 1
                              ? null
                              : () => onMoveStop(i, 1),
                        ),
                    ],
                  ),
          ),
        ],
      ],
    );
  }
}

class _TableCard extends StatelessWidget {
  const _TableCard({
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
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
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: adminType(15, FontWeight.w700, AdminTokens.text),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _SeqRow extends StatelessWidget {
  const _SeqRow({
    required this.seq,
    required this.title,
    required this.subtitle,
    required this.meta,
    this.onUp,
    this.onDown,
  });

  final int seq;
  final String title;
  final String subtitle;
  final String meta;
  final VoidCallback? onUp;
  final VoidCallback? onDown;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AdminTokens.field,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AdminTokens.line),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text(
              seq.toString().padLeft(2, '0'),
              style: adminType(13, FontWeight.w700, AdminTokens.primary),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: adminType(13, FontWeight.w700, AdminTokens.text),
                ),
                Text(
                  subtitle,
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
            meta,
            style: adminType(12, FontWeight.w600, AdminTokens.textSecondary),
          ),
          IconButton(
            onPressed: onUp,
            icon: const Icon(Icons.keyboard_arrow_up),
          ),
          IconButton(
            onPressed: onDown,
            icon: const Icon(Icons.keyboard_arrow_down),
          ),
        ],
      ),
    );
  }
}
