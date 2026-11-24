import 'package:flutter/material.dart';

import 'package:riderfrontend/api/route_api.dart';
import 'package:riderfrontend/customerApp/customer_registration_screen.dart';
import 'package:riderfrontend/customerApp/customer_theme.dart';
import 'package:riderfrontend/screens/login.dart';

const _page = Color(0xFFEAF6FE);
const _ink = Color(0xFF0B2F66);
const _blue = Color(0xFF0070E0);
const _word = Color(0xFF0054C8);
const _muted = Color(0xFF5C6E84);
const _line = Color(0xFFD5E4F2);

class AccountTypeSelectionScreen extends StatefulWidget {
  const AccountTypeSelectionScreen({super.key});

  @override
  State<AccountTypeSelectionScreen> createState() => _AccountTypeSelectionScreenState();
}

class _AccountTypeSelectionScreenState extends State<AccountTypeSelectionScreen> {
  var _leaving = false;

  void _open(Widget screen) {
    if (_leaving) return;
    setState(() => _leaving = true);
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen)).whenComplete(() {
      if (mounted) setState(() => _leaving = false);
    });
  }

  Future<void> _policy(String title) async {
    final kind = title.toLowerCase().contains('term') ? 'terms' : 'privacy';
    var body = 'The document could not be loaded.';
    try {
      body = (await ApiScope.of(context).policyDocument(kind)).body;
    } on ApiException catch (error) {
      body = error.message;
    } catch (_) {
      body = 'The document could not be loaded.';
    }
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: customerType(18, FontWeight.w700, _ink)),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(child: Text(body, style: customerType(14, FontWeight.w500, _muted))),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('account-type-screen'),
      backgroundColor: _page,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final landscape = constraints.maxWidth > constraints.maxHeight;
          final customer = _RoleCard(
            art: 'assets/welcome/customer.png',
            icon: 'assets/welcome/icon_person.png',
            title: "I'm a Customer",
            body: 'Order drinking water, schedule deliveries, track your orders and manage your subscriptions.',
            action: 'Continue as Customer',
            filled: true,
            buttonKey: const Key('account-type-customer'),
            onPressed: _leaving ? null : () => _open(const CustomerRegistrationScreen()),
          );
          final rider = _RoleCard(
            art: 'assets/welcome/rider.png',
            icon: 'assets/welcome/icon_bike.png',
            title: "I'm a Rider",
            body: 'Access your rider account, view assigned deliveries, update delivery status and complete tasks.',
            action: 'Continue as Rider',
            filled: false,
            buttonKey: const Key('account-type-rider'),
            onPressed: _leaving
                ? null
                : () => _open(
                      const LoginScreen(
                        initialUsername: riderTestUsername,
                        initialPassword: riderTestPassword,
                      ),
                    ),
          );
          return Stack(
            fit: StackFit.expand,
            children: [
              const Positioned.fill(child: IgnorePointer(child: _RoleBackdrop())),
              SafeArea(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: landscape ? 980 : 560),
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(16, landscape ? 6 : 4, 16, landscape ? 48 : 88),
                      children: [
                        const _Logo(),
                        SizedBox(height: landscape ? 4 : 8),
                        _Hero(reserve: landscape ? 0.22 : 0.36),
                        SizedBox(height: landscape ? 4 : 8),
                        const _FeatureRow(),
                        SizedBox(height: landscape ? 8 : 12),
                        Text(
                          'How would you like to use AQUARIDER?',
                          textAlign: TextAlign.center,
                          style: customerType(landscape ? 16 : 18, FontWeight.w700, _ink, height: 1.2),
                        ),
                        const SizedBox(height: 4),
                        const Center(child: _Accent()),
                        const SizedBox(height: 10),
                        if (landscape)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: customer),
                              const SizedBox(width: 12),
                              Expanded(child: rider),
                            ],
                          )
                        else ...[
                          customer,
                          const SizedBox(height: 10),
                          rider,
                        ],
                        SizedBox(height: landscape ? 12 : 22),
                        const _SplitLabel('Already have an account?'),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          key: const Key('account-type-login'),
                          onPressed: _leaving
                              ? null
                              : () => _open(
                                    const LoginScreen(
                                      initialUsername: customerTestUsername,
                                      initialPassword: customerTestPassword,
                                    ),
                                  ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _blue,
                            backgroundColor: const Color(0xFFF7FBFE),
                            minimumSize: const Size(double.infinity, 48),
                            side: const BorderSide(color: Color(0xFFD3E2F1)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.asset('assets/welcome/icon_login.png', width: 22, height: 22),
                              const SizedBox(width: 8),
                              Text('Login', style: customerType(16, FontWeight.w700, _blue)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _Link(icon: Icons.verified_user_outlined, label: 'Privacy Policy', onPressed: () => _policy('Privacy Policy')),
                              Container(width: 1, height: 16, color: _line),
                              _Link(icon: Icons.description_outlined, label: 'Terms & Conditions', onPressed: () => _policy('Terms & Conditions')),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RoleBackdrop extends StatelessWidget {
  const _RoleBackdrop();

  @override
  Widget build(BuildContext context) {
    return const Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(painter: _RoleFillPainter()),
        _ScaledWelcomeArt(),
        CustomPaint(foregroundPainter: _RoleWavePainter(), child: SizedBox.expand()),
      ],
    );
  }
}

class _ScaledWelcomeArt extends StatelessWidget {
  const _ScaledWelcomeArt();

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (rect) {
        final landscape = rect.width > rect.height;
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [Color(0xFFFFFFFF), Color(0xFFFFFFFF), Color(0x00FFFFFF)],
          stops: landscape ? const [0, 0.46, 0.82] : const [0, 0.30, 0.58],
        ).createShader(rect);
      },
      child: const Image(
        image: AssetImage('assets/welcome/background.png'),
        fit: BoxFit.cover,
        alignment: Alignment(0.42, -1),
      ),
    );
  }
}

