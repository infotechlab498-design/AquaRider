import 'package:flutter/material.dart';

import 'package:riderfrontend/adminDashboard/data/admin_format.dart';
import 'package:riderfrontend/adminDashboard/data/dispatch_models.dart';
import 'package:riderfrontend/adminDashboard/presentation/widgets/dispatch/dispatch_manifest.dart';
import 'package:riderfrontend/adminDashboard/theme/admin_tokens.dart';

Future<void> showDispatchManifestPreview(
  BuildContext context, {
  required List<DispatchManifestSheet> sheets,
  required String dateLabel,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => _ManifestPreview(sheets: sheets, dateLabel: dateLabel),
  );
}

class _ManifestPreview extends StatefulWidget {
  const _ManifestPreview({required this.sheets, required this.dateLabel});

  final List<DispatchManifestSheet> sheets;
  final String dateLabel;

  @override
  State<_ManifestPreview> createState() => _ManifestPreviewState();
}

class _ManifestPreviewState extends State<_ManifestPreview> {
  var _busy = false;
  String? _error;

  Future<void> _send({required bool download}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final bytes = await buildDispatchManifestPdf(
        widget.sheets,
        dateLabel: widget.dateLabel,
      );
      final filename = dispatchManifestFilename(widget.dateLabel);
      if (download) {
        await DispatchManifestPublisher.current.download(bytes, filename);
      } else {
        await DispatchManifestPublisher.current.openForPrint(bytes, filename);
      }
      if (!mounted) return;
      setState(() => _busy = false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.toString().replaceFirst('Exception: ', '').trim();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.sheets.length;
    return Dialog(
      key: const Key('dispatch-manifest-preview'),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 720),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Delivery manifest',
                          style: adminType(16, FontWeight.w700, Colors.white),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _heading(count, widget.dateLabel),
                          style: adminType(12.5, FontWeight.w600, const Color(0xFFCBD5E1)),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    key: const Key('dispatch-manifest-print'),
                    onPressed: _busy ? null : () => _send(download: false),
                    style: TextButton.styleFrom(foregroundColor: Colors.white),
                    child: const Text('Print'),
                  ),
                  const SizedBox(width: 4),
                  FilledButton(
                    key: const Key('dispatch-manifest-download'),
                    onPressed: _busy ? null : () => _send(download: true),
                    style: FilledButton.styleFrom(
                      backgroundColor: AdminTokens.button,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 36),
                    ),
                    child: const Text('Download PDF'),
                  ),
                  IconButton(
                    key: const Key('dispatch-manifest-close'),
                    tooltip: 'Close',
                    onPressed: _busy ? null : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _error!,
                    style: adminType(12.5, FontWeight.w600, const Color(0xFFFECACA)),
                  ),
                ),
              ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
                  children: [
                    for (final sheet in widget.sheets) _SheetView(sheet: sheet),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _heading(int count, String dateLabel) {
    final orders = count == 1 ? '1 order' : '$count orders';
    if (dateLabel.trim().isEmpty) return orders;
    return '$dateLabel · $orders';
  }
}

class _SheetView extends StatelessWidget {
  const _SheetView({required this.sheet});

  final DispatchManifestSheet sheet;

  @override
  Widget build(BuildContext context) {
    final order = sheet.order;
    final rider = order.hasRider
        ? [order.riderName, order.riderCode].where((part) => part.trim().isNotEmpty).join(' · ')
        : 'Unassigned';
    final error = sheet.linesError?.trim();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AdminTokens.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  order.displayReference,
                  style: adminType(14, FontWeight.w700, AdminTokens.text),
                ),
              ),
              Text(order.status, style: adminType(12, FontWeight.w700, AdminTokens.button)),
            ],
          ),
          const SizedBox(height: 4),
          Text(_customer(order), style: adminType(13, FontWeight.w600, AdminTokens.text)),
          if (order.address.trim().isNotEmpty)
            Text(order.address, style: adminType(12.5, FontWeight.w500, AdminTokens.textSecondary)),
          Text(
            [
              formatDispatchDate(order.scheduledDate),
              order.timeWindow,
              rider,
              if (order.estimatedValue != null) formatPkr(order.estimatedValue!),
            ].where((part) => part.trim().isNotEmpty).join(' · '),
            style: adminType(12.5, FontWeight.w600, AdminTokens.text),
          ),
          const SizedBox(height: 8),
          if (error != null && error.isNotEmpty)
            Text(error, style: adminType(12.5, FontWeight.w600, AdminTokens.error))
          else if (sheet.lines.isEmpty)
            Text(
              'No lines were returned.',
              style: adminType(12.5, FontWeight.w600, AdminTokens.textSecondary),
            )
          else
            for (final line in sheet.lines)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  [
                    line.name,
                    if (line.sku.isNotEmpty) line.sku,
                    if (line.quantity != null) 'x ${line.quantity}',
                    if (line.lineTotal != null) formatPkr(line.lineTotal!),
                  ].join(' · '),
                  style: adminType(12.5, FontWeight.w600, AdminTokens.text),
                ),
              ),
        ],
      ),
    );
  }

  String _customer(DispatchOrderRow order) {
    final name = order.customerName.trim();
    final code = order.customerCode.trim();
    if (name.isEmpty) return code;
    if (code.isEmpty) return name;
    return '$name · $code';
  }
}
