import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:riderfrontend/adminDashboard/data/admin_format.dart';
import 'package:riderfrontend/adminDashboard/data/dispatch_models.dart';
import 'package:riderfrontend/adminDashboard/presentation/widgets/dispatch/dispatch_manifest_save.dart';

class DispatchManifestSheet {
  const DispatchManifestSheet({
    required this.order,
    this.lines = const [],
    this.linesError,
  });

  final DispatchOrderRow order;
  final List<DispatchOrderItem> lines;
  final String? linesError;
}

class DispatchManifestPublisher {
  DispatchManifestPublisher();

  static DispatchManifestPublisher current = DispatchManifestPublisher();

  Future<void> download(Uint8List bytes, String filename) {
    return deliverDispatchManifest(bytes, filename, download: true);
  }

  Future<void> openForPrint(Uint8List bytes, String filename) {
    return deliverDispatchManifest(bytes, filename, download: false);
  }
}

String dispatchManifestFilename(String dateLabel) {
  final stamp = dateLabel.trim().isEmpty
      ? 'selected'
      : dateLabel.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
  return 'dispatch-manifest-$stamp.pdf';
}

Future<Uint8List> buildDispatchManifestPdf(
  List<DispatchManifestSheet> sheets, {
  required String dateLabel,
}) {
  final document = pw.Document();
  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 32),
      footer: (context) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          'Page ${context.pageNumber} of ${context.pagesCount}',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
        ),
      ),
      build: (context) => [
        pw.Text(
          'Delivery manifest',
          style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          _manifestHeading(sheets.length, dateLabel),
          style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 14),
        for (final sheet in sheets) _sheet(sheet),
      ],
    ),
  );
  return document.save();
}

String _manifestHeading(int count, String dateLabel) {
  final orders = count == 1 ? '1 order' : '$count orders';
  if (dateLabel.trim().isEmpty) return orders;
  return '$dateLabel - $orders';
}

String _joinParts(Iterable<String> parts) =>
    parts.map((part) => part.trim()).where((part) => part.isNotEmpty).join(' - ');

pw.Widget _sheet(DispatchManifestSheet sheet) {
  final order = sheet.order;
  final rider = order.hasRider
      ? _joinParts([order.riderName, order.riderCode])
      : 'Unassigned';
  return pw.Container(
    margin: const pw.EdgeInsets.only(bottom: 12),
    padding: const pw.EdgeInsets.all(10),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: PdfColors.grey400, width: 0.6),
      borderRadius: pw.BorderRadius.circular(4),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              order.displayReference,
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(order.status, style: const pw.TextStyle(fontSize: 10)),
          ],
        ),
        pw.SizedBox(height: 4),
        pw.Text(_customer(order), style: const pw.TextStyle(fontSize: 11)),
        if (order.address.trim().isNotEmpty)
          pw.Text(order.address, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800)),
        pw.Text(
          [
            formatDispatchDate(order.scheduledDate),
            order.timeWindow,
            rider,
            if (order.estimatedValue != null) formatPkr(order.estimatedValue!),
          ].where((part) => part.trim().isNotEmpty).join(' - '),
          style: const pw.TextStyle(fontSize: 10),
        ),
        pw.SizedBox(height: 8),
        _lines(sheet),
      ],
    ),
  );
}

String _customer(DispatchOrderRow order) {
  final name = order.customerName.trim();
  final code = order.customerCode.trim();
  if (name.isEmpty) return code;
  if (code.isEmpty) return name;
  return '$name - $code';
}

pw.Widget _lines(DispatchManifestSheet sheet) {
  final error = sheet.linesError?.trim();
  if (error != null && error.isNotEmpty) {
    return pw.Text(error, style: const pw.TextStyle(fontSize: 10, color: PdfColors.red800));
  }
  if (sheet.lines.isEmpty) {
    return pw.Text(
      'No lines were returned.',
      style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
    );
  }
  return pw.Table(
    border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.4),
    columnWidths: const {
      0: pw.FlexColumnWidth(4),
      1: pw.FlexColumnWidth(2),
      2: pw.FlexColumnWidth(1.2),
      3: pw.FlexColumnWidth(1.6),
    },
    children: [
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey200),
        children: [
          _cell('Product', bold: true),
          _cell('SKU', bold: true),
          _cell('Qty', bold: true),
          _cell('Amount', bold: true),
        ],
      ),
      for (final line in sheet.lines)
        pw.TableRow(
          children: [
            _cell(line.name),
            _cell(line.sku),
            _cell(line.quantity == null ? '' : '${line.quantity}'),
            _cell(line.lineTotal == null ? '' : formatPkr(line.lineTotal!)),
          ],
        ),
    ],
  );
}

pw.Widget _cell(String text, {bool bold = false}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
    child: pw.Text(
      text,
      style: pw.TextStyle(
        fontSize: 9,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      ),
    ),
  );
}
