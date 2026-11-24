import 'package:flutter/material.dart';

import '../../../data/admin_format.dart';

import 'package:riderfrontend/adminDashboard/data/dashboard_models.dart';

import '../../../theme/admin_tokens.dart';
import '../admin_shell.dart';

class OperationalSummaryCard extends StatelessWidget {
  const OperationalSummaryCard({required this.summary, super.key});

  final OperationalSummary summary;

  @override
  Widget build(BuildContext context) {
    final tiles = <(String, int)>[
      if (summary.activeRoutes != null)
        ('Active routes', summary.activeRoutes!),
      if (summary.ridersOnDuty != null)
        ('Riders on duty', summary.ridersOnDuty!),
      if (summary.stopsCompleted != null)
        ('Stops completed', summary.stopsCompleted!),
      if (summary.stopsRemaining != null)
        ('Stops remaining', summary.stopsRemaining!),
      if (summary.exceptions != null) ('Exceptions', summary.exceptions!),
    ];
    return AdminSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Operational activity',
            style: adminType(
              16,
              FontWeight.w700,
              AdminTokens.text,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Assignments, stop progress, and recent activity for this period.',
            style: adminType(
              12.5,
              FontWeight.w500,
              AdminTokens.textSecondary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          if (!summary.hasContent)
            Text(
              'No operational activity was returned for this period.',
              style: adminType(
                13.5,
                FontWeight.w600,
                AdminTokens.textSecondary,
                height: 1.4,
              ),
            )
          else ...[
            if (tiles.isNotEmpty)
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final tile in tiles)
                    _StatTile(label: tile.$1, value: tile.$2),
                ],
              ),
            if (summary.note != null && summary.note!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                summary.note!,
                style: adminType(
                  13,
                  FontWeight.w500,
                  AdminTokens.text,
                  height: 1.4,
                ),
              ),
            ],
            if (summary.recent.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                'RECENT ACTIVITY',
                style: adminType(
                  11,
                  FontWeight.w700,
                  AdminTokens.textSecondary,
                  height: 1.2,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              for (final item in summary.recent.take(6)) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Icon(
                        Icons.circle,
                        size: 8,
                        color: AdminTokens.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: adminType(
                              13.5,
                              FontWeight.w700,
                              AdminTokens.text,
                              height: 1.25,
                            ),
                          ),
                          if (item.detail.isNotEmpty)
                            Text(
                              item.detail,
                              style: adminType(
                                12.5,
                                FontWeight.w500,
                                AdminTokens.textSecondary,
                                height: 1.3,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (item.occurredAt != null)
                      Text(
                        formatAdminTime(item.occurredAt!),
                        style: adminType(
                          12,
                          FontWeight.w600,
                          AdminTokens.textSecondary,
                          height: 1.2,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ],
          ],
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 148,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AdminTokens.field,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminTokens.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: adminType(
              10.5,
              FontWeight.w700,
              AdminTokens.textSecondary,
              height: 1.2,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$value',
            style: adminType(
              20,
              FontWeight.w700,
              AdminTokens.text,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}