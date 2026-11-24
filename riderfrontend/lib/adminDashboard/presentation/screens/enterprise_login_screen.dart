import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../api/route_api.dart';
import '../../theme/admin_tokens.dart';
import '../admin_nav.dart';
import '../admin_routing.dart';
import '../admin_workspace.dart';
import '../widgets/enterprise_login_form.dart';
import '../widgets/enterprise_promo_panel.dart';

class EnterpriseLoginScreen extends StatefulWidget {
  const EnterpriseLoginScreen({super.key});

  @override
  State<EnterpriseLoginScreen> createState() => _EnterpriseLoginScreenState();
}

class _EnterpriseLoginScreenState extends State<EnterpriseLoginScreen> {
  static const _hqEmail = 'infotechlab498@gmail.com';
  static const _hqPassword = 'info498@';

  final _username = TextEditingController(text: _hqEmail);
  final _password = TextEditingController(text: _hqPassword);
  var _obscure = true;
  var _remember = true;
  var _loading = false;
  var _previewLoading = true;
  var _started = false;
  String? _message;
  AdminLoginPreview? _preview;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadPreview();
    });
  }

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _loadPreview() async {
    setState(() => _previewLoading = true);
    try {
      final preview = await ApiScope.of(context).adminLoginPreview();
      if (!mounted) return;
      setState(() {
        _preview = preview;
        _previewLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _preview = null;
        _previewLoading = false;
      });
    }
  }

  Future<void> _login() async {
    final username = _username.text.trim();
    final password = _password.text;
    if (username.isEmpty || password.isEmpty) {
      setState(() {
        _message = 'Enter your email or username and password.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      final session = await ApiScope.of(context).login(
        username,
        password,
        rememberMe: _remember,
      );
      if (!mounted) return;
      final rider = session.role.trim().toLowerCase() == 'rider';
      final canEnter = isAdminRole(session.role) || (session.allowedScreens?.isNotEmpty ?? false);
      if (rider || !canEnter) {
        await ApiScope.of(context).logout();
        setState(() {
          _loading = false;
          _message = rider
              ? 'Rider accounts sign in on the Rider app.'
              : 'This role has no portal screens yet. Save the screens, then sign in.';
        });
        return;
      }
      setState(() => _loading = false);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => AdminWorkspace(
            session: session,
            initialKey: AdminNav.dashboard,
          ),
        ),
      );
    } on ApiException {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _message = 'Authentication failed. Check your credentials and try again.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _message = 'Cannot reach the route server.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminTokens.page,
      body: Column(
        children: [
          const _LoginHeader(),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // The wide card stretches two panes. A scroll view gives
                // those panes infinite height, so the card needs an explicit
                // height or the sign-in form collapses.
                final cardHeight = math.max(640.0, constraints.maxHeight - 40);
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 20,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1120),
                      child: _LoginCard(
                        child: LayoutBuilder(
                          builder: (context, card) {
                            final split = card.maxWidth >= 780;
                            final form = EnterpriseLoginForm(
                              username: _username,
                              password: _password,
                              obscure: _obscure,
                              remember: _remember,
                              loading: _loading,
                              message: _message,
                              onToggleObscure: () =>
                                  setState(() => _obscure = !_obscure),
                              onToggleRemember: () =>
                                  setState(() => _remember = !_remember),
                              onLogin: _login,
                            );
                            final promo = EnterprisePromoPanel(
                              preview: _preview,
                              loading: _previewLoading,
                            );
                            if (!split) {
                              return Column(
                                children: [
                                  DecoratedBox(
                                    decoration: const BoxDecoration(
                                      gradient: AdminTokens.loginPromoGradient,
                                    ),
                                    child: promo,
                                  ),
                                  ColoredBox(
                                    color: AdminTokens.surface,
                                    child: form,
                                  ),
                                ],
                              );
                            }
                            return SizedBox(
                              height: cardHeight,
                              child: Stack(
                                children: [
                                  const Positioned.fill(
                                    child: Row(
                                      children: [
                                        Expanded(
                                          flex: 6,
                                          child: DecoratedBox(
                                            decoration: BoxDecoration(
                                              gradient: AdminTokens
                                                  .loginPromoGradient,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 5,
                                          child: ColoredBox(
                                            color: AdminTokens.surface,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Expanded(flex: 6, child: promo),
                                      Expanded(
                                        flex: 5,
                                        child: SingleChildScrollView(
                                          child: form,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const _LoginFooter(),
        ],
      ),
    );
  }
}

class _LoginCard extends StatelessWidget {
  const _LoginCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AdminTokens.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AdminTokens.cardShadow,
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(24), child: child),
    );
  }
}

class _LoginHeader extends StatelessWidget {
  const _LoginHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 18, 28, 8),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AdminTokens.button,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.alt_route, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Text(
            'RouteLedger',
            style: adminType(
              18,
              FontWeight.w700,
              AdminTokens.text,
              height: 1.1,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: AdminTokens.primarySoft,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'PRO',
              style: adminType(
                10,
                FontWeight.w700,
                AdminTokens.primary,
                height: 1.2,
                letterSpacing: 0.4,
              ),
            ),
          ),
          const Spacer(),
          Flexible(
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2F6),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text.rich(
                    TextSpan(
                      style: adminType(
                        12,
                        FontWeight.w500,
                        AdminTokens.textSecondary,
                        height: 1.2,
                      ),
                      children: [
                        const TextSpan(text: 'Need help? '),
                        TextSpan(
                          text: 'Fleet Support: +92 51 1234567',
                          style: adminType(
                            12,
                            FontWeight.w700,
                            AdminTokens.text,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: AdminTokens.line),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: AdminTokens.success,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'PK-NORTH ACTIVE',
                        style: adminType(
                          11,
                          FontWeight.w700,
                          AdminTokens.secondary,
                          height: 1.1,
                          letterSpacing: 0.3,
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

class _LoginFooter extends StatelessWidget {
  const _LoginFooter();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 8, 28, 16),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 8,
        children: [
          Wrap(
            spacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final label in const [
                'Privacy Policy',
                'Terms of Service',
                'Security Compliance',
                'Contact Fleet Operations',
              ])
                TextButton(
                  onPressed: () => showAdminNotice(
                    context,
                    '$label is not published in this build.',
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: AdminTokens.textSecondary,
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    label,
                    style: adminType(
                      12,
                      FontWeight.w500,
                      AdminTokens.textSecondary,
                      height: 1.2,
                    ),
                  ),
                ),
            ],
          ),
          Text(
            '© 2026 RouteLedger Inc. All rights reserved. Enterprise Last-Mile Intelligence.',
            style: adminType(
              12,
              FontWeight.w500,
              AdminTokens.textSecondary,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
