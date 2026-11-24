import 'package:riderfrontend/adminDashboard/data/admin_json.dart';

class DayCloseGatewayStatus {
  const DayCloseGatewayStatus({
    this.configured = false,
    this.status = 'NotConfigured',
    this.message = 'Gateway Integration Not Configured.',
  });

  final bool configured;
  final String status;
  final String message;

  factory DayCloseGatewayStatus.fromJson(Object? data) {
    final map = jsonMap(data);
    if (map == null) return const DayCloseGatewayStatus();
    return DayCloseGatewayStatus(
      configured: map['configured'] == true,
      status: jsonString(map, const ['status']) ?? 'NotConfigured',
      message:
          jsonString(map, const ['message']) ??
          'Gateway Integration Not Configured.',
    );
  }
}

class DayCloseSummary {
  const DayCloseSummary({
    this.businessDate = '',
    this.warehouseName = '',
    this.gateway = const DayCloseGatewayStatus(),
    this.ridersSubmitted,
    this.ridersEligible,
    this.ridersRemaining,
    this.submissionPercent,
    this.expectedCash,
    this.previousDayExpectedCash,
    this.expectedChangePercent,
    this.declaredCash,
    this.declarationCount,
    this.physicallyReceived,
    this.verificationBatchCount,
    this.unresolvedNetVariance,
    this.unresolvedFlagCount,
    this.varianceThreshold,
    this.sopMessage,
  });

  final String businessDate;
  final String warehouseName;
  final DayCloseGatewayStatus gateway;
  final int? ridersSubmitted;
  final int? ridersEligible;
  final int? ridersRemaining;
  final num? submissionPercent;
  final num? expectedCash;
  final num? previousDayExpectedCash;
  final num? expectedChangePercent;
  final num? declaredCash;
  final int? declarationCount;
  final num? physicallyReceived;
  final int? verificationBatchCount;
  final num? unresolvedNetVariance;
  final int? unresolvedFlagCount;
  final num? varianceThreshold;
  final String? sopMessage;

  factory DayCloseSummary.fromJson(Object? data) {
    final map = jsonMap(data);
    if (map == null) return const DayCloseSummary();
    return DayCloseSummary(
      businessDate: jsonString(map, const ['businessDate']) ?? '',
      warehouseName: jsonString(map, const ['warehouseName']) ?? '',
      gateway: DayCloseGatewayStatus.fromJson(map['gateway']),
      ridersSubmitted: optionalInt(map, const ['ridersSubmitted']),
      ridersEligible: optionalInt(map, const ['ridersEligible']),
      ridersRemaining: optionalInt(map, const ['ridersRemaining']),
      submissionPercent: optionalNum(map, const ['submissionPercent']),
      expectedCash: optionalNum(map, const ['expectedCash']),
      previousDayExpectedCash: optionalNum(map, const [
        'previousDayExpectedCash',
      ]),
      expectedChangePercent: optionalNum(map, const ['expectedChangePercent']),
      declaredCash: optionalNum(map, const ['declaredCash']),
      declarationCount: optionalInt(map, const ['declarationCount']),
      physicallyReceived: optionalNum(map, const ['physicallyReceived']),
      verificationBatchCount: optionalInt(map, const [
        'verificationBatchCount',
      ]),
      unresolvedNetVariance: optionalNum(map, const ['unresolvedNetVariance']),
      unresolvedFlagCount: optionalInt(map, const ['unresolvedFlagCount']),
      varianceThreshold: optionalNum(map, const ['varianceThreshold']),
      sopMessage: jsonString(map, const ['sopMessage']),
    );
  }
}

class SettlementStatusCounts {
  const SettlementStatusCounts({
    this.all,
    this.notStarted,
    this.awaitingReview,
    this.varianceDetected,
    this.reconciled,
    this.locked,
  });

  final int? all;
  final int? notStarted;
  final int? awaitingReview;
  final int? varianceDetected;
  final int? reconciled;
  final int? locked;

  factory SettlementStatusCounts.fromJson(Object? data) {
    final map = jsonMap(data);
    if (map == null) return const SettlementStatusCounts();
    return SettlementStatusCounts(
      all: optionalInt(map, const ['all']),
      notStarted: optionalInt(map, const ['notStarted']),
      awaitingReview: optionalInt(map, const ['awaitingReview']),
      varianceDetected: optionalInt(map, const ['varianceDetected']),
      reconciled: optionalInt(map, const ['reconciled']),
      locked: optionalInt(map, const ['locked']),
    );
  }
}

