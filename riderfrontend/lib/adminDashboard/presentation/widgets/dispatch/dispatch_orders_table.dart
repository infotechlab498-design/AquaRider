import 'package:flutter/material.dart';

import 'package:riderfrontend/adminDashboard/data/admin_format.dart';
import 'package:riderfrontend/adminDashboard/data/dispatch_models.dart';
import 'package:riderfrontend/adminDashboard/presentation/widgets/admin_shell.dart';
import 'package:riderfrontend/adminDashboard/theme/admin_tokens.dart';

class DispatchOrdersTable extends StatelessWidget {
  const DispatchOrdersTable({
    required this.counts,
    required this.countsFailed,
    required this.status,
    required this.onStatus,
    required this.search,
    required this.dateLabel,
    required this.onPickDate,
    required this.onClear,
    required this.rows,
    required this.ordersFailed,
    required this.selected,
    required this.onToggle,
    required this.onOpen,
    required this.openId,
    required this.pageLabel,
    required this.onPrevious,
    required this.onNext,
    required this.onClearSelection,
    required this.assignLabel,
    required this.onAssignRider,
    required this.onPrintManifest,
    required this.onExportSelected,
    this.loading = false,
    super.key,
  });

  final DispatchStatusCounts? counts;
  final bool countsFailed;
  final String status;
  final ValueChanged<String> onStatus;
  final TextEditingController search;
  final String dateLabel;
  final VoidCallback onPickDate;
  final VoidCallback onClear;
  final List<DispatchOrderRow> rows;
  final bool ordersFailed;
  final Map<String, num?> selected;
  final void Function(DispatchOrderRow row, bool selected) onToggle;
  final ValueChanged<String> onOpen;
  final String? openId;
  final String pageLabel;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback onClearSelection;
  final String assignLabel;
  final VoidCallback onAssignRider;
  final VoidCallback onPrintManifest;
  final VoidCallback onExportSelected;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final combined = combinedEstimatedValue(selected.values);
    return AdminSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final tab in dispatchStatusTabs)
                _StatusTab(
                  tab: tab,
                  count: countsFailed ? null : counts?.countFor(tab.value),
                  selected: status == tab.value,
                  onStatus: onStatus,
                ),
            ],
          ),
          if (countsFailed) ...[
            const SizedBox(height: 8),
            Text(
              'Status counts could not be loaded.',
              style: adminType(12.5, FontWeight.w600, AdminTokens.error),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 320,
                height: 40,
                child: TextField(
                  key: const Key('dispatch-search'),
                  controller: search,
                  style: adminType(13, FontWeight.w500, AdminTokens.text),
                  decoration: InputDecoration(
                    isDense: true,
                    prefixIcon: const Icon(Icons.search, size: 18),
                    hintText: 'Search order ID, customer or phone...',
                    hintStyle: adminType(13, FontWeight.w400, AdminTokens.border),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: _fieldBorder(),
                    enabledBorder: _fieldBorder(),
                  ),
                ),
              ),
              OutlinedButton.icon(
                key: const Key('dispatch-date'),
                onPressed: onPickDate,
                style: _filterButton(),
                icon: const Icon(Icons.calendar_today_outlined, size: 15),
                label: Text(dateLabel),
              ),
              const _FilterChip(label: 'All Zones'),
              const _FilterChip(label: 'All Riders'),
              const _FilterChip(label: 'All Statuses'),
              IconButton(
                key: const Key('dispatch-clear'),
                tooltip: 'Clear filters',
                onPressed: onClear,
                icon: const Icon(Icons.filter_alt_outlined, size: 18),
              ),
            ],
          ),
          if (selected.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              key: const Key('dispatch-bulk-bar'),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  Wrap(
                    spacing: 16,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        '${selected.length} ${selected.length == 1 ? 'order' : 'orders'} selected',
                        style: adminType(13, FontWeight.w700, Colors.white),
                      ),
                      Text(
                        combined == null
                            ? 'Estimated value was not returned for the selection.'
                            : 'Combined estimated value ${formatPkr(combined)}',
                        style: adminType(
                          13,
                          FontWeight.w600,
                          const Color(0xFFCBD5E1),
                        ),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _BulkAction(
                        buttonKey: const Key('dispatch-assign-rider'),
                        label: assignLabel,
                        filled: true,
                        onPressed: onAssignRider,
                      ),
                      _BulkAction(
                        buttonKey: const Key('dispatch-print-manifest'),
                        label: 'Print Manifest',
                        onPressed: onPrintManifest,
                      ),
                      _BulkAction(
                        buttonKey: const Key('dispatch-export-selected'),
                        label: 'Export Selected',
                        onPressed: onExportSelected,
                      ),
                      TextButton(
                        key: const Key('dispatch-clear-selection'),
                        onPressed: onClearSelection,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Clear selection'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          if (loading) ...[
            const SizedBox(height: 8),
            const LinearProgressIndicator(
              minHeight: 2,
              color: AdminTokens.primary,
            ),
          ],
          const SizedBox(height: 12),
          if (ordersFailed)
            const Text(
              'Orders could not be loaded.',
              style: TextStyle(
                fontFamily: 'Noto Sans',
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: AdminTokens.error,
                height: 1.4,
              ),
            )
          else if (rows.isEmpty)
            const Text(
              'No orders were returned.',
              key: Key('dispatch-orders-empty'),
              style: TextStyle(
                fontFamily: 'Noto Sans',
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: AdminTokens.textSecondary,
                height: 1.4,
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 860) {
                  return Column(
                    children: [
                      for (final row in rows) ...[
                        _OrderCard(
                          row: row,
                          selected: selected.containsKey(row.id),
                          opened: row.id == openId,
                          onToggle: (value) => onToggle(row, value),
                          onOpen: () => onOpen(row.id),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ],
                  );
                }
                return Column(
                  children: [
                    const _TableHeader(),
                    const Divider(height: 16, color: AdminTokens.line),
                    for (final row in rows)
                      _OrderLine(
                        row: row,
                        selected: selected.containsKey(row.id),
                        opened: row.id == openId,
                        onToggle: (value) => onToggle(row, value),
                        onOpen: () => onOpen(row.id),
                      ),
                  ],
                );
              },
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  pageLabel,
                  style: adminType(
                    12.5,
                    FontWeight.w600,
                    AdminTokens.textSecondary,
                  ),
                ),
              ),
              TextButton.icon(
                key: const Key('dispatch-prev'),
                onPressed: onPrevious,
                icon: const Icon(Icons.chevron_left, size: 18),
                label: const Text('Previous'),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                key: const Key('dispatch-next'),
                onPressed: onNext,
                iconAlignment: IconAlignment.end,
                label: const Text('Next'),
                icon: const Icon(Icons.chevron_right, size: 18),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

OutlineInputBorder _fieldBorder() {
  return OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: const BorderSide(color: AdminTokens.line),
  );
}

class _StatusTab extends StatelessWidget {
  const _StatusTab({
    required this.tab,
    required this.count,
    required this.selected,
    required this.onStatus,
  });

  final DispatchStatusTab tab;
  final int? count;
  final bool selected;
  final ValueChanged<String> onStatus;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? Colors.white : AdminTokens.textSecondary;
    return Material(
      color: selected ? AdminTokens.button : Colors.white,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        key: Key('dispatch-tab-${tab.value}'),
        onTap: () => onStatus(tab.value),
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? AdminTokens.button : AdminTokens.line,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                tab.label,
                style: adminType(12.5, FontWeight.w700, foreground),
              ),
              if (count != null) ...[
                const SizedBox(width: 6),
                Text(
                  '$count',
                  style: adminType(12.5, FontWeight.w700, foreground),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _BulkAction extends StatelessWidget {
  const _BulkAction({
    required this.label,
    required this.onPressed,
    this.filled = false,
    this.buttonKey,
  });

  final String label;
  final VoidCallback onPressed;
  final bool filled;
  final Key? buttonKey;

  @override
  Widget build(BuildContext context) {
    final style = TextButton.styleFrom(
      foregroundColor: filled ? Colors.white : const Color(0xFFE2E8F0),
      backgroundColor: filled ? AdminTokens.button : Colors.transparent,
      minimumSize: const Size(0, 32),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: filled ? AdminTokens.button : const Color(0xFF475569),
        ),
      ),
      textStyle: adminType(12, FontWeight.w700, Colors.white),
    );
    return TextButton(
      key: buttonKey,
      onPressed: onPressed,
      style: style,
      child: Text(label),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => showAdminNotice(
        context,
        '$label is not available as a separate filter yet.',
      ),
      style: _filterButton(),
      icon: const Icon(Icons.keyboard_arrow_down, size: 16),
      label: Text(label),
    );
  }
}

ButtonStyle _filterButton() {
  return OutlinedButton.styleFrom(
    foregroundColor: AdminTokens.text,
    backgroundColor: Colors.white,
    side: const BorderSide(color: AdminTokens.line),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    textStyle: adminType(13, FontWeight.w600, AdminTokens.text),
  );
}

class _TableHeader extends StatelessWidget {
  const _TableHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: 42),
        _head('Order ID', flex: 2),
        _head('Customer', flex: 2),
        _head('Delivery address', flex: 2),
        _head('Scheduled date', width: 108),
        _head('Time slot', width: 120),
        _head('Assigned rider', flex: 2),
        _head('Value (PKR)', width: 96),
        _head('Status', width: 112),
      ],
    );
  }
}

