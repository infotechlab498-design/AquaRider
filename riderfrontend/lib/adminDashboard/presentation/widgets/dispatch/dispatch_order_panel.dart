import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:riderfrontend/api/office_document.dart';
import 'package:riderfrontend/api/route_api.dart';

import 'package:riderfrontend/adminDashboard/data/admin_format.dart';
import 'package:riderfrontend/adminDashboard/data/admin_json.dart';
import 'package:riderfrontend/adminDashboard/theme/admin_tokens.dart';

class DispatchOrderPanel extends StatelessWidget {
  const DispatchOrderPanel({
    required this.reference,
    required this.onClose,
    required this.loading,
    required this.onCancel,
    required this.onReassign,
    required this.onPreparePickList,
    this.fullscreen = false,
    this.orderId = '',
    this.customerName = '',
    this.customerCode = '',
    this.address = '',
    this.scheduledDate = '',
    this.timeWindow = '',
    this.riderName = '',
    this.riderCode = '',
    this.scheduledByRider = false,
    this.vehicleName = '',
    this.phone = '',
    this.status = '',
    this.estimatedValue,
    this.notes,
    this.detailError,
    this.items = const [],
    this.itemsError,
    this.events = const [],
    this.eventsError,
    this.pickLines = const [],
    this.pickMessage,
    this.pickError,
    this.pickBusy = false,
    this.closed = false,
    super.key,
  });

  final String reference;
  final String orderId;
  final VoidCallback onClose;
  final bool loading;
  final bool fullscreen;
  final String customerName;
  final String customerCode;
  final String address;
  final String scheduledDate;
  final String timeWindow;
  final String riderName;
  final String riderCode;
  final bool scheduledByRider;
  final String vehicleName;
  final String phone;
  final String status;
  final num? estimatedValue;
  final String? notes;
  final String? detailError;
  final List<DispatchOrderItem> items;
  final String? itemsError;
  final List<DispatchLifecycleEvent> events;
  final String? eventsError;
  final List<DispatchOrderItem> pickLines;
  final String? pickMessage;
  final String? pickError;
  final bool pickBusy;
  final bool closed;
  final VoidCallback? onCancel;
  final VoidCallback? onReassign;
  final VoidCallback? onPreparePickList;

  @override
  Widget build(BuildContext context) {
    final note = operationsDisplayText(notes);
    final when = [
      formatDispatchDate(scheduledDate),
      timeWindow.trim(),
    ].where((part) => part.isNotEmpty).join(' · ');
    return Material(
      key: const Key('dispatch-order-drawer'),
      color: const Color(0xFFF8FAFC),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Color(0x1A0F172A),
              blurRadius: 24,
              offset: Offset(-8, 0),
                ),
            ],
          ),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
            _DrawerHeader(
              reference: reference,
              orderId: orderId,
              status: status,
              when: when,
              fullscreen: fullscreen,
              onClose: onClose,
            ),
          if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(
                child: CircularProgressIndicator(color: AdminTokens.primary),
              ),
            )
          else ...[
            if (detailError != null)
              Text(
                detailError!,
                style: adminType(
                  13.5,
                  FontWeight.w600,
                  AdminTokens.error,
                  height: 1.4,
                ),
              )
            else ...[
                const SizedBox(height: 8),
                _CustomerCard(
                  name: customerName,
                  code: customerCode,
                  address: address,
                  timeWindow: _windowLine(scheduledDate, timeWindow),
                  phone: phone,
                ),
                const SizedBox(height: 12),
                _RiderCard(
                  name: riderName,
                  code: riderCode,
                  vehicleName: vehicleName,
                  scheduledByRider: scheduledByRider,
                  onReassign: closed ? null : onReassign,
                ),
                const SizedBox(height: 12),
                _NoteCard(note: note),
              ],
              const SizedBox(height: 16),
              _Manifest(items: items, error: itemsError),
              if (!loading && !closed) ...[
                const SizedBox(height: 14),
                _ActionBar(
                  onCancel: onCancel,
                  onReassign: onReassign,
                  onPreparePickList: onPreparePickList,
                  pickBusy: pickBusy,
                ),
              ],
              if (estimatedValue != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Estimated order value ${formatPkr(estimatedValue!)} is not collected revenue. Reconciliation occurs upon doorstep bill generation.',
                  style: adminType(
                    11.5,
                    FontWeight.w500,
                    AdminTokens.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
              if (pickError != null) ...[
                const SizedBox(height: 8),
                Text(
                  pickError!,
                  key: const Key('dispatch-picklist-error'),
                  style: adminType(
                    13,
                    FontWeight.w600,
                    AdminTokens.error,
                    height: 1.4,
                  ),
                ),
              ],
              if (pickMessage != null && pickMessage != pickError) ...[
                const SizedBox(height: 4),
                Text(
                  pickMessage!,
                  style: adminType(13, FontWeight.w600, AdminTokens.text),
                ),
              ],
              if (pickLines.isEmpty && pickError == null && pickMessage == null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'No pick-list lines were returned.',
                    style: adminType(
                      13,
                      FontWeight.w600,
                      AdminTokens.textSecondary,
                      height: 1.4,
                    ),
                  ),
                )
              else
                for (final item in pickLines) _PickLine(item: item),
              const SizedBox(height: 18),
              _Lifecycle(events: events, error: eventsError),
            ],
          ],
        ),
      ),
    );
  }
}