class SettlementSessionRow {
  const SettlementSessionRow({
    required this.id,
    this.businessDate = '',
    this.riderId = '',
    this.riderName = '',
    this.riderCode = '',
    this.routeName = '',
    this.shiftStatus = '',
    this.expectedCash,
    this.declaredCash,
    this.physicallyReceived,
    this.netVariance,
    this.status = '',
    this.sessionCode = '',
  });

  final String id;
  final String businessDate;
  final String riderId;
  final String riderName;
  final String riderCode;
  final String routeName;
  final String shiftStatus;
  final num? expectedCash;
  final num? declaredCash;
  final num? physicallyReceived;
  final num? netVariance;
  final String status;
  final String sessionCode;

  factory SettlementSessionRow.fromJson(Map<String, dynamic> json) {
    return SettlementSessionRow(
      id: jsonString(json, const ['id']) ?? '',
      businessDate: jsonString(json, const ['businessDate']) ?? '',
      riderId: jsonString(json, const ['riderId']) ?? '',
      riderName: jsonString(json, const ['riderName']) ?? '',
      riderCode: jsonString(json, const ['riderCode']) ?? '',
      routeName: jsonString(json, const ['routeName']) ?? '',
      shiftStatus: jsonString(json, const ['shiftStatus']) ?? '',
      expectedCash: optionalNum(json, const ['expectedCash']),
      declaredCash: optionalNum(json, const ['declaredCash']),
      physicallyReceived: optionalNum(json, const ['physicallyReceived']),
      netVariance: optionalNum(json, const ['netVariance']),
      status: jsonString(json, const ['status']) ?? '',
      sessionCode: jsonString(json, const ['sessionCode']) ?? '',
    );
  }
}

class SettlementSessionPage {
  const SettlementSessionPage({
    this.rows = const [],
    this.page = 1,
    this.pageSize = 20,
    this.totalRecords = 0,
    this.totalPages = 0,
  });

  final List<SettlementSessionRow> rows;
  final int page;
  final int pageSize;
  final int totalRecords;
  final int totalPages;
}

class SettlementCashLedger {
  const SettlementCashLedger({
    this.expectedCash,
    this.declaredCash,
    this.physicallyReceived,
    this.declarationVariance,
    this.physicalVariance,
    this.netVariance,
  });

  final num? expectedCash;
  final num? declaredCash;
  final num? physicallyReceived;
  final num? declarationVariance;
  final num? physicalVariance;
  final num? netVariance;

  factory SettlementCashLedger.fromJson(Object? data) {
    final map = jsonMap(data);
    if (map == null) return const SettlementCashLedger();
    return SettlementCashLedger(
      expectedCash: optionalNum(map, const ['expectedCash']),
      declaredCash: optionalNum(map, const ['declaredCash']),
      physicallyReceived: optionalNum(map, const ['physicallyReceived']),
      declarationVariance: optionalNum(map, const ['declarationVariance']),
      physicalVariance: optionalNum(map, const ['physicalVariance']),
      netVariance: optionalNum(map, const ['netVariance']),
    );
  }
}

class SettlementStockCard {
  const SettlementStockCard({
    this.productName = '',
    this.sku = '',
    this.kind = '',
    this.loaded,
    this.sold,
    this.expected,
    this.declared,
    this.received,
    this.discrepancy,
    this.statusLabel,
  });

  final String productName;
  final String sku;
  final String kind;
  final int? loaded;
  final int? sold;
  final int? expected;
  final int? declared;
  final int? received;
  final int? discrepancy;
  final String? statusLabel;

  factory SettlementStockCard.fromJson(Map<String, dynamic> json) {
    return SettlementStockCard(
      productName: jsonString(json, const ['productName', 'name']) ?? '',
      sku: jsonString(json, const ['sku']) ?? '',
      kind: jsonString(json, const ['kind']) ?? '',
      loaded: optionalInt(json, const ['loaded']),
      sold: optionalInt(json, const ['sold']),
      expected: optionalInt(json, const ['expected']),
      declared: optionalInt(json, const ['declared']),
      received: optionalInt(json, const ['received']),
      discrepancy: optionalInt(json, const ['discrepancy']),
      statusLabel: jsonString(json, const ['statusLabel']),
    );
  }
}

class SettlementAuditEvent {
  const SettlementAuditEvent({
    this.id = '',
    this.eventCode = '',
    this.title = '',
    this.detail = '',
    this.actorName = '',
    this.occurredAt,
  });

  final String id;
  final String eventCode;
  final String title;
  final String detail;
  final String actorName;
  final DateTime? occurredAt;

