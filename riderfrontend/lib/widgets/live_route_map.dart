import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';

import '../ui/route_ui.dart';

class RoutePin {
  const RoutePin({
    required this.latitude,
    required this.longitude,
    required this.label,
    this.highlighted = false,
  });

  final double latitude;
  final double longitude;
  final String label;
  final bool highlighted;

  LatLng get point => LatLng(latitude, longitude);
}

class LiveRouteMap extends StatefulWidget {
  const LiveRouteMap({
    required this.pins,
    this.height = 176,
    this.showControls = false,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    super.key,
  });

  final List<RoutePin> pins;
  final double height;
  final bool showControls;
  final BorderRadius borderRadius;

  @override
  State<LiveRouteMap> createState() => LiveRouteMapState();
}

class LiveRouteMapState extends State<LiveRouteMap> {
  static const _depot = LatLng(33.626, 73.068);
  final _controller = MapController();
  LatLng? _here;
  var _lightTiles = false;

  @override
  void initState() {
    super.initState();
    _locate();
  }

  @override
  void didUpdateWidget(covariant LiveRouteMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(
      oldWidget.pins.map((pin) => '${pin.latitude},${pin.longitude},${pin.highlighted}').toList(),
      widget.pins.map((pin) => '${pin.latitude},${pin.longitude},${pin.highlighted}').toList(),
    )) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) recenter();
      });
    }
  }

  Future<void> _locate() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final location = Location();
      if (!await location.serviceEnabled()) return;
      final permission = await location.hasPermission();
      final allowed =
          permission == PermissionStatus.granted ||
          permission == PermissionStatus.grantedLimited;
      if (!allowed) return;
      final here = await location.getLocation().timeout(
        const Duration(seconds: 6),
      );
      if (!mounted) return;
      setState(() => _here = LatLng(here.latitude, here.longitude));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) recenter();
      });
    } catch (_) {}
  }

  void recenter() {
    final points = [?_here, ...widget.pins.map((pin) => pin.point)];
    if (points.isEmpty) return;
    try {
      if (points.length == 1) {
        _controller.move(points.first, 15);
        return;
      }
      _controller.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(points),
          padding: const EdgeInsets.all(36),
          maxZoom: 16,
        ),
      );
    } catch (_) {}
  }

  void _toggleLayer() {
    setState(() => _lightTiles = !_lightTiles);
  }

  @override
  Widget build(BuildContext context) {
    final points = [?_here, ...widget.pins.map((pin) => pin.point)];
    final center = points.isEmpty ? _depot : points.first;
    final tileUrl = _lightTiles
        ? 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png'
        : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: SizedBox(
        height: widget.height,
        child: Stack(
          children: [
            FlutterMap(
              mapController: _controller,
              options: MapOptions(
                initialCenter: center,
                initialZoom: points.length > 1 ? 13 : 15,
                initialCameraFit: points.length > 1
                    ? CameraFit.bounds(
                        bounds: LatLngBounds.fromPoints(points),
                        padding: const EdgeInsets.all(36),
                        maxZoom: 16,
                      )
                    : null,
                interactionOptions: const InteractionOptions(
                  flags:
                      InteractiveFlag.drag |
                      InteractiveFlag.pinchZoom |
                      InteractiveFlag.doubleTapZoom |
                      InteractiveFlag.flingAnimation,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: tileUrl,
                  userAgentPackageName: 'com.example.riderfrontend',
                  subdomains: _lightTiles ? const ['a', 'b', 'c', 'd'] : const [],
                ),
                if (points.length > 1)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: points,
                        strokeWidth: 4,
                        color: RouteColors.primary.withValues(alpha: 0.85),
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    if (_here != null)
                      Marker(
                        point: _here!,
                        width: 28,
                        height: 28,
                        child: const _Dot(
                          color: RouteColors.ok,
                          icon: Icons.navigation,
                        ),
                      ),
                    for (final pin in widget.pins)
                      Marker(
                        point: pin.point,
                        width: pin.highlighted ? 34 : 26,
                        height: pin.highlighted ? 34 : 26,
                        child: _Dot(
                          color: pin.highlighted
                              ? RouteColors.primary
                              : const Color(0xFF5C6B8A),
                          icon: Icons.location_on,
                        ),
                      ),
                  ],
                ),
                Align(
                  alignment: Alignment.bottomLeft,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(widget.showControls ? 52 : 6, 6, 6, 6),
                    child: Text(
                      _lightTiles ? '© CARTO · © OSM' : '© OpenStreetMap',
                      style: AppType.style(
                        9,
                        FontWeight.w400,
                        const Color(0xFF434655),
                      ).copyWith(backgroundColor: const Color(0xCCFFFFFF)),
                    ),
                  ),
                ),
              ],
            ),
            if (widget.showControls) ...[
              Positioned(
                left: 10,
                bottom: 10,
                child: _mapFab(
                  key: const Key('route-map-layer'),
                  icon: Icons.layers_outlined,
                  onTap: _toggleLayer,
                ),
              ),
              Positioned(
                right: 10,
                bottom: 10,
                child: _mapFab(
                  key: const Key('route-map-recenter'),
                  icon: Icons.my_location,
                  onTap: () {
                    _locate();
                    recenter();
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _mapFab({required Key key, required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: Colors.white,
      elevation: 2,
      shadowColor: const Color(0x330875E8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        key: key,
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, color: RouteColors.primary, size: 20),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color, required this.icon});

  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Icon(icon, color: color, size: 16),
    );
  }
}
