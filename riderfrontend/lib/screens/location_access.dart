import 'package:flutter/material.dart';
import 'package:location/location.dart';

import '../ui/route_ui.dart';
import 'route_shell.dart';

class DeviceLocation {
  static Future<bool> Function()? override;

  static bool _allowed(PermissionStatus permission) {
    return permission == PermissionStatus.granted ||
        permission == PermissionStatus.grantedLimited;
  }

  /// True only when the phone location service is on and this app may use it.
  /// Does not show a system prompt.
  static Future<bool> isReady() async {
    if (override != null) return true;
    final location = Location();
    if (!await location.serviceEnabled()) return false;
    return _allowed(await location.hasPermission());
  }

  static Future<bool> ensureEnabled() async {
    final replacement = override;
    if (replacement != null) return replacement();
    final location = Location();
    var serviceOn = await location.serviceEnabled();
    if (!serviceOn) {
      serviceOn = await location.requestService();
      if (!serviceOn) return false;
    }
    var permission = await location.hasPermission();
    if (permission == PermissionStatus.denied) {
      permission = await location.requestPermission();
    }
    return _allowed(permission);
  }
}

class LocationAccessScreen extends StatefulWidget {
  const LocationAccessScreen({super.key});

  @override
  State<LocationAccessScreen> createState() => _LocationAccessScreenState();
}

