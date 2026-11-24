import 'package:riderfrontend/adminDashboard/data/admin_json.dart';

class AdminReportSeriesPoint {
  const AdminReportSeriesPoint({required this.day, this.amount = 0});

  final String day;
  final num amount;

  factory AdminReportSeriesPoint.fromJson(Object? data) {
    final map = jsonMap(data) ?? const <String, dynamic>{};
    return AdminReportSeriesPoint(
      day: jsonString(map, const ['day']) ?? '',
      amount: optionalNum(map, const ['amount']) ?? 0,
    );
  }
}

class AdminFulfillmentSlice {
  const AdminFulfillmentSlice({
    this.label = '',
    this.count = 0,
    this.percent = 0,
  });

  final String label;
  final int count;
  final num percent;

  factory AdminFulfillmentSlice.fromJson(Object? data) {
    final map = jsonMap(data) ?? const <String, dynamic>{};
    return AdminFulfillmentSlice(
      label: jsonString(map, const ['label']) ?? '',
      count: optionalInt(map, const ['count']) ?? 0,
      percent: optionalNum(map, const ['percent']) ?? 0,
    );
  }
}

class AdminRiderProductivity {
  const AdminRiderProductivity({
    required this.riderId,
    this.riderName = '',
    this.routeName,
    this.recoveryAmount = 0,
    this.stopsCompleted = 0,
    this.onTimePercent,
  });

  final String riderId;
  final String riderName;
  final String? routeName;
  final num recoveryAmount;
  final int stopsCompleted;
  final num? onTimePercent;

  factory AdminRiderProductivity.fromJson(Object? data) {
    final map = jsonMap(data) ?? const <String, dynamic>{};
    return AdminRiderProductivity(
      riderId: jsonString(map, const ['riderId']) ?? '',
      riderName: jsonString(map, const ['riderName']) ?? '',
      routeName: jsonString(map, const ['routeName']),
      recoveryAmount: optionalNum(map, const ['recoveryAmount']) ?? 0,
      stopsCompleted: optionalInt(map, const ['stopsCompleted']) ?? 0,
      onTimePercent: optionalNum(map, const ['onTimePercent']),
    );
  }
}

class AdminAssetCirculation {
  const AdminAssetCirculation({
    this.issued = 0,
    this.recovered = 0,
    this.storeFloat = 0,
    this.scrap = 0,
    this.clearedPercent = 0,
  });

  final int issued;
  final int recovered;
  final int storeFloat;
  final int scrap;
  final num clearedPercent;

  factory AdminAssetCirculation.fromJson(Object? data) {
    final map = jsonMap(data) ?? const <String, dynamic>{};
    return AdminAssetCirculation(
      issued: optionalInt(map, const ['issued']) ?? 0,
      recovered: optionalInt(map, const ['recovered']) ?? 0,
      storeFloat: optionalInt(map, const ['storeFloat']) ?? 0,
      scrap: optionalInt(map, const ['scrap']) ?? 0,
      clearedPercent: optionalNum(map, const ['clearedPercent']) ?? 0,
    );
  }
}

class AdminReportsSummary {
  const AdminReportsSummary({
    this.from = '',
    this.to = '',
    this.totalRealizedSales = 0,
    this.salesChangePercent,
    this.collectionsReceived = 0,
    this.recoveryRatePercent,
    this.receivablesFloat = 0,
    this.receivableAccounts = 0,
    this.averageReceivableAgeDays,
    this.completedDrops = 0,
    this.firstAttemptSlaPercent,
    this.customerVisits = 0,
    this.fleetCouriers = 0,
    this.shiftAttendancePercent,
    this.salesSeries = const [],
    this.collectionsSeries = const [],
    this.fulfillment = const [],
    this.riderLeaderboard = const [],
    this.assetCirculation = const AdminAssetCirculation(),
    this.scopeNote = '',
  });

  final String from;
  final String to;
  final num totalRealizedSales;
  final num? salesChangePercent;
  final num collectionsReceived;
  final num? recoveryRatePercent;
  final num receivablesFloat;
  final int receivableAccounts;
  final num? averageReceivableAgeDays;
  final int completedDrops;
  final num? firstAttemptSlaPercent;
  final int customerVisits;
  final int fleetCouriers;
  final num? shiftAttendancePercent;
  final List<AdminReportSeriesPoint> salesSeries;
  final List<AdminReportSeriesPoint> collectionsSeries;
  final List<AdminFulfillmentSlice> fulfillment;
  final List<AdminRiderProductivity> riderLeaderboard;
  final AdminAssetCirculation assetCirculation;
  final String scopeNote;

