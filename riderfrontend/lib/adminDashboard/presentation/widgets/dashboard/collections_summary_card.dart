import 'package:flutter/material.dart';

import '../../../data/admin_format.dart';

import 'package:riderfrontend/adminDashboard/data/dashboard_models.dart';

import '../../../theme/admin_tokens.dart';
import '../admin_shell.dart';

class CollectionsSummaryCard extends StatelessWidget {
  const CollectionsSummaryCard({required this.summary, super.key});

  final CollectionsSummary summary;

  @override
  Widget build(BuildContext context) {
    final total = summary.reportedTotal;
    return AdminSurface(
      key: const Key('collections-summary-card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Collections',
                  style: adminType(
                    16,
                    FontWeight.w700,
                    AdminTokens.text,
                    height: 1.2,
                  ),
                ),
              ),
              if (total != null)
                Text(
                  formatPkr(total),
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
            'Cash, full credit, and partial cash.',
            style: adminType(
              12.5,
              FontWeight.w500,
              AdminTokens.textSecondary,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 14),
          if (total == null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                'No collection amounts were returned.',
                style: adminType(
                  13,
                  FontWeight.w600,
                  AdminTokens.textSecondary,
                  height: 1.3,
                ),
              ),
            ),
          for (final channel in summary.channels) ...[
            _ChannelRow(channel: channel),
            const SizedBox(height: 10),
          ],
          if (summary.balanced != null)
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                summary.balanced! ? 'Balanced' : 'Unbalanced',
                style: adminType(
                  12,
                  FontWeight.w700,
                  summary.balanced! ? AdminTokens.success : AdminTokens.warning,
                  height: 1.2,
                ),
              ),
            ),
          if (summary.note != null && summary.note!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              summary.note!,
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
    );
  }
}

class _ChannelRow extends StatelessWidget {
  const _ChannelRow({required this.channel});

  final CollectionChannel channel;

  @override
  Widget build(BuildContext context) {
    final percent = channel.percent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                channel.label,
                style: adminType(
                  13.5,
                  FontWeight.w700,
                  AdminTokens.text,
                  height: 1.2,
                ),
              ),
            ),
            Text(
              channel.amount == null
                  ? 'Not reported'
                  : formatPkr(channel.amount!),
              style: adminType(
                13,
                FontWeight.w700,
                channel.amount == null
                    ? AdminTokens.textSecondary
                    : AdminTokens.text,
                height: 1.2,
              ),
            ),
            if (percent != null) ...[
              const SizedBox(width: 8),
              Text(
                '${percent.round()}%',
                style: adminType(
                  12,
                  FontWeight.w600,
                  AdminTokens.textSecondary,
                  height: 1.2,
                ),
              ),
            ],
          ],
        ),
        if (channel.count != null)
          Text(
            '${channel.count} records',
            style: adminType(
              11.5,
              FontWeight.w500,
              AdminTokens.textSecondary,
              height: 1.2,
            ),
          ),
        if (percent != null) ...[
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              minHeight: 6,
              value: (percent / 100).clamp(0, 1).toDouble(),
              backgroundColor: AdminTokens.field,
              color: channel.key == 'cash'
                  ? AdminTokens.primary
                  : AdminTokens.secondary,
            ),
          ),
        ],
      ],
    );
  }
}