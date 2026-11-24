import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:riderfrontend/adminDashboard/presentation/admin_routing.dart';
import 'package:riderfrontend/customerApp/customer_signed_in_screen.dart';
import '../api/route_api.dart';
import '../core/typography.dart';

const riderTestUsername = 'infotech4@gmail.com';
const riderTestPassword = '123456in';
const customerTestUsername = 'usamamudassar81@gmail.com';
const customerTestPassword = '123456cu';
const _sessionKey = 'routeledger.username';

const _ink = Color(0xFF0C2F66);
const _secondary = Color(0xFF6A7C90);
const _muted = Color(0xFF7B8BA0);
const _primary = Color(0xFF0B74E8);
const _fieldBorder = Color(0xFFD7E6F4);
const _metrics = Color(0xFFF7FBFF);
const _sync = Color(0xFFE5F8EC);
const _syncInk = Color(0xFF168A45);
const _error = Color(0xFFD64545);

const _cardShadow = [
  BoxShadow(
    color: Color(0x1A000000),
    blurRadius: 6,
    spreadRadius: -1,
    offset: Offset(0, 4),
  ),
  BoxShadow(
    color: Color(0x1A000000),
    blurRadius: 4,
    spreadRadius: -2,
    offset: Offset(0, 2),
  ),
];

const _fieldShadow = [
  BoxShadow(color: Color(0x0D000000), blurRadius: 1, offset: Offset(0, 1)),
];

