import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:location/location.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/field_store.dart';
import '../api/route_api.dart';
import '../core/odometer_photo.dart';
import '../core/printer_radio.dart';
import '../ui/route_ui.dart';
import '../widgets/live_route_map.dart';
import '../widgets/rider_inbox_button.dart';
import 'rider_settings_pane.dart';
import 'route_compliance_screen.dart';
import 'session_nav.dart';

Future<void> openStopInGoogleMaps(
  BuildContext context, {
  required String name,
  required String address,
  num? latitude,
  num? longitude,
}) async {
  String? origin;
  try {
    final location = Location();
    final enabled = await location.serviceEnabled();
    final permission = await location.hasPermission();
    final allowed =
        permission == PermissionStatus.granted ||
        permission == PermissionStatus.grantedLimited;
    if (enabled && allowed) {
      final here = await location.getLocation().timeout(
        const Duration(seconds: 6),
      );
      origin = '${here.latitude},${here.longitude}';
    }
  } catch (_) {
    origin = null;
  }

  final destination = latitude != null && longitude != null
      ? '$latitude,$longitude'
      : '$name, $address';
  final uri = Uri.https('www.google.com', '/maps/dir/', {
    'api': '1',
    'destination': destination,
    'travelmode': 'driving',
    'origin': ?origin,
  });
  final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Google Maps could not be opened on this phone.'),
      ),
    );
  }
}

String _pkr(num amount) {
  final digits = amount.round().abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return 'PKR $buffer';
}

class HomeDashboard extends StatelessWidget {
  const HomeDashboard({
    this.onOpenProfile,
    this.onOpenTodo,
    this.onOpenMap,
    super.key,
  });

  final VoidCallback? onOpenProfile;
  final VoidCallback? onOpenTodo;
  final VoidCallback? onOpenMap;

  @override
  Widget build(BuildContext context) {
    final store = FieldScope.of(context);
    final dash = store.dashboard;
    if (dash == null) {
      final problem = store.error;
      if (problem == null) {
        return const Center(child: CircularProgressIndicator());
      }
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                problem,
                textAlign: TextAlign.center,
                style: routeType(14, FontWeight.w600, RouteColors.ink, 20),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: store.loadHome,
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }
    final visitedShare = dash.totalStops == 0
        ? 0.0
        : dash.visitedCount / dash.totalStops;
    final visitedPercent = (visitedShare * 100).round();
    final pins = <RoutePin>[
      for (final stop in store.stops)
        if (stop.latitude != null && stop.longitude != null)
          RoutePin(
            latitude: stop.latitude!.toDouble(),
            longitude: stop.longitude!.toDouble(),
            label: stop.customerName,
            highlighted: stop.customerName == dash.nextStopName,
          ),
    ];
    if (dash.nextLatitude != null &&
        dash.nextLongitude != null &&
        !pins.any((pin) => pin.highlighted)) {
      pins.add(
        RoutePin(
          latitude: dash.nextLatitude!,
          longitude: dash.nextLongitude!,
          label: dash.nextStopName ?? 'Next stop',
          highlighted: true,
        ),
      );
    }
    final initials = dash.riderName
        .split(' ')
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0])
        .join()
        .toUpperCase();
    final van = dash.fleetCode.isEmpty
        ? '${dash.vehicleName} (${dash.vehiclePlate})'
        : '${dash.vehicleName} (${dash.fleetCode})';

    return Stack(
      children: [
        const Positioned.fill(
          child: Image(image: AssetImage('assets/home/background.png'), fit: BoxFit.cover),
        ),
        const Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: Opacity(
              opacity: 0.55,
              child: Image(image: AssetImage('assets/home/wave_header.png'), height: 150, fit: BoxFit.cover),
            ),
          ),
        ),
        RefreshIndicator(
      onRefresh: () async {
        await store.loadHome();
        await store.loadStops();
      },
      child: ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Row(
          children: [
            Image.asset('assets/home/logo.png', height: 46, fit: BoxFit.contain),
            const Spacer(),
            IconButton(
              onPressed: onOpenTodo,
              icon: Image.asset('assets/home/icon_search.png', width: 34, height: 34, fit: BoxFit.contain),
            ),
            const RiderInboxButton(),
            IconButton(
              onPressed: onOpenProfile,
              icon: Image.asset('assets/home/icon_profile.png', width: 34, height: 34, fit: BoxFit.contain),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Stack(
          clipBehavior: Clip.none,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 108),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0875DC),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('RL', style: routeType(9, FontWeight.w700, Colors.white, 12)),
                      ),
                      const SizedBox(width: 8),
                      Text('Field Operative', style: routeType(12, FontWeight.w600, const Color(0xFF66758D), 16)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(dash.greeting, style: routeType(24, FontWeight.w700, const Color(0xFF10264A), 30, -0.3)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Image.asset('assets/home/icon_calendar.png', width: 16, height: 16, fit: BoxFit.contain),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(_longDate(dash.serviceDate), style: routeType(13, FontWeight.w400, const Color(0xFF66758D), 18)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Positioned(
              right: -8,
              top: -8,
              child: Image.asset('assets/home/rider.png', width: 148, height: 118, fit: BoxFit.contain),
            ),
          ],
        ),
        const SizedBox(height: 10),
        RouteCard(
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: RouteColors.pale,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      initials.isEmpty ? 'RL' : initials,
                      style: routeType(
                        14,
                        FontWeight.w700,
                        RouteColors.primary,
                        18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dash.riderName,
                          style: routeType(
                            16,
                            FontWeight.w700,
                            RouteColors.ink,
                            22,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on,
                              color: RouteColors.primary,
                              size: 14,
                            ),
                            const SizedBox(width: 2),
                            Expanded(
                              child: Text(
                                dash.routeName,
                                style: routeType(
                                  12,
                                  FontWeight.w500,
                                  RouteColors.secondary,
                                  16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        dash.riderCode,
                        style: routeType(
                          12,
                          FontWeight.w700,
                          RouteColors.primary,
                          16,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: dash.shiftOpen ? const Color(0xFFE5F6EC) : const Color(0xFFF3F5F8),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.play_arrow_rounded, size: 12, color: dash.shiftOpen ? const Color(0xFF16A36A) : const Color(0xFF66758D)),
                            const SizedBox(width: 2),
                            Text(
                              dash.shiftOpen ? 'Day Started' : 'Day Not Started',
                              style: routeType(10, FontWeight.w700, dash.shiftOpen ? const Color(0xFF16A36A) : const Color(0xFF66758D), 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Divider(height: 16, color: Color(0xFFE3EDF7)),
              Row(
                children: [
                  Image.asset('assets/home/icon_van.png', width: 28, height: 28, fit: BoxFit.contain),
                  const SizedBox(width: 6),
                  Expanded(child: _MetaLine('ASSIGNED VAN', van)),
                  Container(width: 1, height: 32, color: const Color(0xFFE3EDF7)),
                  const SizedBox(width: 8),
                  Image.asset('assets/home/icon_depot.png', width: 28, height: 28, fit: BoxFit.contain),
                  const SizedBox(width: 6),
                  Expanded(child: _MetaLine('DEPOT GATE', dash.depotGate)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _DutyOperations(shiftOpen: dash.shiftOpen, onOpenMap: onOpenMap),
        const SizedBox(height: 12),
        Row(
          children: [
            const Icon(Icons.bar_chart, size: 18, color: Color(0xFF0B74E8)),
            const SizedBox(width: 6),
            Text(
              "Today's Performance",
              style: routeType(16, FontWeight.w700, const Color(0xFF0C2F66), 22),
            ),
            const Spacer(),
            const Icon(Icons.calendar_today_outlined, size: 12, color: RouteColors.secondary),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                _longDate(dash.serviceDate),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: routeType(11, FontWeight.w500, RouteColors.secondary, 16),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _MoneyCard(
                Icons.payments_outlined,
                _pkr(dash.billedSales),
                'Billed Sales',
                '${dash.salesCount} completed sale${dash.salesCount == 1 ? '' : 's'}',
                const Color(0xFF0875DC),
                image: 'assets/home/icon_sales.png',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MoneyCard(
                Icons.account_balance_wallet_outlined,
                _pkr(dash.cashCollected),
                'Cash Collected',
                dash.cashCollected > 0 ? 'Collected today' : 'No cash collected yet',
                const Color(0xFF16A36A),
                image: 'assets/home/icon_cash.png',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatCard(
                Icons.location_on_outlined,
                '${dash.visitedCount} / ${dash.totalStops}',
                '$visitedPercent%',
                'Visited',
                const Color(0xFF0875DC),
                image: 'assets/home/icon_visited.png',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatCard(
                Icons.inventory_2_outlined,
                '${dash.pendingDeliveries}',
                null,
                'Pending Delivery',
                dash.pendingDeliveries > 0 ? const Color(0xFFE53935) : const Color(0xFF10264A),
                note: dash.pendingNote,
                image: 'assets/home/icon_pending.png',
                background: dash.pendingDeliveries > 0 ? const Color(0xFFFFF1F1) : Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        RouteCard(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Image.asset('assets/home/icon_route.png', width: 22, height: 22, fit: BoxFit.contain),
                            const SizedBox(width: 6),
                            Text("Today's Route", style: routeType(16, FontWeight.w700, const Color(0xFF10264A), 22)),
                          ],
                        ),
                        Text(
                          dash.routeName,
                          style: routeType(
                            12,
                            FontWeight.w500,
                            RouteColors.secondary,
                            16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F3FF),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset('assets/home/icon_live_map.png', width: 16, height: 16, fit: BoxFit.contain),
                        const SizedBox(width: 4),
                        Text('Live Map', style: routeType(11, FontWeight.w700, const Color(0xFF0875DC), 14)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        _RouteLine(Icons.inventory_2_outlined, 'Total Stops', '${dash.totalStops}'),
                        _RouteLine(Icons.check_circle_outline, 'Visited', '${dash.visitedCount}'),
                        _RouteLine(Icons.timelapse, 'Remaining', '${dash.remainingStops}'),
                        _RouteLine(Icons.alt_route, 'Estimated Distance', '${dash.remainingDistanceKm} km remaining'),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: SizedBox(
                        height: 148,
                        child: Stack(
                          children: [
                            Positioned.fill(child: LiveRouteMap(pins: pins, height: 148)),
                            Positioned(
                              right: 8,
                              bottom: 8,
                              child: Material(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                child: InkWell(
                                  onTap: () {
                                    final name = dash.nextStopName;
                                    if (name == null) {
                                      onOpenMap?.call();
                                      return;
                                    }
                                    openStopInGoogleMaps(
                                      context,
                                      name: name,
                                      address: dash.nextAddress ?? dash.routeName,
                                      latitude: dash.nextLatitude,
                                      longitude: dash.nextLongitude,
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(20),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    child: Text('View Route →', style: routeType(12, FontWeight.w700, const Color(0xFF0875DC), 16)),
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              left: 8,
                              top: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xF2FFFFFF),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  dash.nextStopName == null
                                      ? 'No pending stop'
                                      : 'Next: ${dash.nextStopName} (${dash.nextDistanceMeters ?? 0}m)',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: routeType(11, FontWeight.w700, const Color(0xFF0C2F66), 14),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Icon(Icons.bolt, size: 18, color: Color(0xFF0875DC)),
            const SizedBox(width: 6),
            Text('Quick Actions', style: routeType(19, FontWeight.w700, const Color(0xFF10264A), 24)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _ActionTile(
                Icons.checklist_rounded,
                'To-Do List',
                '${dash.openTodoCount} items open',
                image: 'assets/home/icon_todo.png',
                badge: dash.openTodoCount > 0 ? '${dash.openTodoCount}' : null,
                onTap:
                    onOpenTodo ??
                    () => pushRoute(
                      context,
                      const RouteQueueScreen(standalone: true),
                    ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ActionTile(
                Icons.history,
                'Audit Logs',
                'Reconciliation',
                image: 'assets/home/icon_audit.png',
                onTap: () => pushRoute(context, const HistoryScreen()),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ActionTile(
                Icons.account_balance_wallet_outlined,
                'Ledgers',
                'Credit checks',
                image: 'assets/home/icon_ledger.png',
                onTap: () => pushRoute(context, const LedgerScreen()),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const IgnorePointer(
          child: Opacity(
            opacity: 0.9,
            child: Image(image: AssetImage('assets/home/wave_footer.png'), height: 72, fit: BoxFit.cover),
          ),
        ),
      ],
      ),
      ),
      ],
    );
  }

  String _longDate(String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value;
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${weekdays[parsed.weekday - 1]}, ${parsed.day} ${months[parsed.month - 1]} ${parsed.year}';
  }
}

class _DutyOperations extends StatefulWidget {
  const _DutyOperations({required this.shiftOpen, this.onOpenMap});

  final bool shiftOpen;
  final VoidCallback? onOpenMap;

  @override
  State<_DutyOperations> createState() => _DutyOperationsState();
}

class _DutyOperationsState extends State<_DutyOperations> {
  var _preShift = true;

  @override
  Widget build(BuildContext context) {
    final preShift = _preShift;
    return RouteCard(
      color: const Color(0xFFF4F8FF),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Duty Operations',
                style: routeType(
                  11,
                  FontWeight.w700,
                  RouteColors.primary,
                  16,
                  0.4,
                ),
              ),
              const Spacer(),
              _HomeChip(
                'Pre-Shift',
                preShift,
                onTap: () => setState(() => _preShift = true),
              ),
              const SizedBox(width: 6),
              _HomeChip(
                'En-Route',
                !preShift,
                onTap: () => setState(() => _preShift = false),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (preShift)
                Image.asset('assets/home/jugs.png', width: 108, height: 120, fit: BoxFit.contain)
              else
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.route, color: RouteColors.primary),
                ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (preShift)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Image.asset('assets/home/icon_checklist.png', width: 28, height: 28, fit: BoxFit.contain),
                      ),
                    Text(
                      preShift
                          ? 'Ready to Start Your Day?'
                          : 'Route is in progress',
                      style: routeType(
                        16,
                        FontWeight.w700,
                        RouteColors.ink,
                        22,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      preShift
                          ? "Audit your van stock, review the scheduled manifest, and begin today's route navigation."
                          : 'The van is on the route. Open the map to reach the next stop.',
                      style: routeType(
                        13,
                        FontWeight.w400,
                        RouteColors.body,
                        18,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF0752B8), Color(0xFF0875DC)]),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: preShift
                    ? () => _openStartDay(context)
                    : () => _openEnRoute(context, widget.shiftOpen, widget.onOpenMap),
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  height: 48,
                  child: Row(
                    children: [
                      const SizedBox(width: 14),
                      Icon(preShift ? Icons.play_arrow_rounded : Icons.map_outlined, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          preShift ? 'Start Day & Load Inventory' : 'Open Route Map',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: routeType(15, FontWeight.w600, Colors.white, 20),
                        ),
                      ),
                      const Icon(Icons.arrow_forward, color: Colors.white, size: 18),
                      const SizedBox(width: 14),
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

Future<void> _openStartDay(BuildContext context) async {
  await Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => const StartDayScreen()));
  if (context.mounted) FieldScope.of(context).loadHome();
}

void _openEnRoute(
  BuildContext context,
  bool shiftOpen,
  VoidCallback? onOpenMap,
) {
  if (!shiftOpen) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Finish the pre-shift checklist and start the day before going en route.',
        ),
      ),
    );
    return;
  }
  onOpenMap?.call();
}

class _HomeChip extends StatelessWidget {
  const _HomeChip(this.label, this.active, {this.onTap});

  final String label;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: active ? const Color(0xFF0875DC) : const Color(0xFFF3F5F8),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: routeType(
          11,
          FontWeight.w600,
          active ? Colors.white : const Color(0xFF66758D),
          14,
        ),
      ),
    );
    if (onTap == null) return chip;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: chip,
      ),
    );
  }
}

class _MoneyCard extends StatelessWidget {
  const _MoneyCard(this.icon, this.value, this.label, this.note, this.valueColor, {this.image});

  final IconData icon;
  final String value;
  final String label;
  final String note;
  final Color valueColor;
  final String? image;

  @override
  Widget build(BuildContext context) {
    return _MiniStat(
      icon: icon,
      value: value,
      label: label,
      note: note,
      color: valueColor,
      image: image,
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard(this.icon, this.value, this.badge, this.label, this.color, {this.note, this.image, this.background = Colors.white});

  final IconData icon;
  final String value;
  final String? badge;
  final String label;
  final Color color;
  final String? note;
  final String? image;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return _MiniStat(
      icon: icon,
      value: value,
      label: label,
      note: note ?? '',
      color: color,
      badge: badge,
      image: image,
      background: background,
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.icon,
    required this.value,
    required this.label,
    required this.note,
    required this.color,
    this.badge,
    this.image,
    this.background = Colors.white,
  });

  final IconData icon;
  final String value;
  final String label;
  final String note;
  final Color color;
  final String? badge;
  final String? image;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return RouteCard(
      color: background,
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              image == null
                  ? Icon(icon, size: 16, color: color)
                  : Image.asset(image!, width: 22, height: 22, fit: BoxFit.contain),
              const Spacer(),
              if (badge != null)
                Text(badge!, style: routeType(10, FontWeight.w700, color, 14)),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: routeType(16, FontWeight.w700, color, 20)),
          ),
          Text(label, maxLines: 2, style: routeType(11, FontWeight.w700, const Color(0xFF0C2F66), 14)),
          if (note.isNotEmpty)
            Text(note, maxLines: 2, style: routeType(10, FontWeight.w500, RouteColors.secondary, 13)),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile(
    this.icon,
    this.title,
    this.subtitle, {
    required this.onTap,
    this.badge,
    this.image,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String? badge;
  final String? image;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: RouteColors.pale,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: image == null
                        ? Icon(icon, color: RouteColors.primary, size: 18)
                        : Image.asset(image!, width: 22, height: 22, fit: BoxFit.contain),
                  ),
                  if (badge != null) ...[
                    const Spacer(),
                    CircleAvatar(
                      radius: 10,
                      backgroundColor: const Color(0xFF0B74E8),
                      child: Text(badge!, style: routeType(10, FontWeight.w700, Colors.white, 12)),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Text(title, style: routeType(13, FontWeight.w700, const Color(0xFF0C2F66), 16)),
              Text(subtitle, style: routeType(11, FontWeight.w500, RouteColors.secondary, 14)),
            ],
          ),
        ),
      ),
    );
  }
}

class _RouteLine extends StatelessWidget {
  const _RouteLine(this.icon, this.label, this.value);

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF0B74E8)),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: routeType(11, FontWeight.w600, RouteColors.secondary, 14)),
                Text(value, style: routeType(13, FontWeight.w700, const Color(0xFF0C2F66), 16)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: routeType(11, FontWeight.w600, RouteColors.secondary, 16, 0.4),
        ),
        Text(value, style: routeType(14, FontWeight.w600, RouteColors.ink, 20)),
      ],
    );
  }
}

class RouteQueueScreen extends StatefulWidget {
  const RouteQueueScreen({
    this.standalone = false,
    this.onOpenProfile,
    super.key,
  });

  final bool standalone;
  final VoidCallback? onOpenProfile;

  @override
  State<RouteQueueScreen> createState() => _RouteQueueScreenState();
}

class _RouteQueueScreenState extends State<RouteQueueScreen> {
  final _searchFocus = FocusNode();
  final _scroll = ScrollController();
  var _loaded = false;
  var _zone = 'All Zones';
  var _span = 'Today';
  var _missed = 0;
  var _drafts = 0;
  var _orders = 0;
  var _reordering = false;
  var _savingOrder = false;
  var _ledgerOpen = false;
  List<StopItem>? _draft;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    final store = FieldScope.of(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) store.loadStops();
    });
  }

  @override
  void dispose() {
    _searchFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = FieldScope.of(context);
    if ((store.settings?.showOrdersTab ?? true) == false &&
        store.stopFilter == 'orders') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && store.stopFilter == 'orders') {
          _selectFilter(store, 'orders');
        }
      });
    }
    final dash = store.dashboard;
    final completed =
        dash?.visitedCount ??
        store.stops.where((stop) => stop.status == 'Completed').length;
    final total = dash?.totalStops ?? store.stops.length;
    final remaining = dash?.remainingStops ?? (total - completed);
    final progress = total == 0 ? 0 : (completed / total * 100).round();
    if (store.stopFilter == 'all') {
      _missed = store.stops.where((stop) => stop.status == 'Missed').length;
    } else if (store.stopFilter == 'missed') {
      _missed = store.stops.length;
    } else if (store.stopFilter == 'drafts') {
      _drafts = store.stops.length;
    } else if (store.stopFilter == 'orders') {
      _orders = store.stops.length;
    }
    final visible = store.stops.where((stop) {
      if (_span == 'History' && stop.status != 'Completed') return false;
      if (_zone == 'All Zones') return true;
      final token = _zone == 'VIP Key Accounts' ? 'vip' : _zone.toLowerCase();
      final haystack = '${stop.customerName} ${stop.address}'.toLowerCase();
      return haystack.contains(token);
    }).toList();
    final shown = _reordering ? (_draft ?? store.stops) : visible;
    final pendingDue = store.stops
        .where((stop) => stop.status != 'Completed')
        .fold<num>(0, (sum, stop) => sum + stop.outstanding);
    final page = Stack(
      children: [
        const Positioned.fill(
          child: Image(image: AssetImage('assets/home/background.png'), fit: BoxFit.cover),
        ),
        const Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: Opacity(
              opacity: 0.5,
              child: Image(image: AssetImage('assets/home/wave_header.png'), height: 140, fit: BoxFit.cover),
            ),
          ),
        ),
        Column(
      children: [
        Expanded(
          child: ReorderableListView(
            scrollController: _scroll,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            buildDefaultDragHandles: false,
            onReorderItem: _applyReorder,
            proxyDecorator: (child, index, animation) => Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(20),
              child: child,
            ),
            header: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              if (!widget.standalone)
                Row(
                  children: [
                    Image.asset('assets/home/logo.png', height: 44, fit: BoxFit.contain),
                    const Spacer(),
                    IconButton(
                      onPressed: _searchFocus.requestFocus,
                      icon: Image.asset('assets/home/icon_search.png', width: 32, height: 32, fit: BoxFit.contain),
                    ),
                    const RiderInboxButton(),
                    const SizedBox(width: 4),
                    IconButton(
                      onPressed: widget.onOpenProfile,
                      icon: Image.asset('assets/home/icon_profile.png', width: 32, height: 32, fit: BoxFit.contain),
                    ),
                  ],
                ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.format_list_bulleted, color: Color(0xFF0B74E8)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('To-Do List & Route Queue', style: routeType(20, FontWeight.w700, const Color(0xFF0C2F66), 24)),
                        Text(
                          "Manage today's deliveries, reorder stops and complete your route.",
                          style: routeType(12, FontWeight.w500, RouteColors.secondary, 16),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const SizedBox(
                    width: 72,
                    height: 64,
                    child: Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        Positioned(right: 0, bottom: 10, child: Image(image: AssetImage('assets/welcome/leaf.png'), width: 22)),
                        Positioned(left: 8, right: 10, top: 0, bottom: 12, child: Image(image: AssetImage('assets/welcome/jug.png'), fit: BoxFit.contain)),
                        Positioned(left: 0, right: 0, bottom: 0, child: Image(image: AssetImage('assets/welcome/splash.png'), height: 18, fit: BoxFit.contain)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _InfoChip(icon: Icons.calendar_today_outlined, label: _queueDate(dash?.serviceDate)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _InfoChip(
                      icon: Icons.location_on_outlined,
                      label: dash?.routeName ?? 'Assigned route',
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: const Color(0xFFE5F6EC), borderRadius: BorderRadius.circular(999)),
                        child: Text('Active Sector', style: routeType(10, FontWeight.w700, RouteColors.ok, 13)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              RouteCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: ColoredBox(
                            color: const Color(0xFFE8F3FF),
                            child: Image.asset(
                              'assets/welcome/truck.png',
                              width: 104,
                              height: 92,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Route Execution',
                                style: routeType(
                                  15,
                                  FontWeight.w700,
                                  RouteColors.ink,
                                  20,
                                ),
                              ),
                              Text(
                                '$completed of $total customer visits completed',
                                style: routeType(
                                  12,
                                  FontWeight.w500,
                                  RouteColors.secondary,
                                  16,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '$progress%',
                          style: routeType(
                            22,
                            FontWeight.w700,
                            RouteColors.primary,
                            28,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: total == 0 ? 0 : completed / total,
                        minHeight: 6,
                        color: const Color(0xFF0B74E8),
                        backgroundColor: const Color(0xFFD7E8FA),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _execBox('$completed', 'Completed', Icons.check_circle, RouteColors.ok),
                        const SizedBox(width: 8),
                        _execBox('$remaining', 'Remaining', Icons.schedule, const Color(0xFF0B74E8)),
                        const SizedBox(width: 8),
                        _execBox('$total', 'Total Stops', Icons.alt_route, const Color(0xFF0B74E8)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _SearchBox(
                      'Search name, code, phone or address...',
                      focusNode: _searchFocus,
                      onChanged: (value) {
                        store.stopSearch = value;
                        store.loadStops();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: RouteColors.line),
                    ),
                    child: IconButton(
                      onPressed: _searchFocus.requestFocus,
                      icon: const Icon(Icons.tune, color: Color(0xFF0C2F66)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_reordering) ...[
                    TextButton(
                      onPressed: _savingOrder ? null : () => setState(() {
                        _reordering = false;
                        _draft = null;
                      }),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: _savingOrder ? null : () => _saveOrder(store),
                      style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0875DC), foregroundColor: Colors.white),
                      child: Text(_savingOrder ? 'Saving...' : 'Save Order'),
                    ),
                  ] else
                    FilledButton.icon(
                      onPressed: () => _beginReorder(store),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0875DC),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                      icon: const Icon(Icons.swap_vert, size: 18),
                      label: Text(MediaQuery.sizeOf(context).width < 420 ? 'Reorder' : 'Reorder Routes'),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final zone in const [
                      'All Zones',
                      'Zone A',
                      'Zone B',
                      'VIP Key Accounts',
                    ]) ...[
                      _queuePill(
                        zone,
                        _zone == zone,
                        () => setState(() => _zone = zone),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _segment(
                    'Today',
                    '$total',
                    _span == 'Today',
                    () => _selectSpan(store, 'Today'),
                  ),
                  const SizedBox(width: 8),
                  _segment(
                    'History',
                    '$completed',
                    _span == 'History',
                    () => _selectSpan(store, 'History'),
                  ),
                  const SizedBox(width: 8),
                  _segment(
                    'All Stops',
                    '$total',
                    _span == 'All',
                    () => _selectSpan(store, 'All'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _countLink(
                    'Missed',
                    _missed,
                    store.stopFilter == 'missed',
                    RouteColors.danger,
                    Icons.cancel_outlined,
                    () => _selectFilter(store, 'missed'),
                  ),
                  _countLink(
                    'Drafts',
                    _drafts,
                    store.stopFilter == 'drafts',
                    RouteColors.secondary,
                    Icons.description_outlined,
                    () => _selectFilter(store, 'drafts'),
                  ),
                  if (store.settings?.showOrdersTab ?? true)
                    _countLink(
                      'Orders',
                      _orders,
                      store.stopFilter == 'orders',
                      RouteColors.primary,
                      Icons.shopping_cart_outlined,
                      () => _selectFilter(store, 'orders'),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (visible.isEmpty)
                Text(
                  store.loading
                      ? 'Loading stops...'
                      : 'No stops match this view.',
                  style: routeType(
                    14,
                    FontWeight.w500,
                    RouteColors.secondary,
                    20,
                  ),
                ),
              ],
            ),
            children: [
              for (var index = 0; index < shown.length; index++)
                _StopCard(
                  key: ValueKey('queue-${shown[index].id}'),
                  stop: shown[index],
                  dragIndex: _reordering && shown[index].status != 'Completed' ? index : null,
                  buttonKey: shown[index].customerCode == 'CUS-1001'
                      ? const Key('stop-ali')
                      : null,
                  onOpen: () => _openStop(store, shown[index]),
                  onInvoice: () => _openInvoice(shown[index]),
                  onShare: () => _shareInvoice(shown[index]),
                  onPrint: () => _openInvoice(shown[index]),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Material(
            color: const Color(0xFF10233A),
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: () => setState(() => _ledgerOpen = !_ledgerOpen),
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.circle, color: RouteColors.ok, size: 10),
                        const SizedBox(width: 8),
                        Text('Day Ledger', style: routeType(13, FontWeight.w700, Colors.white, 16)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Sold: ${_compact(dash?.billedSales ?? 0)}   Cash: ${_compact(dash?.cashCollected ?? 0)}',
                            style: routeType(12, FontWeight.w600, const Color(0xFFD5DDEA), 16),
                          ),
                        ),
                        Icon(_ledgerOpen ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up, color: Colors.white),
                      ],
                    ),
                    if (_ledgerOpen) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Sales: ${_compact(dash?.billedSales ?? 0)}   Cash: ${_compact(dash?.cashCollected ?? 0)}   Still to collect: ${_compact(pendingDue)}',
                        style: routeType(12, FontWeight.w500, const Color(0xFFD5DDEA), 16),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
      ),
      ],
    );
    if (!widget.standalone) return page;
    return RoutePage(title: 'To-Do List & Route Queue', body: page);
  }

  void _selectSpan(FieldStore store, String span) {
    setState(() => _span = span);
    if (store.stopFilter != 'all') {
      store.stopFilter = 'all';
      store.loadStops();
    }
  }

  void _selectFilter(FieldStore store, String filter) {
    if (_reordering) return;
    store.stopFilter = store.stopFilter == filter ? 'all' : filter;
    store.loadStops();
  }

  Future<void> _beginReorder(FieldStore store) async {
    if (store.stopFilter != 'all') {
      store.stopFilter = 'all';
      await store.loadStops();
    }
    if (!mounted) return;
    if (store.stops.length < 2) {
      _opsNote(context, 'There are not enough stops to reorder.');
      return;
    }
    setState(() {
      _zone = 'All Zones';
      _span = 'All';
      _reordering = true;
      _draft = List<StopItem>.of(store.stops);
    });
  }

  Future<void> _saveOrder(FieldStore store) async {
    final draft = _draft;
    if (_savingOrder || draft == null) return;
    setState(() => _savingOrder = true);
    await store.saveStopOrder(draft.map((stop) => stop.id).toList());
    if (!mounted) return;
    final problem = store.error;
    setState(() {
      _savingOrder = false;
      if (problem == null) {
        _reordering = false;
        _draft = null;
      }
    });
    _opsNote(context, problem ?? 'Stop order saved.');
  }

  void _applyReorder(int oldIndex, int newIndex) {
    final draft = _draft;
    if (!_reordering || draft == null) return;
    if (oldIndex < 0 || oldIndex >= draft.length || newIndex < 0 || newIndex >= draft.length) return;
    if (draft[oldIndex].status == 'Completed') {
      _opsNote(context, 'Completed stops stay in place.');
      return;
    }
    final next = List<StopItem>.of(draft);
    final moved = next.removeAt(oldIndex);
    next.insert(newIndex, moved);
    final before = draft.where((stop) => stop.status == 'Completed').map((stop) => stop.id).join('|');
    final after = next.where((stop) => stop.status == 'Completed').map((stop) => stop.id).join('|');
    if (before != after) {
      _opsNote(context, 'Completed stops stay in place.');
      return;
    }
    setState(() => _draft = next);
  }

  Future<void> _openStop(FieldStore store, StopItem stop) async {
    await store.openStop(stop);
    if (!mounted) return;
    pushRoute(context, const CustomerOpsScreen());
  }

  Future<ReceiptData?> _receiptFor(StopItem stop) async {
    final id = stop.receiptSaleId;
    if (id == null || id.isEmpty) {
      _opsNote(
        context,
        '${stop.customerName} has no completed receipt on this stop.',
      );
      return null;
    }
    try {
      final receipt = await ApiScope.of(context).receipt(id);
      if (!mounted) return null;
      FieldScope.of(context).receipt = receipt;
      return receipt;
    } on ApiException catch (error) {
      if (mounted) _opsNote(context, error.message);
      return null;
    }
  }

  Future<void> _openInvoice(StopItem stop) async {
    final receipt = await _receiptFor(stop);
    if (!mounted || receipt == null) return;
    pushRoute(context, ReceiptScreen(amount: receipt.amountReceived.round()));
  }

  Future<void> _shareInvoice(StopItem stop) async {
    final receipt = await _receiptFor(stop);
    if (!mounted || receipt == null) return;
    await _shareReceipt(receipt);
  }

  Widget _execBox(String value, String label, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F7FB),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: color),
            Text(value, style: routeType(18, FontWeight.w700, color, 22)),
            Text(label, style: routeType(11, FontWeight.w500, RouteColors.secondary, 14)),
          ],
        ),
      ),
    );
  }

  Widget _queuePill(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? RouteColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? RouteColors.primary : RouteColors.line,
          ),
        ),
        child: Text(
          label,
          style: routeType(
            12,
            FontWeight.w600,
            selected ? Colors.white : RouteColors.ink,
            16,
          ),
        ),
      ),
    );
  }

  Widget _segment(
    String label,
    String count,
    bool selected,
    VoidCallback onTap,
  ) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? RouteColors.primary : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? RouteColors.primary : RouteColors.line,
            ),
          ),
          child: Text(
            '$label  $count',
            style: routeType(
              12,
              FontWeight.w700,
              selected ? Colors.white : RouteColors.ink,
              16,
            ),
          ),
        ),
      ),
    );
  }

  Widget _countLink(
    String label,
    int count,
    bool selected,
    Color color,
    IconData icon,
    VoidCallback onTap,
  ) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: routeType(
                  12,
                  FontWeight.w600,
                  selected ? color : RouteColors.secondary,
                  16,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count',
                  style: routeType(11, FontWeight.w700, color, 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _queueDate(String? value) {
    final parsed = DateTime.tryParse(value ?? '');
    if (parsed == null) return (value ?? 'TODAY').toUpperCase();
    const days = [
      'MONDAY',
      'TUESDAY',
      'WEDNESDAY',
      'THURSDAY',
      'FRIDAY',
      'SATURDAY',
      'SUNDAY',
    ];
    const months = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];
    String title(String value) =>
        value.isEmpty ? value : '${value[0]}${value.substring(1).toLowerCase()}';
    return '${title(days[parsed.weekday - 1])}, ${parsed.day} ${title(months[parsed.month - 1])} ${parsed.year}';
  }

  String _compact(num amount) {
    if (amount.abs() >= 1000) {
      final scaled = amount / 1000;
      final text = scaled == scaled.roundToDouble()
          ? scaled.toStringAsFixed(0)
          : scaled.toStringAsFixed(1);
      return 'PKR ${text}k';
    }
    return _pkr(amount);
  }
}