  factory AdminReportsSummary.fromJson(Object? data) {
    final map = jsonMap(data) ?? const <String, dynamic>{};
    return AdminReportsSummary(
      from: jsonString(map, const ['from']) ?? '',
      to: jsonString(map, const ['to']) ?? '',
      totalRealizedSales: optionalNum(map, const ['totalRealizedSales']) ?? 0,
      salesChangePercent: optionalNum(map, const ['salesChangePercent']),
      collectionsReceived: optionalNum(map, const ['collectionsReceived']) ?? 0,
      recoveryRatePercent: optionalNum(map, const ['recoveryRatePercent']),
      receivablesFloat: optionalNum(map, const ['receivablesFloat']) ?? 0,
      receivableAccounts: optionalInt(map, const ['receivableAccounts']) ?? 0,
      averageReceivableAgeDays:
          optionalNum(map, const ['averageReceivableAgeDays']),
      completedDrops: optionalInt(map, const ['completedDrops']) ?? 0,
      firstAttemptSlaPercent:
          optionalNum(map, const ['firstAttemptSlaPercent']),
      customerVisits: optionalInt(map, const ['customerVisits']) ?? 0,
      fleetCouriers: optionalInt(map, const ['fleetCouriers']) ?? 0,
      shiftAttendancePercent:
          optionalNum(map, const ['shiftAttendancePercent']),
      salesSeries: [
        for (final row in jsonRows(map['salesSeries']))
          AdminReportSeriesPoint.fromJson(row),
      ],
      collectionsSeries: [
        for (final row in jsonRows(map['collectionsSeries']))
          AdminReportSeriesPoint.fromJson(row),
      ],
      fulfillment: [
        for (final row in jsonRows(map['fulfillment']))
          AdminFulfillmentSlice.fromJson(row),
      ],
      riderLeaderboard: [
        for (final row in jsonRows(map['riderLeaderboard']))
          AdminRiderProductivity.fromJson(row),
      ],
      assetCirculation: AdminAssetCirculation.fromJson(map['assetCirculation']),
      scopeNote: jsonString(map, const ['scopeNote']) ?? '',
    );
  }
}

class AdminReportCatalogItem {
  const AdminReportCatalogItem({
    required this.key,
    required this.name,
    this.description = '',
    this.category = '',
    this.formats = 'CSV',
    this.lastGeneratedAtUtc,
  });

  final String key;
  final String name;
  final String description;
  final String category;
  final String formats;
  final DateTime? lastGeneratedAtUtc;

  factory AdminReportCatalogItem.fromJson(Object? data) {
    final map = jsonMap(data) ?? const <String, dynamic>{};
    return AdminReportCatalogItem(
      key: jsonString(map, const ['key']) ?? '',
      name: jsonString(map, const ['name']) ?? '',
      description: jsonString(map, const ['description']) ?? '',
      category: jsonString(map, const ['category']) ?? '',
      formats: jsonString(map, const ['formats']) ?? 'CSV',
      lastGeneratedAtUtc: jsonDate(map, const ['lastGeneratedAtUtc']),
    );
  }
}

class AdminReportTable {
  const AdminReportTable({
    required this.key,
    required this.name,
    this.category = '',
    this.columns = const [],
    this.rows = const [],
    required this.generatedAtUtc,
  });

  final String key;
  final String name;
  final String category;
  final List<String> columns;
  final List<List<String>> rows;
  final DateTime generatedAtUtc;

  factory AdminReportTable.fromJson(Object? data) {
    final map = jsonMap(data) ?? const <String, dynamic>{};
    final columns = <String>[];
    final rawColumns = map['columns'];
    if (rawColumns is List) {
      for (final item in rawColumns) {
        columns.add('$item');
      }
    }
    final rows = <List<String>>[];
    final rawRows = map['rows'];
    if (rawRows is List) {
      for (final row in rawRows) {
        if (row is List) {
          rows.add([for (final cell in row) '$cell']);
        }
      }
    }
    return AdminReportTable(
      key: jsonString(map, const ['key']) ?? '',
      name: jsonString(map, const ['name']) ?? '',
      category: jsonString(map, const ['category']) ?? '',
      columns: columns,
      rows: rows,
      generatedAtUtc:
          jsonDate(map, const ['generatedAtUtc']) ?? DateTime.now().toUtc(),
    );
  }
}
