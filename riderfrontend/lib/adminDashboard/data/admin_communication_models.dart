import 'package:riderfrontend/adminDashboard/data/admin_json.dart';

class CommunicationGatewayStatus {
  const CommunicationGatewayStatus({
    this.providerName = '',
    this.status = '',
    this.isConfigured = false,
    this.senderId,
    this.messagesToday = 0,
    this.message = '',
    this.scopeNote = '',
  });

  final String providerName;
  final String status;
  final bool isConfigured;
  final String? senderId;
  final int messagesToday;
  final String message;
  final String scopeNote;

  factory CommunicationGatewayStatus.fromJson(Object? data) {
    final map = jsonMap(data) ?? const <String, dynamic>{};
    return CommunicationGatewayStatus(
      providerName: jsonString(map, const ['providerName']) ?? '',
      status: jsonString(map, const ['status']) ?? '',
      isConfigured: jsonBool(map, const ['isConfigured']) ?? false,
      senderId: jsonString(map, const ['senderId']),
      messagesToday: optionalInt(map, const ['messagesToday']) ?? 0,
      message: jsonString(map, const ['message']) ?? '',
      scopeNote: jsonString(map, const ['scopeNote']) ?? '',
    );
  }
}

class CommunicationDashboardSummary {
  const CommunicationDashboardSummary({
    required this.operationalDate,
    this.messagesDispatchedToday = 0,
    this.deliveredSuccessfully = 0,
    this.pendingOrQueued = 0,
    this.failedOrExceptions = 0,
    required this.gateway,
    this.scopeNote = '',
  });

  final String operationalDate;
  final int messagesDispatchedToday;
  final int deliveredSuccessfully;
  final int pendingOrQueued;
  final int failedOrExceptions;
  final CommunicationGatewayStatus gateway;
  final String scopeNote;

  factory CommunicationDashboardSummary.fromJson(Object? data) {
    final map = jsonMap(data) ?? const <String, dynamic>{};
    return CommunicationDashboardSummary(
      operationalDate: jsonString(map, const ['operationalDate']) ?? '',
      messagesDispatchedToday:
          optionalInt(map, const ['messagesDispatchedToday']) ?? 0,
      deliveredSuccessfully:
          optionalInt(map, const ['deliveredSuccessfully']) ?? 0,
      pendingOrQueued: optionalInt(map, const ['pendingOrQueued']) ?? 0,
      failedOrExceptions: optionalInt(map, const ['failedOrExceptions']) ?? 0,
      gateway: CommunicationGatewayStatus.fromJson(map['gateway']),
      scopeNote: jsonString(map, const ['scopeNote']) ?? '',
    );
  }
}

class CommunicationTemplate {
  const CommunicationTemplate({
    required this.id,
    this.templateCode = '',
    this.name = '',
    this.language = 'en',
    this.triggerType = '',
    this.content = '',
    this.isActive = true,
    this.isArchived = false,
    this.updatedAtUtc,
  });

  final String id;
  final String templateCode;
  final String name;
  final String language;
  final String triggerType;
  final String content;
  final bool isActive;
  final bool isArchived;
  final DateTime? updatedAtUtc;

  factory CommunicationTemplate.fromJson(Object? data) {
    final map = jsonMap(data) ?? const <String, dynamic>{};
    return CommunicationTemplate(
      id: jsonString(map, const ['id']) ?? '',
      templateCode: jsonString(map, const ['templateCode']) ?? '',
      name: jsonString(map, const ['name']) ?? '',
      language: jsonString(map, const ['language']) ?? 'en',
      triggerType: jsonString(map, const ['triggerType']) ?? '',
      content: jsonString(map, const ['content']) ?? '',
      isActive: jsonBool(map, const ['isActive']) ?? true,
      isArchived: jsonBool(map, const ['isArchived']) ?? false,
      updatedAtUtc: jsonDate(map, const ['updatedAtUtc']),
    );
  }
}

class CommunicationMessageRow {
  const CommunicationMessageRow({
    required this.id,
    this.messageReference = '',
    this.customerName,
    this.destinationNumber = '',
    this.channel = 'SMS',
    this.triggerType = '',
    this.transactionReference,
    this.createdAtUtc,
    this.status = '',
    this.failureReason,
  });

  final String id;
  final String messageReference;
  final String? customerName;
  final String destinationNumber;
  final String channel;
  final String triggerType;
  final String? transactionReference;
  final DateTime? createdAtUtc;
  final String status;
  final String? failureReason;

