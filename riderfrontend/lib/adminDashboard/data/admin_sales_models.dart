import 'package:riderfrontend/adminDashboard/data/admin_json.dart';

class AdminSalesSummary {
  const AdminSalesSummary({
    this.operationalDate = '',
    this.todaysBilledSales = 0,
    this.billedTransactionCount = 0,
    this.previousBilledSales,
    this.billedChangePercent,
    this.cashSalesInward = 0,
    this.cashSaleCount = 0,
    this.creditReceivablesFromSales = 0,
    this.creditSaleCount = 0,
    this.completedSales = 0,
    this.averageSaleValue = 0,
    this.pendingSyncCount = 0,
    this.failedSyncCount = 0,
  });

  final String operationalDate;
  final num todaysBilledSales;
  final int billedTransactionCount;
  final num? previousBilledSales;
  final num? billedChangePercent;
  final num cashSalesInward;
  final int cashSaleCount;
  final num creditReceivablesFromSales;
  final int creditSaleCount;
  final int completedSales;
  final num averageSaleValue;
  final int pendingSyncCount;
  final int failedSyncCount;

  int get syncAttentionCount => pendingSyncCount + failedSyncCount;

  factory AdminSalesSummary.fromJson(Object? data) {
    final map = jsonMap(data) ?? const <String, dynamic>{};
    return AdminSalesSummary(
      operationalDate: jsonString(map, const ['operationalDate']) ?? '',
      todaysBilledSales: optionalNum(map, const ['todaysBilledSales']) ?? 0,
      billedTransactionCount:
          optionalInt(map, const ['billedTransactionCount']) ?? 0,
      previousBilledSales: optionalNum(map, const ['previousBilledSales']),
      billedChangePercent: optionalNum(map, const ['billedChangePercent']),
      cashSalesInward: optionalNum(map, const ['cashSalesInward']) ?? 0,
      cashSaleCount: optionalInt(map, const ['cashSaleCount']) ?? 0,
      creditReceivablesFromSales:
          optionalNum(map, const ['creditReceivablesFromSales']) ?? 0,
      creditSaleCount: optionalInt(map, const ['creditSaleCount']) ?? 0,
      completedSales: optionalInt(map, const ['completedSales']) ?? 0,
      averageSaleValue: optionalNum(map, const ['averageSaleValue']) ?? 0,
      pendingSyncCount: optionalInt(map, const ['pendingSyncCount']) ?? 0,
      failedSyncCount: optionalInt(map, const ['failedSyncCount']) ?? 0,
    );
  }
}

class AdminSaleRow {
  const AdminSaleRow({
    required this.id,
    required this.receiptNumber,
    required this.createdAtUtc,
    required this.customerId,
    required this.customerCode,
    required this.customerName,
    required this.riderId,
    this.riderName = '',
    this.vehicleLabel,
    this.itemsSummary = '',
    this.itemCount = 0,
    this.grossAmount = 0,
    this.amountReceived = 0,
    this.creditAmount = 0,
    this.tenderLabel = '',
    this.tenderClass = '',
    this.status = '',
    this.syncStatus = '',
  });

  final String id;
  final String receiptNumber;
  final DateTime createdAtUtc;
  final String customerId;
  final String customerCode;
  final String customerName;
  final String riderId;
  final String riderName;
  final String? vehicleLabel;
  final String itemsSummary;
  final int itemCount;
  final num grossAmount;
  final num amountReceived;
  final num creditAmount;
  final String tenderLabel;
  final String tenderClass;
  final String status;
  final String syncStatus;

  factory AdminSaleRow.fromJson(Object? data) {
    final map = jsonMap(data) ?? const <String, dynamic>{};
    return AdminSaleRow(
      id: jsonString(map, const ['id']) ?? '',
      receiptNumber: jsonString(map, const ['receiptNumber']) ?? '',
      createdAtUtc: jsonDate(map, const ['createdAtUtc']) ?? DateTime.now().toUtc(),
      customerId: jsonString(map, const ['customerId']) ?? '',
      customerCode: jsonString(map, const ['customerCode']) ?? '',
      customerName: jsonString(map, const ['customerName']) ?? '',
      riderId: jsonString(map, const ['riderId']) ?? '',
      riderName: jsonString(map, const ['riderName']) ?? '',
      vehicleLabel: jsonString(map, const ['vehicleLabel']),
      itemsSummary: jsonString(map, const ['itemsSummary']) ?? '',
      itemCount: optionalInt(map, const ['itemCount']) ?? 0,
      grossAmount: optionalNum(map, const ['grossAmount']) ?? 0,
      amountReceived: optionalNum(map, const ['amountReceived']) ?? 0,
      creditAmount: optionalNum(map, const ['creditAmount']) ?? 0,
      tenderLabel: jsonString(map, const ['tenderLabel']) ?? '',
      tenderClass: jsonString(map, const ['tenderClass']) ?? '',
      status: jsonString(map, const ['status']) ?? '',
      syncStatus: jsonString(map, const ['syncStatus']) ?? '',
    );
  }
}

