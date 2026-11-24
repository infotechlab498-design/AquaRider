import 'package:riderfrontend/adminDashboard/data/admin_json.dart';

class AdminCollectionsSummary {
  const AdminCollectionsSummary({
    this.operationalDate = '',
    this.todaysCollections = 0,
    this.todaysCollectionCount = 0,
    this.monthlyCollections = 0,
    this.receivablesLedger = 0,
    this.accountsOnCredit = 0,
    this.highRiskAgingAccounts = 0,
    this.fieldCollectionCount = 0,
    this.pendingSyncCount = 0,
    this.failedSyncCount = 0,
    this.cashSharePercent = 0,
    this.scopeNote = '',
  });

  final String operationalDate;
  final num todaysCollections;
  final int todaysCollectionCount;
  final num monthlyCollections;
  final num receivablesLedger;
  final int accountsOnCredit;
  final int highRiskAgingAccounts;
  final int fieldCollectionCount;
  final int pendingSyncCount;
  final int failedSyncCount;
  final num cashSharePercent;
  final String scopeNote;

  int get syncAttentionCount => pendingSyncCount + failedSyncCount;

  factory AdminCollectionsSummary.fromJson(Object? data) {
    final map = jsonMap(data) ?? const <String, dynamic>{};
    return AdminCollectionsSummary(
      operationalDate: jsonString(map, const ['operationalDate']) ?? '',
      todaysCollections: optionalNum(map, const ['todaysCollections']) ?? 0,
      todaysCollectionCount:
          optionalInt(map, const ['todaysCollectionCount']) ?? 0,
      monthlyCollections: optionalNum(map, const ['monthlyCollections']) ?? 0,
      receivablesLedger: optionalNum(map, const ['receivablesLedger']) ?? 0,
      accountsOnCredit: optionalInt(map, const ['accountsOnCredit']) ?? 0,
      highRiskAgingAccounts:
          optionalInt(map, const ['highRiskAgingAccounts']) ?? 0,
      fieldCollectionCount:
          optionalInt(map, const ['fieldCollectionCount']) ?? 0,
      pendingSyncCount: optionalInt(map, const ['pendingSyncCount']) ?? 0,
      failedSyncCount: optionalInt(map, const ['failedSyncCount']) ?? 0,
      cashSharePercent: optionalNum(map, const ['cashSharePercent']) ?? 0,
      scopeNote: jsonString(map, const ['scopeNote']) ?? '',
    );
  }
}

class AdminCollectionRow {
  const AdminCollectionRow({
    required this.id,
    required this.referenceNumber,
    required this.createdAtUtc,
    required this.customerId,
    this.customerCode = '',
    this.customerName = '',
    this.customerArea = '',
    required this.riderId,
    this.riderName = '',
    this.channelLabel = '',
    this.channelClass = '',
    this.amount = 0,
    this.withholdingTax = 0,
    this.outstandingBefore = 0,
    this.outstandingAfter = 0,
    this.syncStatus = '',
  });

  final String id;
  final String referenceNumber;
  final DateTime createdAtUtc;
  final String customerId;
  final String customerCode;
  final String customerName;
  final String customerArea;
  final String riderId;
  final String riderName;
  final String channelLabel;
  final String channelClass;
  final num amount;
  final num withholdingTax;
  final num outstandingBefore;
  final num outstandingAfter;
  final String syncStatus;

  factory AdminCollectionRow.fromJson(Object? data) {
    final map = jsonMap(data) ?? const <String, dynamic>{};
    return AdminCollectionRow(
      id: jsonString(map, const ['id']) ?? '',
      referenceNumber: jsonString(map, const ['referenceNumber']) ?? '',
      createdAtUtc:
          jsonDate(map, const ['createdAtUtc']) ?? DateTime.now().toUtc(),
      customerId: jsonString(map, const ['customerId']) ?? '',
      customerCode: jsonString(map, const ['customerCode']) ?? '',
      customerName: jsonString(map, const ['customerName']) ?? '',
      customerArea: jsonString(map, const ['customerArea']) ?? '',
      riderId: jsonString(map, const ['riderId']) ?? '',
      riderName: jsonString(map, const ['riderName']) ?? '',
      channelLabel: jsonString(map, const ['channelLabel']) ?? '',
      channelClass: jsonString(map, const ['channelClass']) ?? '',
      amount: optionalNum(map, const ['amount']) ?? 0,
      withholdingTax: optionalNum(map, const ['withholdingTax']) ?? 0,
      outstandingBefore: optionalNum(map, const ['outstandingBefore']) ?? 0,
      outstandingAfter: optionalNum(map, const ['outstandingAfter']) ?? 0,
      syncStatus: jsonString(map, const ['syncStatus']) ?? '',
    );
  }
}