class _StopFact extends StatelessWidget {
  const _StopFact({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor = const Color(0xFF0C2F66),
  });

  final IconData icon;
  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 13, color: const Color(0xFF0B74E8)),
            const SizedBox(width: 4),
            Flexible(
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: routeType(10, FontWeight.w500, RouteColors.muted, 13)),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(value, maxLines: 2, overflow: TextOverflow.ellipsis, style: routeType(12, FontWeight.w700, valueColor, 16)),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label, this.trailing});

  final IconData icon;
  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFD7E6F4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF0B74E8)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: routeType(12, FontWeight.w600, const Color(0xFF0C2F66), 16)),
          ),
          if (trailing != null) ...[const SizedBox(width: 6), trailing!],
        ],
      ),
    );
  }
}

class _SearchBox extends StatelessWidget {
  const _SearchBox(this.hint, {this.onChanged, this.focusNode});

  final String hint;
  final ValueChanged<String>? onChanged;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    return TextField(
      focusNode: focusNode,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: routeType(14, FontWeight.w400, RouteColors.muted, 20),
        prefixIcon: const Icon(
          Icons.search,
          color: RouteColors.muted,
          size: 20,
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: RouteColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: RouteColors.line),
        ),
      ),
    );
  }
}

class _StopCard extends StatelessWidget {
  const _StopCard({
    required this.stop,
    required this.onOpen,
    this.onInvoice,
    this.onShare,
    this.onPrint,
    this.buttonKey,
    this.dragIndex,
    super.key,
  });

  final StopItem stop;
  final VoidCallback onOpen;
  final VoidCallback? onInvoice;
  final VoidCallback? onShare;
  final VoidCallback? onPrint;
  final Key? buttonKey;
  final int? dragIndex;

  @override
  Widget build(BuildContext context) {
    final status = stop.status == 'InProgress' ? 'In Progress' : stop.status;
    final settled = stop.outstanding <= 0;
    final completed = stop.status == 'Completed';
    final active = stop.status == 'InProgress';
    final pending = !completed && !active && stop.status != 'Missed';
    final tone = completed || active
        ? RouteColors.ok
        : stop.status == 'Missed'
        ? RouteColors.danger
        : const Color(0xFFE08A00);
    final chipColor = completed || active
        ? const Color(0xFFE5F6EC)
        : stop.status == 'Missed'
        ? const Color(0xFFFDECEC)
        : const Color(0xFFFFF4E5);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: RouteCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (dragIndex != null)
                  ReorderableDragStartListener(
                    index: dragIndex!,
                    child: const Padding(
                      padding: EdgeInsets.only(right: 4),
                      child: Icon(Icons.drag_indicator, color: Color(0xFF66758D)),
                    ),
                  ),
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F3FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    stop.sequence.toString().padLeft(2, '0'),
                    style: routeType(14, FontWeight.w700, const Color(0xFF0B74E8), 18),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stop.customerName,
                        style: routeType(
                          15,
                          FontWeight.w700,
                          RouteColors.ink,
                          20,
                        ),
                      ),
                      Text(
                        stop.customerCode,
                        style: routeType(
                          12,
                          FontWeight.w500,
                          RouteColors.secondary,
                          16,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: chipColor,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(pending ? Icons.schedule : completed ? Icons.check_circle : Icons.info_outline, size: 12, color: tone),
                      const SizedBox(width: 4),
                      Text(status, style: routeType(11, FontWeight.w700, tone, 14)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 14,
                  color: RouteColors.primary,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    stop.address,
                    style: routeType(
                      12,
                      FontWeight.w500,
                      RouteColors.secondary,
                      16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _StopFact(
                    icon: Icons.calendar_today_outlined,
                    label: completed ? 'Completed At' : 'Scheduled',
                    value: stop.scheduledTime ?? '—',
                  ),
                ),
                Expanded(
                  child: _StopFact(
                    icon: Icons.water_drop_outlined,
                    label: 'Returnable',
                    value: completed
                        ? '${stop.emptyBottles} Collected'
                        : '${stop.emptyBottles} Empty Bottles',
                  ),
                ),
                Expanded(
                  child: _StopFact(
                    icon: Icons.payments_outlined,
                    label: completed ? 'Ledger' : 'Outstanding',
                    value: settled ? 'PKR 0' : _pkr(stop.outstanding),
                    valueColor: settled ? RouteColors.ok : RouteColors.danger,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (completed)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      key: buttonKey,
                      onPressed: onInvoice ?? onOpen,
                      icon: const Icon(Icons.receipt_long_outlined, size: 16),
                      label: Text(
                        stop.invoiceNumber == null
                            ? stop.actionLabel
                            : 'View Invoice #${stop.invoiceNumber}',
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Share receipt',
                    onPressed: onShare ?? onOpen,
                    icon: const Icon(
                      Icons.share_outlined,
                      color: RouteColors.secondary,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Print receipt',
                    onPressed: onPrint ?? onOpen,
                    icon: const Icon(
                      Icons.print_outlined,
                      color: RouteColors.secondary,
                    ),
                  ),
                ],
              )
            else if (active)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onOpen,
                      child: const Text('Stock Audit'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      key: buttonKey,
                      style: FilledButton.styleFrom(
                        backgroundColor: RouteColors.ok,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: onOpen,
                      child: Text(stop.actionLabel),
                    ),
                  ),
                ],
              )
            else
              Row(
                children: [
                  IconButton(
                    onPressed: () => launchUrl(
                      Uri(scheme: 'tel', path: stop.phone.replaceAll(' ', '')),
                      mode: LaunchMode.externalApplication,
                    ),
                    icon: const Icon(
                      Icons.phone_outlined,
                      color: RouteColors.primary,
                    ),
                  ),
                  IconButton(
                    onPressed: () => openStopInGoogleMaps(
                      context,
                      name: stop.customerName,
                      address: stop.address,
                      latitude: stop.latitude,
                      longitude: stop.longitude,
                    ),
                    icon: const Icon(
                      Icons.navigation_outlined,
                      color: RouteColors.primary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: 'Stop details',
                    onPressed: onOpen,
                    icon: const Icon(Icons.info_outline, color: Color(0xFF0B74E8)),
                  ),
                  Expanded(
                    child: FilledButton.icon(
                      key: buttonKey,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0B74E8),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                      ),
                      onPressed: onOpen,
                      icon: const Icon(Icons.play_arrow_rounded, size: 18),
                      label: Text(stop.actionLabel),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class CustomerOpsScreen extends StatefulWidget {
  const CustomerOpsScreen({super.key});

  @override
  State<CustomerOpsScreen> createState() => _CustomerOpsScreenState();
}

class _CustomerOpsScreenState extends State<CustomerOpsScreen> {
  var _logWithoutSale = true;

  @override
  Widget build(BuildContext context) {
    final store = FieldScope.of(context);
    final customer = store.customer;
    if (customer == null) {
      return const RoutePage(
        title: 'Customer Operations',
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final photo = store.storefronts[customer.id];
    final address = '${customer.street}, ${customer.area}, ${customer.city}';
    final due = customer.outstanding;
    final hasOrder = customer.nextOrderQuantity > 0 || customer.openOrders > 0;
    final orderQty = customer.nextOrderQuantity > 0
        ? customer.nextOrderQuantity
        : customer.openOrders;
    final orderName = customer.nextOrderProduct ?? 'Scheduled order';
    final orderDate = _prettyDate(customer.nextOrderDate);
    final bottleLabel = customer.bottleOwnership.trim().isEmpty
        ? 'Standard 19L'
        : customer.bottleOwnership;
    return RoutePage(
      body: Stack(
        children: [
          const Positioned.fill(
            child: Image(image: AssetImage('assets/home/ops_background.jpg'), fit: BoxFit.cover),
          ),
          ListView(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back, color: Color(0xFF0C2F66)),
              ),
              Image.asset('assets/home/logo.png', height: 42, fit: BoxFit.contain),
              const Spacer(),
              IconButton(
                onPressed: () => pushRoute(context, const SettingsScreen()),
                icon: Image.asset('assets/home/icon_profile.png', width: 32, height: 32, fit: BoxFit.contain),
              ),
              const SizedBox(width: 8),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(width: 8),
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F3FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.groups_outlined, color: Color(0xFF0B74E8), size: 20),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Customer Operations', style: routeType(22, FontWeight.w700, const Color(0xFF10264A), 26)),
                    Text(
                      'Manage customer, delivery, sales and collections',
                      style: routeType(12, FontWeight.w500, RouteColors.secondary, 16),
                    ),
                  ],
                ),
              ),
              Image.asset('assets/welcome/splash.png', width: 72, height: 48, fit: BoxFit.contain),
            ],
          ),
          const SizedBox(height: 10),
          RouteCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F3FF),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.storefront_outlined, color: Color(0xFF0B74E8), size: 32),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  customer.businessName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: routeType(16, FontWeight.w700, const Color(0xFF0C2F66), 20),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(customer.code, style: routeType(12, FontWeight.w600, RouteColors.secondary, 16)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE8F3FF),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(customer.category, style: routeType(11, FontWeight.w600, const Color(0xFF0B74E8), 14)),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE5F6EC),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  customer.status.isEmpty ? 'Active Customer' : customer.status,
                                  style: routeType(11, FontWeight.w700, RouteColors.ok, 14),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => showModalBottomSheet<void>(
                        context: context,
                        builder: (sheet) => SafeArea(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ListTile(
                                leading: const Icon(
                                  Icons.edit_outlined,
                                  color: RouteColors.primary,
                                ),
                                title: const Text('Edit customer'),
                                onTap: () {
                                  Navigator.of(sheet).pop();
                                  pushRoute(
                                    context,
                                    const CustomerFormScreen(),
                                  );
                                },
                              ),
                              ListTile(
                                leading: const Icon(
                                  Icons.menu_book_outlined,
                                  color: RouteColors.primary,
                                ),
                                title: const Text('Customer ledger'),
                                onTap: () {
                                  Navigator.of(sheet).pop();
                                  pushRoute(context, const LedgerScreen());
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      icon: const Icon(
                        Icons.more_horiz,
                        color: RouteColors.secondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.phone_outlined, size: 15, color: Color(0xFF0B74E8)),
                    const SizedBox(width: 4),
                    Flexible(
                      child: InkWell(
                        onTap: () => launchUrl(
                          Uri(scheme: 'tel', path: customer.phone.replaceAll(' ', '')),
                          mode: LaunchMode.externalApplication,
                        ),
                        child: Text(customer.phone, maxLines: 1, overflow: TextOverflow.ellipsis, style: routeType(12, FontWeight.w600, const Color(0xFF0C2F66), 16)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.location_on_outlined, size: 15, color: Color(0xFF0B74E8)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(address, maxLines: 2, overflow: TextOverflow.ellipsis, style: routeType(12, FontWeight.w500, RouteColors.body, 16)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF0B74E8),
                          foregroundColor: Colors.white,
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                        ),
                        onPressed: () => openStopInGoogleMaps(
                          context,
                          name: customer.businessName,
                          address: address,
                          latitude: customer.latitude,
                          longitude: customer.longitude,
                        ),
                        icon: const Icon(Icons.near_me_outlined, size: 15),
                        label: const FittedBox(child: Text('Go to Location')),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF0C2F66),
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                          side: const BorderSide(color: Color(0xFFD7E6F4)),
                        ),
                        onPressed: () => launchUrl(
                          Uri(scheme: 'tel', path: customer.phone.replaceAll(' ', '')),
                          mode: LaunchMode.externalApplication,
                        ),
                        icon: const Icon(Icons.phone_outlined, size: 15),
                        label: const Text('Call'),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF0C2F66),
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                          side: const BorderSide(color: Color(0xFFD7E6F4)),
                        ),
                        onPressed: () => _saveShopLocation(context, customer),
                        icon: const Icon(Icons.add_location_alt_outlined, size: 15),
                        label: const FittedBox(child: Text('Set Location')),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _opsStat(
                  'Due Balance',
                  _pkr(due),
                  due <= 0 ? 'Settled' : 'Payment Pending',
                  due <= 0 ? RouteColors.ok : RouteColors.danger,
                  Icons.account_balance_wallet_outlined,
                  valueColor: due <= 0 ? RouteColors.ok : RouteColors.danger,
                  background: due <= 0 ? Colors.white : const Color(0xFFFFF1F1),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _opsStat(
                  'Last Drop',
                  _prettyDate(customer.lastDropAt?.toIso8601String()) == '—'
                      ? 'None'
                      : _prettyDate(customer.lastDropAt?.toIso8601String()),
                  _ago(customer.lastDropAt),
                  RouteColors.secondary,
                  Icons.calendar_today_outlined,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _opsStat(
                  'Open Orders',
                  '${customer.openOrders}',
                  customer.openOrders == 0 ? 'None open' : 'Action Required',
                  RouteColors.primary,
                  Icons.shopping_bag_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          RouteCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Image.asset('assets/home/jugs.png', width: 78, height: 92, fit: BoxFit.contain),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.inventory_2_outlined, size: 16, color: Color(0xFF0B74E8)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text('Container & Asset Balance', style: routeType(13, FontWeight.w700, const Color(0xFF0C2F66), 18)),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF4F7FB),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: const Color(0xFFD7E6F4)),
                                ),
                                child: Text(bottleLabel, style: routeType(10, FontWeight.w600, RouteColors.secondary, 13)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _bottleBox('Issued', '${customer.bottlesIssued}', 'Cumulative', Icons.upload_outlined),
                              const SizedBox(width: 6),
                              _bottleBox('Returned', '${customer.bottlesReturned}', 'Collected', Icons.download_outlined),
                              const SizedBox(width: 6),
                              _bottleBox('Holds', '${customer.bottlesHeld}', 'At Store', Icons.person_outline, emphasize: true),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (hasOrder) ...[
            const SizedBox(height: 8),
            RouteCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.local_shipping_outlined,
                        size: 16,
                        color: RouteColors.primary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Pending Delivery Order',
                          style: routeType(
                            14,
                            FontWeight.w700,
                            RouteColors.ink,
                            20,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF4E5),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.schedule, size: 12, color: Color(0xFFE08A00)),
                            const SizedBox(width: 4),
                            Text(
                              'Pending Delivery',
                              style: routeType(10, FontWeight.w700, const Color(0xFFE08A00), 14),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Image.asset('assets/welcome/jug.png', width: 44, height: 52, fit: BoxFit.contain),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(orderName, style: routeType(14, FontWeight.w700, const Color(0xFF0C2F66), 20)),
                            Text(
                              orderDate == '—' ? 'Expected on the next visit' : 'Expected Delivery: $orderDate',
                              style: routeType(12, FontWeight.w500, RouteColors.secondary, 16),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        children: [
                          Text('$orderQty', style: routeType(22, FontWeight.w700, const Color(0xFF0C2F66), 26)),
                          Text('Units', style: routeType(11, FontWeight.w500, RouteColors.secondary, 14)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFE8F1FF),
                        foregroundColor: RouteColors.primary,
                      ),
                      onPressed: () {
                        store.salePrefill = orderQty;
                        pushRoute(context, const NewSaleScreen());
                      },
                      icon: const Icon(Icons.shopping_cart_outlined, size: 16),
                      label: const Text('Convert to Sale  ›'),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          RouteCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.fact_check_outlined,
                      size: 16,
                      color: RouteColors.primary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Visit Outcome',
                        style: routeType(
                          14,
                          FontWeight.w700,
                          RouteColors.ink,
                          20,
                        ),
                      ),
                    ),
                    Text('Log without sale', style: routeType(11, FontWeight.w500, RouteColors.secondary, 14)),
                    Switch(
                      value: _logWithoutSale,
                      activeThumbColor: Colors.white,
                      activeTrackColor: const Color(0xFF0B74E8),
                      onChanged: (value) => setState(() => _logWithoutSale = value),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _outcomeButton(
                        context,
                        'No Need',
                        Icons.check_circle,
                        RouteColors.ok,
                        'NoNeed',
                        const Color(0xFFE5F6EC),
                        enabled: _logWithoutSale,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _outcomeButton(
                        context,
                        'No Response',
                        Icons.cancel_outlined,
                        RouteColors.danger,
                        'NoResponse',
                        const Color(0xFFFFF1F1),
                        enabled: _logWithoutSale,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.bolt, size: 16, color: Color(0xFF0B74E8)),
              const SizedBox(width: 6),
              Text('Quick Rider Actions', style: routeType(15, FontWeight.w700, const Color(0xFF0C2F66), 20)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _actionTile(
                  context,
                  const Key('action-sale'),
                  Icons.shopping_cart_outlined,
                  const Color(0xFF0B74E8),
                  'New Sale',
                  'Invoice & Deliver',
                  const NewSaleScreen(),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _actionTile(
                  context,
                  null,
                  Icons.account_balance_wallet_outlined,
                  const Color(0xFF12A150),
                  'New Collection',
                  'Recover Due Balance',
                  const CollectionScreen(),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _actionTile(
                  context,
                  null,
                  Icons.add_shopping_cart_outlined,
                  const Color(0xFF7C5CFF),
                  'New Order',
                  'Book for Next Cycle',
                  const NewOrderScreen(),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _actionTile(
                  context,
                  null,
                  Icons.menu_book_outlined,
                  const Color(0xFF0B74E8),
                  'Customer Ledger',
                  'Audit Invoices & Cash',
                  const LedgerScreen(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.photo_camera_outlined, size: 16, color: Color(0xFF0B74E8)),
              const SizedBox(width: 6),
              Expanded(
                child: Text('Storefront Reference', style: routeType(15, FontWeight.w700, const Color(0xFF0C2F66), 20)),
              ),
              Text(
                photo == null ? 'Not captured' : 'Captured this visit',
                style: routeType(11, FontWeight.w600, photo == null ? RouteColors.secondary : RouteColors.ok, 14),
              ),
            ],
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => _captureStorefront(context, customer.id),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                height: 150,
                color: const Color(0xFFE7EDF5),
                child: photo == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.photo_camera_outlined,
                            color: RouteColors.primary,
                            size: 28,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Tap to photograph the shopfront',
                            style: AppType.style(
                              12,
                              FontWeight.w400,
                              RouteColors.secondary,
                            ),
                          ),
                        ],
                      )
                    : Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.memory(photo, fit: BoxFit.cover),
                          Positioned(
                            left: 10,
                            bottom: 10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xCC0C2F66),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                'Ref Photo ${customer.code}',
                                style: AppType.style(11, FontWeight.w600, Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
          ),
        ],
      ),
    );
  }
}

Future<void> _saveShopLocation(
  BuildContext context,
  CustomerDetail customer,
) async {
  try {
    final location = Location();
    var service = await location.serviceEnabled();
    if (!service) service = await location.requestService();
    if (!context.mounted) return;
    if (!service) {
      _opsNote(context, 'Turn location on to save the shop pin.');
      return;
    }
    var permission = await location.hasPermission();
    if (permission == PermissionStatus.denied) {
      permission = await location.requestPermission();
    }
    if (!context.mounted) return;
    final allowed =
        permission == PermissionStatus.granted ||
        permission == PermissionStatus.grantedLimited;
    if (!allowed) {
      _opsNote(context, 'Allow location so the shop pin can be saved.');
      return;
    }
    final here = await location.getLocation().timeout(
      const Duration(seconds: 8),
    );
    if (!context.mounted) return;
    await FieldScope.of(context).saveCustomer(
      CustomerDraft(
        id: customer.id,
        businessName: customer.businessName,
        primaryMobile: customer.phone,
        additionalContact: customer.additionalContact,
        category: customer.category,
        street: customer.street,
        area: customer.area,
        city: customer.city,
        latitude: here.latitude,
        longitude: here.longitude,
        bottleOwnership: customer.bottleOwnership,
        openingDebt: customer.outstanding,
        openingEmpties: customer.bottlesHeld,
        cnic: customer.cnic,
        contactName: customer.contactName,
        contactRole: customer.contactRole,
      ),
    );
    if (!context.mounted) return;
    final problem = FieldScope.of(context).error;
    _opsNote(context, problem ?? 'Shop location saved from this phone.');
  } catch (_) {
    if (context.mounted) {
      _opsNote(context, 'The shop location could not be saved.');
    }
  }
}

Future<void> _captureStorefront(BuildContext context, String customerId) async {
  try {
    final file = await ImagePicker().pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.rear,
      maxWidth: 1280,
      imageQuality: 70,
    );
    if (file == null || !context.mounted) return;
    FieldScope.of(context).saveStorefront(customerId, await file.readAsBytes());
  } catch (_) {
    if (context.mounted) {
      _opsNote(context, 'The shopfront photo could not be taken.');
    }
  }
}

Future<void> _logOutcome(
  BuildContext context,
  String outcome,
  String label,
) async {
  final store = FieldScope.of(context);
  await store.logVisit(outcome);
  if (!context.mounted) return;
  _opsNote(context, store.error ?? '$label logged. No sale was created.');
}

void _opsNote(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

Widget _opsStat(
  String label,
  String value,
  String note,
  Color noteColor,
  IconData icon, {
  Color? valueColor,
  Color background = Colors.white,
}) {
  return RouteCard(
    color: background,
    padding: const EdgeInsets.all(10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: noteColor),
        const SizedBox(height: 6),
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: routeType(10, FontWeight.w600, RouteColors.secondary, 13)),
        const SizedBox(height: 2),
        Text(value, maxLines: 2, overflow: TextOverflow.ellipsis, style: routeType(13, FontWeight.w700, valueColor ?? const Color(0xFF0C2F66), 16)),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(Icons.info_outline, size: 11, color: noteColor),
            const SizedBox(width: 3),
            Expanded(
              child: Text(note, maxLines: 2, overflow: TextOverflow.ellipsis, style: routeType(10, FontWeight.w600, noteColor, 13)),
            ),
          ],
        ),
      ],
    ),
  );
}