TextStyle _type(
  double size,
  FontWeight weight,
  Color color,
  double lineHeight, [
  double tracking = 0,
]) {
  return AppType.style(
    size,
    weight,
    color,
    lineHeight: lineHeight,
    letterSpacing: tracking,
  );
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    this.initialUsername = riderTestUsername,
    this.initialPassword = riderTestPassword,
    super.key,
  });

  /// Play-store test presets — rider by default; pass customer credentials for customer login.
  final String initialUsername;
  final String initialPassword;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final _username = TextEditingController(text: widget.initialUsername);
  late final _password = TextEditingController(text: widget.initialPassword);
  var _obscure = true;
  var _remember = true;
  var _loading = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_sessionKey);
    if (!mounted || saved == null || saved.isEmpty) return;
    setState(() {
      _username.text = saved;
      _remember = true;
    });
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  void _clearError() {
    if (_message == null) return;
    setState(() => _message = null);
  }

  Future<void> _login() async {
    final username = _username.text.trim();
    final password = _password.text;
    if (username.isEmpty || password.isEmpty) {
      setState(() {
        _message = username.isEmpty && password.isEmpty
            ? 'Enter your username and password.'
            : username.isEmpty
            ? 'Enter your username.'
            : 'Enter your password.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _message = null;
    });
    late final AuthSession session;
    try {
      session = await ApiScope.of(context)
          .login(username, password, rememberMe: _remember);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _message = error.message;
      });
      return;
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _message = 'Cannot reach the route server. Keep the phone on the same Wi-Fi as this PC.';
      });
      return;
    }
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    if (_remember) {
      await prefs.setString(_sessionKey, username);
    } else {
      await prefs.remove(_sessionKey);
    }
    if (!mounted) return;
    final role = session.role.trim().toLowerCase();
    if (role == 'customer') {
      setState(() => _loading = false);
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => CustomerSignedInScreen(session: session)),
        (route) => false,
      );
      return;
    }
    if (role != 'rider') {
      await ApiScope.of(context).logout();
      if (!mounted) return;
      setState(() {
        _loading = false;
        _message = 'This account signs in on the portal.';
      });
      return;
    }
    setState(() => _loading = false);
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => homeForSession(session)),
      (route) => false,
    );
  }

  Future<void> _forgotPassword() async {
    final username = _username.text.trim();
    if (username.isNotEmpty) {
      try {
        await ApiScope.of(context).forgotPassword(username);
      } on ApiException {
        // The server returns the same message for known and unknown users.
      }
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Ask your fleet admin to reset this password.',
          style: _type(14, FontWeight.w500, Colors.white, 20),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFD7F2FF),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _WaterBackdropPainter(),
                foregroundPainter: _WaterEdgePainter(),
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final pad = width < 360 ? 12.0 : 18.0;
                return Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(pad, 8, pad, 88),
                      child: Column(
                        children: [
                          _BrandHeader(width: width),
                          SizedBox(height: width < 360 ? 8 : 12),
                          _LoginCard(
                            username: _username,
                            password: _password,
                            obscure: _obscure,
                            remember: _remember,
                            loading: _loading,
                            message: _message,
                            onChanged: _clearError,
                            onToggleObscure: () => setState(() => _obscure = !_obscure),
                            onToggleRemember: () => setState(() => _remember = !_remember),
                            onForgot: _forgotPassword,
                            onLogin: _loading ? () {} : _login,
                          ),
                          const SizedBox(height: 12),
                          const _RouteCard(),
                          const SizedBox(height: 14),
                          const _Footer(),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    final art = (width * 0.34).clamp(108.0, 168.0);
    final name = (width * 0.062).clamp(20.0, 30.0);
    final drop = (width * 0.11).clamp(36.0, 52.0);
    return SizedBox(
      height: art + 18,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            bottom: 0,
            width: width * 0.34,
            height: art,
            child: Image.asset(
              'assets/welcome/rider.png',
              fit: BoxFit.contain,
              alignment: Alignment.bottomLeft,
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            width: width * 0.30,
            height: art * 0.92,
            child: const _JugMark(),
          ),
          Align(
            alignment: const Alignment(0, -0.15),
            child: SizedBox(
              width: width * 0.48,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset('assets/welcome/droplet.png', height: drop, fit: BoxFit.contain),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'AQUARIDER',
                      style: _type(name, FontWeight.w800, _primary, name + 2, 0.6),
                    ),
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Water Supply & Delivery App',
                      style: _type(11, FontWeight.w500, const Color(0xFF5C7A9A), 14),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _JugMark extends StatelessWidget {
  const _JugMark();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        Positioned(right: 0, bottom: 18, child: Image.asset('assets/welcome/leaf.png', width: 28, fit: BoxFit.contain)),
        Positioned(left: 8, right: 16, top: 0, bottom: 16, child: Image.asset('assets/welcome/jug.png', fit: BoxFit.contain)),
        Positioned(left: 0, right: 0, bottom: 0, child: Image.asset('assets/welcome/splash.png', height: 28, fit: BoxFit.contain)),
      ],
    );
  }
}

class _LoginCard extends StatelessWidget {
  const _LoginCard({
    required this.username,
    required this.password,
    required this.obscure,
    required this.remember,
    required this.loading,
    required this.message,
    required this.onChanged,
    required this.onToggleObscure,
    required this.onToggleRemember,
    required this.onForgot,
    required this.onLogin,
  });

  final TextEditingController username;
  final TextEditingController password;
  final bool obscure;
  final bool remember;
  final bool loading;
  final String? message;
  final VoidCallback onChanged;
  final VoidCallback onToggleObscure;
  final VoidCallback onToggleRemember;
  final VoidCallback onForgot;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE4F0FA)),
        boxShadow: _cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Welcome Back',
            textAlign: TextAlign.center,
            style: _type(24, FontWeight.w700, _ink, 28),
          ),
          const SizedBox(height: 4),
          Center(
            child: Container(
              width: 42,
              height: 3,
              decoration: BoxDecoration(color: _primary, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Sign in to continue to your route.',
            textAlign: TextAlign.center,
            style: _type(13, FontWeight.w500, _secondary, 18),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.mail_outline, size: 16, color: _ink),
              const SizedBox(width: 6),
              Text('Email or Username', style: _type(13, FontWeight.w600, _ink, 18)),
            ],
          ),
          const SizedBox(height: 8),
          _FieldShell(
            icon: 'assets/login/icon_user.svg',
            iconWidth: 14.6667,
            iconHeight: 14.6667,
            child: TextField(
              key: const Key('username-field'),
              controller: username,
              onChanged: (_) => onChanged(),
              style: _type(14, FontWeight.w400, _ink, 20),
              cursorColor: _primary,
              decoration: _fieldDecoration,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.lock_outline, size: 16, color: _ink),
              const SizedBox(width: 6),
              Text('Password', style: _type(13, FontWeight.w600, _ink, 18)),
            ],
          ),
          const SizedBox(height: 8),
          _FieldShell(
            icon: 'assets/login/icon_lock.svg',
            iconWidth: 14.6667,
            iconHeight: 19.25,
            trailing: SizedBox(
              width: 48,
              height: 44.5,
              child: IconButton(
                onPressed: onToggleObscure,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 48,
                  height: 44.5,
                ),
                icon: obscure
                    ? const _Asset('assets/login/icon_eye.svg', 18.3333, 12.5)
                    : const Icon(
                        Icons.visibility_off_outlined,
                        size: 18,
                        color: _secondary,
                      ),
              ),
            ),
            child: TextField(
              key: const Key('password-field'),
              controller: password,
              obscureText: obscure,
              onChanged: (_) => onChanged(),
              style: _type(14, FontWeight.w400, _ink, 20),
              cursorColor: _primary,
              decoration: _fieldDecoration,
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 0,
            children: [
              GestureDetector(
                onTap: onToggleRemember,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _RememberBox(checked: remember),
                      const SizedBox(width: 8),
                      Text(
                        'Remember session',
                        style: _type(12, FontWeight.w500, _ink, 16, 0.2),
                      ),
                    ],
                  ),
                ),
              ),
              TextButton(
                onPressed: onForgot,
                style: TextButton.styleFrom(
                  foregroundColor: _primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 8,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                child: Text(
                  'Forgot Password?',
                  style: _type(12, FontWeight.w600, _primary, 16, 0.2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SignInButton(loading: loading, onPressed: onLogin),
          if (message != null) ...[
            const SizedBox(height: 8),
            Text(message!, style: _type(12, FontWeight.w500, _error, 16, 0.2)),
          ],
        ],
      ),
    );
  }
}

