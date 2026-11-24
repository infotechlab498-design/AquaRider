import 'package:flutter/material.dart';

import 'package:riderfrontend/adminDashboard/data/dashboard_models.dart';

import '../../../theme/admin_tokens.dart';
import '../admin_shell.dart';

class DashboardKpiWrap extends StatelessWidget {
  const DashboardKpiWrap({required this.cards, this.maxColumns = 6, super.key});

  final List<DashboardKpi> cards;
  final int maxColumns;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 1100
            ? maxColumns
            : width >= 760
            ? (maxColumns >= 3 ? 3 : maxColumns)
            : width >= 520
            ? 2
            : 1;
        const gap = 12.0;
        final cardWidth = (width - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final card in cards)
              SizedBox(
                width: cardWidth,
                child: DashboardKpiCard(kpi: card),
              ),
          ],
        );
      },
    );
  }
}

class DashboardKpiCard extends StatelessWidget {
  const DashboardKpiCard({required this.kpi, super.key});

  final DashboardKpi kpi;

  @override
  Widget build(BuildContext context) {
    return AdminSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  kpi.label.toUpperCase(),
                  style: adminType(
                    11,
                    FontWeight.w700,
                    AdminTokens.textSecondary,
                    height: 1.2,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              Icon(_icon(kpi.key), size: 16, color: AdminTokens.border),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            kpi.value,
            style: adminType(
              22,
              FontWeight.w700,
              AdminTokens.text,
              height: 1.15,
            ),
          ),
          if (kpi.detail != null || kpi.delta != null) ...[
            const SizedBox(height: 6),
            Text(
              [kpi.delta, kpi.detail]
                  .whereType<String>()
                  .where((part) => part.isNotEmpty)
                  .join(' · '),
              style: adminType(
                12,
                FontWeight.w600,
                AdminTokens.textSecondary,
                height: 1.3,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

IconData _icon(String key) {
  final value = key.toLowerCase();
  if (value.contains('collect')) return Icons.payments_outlined;
  if (value.contains('fleet') || value.contains('courier')) {
    return Icons.local_shipping_outlined;
  }
  if (value.contains('deliver')) return Icons.inventory_2_outlined;
  if (value.contains('order')) return Icons.receipt_long_outlined;
  if (value.contains('outstanding')) return Icons.account_balance_outlined;
  return Icons.bar_chart_outlined;
}