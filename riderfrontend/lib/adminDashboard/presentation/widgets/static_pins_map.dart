import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../theme/admin_tokens.dart';

/// Static OSM pins for admin (Locked V1 — no device GPS / live courier tracking).
class StaticPinsMap extends StatelessWidget {
  const StaticPinsMap({
    required this.pins,
    this.height = 220,
    this.emptyLabel = 'No GPS pins are available for this route.',
    super.key,
  });

  final List<StaticMapPin> pins;
  final double height;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    if (pins.isEmpty) {
      return Container(
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AdminTokens.field,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AdminTokens.line),
        ),
        child: Text(
          emptyLabel,
          style: adminType(13, FontWeight.w500, AdminTokens.textSecondary),
          textAlign: TextAlign.center,
        ),
      );
    }

    final points = [for (final pin in pins) pin.point];
    final center = points.first;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: height,
        child: FlutterMap(
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
                  InteractiveFlag.doubleTapZoom,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.riderfrontend',
            ),
            if (points.length > 1)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: points,
                    strokeWidth: 3.5,
                    color: AdminTokens.primary.withValues(alpha: 0.8),
                  ),
                ],
              ),
            MarkerLayer(
              markers: [
                for (final pin in pins)
                  Marker(
                    point: pin.point,
                    width: pin.highlighted ? 34 : 28,
                    height: pin.highlighted ? 34 : 28,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: pin.highlighted
                              ? AdminTokens.primary
                              : AdminTokens.secondary,
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        Icons.location_on,
                        size: 16,
                        color: pin.highlighted
                            ? AdminTokens.primary
                            : AdminTokens.secondary,
                      ),
                    ),
                  ),
              ],
            ),
            Align(
              alignment: Alignment.bottomLeft,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Text(
                  '© OpenStreetMap · static pins only',
                  style: adminType(
                    9,
                    FontWeight.w400,
                    AdminTokens.textSecondary,
                  ).copyWith(backgroundColor: const Color(0xCCFFFFFF)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StaticMapPin {
  const StaticMapPin({
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