const _fieldDecoration = InputDecoration(
  isCollapsed: true,
  isDense: true,
  border: InputBorder.none,
  enabledBorder: InputBorder.none,
  focusedBorder: InputBorder.none,
  contentPadding: EdgeInsets.zero,
);

class _FieldShell extends StatelessWidget {
  const _FieldShell({
    required this.icon,
    required this.iconWidth,
    required this.iconHeight,
    required this.child,
    this.trailing,
  });

  final String icon;
  final double iconWidth;
  final double iconHeight;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _fieldBorder),
        boxShadow: _fieldShadow,
      ),
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          Positioned(
            left: 14,
            top: 13,
            child: _Asset(icon, iconWidth, iconHeight),
          ),
          Padding(
            padding: EdgeInsets.only(
              left: 44,
              right: trailing == null ? 16 : 48,
            ),
            child: child,
          ),
          if (trailing != null)
            Positioned(right: 0, top: 1.75, child: trailing!),
        ],
      ),
    );
  }
}

class _RememberBox extends StatelessWidget {
  const _RememberBox({required this.checked});

  final bool checked;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: checked ? _primary : Colors.white,
        borderRadius: BorderRadius.circular(2.5),
        border: checked ? null : Border.all(color: _fieldBorder),
      ),
      child: checked ? const CustomPaint(painter: _CheckPainter()) : null,
    );
  }
}

