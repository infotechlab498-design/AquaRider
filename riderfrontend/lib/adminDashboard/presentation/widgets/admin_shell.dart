import 'package:flutter/material.dart';

import '../../admin_build.dart';
import '../../theme/admin_tokens.dart';
import '../../../api/route_api.dart';
import 'admin_sidebar.dart';
import 'admin_topbar.dart';

class AdminShell extends StatelessWidget {
  const AdminShell({
    required this.activeKey,
    required this.session,
    required this.serverReachable,
    required this.body,
    required this.search,
    required this.onSearch,
    required this.onNavigate,
    this.searchHint,
    this.onSkip,
    this.trailing,
    this.databaseLatencyMs,
    this.screenKey,
    this.onNotify,
    this.onHelp,
    super.key,
  });

  final String activeKey;
  final AuthSession? session;
  final bool serverReachable;
  final Widget body;
  final TextEditingController search;
  final ValueChanged<String> onSearch;
  final ValueChanged<String> onNavigate;
  final String? searchHint;
  final VoidCallback? onSkip;
  final Widget? trailing;
  final int? databaseLatencyMs;
  final Key? screenKey;
  final VoidCallback? onNotify;
  final VoidCallback? onHelp;

  @override
  Widget build(BuildContext context) {
    final accountName = session == null || session!.fullName.trim().isEmpty
        ? 'Administrator'
        : session!.fullName.trim();
    final accountRole = session == null || session!.role.trim().isEmpty
        ? 'Admin'
        : session!.role.trim();
    return Scaffold(
      key: screenKey,
      backgroundColor: AdminTokens.page,
      drawer: Drawer(
        child: AdminSidebar(
          serverReachable: serverReachable,
          activeKey: activeKey,
          onNavigate: (key) => _go(key),
          allowedScreens: _allowedScreens(),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 960;
          return Row(
            children: [
              if (wide)
                SizedBox(
                  width: 248,
                  child: AdminSidebar(
                    serverReachable: serverReachable,
                    activeKey: activeKey,
                    onNavigate: _go,
                    allowedScreens: _allowedScreens(),
                  ),
                ),
              Expanded(
                child: Column(
                  children: [
                    AdminTopBar(
                      accountName: accountName,
                      accountRole: accountRole,
                      search: search,
                      onSearch: onSearch,
                      onSkip: onSkip,
                      searchHint: searchHint,
                      trailing: trailing,
                      onNotify:
                          onNotify ??
                          () => showAdminNotice(
                            context,
                            'Notifications are not configured.',
                          ),
                      onHelp:
                          onHelp ??
                          () => showAdminNotice(
                            context,
                            'In-app help is not configured.',
                          ),
                      onMenu: wide
                          ? null
                          : () => Scaffold.of(context).openDrawer(),
                    ),
                    Expanded(child: body),
                    AdminSystemFooter(databaseLatencyMs: databaseLatencyMs),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Set<String>? _allowedScreens() {
    final current = session;
    if (current == null || current.isAdmin || current.allowedScreens == null) {
      return null;
    }
    return current.allowedScreens!.toSet();
  }

  void _go(String key) {
    if (key == activeKey) return;
    onNavigate(key);
  }
}

class AdminSystemFooter extends StatelessWidget {
  const AdminSystemFooter({this.databaseLatencyMs, super.key});

  final int? databaseLatencyMs;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: const BoxDecoration(
        color: AdminTokens.surface,
        border: Border(top: BorderSide(color: AdminTokens.line)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.verified_outlined,
            size: 15,
            color: AdminTokens.textSecondary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              AdminBuild.label,
              style: adminType(
                12,
                FontWeight.w600,
                AdminTokens.textSecondary,
                height: 1.2,
              ),
            ),
          ),
          if (databaseLatencyMs != null)
            Text(
              'Database latency $databaseLatencyMs ms',
              style: adminType(
                12,
                FontWeight.w600,
                AdminTokens.textSecondary,
                height: 1.2,
              ),
            ),
        ],
      ),
    );
  }
}

class AdminLoadingPane extends StatelessWidget {
  const AdminLoadingPane({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AdminTokens.primary),
          const SizedBox(height: 12),
          Text(
            label,
            style: adminType(14, FontWeight.w600, AdminTokens.textSecondary),
          ),
        ],
      ),
    );
  }
}

class AdminSectionMessage extends StatelessWidget {
  const AdminSectionMessage({
    required this.message,
    this.onRetry,
    this.error = false,
    super.key,
  });

  final String message;
  final VoidCallback? onRetry;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final tone = error ? AdminTokens.error : AdminTokens.warning;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: error ? AdminTokens.errorBg : AdminTokens.warningBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            error ? Icons.error_outline : Icons.info_outline,
            color: tone,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: adminType(13, FontWeight.w600, tone, height: 1.35),
            ),
          ),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class AdminSurface extends StatelessWidget {
  const AdminSurface({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    super.key,
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AdminTokens.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminTokens.line),
        boxShadow: AdminTokens.softShadow,
      ),
      child: child,
    );
  }
}
