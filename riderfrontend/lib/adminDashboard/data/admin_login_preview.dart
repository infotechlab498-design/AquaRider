import 'package:riderfrontend/adminDashboard/data/admin_json.dart';

class AdminLoginPreview {
  const AdminLoginPreview({
    this.operationalDate = '',
    this.todaysBilledSales = 0,
    this.previousBilledSales,
    this.billedChangePercent,
    this.cashReconciled = 0,
    this.dropsBalanced = 0,
    this.dropsTotal = 0,
    this.scopeNote = '',
  });

  final String operationalDate;
  final num todaysBilledSales;
  final num? previousBilledSales;
  final num? billedChangePercent;
  final num cashReconciled;
  final int dropsBalanced;
  final int dropsTotal;
  final String scopeNote;

  factory AdminLoginPreview.fromJson(Object? data) {
    final map = jsonMap(data) ?? const <String, dynamic>{};
    return AdminLoginPreview(
      operationalDate: jsonString(map, const ['operationalDate']) ?? '',
      todaysBilledSales: optionalNum(map, const ['todaysBilledSales']) ?? 0,
      previousBilledSales: optionalNum(map, const ['previousBilledSales']),
      billedChangePercent: optionalNum(map, const ['billedChangePercent']),
      cashReconciled: optionalNum(map, const ['cashReconciled']) ?? 0,
      dropsBalanced: optionalInt(map, const ['dropsBalanced']) ?? 0,
      dropsTotal: optionalInt(map, const ['dropsTotal']) ?? 0,
      scopeNote: jsonString(map, const ['scopeNote']) ?? '',
    );
  }
}