Widget _bottleBox(
  String label,
  String value,
  String note,
  IconData icon, {
  bool emphasize = false,
}) {
  return Expanded(
    child: Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: emphasize ? const Color(0xFFE8F3FF) : const Color(0xFFF4F7FB),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF0B74E8)),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: routeType(10, FontWeight.w600, RouteColors.secondary, 13)),
          Text(
            value,
            style: routeType(
              20,
              FontWeight.w700,
              emphasize ? RouteColors.primary : RouteColors.ink,
              24,
            ),
          ),
          Text(
            note,
            style: routeType(10, FontWeight.w500, RouteColors.muted, 14),
          ),
        ],
      ),
    ),
  );
}

Widget _outcomeButton(
  BuildContext context,
  String label,
  IconData icon,
  Color color,
  String outcome,
  Color background, {
  required bool enabled,
}) {
  return Material(
    color: background,
    borderRadius: BorderRadius.circular(24),
    child: InkWell(
      onTap: () {
        if (!enabled) {
          _opsNote(context, 'Turn on Log without sale, or use New Sale.');
          return;
        }
        _logOutcome(context, outcome, label);
      },
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(label, style: AppType.style(13, FontWeight.w700, color)),
          ],
        ),
      ),
    ),
  );
}

Widget _actionTile(
  BuildContext context,
  Key? key,
  IconData icon,
  Color color,
  String title,
  String subtitle,
  Widget page,
) {
  return Material(
    key: key,
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      onTap: () => pushRoute(context, page),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        child: Column(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 8),
            Text(title, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: routeType(11, FontWeight.w700, const Color(0xFF0C2F66), 14)),
            Text(subtitle, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: routeType(9, FontWeight.w500, RouteColors.secondary, 12)),
          ],
        ),
      ),
    ),
  );
}

String _prettyDate(String? value) {
  final parsed = DateTime.tryParse(value ?? '');
  if (parsed == null) return '—';
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${parsed.day.toString().padLeft(2, '0')} ${months[parsed.month - 1]} ${parsed.year}';
}

String _ago(DateTime? date) {
  if (date == null) return 'No drop yet';
  final days = DateTime.now().difference(date).inDays;
  if (days <= 0) return 'Today';
  if (days == 1) return '1 day ago';
  return '$days days ago';
}

class StartDayScreen extends StatefulWidget {
  const StartDayScreen({super.key});

  @override
  State<StartDayScreen> createState() => _StartDayScreenState();
}

class _StartDayScreenState extends State<StartDayScreen> {
  final Map<String, int> _counts = {};
  final _meter = TextEditingController();
  var _start = true;
  var _submitting = false;
  var _asked = false;
  var _countsReady = false;
  var _meterSeeded = false;
  var _capturing = false;
  int? _reading;
  int? _fromPhoto;
  int? _accuracy;
  Uint8List? _odometerBytes;
  Uint8List? _selfieBytes;

  @override
  void dispose() {
    _meter.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _readLocation();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_asked) return;
    _asked = true;
    final store = FieldScope.of(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) store.loadShift();
    });
  }

  Future<void> _readLocation() async {
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
      final accuracy = here.accuracy?.round();
      if (!mounted || accuracy == null) return;
      setState(() => _accuracy = accuracy);
    } catch (_) {}
  }

  Future<void> _captureMeter(int? previous) async {
    setState(() => _capturing = true);
    try {
      final shot = await takeOdometerPhoto(previous);
      if (!mounted || shot == null) return;
      if (shot.reading != null && _meter.text != '${shot.reading}') {
        _meter.text = '${shot.reading}';
      }
      setState(() {
        _odometerBytes = shot.bytes;
        if (shot.reading != null) {
          _fromPhoto = shot.reading;
          _reading = shot.reading;
        }
      });
      if (shot.reading == null) {
        _note(
          'The digits were not clear. Type the kilometres, or retake the photo.',
        );
      }
    } catch (_) {
      if (mounted) _note('The camera could not read the meter. Try again.');
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  Future<void> _captureSelfie() async {
    setState(() => _capturing = true);
    try {
      final bytes = await takeInspectionPhoto();
      if (!mounted || bytes == null) return;
      setState(() => _selfieBytes = bytes);
    } catch (_) {
      if (mounted) _note('The camera could not take the inspection photo.');
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  void _note(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _prepareCounts(ShiftData? shift) {
    if (_countsReady || shift == null || shift.lines.isEmpty) return;
    _countsReady = true;
    for (final line in shift.lines) {
      _counts[line.productId] = line.countedQuantity;
    }
  }

  void _seedMeter(ShiftData? shift) {
    if (_meterSeeded || shift == null) return;
    _meterSeeded = true;
    final seed = shift.openingOdometer;
    if (seed <= 0) return;
    _meter.text = '$seed';
    _reading = seed;
  }

  void _onMeter(String value) {
    final parsed = int.tryParse(value);
    setState(() => _reading = parsed != null && parsed > 0 ? parsed : null);
  }

  @override
  Widget build(BuildContext context) {
    final shift = FieldScope.of(context).shift;
    _prepareCounts(shift);
    _seedMeter(shift);
    final lines = shift?.lines ?? const <ShiftLine>[];
    final verified = _reading != null || (shift?.odometerVerified ?? false);
    final depot = shift?.depotLabel ?? '';
    final depotParts = depot.split(' · ');
    final place = depotParts.isEmpty || depotParts.first.isEmpty
        ? 'Current stop'
        : depotParts.first;
    final warehouse = depotParts.length > 1
        ? depotParts.sublist(1).join(' · ')
        : '';
    final units = lines.fold<int>(
      0,
      (sum, line) => sum + (_counts[line.productId] ?? line.countedQuantity),
    );
    final opening = _start;

    return RoutePage(
      body: Stack(
        children: [
          const Positioned.fill(
            child: Image(image: AssetImage('assets/home/ops_background.jpg'), fit: BoxFit.cover),
          ),
          ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back, color: Color(0xFF10264A)),
              ),
              Image.asset('assets/home/logo.png', height: 40, fit: BoxFit.contain),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFF0875DC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.fact_check_outlined, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Shift Checklist', style: routeType(24, FontWeight.w700, const Color(0xFF10264A), 28)),
                    Text(
                      'Complete your pre-shift checks and load the van',
                      style: routeType(13, FontWeight.w400, const Color(0xFF66758D), 18),
                    ),
                  ],
                ),
              ),
              Image.asset('assets/welcome/truck.png', width: 84, height: 64, fit: BoxFit.contain),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _mode(
                  'Start Day',
                  Icons.play_circle_outline,
                  opening,
                  () => _setMode(true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _mode(
                  'End Day',
                  Icons.stop_circle_outlined,
                  !opening,
                  () => _setMode(false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          RouteCard(
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE4F2FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.calendar_today_outlined, color: Color(0xFF0875DC)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Route Manifest Date', style: routeType(12, FontWeight.w500, const Color(0xFF66758D), 16)),
                      Text(_manifestDate(shift?.serviceDate), style: routeType(18, FontWeight.w700, const Color(0xFF10264A), 24)),
                    ],
                  ),
                ),
                _chip(shift?.status == 'Open' ? 'In Progress' : 'Not Started', shift?.status == 'Open'),
              ],
            ),
          ),
          const SizedBox(height: 8),
          RouteCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE4F2FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.local_shipping_outlined, color: Color(0xFF0875DC)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        opening ? 'Route & Vehicle Details' : 'Ready to close the route?',
                        style: routeType(16, FontWeight.w700, const Color(0xFF10264A), 22),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  opening
                      ? 'Confirm your assigned vehicle condition and opening stock manifest before departing the depot.'
                      : 'Photograph the closing meter and confirm the stock left on the van.',
                  style: routeType(13, FontWeight.w400, RouteColors.body, 18),
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE4F2FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Van ID: ${shift?.fleetCode.isNotEmpty == true ? shift!.fleetCode : 'Assigned van'}  ·  ${shift?.routeLabel.isNotEmpty == true ? shift!.routeLabel : 'Assigned route'}',
                    style: routeType(13, FontWeight.w600, const Color(0xFF10264A), 18),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          RouteCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      color: RouteColors.primary,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Current Location',
                      style: routeType(
                        12,
                        FontWeight.w600,
                        RouteColors.secondary,
                        16,
                      ),
                    ),
                    const Spacer(),
                    if (_accuracy != null) _chip('Verified', true),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  place,
                  style: routeType(15, FontWeight.w700, RouteColors.ink, 20),
                ),
                if (warehouse.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    _accuracy == null
                        ? warehouse
                        : '$warehouse · ±$_accuracy meters',
                    style: routeType(
                      12,
                      FontWeight.w500,
                      RouteColors.secondary,
                      16,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          _meterCard(verified, opening, shift?.openingOdometer),
          const SizedBox(height: 8),
          _inspectionCard(opening),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                opening ? 'Opening Van Stock' : 'Closing Van Stock',
                style: routeType(16, FontWeight.w700, RouteColors.ink, 22),
              ),
              const Spacer(),
              if (lines.isNotEmpty) _chip('${lines.length} Items', false),
            ],
          ),
          Text(
            'Verify quantities loaded onto van pallets.',
            style: routeType(12, FontWeight.w400, RouteColors.secondary, 16),
          ),
          const SizedBox(height: 8),
          if (lines.isEmpty)
            RouteCard(
              child: Text(
                'Van stock loads with the assigned route.',
                style: AppType.style(
                  13,
                  FontWeight.w400,
                  RouteColors.secondary,
                ),
              ),
            )
          else
            for (final line in lines)
              _stockRow(
                line,
                _counts[line.productId] ?? line.countedQuantity,
                (value) => setState(() => _counts[line.productId] = value),
              ),
          const SizedBox(height: 8),
          RouteCard(
            color: RouteColors.tint,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(
              'Manifest Total · ${lines.length} items · $units units loaded',
              style: routeType(13, FontWeight.w700, RouteColors.ink, 18),
            ),
          ),
          const SizedBox(height: 12),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF0752B8), Color(0xFF0875DC)]),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _capturing || _submitting ? null : () => _confirm(lines),
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  height: 56,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        _submitting
                            ? 'Saving...'
                            : opening
                            ? 'Confirm & Start Day'
                            : 'Confirm & End Day',
                        style: routeType(16, FontWeight.w700, Colors.white, 20),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => Navigator.of(context).maybePop(),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              foregroundColor: const Color(0xFF10264A),
              side: const BorderSide(color: Color(0xFFD5E7F8)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: Text('Cancel', style: routeType(14, FontWeight.w600, const Color(0xFF10264A), 18)),
          ),
        ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirm(List<ShiftLine> lines) async {
    if (_submitting || _capturing) return;
    final store = FieldScope.of(context);
    final alreadyOpen = store.shift?.status == 'Open';
    if (_start && alreadyOpen) {
      _note(
        'This day is already started. Use End Day when you are back at the depot.',
      );
      return;
    }
    if (!_start && !alreadyOpen) {
      _note('Start the day from the pre-shift checklist before closing it.');
      return;
    }
    final reading = _reading;
    final photo = _odometerBytes;
    if (reading == null) {
      _note('Type the kilometres, or take a photo of the odometer.');
      return;
    }
    final encoded = photo == null ? null : base64Encode(photo);
    final inspection = _selfieBytes == null
        ? null
        : base64Encode(_selfieBytes!);
    setState(() => _submitting = true);
    try {
    if (_start) {
      await store.startShift(
        [
          for (final line in lines)
            {
              'productId': line.productId,
              'countedQuantity':
                  _counts[line.productId] ?? line.countedQuantity,
            },
        ],
        openingOdometer: reading,
        odometerPhoto: encoded,
        inspectionPhoto: inspection,
      );
    } else {
      await store.endShift(
        closingOdometer: reading,
        odometerPhoto: encoded,
        inspectionPhoto: inspection,
        stock: [
          for (final line in lines)
            {
              'productId': line.productId,
              'countedQuantity':
                  _counts[line.productId] ?? line.countedQuantity,
            },
        ],
      );
    }
    if (!mounted) return;
    final problem = store.error;
    if (problem != null) {
      _note(problem);
      return;
    }
    Navigator.of(context).maybePop();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _setMode(bool start) {
    final seed = FieldScope.of(context).shift?.openingOdometer ?? 0;
    final text = seed > 0 ? '$seed' : '';
    if (_meter.text != text) _meter.text = text;
    setState(() {
      _start = start;
      _fromPhoto = null;
      _odometerBytes = null;
      _selfieBytes = null;
      _reading = seed > 0 ? seed : null;
    });
  }

  String _meterLabel(bool lastVerified) {
    if (_reading != null && _fromPhoto != null && _reading == _fromPhoto) {
      return 'Read from photo';
    }
    if (_reading != null) return 'Entered manually';
    if (lastVerified) return 'Photo verified last shift';
    return 'Type or photo';
  }

  Widget _meterCard(bool verified, bool opening, int? previous) {
    final photo = _odometerBytes;
    return RouteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  opening
                      ? 'Opening Odometer Reading'
                      : 'Closing Odometer Reading',
                  style: routeType(14, FontWeight.w700, RouteColors.ink, 20),
                ),
              ),
              _chip(
                _meterLabel(verified),
                _reading != null || verified,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: RouteColors.pale,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.edit_outlined,
                  color: RouteColors.secondary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _meter,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(7),
                    ],
                    style: routeType(28, FontWeight.w700, RouteColors.ink, 32),
                    decoration: InputDecoration(
                      isDense: true,
                      filled: false,
                      contentPadding: EdgeInsets.zero,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      hintText: 'Enter kilometres',
                      hintStyle: routeType(
                        16,
                        FontWeight.w500,
                        RouteColors.secondary,
                        22,
                      ),
                    ),
                    onChanged: _onMeter,
                  ),
                ),
                Text(
                  'KM',
                  style: routeType(
                    14,
                    FontWeight.w700,
                    RouteColors.secondary,
                    18,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Ensure the dashboard digits exactly match your gauge reading.',
            style: routeType(12, FontWeight.w400, RouteColors.secondary, 16),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 72,
                  height: 72,
                  color: RouteColors.pale,
                  child: photo == null
                      ? const Icon(
                          Icons.speed,
                          color: RouteColors.primary,
                          size: 28,
                        )
                      : Image.memory(photo, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: _capturing ? null : () => _captureMeter(previous),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Icon(
                          _capturing
                              ? Icons.hourglass_top
                              : Icons.photo_camera_outlined,
                          color: RouteColors.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                photo == null
                                    ? 'Take odometer photo'
                                    : 'Retake photo',
                                style: routeType(
                                  14,
                                  FontWeight.w700,
                                  RouteColors.primary,
                                  18,
                                ),
                              ),
                              Text(
                                'Optional when the kilometres are typed.',
                                style: routeType(
                                  12,
                                  FontWeight.w400,
                                  RouteColors.secondary,
                                  16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _inspectionCard(bool opening) {
    final photo = _selfieBytes;
    return RouteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  opening
                      ? 'Opening Selfie / Inspection'
                      : 'Closing Selfie / Inspection',
                  style: routeType(14, FontWeight.w700, RouteColors.ink, 20),
                ),
              ),
              _chip('Optional', false),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Capture the uniform check or vehicle front if the supervisor asks for it.',
            style: routeType(12, FontWeight.w400, RouteColors.secondary, 16),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 72,
                  height: 72,
                  color: RouteColors.pale,
                  child: photo == null
                      ? const Icon(
                          Icons.person_outline,
                          color: RouteColors.primary,
                          size: 28,
                        )
                      : Image.memory(photo, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: _capturing ? null : _captureSelfie,
                  borderRadius: BorderRadius.circular(12),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.photo_camera_outlined,
                        color: RouteColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            photo == null ? 'Take photo' : 'Retake photo',
                            style: routeType(
                              14,
                              FontWeight.w700,
                              RouteColors.primary,
                              18,
                            ),
                          ),
                          Text(
                            'Tap to capture',
                            style: routeType(
                              12,
                              FontWeight.w400,
                              RouteColors.secondary,
                              16,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _mode(String label, IconData icon, bool selected, VoidCallback onTap) {
    return Material(
      color: selected ? const Color(0xFF0875DC) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: selected ? const Color(0xFF0875DC) : const Color(0xFFD5E7F8)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 54,
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? Colors.white : RouteColors.ink,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: routeType(
                  14,
                  FontWeight.w600,
                  selected ? Colors.white : RouteColors.ink,
                  20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, bool positive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: positive ? const Color(0xFFE5F6EC) : RouteColors.pale,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: routeType(
          11,
          FontWeight.w700,
          positive ? RouteColors.ok : RouteColors.primary,
          14,
        ),
      ),
    );
  }

  Widget _qtyButton(IconData icon, VoidCallback onTap) {
    return Material(
      color: const Color(0xFFE4F2FF),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(width: 36, height: 36, child: Icon(icon, size: 18, color: Color(0xFF0875DC))),
      ),
    );
  }

  Widget _stockRow(ShiftLine line, int value, ValueChanged<int> onChanged) {
    final icon = line.name.toLowerCase().contains('empty')
        ? Icons.inventory_2_outlined
        : line.name.contains('500')
        ? Icons.water_drop_outlined
        : Icons.local_drink_outlined;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RouteCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            line.name.toLowerCase().contains('empty') || line.name.contains('500')
                ? Icon(icon, color: const Color(0xFF0875DC))
                : Image.asset('assets/welcome/jug.png', width: 36, height: 40, fit: BoxFit.contain),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    line.name,
                    style: routeType(14, FontWeight.w600, RouteColors.ink, 20),
                  ),
                  Text(
                    'Depot Expected: ${line.depotExpected}',
                    style: routeType(
                      12,
                      FontWeight.w400,
                      RouteColors.secondary,
                      16,
                    ),
                  ),
                ],
              ),
            ),
            _qtyButton(Icons.remove, () => onChanged(value - 1 < 0 ? 0 : value - 1)),
            SizedBox(
              width: 48,
              child: Text('$value', textAlign: TextAlign.center, style: routeType(18, FontWeight.w700, const Color(0xFF10264A), 22)),
            ),
            _qtyButton(Icons.add, () => onChanged(value + 1)),
          ],
        ),
      ),
    );
  }

  String _manifestDate(String? value) {
    final parsed = DateTime.tryParse(value ?? '');
    final date = parsed ?? DateTime.now();
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

class NewSaleScreen extends StatefulWidget {
  const NewSaleScreen({super.key});

  @override
  State<NewSaleScreen> createState() => _NewSaleScreenState();
}

class _NewSaleScreenState extends State<NewSaleScreen> {
  var _openingQty = 2;
  var _asked = false;
  var _seeded = false;
  var _emptiesTouched = false;
  var _empties = 0;
  final Map<String, int> _qty = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_asked) return;
    _asked = true;
    final store = FieldScope.of(context);
    final prefill = store.salePrefill;
    if (prefill != null && prefill > 0) {
      _openingQty = prefill;
      store.salePrefill = null;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) store.loadSale();
    });
  }

  void _seed(SaleContext sale) {
    if (_seeded || sale.products.isEmpty) return;
    _seeded = true;
    final primary =
        sale.products.where((item) => item.isReturnable).firstOrNull ??
        sale.products.first;
    _qty[primary.id] = _bound(_openingQty, primary.vanStock);
    _empties = _suggestedEmpties(sale);
  }

  int _qtyOf(String id) => _qty[id] ?? 0;

  int _suggestedEmpties(SaleContext sale) {
    final sold = sale.products
        .where((item) => item.isReturnable)
        .fold<int>(0, (sum, item) => sum + _qtyOf(item.id));
    final held = sale.emptyBottlesHeld;
    if (sold < held) return sold;
    return held;
  }

  int _lineTotal(ProductItem product) =>
      _qtyOf(product.id) * product.unitPrice.round();

  bool _withinStock(SaleContext sale) {
    for (final product in sale.products) {
      if (_qtyOf(product.id) > product.vanStock) return false;
    }
    return true;
  }

  Future<void> _commit(FieldStore store, int total, {required bool pay}) async {
    final selected = {
      for (final entry in _qty.entries)
        if (entry.value > 0) entry.key: entry.value,
    };
    if (selected.isEmpty) {
      _opsNote(context, 'Add at least one product.');
      return;
    }
    await store.saveDraft(selected, emptyBottlesReturned: _empties);
    if (!mounted) return;
    if (store.error != null || store.draft == null) {
      _opsNote(context, store.error ?? 'The sale could not be saved.');
      return;
    }
    if (pay) {
      pushRoute(context, PaymentDetailsScreen(sale: total));
      return;
    }
    _opsNote(context, 'Draft saved. It will sync with the next connection.');
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final store = FieldScope.of(context);
    final sale = store.saleContext;
    final customer = sale?.customer ?? store.customer;
    if (sale != null) _seed(sale);
    final products = sale?.products ?? const <ProductItem>[];
    final total = products.fold<int>(
      0,
      (sum, product) => sum + _lineTotal(product),
    );
    final selectedCount = products
        .where((product) => _qtyOf(product.id) > 0)
        .length;
    final primary =
        products.where((product) => product.isReturnable).firstOrNull ??
        (products.isEmpty ? null : products.first);
    final delivered = primary == null ? 0 : _qtyOf(primary.id);
    final available = primary?.vanStock ?? 0;
    final remainingVan = available - delivered;
    final held = sale?.emptyBottlesHeld ?? customer?.bottlesHeld ?? 0;
    final emptiesLeft = held - _empties;
    final ready = sale != null && _withinStock(sale);
    final outstanding = customer?.outstanding ?? 0;
    return RoutePage(
      title: 'New Sale / Delivery Entry',
      trailing: IconButton(
        onPressed: () => pushRoute(context, const SettingsScreen()),
        icon: const CircleAvatar(
          radius: 16,
          backgroundColor: RouteColors.primary,
          child: Icon(Icons.person, color: Colors.white, size: 18),
        ),
      ),
      bottom: Material(
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: sale == null
                      ? null
                      : () => _commit(store, total, pay: false),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    foregroundColor: RouteColors.ink,
                    side: const BorderSide(color: RouteColors.line),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Save Draft',
                    style: routeType(13, FontWeight.w700, RouteColors.ink, 18),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: FilledButton(
                  key: const Key('continue-payment'),
                  onPressed: sale == null
                      ? null
                      : () => _commit(store, total, pay: true),
                  style: FilledButton.styleFrom(
                    backgroundColor: RouteColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Continue to Payment (${_pkr(total)}) →',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: routeType(13, FontWeight.w700, Colors.white, 18),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        children: [
          RouteCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        customer?.businessName ?? 'Customer',
                        style: routeType(
                          16,
                          FontWeight.w700,
                          RouteColors.ink,
                          22,
                        ),
                      ),
                    ),
                    Text(
                      customer?.code ?? '',
                      style: routeType(
                        12,
                        FontWeight.w700,
                        RouteColors.primary,
                        16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 15,
                      color: RouteColors.primary,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        [customer?.street, customer?.area]
                            .where((part) => part != null && part.isNotEmpty)
                            .join('  ·  '),
                        style: routeType(
                          12,
                          FontWeight.w500,
                          RouteColors.secondary,
                          16,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF6F6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Previous Outstanding',
                              style: routeType(
                                11,
                                FontWeight.w600,
                                RouteColors.secondary,
                                14,
                              ),
                            ),
                            Text(
                              _pkr(outstanding),
                              style: routeType(
                                16,
                                FontWeight.w700,
                                outstanding <= 0
                                    ? RouteColors.ok
                                    : RouteColors.danger,
                                22,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE5F6EC),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.verified_outlined,
                                  size: 14,
                                  color: RouteColors.ok,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Verified Ledger',
                                  style: routeType(
                                    11,
                                    FontWeight.w700,
                                    RouteColors.ok,
                                    14,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              'Separate from today',
                              style: routeType(
                                11,
                                FontWeight.w500,
                                RouteColors.secondary,
                                14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: RouteColors.pale,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.local_shipping_outlined,
                  color: RouteColors.primary,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$available available – $delivered delivered = $remainingVan remaining van stock',
                        style: routeType(
                          12,
                          FontWeight.w700,
                          RouteColors.ink,
                          16,
                        ),
                      ),
                      Text(
                        ready
                            ? 'Requested quantity verified against van manifest'
                            : 'Requested quantity is above the van manifest',
                        style: routeType(
                          11,
                          FontWeight.w500,
                          ready ? RouteColors.secondary : RouteColors.danger,
                          14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              Text(
                'Select Products',
                style: routeType(16, FontWeight.w700, RouteColors.ink, 22),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: RouteColors.pale,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  selectedCount == 1
                      ? '1 Item Selected'
                      : '$selectedCount Items Selected',
                  style: routeType(
                    10,
                    FontWeight.w700,
                    RouteColors.primary,
                    14,
                  ),
                ),
              ),
              Text(
                ready ? 'Van Stock Ready' : 'Check Stock',
                style: routeType(
                  11,
                  FontWeight.w700,
                  ready ? RouteColors.ok : RouteColors.danger,
                  14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (sale == null)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            for (final product in products) ...[
              _SaleProductCard(
                product: product,
                quantity: _qtyOf(product.id),
                lineTotal: _lineTotal(product),
                onChanged: (next) => setState(() {
                  _qty[product.id] = _bound(next, product.vanStock);
                  if (!_emptiesTouched) _empties = _suggestedEmpties(sale);
                }),
              ),
              const SizedBox(height: 8),
            ],
          OutlinedButton.icon(
            onPressed: sale == null
                ? null
                : () => showModalBottomSheet<void>(
                    context: context,
                    builder: (sheet) => SafeArea(
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                            child: Text(
                              'Add a product',
                              style: routeType(
                                16,
                                FontWeight.w700,
                                RouteColors.ink,
                                22,
                              ),
                            ),
                          ),
                          for (final product in products)
                            ListTile(
                              title: Text(product.name),
                              subtitle: Text(
                                'PKR ${product.unitPrice.round()} / ${product.unitLabel} · Stock ${product.vanStock}',
                              ),
                              trailing: Text('${_qtyOf(product.id)}'),
                              onTap: () {
                                Navigator.of(sheet).pop();
                                setState(() {
                                  final next = _qtyOf(product.id) + 1;
                                  _qty[product.id] = _bound(
                                    next,
                                    product.vanStock,
                                  );
                                  if (!_emptiesTouched) {
                                    _empties = _suggestedEmpties(sale);
                                  }
                                });
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
            icon: const Icon(Icons.add),
            label: const Text('Add Another Product'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.recycling_outlined,
                size: 18,
                color: RouteColors.primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Empty Bottles Returned',
                  style: routeType(15, FontWeight.w700, RouteColors.ink, 20),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: sale == null
                    ? null
                    : () => setState(() {
                        _emptiesTouched = false;
                        _empties = _suggestedEmpties(sale);
                      }),
                icon: const Icon(Icons.refresh, color: RouteColors.primary),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                ),
                onPressed: customer == null
                    ? null
                    : () => showModalBottomSheet<void>(
                        context: context,
                        builder: (sheet) => SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Asset Audit',
                                  style: routeType(
                                    16,
                                    FontWeight.w700,
                                    RouteColors.ink,
                                    22,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Issued ${customer.bottlesIssued} · Returned ${customer.bottlesReturned} · Customer holds ${customer.bottlesHeld}',
                                  style: routeType(
                                    14,
                                    FontWeight.w500,
                                    RouteColors.body,
                                    20,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'This visit records $_empties empty bottle${_empties == 1 ? '' : 's'} coming back on the van.',
                                  style: routeType(
                                    13,
                                    FontWeight.w400,
                                    RouteColors.secondary,
                                    18,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                child: Text(
                  'Asset Audit',
                  style: routeType(
                    12,
                    FontWeight.w700,
                    RouteColors.primary,
                    16,
                  ),
                ),
              ),
            ],
          ),
          RouteCard(
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: RouteColors.pale,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.water_drop_outlined,
                        color: RouteColors.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '19L Empty Bottle',
                            style: routeType(
                              14,
                              FontWeight.w700,
                              RouteColors.ink,
                              20,
                            ),
                          ),
                          Text(
                            'Customer holds: $held bottles',
                            style: routeType(
                              12,
                              FontWeight.w500,
                              RouteColors.secondary,
                              16,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _QtyStepper(
                      quantity: _empties,
                      onChanged: (next) => setState(() {
                        _emptiesTouched = true;
                        _empties = _bound(next, held);
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Remaining Empty Bottle Balance: $emptiesLeft bottle${emptiesLeft == 1 ? '' : 's'}',
                    style: routeType(12, FontWeight.w700, RouteColors.ok, 16),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          RouteCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sale Summary',
                  style: routeType(15, FontWeight.w700, RouteColors.ink, 20),
                ),
                const SizedBox(height: 8),
                _summaryRow('Items Total', _pkr(total)),
                _summaryRow(
                  'Trade Discount',
                  _pkr(0),
                  valueColor: RouteColors.ok,
                ),
                _summaryRow('Bottle Security Deposit', _pkr(0)),
                const Divider(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        "Today's Sale Total",
                        style: routeType(
                          14,
                          FontWeight.w700,
                          RouteColors.ink,
                          20,
                        ),
                      ),
                    ),
                    Text(
                      _pkr(total),
                      style: routeType(
                        22,
                        FontWeight.w700,
                        RouteColors.primary,
                        26,
                      ),
                    ),
                  ],
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Excludes previous balance',
                    style: routeType(
                      11,
                      FontWeight.w500,
                      RouteColors.secondary,
                      14,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 14,
                      color: RouteColors.secondary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'This sale can be saved on your device and synced later.',
                        style: routeType(
                          11,
                          FontWeight.w500,
                          RouteColors.secondary,
                          14,
                        ),
                      ),
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
}

class _SaleProductCard extends StatelessWidget {
  const _SaleProductCard({
    required this.product,
    required this.quantity,
    required this.lineTotal,
    required this.onChanged,
  });

  final ProductItem product;
  final int quantity;
  final int lineTotal;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final hint = _packHint(product);
    return RouteCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: product.isReturnable
                      ? RouteColors.pale
                      : const Color(0xFFF4F7FB),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  product.isReturnable
                      ? Icons.water_drop_outlined
                      : Icons.inventory_2_outlined,
                  color: RouteColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: routeType(
                        14,
                        FontWeight.w700,
                        RouteColors.ink,
                        20,
                      ),
                    ),
                    Text(
                      'PKR ${product.unitPrice.round()} / ${product.unitLabel}    Stock: ${product.vanStock} units',
                      style: routeType(
                        11,
                        FontWeight.w500,
                        RouteColors.secondary,
                        15,
                      ),
                    ),
                    if (hint != null)
                      Text(
                        hint,
                        style: routeType(
                          11,
                          FontWeight.w500,
                          RouteColors.muted,
                          15,
                        ),
                      ),
                    if (product.isReturnable)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE5F6EC),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'Returnable container',
                            style: routeType(
                              10,
                              FontWeight.w700,
                              RouteColors.ok,
                              14,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                _pkr(lineTotal),
                style: routeType(14, FontWeight.w700, RouteColors.ink, 20),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: _QtyStepper(quantity: quantity, onChanged: onChanged),
          ),
        ],
      ),
    );
  }
}

class _QtyStepper extends StatelessWidget {
  const _QtyStepper({required this.quantity, required this.onChanged});

  final int quantity;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: RouteColors.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: quantity == 0 ? null : () => onChanged(quantity - 1),
            icon: const Icon(Icons.remove, size: 18),
          ),
          SizedBox(
            width: 24,
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: routeType(16, FontWeight.w700, RouteColors.ink, 22),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () => onChanged(quantity + 1),
            icon: const Icon(Icons.add, size: 18, color: RouteColors.primary),
          ),
        ],
      ),
    );
  }
}

Widget _summaryRow(String label, String value, {Color? valueColor}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: routeType(13, FontWeight.w500, RouteColors.body, 18),
          ),
        ),
        Text(
          value,
          style: routeType(
            13,
            FontWeight.w700,
            valueColor ?? RouteColors.ink,
            18,
          ),
        ),
      ],
    ),
  );
}

