import 'package:flutter/material.dart';

import '../../../api/route_api.dart';
import '../../theme/admin_tokens.dart';
import '../admin_nav.dart';
import '../widgets/admin_shell.dart';

class AdminUnavailableScreen extends StatefulWidget {
  const AdminUnavailableScreen({
    required this.activeKey,
    required this.onNavigate,
    this.session,
    super.key,
  });

  final String activeKey;
  final AuthSession? session;
  final ValueChanged<String> onNavigate;

  @override
  State<AdminUnavailableScreen> createState() => _AdminUnavailableScreenState();
}

class _AdminUnavailableScreenState extends State<AdminUnavailableScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String get _title => switch (widget.activeKey) {
    AdminNav.manifests => 'Route Manifests',
    AdminNav.audits => 'Inventory Audits',
    AdminNav.settings => 'HQ Settings',
    _ => 'This section',
  };

  String get _message => switch (widget.activeKey) {
    AdminNav.manifests =>
      'Route manifests are not available on this server yet.',
    AdminNav.audits => 'Inventory audits are not available on this server yet.',
    AdminNav.settings => 'HQ settings are not available on this server yet.',
    _ => 'This section is not available on this server yet.',
  };

  @override
  Widget build(BuildContext context) {
    return AdminShell(
      screenKey: const Key('admin-unavailable-screen'),
      activeKey: widget.activeKey,
      session: widget.session,
      serverReachable: true,
      search: _search,
      onSearch: (_) {},
      searchHint: 'Search is not available in this section',
      onNavigate: widget.onNavigate,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.inbox_outlined,
                  size: 36,
                  color: AdminTokens.textSecondary,
                ),
                const SizedBox(height: 12),
                Text(
                  _title,
                  style: adminType(
                    20,
                    FontWeight.w700,
                    AdminTokens.text,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _message,
                  textAlign: TextAlign.center,
                  style: adminType(
                    14,
                    FontWeight.w500,
                    AdminTokens.textSecondary,
                    height: 1.45,
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