class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader({
    required this.reference,
    required this.orderId,
    required this.status,
    required this.when,
    required this.fullscreen,
    required this.onClose,
  });

  final String reference;
  final String orderId;
  final String status;
  final String when;
  final bool fullscreen;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconButton(
          key: const Key('dispatch-drawer-close'),
          tooltip: fullscreen ? 'Back to orders' : 'Close',
          onPressed: onClose,
          icon: Icon(fullscreen ? Icons.arrow_back : Icons.close, size: 18),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      reference,
                      style: adminType(16, FontWeight.w700, AdminTokens.text),
                    ),
                    if (status.trim().isNotEmpty) _StatusPill(status: status),
                  ],
                ),
                if (when.isNotEmpty)
                  Text(
                    when,
                    style: adminType(
                      12,
                      FontWeight.w500,
                      AdminTokens.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
        ),
        IconButton(
          tooltip: 'Print',
          onPressed: orderId.isEmpty
              ? null
              : () async {
                  try {
                    await shareOfficeDocument(await ApiScope.of(context).orderPdf(orderId));
                  } on ApiException catch (error) {
                    if (context.mounted) showAdminNotice(context, error.message);
                  }
                },
          icon: const Icon(Icons.print_outlined, size: 18),
        ),
        IconButton(
          tooltip: 'Export CSV',
          onPressed: orderId.isEmpty
              ? null
              : () async {
                  try {
                    await shareOfficeDocument(await ApiScope.of(context).orderCsv(orderId));
                  } on ApiException catch (error) {
                    if (context.mounted) showAdminNotice(context, error.message);
                  }
                },
          icon: const Icon(Icons.table_chart_outlined, size: 18),
        ),
        IconButton(
          tooltip: 'More',
          onPressed: () => showAdminNotice(
            context,
            'More order actions are not available yet.',
          ),
          icon: const Icon(Icons.more_vert, size: 18),
        ),
      ],
    );
  }
}

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({
    required this.name,
    required this.code,
    required this.address,
    required this.timeWindow,
    required this.phone,
  });

  final String name;
  final String code;
  final String address;
  final String timeWindow;
  final String phone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F8FC),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AdminTokens.button,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.storefront, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.trim().isEmpty ? 'Customer' : name.trim(),
                      style: adminType(15, FontWeight.w700, AdminTokens.text),
                    ),
                    if (code.trim().isNotEmpty)
                      Text(
                        'Customer ID: ${code.trim()}',
                        style: adminType(
                          12,
                          FontWeight.w500,
                          AdminTokens.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _call(context, phone),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AdminTokens.button,
                  minimumSize: const Size(0, 34),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  side: const BorderSide(color: Color(0xFFD6E4F5)),
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.call_outlined, size: 14),
                label: const Text('Call'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _meta(
                  'Delivery Address',
                  address.trim().isEmpty ? '—' : address.trim(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: _meta('Time Slot Window', timeWindow)),
            ],
          ),
        ],
      ),
    );
  }
}

class _RiderCard extends StatelessWidget {
  const _RiderCard({
    required this.name,
    required this.code,
    required this.vehicleName,
    required this.scheduledByRider,
    required this.onReassign,
  });

  final String name;
  final String code;
  final String vehicleName;
  final bool scheduledByRider;
  final VoidCallback? onReassign;

