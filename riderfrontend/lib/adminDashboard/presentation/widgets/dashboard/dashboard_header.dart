import 'package:flutter/material.dart';

import '../../../data/dashboard_period.dart';
import '../../../theme/admin_tokens.dart';

class DashboardHeader extends StatelessWidget {
  const DashboardHeader({
    required this.greeting,
    required this.businessLine,
    required this.period,
    required this.onRange,
    required this.onCreateOrder,
    this.facilityName,
    this.onDutyRiders,
    super.key,
  });

  final String greeting;
  final String businessLine;
  final String? facilityName;
  final int? onDutyRiders;
  final DashboardPeriod period;
  final ValueChanged<DashboardRange> onRange;
  final VoidCallback onCreateOrder;

  @override
  Widget build(BuildContext context) {
    final chips = Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _RangeChip(
          label: 'Today',
          selected: period.range == DashboardRange.today,
          onTap: () => onRange(DashboardRange.today),
          chipKey: const Key('range-today'),
        ),
        _RangeChip(
          label: 'Yesterday',
          selected: period.range == DashboardRange.yesterday,
          onTap: () => onRange(DashboardRange.yesterday),
          chipKey: const Key('range-yesterday'),
        ),
        _RangeChip(
          label: '7D',
          selected: period.range == DashboardRange.week,
          onTap: () => onRange(DashboardRange.week),
          chipKey: const Key('range-7d'),
        ),
        _RangeChip(
          label: '30D',
          selected: period.range == DashboardRange.month,
          onTap: () => onRange(DashboardRange.month),
          chipKey: const Key('range-30d'),
        ),
        FilledButton.icon(
          key: const Key('create-order-button'),
          onPressed: onCreateOrder,
          style: adminPrimaryButton(radius: 10).copyWith(
            minimumSize: const WidgetStatePropertyAll(Size(0, 40)),
            padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: 14),
            ),
          ),
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Create Order'),
        ),
      ],
    );
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Overview  ›  Command Dashboard',
          style: adminType(
            12,
            FontWeight.w600,
            AdminTokens.textSecondary,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          greeting,
          style: adminType(28, FontWeight.w700, AdminTokens.text, height: 1.15),
        ),
        const SizedBox(height: 6),
        Text(
          businessLine,
          style: adminType(
            14,
            FontWeight.w500,
            AdminTokens.textSecondary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          period.label,
          style: adminType(
            12,
            FontWeight.w600,
            AdminTokens.border,
            height: 1.2,
          ),
        ),
        if (facilityName != null && facilityName!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            facilityName!,
            style: adminType(
              13,
              FontWeight.w600,
              AdminTokens.text,
              height: 1.2,
            ),
          ),
        ],
        if (onDutyRiders != null) ...[
          const SizedBox(height: 6),
          Text(
            '$onDutyRiders riders on duty',
            style: adminType(
              12.5,
              FontWeight.w700,
              AdminTokens.primary,
              height: 1.2,
            ),
          ),
        ],
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 860) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [copy, const SizedBox(height: 12), chips],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: copy),
            const SizedBox(width: 16),
            chips,
          ],
        );
      },
    );
  }
}

class _RangeChip extends StatelessWidget {
  const _RangeChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.chipKey,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Key chipKey;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AdminTokens.primarySoft : AdminTokens.surface,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        key: chipKey,
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? AdminTokens.primary : AdminTokens.line,
            ),
          ),
          child: Text(
            label,
            style: adminType(
              12.5,
              FontWeight.w700,
              selected ? AdminTokens.primary : AdminTokens.textSecondary,
              height: 1.1,
            ),
          ),
        ),
      ),
    );
  }
}
