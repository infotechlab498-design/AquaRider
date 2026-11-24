import 'package:flutter/material.dart';

import '../../../data/admin_format.dart';

import 'package:riderfrontend/adminDashboard/data/admin_json.dart';
import 'package:riderfrontend/adminDashboard/data/dashboard_models.dart';
import 'package:riderfrontend/adminDashboard/data/rider_operations_models.dart';

import '../../../theme/admin_tokens.dart';
import '../admin_shell.dart';
import '../dashboard/dashboard_kpi_card.dart';

class RiderKpiWrap extends StatelessWidget {
  const RiderKpiWrap({required this.kpis, super.key});

  final List<RiderKpi> kpis;

  @override
  Widget build(BuildContext context) {
    return DashboardKpiWrap(
      maxColumns: 5,
      cards: [
        for (final kpi in kpis)
          DashboardKpi(
            key: kpi.key,
            label: kpi.label,
            value: kpi.value,
            detail: kpi.detail,
          ),
      ],
    );
  }
}

class RiderOverviewPanel extends StatelessWidget {
  const RiderOverviewPanel({
    required this.selected,
    required this.assignments,
    required this.assignmentsFailed,
    required this.activity,
    required this.activityFailed,
    required this.exceptions,
    required this.exceptionsFailed,
    super.key,
  });

  final RiderRecord? selected;
  final List<RiderAssignment> assignments;
  final bool assignmentsFailed;
  final List<RiderActivityItem> activity;
  final bool activityFailed;
  final List<RiderExceptionItem> exceptions;
  final bool exceptionsFailed;

