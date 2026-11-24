import 'package:flutter/material.dart';

import '../../../data/admin_format.dart';

import 'package:riderfrontend/adminDashboard/data/dashboard_models.dart';

import '../../../theme/admin_tokens.dart';
import '../admin_shell.dart';

class SalesSummaryChart extends StatelessWidget {
  const SalesSummaryChart({required this.summary, super.key});

  final SalesSummary summary;

  @override
  Widget build(BuildContext context) {
    final peak = summary.derivedPeakLabel;
    final maxAmount = summary.buckets.fold<num>(
      0,
      (max, bucket) => bucket.amount > max ? bucket.amount : max,
    );
    return AdminSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Sales',
                  style: adminType(
                    16,
                    FontWeight.w700,
                    AdminTokens.text,
                    height: 1.2,
                  ),
                ),
              ),
              if (summary.total != null)
                Text(
                  formatPkr(summary.total!),
                  style: adminType(
                    13,
                    FontWeight.w700,
                    AdminTokens.text,
                    height: 1.2,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            peak == null ? 'Amounts returned for this period.' : 'Peak · $peak',
            style: adminType(
              12.5,
              FontWeight.w600,
              AdminTokens.textSecondary,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          if (summary.buckets.isEmpty)
            Text(
              'No sales were returned for this period.',
              style: adminType(
                13.5,
                FontWeight.w600,
                AdminTokens.textSecondary,
                height: 1.4,
              ),
            )
          else
            SizedBox(
              height: 196,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final bucket in summary.buckets)
                      _Bar(
                        label: bucket.label,
                        amount: bucket.amount,
                        maxAmount: maxAmount,
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

class _Bar extends StatelessWidget {
  const _Bar({
    required this.label,
    required this.amount,
    required this.maxAmount,
  });

  final String label;
  final num amount;
  final num maxAmount;

  @override
  Widget build(BuildContext context) {
    final fraction = maxAmount <= 0
        ? 0.0
        : (amount / maxAmount).clamp(0, 1).toDouble();
    final height = amount <= 0 || maxAmount <= 0 ? 0.0 : 8 + (fraction * 120);
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: SizedBox(
        width: 48,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              formatGrouped(amount),
              style: adminType(
                10,
                FontWeight.w700,
                AdminTokens.textSecondary,
                height: 1.1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Container(
              height: height,
              width: 22,
              decoration: BoxDecoration(
                color: AdminTokens.primary,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: adminType(
                10,
                FontWeight.w600,
                AdminTokens.textSecondary,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}