class _OrderLine extends StatelessWidget {
  const _OrderLine({
    required this.row,
    required this.selected,
    required this.opened,
    required this.onToggle,
    required this.onOpen,
  });

  final DispatchOrderRow row;
  final bool selected;
  final bool opened;
  final ValueChanged<bool> onToggle;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: opened ? AdminTokens.primarySoft : Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 42,
              child: Checkbox(
                key: Key('dispatch-select-${row.id}'),
                value: selected,
                onChanged: (value) => onToggle(value ?? false),
              ),
            ),
            Expanded(
              child: InkWell(
                key: Key('dispatch-order-${row.id}'),
                onTap: onOpen,
                child: Row(
                  children: [
                    _OrderIdentity(row: row),
                    _cell(_customer(row), flex: 2),
                    _cell(_blank(row.address), flex: 2),
                    _cell(
                      _blank(formatDispatchDate(row.scheduledDate)),
                      width: 108,
                    ),
                    _TimeSlot(label: row.timeWindow),
                    _RiderCell(row: row),
                    _cell(
                      row.estimatedValue == null
                          ? '—'
                          : formatPkr(row.estimatedValue!),
                      width: 96,
                    ),
                    _status(row.status, width: 112),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.row,
    required this.selected,
    required this.opened,
    required this.onToggle,
    required this.onOpen,
  });

  final DispatchOrderRow row;
  final bool selected;
  final bool opened;
  final ValueChanged<bool> onToggle;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: opened ? AdminTokens.primarySoft : AdminTokens.field,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: opened ? AdminTokens.primary : AdminTokens.line,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              key: Key('dispatch-select-${row.id}'),
              value: selected,
              onChanged: (value) => onToggle(value ?? false),
            ),
            Expanded(
              child: InkWell(
                key: Key('dispatch-order-${row.id}'),
                onTap: onOpen,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.displayReference,
                      style: adminType(14, FontWeight.w700, AdminTokens.text),
                    ),
                    Text(
                      _customer(row),
                      style: adminType(
                        13,
                        FontWeight.w600,
                        AdminTokens.textSecondary,
                      ),
                    ),
                    if (row.address.isNotEmpty)
                      Text(
                        row.address,
                        style: adminType(
                          12.5,
                          FontWeight.w500,
                          AdminTokens.textSecondary,
                          height: 1.3,
                        ),
                      ),
                    if (row.scheduledByRider)
                      Text(
                        'Scheduled by rider',
                        style: adminType(12, FontWeight.w700, AdminTokens.button),
                      ),
                    Text(
                      [
                        formatDispatchDate(row.scheduledDate),
                        row.timeWindow,
                        row.hasRider
                            ? (row.riderCode.isEmpty
                                ? row.riderName
                                : '${row.riderName} · ${row.riderCode}')
                            : 'Unassigned',
                        if (row.estimatedValue != null)
                          formatPkr(row.estimatedValue!),
                        if (row.status.isNotEmpty) row.status,
                      ].where((part) => part.isNotEmpty).join(' · '),
                      style: adminType(12.5, FontWeight.w600, AdminTokens.text),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _customer(DispatchOrderRow row) {
  if (row.customerName.isEmpty && row.customerCode.isEmpty) return '—';
  if (row.customerCode.isEmpty) return row.customerName;
  if (row.customerName.isEmpty) return row.customerCode;
  return '${row.customerName} · ${row.customerCode}';
}

String _blank(String value) => value.trim().isEmpty ? '—' : value.trim();

Widget _head(String label, {int? flex, double? width}) {
  final text = Text(
    label.toUpperCase(),
    style: adminType(
      11,
      FontWeight.w700,
      AdminTokens.textSecondary,
      letterSpacing: 0.4,
    ),
  );
  if (width != null) return SizedBox(width: width, child: text);
  return Expanded(flex: flex ?? 1, child: text);
}

Widget _cell(String value, {int? flex, double? width, bool strong = false}) {
  final text = Text(
    value,
    maxLines: 2,
    overflow: TextOverflow.ellipsis,
    style: adminType(
      12.5,
      strong ? FontWeight.w700 : FontWeight.w600,
      AdminTokens.text,
      height: 1.25,
    ),
  );
  if (width != null) return SizedBox(width: width, child: text);
  return Expanded(flex: flex ?? 1, child: text);
}

class _OrderIdentity extends StatelessWidget {
  const _OrderIdentity({required this.row});

  final DispatchOrderRow row;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            row.displayReference,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: adminType(12.5, FontWeight.w700, AdminTokens.text, height: 1.2),
          ),
          if (row.scheduledByRider)
            Text(
              'Scheduled by rider',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: adminType(11, FontWeight.w700, AdminTokens.button, height: 1.2),
            ),
          if (row.priority != null && row.priority!.trim().isNotEmpty)
            Text(
              row.priority!.trim(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: adminType(
                11,
                FontWeight.w600,
                AdminTokens.textSecondary,
                height: 1.2,
              ),
            ),
        ],
      ),
    );
  }
}