  @override
  Widget build(BuildContext context) {
    final assigned = name.trim().isNotEmpty;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminTokens.line),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: const Color(0xFFE8EEF5),
            child: Text(
              _initials(assigned ? name : 'U'),
              style: adminType(11, FontWeight.w700, AdminTokens.secondary),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      assigned ? name.trim() : 'Unassigned',
                      style: adminType(14, FontWeight.w700, AdminTokens.text),
                    ),
                    if (code.trim().isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AdminTokens.primarySoft,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          code.trim(),
                          style: adminType(
                            11,
                            FontWeight.w700,
                            AdminTokens.button,
                          ),
                        ),
                      ),
                  ],
                ),
                if (scheduledByRider)
                  Text(
                    'Scheduled by this rider',
                    style: adminType(12, FontWeight.w700, AdminTokens.button),
                  ),
                if (vehicleName.trim().isNotEmpty)
              Text(
                    vehicleName.trim(),
                    style: adminType(
                      12,
                      FontWeight.w500,
                      AdminTokens.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          if (onReassign != null)
            TextButton.icon(
              key: const Key('dispatch-reassign'),
              onPressed: onReassign,
              style: TextButton.styleFrom(
                foregroundColor: AdminTokens.button,
                minimumSize: const Size(0, 32),
              ),
              icon: const Icon(Icons.swap_horiz, size: 16),
              label: const Text('Reassign'),
            ),
        ],
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.note});

  final String? note;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DISPATCHER NOTE',
            style: adminType(
              11,
              FontWeight.w700,
              const Color(0xFF8A4B00),
              letterSpacing: 0.4,
            ),
              ),
              const SizedBox(height: 4),
              Text(
                note ?? 'No dispatcher note was returned.',
                style: adminType(
                  13.5,
                  FontWeight.w600,
                  note == null ? AdminTokens.textSecondary : AdminTokens.text,
                  height: 1.4,
                ),
              ),
            ],
      ),
    );
  }
}

class _Manifest extends StatelessWidget {
  const _Manifest({required this.items, required this.error});

  final List<DispatchOrderItem> items;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final units = items.fold<int>(0, (sum, item) => sum + (item.quantity ?? 0));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Order Manifest Items (${items.length} SKUs)',
                style: adminType(15, FontWeight.w700, AdminTokens.text),
              ),
            ),
            if (items.isNotEmpty)
              Text(
                'Units: $units Total',
                style: adminType(12, FontWeight.w600, AdminTokens.textSecondary),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (error != null)
          Text(
            error!,
                style: adminType(13, FontWeight.w600, AdminTokens.error),
              )
            else if (items.isEmpty)
              Text(
                'No order lines were returned.',
                style: adminType(
                  13,
                  FontWeight.w600,
                  AdminTokens.textSecondary,
                  height: 1.4,
                ),
              )
            else
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: AdminTokens.line),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                const _ManifestHeader(),
                for (var i = 0; i < items.length; i++)
                  _ManifestRow(item: items[i], shaded: i.isOdd),
              ],
            ),
          ),
      ],
    );
  }
}

class _ManifestHeader extends StatelessWidget {
  const _ManifestHeader();

  @override
  Widget build(BuildContext context) {
    final style = adminType(
      10,
      FontWeight.w700,
      AdminTokens.textSecondary,
      letterSpacing: 0.3,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          Expanded(flex: 4, child: Text('ITEM DESCRIPTION', style: style)),
          Expanded(flex: 2, child: Text('QTY', style: style)),
          Expanded(flex: 2, child: Text('UNIT PRICE', style: style)),
          Expanded(flex: 2, child: Text('SUBTOTAL', style: style)),
        ],
      ),
    );
  }
}

class _ManifestRow extends StatelessWidget {
  const _ManifestRow({required this.item, required this.shaded});

  final DispatchOrderItem item;
  final bool shaded;

  @override
  Widget build(BuildContext context) {
    final title = item.name.isNotEmpty ? item.name : item.sku;
    final qty = item.quantity == null
        ? '—'
        : '${item.quantity}${item.unit.isEmpty ? '' : ' ${item.unit}'}';
    return ColoredBox(
      color: shaded ? const Color(0xFFF8FAFC) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: adminType(13, FontWeight.w700, AdminTokens.text),
                  ),
                  if (item.sku.isNotEmpty && item.name.isNotEmpty)
              Text(
                      'SKU: ${item.sku}',
                style: adminType(
                        11,
                        FontWeight.w500,
                        AdminTokens.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                qty,
                style: adminType(12, FontWeight.w600, AdminTokens.text),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                item.unitPrice == null ? '—' : formatPkr(item.unitPrice!),
                style: adminType(12, FontWeight.w600, AdminTokens.text),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                item.lineTotal == null ? '—' : formatPkr(item.lineTotal!),
                style: adminType(12, FontWeight.w700, AdminTokens.text),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.onCancel,
    required this.onReassign,
    required this.onPreparePickList,
    required this.pickBusy,
  });

  final VoidCallback? onCancel;
  final VoidCallback? onReassign;
  final VoidCallback? onPreparePickList;
  final bool pickBusy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F7FB),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          OutlinedButton.icon(
            key: const Key('dispatch-cancel'),
            onPressed: onCancel,
            style: OutlinedButton.styleFrom(
              foregroundColor: AdminTokens.error,
              minimumSize: const Size(0, 40),
              side: const BorderSide(color: Color(0xFFF3C7C7)),
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: const Icon(Icons.cancel_outlined, size: 16),
            label: const Text('Cancel Order'),
          ),
          OutlinedButton.icon(
            key: const Key('dispatch-prepare-picklist'),
            onPressed: pickBusy ? null : onPreparePickList,
            style: OutlinedButton.styleFrom(
              foregroundColor: AdminTokens.text,
              backgroundColor: Colors.white,
              minimumSize: const Size(0, 40),
              side: const BorderSide(color: AdminTokens.line),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: const Icon(Icons.inventory_2_outlined, size: 16),
            label: Text(pickBusy ? 'Preparing…' : 'Pick-list'),
          ),
          FilledButton.icon(
            onPressed: onReassign,
            style: FilledButton.styleFrom(
              backgroundColor: AdminTokens.button,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 40),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: const Icon(Icons.swap_horiz, size: 16),
            label: const Text('Reassign Rider'),
          ),
        ],
      ),
    );
  }
}

