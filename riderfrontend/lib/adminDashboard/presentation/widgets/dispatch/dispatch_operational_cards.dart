import 'package:flutter/material.dart';

import 'package:riderfrontend/adminDashboard/data/dispatch_models.dart';
import 'package:riderfrontend/adminDashboard/presentation/widgets/admin_shell.dart';
import 'package:riderfrontend/adminDashboard/theme/admin_tokens.dart';

class DispatchOperationalSection extends StatelessWidget {
  const DispatchOperationalSection({
    required this.summary,
    required this.failed,
    super.key,
  });

  final DispatchOperationalSummary? summary;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    if (failed || summary == null) {
      return const AdminSectionMessage(
        key: Key('dispatch-operational'),
        message: 'Operational summary could not be loaded.',
        error: true,
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final zone = _ZoneCard(zones: summary!.zones);
        final shift = _ShiftCard(shift: summary!.shift);
        if (constraints.maxWidth < 760) {
          return Column(
            children: [
              zone,
              const SizedBox(height: 12),
              shift,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: zone),
            const SizedBox(width: 12),
            Expanded(child: shift),
          ],
        );
      },
    );
  }
}

class _ZoneCard extends StatelessWidget {
  const _ZoneCard({required this.zones});

  final List<DispatchZoneSummary> zones;

  @override
  Widget build(BuildContext context) {
    return AdminSurface(
      key: const Key('dispatch-zones'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            zones.length == 1 ? zones.first.name : 'Operational zone summary',
            style: adminType(16, FontWeight.w700, AdminTokens.text, height: 1.2),
          ),
          const SizedBox(height: 4),
          Text(
            zones.length == 1 && zones.first.detail.isNotEmpty
                ? zones.first.detail
                : 'Stops and orders recorded for the selected day.',
            style: adminType(
              12.5,
              FontWeight.w500,
              AdminTokens.textSecondary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          if (zones.isEmpty)
            Text(
              'No operational zones were returned.',
              style: adminType(
                13.5,
                FontWeight.w600,
                AdminTokens.textSecondary,
                height: 1.4,
              ),
            )
          else
            for (final zone in zones) ...[
              if (zones.length != 1)
                Text(
                  zone.name,
                  style: adminType(14, FontWeight.w700, AdminTokens.text),
                ),
              if (zones.length != 1 && zone.detail.isNotEmpty)
                Text(
                  zone.detail,
                  style: adminType(
                    12.5,
                    FontWeight.w500,
                    AdminTokens.textSecondary,
                    height: 1.3,
                  ),
                ),
              if (zone.activeStops != null)
                Text(
                  'Stops ${zone.activeStops}',
                  style: adminType(13, FontWeight.w600, AdminTokens.text),
                ),
              if (zone.orderCount != null)
                Text(
                  'Orders ${zone.orderCount}',
                  style: adminType(13, FontWeight.w600, AdminTokens.text),
                ),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class _ShiftCard extends StatelessWidget {
  const _ShiftCard({required this.shift});

  final DispatchShiftProgress shift;

  @override
  Widget build(BuildContext context) {
    final percent = shift.percent;
    return AdminSurface(
      key: const Key('dispatch-shift'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Shift progress',
            style: adminType(16, FontWeight.w700, AdminTokens.text, height: 1.2),
          ),
          const SizedBox(height: 4),
          Text(
            shift.hasTarget
                ? 'Shift target: ${shift.target} deliveries'
                : 'Completed deliveries against the configured target.',
            style: adminType(
              12.5,
              FontWeight.w500,
              AdminTokens.textSecondary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          if (!shift.hasTarget)
            Text(
              'Not configured',
              key: const Key('dispatch-shift-unconfigured'),
              style: adminType(18, FontWeight.w700, AdminTokens.text),
            )
          else if (percent != null)
            Row(
              children: [
                SizedBox(
                  width: 92,
                  height: 92,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: percent.clamp(0, 1),
                        strokeWidth: 8,
                        backgroundColor: AdminTokens.primarySoft,
                        color: AdminTokens.button,
                      ),
                      Text(
                        '${(percent * 100).round()}%',
                        style: adminType(
                          18,
                          FontWeight.w700,
                          AdminTokens.text,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    '${shift.completed ?? 0} / ${shift.target}',
                    style: adminType(
                      13,
                      FontWeight.w600,
                      AdminTokens.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          if (shift.completed != null) ...[
            const SizedBox(height: 6),
            Text(
              'Completed ${shift.completed}',
              style: adminType(13, FontWeight.w600, AdminTokens.textSecondary),
            ),
          ],
          if (shift.hasTarget) ...[
            const SizedBox(height: 4),
            Text(
              'Target ${shift.target}',
              style: adminType(13, FontWeight.w600, AdminTokens.textSecondary),
            ),
          ],
          if (shift.averageStopMinutes != null) ...[
            const SizedBox(height: 4),
            Text(
              'Average stop ${formatDispatchNumber(shift.averageStopMinutes!)} min',
              style: adminType(13, FontWeight.w600, AdminTokens.textSecondary),
            ),
          ],
          if (shift.firstAttemptPercent != null) ...[
            const SizedBox(height: 4),
            Text(
              'First-attempt success ${formatDispatchNumber(shift.firstAttemptPercent!)}%',
              style: adminType(13, FontWeight.w600, AdminTokens.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}