  factory CommunicationMessageRow.fromJson(Object? data) {
    final map = jsonMap(data) ?? const <String, dynamic>{};
    return CommunicationMessageRow(
      id: jsonString(map, const ['id']) ?? '',
      messageReference: jsonString(map, const ['messageReference']) ?? '',
      customerName: jsonString(map, const ['customerName']),
      destinationNumber: jsonString(map, const ['destinationNumber']) ?? '',
      channel: jsonString(map, const ['channel']) ?? 'SMS',
      triggerType: jsonString(map, const ['triggerType']) ?? '',
      transactionReference: jsonString(map, const ['transactionReference']),
      createdAtUtc: jsonDate(map, const ['createdAtUtc']),
      status: jsonString(map, const ['status']) ?? '',
      failureReason: jsonString(map, const ['failureReason']),
    );
  }
}

class CommunicationMessagePage {
  const CommunicationMessagePage({
    required this.items,
    this.page = 1,
    this.pageSize = 20,
    this.totalRecords = 0,
    this.totalPages = 0,
  });

  final List<CommunicationMessageRow> items;
  final int page;
  final int pageSize;
  final int totalRecords;
  final int totalPages;
}

class CommunicationMessageDetail {
  const CommunicationMessageDetail({
    required this.id,
    this.messageReference = '',
    this.customerId,
    this.customerName,
    this.destinationNumber = '',
    this.channel = 'SMS',
    this.triggerType = '',
    this.transactionReference,
    this.templateId,
    this.templateName,
    this.renderedContent = '',
    this.status = '',
    this.failureReason,
    this.idempotencyKey,
    this.createdAtUtc,
    this.submittedAtUtc,
    this.scopeNote = '',
  });

  final String id;
  final String messageReference;
  final String? customerId;
  final String? customerName;
  final String destinationNumber;
  final String channel;
  final String triggerType;
  final String? transactionReference;
  final String? templateId;
  final String? templateName;
  final String renderedContent;
  final String status;
  final String? failureReason;
  final String? idempotencyKey;
  final DateTime? createdAtUtc;
  final DateTime? submittedAtUtc;
  final String scopeNote;

  factory CommunicationMessageDetail.fromJson(Object? data) {
    final map = jsonMap(data) ?? const <String, dynamic>{};
    return CommunicationMessageDetail(
      id: jsonString(map, const ['id']) ?? '',
      messageReference: jsonString(map, const ['messageReference']) ?? '',
      customerId: jsonString(map, const ['customerId']),
      customerName: jsonString(map, const ['customerName']),
      destinationNumber: jsonString(map, const ['destinationNumber']) ?? '',
      channel: jsonString(map, const ['channel']) ?? 'SMS',
      triggerType: jsonString(map, const ['triggerType']) ?? '',
      transactionReference: jsonString(map, const ['transactionReference']),
      templateId: jsonString(map, const ['templateId']),
      templateName: jsonString(map, const ['templateName']),
      renderedContent: jsonString(map, const ['renderedContent']) ?? '',
      status: jsonString(map, const ['status']) ?? '',
      failureReason: jsonString(map, const ['failureReason']),
      idempotencyKey: jsonString(map, const ['idempotencyKey']),
      createdAtUtc: jsonDate(map, const ['createdAtUtc']),
      submittedAtUtc: jsonDate(map, const ['submittedAtUtc']),
      scopeNote: jsonString(map, const ['scopeNote']) ?? '',
    );
  }
}

class CommunicationPreview {
  const CommunicationPreview({
    this.language = 'en',
    this.renderedContent = '',
    this.destinationHint = '',
  });

  final String language;
  final String renderedContent;
  final String destinationHint;

  factory CommunicationPreview.fromJson(Object? data) {
    final map = jsonMap(data) ?? const <String, dynamic>{};
    return CommunicationPreview(
      language: jsonString(map, const ['language']) ?? 'en',
      renderedContent: jsonString(map, const ['renderedContent']) ?? '',
      destinationHint: jsonString(map, const ['destinationHint']) ?? '',
    );
  }
}

class CommunicationTrigger {
  const CommunicationTrigger({
    required this.triggerType,
    this.description = '',
    this.templateId,
    this.templateName,
    this.enabled = false,
  });

  final String triggerType;
  final String description;
  final String? templateId;
  final String? templateName;
  final bool enabled;

  factory CommunicationTrigger.fromJson(Object? data) {
    final map = jsonMap(data) ?? const <String, dynamic>{};
    return CommunicationTrigger(
      triggerType: jsonString(map, const ['triggerType']) ?? '',
      description: jsonString(map, const ['description']) ?? '',
      templateId: jsonString(map, const ['templateId']),
      templateName: jsonString(map, const ['templateName']),
      enabled: jsonBool(map, const ['enabled']) ?? false,
    );
  }
}
