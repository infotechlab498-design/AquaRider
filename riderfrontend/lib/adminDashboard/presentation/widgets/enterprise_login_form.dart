import 'package:flutter/material.dart';

import '../../theme/admin_tokens.dart';

class EnterpriseLoginForm extends StatelessWidget {
  const EnterpriseLoginForm({
    required this.username,
    required this.password,
    required this.obscure,
    required this.remember,
    required this.loading,
    required this.message,
    required this.onToggleObscure,
    required this.onToggleRemember,
    required this.onLogin,
    super.key,
  });

  final TextEditingController username;
  final TextEditingController password;
  final bool obscure;
  final bool remember;
  final bool loading;
  final String? message;
  final VoidCallback onToggleObscure;
  final VoidCallback onToggleRemember;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(36, 36, 36, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AdminTokens.button,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'CONSOLE ACCESS',
                style: adminType(
                  12,
                  FontWeight.w700,
                  AdminTokens.primary,
                  height: 1.2,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Welcome Back',
            style: adminType(
              30,
              FontWeight.w700,
              AdminTokens.text,
              height: 1.15,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Sign in to access your RouteLedger distribution workspace.',
            style: adminType(
              14,
              FontWeight.w400,
              AdminTokens.textSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 22),
          Text(
            'Email or Username',
            style: adminType(
              13,
              FontWeight.w600,
              AdminTokens.text,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          _AdminField(
            icon: Icons.person_outline,
            child: TextField(
              key: const Key('admin-username-field'),
              controller: username,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              style: adminType(
                14,
                FontWeight.w500,
                AdminTokens.text,
                height: 1.2,
              ),
              cursorColor: AdminTokens.primary,
              decoration: const InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: 'name@company.com',
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Master Password',
            style: adminType(
              13,
              FontWeight.w600,
              AdminTokens.text,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          _AdminField(
            icon: Icons.lock_outline,
            trailing: IconButton(
              onPressed: onToggleObscure,
              icon: Icon(
                obscure
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                size: 18,
                color: AdminTokens.textSecondary,
              ),
            ),
            child: TextField(
              key: const Key('admin-password-field'),
              controller: password,
              obscureText: obscure,
              onSubmitted: (_) => onLogin(),
              style: adminType(
                14,
                FontWeight.w500,
                AdminTokens.text,
                height: 1.2,
              ),
              cursorColor: AdminTokens.primary,
              decoration: const InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: onToggleRemember,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _CheckBox(checked: remember),
                  const SizedBox(width: 8),
                  Text(
                    'Remember 30 days',
                    style: adminType(
                      13,
                      FontWeight.w500,
                      AdminTokens.text,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const Key('admin-login-button'),
              onPressed: loading ? null : onLogin,
              style: adminPrimaryButton(),
              child: loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Sign In to Workspace'),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward, size: 18),
                      ],
                    ),
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 8),
            Text(
              message!,
              style: adminType(
                12.5,
                FontWeight.w600,
                AdminTokens.error,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 22),
          const Divider(color: AdminTokens.line, height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: AdminTokens.secondary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Node: Islamabad Server Farm 01',
                  style: adminType(
                    12,
                    FontWeight.w500,
                    AdminTokens.textSecondary,
                    height: 1.2,
                  ),
                ),
              ),
              Text(
                'BUILD 2026.4.1',
                style: adminType(
                  11,
                  FontWeight.w700,
                  AdminTokens.border,
                  height: 1.2,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AdminField extends StatelessWidget {
  const _AdminField({required this.icon, required this.child, this.trailing});

  final IconData icon;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: AdminTokens.field,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          Icon(icon, size: 18, color: AdminTokens.textSecondary),
          const SizedBox(width: 10),
          Expanded(child: child),
          ?trailing,
        ],
      ),
    );
  }
}

class _CheckBox extends StatelessWidget {
  const _CheckBox({required this.checked});

  final bool checked;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: checked ? AdminTokens.button : Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: checked ? AdminTokens.button : const Color(0xFFCBD5E1),
        ),
      ),
      child: checked
          ? const Icon(Icons.check, size: 14, color: Colors.white)
          : null,
    );
  }
}