class _CheckPainter extends CustomPainter {
  const _CheckPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(size.width * 0.24, size.height * 0.52)
      ..lineTo(size.width * 0.42, size.height * 0.68)
      ..lineTo(size.width * 0.76, size.height * 0.34);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SignInButton extends StatelessWidget {
  const _SignInButton({required this.loading, required this.onPressed});

  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(colors: [Color(0xFF0A6FE0), Color(0xFF2B9BFF)]),
        boxShadow: _cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const Key('login-button'),
          onTap: onPressed,
          borderRadius: BorderRadius.circular(26),
          child: SizedBox(
            height: 48,
            width: double.infinity,
            child: loading
                ? const Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Sign In',
                        style: _type(14, FontWeight.w600, Colors.white, 20),
                      ),
                      const SizedBox(width: 8),
                      const _Asset(
                        'assets/login/icon_arrow.svg',
                        13.3333,
                        13.3333,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _RouteCard extends StatelessWidget {
  const _RouteCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _metrics,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE3EEF8)),
        boxShadow: _fieldShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: _fieldShadow,
            ),
            child: const Center(
              child: _Asset('assets/login/icon_truck.svg', 22, 16),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sector 4D Route Ready',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _type(14, FontWeight.w600, _ink, 20),
                ),
                Text(
                  '28 stops loaded • 6 priority parcels',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _type(12, FontWeight.w400, _secondary, 16, 0.2),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _sync,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, size: 14, color: _syncInk),
                const SizedBox(width: 4),
                Text('Sync OK', style: _type(11, FontWeight.w700, _syncInk, 16)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 24),
      child: Column(
        children: [
          Text(
            'Version 1.0.0 (Build 4209)',
            textAlign: TextAlign.center,
            style: _type(11, FontWeight.w500, _secondary, 16, 0.3),
          ),
          const SizedBox(height: 2),
          Text(
            'POWERED BY AQUARIDER MOBILE',
            textAlign: TextAlign.center,
            style: _type(11, FontWeight.w600, _muted, 16, 0.5),
          ),
        ],
      ),
    );
  }
}

class _WaterBackdropPainter extends CustomPainter {
  const _WaterBackdropPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFD4F0FF), Color(0xFFEAF7FF), Color(0xFFD7F0FF)],
          stops: [0, 0.42, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _WaterEdgePainter extends CustomPainter {
  const _WaterEdgePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final top = Path()
      ..moveTo(0, 0)
      ..lineTo(w, 0)
      ..lineTo(w, h * 0.07)
      ..quadraticBezierTo(w * 0.7, h * 0.13, w * 0.42, h * 0.055)
      ..quadraticBezierTo(w * 0.18, h * 0.0, 0, h * 0.09)
      ..close();
    canvas.drawPath(top, Paint()..color = const Color(0x6639A6F0));
    final topSoft = Path()
      ..moveTo(0, 0)
      ..lineTo(w * 0.58, 0)
      ..quadraticBezierTo(w * 0.28, h * 0.09, 0, h * 0.045)
      ..close();
    canvas.drawPath(topSoft, Paint()..color = const Color(0x552B8FE0));

    final waveTop = h * 0.84;
    final wave = Path()
      ..moveTo(0, h)
      ..lineTo(0, waveTop)
      ..cubicTo(w * 0.22, h * 0.76, w * 0.38, h * 0.93, w * 0.58, h * 0.86)
      ..cubicTo(w * 0.78, h * 0.79, w * 0.9, h * 0.9, w, h * 0.84)
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(
      wave,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF49B4F8), Color(0xFF0875DC), Color(0xFF0752B8)],
        ).createShader(Rect.fromLTWH(0, h * 0.76, w, h * 0.24)),
    );

    final bubble = Paint()..color = const Color(0x99FFFFFF);
    final gloss = Paint()..color = const Color(0x66FFFFFF);
    final spots = <(double, double, double)>[
      (0.08, 0.90, 0.018),
      (0.16, 0.95, 0.010),
      (0.78, 0.91, 0.016),
      (0.90, 0.86, 0.009),
      (0.06, 0.10, 0.008),
      (0.93, 0.14, 0.011),
      (0.84, 0.96, 0.007),
    ];
    for (final spot in spots) {
      final center = Offset(w * spot.$1, h * spot.$2);
      final radius = w * spot.$3;
      canvas.drawCircle(center, radius, bubble);
      canvas.drawCircle(center.translate(-radius * 0.25, -radius * 0.25), radius * 0.28, gloss);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Asset extends StatelessWidget {
  const _Asset(this.path, this.width, this.height);

  final String path;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(path, width: width, height: height);
  }
}