class AdminSalePage {
  const AdminSalePage({
    required this.rows,
    this.page = 1,
    this.pageSize = 20,
    this.totalRecords = 0,
    this.totalPages = 1,
  });

  final List<AdminSaleRow> rows;
  final int page;
  final int pageSize;
  final int totalRecords;
  final int totalPages;
}

class AdminSaleLineDetail {
  const AdminSaleLineDetail({
    required this.productId,
    required this.productName,
    this.sku = '',
    this.quantity = 0,
    this.unit = '',
    this.unitPrice = 0,
    this.lineTotal = 0,
    this.isReturnable = false,
  });

  final String productId;
  final String productName;
  final String sku;
  final int quantity;
  final String unit;
  final num unitPrice;
  final num lineTotal;
  final bool isReturnable;

  factory AdminSaleLineDetail.fromJson(Object? data) {
    final map = jsonMap(data) ?? const <String, dynamic>{};
    return AdminSaleLineDetail(
      productId: jsonString(map, const ['productId']) ?? '',
      productName: jsonString(map, const ['productName']) ?? '',
      sku: jsonString(map, const ['sku']) ?? '',
      quantity: optionalInt(map, const ['quantity']) ?? 0,
      unit: jsonString(map, const ['unit']) ?? '',
      unitPrice: optionalNum(map, const ['unitPrice']) ?? 0,
      lineTotal: optionalNum(map, const ['lineTotal']) ?? 0,
      isReturnable: map['isReturnable'] == true,
    );
  }
}

class AdminSaleAsset {
  const AdminSaleAsset({
    this.assetType = '',
    this.previousHeld = 0,
    this.issued = 0,
    this.returned = 0,
    this.closingBalance = 0,
  });

  final String assetType;
  final int previousHeld;
  final int issued;
  final int returned;
  final int closingBalance;

  factory AdminSaleAsset.fromJson(Object? data) {
    final map = jsonMap(data);
    if (map == null) return const AdminSaleAsset();
    return AdminSaleAsset(
      assetType: jsonString(map, const ['assetType']) ?? '',
      previousHeld: optionalInt(map, const ['previousHeld']) ?? 0,
      issued: optionalInt(map, const ['issued']) ?? 0,
      returned: optionalInt(map, const ['returned']) ?? 0,
      closingBalance: optionalInt(map, const ['closingBalance']) ?? 0,
    );
  }
}

class AdminSaleDetail {
  const AdminSaleDetail({
    required this.id,
    required this.receiptNumber,
    required this.createdAtUtc,
    this.postedAtUtc,
    this.status = '',
    this.syncStatus = '',
    required this.customerId,
    this.customerCode = '',
    this.customerName = '',
    this.customerAddress = '',
    this.customerPhone = '',
    this.customerCategory = '',
    required this.riderId,
    this.riderName = '',
    this.riderCode,
    this.vehicleLabel,
    this.routeName,
    this.lines = const [],
    this.grossAmount = 0,
    this.previousOutstanding = 0,
    this.amountReceived = 0,
    this.creditAmount = 0,
    this.remainingFromSale = 0,
    this.paymentChannel,
    this.tenderClass = '',
    this.returnableAssets,
    this.signerName,
    this.signerRole,
    this.signedAtUtc,
    this.hasSignatureImage = false,
    this.signatureNote,
    this.depotName = '',
    this.scopeNote = '',
  });

  final String id;
  final String receiptNumber;
  final DateTime createdAtUtc;
  final DateTime? postedAtUtc;
  final String status;
  final String syncStatus;
  final String customerId;
  final String customerCode;
  final String customerName;
  final String customerAddress;
  final String customerPhone;
  final String customerCategory;
  final String riderId;
  final String riderName;
  final String? riderCode;
  final String? vehicleLabel;
  final String? routeName;
  final List<AdminSaleLineDetail> lines;
  final num grossAmount;
  final num previousOutstanding;
  final num amountReceived;
  final num creditAmount;
  final num remainingFromSale;
  final String? paymentChannel;
  final String tenderClass;
  final AdminSaleAsset? returnableAssets;
  final String? signerName;
  final String? signerRole;
  final DateTime? signedAtUtc;
  final bool hasSignatureImage;
  final String? signatureNote;
  final String depotName;
  final String scopeNote;