class _Lifecycle extends StatelessWidget {
  const _Lifecycle({required this.events, required this.error});

  final List<DispatchLifecycleEvent> events;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
              Text(
          'Dispatch Lifecycle',
          style: adminType(16, FontWeight.w700, AdminTokens.text),
        ),
        const SizedBox(height: 10),
        if (error != null)
              Text(
            error!,
                style: adminType(13, FontWeight.w600, AdminTokens.error),
              )
            else if (events.isEmpty)
              Text(
                'No lifecycle events were returned.',
                style: adminType(
                  13,
                  FontWeight.w600,
                  AdminTokens.textSecondary,
                  height: 1.4,
                ),
              )
            else
          for (var i = 0; i < events.length; i++)
            _LifecycleStep(event: events[i], last: i == events.length - 1),
      ],
    );
  }
}

class _LifecycleStep extends StatelessWidget {
  const _LifecycleStep({required this.event, required this.last});

  final DispatchLifecycleEvent event;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final title =
        operationsDisplayText(event.title) ??
        operationsDisplayText(event.detail) ??
        'Event';
    final detail = operationsDisplayText(event.detail);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 18,
            child: Column(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: const BoxDecoration(
                    color: AdminTokens.secondary,
                    shape: BoxShape.circle,
                  ),
                ),
                if (!last)
                  Container(
                    width: 2,
                    height: 28,
                    color: const Color(0xFFD8E0EA),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                  title,
                        style: adminType(13.5, FontWeight.w700, AdminTokens.text),
                      ),
                if (event.occurredAt != null ||
                    (detail != null && detail != title))
                        Text(
                    [
                      if (event.occurredAt != null)
                        formatAdminStamp(event.occurredAt!),
                      if (detail != null && detail != title) detail,
                    ].join(' · '),
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
        ],
      ),
    );
  }
}

class _PickLine extends StatelessWidget {
  const _PickLine({required this.item});

  final DispatchOrderItem item;

  @override
  Widget build(BuildContext context) {
    final title = item.name.isNotEmpty ? item.name : item.sku;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        title,
        style: adminType(13, FontWeight.w600, AdminTokens.text),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.trim(),
        style: adminType(11, FontWeight.w700, color),
    ),
  );
}
}

Widget _meta(String label, String value) {
  return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
        label,
        style: adminType(11, FontWeight.w600, AdminTokens.textSecondary),
        ),
      const SizedBox(height: 2),
          Text(
        value.trim().isEmpty ? '—' : value.trim(),
        style: adminType(13, FontWeight.w700, AdminTokens.text, height: 1.3),
      ),
    ],
  );
}

String _windowLine(String date, String window) {
  final parts = [
    formatDispatchDate(date),
    window.trim(),
  ].where((part) => part.isNotEmpty);
  final text = parts.join(' · ');
  return text.isEmpty ? '—' : text;
}

String _initials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .take(2);
  final letters = parts.map((part) => part[0].toUpperCase()).join();
  return letters.isEmpty ? '?' : letters;
}

Future<void> _call(BuildContext context, String phone) async {
  final number = phone.trim();
  if (number.isEmpty) {
    showAdminNotice(context, 'No phone number was returned for this customer.');
    return;
  }
  final uri = Uri(scheme: 'tel', path: number);
  if (!await launchUrl(uri)) {
    if (!context.mounted) return;
    showAdminNotice(context, 'This device could not start a call.');
  }
}

Color _statusColor(String status) {
  final value = status.toLowerCase();
  if (value.contains('cancel')) return AdminTokens.error;
  if (value.contains('deliver') || value.contains('complete')) {
    return AdminTokens.success;
  }
  if (value.contains('progress')) return const Color(0xFFB45309);
  return AdminTokens.button;
}