class AdminCollectionPage {
  const AdminCollectionPage({
    required this.rows,
    this.page = 1,
    this.pageSize = 20,
    this.totalRecords = 0,
    this.totalPages = 1,
  });

  final List<AdminCollectionRow> rows;
  final int page;
  final int pageSize;
  final int totalRecords;
  final int totalPages;
}

class AdminCollectionDetail {
  const AdminCollectionDetail({
    required this.id,
    required this.referenceNumber,
    required this.createdAtUtc,
    this.syncStatus = '',
    required this.customerId,
    this.customerCode = '',
    this.customerName = '',
    this.customerAddress = '',
    this.customerPhone = '',
    required this.riderId,
    this.riderName = '',
    this.riderCode,
    this.vehicleLabel,
    this.routeName,
    this.channelLabel = '',
    this.amount = 0,
    this.withholdingTax = 0,
    this.outstandingBefore = 0,
    this.outstandingAfter = 0,
    this.notes,
    this.signerName,
    this.signerRole,
    this.hasSignatureImage = false,
    this.signatureNote,
    this.scopeNote = '',
  });

  final String id;
  final String referenceNumber;
  final DateTime createdAtUtc;
  final String syncStatus;
  final String customerId;
  final String customerCode;
  final String customerName;
  final String customerAddress;
  final String customerPhone;
  final String riderId;
  final String riderName;
  final String? riderCode;
  final String? vehicleLabel;
  final String? routeName;
  final String channelLabel;
  final num amount;
  final num withholdingTax;
  final num outstandingBefore;
  final num outstandingAfter;
  final String? notes;
  final String? signerName;
  final String? signerRole;
  final bool hasSignatureImage;
  final String? signatureNote;
  final String scopeNote;

  factory AdminCollectionDetail.fromJson(Object? data) {
    final map = jsonMap(data) ?? const <String, dynamic>{};
    return AdminCollectionDetail(
      id: jsonString(map, const ['id']) ?? '',
      referenceNumber: jsonString(map, const ['referenceNumber']) ?? '',
      createdAtUtc:
          jsonDate(map, const ['createdAtUtc']) ?? DateTime.now().toUtc(),
      syncStatus: jsonString(map, const ['syncStatus']) ?? '',
      customerId: jsonString(map, const ['customerId']) ?? '',
      customerCode: jsonString(map, const ['customerCode']) ?? '',
      customerName: jsonString(map, const ['customerName']) ?? '',
      customerAddress: jsonString(map, const ['customerAddress']) ?? '',
      customerPhone: jsonString(map, const ['customerPhone']) ?? '',
      riderId: jsonString(map, const ['riderId']) ?? '',
      riderName: jsonString(map, const ['riderName']) ?? '',
      riderCode: jsonString(map, const ['riderCode']),
      vehicleLabel: jsonString(map, const ['vehicleLabel']),
      routeName: jsonString(map, const ['routeName']),
      channelLabel: jsonString(map, const ['channelLabel']) ?? '',
      amount: optionalNum(map, const ['amount']) ?? 0,
      withholdingTax: optionalNum(map, const ['withholdingTax']) ?? 0,
      outstandingBefore: optionalNum(map, const ['outstandingBefore']) ?? 0,
      outstandingAfter: optionalNum(map, const ['outstandingAfter']) ?? 0,
      notes: jsonString(map, const ['notes']),
      signerName: jsonString(map, const ['signerName']),
      signerRole: jsonString(map, const ['signerRole']),
      hasSignatureImage: map['hasSignatureImage'] == true,
      signatureNote: jsonString(map, const ['signatureNote']),
      scopeNote: jsonString(map, const ['scopeNote']) ?? '',
    );
  }
}

class AdminReceivableExposure {
  const AdminReceivableExposure({
    required this.customerId,
    this.customerCode = '',
    this.customerName = '',
    this.area = '',
    this.outstanding = 0,
    this.daysOverdue,
    this.riskLabel = '',
  });

  final String customerId;
  final String customerCode;
  final String customerName;
  final String area;
  final num outstanding;
  final int? daysOverdue;
  final String riskLabel;

  factory AdminReceivableExposure.fromJson(Object? data) {
    final map = jsonMap(data) ?? const <String, dynamic>{};
    return AdminReceivableExposure(
      customerId: jsonString(map, const ['customerId']) ?? '',
      customerCode: jsonString(map, const ['customerCode']) ?? '',
      customerName: jsonString(map, const ['customerName']) ?? '',
      area: jsonString(map, const ['area']) ?? '',
      outstanding: optionalNum(map, const ['outstanding']) ?? 0,
      daysOverdue: optionalInt(map, const ['daysOverdue']),
      riskLabel: jsonString(map, const ['riskLabel']) ?? '',
    );
  }
}
