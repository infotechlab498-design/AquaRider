import 'package:riderfrontend/adminDashboard/data/admin_json.dart';

class AdminAuditSummary {
  const AdminAuditSummary({
    required this.operationalDate,
    this.totalEventsToday = 0,
    this.userAndCourierActions = 0,
    this.administrativeModifications = 0,
    this.financialJournalOps = 0,
    this.accessAndSecurity = 0,
    this.fieldOperations = 0,
    this.masterData = 0,
    this.integrityNote = '',
    this.scopeNote = '',
  });

  final String operationalDate;
  final int totalEventsToday;
  final int userAndCourierActions;
  final int administrativeModifications;
  final int financialJournalOps;
  final int accessAndSecurity;
  final int fieldOperations;
  final int masterData;
  final String integrityNote;
  final String scopeNote;

  factory AdminAuditSummary.fromJson(Object? data) {
    final map = jsonMap(data) ?? const <String, dynamic>{};
    return AdminAuditSummary(
      operationalDate: jsonString(map, const ['operationalDate']) ?? '',
      totalEventsToday: optionalInt(map, const ['totalEventsToday']) ?? 0,
      userAndCourierActions:
          optionalInt(map, const ['userAndCourierActions']) ?? 0,
      administrativeModifications:
          optionalInt(map, const ['administrativeModifications']) ?? 0,
      financialJournalOps:
          optionalInt(map, const ['financialJournalOps']) ?? 0,
      accessAndSecurity: optionalInt(map, const ['accessAndSecurity']) ?? 0,
      fieldOperations: optionalInt(map, const ['fieldOperations']) ?? 0,
      masterData: optionalInt(map, const ['masterData']) ?? 0,
      integrityNote: jsonString(map, const ['integrityNote']) ?? '',
      scopeNote: jsonString(map, const ['scopeNote']) ?? '',
    );
  }
}

class AdminAuditEventRow {
  const AdminAuditEventRow({
    required this.id,
    required this.occurredAtUtc,
    this.actorUserId = '',
    this.actorName = '',
    this.actorRole = '',
    this.action = '',
    this.entityName = '',
    this.entityId = '',
    this.category = '',
    this.outcome = '',
    this.description = '',
  });

  final String id;
  final DateTime? occurredAtUtc;
  final String actorUserId;
  final String actorName;
  final String actorRole;
  final String action;
  final String entityName;
  final String entityId;
  final String category;
  final String outcome;
  final String description;

  factory AdminAuditEventRow.fromJson(Object? data) {
    final map = jsonMap(data) ?? const <String, dynamic>{};
    return AdminAuditEventRow(
      id: jsonString(map, const ['id']) ?? '',
      occurredAtUtc: jsonDate(map, const ['occurredAtUtc']),
      actorUserId: jsonString(map, const ['actorUserId']) ?? '',
      actorName: jsonString(map, const ['actorName']) ?? '',
      actorRole: jsonString(map, const ['actorRole']) ?? '',
      action: jsonString(map, const ['action']) ?? '',
      entityName: jsonString(map, const ['entityName']) ?? '',
      entityId: jsonString(map, const ['entityId']) ?? '',
      category: jsonString(map, const ['category']) ?? '',
      outcome: jsonString(map, const ['outcome']) ?? '',
      description: jsonString(map, const ['description']) ?? '',
    );
  }
}

class AdminAuditEventPage {
  const AdminAuditEventPage({
    required this.items,
    this.page = 1,
    this.pageSize = 20,
    this.totalRecords = 0,
    this.totalPages = 0,
  });

  final List<AdminAuditEventRow> items;
  final int page;
  final int pageSize;
  final int totalRecords;
  final int totalPages;
}

class AdminAuditTimelineItem {
  const AdminAuditTimelineItem({
    required this.id,
    this.occurredAtUtc,
    this.action = '',
    this.entityName = '',
    this.entityId = '',
    this.isCurrent = false,
  });

  final String id;
  final DateTime? occurredAtUtc;
  final String action;
  final String entityName;
  final String entityId;
  final bool isCurrent;

  factory AdminAuditTimelineItem.fromJson(Object? data) {
    final map = jsonMap(data) ?? const <String, dynamic>{};
    return AdminAuditTimelineItem(
      id: jsonString(map, const ['id']) ?? '',
      occurredAtUtc: jsonDate(map, const ['occurredAtUtc']),
      action: jsonString(map, const ['action']) ?? '',
      entityName: jsonString(map, const ['entityName']) ?? '',
      entityId: jsonString(map, const ['entityId']) ?? '',
      isCurrent: jsonBool(map, const ['isCurrent']) ?? false,
    );
  }
}

class AdminAuditEventDetail {
  const AdminAuditEventDetail({
    required this.id,
    this.occurredAtUtc,
    this.actorUserId = '',
    this.actorName = '',
    this.actorRole = '',
    this.action = '',
    this.entityName = '',
    this.entityId = '',
    this.category = '',
    this.outcome = '',
    this.description = '',
    this.verificationStatus = '',
    this.verificationMessage,
    this.timeline = const [],
    this.scopeNote = '',
  });

  final String id;
  final DateTime? occurredAtUtc;
  final String actorUserId;
  final String actorName;
  final String actorRole;
  final String action;
  final String entityName;
  final String entityId;
  final String category;
  final String outcome;
  final String description;
  final String verificationStatus;
  final String? verificationMessage;
  final List<AdminAuditTimelineItem> timeline;
  final String scopeNote;

  factory AdminAuditEventDetail.fromJson(Object? data) {
    final map = jsonMap(data) ?? const <String, dynamic>{};
    return AdminAuditEventDetail(
      id: jsonString(map, const ['id']) ?? '',
      occurredAtUtc: jsonDate(map, const ['occurredAtUtc']),
      actorUserId: jsonString(map, const ['actorUserId']) ?? '',
      actorName: jsonString(map, const ['actorName']) ?? '',
      actorRole: jsonString(map, const ['actorRole']) ?? '',
      action: jsonString(map, const ['action']) ?? '',
      entityName: jsonString(map, const ['entityName']) ?? '',
      entityId: jsonString(map, const ['entityId']) ?? '',
      category: jsonString(map, const ['category']) ?? '',
      outcome: jsonString(map, const ['outcome']) ?? '',
      description: jsonString(map, const ['description']) ?? '',
      verificationStatus: jsonString(map, const ['verificationStatus']) ?? '',
      verificationMessage: jsonString(map, const ['verificationMessage']),
      timeline: [
        for (final row in jsonRows(map['timeline']))
          AdminAuditTimelineItem.fromJson(row),
      ],
      scopeNote: jsonString(map, const ['scopeNote']) ?? '',
    );
  }
}

class AdminAuditVerifyResult {
  const AdminAuditVerifyResult({
    required this.eventId,
    this.status = '',
    this.message = '',
  });

  final String eventId;
  final String status;
  final String message;

  factory AdminAuditVerifyResult.fromJson(Object? data) {
    final map = jsonMap(data) ?? const <String, dynamic>{};
    return AdminAuditVerifyResult(
      eventId: jsonString(map, const ['eventId']) ?? '',
      status: jsonString(map, const ['status']) ?? '',
      message: jsonString(map, const ['message']) ?? '',
    );
  }
}
