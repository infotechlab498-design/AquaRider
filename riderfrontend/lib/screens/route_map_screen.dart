import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/field_store.dart';
import '../api/route_api.dart';
import '../ui/route_ui.dart';
import '../widgets/live_route_map.dart';
import '../widgets/rider_inbox_button.dart';
import '../widgets/rider_wave_background.dart';
import 'field_screens.dart';

const _navy = Color(0xFF102448);
const _blue = Color(0xFF0875E8);
const _muted = Color(0xFF6A7C90);
const _line = Color(0xFFE3EEF7);

class RouteMapScreen extends StatefulWidget {
  const RouteMapScreen({this.standalone = false, this.onOpenProfile, super.key});

  final bool standalone;
  final VoidCallback? onOpenProfile;

  @override
  State<RouteMapScreen> createState() => _RouteMapScreenState();
}

class _RouteMapScreenState extends State<RouteMapScreen> {
  final _mapKey = GlobalKey<LiveRouteMapState>();
  var _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    final store = FieldScope.of(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      store.loadHome();
      store.loadStops();
    });
  }

  StopItem? _destination(List<StopItem> stops, DashboardData? dash) {
    StopItem? destination;
    for (final stop in stops) {
      if (dash?.nextStopName != null && stop.customerName == dash!.nextStopName) {
        destination = stop;
        break;
      }
    }
    if (destination == null) {
      for (final stop in stops) {
        if (stop.status != 'Completed') {
          destination = stop;
          break;
        }
      }
    }
    return destination ?? (stops.isEmpty ? null : stops.first);
  }

  int _estimateMinutes(DashboardData? dash) {
    if (dash == null) return 0;
    final km = dash.remainingDistanceKm.toDouble();
    if (km <= 0) {
      final meters = dash.nextDistanceMeters ?? 0;
      if (meters <= 0) return 0;
      return (meters / 250).round().clamp(0, 999);
    }
    return (km * 3.5).round().clamp(0, 999);
  }

  String _statusLabel(String status) {
    if (status == 'Completed') return 'Completed';
    if (status == 'Missed') return 'Missed';
    if (status.toLowerCase().contains('progress') || status == 'Arrived') return status;
    return status.isEmpty ? 'Pending' : status;
  }

  Color _statusColor(String status) {
    final value = status.toLowerCase();
    if (value == 'completed') return const Color(0xFF168A45);
    if (value == 'missed') return const Color(0xFFE23B4A);
    if (value.contains('progress') || value == 'arrived') return _blue;
    return const Color(0xFFB45309);
  }

  Color _statusBg(String status) {
    final value = status.toLowerCase();
    if (value == 'completed') return const Color(0xFFE6F7ED);
    if (value == 'missed') return const Color(0xFFFDECEC);
    if (value.contains('progress') || value == 'arrived') return const Color(0xFFE8F4FF);
    return const Color(0xFFFFF4D6);
  }

  Future<void> _copyAddress(String address) async {
    if (address.trim().isEmpty) return;
    await Clipboard.setData(ClipboardData(text: address));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Address copied.')));
  }

  Future<void> _openStop(StopItem stop) async {
    final store = FieldScope.of(context);
    await store.openStop(stop);
    if (!mounted) return;
    pushRoute(context, const CustomerOpsScreen());
  }

  @override
  Widget build(BuildContext context) {
    final store = FieldScope.of(context);
    final dash = store.dashboard;
    final stops = store.stops;
    final destination = _destination(stops, dash);
    final remaining = dash?.remainingStops ?? stops.where((stop) => stop.status != 'Completed').length;
    final total = dash?.totalStops ?? stops.length;
    final km = dash?.remainingDistanceKm ?? 0;
    final minutes = _estimateMinutes(dash);
    final address = destination?.address.isNotEmpty == true
        ? destination!.address
        : (dash?.nextAddress ?? '');
    final pins = [
      for (final stop in stops)
        if (stop.latitude != null && stop.longitude != null)
          RoutePin(
            latitude: stop.latitude!.toDouble(),
            longitude: stop.longitude!.toDouble(),
            label: stop.customerName,
            highlighted: stop.id == destination?.id || stop.customerName == (destination?.customerName ?? dash?.nextStopName),
          ),
    ];
    final pendingStops = stops.where((stop) => stop.status != 'Completed').toList();
    final nextIndex = destination == null
        ? 0
        : stops.indexWhere((stop) => stop.id == destination.id).clamp(0, stops.length);
    final isFinal = destination != null && pendingStops.length <= 1;

    final body = LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 720;
        final landscape = constraints.maxHeight > 0 && constraints.maxWidth / constraints.maxHeight > 1.15;
        final mapHeight = landscape ? 150.0 : (wide ? 190.0 : 168.0);
        return Stack(
          fit: StackFit.expand,
          children: [
            const RiderWaveBackground(),
            RefreshIndicator(
              color: _blue,
              onRefresh: () async {
                await store.loadHome();
                await store.loadStops();
              },
              child: ListView(
                key: const Key('route-map-screen'),
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(16, 8, 16, widget.standalone ? 24 : 12),
                children: [
                  _topBar(),
                  const SizedBox(height: 12),
                  _title(dash?.routeName ?? 'Assigned route'),
                  const SizedBox(height: 12),
                  _statsCard(
                    remaining: remaining,
                    total: total == 0 ? remaining : total,
                    km: km,
                    minutes: minutes,
                    compact: landscape && !wide,
                  ),
                  const SizedBox(height: 14),
                  if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 6,
                          child: _mapCard(
                            destination: destination,
                            dash: dash,
                            pins: pins,
                            address: address,
                            mapHeight: mapHeight,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          flex: 4,
                          child: Column(
                            children: [
                              if (destination != null)
                                _nextStopCard(
                                  stop: destination,
                                  index: nextIndex + 1,
                                  isFinal: isFinal,
                                )
                              else
                                _emptyNext(),
                              if (stops.length > 1) ...[
                                const SizedBox(height: 12),
                                _queuePreview(stops, destination),
                              ],
                            ],
                          ),
                        ),
                      ],
                    )
                  else ...[
                    _mapCard(
                      destination: destination,
                      dash: dash,
                      pins: pins,
                      address: address,
                      mapHeight: mapHeight,
                    ),
                    const SizedBox(height: 14),
                    if (destination != null)
                      _nextStopCard(
                        stop: destination,
                        index: nextIndex + 1,
                        isFinal: isFinal,
                      )
                    else
                      _emptyNext(),
                    if (stops.length > 1) ...[
                      const SizedBox(height: 12),
                      _queuePreview(stops, destination),
                    ],
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );

    if (!widget.standalone) return body;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F9FE),
      appBar: AppBar(backgroundColor: Colors.transparent, foregroundColor: _navy, elevation: 0, title: const Text('Route Map')),
      body: body,
    );
  }

  Widget _topBar() {
    return Row(
      children: [
        Image.asset('assets/customer_home/branding/aquarider_logo.png', height: 36, fit: BoxFit.contain),
        const Spacer(),
        Material(
          color: Colors.white,
          elevation: 1,
          shadowColor: const Color(0x220875E8),
          shape: const CircleBorder(),
          child: SizedBox(
            width: 34,
            height: 34,
            child: Center(
              child: Transform.scale(
                scale: 0.78,
                child: const RiderInboxButton(iconColor: _navy),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Material(
          color: Colors.white,
          elevation: 1,
          shadowColor: const Color(0x220875E8),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: widget.onOpenProfile,
            child: const SizedBox(
              width: 34,
              height: 34,
              child: Icon(Icons.person_outline, color: _navy, size: 18),
            ),
          ),
        ),
      ],
    );
  }

  Widget _title(String routeName) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          margin: const EdgeInsets.only(top: 2),
          alignment: Alignment.center,
          decoration: BoxDecoration(color: const Color(0xFFE8F4FF), borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.location_on, color: _blue, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Route Map', style: routeType(26, FontWeight.w800, _navy, 30, -0.3)),
              Text(routeName, style: routeType(14, FontWeight.w500, _muted, 18)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statsCard({
    required int remaining,
    required int total,
    required num km,
    required int minutes,
    required bool compact,
  }) {
    final items = [
      _stat(Icons.alt_route, '$remaining / $total', 'Stops Left'),
      _stat(Icons.route_outlined, '${_fmtKm(km)} km', 'Remaining'),
      _stat(Icons.schedule, '~ $minutes min', 'Est. Time'),
    ];
    return _card(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: compact
          ? Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) const Divider(height: 16, color: _line),
                  items[i],
                ],
              ],
            )
          : Row(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) Container(width: 1, height: 36, color: _line),
                  Expanded(child: items[i]),
                ],
              ],
            ),
    );
  }

  Widget _stat(IconData icon, String value, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        children: [
          Icon(icon, size: 18, color: _blue),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: routeType(14, FontWeight.w800, _navy, 18)),
          ),
          Text(label, style: routeType(11, FontWeight.w600, _muted, 14)),
        ],
      ),
    );
  }

  Widget _mapCard({
    required StopItem? destination,
    required DashboardData? dash,
    required List<RoutePin> pins,
    required String address,
    required double mapHeight,
  }) {
    return _card(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            children: [
              LiveRouteMap(
                key: _mapKey,
                pins: pins,
                height: mapHeight,
                showControls: true,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
              ),
              Positioned(
                left: 12,
                top: 12,
                child: _mapBadge('You', const Color(0xFF168A45)),
              ),
              if ((destination?.customerName ?? dash?.nextStopName) != null)
                Positioned(
                  right: 12,
                  top: 12,
                  child: _mapBadge(destination?.customerName ?? dash!.nextStopName!, _blue),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.location_on, color: _blue, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        address.isEmpty ? 'Destination address loads with the next stop.' : address,
                        style: routeType(13, FontWeight.w600, _navy, 18),
                      ),
                    ),
                    IconButton(
                      key: const Key('route-map-copy-address'),
                      tooltip: 'Copy address',
                      onPressed: address.isEmpty ? null : () => _copyAddress(address),
                      icon: const Icon(Icons.copy_outlined, size: 18, color: _blue),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: const LinearGradient(colors: [Color(0xFF0A7BEA), Color(0xFF0662C8)]),
                      boxShadow: const [BoxShadow(color: Color(0x330875E8), blurRadius: 12, offset: Offset(0, 5))],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        key: const Key('route-map-open-google'),
                        borderRadius: BorderRadius.circular(14),
                        onTap: destination == null
                            ? null
                            : () => openStopInGoogleMaps(
                                  context,
                                  name: destination.customerName,
                                  address: destination.address,
                                  latitude: destination.latitude,
                                  longitude: destination.longitude,
                                ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.navigation_rounded, color: Colors.white, size: 18),
                            const SizedBox(width: 8),
                            Text('Open in Google Maps', style: routeType(14, FontWeight.w700, Colors.white, 18)),
                            const SizedBox(width: 6),
                            const Icon(Icons.open_in_new, color: Colors.white, size: 16),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _mapBadge(String label, Color color) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 140),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(999)),
      child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: routeType(11, FontWeight.w700, Colors.white, 14)),
    );
  }

  Widget _nextStopCard({required StopItem stop, required int index, required bool isFinal}) {
    final status = _statusLabel(stop.status);
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_shipping_outlined, color: _blue, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text('Next Stop', style: routeType(16, FontWeight.w800, _navy, 20))),
              if (isFinal)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: const Color(0xFFE8F4FF), borderRadius: BorderRadius.circular(16)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.flag_outlined, size: 14, color: _blue),
                      const SizedBox(width: 4),
                      Text('Final Stop', style: routeType(12, FontWeight.w700, _blue, 16)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Material(
            color: const Color(0xFFEFF7FF),
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              key: Key('route-map-next-${stop.id}'),
              borderRadius: BorderRadius.circular(16),
              onTap: () => _openStop(stop),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(color: _blue, shape: BoxShape.circle),
                      child: Text(index.toString().padLeft(2, '0'), style: routeType(13, FontWeight.w800, Colors.white, 16)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(stop.customerName, style: routeType(15, FontWeight.w800, _navy, 20)),
                          Text(stop.customerCode, style: routeType(12, FontWeight.w600, _muted, 16)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: _statusBg(status), borderRadius: BorderRadius.circular(16)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.schedule, size: 13, color: _statusColor(status)),
                          const SizedBox(width: 4),
                          Text(status, style: routeType(12, FontWeight.w700, _statusColor(status), 16)),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Color(0xFF9AADC0)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyNext() {
    return _card(
      child: Text(
        'No pending stop is loaded for this route yet.',
        style: routeType(13, FontWeight.w600, _muted, 18),
      ),
    );
  }

  Widget _queuePreview(List<StopItem> stops, StopItem? destination) {
    final rows = stops.take(8).toList();
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Route Stops', style: routeType(15, FontWeight.w800, _navy, 20)),
          const SizedBox(height: 8),
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 12, color: _line),
            InkWell(
              onTap: () => _openStop(rows[i]),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: rows[i].id == destination?.id ? _blue : const Color(0xFFE8F4FF),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        (i + 1).toString().padLeft(2, '0'),
                        style: routeType(11, FontWeight.w800, rows[i].id == destination?.id ? Colors.white : _blue, 14),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(rows[i].customerName, style: routeType(13, FontWeight.w700, _navy, 18)),
                          Text('${rows[i].status} · ${rows[i].customerCode}', style: routeType(11, FontWeight.w500, _muted, 14)),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => openStopInGoogleMaps(
                        context,
                        name: rows[i].customerName,
                        address: rows[i].address,
                        latitude: rows[i].latitude,
                        longitude: rows[i].longitude,
                      ),
                      icon: const Icon(Icons.navigation_outlined, color: _blue, size: 18),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _card({required Widget child, EdgeInsetsGeometry padding = const EdgeInsets.all(14)}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [BoxShadow(color: Color(0x140875C8), blurRadius: 18, offset: Offset(0, 8))],
      ),
      child: Material(
        color: const Color(0xF7FFFFFF),
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: Padding(padding: padding, child: child),
      ),
    );
  }

  String _fmtKm(num km) {
    if (km == km.roundToDouble()) return km.round().toString();
    return km.toStringAsFixed(1);
  }
}
