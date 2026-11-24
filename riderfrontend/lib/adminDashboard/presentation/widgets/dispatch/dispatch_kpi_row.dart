import 'package:flutter/material.dart';

import 'package:riderfrontend/adminDashboard/data/dispatch_models.dart';
import 'package:riderfrontend/adminDashboard/presentation/widgets/admin_shell.dart';
import 'package:riderfrontend/adminDashboard/theme/admin_tokens.dart';

class DispatchKpiRow extends StatelessWidget {
  const DispatchKpiRow({
    required this.summary,
    required this.failed,
    super.key,
  });

  final DispatchOrderSummary? summary;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    if (failed) {
      return const AdminSectionMessage(
        message: 'Order totals could not be loaded.',
        error: true,
      );
    }
    final cards = summary?.kpis ?? const <DispatchKpi>[];
    if (cards.isEmpty) {
      return const AdminSectionMessage(
        message: 'No order totals were returned.',
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 1100
            ? cards.length.clamp(1, 5)
            : width >= 760
            ? 3
            : width >= 520
            ? 2
            : 1;
        const gap = 12.0;
        final cardWidth = (width - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final kpi in cards)
              SizedBox(
                width: cardWidth,
                child: _KpiCard(kpi: kpi),
              ),
          ],
        );
      },
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.kpi});

  final DispatchKpi kpi;

  @override
  Widget build(BuildContext context) {
    final tone = _tone(kpi.key);
    return AdminSurface(
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
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
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: tone.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(tone.icon, size: 16, color: tone.foreground),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            kpi.value,
            style: adminType(28, FontWeight.w700, AdminTokens.text, height: 1.05),
          ),
          if (kpi.detail != null && kpi.detail!.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              kpi.detail!.trim(),
              style: adminType(
                12,
                FontWeight.w600,
                tone.detail,
                height: 1.3,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _KpiTone {
  const _KpiTone(this.icon, this.foreground, this.background, this.detail);

  final IconData icon;
  final Color foreground;
  final Color background;
  final Color detail;
}

_KpiTone _tone(String key) {
  final value = key.toLowerCase();
  if (value.contains('pending')) {
    return const _KpiTone(
      Icons.warning_amber_rounded,
      Color(0xFFB45309),
      Color(0xFFFFF4D6),
      Color(0xFFB45309),
    );
  }
  if (value.contains('progress') || value.contains('route')) {
    return const _KpiTone(
      Icons.local_shipping_outlined,
      AdminTokens.button,
      AdminTokens.primarySoft,
      AdminTokens.button,
    );
  }
  if (value.contains('complete') || value.contains('deliver')) {
    return const _KpiTone(
      Icons.inventory_2_outlined,
      AdminTokens.success,
      AdminTokens.successSoft,
      AdminTokens.success,
    );
  }
  if (value.contains('assign')) {
    return const _KpiTone(
      Icons.groups_outlined,
      AdminTokens.button,
      AdminTokens.primarySoft,
      AdminTokens.textSecondary,
    );
  }
  return const _KpiTone(
    Icons.receipt_long_outlined,
    AdminTokens.button,
    AdminTokens.primarySoft,
    AdminTokens.success,
  );
}