  @override
  Widget build(BuildContext context) {
    final completed = selected?.completedStops;
    final total = selected?.totalStops;
    final progress = completed != null && total != null && total > 0
        ? (completed / total).clamp(0, 1).toDouble()
        : null;
    return AdminSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Operational overview',
            style: adminType(
              16,
              FontWeight.w700,
              AdminTokens.text,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Assignments, progress, and exceptions for the selected day.',
            style: adminType(
              12.5,
              FontWeight.w500,
              AdminTokens.textSecondary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          if (selected == null)
            Text(
              'Select a rider to load assignments and activity.',
              style: adminType(
                13.5,
                FontWeight.w600,
                AdminTokens.textSecondary,
                height: 1.4,
              ),
            )
          else ...[
            Text(
              selected!.fullName,
              style: adminType(
                15,
                FontWeight.w700,
                AdminTokens.text,
                height: 1.2,
              ),
            ),
            if (completed != null || total != null) ...[
              const SizedBox(height: 8),
              Text(
                completed != null && total != null
                    ? '$completed of $total stops'
                    : '${completed ?? total} stops',
                style: adminType(
                  13,
                  FontWeight.w600,
                  AdminTokens.textSecondary,
                ),
              ),
              if (progress != null) ...[
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    minHeight: 8,
                    value: progress,
                    color: AdminTokens.primary,
                    backgroundColor: AdminTokens.field,
                  ),
                ),
              ],
            ],
            const SizedBox(height: 12),
            Text(
              'ASSIGNMENTS',
              style: adminType(
                11,
                FontWeight.w700,
                AdminTokens.textSecondary,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 6),
            if (assignmentsFailed)
              Text(
                'Assignments could not be loaded.',
                style: adminType(13, FontWeight.w600, AdminTokens.error),
              )
            else if (assignments.isEmpty)
              Text(
                'No assignments were returned.',
                style: adminType(
                  13,
                  FontWeight.w600,
                  AdminTokens.textSecondary,
                ),
              )
            else
              for (final stop in assignments.take(6))
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '${stop.sequence == null ? '' : '${stop.sequence}. '}${stop.customerName}${stop.status.isEmpty ? '' : ' · ${stop.status}'}',
                    style: adminType(
                      13,
                      FontWeight.w600,
                      AdminTokens.text,
                      height: 1.3,
                    ),
                  ),
                ),
            const SizedBox(height: 8),
            Text(
              'LAST ACTIVITY',
              style: adminType(
                11,
                FontWeight.w700,
                AdminTokens.textSecondary,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 6),
            if (activityFailed)
              Text(
                'Activity could not be loaded.',
                style: adminType(13, FontWeight.w600, AdminTokens.error),
              )
            else if (_activityLine(activity, selected!) == null)
              Text(
                'No activity was returned.',
                style: adminType(
                  13,
                  FontWeight.w600,
                  AdminTokens.textSecondary,
                ),
              )
            else
              Text(
                _activityLine(activity, selected!)!,
                style: adminType(
                  13,
                  FontWeight.w600,
                  AdminTokens.text,
                  height: 1.35,
                ),
              ),
          ],
          const SizedBox(height: 14),
          Text(
            'EXCEPTIONS',
            style: adminType(
              11,
              FontWeight.w700,
              AdminTokens.textSecondary,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 6),
          if (exceptionsFailed)
            Text(
              'Exceptions could not be loaded.',
              style: adminType(13, FontWeight.w600, AdminTokens.error),
            )
          else if (exceptions.isEmpty)
            Text(
              'No exceptions were returned for this date.',
              style: adminType(
                13,
                FontWeight.w600,
                AdminTokens.textSecondary,
                height: 1.35,
              ),
            )
          else if (_visibleExceptions(exceptions).isEmpty)
            Text(
              'No exceptions were returned for this date.',
              style: adminType(
                13,
                FontWeight.w600,
                AdminTokens.textSecondary,
                height: 1.35,
              ),
            )
          else
            for (final item in _visibleExceptions(exceptions).take(5))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      operationsDisplayText(item.title) ??
                          operationsDisplayText(item.detail)!,
                      style: adminType(
                        13.5,
                        FontWeight.w700,
                        AdminTokens.text,
                        height: 1.25,
                      ),
                    ),
                    if (operationsDisplayText(item.detail) != null &&
                        operationsDisplayText(item.title) != null)
                      Text(
                        operationsDisplayText(item.detail)!,
                        style: adminType(
                          12.5,
                          FontWeight.w500,
                          AdminTokens.textSecondary,
                          height: 1.3,
                        ),
                      ),
                    if (operationsDisplayText(item.riderName) != null)
                      Text(
                        operationsDisplayText(item.riderName)!,
                        style: adminType(
                          12,
                          FontWeight.w600,
                          AdminTokens.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class RiderDirectory extends StatelessWidget {
  const RiderDirectory({
    required this.search,
    required this.status,
    required this.onStatus,
    required this.riders,
    required this.selectedId,
    required this.onSelect,
    this.detail,
    this.detailFailed = false,
    this.onCall,
    this.onProfile,
    this.onAssignments,
    this.onActivity,
    this.emptyMessage = 'No riders match this search.',
    super.key,
  });

  final TextEditingController search;
  final String status;
  final ValueChanged<String> onStatus;
  final List<RiderRecord> riders;
  final String? selectedId;
  final ValueChanged<String> onSelect;
  final RiderRecord? detail;
  final bool detailFailed;
  final VoidCallback? onCall;
  final VoidCallback? onProfile;
  final VoidCallback? onAssignments;
  final VoidCallback? onActivity;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    final selected = _selected(riders, selectedId);
    final shown = detail ?? selected;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const Key('rider-search'),
          controller: search,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: 'Search rider by name, ID, or route',
            filled: true,
            fillColor: AdminTokens.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AdminTokens.line),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AdminTokens.line),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _FilterChip(
              label: 'All',
              value: 'all',
              selected: status,
              onStatus: onStatus,
            ),
            _FilterChip(
              label: 'Active',
              value: 'active',
              selected: status,
              onStatus: onStatus,
            ),
            _FilterChip(
              label: 'At customer',
              value: 'atCustomer',
              selected: status,
              onStatus: onStatus,
            ),
            _FilterChip(
              label: 'Idle',
              value: 'idle',
              selected: status,
              onStatus: onStatus,
            ),
            _FilterChip(
              label: 'Offline',
              value: 'offline',
              selected: status,
              onStatus: onStatus,
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (shown != null) ...[
          _DetailCard(
            rider: shown,
            detailFailed: detailFailed,
            onCall: onCall,
            onProfile: onProfile,
            onAssignments: onAssignments,
            onActivity: onActivity,
          ),
          const SizedBox(height: 12),
        ],
        if (riders.isEmpty)
          Text(
            emptyMessage,
            key: const Key('rider-directory-empty'),
            style: adminType(
              13.5,
              FontWeight.w600,
              AdminTokens.textSecondary,
              height: 1.4,
            ),
          )
        else
          for (final rider in riders) ...[
            _DirectoryCard(
              rider: rider,
              selected: rider.id == selectedId,
              onTap: () => onSelect(rider.id),
            ),
            const SizedBox(height: 8),
          ],
      ],
    );
  }
}