class _RoleFillPainter extends CustomPainter {
  const _RoleFillPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFD7F1FF), Color(0xFFEAF6FE), Color(0xFFE3F3FD)],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RoleWavePainter extends CustomPainter {
  const _RoleWavePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final band = h < w ? 0.16 : 0.11;
    final wave = Path()
      ..moveTo(0, h)
      ..lineTo(0, h * (1 - band))
      ..cubicTo(w * 0.22, h * (1 - band - 0.05), w * 0.4, h * (1 - band + 0.04), w * 0.58, h * (1 - band))
      ..cubicTo(w * 0.78, h * (1 - band - 0.045), w * 0.9, h * (1 - band + 0.02), w, h * (1 - band - 0.01))
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(
      wave,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF49B4F8), Color(0xFF0875DC), Color(0xFF0752B8)],
        ).createShader(Rect.fromLTWH(0, h * (1 - band - 0.04), w, h * (band + 0.06))),
    );
    final bubble = Paint()..color = const Color(0x99FFFFFF);
    for (final spot in <(double, double, double)>[(0.08, 0.95, 0.012), (0.18, 0.92, 0.007), (0.84, 0.94, 0.011), (0.92, 0.90, 0.006)]) {
      canvas.drawCircle(Offset(w * spot.$1, h * spot.$2), w * spot.$3, bubble);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Image.asset('assets/welcome/droplet.png', height: 46, fit: BoxFit.contain),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('AQUARIDER', style: customerType(20, FontWeight.w700, _word, height: 1)),
            Text('Water Supply & Delivery App', style: customerType(11, FontWeight.w600, _muted, height: 1.1)),
          ],
        ),
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.reserve});

  final double reserve;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final gap = (constraints.maxWidth * reserve).clamp(0.0, 220.0);
        return Padding(
          padding: EdgeInsets.only(right: gap),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Welcome to', style: customerType(22, FontWeight.w700, _ink, height: 1.05)),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text('AQUARIDER', style: customerType(24, FontWeight.w700, _word, height: 1.05)),
              ),
              const SizedBox(height: 6),
              const _Accent(),
              const SizedBox(height: 8),
              Text('Your Trusted Water Supply Partner', style: customerType(13, FontWeight.w600, _muted, height: 1.2)),
            ],
          ),
        );
      },
    );
  }
}

class _Accent extends StatelessWidget {
  const _Accent();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 3,
      decoration: BoxDecoration(color: _blue, borderRadius: BorderRadius.circular(2)),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: _Feature('assets/welcome/icon_drop.png', 'Order Water')),
        _Divider(),
        Expanded(child: _Feature('assets/welcome/icon_pin.png', 'Track Delivery')),
        _Divider(),
        Expanded(child: _Feature('assets/welcome/icon_history.png', 'Order History')),
      ],
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature(this.asset, this.label);

  final String asset;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Image.asset(asset, width: 36, height: 36, fit: BoxFit.contain),
        const SizedBox(height: 4),
        Text(label, textAlign: TextAlign.center, style: customerType(11, FontWeight.w600, _muted, height: 1.1)),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 42, color: _line);
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.art,
    required this.icon,
    required this.title,
    required this.body,
    required this.action,
    required this.filled,
    required this.buttonKey,
    required this.onPressed,
  });

  final String art;
  final String icon;
  final String title;
  final String body;
  final String action;
  final bool filled;
  final Key buttonKey;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final button = filled
        ? FilledButton(
            key: buttonKey,
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: _blue,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 40),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            ),
            child: _ActionLabel(action, Colors.white),
          )
        : OutlinedButton(
            key: buttonKey,
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: _blue,
              backgroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 40),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              side: const BorderSide(color: _blue, width: 1.4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            ),
            child: _ActionLabel(action, _blue),
          );
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFD6E7F7)),
        boxShadow: const [BoxShadow(color: Color(0x140B4F93), blurRadius: 16, offset: Offset(0, 6))],
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final artWidth = constraints.maxWidth < 340 ? 84.0 : 112.0;
          return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: artWidth,
              child: Image.asset(art, fit: BoxFit.cover),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Image.asset(icon, width: 26, height: 26, fit: BoxFit.contain),
                        const SizedBox(width: 6),
                        Expanded(child: Text(title, style: customerType(15, FontWeight.w700, _ink, height: 1.1))),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(body, style: customerType(11.5, FontWeight.w500, _muted, height: 1.2)),
                    const SizedBox(height: 8),
                    button,
                  ],
                ),
              ),
            ),
          ],
        ),
          );
        },
      ),
    );
  }
}

class _ActionLabel extends StatelessWidget {
  const _ActionLabel(this.label, this.color);

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: customerType(13, FontWeight.w700, color)),
          const SizedBox(width: 6),
          Icon(Icons.arrow_forward_rounded, size: 16, color: color),
        ],
      ),
    );
  }
}

class _SplitLabel extends StatelessWidget {
  const _SplitLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: _line, thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(label, style: customerType(13, FontWeight.w700, _ink)),
        ),
        const Expanded(child: Divider(color: _line, thickness: 1)),
      ],
    );
  }
}

class _Link extends StatelessWidget {
  const _Link({required this.icon, required this.label, required this.onPressed});

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: _blue,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        visualDensity: VisualDensity.compact,
      ),
      icon: Icon(icon, size: 16, color: _blue),
      label: Text(label, style: customerType(12, FontWeight.w600, _blue)),
    );
  }
}