class _LocationAccessScreenState extends State<LocationAccessScreen>
    with WidgetsBindingObserver {
  var _waiting = false;
  var _ready = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final ready = await DeviceLocation.isReady();
    if (!mounted) return;
    setState(() => _ready = ready);
  }

  void _openHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: riderShellRoute),
        builder: (_) => const RouteShell(),
      ),
      (route) => false,
    );
  }

  Future<void> _allow() async {
    if (_waiting) return;
    if (_ready) {
      _openHome();
      return;
    }
    setState(() => _waiting = true);
    final enabled = await DeviceLocation.ensureEnabled();
    if (!mounted) return;
    setState(() => _waiting = false);
    if (!enabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Turn on location in the system prompt to continue the route.',
          ),
        ),
      );
      await _refresh();
      return;
    }
    _openHome();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RouteColors.page,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 23, 16, 16),
              children: [
                const _TerminalHeader(),
                const SizedBox(height: 12),
                const _MapCard(),
                const SizedBox(height: 12),
                Text(
                  'Enable Location Access',
                  style: routeType(
                    22,
                    FontWeight.w600,
                    RouteColors.ink,
                    28,
                    -0.3,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'RouteLedger uses your location to verify customer visits, audit physical handoffs, and support accurate field operations.',
                  style: routeType(14, FontWeight.w400, RouteColors.body, 20),
                ),
                const SizedBox(height: 12),
                const _WhyCard(),
                const SizedBox(height: 12),
                const _PrivacyCard(),
                const SizedBox(height: 16),
                RouteButton(
                  keyId: const Key('allow-location'),
                  label: _ready ? 'Move to Home' : 'Allow Location Access',
                  icon: _ready
                      ? const Icon(
                          Icons.home_outlined,
                          color: Colors.white,
                          size: 18,
                        )
                      : const RouteSvg(
                          'assets/location/button_pin.svg',
                          13.3333,
                          16.6667,
                        ),
                  onPressed: _waiting ? () {} : _allow,
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const RouteSvg('assets/location/lock.svg', 9.33333, 12.25),
                    const SizedBox(width: 4),
                    Text(
                      'Location access is required for field operations.',
                      style: routeType(
                        11,
                        FontWeight.w500,
                        RouteColors.secondary,
                        16,
                        0.3,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TerminalHeader extends StatelessWidget {
  const _TerminalHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: RouteColors.primary,
            borderRadius: BorderRadius.circular(8),
            boxShadow: routeSoftShadow,
          ),
          child: const Center(
            child: RouteSvg('assets/location/truck.svg', 18.3333, 13.3333),
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'RouteLedger',
              style: routeType(18, FontWeight.w600, RouteColors.ink, 24, -0.1),
            ),
            Text(
              'RIDER TERMINAL',
              style: routeType(
                11,
                FontWeight.w500,
                RouteColors.secondary,
                16,
                0.5,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MapCard extends StatelessWidget {
  const _MapCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            height: 160,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(280, 160),
                  painter: _RoutePainter(),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const RouteSvg('assets/location/pin.svg', 59, 68.625),
                    Text(
                      'Current Stop',
                      style: routeType(
                        10,
                        FontWeight.w700,
                        RouteColors.link,
                        14,
                        0.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFE5EEFF),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              children: [
                const RouteSvg('assets/location/badge.svg', 12.5, 8.84375),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'On-duty location sharing for route compliance',
                    style: routeType(
                      11,
                      FontWeight.w500,
                      RouteColors.body,
                      16,
                      0.3,
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
}

class _RoutePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * 0.12, size.height * 0.32)
      ..quadraticBezierTo(
        size.width * 0.4,
        size.height * 0.08,
        size.width * 0.55,
        size.height * 0.28,
      )
      ..quadraticBezierTo(
        size.width * 0.75,
        size.height * 0.5,
        size.width * 0.9,
        size.height * 0.3,
      );
    final lower = Path()
      ..moveTo(size.width * 0.16, size.height * 0.78)
      ..quadraticBezierTo(
        size.width * 0.45,
        size.height * 0.95,
        size.width * 0.84,
        size.height * 0.72,
      );
    final paint = Paint()
      ..color = const Color(0xFF1565C0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, paint);
    canvas.drawPath(lower, paint);
    void dot(double x, double y, Color color) {
      canvas.drawCircle(Offset(x, y), 5, Paint()..color = color);
    }

    dot(size.width * 0.18, size.height * 0.48, const Color(0xFF0B7A4B));
    dot(size.width * 0.82, size.height * 0.58, const Color(0xFF737686));
    final label = TextPainter(
      text: TextSpan(
        text: 'Stop 01',
        style: routeType(10, FontWeight.w600, RouteColors.secondary, 14, 0.5),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    label.paint(canvas, Offset(size.width * 0.22, size.height * 0.62));
    final label3 = TextPainter(
      text: TextSpan(
        text: 'Stop 03',
        style: routeType(10, FontWeight.w600, RouteColors.secondary, 14, 0.5),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    label3.paint(canvas, Offset(size.width * 0.72, size.height * 0.7));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _WhyCard extends StatelessWidget {
  const _WhyCard();

  @override
  Widget build(BuildContext context) {
    return RouteCard(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Why we need your location',
                  style: routeType(14, FontWeight.w600, RouteColors.ink, 20),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Strict Purpose',
                style: routeType(
                  11,
                  FontWeight.w600,
                  RouteColors.link,
                  16,
                  0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const _Reason(
            'assets/location/visit.svg',
            12,
            15,
            'Verify customer visits',
            'Confirms physical proximity at merchant doorsteps before generating digital cash receipts or drop signatures.',
          ),
          const SizedBox(height: 8),
          const _Reason(
            'assets/location/route.svg',
            13.5,
            15,
            'Record your route activity',
            'Calculates realistic travel allowances, trip mileage compensation, and sequence optimizations automatically.',
          ),
          const SizedBox(height: 8),
          const _Reason(
            'assets/location/collections.svg',
            15,
            13.5,
            'Support accurate delivery & collections',
            'Prevents misallocated parcels and protects riders against false dispute claims on collected spot balances.',
          ),
        ],
      ),
    );
  }
}

class _Reason extends StatelessWidget {
  const _Reason(this.asset, this.width, this.height, this.title, this.body);

  final String asset;
  final double width;
  final double height;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: const BoxDecoration(
            color: RouteColors.tint,
            shape: BoxShape.circle,
            boxShadow: routeSoftShadow,
          ),
          child: Center(child: RouteSvg(asset, width, height)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: routeType(14, FontWeight.w600, RouteColors.ink, 20),
              ),
              Text(
                body,
                style: routeType(
                  12,
                  FontWeight.w400,
                  RouteColors.body,
                  16,
                  0.2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PrivacyCard extends StatelessWidget {
  const _PrivacyCard();

  @override
  Widget build(BuildContext context) {
    return RouteCard(
      color: RouteColors.tint,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: const Color(0x1A1565C0),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Center(
                  child: RouteSvg('assets/location/shield.svg', 12, 15),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Your Privacy Matters',
                style: routeType(14, FontWeight.w400, RouteColors.ink, 20),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(
              style: routeType(12, FontWeight.w400, RouteColors.body, 16),
              children: [
                const TextSpan(
                  text:
                      'Location sharing turns ',
                ),
                TextSpan(
                  text: 'Active',
                  style: routeType(12, FontWeight.w700, RouteColors.link, 16),
                ),
                const TextSpan(
                  text:
                      ' only during an authorized shift (Start Day → End Day) so HQ can match deliveries to your assigned route. Status stays visible in Route Compliance.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: routeSoftShadow,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const RouteSvg('assets/location/bell.svg', 15, 17.0375),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'A persistent Android system status notification will always indicate when on-duty location logging is running.',
                    style: routeType(12, FontWeight.w400, RouteColors.body, 16),
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