RiderRecord? _selected(List<RiderRecord> riders, String? id) {
  for (final rider in riders) {
    if (rider.id == id) return rider;
  }
  return null;
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onStatus,
  });

  final String label;
  final String value;
  final String selected;
  final ValueChanged<String> onStatus;

  @override
  Widget build(BuildContext context) {
    final active = selected == value;
    return Material(
      color: active ? AdminTokens.primarySoft : AdminTokens.surface,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        key: Key('rider-filter-$value'),
        onTap: () => onStatus(value),
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: active ? AdminTokens.primary : AdminTokens.line,
            ),
          ),
          child: Text(
            label,
            style: adminType(
              12,
              FontWeight.w700,
              active ? AdminTokens.primary : AdminTokens.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({
    required this.rider,
    required this.detailFailed,
    this.onCall,
    this.onProfile,
    this.onAssignments,
    this.onActivity,
  });

  final RiderRecord rider;
  final bool detailFailed;
  final VoidCallback? onCall;
  final VoidCallback? onProfile;
  final VoidCallback? onAssignments;
  final VoidCallback? onActivity;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdminTokens.navy,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AdminTokens.button,
                child: Text(
                  rider.initials,
                  style: adminType(12, FontWeight.w700, Colors.white),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rider.fullName.isEmpty ? 'Rider' : rider.fullName,
                      style: adminType(
                        16,
                        FontWeight.w700,
                        Colors.white,
                        height: 1.2,
                      ),
                    ),
                    Text(
                      [
                        rider.riderCode,
                        rider.vehicleName,
                        rider.vehiclePlate,
                      ].where((part) => part.isNotEmpty).join(' · '),
                      style: adminType(
                        12,
                        FontWeight.w500,
                        AdminTokens.promoMuted,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              if (operationsDisplayText(rider.status) != null)
                Text(
                  operationsDisplayText(rider.status)!,
                  style: adminType(
                    12,
                    FontWeight.w700,
                    const Color(0xFF8FD0FF),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _line('Route', rider.routeName),
          _line('Next stop', operationsDisplayText(rider.nextStop) ?? ''),
          _line('Stops', _stops(rider)),
          _line(
            'Sales',
            rider.salesAmount == null ? '' : formatPkr(rider.salesAmount!),
          ),
          _line(
            'Cash in hand',
            rider.cashInHand == null ? '' : formatPkr(rider.cashInHand!),
          ),
          _line(
            'Returns',
            rider.returnsCount == null ? '' : '${rider.returnsCount}',
          ),
          if (detailFailed)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'The rider detail could not be loaded.',
                style: adminType(
                  12.5,
                  FontWeight.w600,
                  const Color(0xFFFFB4A8),
                ),
              ),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 4,
            children: [
              if (onProfile != null)
                TextButton(
                  key: const Key('rider-view-profile'),
                  onPressed: onProfile,
                  style: TextButton.styleFrom(foregroundColor: Colors.white),
                  child: const Text('View Profile'),
                ),
              if (onAssignments != null)
                TextButton(
                  key: const Key('rider-view-assignment'),
                  onPressed: onAssignments,
                  style: TextButton.styleFrom(foregroundColor: Colors.white),
                  child: const Text('View Assignment'),
                ),
              if (onActivity != null)
                TextButton(
                  key: const Key('rider-view-activity'),
                  onPressed: onActivity,
                  style: TextButton.styleFrom(foregroundColor: Colors.white),
                  child: const Text('Activity'),
                ),
              if (onCall != null)
                FilledButton(
                  key: const Key('rider-call'),
                  onPressed: onCall,
                  style: adminPrimaryButton().copyWith(
                    minimumSize: const WidgetStatePropertyAll(Size(0, 36)),
                  ),
                  child: const Text('Call'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

String _stops(RiderRecord rider) {
  if (rider.completedStops == null && rider.totalStops == null) return '';
  if (rider.completedStops != null && rider.totalStops != null) {
    return '${rider.completedStops} of ${rider.totalStops}';
  }
  return '${rider.completedStops ?? rider.totalStops}';
}

Widget _line(String label, String value) {
  if (value.isEmpty) return const SizedBox.shrink();
  return Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: adminType(12, FontWeight.w500, AdminTokens.promoMuted),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: adminType(13, FontWeight.w600, Colors.white),
          ),
        ),
      ],
    ),
  );
}

class _DirectoryCard extends StatelessWidget {
  const _DirectoryCard({
    required this.rider,
    required this.selected,
    required this.onTap,
  });

  final RiderRecord rider;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AdminTokens.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AdminTokens.primary : AdminTokens.line,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AdminTokens.primarySoft,
                child: Text(
                  rider.initials,
                  style: adminType(12, FontWeight.w700, AdminTokens.primary),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rider.fullName.isEmpty ? 'Unnamed rider' : rider.fullName,
                      style: adminType(
                        14,
                        FontWeight.w700,
                        AdminTokens.text,
                        height: 1.2,
                      ),
                    ),
                    Text(
                      [
                        rider.riderCode,
                        rider.routeName,
                      ].where((part) => part.isNotEmpty).join(' · '),
                      style: adminType(
                        12,
                        FontWeight.w500,
                        AdminTokens.textSecondary,
                        height: 1.3,
                      ),
                    ),
                    if (rider.completedStops != null ||
                        rider.totalStops != null)
                      Text(
                        _stops(rider),
                        style: adminType(
                          12,
                          FontWeight.w600,
                          AdminTokens.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              if (operationsDisplayText(rider.status) != null)
                Text(
                  operationsDisplayText(rider.status)!,
                  style: adminType(12, FontWeight.w700, AdminTokens.primary),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class LocationVerificationsSection extends StatelessWidget {
  const LocationVerificationsSection({
    required this.items,
    required this.failed,
    super.key,
  });

  final List<LocationVerification> items;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    return AdminSurface(
      key: const Key('location-verifications'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Location verifications',
            style: adminType(
              16,
              FontWeight.w700,
              AdminTokens.text,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          if (failed)
            Text(
              'Location verifications could not be loaded.',
              style: adminType(
                13.5,
                FontWeight.w600,
                AdminTokens.error,
                height: 1.4,
              ),
            )
          else if (items.isEmpty)
            const Text(
              'No location verifications are recorded.',
              key: Key('location-verifications-empty'),
              style: TextStyle(
                fontFamily: 'Noto Sans',
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: AdminTokens.textSecondary,
                height: 1.4,
              ),
            )
          else
            for (final item in items)
              if (_verificationLine(item) case final line?)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    line,
                    style: adminType(
                      13,
                      FontWeight.w600,
                      AdminTokens.text,
                      height: 1.35,
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

String? _activityLine(List<RiderActivityItem> activity, RiderRecord rider) {
  if (activity.isNotEmpty) {
    final title = operationsDisplayText(activity.first.title);
    final detail = operationsDisplayText(activity.first.detail);
    final text = [title, detail].whereType<String>().join(' — ');
    if (text.isNotEmpty) {
      final stamp = activity.first.occurredAt == null
          ? ''
          : ' · ${formatAdminStamp(activity.first.occurredAt!)}';
      return '$text$stamp';
    }
  }
  return operationsDisplayText(rider.lastActivity);
}

List<RiderExceptionItem> _visibleExceptions(List<RiderExceptionItem> items) {
  return [
    for (final item in items)
      if (operationsDisplayText(item.title) != null ||
          operationsDisplayText(item.detail) != null)
        item,
  ];
}

String? _verificationLine(LocationVerification item) {
  final parts = [
    operationsDisplayText(item.riderName),
    operationsDisplayText(item.outcome),
    operationsDisplayText(item.note),
    if (item.recordedAt != null) formatAdminStamp(item.recordedAt!),
  ].whereType<String>();
  if (parts.isEmpty) return null;
  return parts.join(' · ');
}