int _bound(int value, int max) {
  if (value < 0) return 0;
  if (value > max) return max;
  return value;
}

String? _packHint(ProductItem product) {
  final name = product.name.toLowerCase();
  if (name.contains('500')) return '12 bottles / pack';
  if (name.contains('1.5')) return '6 bottles / pack';
  return null;
}

class PaymentDetailsScreen extends StatefulWidget {
  const PaymentDetailsScreen({required this.sale, super.key});

  final int sale;

  @override
  State<PaymentDetailsScreen> createState() => _PaymentDetailsScreenState();
}

class _PaymentDetailsScreenState extends State<PaymentDetailsScreen> {
  var _method = 'Cash';
  var _credit = false;
  var _closeStop = true;
  var _ready = false;
  late final TextEditingController _amount;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ready) return;
    _ready = true;
    final due = (FieldScope.of(context).draft?.amountDue ?? widget.sale)
        .round();
    _amount = TextEditingController(text: '$due');
    final store = FieldScope.of(context);
    store.paymentMethod = _method;
    store.amountReceived = due;
    store.closeStop = true;
  }

  @override
  void dispose() {
    if (_ready) _amount.dispose();
    super.dispose();
  }

  int _taken(int due) {
    final digits = _amount.text.replaceAll(RegExp(r'[^0-9]'), '');
    return _bound(int.tryParse(digits) ?? 0, due);
  }

  void _setAmount(int value, int due, {bool? credit}) {
    final next = _bound(value, due);
    _amount.text = '$next';
    _credit = credit ?? next < due;
    FieldScope.of(context).amountReceived = next;
  }

  @override
  Widget build(BuildContext context) {
    final store = FieldScope.of(context);
    final draft = store.draft;
    final due = (draft?.amountDue ?? widget.sale).round();
    final sale = (draft?.saleAmount ?? widget.sale).round();
    final previous = (draft?.previousOutstanding ?? 0).round();
    final customer = store.customer;
    final received = _ready ? _taken(due) : due;
    final remaining = due - received;
    final progress = due == 0 ? 1.0 : received / due;
    final invoice = _invoiceLabel(draft?.receiptNumber ?? '');
    final paid = remaining == 0;
    final status = paid
        ? 'Fully Paid'
        : (received == 0 ? 'Credit Sale' : 'Partial');
    return RoutePage(
      title: 'Payment Details',
      trailing: IconButton(
        onPressed: () => pushRoute(context, const SettingsScreen()),
        icon: const CircleAvatar(
          radius: 16,
          backgroundColor: RouteColors.primary,
          child: Icon(Icons.person, color: Colors.white, size: 18),
        ),
      ),
      bottom: Material(
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FilledButton(
                key: const Key('continue-signature'),
                onPressed: () {
                  final taken = _taken(due);
                  store.paymentMethod = _method;
                  store.amountReceived = taken;
                  store.closeStop = _closeStop;
                  pushRoute(context, SignatureScreen(amount: taken));
                },
                style: FilledButton.styleFrom(
                  backgroundColor: RouteColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Continue to Signature  →',
                  style: routeType(14, FontWeight.w700, Colors.white, 20),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: Text(
                  'Back to Sale',
                  style: routeType(
                    13,
                    FontWeight.w600,
                    RouteColors.secondary,
                    18,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        children: [
          RouteCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                const Icon(
                  Icons.storefront_outlined,
                  color: RouteColors.primary,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${customer?.businessName ?? 'Customer'}  ·  ${customer?.code ?? ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: routeType(13, FontWeight.w700, RouteColors.ink, 18),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    customer?.routeName ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: routeType(
                      11,
                      FontWeight.w600,
                      RouteColors.secondary,
                      14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _moneyLine("Today's Sale Amount", _pkr(sale)),
          _moneyLine(
            'Previous Outstanding',
            _pkr(previous),
            trailing: IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: () => showDialog<void>(
                context: context,
                builder: (dialog) => AlertDialog(
                  title: const Text('Previous outstanding'),
                  content: const Text(
                    'This balance was already on the ledger before today. It is collected here only when the amount received is higher than today\'s sale.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(dialog).pop(),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ),
              icon: const Icon(
                Icons.info_outline,
                size: 16,
                color: RouteColors.secondary,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TOTAL AMOUNT DUE',
                      style: routeType(
                        11,
                        FontWeight.w700,
                        RouteColors.secondary,
                        14,
                        0.4,
                      ),
                    ),
                    Text(
                      _pkr(due),
                      style: routeType(
                        26,
                        FontWeight.w700,
                        RouteColors.ink,
                        30,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: RouteColors.pale,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Inv #$invoice',
                  style: routeType(
                    11,
                    FontWeight.w700,
                    RouteColors.primary,
                    14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Payment Method',
                  style: routeType(15, FontWeight.w700, RouteColors.ink, 20),
                ),
              ),
              TextButton.icon(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (dialog) => AlertDialog(
                    title: const Text('One method on this receipt'),
                    content: Text(
                      '$_method is the channel stored on this receipt. Cash, bank transfer, wallet, and cheque are all accepted, one at a time.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(dialog).pop(),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                ),
                icon: const Icon(Icons.account_tree_outlined, size: 16),
                label: const Text('Multi-channel'),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: _methodCard(
                  'Cash',
                  'Physical note',
                  Icons.payments_outlined,
                  _method == 'Cash',
                  () => setState(() {
                    _method = 'Cash';
                    store.paymentMethod = 'Cash';
                  }),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _methodCard(
                  'Bank Transfer',
                  'IBFT / Raast',
                  Icons.account_balance_outlined,
                  _method == 'Bank Transfer',
                  () => setState(() {
                    _method = 'Bank Transfer';
                    store.paymentMethod = 'Bank Transfer';
                  }),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _methodCard(
                  'Wallet',
                  'Easypaisa/Jazz',
                  Icons.account_balance_wallet_outlined,
                  _method == 'Wallet',
                  () => setState(() {
                    _method = 'Wallet';
                    store.paymentMethod = 'Wallet';
                  }),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _methodCard(
                  'Cheque',
                  'Clearing / Post',
                  Icons.receipt_long_outlined,
                  _method == 'Cheque',
                  () => setState(() {
                    _method = 'Cheque';
                    store.paymentMethod = 'Cheque';
                  }),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _amount,
            keyboardType: TextInputType.number,
            style: routeType(22, FontWeight.w700, RouteColors.ink, 28),
            decoration: InputDecoration(
              labelText: 'Amount Received (PKR)',
              prefixText: 'PKR ',
              filled: true,
              fillColor: Colors.white,
              suffixIcon: IconButton(
                onPressed: () =>
                    setState(() => _setAmount(0, due, credit: true)),
                icon: const Icon(Icons.cancel_outlined),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: RouteColors.line),
              ),
            ),
            onChanged: (_) => setState(() {
              _credit = _taken(due) < due;
              store.amountReceived = _taken(due);
            }),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _amountChip(
                'Full: ${_pkr(due)}',
                received == due && due > 0,
                () => setState(() => _setAmount(due, due, credit: false)),
              ),
              _amountChip(
                'Sale Only: ${_pkr(sale)}',
                received == sale && sale != due,
                () => setState(() => _setAmount(sale, due)),
              ),
              _amountChip(
                'Unpaid',
                received == 0,
                () => setState(() => _setAmount(0, due, credit: true)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          RouteCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: _credit,
                  onChanged: (value) => setState(() {
                    final on = value ?? false;
                    if (on) {
                      _setAmount(
                        received == due ? 0 : received,
                        due,
                        credit: true,
                      );
                    } else {
                      _setAmount(due, due, credit: false);
                    }
                  }),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Record as Credit Sale',
                          style: routeType(
                            14,
                            FontWeight.w700,
                            RouteColors.ink,
                            20,
                          ),
                        ),
                        Text(
                          'Leave any remaining balance on the customer ledger. No dispute is raised.',
                          style: routeType(
                            12,
                            FontWeight.w400,
                            RouteColors.secondary,
                            16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          RouteCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.account_balance_outlined,
                      size: 16,
                      color: RouteColors.primary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Reconciliation Ledger',
                        style: routeType(
                          14,
                          FontWeight.w700,
                          RouteColors.ink,
                          20,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: paid
                            ? const Color(0xFFE5F6EC)
                            : const Color(0xFFFFF4E5),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        status,
                        style: routeType(
                          11,
                          FontWeight.w700,
                          paid ? RouteColors.ok : const Color(0xFFB26A00),
                          14,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _summaryRow('Gross Outstanding', _pkr(due)),
                _summaryRow(
                  'Disbursed Now',
                  '- ${_pkr(received)}',
                  valueColor: RouteColors.ok,
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: RouteColors.pale,
                    color: RouteColors.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Remaining Customer Balance',
                        style: routeType(
                          12,
                          FontWeight.w600,
                          RouteColors.secondary,
                          16,
                        ),
                      ),
                    ),
                    Text(
                      _pkr(remaining),
                      style: routeType(
                        16,
                        FontWeight.w700,
                        paid ? RouteColors.ok : RouteColors.danger,
                        20,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          RouteCard(
            child: Row(
              children: [
                const Icon(Icons.task_alt, color: RouteColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Close Stop #$invoice',
                        style: routeType(
                          14,
                          FontWeight.w700,
                          RouteColors.ink,
                          20,
                        ),
                      ),
                      Text(
                        'Mark this doorstep delivery complete',
                        style: routeType(
                          12,
                          FontWeight.w400,
                          RouteColors.secondary,
                          16,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _closeStop,
                  onChanged: (value) => setState(() {
                    _closeStop = value;
                    store.closeStop = value;
                  }),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          RouteCard(
            color: RouteColors.tint,
            child: Row(
              children: [
                const Icon(
                  Icons.cloud_done_outlined,
                  color: RouteColors.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Offline Sync Ready',
                        style: routeType(
                          14,
                          FontWeight.w700,
                          RouteColors.ink,
                          20,
                        ),
                      ),
                      Text(
                        'The signed receipt is kept on this phone and syncs when the connection returns.',
                        style: routeType(
                          12,
                          FontWeight.w400,
                          RouteColors.secondary,
                          16,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.check_circle, color: RouteColors.ok, size: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Widget _moneyLine(String label, String value, {Widget? trailing}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: routeType(13, FontWeight.w500, RouteColors.body, 18),
          ),
        ),
        ?trailing,
        Text(value, style: routeType(14, FontWeight.w700, RouteColors.ink, 20)),
      ],
    ),
  );
}

Widget _methodCard(
  String title,
  String subtitle,
  IconData icon,
  bool selected,
  VoidCallback onTap,
) {
  return Material(
    color: selected ? RouteColors.pale : Colors.white,
    borderRadius: BorderRadius.circular(14),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? RouteColors.primary : RouteColors.line,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? RouteColors.primary : RouteColors.tint,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 16,
                color: selected ? Colors.white : RouteColors.primary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: routeType(12, FontWeight.w700, RouteColors.ink, 16),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: routeType(
                      10,
                      FontWeight.w500,
                      RouteColors.secondary,
                      13,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected ? Icons.check_circle : Icons.circle_outlined,
              size: 16,
              color: selected ? RouteColors.primary : RouteColors.muted,
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _amountChip(String label, bool selected, VoidCallback onTap) {
  return ChoiceChip(
    label: Text(label),
    selected: selected,
    onSelected: (_) => onTap(),
    selectedColor: RouteColors.primary,
    labelStyle: routeType(
      12,
      FontWeight.w700,
      selected ? Colors.white : RouteColors.ink,
      16,
    ),
  );
}

String _invoiceLabel(String receiptNumber) {
  final cleaned = receiptNumber.trim();
  if (cleaned.isEmpty) return 'DRAFT';
  final tail = cleaned.length <= 4
      ? cleaned
      : cleaned.substring(cleaned.length - 4);
  return tail.toUpperCase();
}

class SignatureScreen extends StatefulWidget {
  const SignatureScreen({required this.amount, super.key});

  final int amount;

  @override
  State<SignatureScreen> createState() => _SignatureScreenState();
}

class _SignatureScreenState extends State<SignatureScreen> {
  final _pad = _SignatureController();
  final _name = TextEditingController();
  final _role = TextEditingController();
  var _ready = false;
  var _editing = false;
  var _saving = false;
  String? _unable;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ready) return;
    _ready = true;
    final customer = FieldScope.of(context).customer;
    _name.text = customer?.contactName ?? customer?.businessName ?? 'Customer';
    _role.text = customer?.contactRole ?? 'Receiver';
  }

  @override
  void dispose() {
    _pad.dispose();
    _name.dispose();
    _role.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final store = FieldScope.of(context);
    final name = _name.text.trim();
    if (name.isEmpty) {
      _opsNote(context, 'Enter the name of the person receiving the delivery.');
      return;
    }
    setState(() => _saving = true);
    final png = _unable == null ? await _pad.toPng() : null;
    if (!mounted) return;
    final image = png == null ? null : base64Encode(png);
    final role = _role.text.trim();
    if (store.collecting) {
      await store.completeCollection(
        signerName: name,
        signerRole: role,
        signatureImage: image,
        signatureNote: _unable,
      );
    } else {
      await store.completeSale(
        signerName: name,
        signerRole: role,
        signatureImage: image,
        signatureNote: _unable,
      );
    }
    if (!mounted) return;
    setState(() => _saving = false);
    if (store.error != null || store.receipt == null) {
      _opsNote(context, store.error ?? 'The sale could not be completed.');
      return;
    }
    pushRoute(
      context,
      ReceiptScreen(amount: store.receipt!.amountReceived.round()),
    );
  }

  Future<void> _unableToSign() async {
    final reason = await showModalBottomSheet<String>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: Text(
                'Unable to sign',
                style: routeType(16, FontWeight.w700, RouteColors.ink, 22),
              ),
            ),
            for (final option in const [
              'Customer refused',
              'No one available to sign',
              'Receiver cannot write',
            ])
              ListTile(
                title: Text(option),
                onTap: () => Navigator.of(sheet).pop(option),
              ),
          ],
        ),
      ),
    );
    if (!mounted || reason == null) return;
    _pad.clear();
    setState(() => _unable = reason);
  }

  @override
  Widget build(BuildContext context) {
    final store = FieldScope.of(context);
    final customer = store.customer;
    final reference = store.draft?.receiptNumber ?? '';
    final trail = _invoiceLabel(
      reference.isEmpty ? (customer?.code ?? 'DRAFT') : reference,
    );
    final accepted = _pad.hasInk || _unable != null;
    final when = _signedStamp(DateTime.now());
    return RoutePage(
      title: 'Customer Signature Capture',
      trailing: IconButton(
        onPressed: () => pushRoute(context, const SettingsScreen()),
        icon: const CircleAvatar(
          radius: 16,
          backgroundColor: RouteColors.primary,
          child: Icon(Icons.person, color: Colors.white, size: 18),
        ),
      ),
      bottom: Material(
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        _pad.clear();
                        setState(() => _unable = null);
                      },
                      icon: const Icon(
                        Icons.draw_outlined,
                        size: 16,
                        color: RouteColors.danger,
                      ),
                      label: Text(
                        'Clear Pad',
                        style: routeType(
                          13,
                          FontWeight.w700,
                          RouteColors.ink,
                          18,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _unableToSign,
                      icon: const Icon(Icons.do_not_touch_outlined, size: 16),
                      label: Text(
                        'Unable to Sign',
                        style: routeType(
                          13,
                          FontWeight.w700,
                          RouteColors.ink,
                          18,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                key: const Key('confirm-signature'),
                onPressed: _saving ? null : _confirm,
                style: FilledButton.styleFrom(
                  backgroundColor: RouteColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.fact_check_outlined, size: 18),
                label: Text(
                  'Confirm Signature & Complete Sale',
                  style: routeType(14, FontWeight.w700, Colors.white, 20),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Signature attached to transaction receipt · AES-256 encrypted',
                textAlign: TextAlign.center,
                style: routeType(
                  11,
                  FontWeight.w500,
                  RouteColors.secondary,
                  15,
                ),
              ),
            ],
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        children: [
          RouteCard(
            color: const Color(0xFFF4F7FB),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.white,
                  child: Icon(
                    Icons.touch_app_outlined,
                    size: 16,
                    color: RouteColors.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Please ask the customer to sign below',
                        style: routeType(
                          14,
                          FontWeight.w700,
                          RouteColors.ink,
                          20,
                        ),
                      ),
                      Text(
                        'Turn the device toward the merchant or receiver to capture direct touch confirmation.',
                        style: routeType(
                          12,
                          FontWeight.w400,
                          RouteColors.secondary,
                          16,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          RouteCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.storefront_outlined,
                      size: 16,
                      color: RouteColors.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'MERCHANT',
                      style: routeType(
                        11,
                        FontWeight.w700,
                        RouteColors.secondary,
                        14,
                        0.4,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5F6EC),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        _pkr(widget.amount),
                        style: routeType(
                          12,
                          FontWeight.w700,
                          RouteColors.ok,
                          16,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  customer?.businessName ?? 'Customer',
                  style: routeType(18, FontWeight.w700, RouteColors.ink, 24),
                ),
                Text(
                  'ID: ${customer?.code ?? ''}',
                  style: routeType(
                    12,
                    FontWeight.w500,
                    RouteColors.secondary,
                    16,
                  ),
                ),
                const Divider(height: 18),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.receipt_long_outlined,
                          size: 14,
                          color: RouteColors.secondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          store.collecting
                              ? 'Collection #$trail'
                              : 'Sale Receipt #$trail',
                          style: routeType(
                            12,
                            FontWeight.w600,
                            RouteColors.ink,
                            16,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.schedule,
                          size: 14,
                          color: RouteColors.secondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          when,
                          style: routeType(
                            12,
                            FontWeight.w500,
                            RouteColors.secondary,
                            16,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(
                Icons.draw_outlined,
                size: 18,
                color: RouteColors.primary,
              ),
              const SizedBox(width: 6),
              Text(
                'Capture Signature',
                style: routeType(16, FontWeight.w700, RouteColors.ink, 22),
              ),
            ],
          ),
          Text(
            'Ask the customer to sign using their finger inside the box below.',
            style: routeType(12, FontWeight.w400, RouteColors.secondary, 16),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: RouteColors.line),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.verified_outlined,
                      size: 14,
                      color: RouteColors.primary,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Digital Audit Trail #$trail',
                        style: routeType(
                          11,
                          FontWeight.w700,
                          RouteColors.ink,
                          14,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: RouteColors.pale,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '256-Bit Ledger',
                        style: routeType(
                          10,
                          FontWeight.w700,
                          RouteColors.primary,
                          14,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 150,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: _unable == null
                        ? _SignatureCanvas(
                            controller: _pad,
                            onDrawn: () => setState(() {}),
                          )
                        : Center(
                            child: Text(
                              _unable!,
                              style: routeType(
                                14,
                                FontWeight.w700,
                                RouteColors.danger,
                                20,
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.edit_outlined,
                      size: 14,
                      color: RouteColors.secondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'SIGN ABOVE THIS LINE',
                      style: routeType(
                        10,
                        FontWeight.w700,
                        RouteColors.secondary,
                        14,
                        0.4,
                      ),
                    ),
                    const Expanded(child: Divider(indent: 8, endIndent: 8)),
                    Text(
                      accepted ? 'Accepted' : 'Waiting',
                      style: routeType(
                        12,
                        FontWeight.w700,
                        accepted ? RouteColors.primary : RouteColors.muted,
                        16,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          RouteCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'CUSTOMER / RECEIVER NAME',
                      style: routeType(
                        11,
                        FontWeight.w700,
                        RouteColors.secondary,
                        14,
                        0.3,
                      ),
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.verified_user_outlined,
                      size: 14,
                      color: RouteColors.ok,
                    ),
                    Text(
                      ' verified',
                      style: routeType(11, FontWeight.w700, RouteColors.ok, 14),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_editing)
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _name,
                          decoration: const InputDecoration(
                            labelText: 'Name',
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _role,
                          decoration: const InputDecoration(
                            labelText: 'Role',
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: RouteColors.pale,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.badge_outlined,
                          size: 16,
                          color: RouteColors.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${_name.text} (${_role.text})',
                            style: routeType(
                              14,
                              FontWeight.w700,
                              RouteColors.ink,
                              20,
                            ),
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          onPressed: () => setState(() => _editing = true),
                          icon: const Icon(
                            Icons.edit_outlined,
                            size: 16,
                            color: RouteColors.primary,
                          ),
                        ),
                      ],
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

class _SignatureController extends ChangeNotifier {
  final List<List<Offset>> strokes = [];
  Size size = Size.zero;
  bool get hasInk => strokes.any((stroke) => stroke.length > 1);

  void start(Offset point) {
    strokes.add([point]);
    notifyListeners();
  }

  void extend(Offset point) {
    if (strokes.isEmpty) strokes.add([point]);
    strokes.last.add(point);
    notifyListeners();
  }

  void clear() {
    strokes.clear();
    notifyListeners();
  }

  Future<Uint8List?> toPng() async {
    if (!hasInk || size.width < 1 || size.height < 1) return null;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFF8F9FF),
    );
    final paint = Paint()
      ..color = const Color(0xFF1565C0)
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    for (final stroke in strokes) {
      if (stroke.length < 2) continue;
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (final point in stroke.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, paint);
    }
    final image = await recorder.endRecording().toImage(
      size.width.ceil(),
      size.height.ceil(),
    );
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List();
  }
}

class _SignatureCanvas extends StatefulWidget {
  const _SignatureCanvas({required this.controller, required this.onDrawn});

  final _SignatureController controller;
  final VoidCallback onDrawn;

  @override
  State<_SignatureCanvas> createState() => _SignatureCanvasState();
}

class _SignatureCanvasState extends State<_SignatureCanvas> {
  ScrollHoldController? _hold;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_redraw);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_redraw);
    _hold?.cancel();
    super.dispose();
  }

  void _redraw() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        widget.controller.size = Size(
          constraints.maxWidth,
          constraints.maxHeight,
        );
        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (event) {
            _hold?.cancel();
            _hold = Scrollable.maybeOf(context)?.position.hold(() {});
            widget.controller.start(event.localPosition);
            widget.onDrawn();
          },
          onPointerMove: (event) {
            widget.controller.extend(event.localPosition);
            widget.onDrawn();
          },
          onPointerUp: (_) => _release(),
          onPointerCancel: (_) => _release(),
          child: CustomPaint(
            painter: _InkPainter(widget.controller.strokes),
            child: Center(
              child: Text(
                'RL-CRYPTO-SIGN',
                style: AppType.style(
                  12,
                  FontWeight.w600,
                  const Color(0x220B1C30),
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _release() {
    _hold?.cancel();
    _hold = null;
  }
}

class _InkPainter extends CustomPainter {
  const _InkPainter(this.strokes);

  final List<List<Offset>> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1565C0)
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    for (final stroke in strokes) {
      if (stroke.length < 2) continue;
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (final point in stroke.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _InkPainter oldDelegate) => true;
}

String _signedStamp(DateTime time) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
  final suffix = time.hour >= 12 ? 'PM' : 'AM';
  final minute = time.minute.toString().padLeft(2, '0');
  return '${time.day} ${months[time.month - 1]} ${time.year} · $hour:$minute $suffix';
}

class ReceiptScreen extends StatefulWidget {
  const ReceiptScreen({this.amount = 2860, super.key});

  final int amount;

  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  var _paper = 58;
  var _autoSent = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_autoSent) return;
    final store = FieldScope.of(context);
    final receipt = store.receipt;
    if (store.settings?.autoPrint != true ||
        receipt == null ||
        !PrinterRadio.isConnected) {
      return;
    }
    _autoSent = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _print(receipt);
    });
  }

  int get _columns => _paper == 80 ? 48 : (_paper == 58 ? 32 : 42);

  Future<void> _open(Uri uri) async {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      _opsNote(context, 'This phone could not open the link.');
    }
  }

  Future<void> _print(ReceiptData receipt) async {
    final notes = <String>[];
    try {
      notes.add(await FieldScope.of(context).printReceipt());
    } catch (_) {
      notes.add('The print queue was not reached.');
    }
    if (!mounted) return;
    if (PrinterRadio.isConnected) {
      try {
        final slip = await PrintSlip.load();
        await PrinterRadio.printText(_ticket(receipt, _columns, slip));
        notes.add('Sent to ${PrinterRadio.connectedName}.');
      } catch (_) {
        notes.add('The connected printer did not accept the ticket.');
      }
    } else {
      notes.add(
        'Connect a printer in Printer Configuration to print from this phone.',
      );
    }
    if (mounted) _opsNote(context, notes.join(' '));
  }

  @override
  Widget build(BuildContext context) {
    final receipt = FieldScope.of(context).receipt;
    if (receipt == null) {
      return const RoutePage(
        title: 'Final Receipt & Printing',
        body: Center(child: Text('Transaction Recorded')),
      );
    }
    final verify = receiptVerifyUrl(receipt.receiptNumber);
    final due = receipt.saleAmount + receipt.previousOutstanding;
    final paid = receipt.balanceAfter == 0;
    final when = _signedStamp(receipt.issuedAt);
    final signed = (receipt.signatureNote ?? '').trim().isEmpty
        ? 'ACCEPTED · SIGNED'
        : receipt.signatureNote!.trim();
    final printer = PrinterRadio.connectedName;
    final online = PrinterRadio.isConnected;
    return RoutePage(
      title: 'Final Receipt & Printing',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () => _shareReceipt(receipt),
            icon: const Icon(Icons.share_outlined, color: RouteColors.ink),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () => pushRoute(context, const SettingsScreen()),
            icon: const CircleAvatar(
              radius: 16,
              backgroundColor: RouteColors.primary,
              child: Icon(Icons.person, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        children: [
          const Center(
            child: CircleAvatar(
              radius: 22,
              backgroundColor: Color(0xFFE5F6EC),
              child: Icon(Icons.check, color: RouteColors.ok),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Transaction Recorded',
            textAlign: TextAlign.center,
            style: routeType(22, FontWeight.w700, RouteColors.ink, 28),
          ),
          Text(
            'Your transaction receipt is ready.',
            textAlign: TextAlign.center,
            style: routeType(13, FontWeight.w400, RouteColors.secondary, 18),
          ),
          Text(
            '${receipt.syncStatus} · Stored with this customer',
            textAlign: TextAlign.center,
            style: routeType(12, FontWeight.w600, RouteColors.ok, 16),
          ),
          const SizedBox(height: 8),
          RouteCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  receipt.depotName.isEmpty ? 'AquaRider' : receipt.depotName,
                  style: routeType(15, FontWeight.w700, RouteColors.ink, 20),
                ),
                if (receipt.depotAddress.isNotEmpty)
                  Text(
                    receipt.depotAddress,
                    style: routeType(
                      12,
                      FontWeight.w400,
                      RouteColors.secondary,
                      16,
                    ),
                  ),
                const Divider(),
                _receiptFact('Receipt No', receipt.receiptNumber),
                _receiptFact('Date & Time', when),
                _receiptFact(
                  'Rider',
                  '${receipt.riderName} (${receipt.riderCode})',
                ),
                _receiptFact(
                  'Customer',
                  '${receipt.customerName} · ${receipt.customerCode}',
                ),
                _receiptFact('Phone', receipt.customerPhone),
                _receiptFact('Address', receipt.customerAddress),
                const Divider(),
                Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Text(
                        'PRODUCT',
                        style: routeType(
                          10,
                          FontWeight.w700,
                          RouteColors.secondary,
                          14,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'QTY',
                        textAlign: TextAlign.right,
                        style: routeType(
                          10,
                          FontWeight.w700,
                          RouteColors.secondary,
                          14,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'RATE',
                        textAlign: TextAlign.right,
                        style: routeType(
                          10,
                          FontWeight.w700,
                          RouteColors.secondary,
                          14,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'AMOUNT',
                        textAlign: TextAlign.right,
                        style: routeType(
                          10,
                          FontWeight.w700,
                          RouteColors.secondary,
                          14,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                if (receipt.lines.isEmpty)
                  _receiptLine(
                    'Collection',
                    1,
                    receipt.amountReceived,
                    receipt.amountReceived,
                  )
                else
                  for (final line in receipt.lines)
                    _receiptLine(
                      line.name,
                      line.quantity,
                      line.unitPrice,
                      line.lineTotal,
                    ),
                const Divider(),
                _summaryRow('Items Subtotal', _pkr(receipt.saleAmount)),
                _summaryRow(
                  'Previous Balance',
                  _pkr(receipt.previousOutstanding),
                ),
                _summaryRow('Total Due', _pkr(due)),
                _summaryRow(
                  'Amount Received (${receipt.paymentMethod})',
                  _pkr(receipt.amountReceived),
                  valueColor: RouteColors.ok,
                ),
                if (receipt.withholdingTax > 0)
                  _summaryRow(
                    'Withholding Tax',
                    _pkr(receipt.withholdingTax),
                    valueColor: RouteColors.ok,
                  ),
                const SizedBox(height: 4),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  children: [
                    Text(
                      'Remaining Ledger',
                      style: routeType(
                        13,
                        FontWeight.w700,
                        RouteColors.ink,
                        18,
                      ),
                    ),
                    Text(
                      _pkr(receipt.balanceAfter),
                      style: routeType(
                        14,
                        FontWeight.w700,
                        paid ? RouteColors.ok : RouteColors.danger,
                        18,
                      ),
                    ),
                    if (paid)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE5F6EC),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'FULLY PAID',
                          style: routeType(
                            10,
                            FontWeight.w700,
                            RouteColors.ok,
                            14,
                          ),
                        ),
                      ),
                  ],
                ),
                if (receipt.kind == 'Sale') ...[
                  const Divider(),
                  Text(
                    'Returnable Assets (19L Empties)',
                    style: routeType(13, FontWeight.w700, RouteColors.ink, 18),
                  ),
                  _summaryRow(
                    'Bottles Returned Today',
                    '${receipt.emptyBottlesReturned} units',
                  ),
                  _summaryRow(
                    'Previous Store Hold',
                    '${receipt.previousBottlesHeld} units',
                  ),
                  _summaryRow(
                    'New Store Balance',
                    '${receipt.emptyBottlesHeld} bottle${receipt.emptyBottlesHeld == 1 ? '' : 's'} remaining',
                    valueColor: RouteColors.primary,
                  ),
                ],
                const Divider(),
                Text(
                  'RECEIVER DETAILS',
                  style: routeType(
                    11,
                    FontWeight.w700,
                    RouteColors.secondary,
                    14,
                    0.4,
                  ),
                ),
                Text(
                  receipt.signerName ?? receipt.customerName,
                  style: routeType(15, FontWeight.w700, RouteColors.ink, 20),
                ),
                Text(
                  '${receipt.signerRole ?? 'Receiver'} · ${receipt.customerName}',
                  style: routeType(
                    12,
                    FontWeight.w500,
                    RouteColors.secondary,
                    16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  signed,
                  style: routeType(12, FontWeight.w700, RouteColors.ok, 16),
                ),
                const SizedBox(height: 10),
                Center(
                  child: Text(
                    'Thank you for your business!',
                    style: routeType(13, FontWeight.w700, RouteColors.ink, 18),
                  ),
                ),
                Center(
                  child: Text(
                    'Prompt settlement keeps the next refill on priority.',
                    textAlign: TextAlign.center,
                    style: routeType(
                      11,
                      FontWeight.w400,
                      RouteColors.secondary,
                      15,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: QrImageView(
                    data: verify,
                    size: 140,
                    backgroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Center(
                  child: Text(
                    'VERIFY: ${receipt.receiptNumber}',
                    style: routeType(11, FontWeight.w700, RouteColors.ink, 14),
                  ),
                ),
                Center(
                  child: Text(
                    'Scan to open this customer receipt',
                    style: routeType(
                      10,
                      FontWeight.w500,
                      RouteColors.secondary,
                      14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Paper Width',
            style: routeType(12, FontWeight.w700, RouteColors.secondary, 16),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              for (final width in const [58, 80, 0])
                ChoiceChip(
                  label: Text(width == 0 ? 'Custom' : '${width}mm'),
                  selected: _paper == (width == 0 ? 42 : width),
                  onSelected: (_) =>
                      setState(() => _paper = width == 0 ? 42 : width),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${printer ?? 'No printer connected'} · ${online ? 'Online · Ready to print' : 'Offline'}',
            style: routeType(
              12,
              FontWeight.w600,
              online ? RouteColors.ok : RouteColors.secondary,
              16,
            ),
          ),
          const SizedBox(height: 8),
          RouteButton(
            label: 'Print Receipt',
            icon: const Icon(Icons.print, color: Colors.white, size: 18),
            onPressed: () => _print(receipt),
          ),
          const SizedBox(height: 10),
          Text(
            'DIGITAL HANDOFF & EXPORT',
            style: routeType(
              11,
              FontWeight.w700,
              RouteColors.secondary,
              16,
              0.4,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _handoff(
                  Icons.ios_share,
                  'Share Receipt',
                  () => _shareReceipt(receipt),
                ),
              ),
              Expanded(
                child: _handoff(
                  Icons.picture_as_pdf_outlined,
                  'Download PDF',
                  () => _open(Uri.parse(verify)),
                ),
              ),
              Expanded(
                child: _handoff(
                  Icons.chat_outlined,
                  'WhatsApp',
                  () => _open(
                    Uri.parse(
                      'https://wa.me/?text=${Uri.encodeComponent(_shareText(receipt))}',
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          RouteButton(
            label: 'Done (Return to Manifest)',
            onPressed: () => popToRiderHome(context),
          ),
          const SizedBox(height: 8),
          RouteOutlineButton(
            label: 'New Transaction with Customer',
            onPressed: () => Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute<void>(builder: (_) => const NewSaleScreen()),
              (route) => route.isFirst,
            ),
          ),
        ],
      ),
    );
  }
}

Widget _receiptFact(String label, String value) {
  if (value.trim().isEmpty) return const SizedBox.shrink();
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 92,
          child: Text(
            label,
            style: routeType(12, FontWeight.w600, RouteColors.secondary, 16),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: routeType(12, FontWeight.w600, RouteColors.ink, 16),
          ),
        ),
      ],
    ),
  );
}

Widget _receiptLine(String name, int quantity, num rate, num amount) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Expanded(
          flex: 4,
          child: Text(
            name,
            style: routeType(12, FontWeight.w600, RouteColors.ink, 16),
          ),
        ),
        Expanded(
          child: Text(
            '$quantity',
            textAlign: TextAlign.right,
            style: routeType(12, FontWeight.w600, RouteColors.ink, 16),
          ),
        ),
        Expanded(
          child: Text(
            '${rate.round()}',
            textAlign: TextAlign.right,
            style: routeType(12, FontWeight.w600, RouteColors.ink, 16),
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            _pkr(amount),
            textAlign: TextAlign.right,
            style: routeType(12, FontWeight.w700, RouteColors.ink, 16),
          ),
        ),
      ],
    ),
  );
}

Widget _handoff(IconData icon, String label, VoidCallback onTap) {
  return InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          Icon(icon, color: RouteColors.primary),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: routeType(11, FontWeight.w600, RouteColors.ink, 14),
          ),
        ],
      ),
    ),
  );
}

String receiptVerifyUrl(String number) =>
    '${ApiConfig.baseUrl}/verify/${Uri.encodeComponent(number)}';

String _shareText(ReceiptData receipt) {
  final lines = receipt.lines.isEmpty
      ? 'Collection ${_pkr(receipt.amountReceived)}'
      : receipt.lines
            .map(
              (line) =>
                  '${line.name} x${line.quantity}  ${_pkr(line.lineTotal)}',
            )
            .join('\n');
  return '${receipt.customerName} (${receipt.customerCode})\n'
      'Receipt ${receipt.receiptNumber}\n'
      '$lines\n'
      'Sale ${_pkr(receipt.saleAmount)}\n'
      'Previous ${_pkr(receipt.previousOutstanding)}\n'
      'Received ${_pkr(receipt.amountReceived)} by ${receipt.paymentMethod}\n'
      'Remaining ${_pkr(receipt.balanceAfter)}\n'
      '${receiptVerifyUrl(receipt.receiptNumber)}';
}

Future<void> _shareReceipt(ReceiptData receipt) {
  return SharePlus.instance.share(
    ShareParams(
      text: _shareText(receipt),
      title: 'Receipt ${receipt.receiptNumber}',
      subject: '${receipt.customerName} · ${receipt.receiptNumber}',
    ),
  );
}

class PrintSlip {
  const PrintSlip({
    this.company = true,
    this.customer = true,
    this.ledger = true,
    this.gps = false,
  });

  static const _company = 'routeledger.slip.company';
  static const _customer = 'routeledger.slip.customer';
  static const _ledger = 'routeledger.slip.ledger';
  static const _gps = 'routeledger.slip.gps';

  final bool company;
  final bool customer;
  final bool ledger;
  final bool gps;

  static Future<PrintSlip> load() async {
    final prefs = await SharedPreferences.getInstance();
    return PrintSlip(
      company: prefs.getBool(_company) ?? true,
      customer: prefs.getBool(_customer) ?? true,
      ledger: prefs.getBool(_ledger) ?? true,
      gps: prefs.getBool(_gps) ?? false,
    );
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_company, company);
    await prefs.setBool(_customer, customer);
    await prefs.setBool(_ledger, ledger);
    await prefs.setBool(_gps, gps);
  }

  PrintSlip copyWith({bool? company, bool? customer, bool? ledger, bool? gps}) {
    return PrintSlip(
      company: company ?? this.company,
      customer: customer ?? this.customer,
      ledger: ledger ?? this.ledger,
      gps: gps ?? this.gps,
    );
  }
}

String _ticket(ReceiptData receipt, int columns, PrintSlip slip) {
  String clip(String value) =>
      value.length <= columns ? value : value.substring(0, columns);
  String pair(String left, String right) {
    final space = columns - left.length - right.length;
    if (space < 1) return clip('$left $right');
    return left + (' ' * space) + right;
  }

  final lines = <String>[
    if (slip.company) ...[
      clip(receipt.depotName.isEmpty ? 'AquaRider' : receipt.depotName),
      clip(receipt.receiptNumber),
    ],
    if (slip.customer) ...[
      clip('${receipt.customerName} ${receipt.customerCode}'),
      clip(receipt.customerPhone),
      clip(receipt.customerAddress),
      clip('Rider ${receipt.riderName} ${receipt.riderCode}'),
    ],
    '-' * columns,
    for (final line in receipt.lines)
      pair(clip(line.name), '${line.quantity} x ${line.unitPrice.round()}'),
    pair('Sale', '${receipt.saleAmount.round()}'),
    pair(
      'Received ${receipt.paymentMethod}',
      '${receipt.amountReceived.round()}',
    ),
    if (slip.ledger) ...[
      pair('Previous', '${receipt.previousOutstanding.round()}'),
      pair('Remaining', '${receipt.balanceAfter.round()}'),
      pair('Empties back', '${receipt.emptyBottlesReturned}'),
      pair('Store holds', '${receipt.emptyBottlesHeld}'),
    ],
    clip('Receiver ${receipt.signerName ?? ''} ${receipt.signerRole ?? ''}'),
    if (slip.gps) 'GPS is not stored on the receipt',
    'Check ${receiptVerifyUrl(receipt.receiptNumber)}',
  ];
  return lines.join('\n');
}

class CollectionScreen extends StatefulWidget {
  const CollectionScreen({super.key});

  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> {
  final _amount = TextEditingController();
  final _tax = TextEditingController(text: '0');
  final _note = TextEditingController();
  final _amountFocus = FocusNode();
  var _channel = 'Cash';
  var _ready = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ready) return;
    _ready = true;
    final due = (FieldScope.of(context).customer?.outstanding ?? 0).round();
    final start = due >= 1000 ? 1000 : due;
    _amount.text = '$start';
  }

  @override
  void dispose() {
    _amount.dispose();
    _tax.dispose();
    _note.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  int _read(TextEditingController controller, int max) {
    final digits = controller.text.replaceAll(RegExp(r'[^0-9]'), '');
    return _bound(int.tryParse(digits) ?? 0, max);
  }

  void _setAmount(int value, int due) {
    final next = _bound(value, due);
    _amount.text = '$next';
    final taxRoom = due - next;
    if (_read(_tax, due) > taxRoom) _tax.text = '$taxRoom';
  }

  void _continue(int due, int collected, int tax) {
    if (due <= 0) {
      _opsNote(context, 'This customer has no outstanding balance.');
      return;
    }
    if (collected <= 0) {
      _opsNote(context, 'Enter the amount collected.');
      return;
    }
    if (collected + tax > due) {
      _opsNote(
        context,
        'Collection and withholding tax cannot exceed the outstanding balance.',
      );
      return;
    }
    final store = FieldScope.of(context);
    store.collecting = true;
    store.collectionAmount = collected;
    store.collectionChannel = _channel;
    store.collectionWithholding = tax;
    store.collectionNote = _note.text.trim();
    pushRoute(context, SignatureScreen(amount: collected));
  }

  @override
  Widget build(BuildContext context) {
    final customer = FieldScope.of(context).customer;
    final due = (customer?.outstanding ?? 0).round();
    final collected = _ready ? _read(_amount, due) : 0;
    final tax = _ready ? _read(_tax, due) : 0;
    final after = due - collected - tax;
    final address = [
      customer?.street,
      customer?.area,
    ].where((part) => part != null && part.isNotEmpty).join(', ');
    final lastPayment = customer?.lastPaymentLabel;
    return RoutePage(
      title: 'New Collection & Recovery',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: customer == null
                ? null
                : () => launchUrl(
                    Uri.parse(
                      'https://wa.me/?text=${Uri.encodeComponent('${customer.businessName} (${customer.code}) owes ${_pkr(due)}.')}',
                    ),
                    mode: LaunchMode.externalApplication,
                  ),
            icon: const Icon(Icons.share_outlined, color: RouteColors.ink),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () => pushRoute(context, const SettingsScreen()),
            icon: const CircleAvatar(
              radius: 16,
              backgroundColor: RouteColors.primary,
              child: Icon(Icons.person, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
      bottom: Material(
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FilledButton.icon(
                onPressed: () => _continue(due, collected, tax),
                style: FilledButton.styleFrom(
                  backgroundColor: RouteColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.draw_outlined, size: 18),
                label: Text(
                  'Continue to Signature (${_pkr(collected)})',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: routeType(14, FontWeight.w700, Colors.white, 20),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: Text(
                  'Cancel',
                  style: routeType(
                    13,
                    FontWeight.w600,
                    RouteColors.secondary,
                    18,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        children: [
          Text(
            'CUSTOMER DEBT RECOVERY',
            style: routeType(
              11,
              FontWeight.w700,
              RouteColors.secondary,
              16,
              0.6,
            ),
          ),
          Text(
            'Standalone balance reconciliation without a delivery.',
            style: routeType(12, FontWeight.w400, RouteColors.secondary, 16),
          ),
          const SizedBox(height: 10),
          RouteCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.storefront_outlined,
                      color: RouteColors.primary,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        customer?.businessName ?? 'Customer',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: routeType(
                          15,
                          FontWeight.w700,
                          RouteColors.ink,
                          20,
                        ),
                      ),
                    ),
                    Text(
                      customer?.code ?? '',
                      style: routeType(
                        12,
                        FontWeight.w700,
                        RouteColors.primary,
                        16,
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: customer == null
                          ? null
                          : () => launchUrl(
                              Uri(
                                scheme: 'tel',
                                path: customer.phone.replaceAll(' ', ''),
                              ),
                              mode: LaunchMode.externalApplication,
                            ),
                      icon: const Icon(
                        Icons.phone_outlined,
                        color: RouteColors.primary,
                        size: 18,
                      ),
                    ),
                  ],
                ),
                if (address.isNotEmpty)
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 14,
                        color: RouteColors.primary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          address,
                          style: routeType(
                            12,
                            FontWeight.w500,
                            RouteColors.secondary,
                            16,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          RouteCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'OUTSTANDING BALANCE',
                        style: routeType(
                          11,
                          FontWeight.w700,
                          RouteColors.secondary,
                          14,
                          0.3,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: due > 0
                            ? const Color(0xFFFFF4E5)
                            : const Color(0xFFE5F6EC),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        due > 0 ? 'Uncollected Due' : 'Settled',
                        style: routeType(
                          10,
                          FontWeight.w700,
                          due > 0 ? const Color(0xFFB26A00) : RouteColors.ok,
                          14,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  _pkr(due),
                  style: routeType(
                    28,
                    FontWeight.w700,
                    due > 0 ? RouteColors.ink : RouteColors.ok,
                    32,
                  ),
                ),
                Text(
                  'Total ledger balance currently due from this account.',
                  style: routeType(
                    12,
                    FontWeight.w400,
                    RouteColors.secondary,
                    16,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        lastPayment == null
                            ? 'No payment recorded yet'
                            : 'Last Payment: $lastPayment',
                        style: routeType(
                          12,
                          FontWeight.w600,
                          RouteColors.ink,
                          16,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.verified_outlined,
                      size: 14,
                      color: RouteColors.ok,
                    ),
                    Text(
                      ' Ledger Verified',
                      style: routeType(11, FontWeight.w700, RouteColors.ok, 14),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Amount to Collect',
                  style: routeType(15, FontWeight.w700, RouteColors.ink, 20),
                ),
              ),
              Text(
                'Cash drawer ready',
                style: routeType(11, FontWeight.w600, RouteColors.ok, 14),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _amount,
            focusNode: _amountFocus,
            keyboardType: TextInputType.number,
            style: routeType(22, FontWeight.w700, RouteColors.ink, 28),
            decoration: InputDecoration(
              prefixText: 'PKR ',
              filled: true,
              fillColor: Colors.white,
              suffixIcon: IconButton(
                onPressed: () => _amountFocus.requestFocus(),
                icon: const Icon(Icons.edit_outlined),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: RouteColors.line),
              ),
            ),
            onChanged: (value) {
              final parsed =
                  int.tryParse(value.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
              final next = parsed > due ? due : parsed;
              if (parsed > due) {
                _amount.text = '$due';
                _amount.selection = TextSelection.collapsed(
                  offset: _amount.text.length,
                );
              }
              if (next + _read(_tax, due) > due) _tax.text = '${due - next}';
              setState(() {});
            },
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (due >= 500)
                _amountChip(
                  'PKR 500',
                  collected == 500,
                  () => setState(() => _setAmount(500, due)),
                ),
              if (due >= 1000)
                _amountChip(
                  'PKR 1,000',
                  collected == 1000,
                  () => setState(() => _setAmount(1000, due)),
                ),
              _amountChip(
                'Full Balance (${_pkr(due)})',
                collected == due && due > 0,
                () => setState(() => _setAmount(due, due)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Payment Channel',
                  style: routeType(15, FontWeight.w700, RouteColors.ink, 20),
                ),
              ),
              Text(
                'Select one',
                style: routeType(
                  11,
                  FontWeight.w500,
                  RouteColors.secondary,
                  14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _collectChannel(
                'Cash',
                'Cash',
                'Immediate drawer',
                Icons.payments_outlined,
              ),
              const SizedBox(width: 8),
              _collectChannel(
                'Bank Transfer',
                'Bank Transfer',
                'IBFT / Raast',
                Icons.account_balance_outlined,
              ),
              const SizedBox(width: 8),
              _collectChannel(
                'Wallet',
                'Mobile Wallet',
                'Easypaisa / Jazz',
                Icons.account_balance_wallet_outlined,
              ),
            ],
          ),
          const SizedBox(height: 10),
          RouteCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.receipt_long_outlined,
                      size: 16,
                      color: RouteColors.primary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Withholding Tax (WHT)',
                        style: routeType(
                          14,
                          FontWeight.w700,
                          RouteColors.ink,
                          20,
                        ),
                      ),
                    ),
                    Text(
                      'Optional',
                      style: routeType(
                        11,
                        FontWeight.w600,
                        RouteColors.secondary,
                        14,
                      ),
                    ),
                  ],
                ),
                Text(
                  'Deducted at source by the customer. Stored separately from the cash collected.',
                  style: routeType(
                    12,
                    FontWeight.w400,
                    RouteColors.secondary,
                    16,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _tax,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          prefixText: 'PKR ',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) {
                          final room = due - collected;
                          final parsed =
                              int.tryParse(
                                value.replaceAll(RegExp(r'[^0-9]'), ''),
                              ) ??
                              0;
                          if (parsed > room) {
                            _tax.text = '$room';
                            _tax.selection = TextSelection.collapsed(
                              offset: _tax.text.length,
                            );
                          }
                          setState(() {});
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () => setState(() => _tax.text = '0'),
                      child: const Text('Set 0'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          RouteCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ledger Impact Breakdown',
                  style: routeType(14, FontWeight.w700, RouteColors.ink, 20),
                ),
                const SizedBox(height: 8),
                _summaryRow('Outstanding Before Collection', _pkr(due)),
                _summaryRow(
                  'Collection Amount',
                  '- ${_pkr(collected)}',
                  valueColor: RouteColors.danger,
                ),
                _summaryRow(
                  'WHT Deducted',
                  _pkr(tax),
                  valueColor: RouteColors.ok,
                ),
                const Divider(),
                _summaryRow(
                  'Outstanding After Collection',
                  _pkr(after < 0 ? 0 : after),
                ),
                Text(
                  after <= 0
                      ? 'Account settled by this collection'
                      : 'Pending account liability',
                  style: routeType(
                    11,
                    FontWeight.w500,
                    RouteColors.secondary,
                    14,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Collection Reference / Notes',
                  style: routeType(14, FontWeight.w700, RouteColors.ink, 20),
                ),
              ),
              Text(
                'Optional',
                style: routeType(
                  11,
                  FontWeight.w600,
                  RouteColors.secondary,
                  14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _note,
            maxLines: 3,
            maxLength: 300,
            decoration: InputDecoration(
              hintText: 'Add a reference or payment note, such as who handed over the cash.',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          Row(
            children: [
              const Icon(
                Icons.cloud_queue,
                size: 16,
                color: RouteColors.primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'This stays Collected by Rider until the warehouse confirms the physical cash. It is not company cash yet.',
                  style: routeType(
                    12,
                    FontWeight.w500,
                    RouteColors.secondary,
                    16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(onPressed: _submitHandover, child: const Text("Submit today's cash handover")),
          ),
        ],
      ),
    );
  }

  Future<void> _submitHandover() async {
    final today = DateTime.now();
    final date = '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    try {
      final handover = await ApiScope.of(context).submitCashHandover(businessDate: date);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${handover.referenceNumber} submitted. Expected ${handover.expectedAmount}.')));
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Widget _collectChannel(
    String value,
    String title,
    String subtitle,
    IconData icon,
  ) {
    final selected = _channel == value;
    return Expanded(
      child: Material(
        color: selected ? RouteColors.pale : Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () => setState(() => _channel = value),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? RouteColors.primary : RouteColors.line,
                width: selected ? 1.4 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      icon,
                      size: 16,
                      color: selected
                          ? RouteColors.primary
                          : RouteColors.secondary,
                    ),
                    const Spacer(),
                    Icon(
                      selected ? Icons.check_circle : Icons.circle_outlined,
                      size: 14,
                      color: selected ? RouteColors.primary : RouteColors.muted,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  title,
                  maxLines: 2,
                  style: routeType(11, FontWeight.w700, RouteColors.ink, 14),
                ),
                Text(
                  subtitle,
                  maxLines: 2,
                  style: routeType(
                    9,
                    FontWeight.w500,
                    RouteColors.secondary,
                    12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class NewOrderScreen extends StatefulWidget {
  const NewOrderScreen({super.key});

  @override
  State<NewOrderScreen> createState() => _NewOrderScreenState();
}

class _NewOrderScreenState extends State<NewOrderScreen> {
  static const _windows = [
    ('Morning', 'Morning Window', '08:00 AM – 12:00 PM'),
    ('Afternoon', 'Afternoon Window', '12:00 PM – 05:00 PM'),
    ('Evening', 'Evening Window', '05:00 PM – 09:00 PM'),
  ];

  final _note = TextEditingController();
  final Map<String, int> _qty = {};
  late final DateTime _today;
  late DateTime _date;
  var _window = 'Morning';
  var _asked = false;
  var _seeded = false;
  var _notesOpen = false;
  var _onManifest = true;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _today = DateTime(now.year, now.month, now.day);
    _date = _today.add(const Duration(days: 2));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_asked) return;
    _asked = true;
    final store = FieldScope.of(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) store.loadSale();
    });
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _seed(List<ProductItem> products) {
    if (_seeded || products.isEmpty) return;
    _seeded = true;
    final bottle = products.where((item) => item.isReturnable).firstOrNull;
    final pack = products
        .where((item) => item.name.toLowerCase().contains('500'))
        .firstOrNull;
    if (bottle != null) _qty[bottle.id] = 4;
    if (pack != null && pack.id != bottle?.id) _qty[pack.id] = 1;
  }

  int _count(String id) => _qty[id] ?? 0;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: _today,
      lastDate: _today.add(const Duration(days: 60)),
    );
    if (picked == null) return;
    setState(() => _date = DateTime(picked.year, picked.month, picked.day));
  }

  Future<void> _confirm(FieldStore store) async {
    final selected = {
      for (final entry in _qty.entries)
        if (entry.value > 0) entry.key: entry.value,
    };
    if (selected.isEmpty) {
      _opsNote(context, 'Add at least one product.');
      return;
    }
    setState(() => _saving = true);
    final note = _note.text.trim();
    await store.placeOrder(
      selected,
      _window,
      deliveryDate:
          '${_date.year.toString().padLeft(4, '0')}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}',
      note: note.isEmpty ? null : note,
      showOnManifest: _onManifest,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (store.error != null) {
      _opsNote(context, store.error!);
      return;
    }
    _opsNote(context, 'Order scheduled for ${_orderDate(_date)}.');
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final store = FieldScope.of(context);
    final customer = store.customer;
    final dash = store.dashboard;
    final products = store.saleContext?.products ?? const <ProductItem>[];
    if (products.isNotEmpty) _seed(products);
    final selected = products.where((item) => _count(item.id) > 0).length;
    final units = products.fold<int>(0, (sum, item) => sum + _count(item.id));
    final value = products.fold<int>(
      0,
      (sum, item) => sum + _count(item.id) * item.unitPrice.round(),
    );
    final ahead = _date.difference(_today).inDays;
    final address = [
      customer?.street,
      customer?.area,
    ].where((part) => part != null && part.isNotEmpty).join(', ');
    final routeName = customer?.routeName ?? dash?.routeName ?? '';
    final rider = dash == null || dash.riderName.isEmpty
        ? ''
        : '${dash.riderName} · ${dash.riderCode}';
    return RoutePage(
      title: 'New Order',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: RouteColors.pale,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'DRAFT',
              style: routeType(10, FontWeight.w700, RouteColors.primary, 14),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () => launchUrl(
              Uri.parse(
                'https://wa.me/?text=${Uri.encodeComponent('${customer?.businessName ?? 'Customer'} order for ${_orderDate(_date)}. $selected products, ${_pkr(value)}.')}',
              ),
              mode: LaunchMode.externalApplication,
            ),
            icon: const Icon(Icons.share_outlined, color: RouteColors.ink),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () => pushRoute(context, const SettingsScreen()),
            icon: const CircleAvatar(
              radius: 16,
              backgroundColor: RouteColors.primary,
              child: Icon(Icons.person, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
      bottom: Material(
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FilledButton.icon(
                onPressed: _saving || products.isEmpty
                    ? null
                    : () => _confirm(store),
                style: FilledButton.styleFrom(
                  backgroundColor: RouteColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.event_available_outlined, size: 18),
                label: Text(
                  'Confirm & Schedule Order',
                  style: routeType(14, FontWeight.w700, Colors.white, 20),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: Text(
                  'Cancel',
                  style: routeType(
                    13,
                    FontWeight.w600,
                    RouteColors.secondary,
                    18,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        children: [
          RouteCard(
            color: RouteColors.pale,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Future Order · Van Stock Untouched',
                  style: routeType(
                    13,
                    FontWeight.w700,
                    RouteColors.primary,
                    18,
                  ),
                ),
                Text(
                  'Stock is reserved for the morning depot load. Today’s van count does not change.',
                  style: routeType(
                    12,
                    FontWeight.w400,
                    RouteColors.secondary,
                    16,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          RouteCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.storefront_outlined,
                      color: RouteColors.primary,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        customer?.businessName ?? 'Customer',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: routeType(
                          15,
                          FontWeight.w700,
                          RouteColors.ink,
                          20,
                        ),
                      ),
                    ),
                    Text(
                      customer?.code ?? '',
                      style: routeType(
                        12,
                        FontWeight.w700,
                        RouteColors.primary,
                        16,
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: customer == null
                          ? null
                          : () => launchUrl(
                              Uri(
                                scheme: 'tel',
                                path: customer.phone.replaceAll(' ', ''),
                              ),
                              mode: LaunchMode.externalApplication,
                            ),
                      icon: const Icon(
                        Icons.phone_outlined,
                        color: RouteColors.primary,
                        size: 18,
                      ),
                    ),
                  ],
                ),
                if (address.isNotEmpty)
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 14,
                        color: RouteColors.primary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          address,
                          style: routeType(
                            12,
                            FontWeight.w500,
                            RouteColors.secondary,
                            16,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Order Products',
                  style: routeType(16, FontWeight.w700, RouteColors.ink, 22),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: RouteColors.pale,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  selected == 1 ? '1 item' : '$selected items',
                  style: routeType(
                    10,
                    FontWeight.w700,
                    RouteColors.primary,
                    14,
                  ),
                ),
              ),
            ],
          ),
          Text(
            'Steppers set the quantity for the scheduled delivery.',
            style: routeType(12, FontWeight.w400, RouteColors.secondary, 16),
          ),
          const SizedBox(height: 8),
          if (products.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            for (final product in products) ...[
              _orderProduct(
                product,
                _count(product.id),
                (next) => setState(() => _qty[product.id] = _bound(next, 99)),
              ),
              const SizedBox(height: 8),
            ],
          OutlinedButton.icon(
            onPressed: products.isEmpty
                ? null
                : () => showModalBottomSheet<void>(
                    context: context,
                    builder: (sheet) => SafeArea(
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                            child: Text(
                              'Add a product',
                              style: routeType(
                                16,
                                FontWeight.w700,
                                RouteColors.ink,
                                22,
                              ),
                            ),
                          ),
                          for (final product in products)
                            ListTile(
                              title: Text(product.name),
                              subtitle: Text(
                                'PKR ${product.unitPrice.round()} / ${product.unitLabel}',
                              ),
                              trailing: Text('${_count(product.id)}'),
                              onTap: () {
                                Navigator.of(sheet).pop();
                                setState(
                                  () => _qty[product.id] = _bound(
                                    _count(product.id) + 1,
                                    99,
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
            icon: const Icon(Icons.add),
            label: const Text('Add Another Product'),
          ),
          const SizedBox(height: 12),
          Text(
            'Schedule Delivery',
            style: routeType(16, FontWeight.w700, RouteColors.ink, 22),
          ),
          Text(
            'Choose the dispatch day and the gate drop window.',
            style: routeType(12, FontWeight.w400, RouteColors.secondary, 16),
          ),
          const SizedBox(height: 8),
          Text(
            'Target route date',
            style: routeType(12, FontWeight.w600, RouteColors.secondary, 16),
          ),
          const SizedBox(height: 6),
          InkWell(
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: RouteColors.line),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 16,
                    color: RouteColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _orderDate(_date),
                      style: routeType(
                        14,
                        FontWeight.w700,
                        RouteColors.ink,
                        20,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: RouteColors.pale,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      ahead == 0
                          ? 'Today'
                          : '+$ahead ${ahead == 1 ? 'Day' : 'Days'}',
                      style: routeType(
                        11,
                        FontWeight.w700,
                        RouteColors.primary,
                        14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Delivery Time Window',
            style: routeType(12, FontWeight.w600, RouteColors.secondary, 16),
          ),
          const SizedBox(height: 6),
          for (final window in _windows) ...[
            _windowCard(window.$1, window.$2, window.$3),
            const SizedBox(height: 8),
          ],
          RouteCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dispatch Assignment Plan',
                  style: routeType(14, FontWeight.w700, RouteColors.ink, 20),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _assignBox(
                        'Assigned Route',
                        routeName.isEmpty ? 'This customer’s route' : routeName,
                        'Auto-allocated',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _assignBox(
                        'Designated Rider',
                        rider.isEmpty ? 'Signed-in rider' : rider,
                        'On this route',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Stock is scheduled for the ${_orderDate(_date)} morning depot load.',
                  style: routeType(
                    12,
                    FontWeight.w500,
                    RouteColors.secondary,
                    16,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () => setState(() => _notesOpen = !_notesOpen),
            child: Row(
              children: [
                Icon(
                  _notesOpen ? Icons.expand_more : Icons.chevron_right,
                  color: RouteColors.primary,
                ),
                Expanded(
                  child: Text(
                    'Order Notes & Special Instructions',
                    style: routeType(14, FontWeight.w700, RouteColors.ink, 20),
                  ),
                ),
              ],
            ),
          ),
          if (_notesOpen) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _note,
              maxLines: 3,
              maxLength: 300,
              decoration: InputDecoration(
                hintText: 'Example: deliver before noon prayer and unload at the rear rack.',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _onManifest,
              onChanged: (value) => setState(() => _onManifest = value ?? true),
              title: Text(
                'Visible on the rider delivery manifest',
                style: routeType(13, FontWeight.w600, RouteColors.ink, 18),
              ),
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ],
          const SizedBox(height: 8),
          RouteCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Order Summary',
                        style: routeType(
                          15,
                          FontWeight.w700,
                          RouteColors.ink,
                          20,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF4E5),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'Doorstep COD',
                        style: routeType(
                          10,
                          FontWeight.w700,
                          const Color(0xFFB26A00),
                          14,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _summaryRow(
                  'Total Line Items',
                  '$selected ${selected == 1 ? 'product' : 'products'}',
                ),
                _summaryRow(
                  'Total Scheduled Quantity',
                  '$units ${units == 1 ? 'unit' : 'units'}',
                ),
                const Divider(),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Estimated Order Value',
                        style: routeType(
                          13,
                          FontWeight.w700,
                          RouteColors.ink,
                          18,
                        ),
                      ),
                    ),
                    Text(
                      _pkr(value),
                      style: routeType(
                        20,
                        FontWeight.w700,
                        RouteColors.primary,
                        24,
                      ),
                    ),
                  ],
                ),
                Text(
                  'Payment is collected at the doorstep on the delivery date.',
                  style: routeType(
                    12,
                    FontWeight.w400,
                    RouteColors.secondary,
                    16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _windowCard(String value, String title, String hours) {
    final selected = _window == value;
    return Material(
      color: selected ? RouteColors.pale : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => setState(() => _window = value),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? RouteColors.primary : RouteColors.line,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? RouteColors.primary : RouteColors.muted,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: routeType(14, FontWeight.w700, RouteColors.ink, 20),
                ),
              ),
              Text(
                hours,
                style: routeType(
                  11,
                  FontWeight.w600,
                  RouteColors.secondary,
                  14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _orderProduct(
  ProductItem product,
  int quantity,
  ValueChanged<int> onChanged,
) {
  final hint = product.isReturnable
      ? 'Returnable container'
      : (_packHint(product) ?? product.unitLabel);
  return RouteCard(
    padding: const EdgeInsets.all(12),
    child: Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: product.isReturnable
                    ? RouteColors.pale
                    : const Color(0xFFF4F7FB),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                product.isReturnable
                    ? Icons.water_drop_outlined
                    : Icons.inventory_2_outlined,
                color: RouteColors.primary,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: routeType(14, FontWeight.w700, RouteColors.ink, 20),
                  ),
                  Text(
                    hint,
                    style: routeType(
                      11,
                      FontWeight.w500,
                      RouteColors.secondary,
                      14,
                    ),
                  ),
                  Text(
                    'PKR ${product.unitPrice.round()} / ${product.unitLabel}',
                    style: routeType(11, FontWeight.w600, RouteColors.ink, 14),
                  ),
                ],
              ),
            ),
            Text(
              _pkr(quantity * product.unitPrice.round()),
              style: routeType(
                13,
                FontWeight.w700,
                quantity == 0 ? RouteColors.muted : RouteColors.ink,
                18,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              'Scheduled Qty',
              style: routeType(12, FontWeight.w600, RouteColors.secondary, 16),
            ),
            const Spacer(),
            _QtyStepper(quantity: quantity, onChanged: onChanged),
          ],
        ),
      ],
    ),
  );
}

Widget _assignBox(String label, String value, String note) {
  return Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: const Color(0xFFF4F7FB),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: routeType(10, FontWeight.w700, RouteColors.secondary, 14),
        ),
        Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: routeType(12, FontWeight.w700, RouteColors.ink, 16),
        ),
        Text(
          note,
          style: routeType(10, FontWeight.w500, RouteColors.muted, 14),
        ),
      ],
    ),
  );
}

String _orderDate(DateTime date) {
  const weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${weekdays[date.weekday - 1]}, ${date.day} ${months[date.month - 1]} ${date.year}';
}

class LedgerScreen extends StatefulWidget {
  const LedgerScreen({super.key});

  @override
  State<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends State<LedgerScreen> {
  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  var _asked = false;
  var _days = 30;
  var _tab = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_asked) return;
    _asked = true;
    final store = FieldScope.of(context);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (store.stops.isEmpty) await store.loadStops();
      if (!mounted) return;
      if (store.customer == null && store.stops.isNotEmpty) {
        await store.openStop(store.stops.first);
      }
      if (mounted) await store.loadLedger();
    });
  }

  List<LedgerRow> _visible(List<LedgerRow> entries) {
    final now = DateTime.now();
    final start = _days == 0
        ? null
        : DateTime(
            now.year,
            now.month,
            now.day,
          ).subtract(Duration(days: _days));
    return [
      for (final entry in entries)
        if ((start == null || !entry.occurredAt.isBefore(start)) &&
            (_tab == 0 ||
                (_tab == 1 && !entry.isCredit) ||
                (_tab == 2 && entry.isCredit)))
          entry,
    ];
  }

  String _span() {
    final now = DateTime.now();
    if (_days == 0) return 'Full account history';
    final start = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: _days));
    return '${start.day} ${_months[start.month - 1]} – ${now.day} ${_months[now.month - 1]} ${now.year}';
  }

  String _short(DateTime value) =>
      '${value.day} ${_months[value.month - 1]} ${value.year}';

  Future<void> _share(LedgerData? ledger, CustomerDetail? customer) async {
    final name = ledger?.customerName ?? customer?.businessName ?? 'Customer';
    final code = ledger?.customerCode ?? customer?.code ?? '';
    final balance = _pkr(ledger?.outstanding ?? customer?.outstanding ?? 0);
    final issued = ledger?.bottlesIssued ?? customer?.bottlesIssued ?? 0;
    final returned = ledger?.bottlesReturned ?? customer?.bottlesReturned ?? 0;
    final held = ledger?.bottlesHeld ?? customer?.bottlesHeld ?? 0;
    final lines = (ledger?.entries ?? const <LedgerRow>[])
        .take(8)
        .map((entry) {
          final sign = entry.isCredit ? '−' : '+';
          final ref = entry.reference == null ? '' : ' ${entry.reference}';
          return '$sign ${_pkr(entry.amount.abs())} ${entry.description}$ref';
        })
        .join('\n');
    final text =
        '$name ($code)\nOutstanding $balance\nCycle Net ${ledger?.creditDays ?? customer?.creditDays ?? 7}\nBottles issued $issued, returned $returned, holding $held\n$lines';
    final opened = await launchUrl(
      Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}'),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      _opsNote(context, 'WhatsApp could not be opened on this phone.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = FieldScope.of(context);
    final ledger = store.ledger;
    final customer = store.customer;
    final entries = _visible(ledger?.entries ?? const []);
    final outstanding = ledger?.outstanding ?? customer?.outstanding ?? 0;
    final issued = ledger?.bottlesIssued ?? customer?.bottlesIssued ?? 0;
    final returned = ledger?.bottlesReturned ?? customer?.bottlesReturned ?? 0;
    final held = ledger?.bottlesHeld ?? customer?.bottlesHeld ?? 0;
    final ratio = issued == 0
        ? 0.0
        : (returned / issued).clamp(0, 1).toDouble();
    final name = ledger?.customerName ?? customer?.businessName ?? 'Customer';
    final code = ledger?.customerCode ?? customer?.code ?? '';
    final area = customer?.area ?? '';
    final address = [
      customer?.street,
      customer?.area,
      customer?.city,
    ].where((part) => part != null && part.isNotEmpty).join(', ');
    final phone = customer?.phone ?? '';
    final stop = ledger?.stopSequence;
    final routeLine = stop == null
        ? (customer?.routeName ?? 'Assigned route')
        : 'Direct Route Stop #${stop.toString().padLeft(2, '0')}';
    final openOrders = ledger?.openOrders ?? customer?.openOrders ?? 0;
    return RoutePage(
      title: 'Customer Ledger',
      navIndex: 1,
      onNav: (index) {
        if (index == 3) {
          pushRoute(context, const SettingsScreen());
          return;
        }
        popToRiderHome(context);
      },
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () => _share(ledger, customer),
            icon: const Icon(Icons.share_outlined, color: RouteColors.ink),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () => pushRoute(context, const SettingsScreen()),
            icon: const CircleAvatar(
              radius: 16,
              backgroundColor: RouteColors.primary,
              child: Icon(Icons.person, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: store.loadLedger,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          children: [
            if (store.stops.isNotEmpty)
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final stop in store.stops)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(stop.customerName),
                          selected: store.customer?.id == stop.customerId,
                          onSelected: (_) async {
                            await store.openStop(stop);
                            if (context.mounted) await store.loadLedger();
                          },
                        ),
                      ),
                  ],
                ),
              ),
            if (store.stops.isNotEmpty) const SizedBox(height: 8),
            if (store.customer == null && store.stops.isEmpty)
              Text(
                store.loading
                    ? 'Loading today\'s customers...'
                    : 'No customers are on today\'s route.',
                style: routeType(14, FontWeight.w600, RouteColors.secondary, 20),
              ),
            RouteCard(
              padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.storefront_outlined,
                        color: RouteColors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: routeType(
                                16,
                                FontWeight.w700,
                                RouteColors.ink,
                                22,
                              ),
                            ),
                            Text(
                              '$code${area.isEmpty ? '' : ' · $area'}',
                              style: routeType(
                                12,
                                FontWeight.w600,
                                RouteColors.primary,
                                16,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: phone.isEmpty
                            ? null
                            : () => launchUrl(
                                Uri(
                                  scheme: 'tel',
                                  path: phone.replaceAll(' ', ''),
                                ),
                                mode: LaunchMode.externalApplication,
                              ),
                        icon: const Icon(
                          Icons.phone_outlined,
                          color: RouteColors.primary,
                        ),
                      ),
                    ],
                  ),
                  if (address.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 2, bottom: 4),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 14,
                            color: RouteColors.primary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              address,
                              style: routeType(
                                12,
                                FontWeight.w500,
                                RouteColors.secondary,
                                16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(left: 2),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.route_outlined,
                          size: 14,
                          color: RouteColors.ok,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            routeLine,
                            style: routeType(
                              12,
                              FontWeight.w600,
                              RouteColors.secondary,
                              16,
                            ),
                          ),
                        ),
                        if (phone.isNotEmpty)
                          Text(
                            phone,
                            style: routeType(
                              12,
                              FontWeight.w600,
                              RouteColors.ink,
                              16,
                            ),
                          ),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: RouteColors.primary,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'CURRENT OUTSTANDING BALANCE',
                          style: routeType(
                            11,
                            FontWeight.w700,
                            Colors.white70,
                            14,
                            0.4,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          outstanding > 0 ? 'Active Credit' : 'Settled',
                          style: routeType(
                            10,
                            FontWeight.w700,
                            Colors.white,
                            14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _pkr(outstanding),
                    style: routeType(28, FontWeight.w700, Colors.white, 34),
                  ),
                  Text(
                    'As of ${_short(DateTime.now())} · Verified     Cycle: Net ${ledger?.creditDays ?? customer?.creditDays ?? 7}',
                    style: routeType(12, FontWeight.w500, Colors.white70, 16),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _ledgerStat(
                    'Today’s Collections',
                    _pkr(ledger?.todayCollected ?? 0),
                    Icons.payments_outlined,
                    RouteColors.ok,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ledgerStat(
                    'Open Invoices',
                    openOrders == 1 ? '1 Order' : '$openOrders Orders',
                    Icons.receipt_long_outlined,
                    RouteColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            PopupMenuButton<int>(
              onSelected: (value) => setState(() => _days = value),
              itemBuilder: (context) => const [
                PopupMenuItem(value: 7, child: Text('Last 7 Days')),
                PopupMenuItem(value: 30, child: Text('Last 30 Days')),
                PopupMenuItem(value: 90, child: Text('Last 90 Days')),
                PopupMenuItem(value: 0, child: Text('All activity')),
              ],
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: RouteColors.line),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 16,
                      color: RouteColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${_days == 0 ? 'All activity' : 'Last $_days Days'} (${_span()})',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: routeType(
                          13,
                          FontWeight.w600,
                          RouteColors.ink,
                          18,
                        ),
                      ),
                    ),
                    const Icon(Icons.expand_more, color: RouteColors.secondary),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _filterChip(0, 'All'),
                const SizedBox(width: 6),
                _filterChip(1, 'Sales (Debit)'),
                const SizedBox(width: 6),
                _filterChip(2, 'Collections'),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Account Transactions',
                    style: routeType(16, FontWeight.w700, RouteColors.ink, 22),
                  ),
                ),
                Text(
                  '${entries.length}',
                  style: routeType(
                    12,
                    FontWeight.w700,
                    RouteColors.primary,
                    16,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.circle, size: 8, color: RouteColors.ok),
                const SizedBox(width: 4),
                Text(
                  'Live',
                  style: routeType(11, FontWeight.w600, RouteColors.ok, 14),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (ledger == null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: store.loading
                      ? const CircularProgressIndicator()
                      : Text(
                          'Open a customer to load the ledger.',
                          style: routeType(
                            13,
                            FontWeight.w500,
                            RouteColors.secondary,
                            18,
                          ),
                        ),
                ),
              )
            else if (entries.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'No transactions in this range.',
                  style: routeType(
                    13,
                    FontWeight.w500,
                    RouteColors.secondary,
                    18,
                  ),
                ),
              )
            else
              for (final entry in entries) ...[
                _ledgerEntry(entry),
                const SizedBox(height: 8),
              ],
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Returnable Assets',
                    style: routeType(16, FontWeight.w700, RouteColors.ink, 22),
                  ),
                ),
                const Icon(Icons.circle, size: 8, color: RouteColors.ok),
                const SizedBox(width: 4),
                Text(
                  'Live Audit',
                  style: routeType(11, FontWeight.w700, RouteColors.ok, 14),
                ),
              ],
            ),
            Text(
              '19-litre commercial bottles',
              style: routeType(12, FontWeight.w500, RouteColors.secondary, 16),
            ),
            const SizedBox(height: 8),
            RouteCard(
              child: Column(
                children: [
                  Row(
                    children: [
                      _assetBox('ISSUED', '$issued', 'Bottles'),
                      const SizedBox(width: 8),
                      _assetBox('RETURNED', '$returned', 'Bottles'),
                      const SizedBox(width: 8),
                      _assetBox(
                        'HOLDING',
                        '$held',
                        'With store',
                        valueColor: RouteColors.primary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Asset Return Ratio',
                          style: routeType(
                            12,
                            FontWeight.w600,
                            RouteColors.secondary,
                            16,
                          ),
                        ),
                      ),
                      Text(
                        '${(ratio * 100).round()}% Reconciled',
                        style: routeType(
                          12,
                          FontWeight.w700,
                          RouteColors.ok,
                          16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: ratio,
                      minHeight: 8,
                      backgroundColor: RouteColors.line,
                      color: RouteColors.ok,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Recent Movement Log',
              style: routeType(16, FontWeight.w700, RouteColors.ink, 22),
            ),
            const SizedBox(height: 8),
            if ((ledger?.movements ?? const []).isEmpty)
              Text(
                'No bottle handoffs on completed sales yet.',
                style: routeType(
                  13,
                  FontWeight.w500,
                  RouteColors.secondary,
                  18,
                ),
              )
            else
              for (final move in ledger!.movements) ...[
                _movement(move),
                const SizedBox(height: 8),
              ],
            const SizedBox(height: 8),
            RouteCard(
              color: RouteColors.pale,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.verified_outlined,
                    color: RouteColors.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Audit Transparency',
                          style: routeType(
                            13,
                            FontWeight.w700,
                            RouteColors.ink,
                            18,
                          ),
                        ),
                        Text(
                          'The statement sent to the storekeeper uses this balance, these transactions, and the bottle counts above.',
                          style: routeType(
                            12,
                            FontWeight.w400,
                            RouteColors.secondary,
                            16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            RouteButton(
              label: 'Share Ledger Statement',
              icon: const Icon(
                Icons.share_outlined,
                color: Colors.white,
                size: 18,
              ),
              onPressed: () => _share(ledger, customer),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(int index, String label) {
    final selected = _tab == index;
    return Expanded(
      child: Material(
        color: selected ? RouteColors.primary : Colors.white,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: () => setState(() => _tab = index),
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: selected ? RouteColors.primary : RouteColors.line,
              ),
            ),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: routeType(
                11,
                FontWeight.w700,
                selected ? Colors.white : RouteColors.secondary,
                14,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Widget _ledgerStat(String label, String value, IconData icon, Color color) {
  return RouteCard(
    padding: const EdgeInsets.all(12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(height: 6),
        Text(
          label,
          style: routeType(11, FontWeight.w600, RouteColors.secondary, 14),
        ),
        Text(value, style: routeType(16, FontWeight.w700, RouteColors.ink, 22)),
      ],
    ),
  );
}

Widget _assetBox(
  String label,
  String value,
  String note, {
  Color valueColor = RouteColors.ink,
}) {
  return Expanded(
    child: Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7FB),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: routeType(
              10,
              FontWeight.w700,
              RouteColors.secondary,
              14,
              0.3,
            ),
          ),
          Text(value, style: routeType(20, FontWeight.w700, valueColor, 24)),
          Text(
            note,
            style: routeType(10, FontWeight.w500, RouteColors.muted, 14),
          ),
        ],
      ),
    ),
  );
}

Widget _ledgerEntry(LedgerRow entry) {
  final credit = entry.isCredit;
  final color = credit ? RouteColors.ok : RouteColors.primary;
  final reference = entry.reference;
  final detail = entry.detail;
  final meta = [
    if (reference != null && reference.isNotEmpty)
      credit ? 'Receipt #$reference' : 'Inv #$reference',
    if (detail != null && detail.isNotEmpty) credit ? detail : 'Rider: $detail',
  ].join(' · ');
  return RouteCard(
    padding: const EdgeInsets.all(12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: credit ? const Color(0xFFE8F6EE) : RouteColors.pale,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            credit ? Icons.payments_outlined : Icons.receipt_long_outlined,
            size: 18,
            color: color,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.description,
                style: routeType(14, FontWeight.w700, RouteColors.ink, 20),
              ),
              Text(
                _ledgerWhen(entry.occurredAt),
                style: routeType(
                  11,
                  FontWeight.w500,
                  RouteColors.secondary,
                  14,
                ),
              ),
              if (meta.isNotEmpty)
                Text(
                  meta,
                  style: routeType(
                    11,
                    FontWeight.w600,
                    RouteColors.secondary,
                    14,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: credit ? const Color(0xFFE8F6EE) : RouteColors.pale,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                credit ? 'CREDIT' : 'DEBIT',
                style: routeType(9, FontWeight.w700, color, 12),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${credit ? '−' : '+'} ${_pkr(entry.amount.abs())}',
              style: routeType(13, FontWeight.w700, color, 18),
            ),
            Text(
              'Bal ${_pkr(entry.balanceAfter)}',
              style: routeType(11, FontWeight.w600, RouteColors.secondary, 14),
            ),
          ],
        ),
      ],
    ),
  );
}

String _ledgerWhen(DateTime value) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final now = DateTime.now();
  final day = DateTime(value.year, value.month, value.day);
  final today = DateTime(now.year, now.month, now.day);
  final date = day == today
      ? 'Today, ${value.day} ${months[value.month - 1]} ${value.year}'
      : '${value.day} ${months[value.month - 1]} ${value.year}';
  final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
  final minute = value.minute.toString().padLeft(2, '0');
  return '$date · $hour:$minute ${value.hour < 12 ? 'AM' : 'PM'}';
}

Widget _movement(BottleMovement move) {
  final title = move.fullGiven == 0
      ? '${move.emptiesReturned} Empties Returned'
      : move.emptiesReturned == 0
      ? '${move.fullGiven} Full Given'
      : '${move.fullGiven} Full Given · ${move.emptiesReturned} Returned';
  return RouteCard(
    padding: const EdgeInsets.all(12),
    child: Row(
      children: [
        const Icon(
          Icons.water_drop_outlined,
          color: RouteColors.primary,
          size: 18,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: routeType(13, FontWeight.w700, RouteColors.ink, 18),
              ),
              Text(
                '${_ledgerWhen(move.occurredAt).split(' · ').first} · ${move.note}',
                style: routeType(
                  11,
                  FontWeight.w500,
                  RouteColors.secondary,
                  14,
                ),
              ),
            ],
          ),
        ),
        Text(
          'Rem: ${move.holdingAfter}',
          style: routeType(12, FontWeight.w700, RouteColors.primary, 16),
        ),
      ],
    ),
  );
}

class CustomerFormScreen extends StatefulWidget {
  const CustomerFormScreen({super.key});

  @override
  State<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends State<CustomerFormScreen> {
  static const _categories = [
    'Retail Store',
    'Restaurant',
    'Office',
    'Household',
  ];

  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _extra = TextEditingController();
  final _street = TextEditingController();
  final _area = TextEditingController();
  final _city = TextEditingController();
  final _debt = TextEditingController(text: '0');
  final _cnic = TextEditingController();
  var _category = _categories.first;
  var _ownership = 'Rented';
  var _held = 0;
  var _creating = true;
  var _ready = false;
  var _saving = false;
  var _locating = false;
  double? _latitude;
  double? _longitude;
  double? _accuracy;
  Uint8List? _photo;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ready) return;
    _ready = true;
    final customer = FieldScope.of(context).customer;
    _creating = customer == null;
    if (customer != null) _apply(customer);
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _phone,
      _extra,
      _street,
      _area,
      _city,
      _debt,
      _cnic,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _apply(CustomerDetail customer) {
    _name.text = customer.businessName;
    _phone.text = customer.phone;
    _extra.text = customer.additionalContact ?? '';
    _street.text = customer.street;
    _area.text = customer.area;
    _city.text = customer.city;
    _debt.text = customer.outstanding.round().toString();
    _cnic.text = customer.cnic ?? '';
    _held = customer.bottlesHeld;
    _ownership = customer.bottleOwnership == 'Own' ? 'Own' : 'Rented';
    _category = customer.category.isEmpty
        ? _categories.first
        : customer.category;
    _latitude = customer.latitude?.toDouble();
    _longitude = customer.longitude?.toDouble();
    _accuracy = null;
    _photo = FieldScope.of(context).storefronts[customer.id];
  }

  void _clear() {
    for (final controller in [
      _name,
      _phone,
      _extra,
      _street,
      _area,
      _city,
      _cnic,
    ]) {
      controller.clear();
    }
    _debt.text = '0';
    _held = 0;
    _ownership = 'Rented';
    _category = _categories.first;
    _latitude = null;
    _longitude = null;
    _accuracy = null;
    _photo = null;
  }

  String? _phoneClash(FieldStore store) {
    final digits = _phone.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 7) return null;
    final self = _creating ? null : store.customer?.id;
    for (final stop in store.stops) {
      if (stop.customerId == self) continue;
      if (stop.phone.replaceAll(RegExp(r'\D'), '') == digits) {
        return stop.customerName;
      }
    }
    return null;
  }

  Future<void> _captureGps() async {
    setState(() => _locating = true);
    try {
      final location = Location();
      var service = await location.serviceEnabled();
      if (!service) service = await location.requestService();
      if (!mounted) return;
      if (!service) {
        _opsNote(context, 'Turn location on to capture the shop pin.');
        return;
      }
      var permission = await location.hasPermission();
      if (permission == PermissionStatus.denied) {
        permission = await location.requestPermission();
      }
      if (!mounted) return;
      final allowed =
          permission == PermissionStatus.granted ||
          permission == PermissionStatus.grantedLimited;
      if (!allowed) {
        _opsNote(context, 'Allow location so the shop pin can be saved.');
        return;
      }
      final here = await location.getLocation().timeout(
        const Duration(seconds: 8),
      );
      if (!mounted) return;
      setState(() {
        _latitude = here.latitude;
        _longitude = here.longitude;
        _accuracy = here.accuracy;
      });
    } catch (_) {
      if (mounted) _opsNote(context, 'The shop location could not be read.');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _retake() async {
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        maxWidth: 1280,
        imageQuality: 70,
      );
      if (file == null || !mounted) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() => _photo = bytes);
      final id = _creating ? null : FieldScope.of(context).customer?.id;
      if (id != null) FieldScope.of(context).saveStorefront(id, bytes);
    } catch (_) {
      if (mounted) _opsNote(context, 'The shopfront photo could not be taken.');
    }
  }

  void _preview() {
    final photo = _photo;
    if (photo == null) return;
    showDialog<void>(
      context: context,
      builder: (dialog) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              child: Image.memory(
                photo,
                height: 320,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialog).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final store = FieldScope.of(context);
    final existing = _creating ? null : store.customer;
    if (existing == null && !_creating) {
      _opsNote(context, 'Open a customer from the route before editing.');
      return;
    }
    final name = _name.text.trim();
    final phone = _phone.text.trim();
    final street = _street.text.trim();
    final area = _area.text.trim();
    final city = _city.text.trim();
    if (name.isEmpty ||
        phone.isEmpty ||
        street.isEmpty ||
        area.isEmpty ||
        city.isEmpty) {
      _opsNote(context, 'Name, mobile, street, area, and city are required.');
      return;
    }
    final debt =
        num.tryParse(_debt.text.replaceAll(RegExp(r'[^0-9.]'), '')) ?? -1;
    if (debt < 0) {
      _opsNote(context, 'Opening debt cannot be negative.');
      return;
    }
    final clash = _phoneClash(store);
    if (clash != null) {
      _opsNote(context, 'This mobile is already on today\'s route for $clash.');
      return;
    }
    setState(() => _saving = true);
    try {
      final saved = await store.saveCustomer(
        CustomerDraft(
          id: existing?.id,
          businessName: name,
          primaryMobile: phone,
          additionalContact: _extra.text.trim().isEmpty
              ? null
              : _extra.text.trim(),
          category: _category,
          street: street,
          area: area,
          city: city,
          latitude: _latitude,
          longitude: _longitude,
          bottleOwnership: _ownership,
          openingDebt: debt,
          openingEmpties: _held,
          cnic: _cnic.text.trim().isEmpty ? null : _cnic.text.trim(),
          contactName: existing?.contactName,
          contactRole: existing?.contactRole,
        ),
      );
      final photo = _photo;
      if (photo != null) store.saveStorefront(saved.id, photo);
      if (!mounted) return;
      final balancesKept =
          existing != null &&
          (saved.outstanding != debt || saved.bottlesHeld != _held);
      _opsNote(
        context,
        balancesKept
            ? 'Customer updated. Opening balances stay on the existing ledger.'
            : 'Customer saved on ${saved.routeName}.',
      );
      Navigator.of(context).maybePop();
    } on ApiException catch (exception) {
      if (!mounted) return;
      setState(() => _saving = false);
      _opsNote(context, exception.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      _opsNote(context, 'The customer could not be saved.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = FieldScope.of(context);
    final customer = _creating ? null : store.customer;
    final routeName = customer?.routeName ?? store.dashboard?.routeName ?? '';
    final clash = _phoneClash(store);
    final onFile =
        customer != null &&
        _phone.text.trim() == customer.phone &&
        customer.phone.isNotEmpty;
    final categories = [
      if (!_categories.contains(_category)) _category,
      ..._categories,
    ];
    final ledgerLocked =
        customer != null &&
        (customer.outstanding > 0 ||
            customer.bottlesIssued > 0 ||
            customer.bottlesReturned > 0);
    final canSave = !_saving && (_creating || customer != null);
    return RoutePage(
      title: 'New / Edit Customer',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: canSave ? _save : null,
            icon: const Icon(Icons.save_outlined, color: RouteColors.ink),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () => pushRoute(context, const SettingsScreen()),
            icon: const CircleAvatar(
              radius: 16,
              backgroundColor: RouteColors.primary,
              child: Icon(Icons.person, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
      bottom: Material(
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FilledButton.icon(
                onPressed: canSave ? _save : null,
                style: FilledButton.styleFrom(
                  backgroundColor: RouteColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.save_outlined, size: 18),
                label: Text(
                  _saving ? 'Saving…' : 'Save Customer & Assign Route',
                  style: routeType(14, FontWeight.w700, Colors.white, 20),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: Text(
                  'Cancel',
                  style: routeType(
                    13,
                    FontWeight.w600,
                    RouteColors.secondary,
                    18,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        children: [
          Row(
            children: [
              _modeChip('Add New Customer', true),
              const SizedBox(width: 8),
              _modeChip('Edit Customer', false),
            ],
          ),
          if (!_creating && customer == null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'Open a customer from today\'s route, then come back to edit that record.',
                style: routeType(
                  13,
                  FontWeight.w500,
                  RouteColors.secondary,
                  18,
                ),
              ),
            ),
          _step('Customer Information', 'Step 1 of 5'),
          _labeled(
            'Customer / Business Name',
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              style: _inputStyle,
              decoration: _inputDecoration('Business name'),
            ),
          ),
          _labeled(
            'Primary Mobile (WhatsApp / SMS)',
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              style: _inputStyle,
              onChanged: (_) => setState(() {}),
              decoration: _inputDecoration('03xx or +92'),
            ),
          ),
          if (clash != null)
            Text(
              'Already on today\'s route for $clash.',
              style: routeType(12, FontWeight.w600, RouteColors.danger, 16),
            )
          else if (onFile)
            Text(
              'Saved on this customer.',
              style: routeType(12, FontWeight.w600, RouteColors.ok, 16),
            ),
          const SizedBox(height: 8),
          _labeled(
            'Additional Contact Number (Optional)',
            TextField(
              controller: _extra,
              keyboardType: TextInputType.phone,
              style: _inputStyle,
              decoration: _inputDecoration('Landline or second mobile'),
            ),
          ),
          _labeled(
            'Customer Category',
            DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: _category,
                items: [
                  for (final item in categories)
                    DropdownMenuItem(
                      value: item,
                      child: Text(item, style: _inputStyle),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _category = value);
                },
              ),
            ),
          ),
          _step('Customer Address & GPS', 'Step 2 of 5'),
          _labeled(
            'Street / Shop Address',
            TextField(
              controller: _street,
              style: _inputStyle,
              decoration: _inputDecoration('Shop number and street'),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: _labeled(
                  'Area / Locality',
                  TextField(
                    controller: _area,
                    style: _inputStyle,
                    decoration: _inputDecoration('Area'),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _labeled(
                  'City',
                  TextField(
                    controller: _city,
                    style: _inputStyle,
                    decoration: _inputDecoration('City'),
                  ),
                ),
              ),
            ],
          ),
          _labeled(
            'Assigned Route / Delivery Sector',
            Row(
              children: [
                const Icon(
                  Icons.lock_outline,
                  size: 16,
                  color: RouteColors.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    routeName.isEmpty ? 'Your signed-in route' : routeName,
                    style: routeType(14, FontWeight.w600, RouteColors.ink, 20),
                  ),
                ),
              ],
            ),
          ),
          Text(
            'New customers are saved on the route you are signed in to.',
            style: routeType(12, FontWeight.w400, RouteColors.secondary, 16),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Field GPS Waypoint',
                  style: routeType(14, FontWeight.w700, RouteColors.ink, 20),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _latitude == null
                      ? RouteColors.pale
                      : const Color(0xFFE8F6EE),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _accuracy != null
                      ? 'Accuracy ${_accuracy!.round()} m'
                      : (_latitude == null ? 'No pin yet' : 'Saved pin'),
                  style: routeType(
                    10,
                    FontWeight.w700,
                    _latitude == null ? RouteColors.secondary : RouteColors.ok,
                    14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_latitude != null && _longitude != null) ...[
            LiveRouteMap(
              height: 160,
              pins: [
                RoutePin(
                  latitude: _latitude!,
                  longitude: _longitude!,
                  label: _name.text.isEmpty ? 'Shop' : _name.text,
                  highlighted: true,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Lat ${_latitude!.toStringAsFixed(5)}, Lng ${_longitude!.toStringAsFixed(5)}',
              style: routeType(12, FontWeight.w600, RouteColors.secondary, 16),
            ),
          ] else
            Container(
              height: 120,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFE7EDF5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'Capture the shop pin to place it on the map.',
                style: routeType(
                  13,
                  FontWeight.w500,
                  RouteColors.secondary,
                  18,
                ),
              ),
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _locating ? null : _captureGps,
            icon: const Icon(Icons.my_location),
            label: Text(
              _locating
                  ? 'Reading location…'
                  : 'Recalibrate / Capture Current GPS',
            ),
          ),
          _step('Container Ownership & Terms', 'Step 3 of 5'),
          _ownershipCard(
            'Rented',
            'RouteLedger Rented Bottles',
            'Company bottles. Issued, returned, and holding counts stay on this customer.',
          ),
          const SizedBox(height: 8),
          _ownershipCard(
            'Own',
            'Customer Own Bottles',
            'The customer supplies the bottles. Ownership is stored as self-supply.',
          ),
          _step('Opening Balances (Day 1 Ledger)', 'Step 4 of 5'),
          if (ledgerLocked)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'This customer already has ledger activity. Saving keeps the current balance and empties.',
                style: routeType(
                  12,
                  FontWeight.w600,
                  RouteColors.secondary,
                  16,
                ),
              ),
            ),
          _labeled(
            'Opening Financial Debt',
            TextField(
              controller: _debt,
              keyboardType: TextInputType.number,
              style: _inputStyle,
              decoration: _inputDecoration('0').copyWith(prefixText: 'PKR '),
            ),
          ),
          Text(
            'Opening 19L Empty Bottles Held',
            style: routeType(12, FontWeight.w600, RouteColors.ink, 16),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: _QtyStepper(
              quantity: _held,
              onChanged: (value) => setState(() => _held = _bound(value, 999)),
            ),
          ),
          _step('Identity & Verification', 'Step 5 of 5'),
          _labeled(
            'CNIC / National Identity Card (Optional)',
            TextField(
              controller: _cnic,
              keyboardType: TextInputType.number,
              style: _inputStyle,
              decoration: _inputDecoration('37405-1234567-1'),
            ),
          ),
          Text(
            'Storefront Photo',
            style: routeType(12, FontWeight.w600, RouteColors.ink, 16),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              height: 150,
              width: double.infinity,
              color: const Color(0xFFE7EDF5),
              child: _photo == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.photo_camera_outlined,
                          color: RouteColors.primary,
                          size: 28,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'No shopfront photo on this phone yet.',
                          style: routeType(
                            12,
                            FontWeight.w500,
                            RouteColors.secondary,
                            16,
                          ),
                        ),
                      ],
                    )
                  : Image.memory(
                      _photo!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _retake,
                  icon: const Icon(Icons.photo_camera_outlined, size: 16),
                  label: Text(_photo == null ? 'Capture' : 'Retake'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _photo == null ? null : _preview,
                  icon: const Icon(Icons.visibility_outlined, size: 16),
                  label: const Text('Preview'),
                ),
              ),
            ],
          ),
          Text(
            'The photo stays on this phone for the visit. It is not stored in the customer database.',
            style: routeType(12, FontWeight.w400, RouteColors.secondary, 16),
          ),
        ],
      ),
    );
  }

  Widget _modeChip(String label, bool creating) {
    final selected = _creating == creating;
    return Expanded(
      child: Material(
        color: selected ? RouteColors.primary : Colors.white,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: () {
            final customer = FieldScope.of(context).customer;
            setState(() {
              _creating = creating;
              if (creating) {
                _clear();
              } else if (customer != null) {
                _apply(customer);
              }
            });
          },
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: selected ? RouteColors.primary : RouteColors.line,
              ),
            ),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: routeType(
                12,
                FontWeight.w700,
                selected ? Colors.white : RouteColors.secondary,
                16,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _step(String title, String step) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: routeType(16, FontWeight.w700, RouteColors.ink, 22),
            ),
          ),
          Text(
            step,
            style: routeType(11, FontWeight.w700, RouteColors.primary, 14),
          ),
        ],
      ),
    );
  }

  Widget _ownershipCard(String value, String title, String body) {
    final selected = _ownership == value;
    return Material(
      color: selected ? RouteColors.pale : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => setState(() => _ownership = value),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? RouteColors.primary : RouteColors.line,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? RouteColors.primary : RouteColors.muted,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: routeType(
                        14,
                        FontWeight.w700,
                        RouteColors.ink,
                        20,
                      ),
                    ),
                    Text(
                      body,
                      style: routeType(
                        12,
                        FontWeight.w400,
                        RouteColors.secondary,
                        16,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

TextStyle get _inputStyle =>
    routeType(14, FontWeight.w500, RouteColors.ink, 20);

InputDecoration _inputDecoration(String hint) {
  return InputDecoration(
    hintText: hint,
    border: InputBorder.none,
    isDense: true,
    contentPadding: EdgeInsets.zero,
    hintStyle: routeType(14, FontWeight.w400, RouteColors.muted, 20),
  );
}

Widget _labeled(String label, Widget field) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: routeType(12, FontWeight.w600, RouteColors.ink, 16)),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: RouteColors.line),
          ),
          child: field,
        ),
      ],
    ),
  );
}

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  static const _weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  var _asked = false;
  var _search = '';
  var _filter = 'all';
  late DateTime _day;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _day = DateTime(now.year, now.month, now.day);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_asked) return;
    _asked = true;
    final store = FieldScope.of(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _reload(store);
    });
  }

  String get _iso =>
      '${_day.year.toString().padLeft(4, '0')}-${_day.month.toString().padLeft(2, '0')}-${_day.day.toString().padLeft(2, '0')}';

  void _reload(FieldStore store) => store.loadHistory(_search, date: _iso);

  Future<void> _pickDay(FieldStore store) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: today.subtract(const Duration(days: 90)),
      lastDate: today,
    );
    if (picked == null) return;
    setState(() => _day = DateTime(picked.year, picked.month, picked.day));
    _reload(store);
  }

  @override
  Widget build(BuildContext context) {
    final store = FieldScope.of(context);
    final history = store.history;
    final riderName = history?.riderName.isNotEmpty == true
        ? history!.riderName
        : (store.dashboard?.riderName ?? '');
    final riderCode = history?.riderCode.isNotEmpty == true
        ? history!.riderCode
        : (store.dashboard?.riderCode ?? '');
    final riderId = history?.riderUserId ?? '';
    final loaded = history?.items ?? const <HistoryItem>[];
    final visible = [
      for (final item in loaded)
        if (_filter == 'all' || item.syncStatus.toLowerCase() == _filter) item,
    ];
    final synced = history?.synced ?? 0;
    final pending = history?.pending ?? 0;
    final failed = history?.failed ?? 0;
    final total = synced + pending + failed;
    final percent = total == 0 ? 0 : ((synced / total) * 100).round();
    return RoutePage(
      title: 'History & Sync Queue',
      navIndex: 0,
      onNav: (index) {
        if (index == 3) {
          pushRoute(context, const SettingsScreen());
          return;
        }
        popToRiderHome(context);
      },
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () => _reload(store),
            icon: const Icon(Icons.sync, color: RouteColors.ink),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () => pushRoute(context, const SettingsScreen()),
            icon: const CircleAvatar(
              radius: 16,
              backgroundColor: RouteColors.primary,
              child: Icon(Icons.person, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => store.loadHistory(_search, date: _iso),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          children: [
            Text(
              '${_weekdays[_day.weekday - 1]}, ${_day.day} ${_months[_day.month - 1]} ${_day.year}',
              style: routeType(12, FontWeight.w600, RouteColors.secondary, 16),
            ),
            Text(
              'Activity & Sync',
              style: routeType(24, FontWeight.w700, RouteColors.ink, 30),
            ),
            Text(
              'Sales, collections, orders, visits, and shift changes for this rider.',
              style: routeType(13, FontWeight.w400, RouteColors.secondary, 18),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: RouteColors.primary,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          riderName.isEmpty ? 'Sync Overview' : riderName,
                          style: routeType(
                            16,
                            FontWeight.w700,
                            Colors.white,
                            22,
                          ),
                        ),
                      ),
                      if (riderCode.isNotEmpty)
                        Text(
                          riderCode,
                          style: routeType(
                            12,
                            FontWeight.w600,
                            Colors.white70,
                            16,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _syncStat(
                        Icons.check_circle_outline,
                        '$synced',
                        'Synced',
                      ),
                      _syncStat(Icons.schedule, '$pending', 'Pending'),
                      _syncStat(Icons.error_outline, '$failed', 'Failed'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: const BorderRadius.all(Radius.circular(999)),
                    child: LinearProgressIndicator(
                      value: total == 0 ? 0 : synced / total,
                      minHeight: 8,
                      color: const Color(0xFF8FE3C2),
                      backgroundColor: Colors.white24,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '$synced of $total transactions verified',
                          style: routeType(
                            12,
                            FontWeight.w500,
                            Colors.white,
                            16,
                          ),
                        ),
                      ),
                      Text(
                        '$percent%',
                        style: routeType(14, FontWeight.w700, Colors.white, 18),
                      ),
                    ],
                  ),
                  Text(
                    riderId.isEmpty
                        ? 'Saved on the server for the signed-in rider.'
                        : riderId,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: routeType(11, FontWeight.w500, Colors.white70, 14),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _historyChip('all', 'All Activity', loaded.length),
                  const SizedBox(width: 8),
                  _historyChip(
                    'synced',
                    'Synced',
                    loaded.where((item) => item.syncStatus == 'Synced').length,
                  ),
                  const SizedBox(width: 8),
                  _historyChip(
                    'pending',
                    'Pending',
                    loaded.where((item) => item.syncStatus == 'Pending').length,
                  ),
                  const SizedBox(width: 8),
                  _historyChip(
                    'failed',
                    'Failed',
                    loaded.where((item) => item.syncStatus == 'Failed').length,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _SearchBox(
                    'Search receipt number or customer...',
                    onChanged: (value) {
                      _search = value;
                      _reload(store);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: () => _pickDay(store),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: RouteColors.line),
                      ),
                      child: const Icon(
                        Icons.calendar_today_outlined,
                        color: RouteColors.primary,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Recent Activity',
                    style: routeType(16, FontWeight.w700, RouteColors.ink, 22),
                  ),
                ),
                Text(
                  '${visible.length} displayed of $total',
                  style: routeType(
                    11,
                    FontWeight.w600,
                    RouteColors.secondary,
                    14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (history == null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: store.loading
                      ? const CircularProgressIndicator()
                      : Text(
                          store.error ?? 'Activity has not loaded yet.',
                          style: routeType(
                            13,
                            FontWeight.w500,
                            RouteColors.secondary,
                            18,
                          ),
                        ),
                ),
              )
            else if (visible.isEmpty)
              Text(
                _search.isEmpty
                    ? 'No activity for this rider on this day.'
                    : 'No activity matches this search.',
                style: routeType(
                  13,
                  FontWeight.w500,
                  RouteColors.secondary,
                  18,
                ),
              )
            else
              for (final item in visible) ...[
                _historyCard(item),
                const SizedBox(height: 8),
              ],
          ],
        ),
      ),
    );
  }

  Widget _syncStat(IconData icon, String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 18),
          Text(value, style: routeType(22, FontWeight.w700, Colors.white, 28)),
          Text(
            label,
            style: routeType(11, FontWeight.w600, Colors.white70, 14),
          ),
        ],
      ),
    );
  }

  Widget _historyChip(String value, String label, int count) {
    final selected = _filter == value;
    return Material(
      color: selected ? RouteColors.primary : Colors.white,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: () => setState(() => _filter = value),
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? RouteColors.primary : RouteColors.line,
            ),
          ),
          child: Text(
            '$label ($count)',
            style: routeType(
              12,
              FontWeight.w700,
              selected ? Colors.white : RouteColors.secondary,
              16,
            ),
          ),
        ),
      ),
    );
  }
}

Widget _historyCard(HistoryItem item) {
  final status = item.syncStatus;
  final failed = status == 'Failed';
  final pending = status == 'Pending';
  final color = failed
      ? RouteColors.danger
      : pending
      ? const Color(0xFFB26A00)
      : RouteColors.ok;
  final chip = failed
      ? 'Sync Failed'
      : pending
      ? 'Pending Sync'
      : 'Synced';
  final kind = item.title.split('—').first.trim().toLowerCase();
  final icon = switch (kind) {
    'sale' => Icons.shopping_cart_outlined,
    'collection' => Icons.payments_outlined,
    'order' => Icons.event_note_outlined,
    'visit' => Icons.storefront_outlined,
    _ => Icons.receipt_long_outlined,
  };
  final hour = item.occurredAt.hour % 12 == 0 ? 12 : item.occurredAt.hour % 12;
  final minute = item.occurredAt.minute.toString().padLeft(2, '0');
  final clock = '$hour:$minute ${item.occurredAt.hour < 12 ? 'AM' : 'PM'}';
  final code = item.customerCode;
  final meta = [
    if (code != null && code.isNotEmpty) code,
    if (item.reference.isNotEmpty && item.reference != code) item.reference,
    clock,
  ].join(' · ');
  final showAmount = item.amount != null && item.amount != 0;
  return RouteCard(
    padding: const EdgeInsets.all(12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: failed
                    ? const Color(0xFFFDECEC)
                    : pending
                    ? const Color(0xFFFFF4E5)
                    : RouteColors.pale,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                failed ? Icons.sync_problem : icon,
                size: 18,
                color: failed ? RouteColors.danger : RouteColors.primary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: routeType(14, FontWeight.w700, RouteColors.ink, 20),
                  ),
                  Text(
                    meta,
                    style: routeType(
                      11,
                      FontWeight.w500,
                      RouteColors.secondary,
                      14,
                    ),
                  ),
                ],
              ),
            ),
            if (showAmount)
              Text(
                _pkr(item.amount!),
                style: routeType(14, FontWeight.w700, RouteColors.ink, 20),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: failed
                ? const Color(0xFFFDECEC)
                : pending
                ? const Color(0xFFFFF4E5)
                : const Color(0xFFE8F6EE),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(chip, style: routeType(10, FontWeight.w700, color, 14)),
        ),
        if (item.detail.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            item.detail,
            style: routeType(
              12,
              FontWeight.w500,
              failed ? RouteColors.danger : RouteColors.secondary,
              16,
            ),
          ),
        ],
      ],
    ),
  );
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _version = '0.1.0+1';

  var _autoSync = true;
  var _ordersTab = true;
  var _autoPrint = false;
  var _deleteOnLogout = false;
  var _paper = '58mm Standard';
  var _language = 'English (US)';
  var _slip = const PrintSlip();
  var _applied = false;
  var _asked = false;

  @override
  void initState() {
    super.initState();
    PrintSlip.load().then((slip) {
      if (mounted) setState(() => _slip = slip);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final store = FieldScope.of(context);
    final settings = store.settings;
    if (!_asked) {
      _asked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        store.loadSettings();
        if (store.dashboard == null) store.loadHome();
        if (store.stops.isEmpty) store.loadStops();
        final now = DateTime.now();
        final iso =
            '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
        store.loadHistory('', date: iso);
      });
    }
    if (settings == null || _applied) return;
    _applied = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _autoSync = settings.autoSync;
        _ordersTab = settings.showOrdersTab;
        _autoPrint = settings.autoPrint;
        _deleteOnLogout = settings.deleteOnLogout;
        _language = settings.language.isEmpty
            ? 'English (US)'
            : settings.language;
        _paper = settings.paperSize.startsWith('80') ? '80mm' : '58mm Standard';
      });
    });
  }

  Future<void> _persist() async {
    final store = FieldScope.of(context);
    final current = store.settings;
    if (current == null) {
      _opsNote(context, 'Settings have not loaded from the server yet.');
      return;
    }
    await store.saveSettings(
      current.copyWith(
        autoSync: _autoSync,
        showOrdersTab: _ordersTab,
        language: _language,
        autoPrint: _autoPrint,
        deleteOnLogout: _deleteOnLogout,
        paperSize: _paper.startsWith('80') ? '80mm' : '58mm',
      ),
    );
    await _slip.save();
    if (!mounted) return;
    _opsNote(context, store.error ?? 'Configuration saved.');
  }

  Future<void> _setSlip(PrintSlip slip) async {
    setState(() => _slip = slip);
    await slip.save();
    if (mounted) _opsNote(context, 'Receipt layout saved on this phone.');
  }

  Future<void> _defaults() async {
    setState(() {
      _autoSync = true;
      _ordersTab = true;
      _autoPrint = false;
      _deleteOnLogout = false;
      _language = 'English (US)';
      _paper = '58mm Standard';
      _slip = const PrintSlip();
    });
    await _persist();
  }

  Future<void> _chooseLanguage() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('English (US)'),
              trailing: _language == 'English (US)'
                  ? const Icon(Icons.check, color: RouteColors.primary)
                  : null,
              onTap: () {
                Navigator.of(sheet).pop();
                setState(() => _language = 'English (US)');
                _persist();
              },
            ),
            const ListTile(
              title: Text('Urdu'),
              subtitle: Text('The translated layout is not in this build.'),
              enabled: false,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _testPrint() async {
    if (!PrinterRadio.isConnected) {
      _opsNote(context, 'Pair a printer before printing a test slip.');
      return;
    }
    final dash = FieldScope.of(context).dashboard;
    final columns = _paper.startsWith('80') ? 48 : 32;
    String clip(String value) =>
        value.length <= columns ? value : value.substring(0, columns);
    final now = DateTime.now();
    final lines = <String>[
      clip('TEST RECEIPT'),
      clip(
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
      ),
      if (_slip.company)
        clip(
          dash?.depotName.isNotEmpty == true ? dash!.depotName : 'AquaRider',
        ),
      if (_slip.customer)
        clip('${dash?.riderName ?? 'Rider'} ${dash?.riderCode ?? ''}'),
      if (_slip.ledger) clip('No customer ledger on a test slip.'),
      clip('Paper $_paper'),
    ];
    if (_slip.gps) {
      try {
        final location = Location();
        final here = await location.getLocation().timeout(
          const Duration(seconds: 6),
        );
        lines.add(
          clip(
            'GPS ${here.latitude.toStringAsFixed(5)}, ${here.longitude.toStringAsFixed(5)}',
          ),
        );
      } catch (_) {
        lines.add('GPS was not available');
      }
    }
    try {
      await PrinterRadio.printText(lines.join('\n'));
      if (mounted) {
        _opsNote(context, 'Test slip sent to ${PrinterRadio.connectedName}.');
      }
    } catch (error) {
      if (mounted) {
        _opsNote(
          context,
          error is StateError
              ? error.message
              : 'The printer did not accept the test slip.',
        );
      }
    }
  }

  Future<void> _changePassword() async {
    final current = TextEditingController();
    final next = TextEditingController();
    final again = TextEditingController();
    final form = GlobalKey<FormState>();
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Change password'),
        content: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: current,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Current password',
                ),
                validator: (value) => value == null || value.isEmpty
                    ? 'Enter the current password.'
                    : null,
              ),
              TextFormField(
                controller: next,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New password'),
                validator: (value) {
                  if (value == null || value.length < 8) {
                    return 'Use at least 8 characters.';
                  }
                  if (!RegExp(r'[a-z]').hasMatch(value) ||
                      !RegExp(r'\d').hasMatch(value)) {
                    return 'Include a lowercase letter and a digit.';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: again,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm new password',
                ),
                validator: (value) => value != next.text
                    ? 'The new passwords do not match.'
                    : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState?.validate() ?? false) {
                Navigator.of(dialog).pop(true);
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
    final currentText = current.text;
    final nextText = next.text;
    current.dispose();
    next.dispose();
    again.dispose();
    if (saved != true || !mounted) return;
    try {
      await ApiScope.of(context)
          .changePassword(currentPassword: currentText, newPassword: nextText);
      if (!mounted) return;
      _opsNote(context, 'Password changed. Sign in again.');
      await ApiScope.of(context).logout();
      if (!mounted) return;
      FieldScope.of(context).reset();
      replaceWithLogin(context);
    } on ApiException catch (error) {
      if (mounted) _opsNote(context, error.message);
    }
  }

  Future<void> _signOut() async {
    if (_deleteOnLogout) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: const Text('Delete data on this phone?'),
          content: const Text(
            'The saved username, shop photos, and receipt options on this phone will be removed. Sales already stored on the server stay there.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialog).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialog).pop(true),
              child: const Text('Sign out'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    final wipe = _deleteOnLogout;
    await ApiScope.of(context).logout(clearLocal: wipe);
    if (wipe) await PrinterRadio.disconnect();
    if (!mounted) return;
    FieldScope.of(context).reset();
    replaceWithLogin(context);
  }

  Future<void> _checkServer() async {
    final store = FieldScope.of(context);
    await store.loadSettings();
    await store.loadHome();
    if (!mounted) return;
    _opsNote(
      context,
      store.error ?? 'Server answered. This phone is running $_version.',
    );
  }

  Future<void> _accountSheet() async {
    final failed = FieldScope.of(context).history?.failed ?? 0;
    final dash = FieldScope.of(context).dashboard;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheet) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Text('Account', style: routeType(18, FontWeight.w800, const Color(0xFF102448), 24)),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.lock_outline, color: Color(0xFF0875E8)),
              title: const Text('Change password'),
              subtitle: const Text('At least 8 characters, with a lowercase letter and a digit.'),
              onTap: () {
                Navigator.pop(sheet);
                _changePassword();
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Delete data on logout'),
              subtitle: const Text('Clears the saved username, shop photos, and receipt options on this phone. Server records stay.'),
              value: _deleteOnLogout,
              onChanged: (value) {
                Navigator.pop(sheet);
                setState(() => _deleteOnLogout = value);
                _persist();
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.storefront_outlined, color: Color(0xFF0875E8)),
              title: const Text('Add or edit a customer'),
              subtitle: const Text('Opens the customer form for this route.'),
              onTap: () {
                Navigator.pop(sheet);
                pushRoute(context, const CustomerFormScreen());
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.menu_book_outlined, color: Color(0xFF0875E8)),
              title: const Text('Field steps'),
              subtitle: const Text('Start day, route, sale, collection, and history.'),
              onTap: () {
                Navigator.pop(sheet);
                showDialog<void>(
                  context: context,
                  builder: (dialog) => AlertDialog(
                    title: const Text('Field steps'),
                    content: const Text('Start the day with the odometer photo. Open a stop from To-Do. Record the sale, payment, and signature. Collect an outstanding balance from the customer. History shows what reached the server today.'),
                    actions: [TextButton(onPressed: () => Navigator.of(dialog).pop(), child: const Text('Close'))],
                  ),
                );
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.phone_android, color: Color(0xFF0875E8)),
              title: Text('AquaRider rider app $_version'),
              subtitle: Text(dash?.depotName.isNotEmpty == true ? dash!.depotName : 'Depot loads with the dashboard'),
              trailing: const Text('Check'),
              onTap: () {
                Navigator.pop(sheet);
                _checkServer();
              },
            ),
            if (failed > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('$failed activities today did not reach the server. Open History to review them.', style: routeType(12, FontWeight.w600, const Color(0xFFB26A00), 16)),
              ),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: RouteColors.danger, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(48)),
              onPressed: () {
                Navigator.pop(sheet);
                _signOut();
              },
              icon: const Icon(Icons.logout),
              label: const Text('Sign out'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = FieldScope.of(context);
    final dash = store.dashboard;
    final canPop = Navigator.of(context).canPop();
    final printer = PrinterRadio.connectedName ?? store.settings?.printerName;
    final connected = printer != null && printer.isNotEmpty;
    final name = dash?.riderName.isNotEmpty == true ? dash!.riderName : 'Signed-in rider';
    final initials = name.split(' ').where((part) => part.isNotEmpty).take(2).map((part) => part[0]).join().toUpperCase();
    final pane = RiderSettingsPane(
      canPop: canPop,
      name: name,
      initials: initials,
      riderCode: dash?.riderCode ?? '',
      routeLine: dash?.routeName.isNotEmpty == true ? 'Delivery Rider • ${dash!.routeName}' : 'Route loads with the dashboard',
      onShift: dash?.shiftOpen == true,
      stopsCompleted: dash?.visitedCount ?? 0,
      connected: connected,
      printerLabel: connected ? printer : 'Not Connected',
      autoSync: _autoSync,
      ordersTab: _ordersTab,
      autoPrint: _autoPrint,
      language: _language,
      paper80: _paper.startsWith('80'),
      company: _slip.company,
      customer: _slip.customer,
      ledger: _slip.ledger,
      gps: _slip.gps,
      failedCount: store.history?.failed ?? 0,
      onEdit: _accountSheet,
      onDefaults: _defaults,
      onCompliance: () {
        Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const RouteComplianceScreen()));
      },
      onAutoSync: (value) {
        setState(() => _autoSync = value);
        _persist();
      },
      onOrdersTab: (value) {
        setState(() => _ordersTab = value);
        _persist();
      },
      onLanguage: _chooseLanguage,
      onStatus: () => _opsNote(context, connected ? 'Connected to $printer.' : 'No printer is connected on this phone.'),
      onConfigure: () => pushRoute(context, const PrinterScreen()),
      onPair: () => pushRoute(context, const PrinterScreen()),
      onAutoPrint: (value) {
        setState(() => _autoPrint = value);
        _persist();
      },
      onPaper: (wide) {
        setState(() => _paper = wide ? '80mm' : '58mm Standard');
        _persist();
      },
      onCompany: (value) => _setSlip(_slip.copyWith(company: value)),
      onCustomer: (value) => _setSlip(_slip.copyWith(customer: value)),
      onLedger: (value) => _setSlip(_slip.copyWith(ledger: value)),
      onGps: (value) => _setSlip(_slip.copyWith(gps: value)),
      onTestPrint: _testPrint,
    );
    if (!canPop) return pane;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F9FE),
      body: pane,
    );
  }
}

class PrinterScreen extends StatefulWidget {
  const PrinterScreen({super.key});

  @override
  State<PrinterScreen> createState() => _PrinterScreenState();
}

class _PrinterScreenState extends State<PrinterScreen> {
  final List<NearbyPrinter> _found = [];
  StreamSubscription<NearbyPrinter>? _scan;
  StreamSubscription<dynamic>? _adapter;
  var _paper = '58mm';
  var _auto = true;
  var _checked = false;
  var _permitted = false;
  var _bluetoothOn = false;
  var _scanning = false;
  var _scanId = 0;
  String? _connecting;

  @override
  void initState() {
    super.initState();
    final saved = PrinterRadio.connectedName;
    final address = PrinterRadio.connectedAddress;
    if (saved != null && address != null && address.isNotEmpty) {
      _found.add(NearbyPrinter(name: saved, address: address, paired: true));
    }
    _listen();
    _refresh();
  }

  var _applied = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_applied) return;
    final settings = FieldScope.of(context).settings;
    if (settings == null) return;
    _applied = true;
    _paper = settings.paperSize.startsWith('80')
        ? '80mm'
        : settings.paperSize.startsWith('48')
        ? '48mm'
        : '58mm';
    _auto = settings.autoPrint;
  }

  @override
  void dispose() {
    _scanId++;
    _scan?.cancel();
    _adapter?.cancel();
    PrinterRadio.cancelDiscovery();
    super.dispose();
  }

  Future<void> _listen() async {
    if (!PrinterRadio.isAndroid) return;
    _adapter = PrinterRadio.watchState().listen((state) {
      if (!mounted) return;
      setState(() => _bluetoothOn = state.isEnabled);
    });
  }

  Future<void> _refresh() async {
    if (!PrinterRadio.isAndroid) return;
    try {
      final status = await PrinterRadio.status();
      if (!mounted) return;
      setState(() {
        _checked = true;
        _permitted = status.permitted;
        _bluetoothOn = status.enabled;
      });
      if (!status.enabled) return;
      final paired = await PrinterRadio.bonded();
      if (!mounted) return;
      setState(() => _merge(paired));
    } catch (_) {
      if (!mounted) return;
      _note(
        'Bluetooth could not be read. Turn it on from the phone and try again.',
      );
    }
  }

  Future<void> _turnOn() async {
    try {
      final on = await PrinterRadio.turnOn();
      if (!mounted) return;
      setState(() {
        _permitted = true;
        _bluetoothOn = on;
      });
      if (!on) {
        _note('Bluetooth stayed off. Accept the system prompt to turn it on.');
        return;
      }
      await _search();
    } catch (_) {
      if (!mounted) return;
      _note(
        'Allow Nearby devices so the app can turn Bluetooth on and find printers.',
      );
    }
  }

  Future<void> _search() async {
    if (!PrinterRadio.isAndroid) {
      _note('Printer search runs on the Android phone.');
      return;
    }
    final id = ++_scanId;
    await _scan?.cancel();
    setState(() => _scanning = true);
    try {
      if (!_bluetoothOn) {
        final on = await PrinterRadio.turnOn();
        if (!mounted || id != _scanId) return;
        setState(() => _bluetoothOn = on);
        if (!on) {
          setState(() => _scanning = false);
          _note('Turn Bluetooth on before searching for printers.');
          return;
        }
      }
      final paired = await PrinterRadio.bonded();
      if (!mounted || id != _scanId) return;
      setState(() => _merge(paired));
      _scan = PrinterRadio.discover().listen(
        (printer) {
          if (!mounted || id != _scanId) return;
          setState(() => _merge([printer]));
        },
        onError: (_) {
          if (!mounted || id != _scanId) return;
          setState(() => _scanning = false);
          _note('The search stopped. Keep Bluetooth on and search again.');
        },
        onDone: () {
          if (!mounted || id != _scanId) return;
          setState(() => _scanning = false);
        },
      );
      Future.delayed(const Duration(seconds: 12), () async {
        if (!mounted || id != _scanId) return;
        await _scan?.cancel();
        await PrinterRadio.cancelDiscovery();
        if (mounted && id == _scanId) setState(() => _scanning = false);
      });
    } catch (_) {
      if (!mounted || id != _scanId) return;
      setState(() => _scanning = false);
      _note('Allow Nearby devices, then search again.');
    }
  }

  Future<void> _connect(NearbyPrinter printer) async {
    if (printer.address.isEmpty) return;
    setState(() => _connecting = printer.address);
    try {
      await PrinterRadio.connect(printer);
      if (!mounted) return;
      setState(
        () => _merge([
          NearbyPrinter(
            name: printer.name,
            address: printer.address,
            paired: true,
            rssi: printer.rssi,
          ),
        ]),
      );
      _note('Connected to ${printer.name}.');
    } on StateError catch (error) {
      if (!mounted) return;
      _note(error.message);
    } on TimeoutException {
      if (!mounted) return;
      _note('The printer did not answer. Turn it on and search again.');
    } catch (_) {
      if (!mounted) return;
      _note('Could not connect to ${printer.name}. Keep it on and try again.');
    } finally {
      if (mounted) setState(() => _connecting = null);
    }
  }

  Future<void> _disconnect() async {
    await PrinterRadio.disconnect();
    if (mounted) setState(() {});
  }

  void _merge(List<NearbyPrinter> incoming) {
    for (final printer in incoming) {
      if (printer.address.isEmpty) continue;
      final index = _found.indexWhere(
        (item) => item.address == printer.address,
      );
      if (index >= 0) {
        final current = _found[index];
        _found[index] = NearbyPrinter(
          name: printer.name == 'Unknown printer' ? current.name : printer.name,
          address: printer.address,
          paired: printer.paired || current.paired,
          rssi: printer.rssi ?? current.rssi,
        );
      } else {
        _found.add(printer);
      }
    }
    _found.sort((a, b) {
      if (a.address == PrinterRadio.connectedAddress) return -1;
      if (b.address == PrinterRadio.connectedAddress) return 1;
      if (a.paired != b.paired) return a.paired ? -1 : 1;
      return a.name.compareTo(b.name);
    });
  }

  void _note(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final connectedName = PrinterRadio.connectedName;
    return RoutePage(
      title: 'Printer Configuration',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'ESC/POS Engine',
            style: routeType(12, FontWeight.w600, RouteColors.link, 16),
          ),
          Text(
            'Turn Bluetooth on, search for a receipt printer, and connect it for field billing.',
            style: routeType(13, FontWeight.w400, RouteColors.body, 18),
          ),
          const SizedBox(height: 8),
          _statusCard(),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'Nearby printers',
                style: routeType(14, FontWeight.w700, RouteColors.ink, 20),
              ),
              const Spacer(),
              if (_scanning)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (_found.isEmpty)
            RouteCard(
              color: RouteColors.tint,
              child: Text(
                _bluetoothOn
                    ? 'No printers yet. Turn the printer on, then search.'
                    : 'Turn Bluetooth on to search for printers near this phone.',
                style: routeType(13, FontWeight.w500, RouteColors.body, 18),
              ),
            )
          else
            for (final printer in _found) _printerTile(printer),
          const SizedBox(height: 8),
          Text(
            'Receipt Paper Size',
            style: routeType(14, FontWeight.w700, RouteColors.ink, 20),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final size in const ['48mm', '58mm', '80mm'])
                ChoiceChip(
                  label: Text(size),
                  selected: _paper == size,
                  onSelected: (_) => setState(() => _paper = size),
                ),
            ],
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Auto-Print Slip on Sign-off',
              style: routeType(14, FontWeight.w600, RouteColors.ink, 20),
            ),
            value: _auto,
            activeThumbColor: RouteColors.primary,
            onChanged: (value) => setState(() => _auto = value),
          ),
          Text(
            connectedName == null
                ? 'No printer connected'
                : 'Connected printer: $connectedName',
            style: routeType(
              12,
              FontWeight.w500,
              connectedName == null ? RouteColors.secondary : RouteColors.ok,
              16,
            ),
          ),
          const SizedBox(height: 8),
          RouteButton(
            label: 'Save Printer Settings',
            onPressed: () async {
              final store = FieldScope.of(context);
              final current = store.settings;
              if (current != null) {
                await store.saveSettings(
                  current.copyWith(
                    autoPrint: _auto,
                    paperSize: _paper,
                    printerName:
                        PrinterRadio.connectedName ?? current.printerName,
                  ),
                );
              }
              if (!context.mounted) return;
              Navigator.of(context).maybePop();
            },
          ),
          const SizedBox(height: 8),
          RouteOutlineButton(
            label: 'Cancel & Return',
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
    );
  }

  Widget _statusCard() {
    final on = _bluetoothOn;
    final title = !PrinterRadio.isAndroid
        ? 'Use the Android phone'
        : !_checked
        ? 'Checking Bluetooth'
        : !_permitted
        ? 'Bluetooth permission needed'
        : on
        ? 'Bluetooth is on'
        : 'Bluetooth is off';
    final detail = !PrinterRadio.isAndroid
        ? 'Classic receipt printers connect from the rider phone.'
        : !_checked
        ? 'The phone is reading the Bluetooth radio.'
        : !_permitted
        ? 'Allow Nearby devices so this phone can find printers.'
        : on
        ? 'Search lists printers that are on and in range.'
        : 'Turn it on, then the phone will search nearby printers.';
    return RouteCard(
      color: RouteColors.tint,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                on ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                color: on ? RouteColors.ok : RouteColors.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: routeType(15, FontWeight.w700, RouteColors.ink, 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            detail,
            style: routeType(13, FontWeight.w400, RouteColors.body, 18),
          ),
          const SizedBox(height: 8),
          if (!on)
            RouteButton(
              label: 'Turn on Bluetooth',
              icon: const Icon(Icons.bluetooth, color: Colors.white, size: 18),
              onPressed: _turnOn,
            ),
          if (on) ...[
            RouteButton(
              label: _scanning ? 'Searching printers…' : 'Search printers',
              icon: const Icon(Icons.radar, color: Colors.white, size: 18),
              onPressed: _scanning ? () {} : _search,
            ),
          ],
        ],
      ),
    );
  }

  Widget _printerTile(NearbyPrinter printer) {
    final connected =
        PrinterRadio.isConnected &&
        printer.address == PrinterRadio.connectedAddress;
    final connecting = _connecting == printer.address;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: connected ? RouteColors.tint : Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: connecting || printer.address.isEmpty
              ? null
              : () => _connect(printer),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: connected
                      ? RouteColors.primary
                      : RouteColors.pale,
                  child: Icon(
                    Icons.print_outlined,
                    color: connected ? Colors.white : RouteColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        printer.name,
                        style: routeType(
                          15,
                          FontWeight.w700,
                          RouteColors.ink,
                          20,
                        ),
                      ),
                      Text(
                        '${printer.paired ? 'Paired' : 'New'} · ${printer.signal}',
                        style: routeType(
                          12,
                          FontWeight.w400,
                          RouteColors.secondary,
                          16,
                        ),
                      ),
                      Text(
                        printer.address,
                        style: routeType(
                          11,
                          FontWeight.w500,
                          RouteColors.muted,
                          16,
                        ),
                      ),
                    ],
                  ),
                ),
                if (connecting)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (connected)
                  IconButton(
                    onPressed: _disconnect,
                    icon: const Icon(
                      Icons.link_off,
                      color: RouteColors.primary,
                    ),
                    tooltip: 'Disconnect',
                  )
                else
                  const Icon(Icons.chevron_right, color: RouteColors.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