  factory SettlementAuditEvent.fromJson(Map<String, dynamic> json) {
    return SettlementAuditEvent(
      id: jsonString(json, const ['id']) ?? '',
      eventCode: jsonString(json, const ['eventCode']) ?? '',
      title: jsonString(json, const ['title']) ?? '',
      detail: jsonString(json, const ['detail']) ?? '',
      actorName: jsonString(json, const ['actorName']) ?? '',
      occurredAt: jsonDate(json, const ['occurredAtUtc', 'occurredAt']),
    );
  }
}

class SettlementSessionDetail {
  const SettlementSessionDetail({
    required this.session,
    this.ledger = const SettlementCashLedger(),
    this.riderAnnotation,
    this.fullBottles = const [],
    this.emptyReturns = const [],
    this.stockNote,
    this.auditTrail = const [],
    this.draftVerifiedCash,
    this.draftResolutionCategory,
    this.draftRemarks,
    this.resolutionCategories = const [],
    this.dayLocked = false,
    this.canEdit = true,
  });

  final SettlementSessionRow session;
  final SettlementCashLedger ledger;
  final String? riderAnnotation;
  final List<SettlementStockCard> fullBottles;
  final List<SettlementStockCard> emptyReturns;
  final String? stockNote;
  final List<SettlementAuditEvent> auditTrail;
  final num? draftVerifiedCash;
  final String? draftResolutionCategory;
  final String? draftRemarks;
  final List<String> resolutionCategories;
  final bool dayLocked;
  final bool canEdit;

  factory SettlementSessionDetail.fromJson(Object? data) {
    final map = jsonMap(data);
    if (map == null) {
      return const SettlementSessionDetail(
        session: SettlementSessionRow(id: ''),
      );
    }
    final sessionMap = jsonMap(map['session']) ?? map;
    final stock = jsonMap(map['stock']) ?? const {};
    final full = jsonRows(stock['fullBottles']);
    final empty = jsonRows(stock['emptyReturns']);
    final events = jsonRows(map['auditTrail']);
    final categories = map['resolutionCategories'];
    return SettlementSessionDetail(
      session: SettlementSessionRow.fromJson(sessionMap),
      ledger: SettlementCashLedger.fromJson(map['ledger']),
      riderAnnotation: jsonString(map, const ['riderAnnotation']),
      fullBottles: [
        for (final row in full) SettlementStockCard.fromJson(row),
      ],
      emptyReturns: [
        for (final row in empty) SettlementStockCard.fromJson(row),
      ],
      stockNote: jsonString(stock, const ['note']),
      auditTrail: [
        for (final row in events) SettlementAuditEvent.fromJson(row),
      ],
      draftVerifiedCash: optionalNum(map, const ['draftVerifiedCash']),
      draftResolutionCategory: jsonString(map, const [
        'draftResolutionCategory',
      ]),
      draftRemarks: jsonString(map, const ['draftRemarks']),
      resolutionCategories: categories is List
          ? [
              for (final item in categories)
                if (item != null) item.toString(),
            ]
          : const [],
      dayLocked: map['dayLocked'] == true,
      canEdit: map['canEdit'] != false,
    );
  }
}

class DayLockReadiness {
  const DayLockReadiness({
    this.businessDate = '',
    this.ready = false,
    this.blockingReasons = const [],
  });

  final String businessDate;
  final bool ready;
  final List<String> blockingReasons;

  factory DayLockReadiness.fromJson(Object? data) {
    final map = jsonMap(data);
    if (map == null) return const DayLockReadiness();
    final reasons = map['blockingReasons'];
    return DayLockReadiness(
      businessDate: jsonString(map, const ['businessDate']) ?? '',
      ready: map['ready'] == true,
      blockingReasons: reasons is List
          ? [for (final item in reasons) if (item != null) item.toString()]
          : const [],
    );
  }
}

class DayLockResult {
  const DayLockResult({
    this.businessDate = '',
    this.locked = false,
    this.message = '',
    this.blockingReasons = const [],
  });

  final String businessDate;
  final bool locked;
  final String message;
  final List<String> blockingReasons;

  factory DayLockResult.fromJson(Object? data, {String? message}) {
    final map = jsonMap(data) ?? const {};
    final reasons = map['blockingReasons'];
    return DayLockResult(
      businessDate: jsonString(map, const ['businessDate']) ?? '',
      locked: map['locked'] == true,
      message:
          (message ?? jsonString(map, const ['message']) ?? '').trim(),
      blockingReasons: reasons is List
          ? [for (final item in reasons) if (item != null) item.toString()]
          : const [],
    );
  }
}