class _TimeSlot extends StatelessWidget {
  const _TimeSlot({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final text = label.trim().isEmpty ? '—' : label.trim();
    return SizedBox(
      width: 120,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AdminTokens.field,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: adminType(11.5, FontWeight.w600, AdminTokens.textSecondary),
          ),
        ),
      ),
    );
  }
}

class _RiderCell extends StatelessWidget {
  const _RiderCell({required this.row});

  final DispatchOrderRow row;

  @override
  Widget build(BuildContext context) {
    final assigned = row.hasRider;
    final name = assigned ? row.riderName : 'Unassigned';
    return Expanded(
      flex: 2,
      child: Row(
        children: [
          Icon(
            assigned ? Icons.person_outline : Icons.warning_amber_rounded,
            size: 16,
            color: assigned ? AdminTokens.button : const Color(0xFFB45309),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.trim().isEmpty ? 'Unassigned' : name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: adminType(12.5, FontWeight.w600, AdminTokens.text, height: 1.2),
                ),
                if (assigned && row.riderCode.trim().isNotEmpty)
                  Text(
                    row.riderCode.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: adminType(11, FontWeight.w600, AdminTokens.textSecondary, height: 1.2),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Widget _status(String status, {required double width}) {
  final label = status.trim().isEmpty ? '—' : status.trim();
  final color = _statusColor(status);
  return SizedBox(
    width: width,
    child: Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: adminType(11, FontWeight.w700, color, height: 1.2),
        ),
      ),
    ),
  );
}

Color _statusColor(String status) {
  final value = status.toLowerCase();
  if (value.contains('cancel')) return AdminTokens.error;
  if (value.contains('deliver') || value.contains('complete')) {
    return AdminTokens.success;
  }
  if (value.contains('progress')) return AdminTokens.warning;
  return AdminTokens.primary;
}
