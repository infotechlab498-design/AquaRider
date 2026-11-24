import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:riderfrontend/adminDashboard/presentation/admin_routing.dart';
import 'package:riderfrontend/adminDashboard/presentation/screens/enterprise_login_screen.dart';
import 'package:riderfrontend/api/route_api.dart';
import 'package:riderfrontend/customerApp/account_type_screen.dart';
import 'package:riderfrontend/customerApp/customer_signed_in_screen.dart';
import '../ui/route_ui.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    Future<void>.delayed(const Duration(milliseconds: 1600), () async {
      if (!mounted) return;
      final wide = MediaQuery.sizeOf(context).width >= 900;
      if (wide) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (_) => const EnterpriseLoginScreen()),
        );
        return;
      }
      final session = await ApiScope.of(context).currentSession();
      if (!mounted) return;
      final role = session?.role.trim().toLowerCase() ?? '';
      final Widget next = session == null
          ? const AccountTypeSelectionScreen()
          : role == 'customer'
          ? CustomerSignedInScreen(session: session)
          : role == 'rider'
          ? homeForSession(session)
          : const AccountTypeSelectionScreen();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => next),
      );
    });
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: constraints.maxWidth > 560 ? 560 : constraints.maxWidth,
                height: constraints.maxHeight,
                child: const _SplashBody(),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SplashBody extends StatelessWidget {
  const _SplashBody();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Column(
        children: [
          const Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: RouteColors.accent,
                borderRadius: BorderRadius.all(Radius.circular(999)),
              ),
              child: SizedBox(width: 80, height: 4),
            ),
          ),
          const Spacer(),
          const _BrandMark(),
          const SizedBox(height: 8),
          Text(
            'RouteLedger',
            style: routeType(14, FontWeight.w400, RouteColors.splash, 20),
          ),
          const SizedBox(height: 4),
          Text(
            'Deliveries. Collections. Control.',
            style: routeType(14, FontWeight.w600, RouteColors.slate, 20),
          ),
          const SizedBox(height: 12),
          const _Badges(),
          const Spacer(),
          const _ProgressBlock(),
          const SizedBox(height: 24),
          const _IntegrityPill(),
          const Spacer(),
          Text(
            'Version 1.0.0',
            style: routeType(14, FontWeight.w600, RouteColors.slate, 20),
          ),
          const SizedBox(height: 4),
          Text(
            'POWERED BY ROUTELEDGER MOBILE',
            style: routeType(14, FontWeight.w400, Color(0xB337474F), 20),
          ),
          const SizedBox(height: 12),
          const DecoratedBox(
            decoration: BoxDecoration(
              color: Color(0x4D1565C0),
              borderRadius: BorderRadius.all(Radius.circular(999)),
            ),
            child: SizedBox(width: 128, height: 4),
          ),
        ],
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 112,
      height: 112,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.all(Radius.circular(24)),
              boxShadow: routeSoftShadow,
            ),
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Image.asset(
                'assets/icon/app_icon.png',
                width: 88,
                height: 88,
                fit: BoxFit.contain,
              ),
            ),
          ),
          Positioned(
            right: -4,
            top: -4,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: RouteColors.accent,
                shape: BoxShape.circle,
              ),
              child: SizedBox(
                width: 16,
                height: 16,
                child: Center(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: RouteColors.splash,
                      shape: BoxShape.circle,
                    ),
                    child: SizedBox(width: 8, height: 8),
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

class _Badges extends StatelessWidget {
  const _Badges();

  @override
  Widget build(BuildContext context) {
    return const Wrap(
      spacing: 8,
      children: [
        _Badge(
          'assets/splash/certified.svg',
          12.8333,
          12.25,
          'Terminal Certified',
        ),
        _Badge('assets/splash/sync.svg', 11.6667, 11.6667, 'Sync Ready'),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.asset, this.width, this.height, this.label);

  final String asset;
  final double width;
  final double height;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: RouteColors.pale,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          RouteSvg(asset, width, height),
          const SizedBox(width: 4),
          Text(
            label,
            style: routeType(14, FontWeight.w400, RouteColors.slate, 20),
          ),
        ],
      ),
    );
  }
}

class _ProgressBlock extends StatelessWidget {
  const _ProgressBlock();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: const SizedBox(
            height: 6,
            width: 320,
            child: Stack(
              children: [
                ColoredBox(color: RouteColors.pale, child: SizedBox.expand()),
                FractionallySizedBox(
                  widthFactor: 0.6,
                  child: ColoredBox(
                    color: RouteColors.bar,
                    child: SizedBox.expand(),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Preparing your workspace...',
          style: routeType(14, FontWeight.w400, RouteColors.splash, 20),
        ),
        Text(
          'Checking device security & route sync...',
          style: routeType(14, FontWeight.w400, RouteColors.slate, 20),
        ),
      ],
    );
  }
}

class _IntegrityPill extends StatelessWidget {
  const _IntegrityPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: RouteColors.pale,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              color: RouteColors.splash,
              shape: BoxShape.circle,
            ),
            child: SizedBox(width: 8, height: 8),
          ),
          const SizedBox(width: 8),
          Text(
            'Data Integrity',
            style: routeType(14, FontWeight.w600, RouteColors.slate, 20),
          ),
          const Spacer(),
          Text(
            'AES-256 Validated',
            style: routeType(14, FontWeight.w600, RouteColors.splash, 20),
          ),
        ],
      ),
    );
  }
}