  factory AdminSaleDetail.fromJson(Object? data) {
    final map = jsonMap(data) ?? const <String, dynamic>{};
    final assetsRaw = map['returnableAssets'];
    return AdminSaleDetail(
      id: jsonString(map, const ['id']) ?? '',
      receiptNumber: jsonString(map, const ['receiptNumber']) ?? '',
      createdAtUtc: jsonDate(map, const ['createdAtUtc']) ?? DateTime.now().toUtc(),
      postedAtUtc: jsonDate(map, const ['postedAtUtc']),
      status: jsonString(map, const ['status']) ?? '',
      syncStatus: jsonString(map, const ['syncStatus']) ?? '',
      customerId: jsonString(map, const ['customerId']) ?? '',
      customerCode: jsonString(map, const ['customerCode']) ?? '',
      customerName: jsonString(map, const ['customerName']) ?? '',
      customerAddress: jsonString(map, const ['customerAddress']) ?? '',
      customerPhone: jsonString(map, const ['customerPhone']) ?? '',
      customerCategory: jsonString(map, const ['customerCategory']) ?? '',
      riderId: jsonString(map, const ['riderId']) ?? '',
      riderName: jsonString(map, const ['riderName']) ?? '',
      riderCode: jsonString(map, const ['riderCode']),
      vehicleLabel: jsonString(map, const ['vehicleLabel']),
      routeName: jsonString(map, const ['routeName']),
      lines: [
        for (final row in jsonRows(map['lines'])) AdminSaleLineDetail.fromJson(row),
      ],
      grossAmount: optionalNum(map, const ['grossAmount']) ?? 0,
      previousOutstanding: optionalNum(map, const ['previousOutstanding']) ?? 0,
      amountReceived: optionalNum(map, const ['amountReceived']) ?? 0,
      creditAmount: optionalNum(map, const ['creditAmount']) ?? 0,
      remainingFromSale: optionalNum(map, const ['remainingFromSale']) ?? 0,
      paymentChannel: jsonString(map, const ['paymentChannel']),
      tenderClass: jsonString(map, const ['tenderClass']) ?? '',
      returnableAssets: assetsRaw == null ? null : AdminSaleAsset.fromJson(assetsRaw),
      signerName: jsonString(map, const ['signerName']),
      signerRole: jsonString(map, const ['signerRole']),
      signedAtUtc: jsonDate(map, const ['signedAtUtc']),
      hasSignatureImage: map['hasSignatureImage'] == true,
      signatureNote: jsonString(map, const ['signatureNote']),
      depotName: jsonString(map, const ['depotName']) ?? '',
      scopeNote: jsonString(map, const ['scopeNote']) ?? '',
    );
  }
}

class AdminSaleDraft {
  const AdminSaleDraft({
    required this.id,
    required this.customerId,
    this.saleAmount = 0,
    this.previousOutstanding = 0,
    this.amountDue = 0,
    this.emptyBottlesReturned = 0,
    this.emptyBottlesRemaining = 0,
    this.receiptNumber = '',
  });

  final String id;
  final String customerId;
  final num saleAmount;
  final num previousOutstanding;
  final num amountDue;
  final int emptyBottlesReturned;
  final int emptyBottlesRemaining;
  final String receiptNumber;

  factory AdminSaleDraft.fromJson(Object? data) {
    final map = jsonMap(data) ?? const <String, dynamic>{};
    return AdminSaleDraft(
      id: jsonString(map, const ['id']) ?? '',
      customerId: jsonString(map, const ['customerId']) ?? '',
      saleAmount: optionalNum(map, const ['saleAmount']) ?? 0,
      previousOutstanding: optionalNum(map, const ['previousOutstanding']) ?? 0,
      amountDue: optionalNum(map, const ['amountDue']) ?? 0,
      emptyBottlesReturned: optionalInt(map, const ['emptyBottlesReturned']) ?? 0,
      emptyBottlesRemaining: optionalInt(map, const ['emptyBottlesRemaining']) ?? 0,
      receiptNumber: jsonString(map, const ['receiptNumber']) ?? '',
    );
  }
}
