import 'package:flutter/material.dart';

import 'package:riderfrontend/adminDashboard/data/dashboard_models.dart';

import '../../../theme/admin_tokens.dart';
import '../admin_shell.dart';

class AttentionItemsCard extends StatelessWidget {
  const AttentionItemsCard({required this.items, super.key});

  final List<AttentionItem> items;

  @override
  Widget build(BuildContext context) {
    return AdminSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.notification_important_outlined,
                size: 18,
                color: AdminTokens.error,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Needs attention',
                  style: adminType(
                    16,
                    FontWeight.w700,
                    AdminTokens.text,
                    height: 1.2,
                  ),
                ),
              ),
              if (items.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AdminTokens.errorBg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${items.length}',
                    style: adminType(
                      12,
                      FontWeight.w700,
                      AdminTokens.error,
                      height: 1.1,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            Text(
              'Nothing needs attention for this period.',
              style: adminType(
                13.5,
                FontWeight.w600,
                AdminTokens.textSecondary,
                height: 1.4,
              ),
            )
          else
            for (final item in items) ...[
              _AttentionRow(item: item),
              const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }
}

class _AttentionRow extends StatelessWidget {
  const _AttentionRow({required this.item});

  final AttentionItem item;

  @override
  Widget build(BuildContext context) {
    final tone = switch (item.severity) {
      'error' || 'critical' || 'high' => AdminTokens.error,
      'warning' || 'medium' => AdminTokens.warning,
      _ => AdminTokens.primary,
    };
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AdminTokens.field,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminTokens.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: 16, color: tone),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.count == null
                      ? item.title
                      : '${item.title} (${item.count})',
                  style: adminType(
                    13.5,
                    FontWeight.w700,
                    AdminTokens.text,
                    height: 1.25,
                  ),
                ),
                if (item.detail.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    item.detail,
                    style: adminType(
                      12.5,
                      FontWeight.w500,
                      AdminTokens.textSecondary,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (item.actionLabel != null)
            TextButton(
              onPressed: () {
                showDialog<void>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(
                      item.title.isEmpty ? 'Attention item' : item.title,
                      style: adminType(18, FontWeight.w700, AdminTokens.text),
                    ),
                    content: Text(
                      item.detail.isEmpty
                          ? 'No further detail was returned.'
                          : item.detail,
                      style: adminType(
                        14,
                        FontWeight.w500,
                        AdminTokens.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                );
              },
              child: Text(item.actionLabel!),
            ),
        ],
      ),
    );
  }
}