import 'package:flutter/material.dart';

import '../../data/admin_format.dart';
import '../../theme/admin_tokens.dart';

class AdminTopBar extends StatelessWidget {
  const AdminTopBar({
    required this.accountName,
    required this.accountRole,
    required this.search,
    required this.onSearch,
    required this.onNotify,
    required this.onHelp,
    this.onSkip,
    this.onMenu,
    this.searchHint,
    this.trailing,
    super.key,
  });

  final String accountName;
  final String accountRole;
  final TextEditingController search;
  final ValueChanged<String> onSearch;
  final VoidCallback? onSkip;
  final VoidCallback onNotify;
  final VoidCallback onHelp;
  final VoidCallback? onMenu;
  final String? searchHint;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final today = 'Today · ${formatAdminDay(DateTime.now())}';
    return Material(
      color: AdminTokens.surface,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AdminTokens.line)),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 860;
            final hint =
                searchHint ??
                (compact
                    ? 'Search steps'
                    : 'Search steps, plants, customers, or riders');
            return Row(
              children: [
                if (onMenu != null) ...[
                  IconButton(
                    onPressed: onMenu,
                    icon: const Icon(Icons.menu, color: AdminTokens.text),
                  ),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: Container(
                    height: 40,
                    constraints: const BoxConstraints(maxWidth: 420),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AdminTokens.field,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AdminTokens.line),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.search,
                          size: 18,
                          color: AdminTokens.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: search,
                            onChanged: onSearch,
                            style: adminType(
                              13,
                              FontWeight.w500,
                              AdminTokens.text,
                              height: 1.2,
                            ),
                            decoration: InputDecoration(
                              isCollapsed: true,
                              border: InputBorder.none,
                              hintText: hint,
                              hintStyle: adminType(
                                13,
                                FontWeight.w400,
                                AdminTokens.border,
                                height: 1.2,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (!compact) ...[
                  const SizedBox(width: 12),
                  Text(
                    today,
                    style: adminType(
                      13,
                      FontWeight.w600,
                      AdminTokens.textSecondary,
                      height: 1.2,
                    ),
                  ),
                ],
                IconButton(
                  onPressed: onNotify,
                  icon: const Icon(
                    Icons.notifications_none,
                    color: AdminTokens.secondary,
                  ),
                ),
                if (!compact)
                  IconButton(
                    onPressed: onHelp,
                    icon: const Icon(
                      Icons.help_outline,
                      color: AdminTokens.secondary,
                    ),
                  ),
                ?trailing,
                if (onSkip != null)
                  compact
                      ? IconButton(
                          onPressed: onSkip,
                          tooltip: 'Skip to Dashboard',
                          icon: const Icon(
                            Icons.arrow_forward,
                            color: AdminTokens.primary,
                          ),
                        )
                      : OutlinedButton.icon(
                          onPressed: onSkip,
                          style: adminOutlineButton(),
                          icon: const Icon(Icons.arrow_forward, size: 16),
                          label: const Text('Skip to Dashboard'),
                        ),
                _AccountChip(
                  name: accountName,
                  role: compact ? '' : accountRole,
                ),
                const SizedBox(width: 8),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AccountChip extends StatelessWidget {
  const _AccountChip({required this.name, required this.role});

  final String name;
  final String role;

  @override
  Widget build(BuildContext context) {
    final parts = name.split(' ').where((part) => part.isNotEmpty).take(2);
    final initials = parts.isEmpty
        ? 'A'
        : parts.map((part) => part[0]).join().toUpperCase();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: AdminTokens.primarySoft,
          child: Text(
            initials,
            style: adminType(
              11,
              FontWeight.w700,
              AdminTokens.primary,
              height: 1,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              name,
              style: adminType(
                13,
                FontWeight.w700,
                AdminTokens.text,
                height: 1.15,
              ),
            ),
            if (role.isNotEmpty)
              Text(
                role,
                style: adminType(
                  11,
                  FontWeight.w500,
                  AdminTokens.textSecondary,
                  height: 1.15,
                ),
              ),
          ],
        ),
      ],
    );
  }
}
