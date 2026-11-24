import 'package:riderfrontend/adminDashboard/data/admin_json.dart';
import 'package:riderfrontend/adminDashboard/data/zones_routes_models.dart';

class AdminCustomersSummary {
  const AdminCustomersSummary({
    this.totalCustomers = 0,
    this.activeCustomers = 0,
    this.inactiveCustomers = 0,
    this.newThisMonth = 0,
    this.totalOutstanding = 0,
    this.withOutstanding = 0,
    this.missingGps = 0,
  });

  final int totalCustomers;
  final int activeCustomers;
  final int inactiveCustomers;
  final int newThisMonth;
  final num totalOutstanding;
  final int withOutstanding;
  final int missingGps;

  factory AdminCustomersSummary.fromJson(Object? data) {
    final map = jsonMap(data);
    if (map == null) return const AdminCustomersSummary();
    return AdminCustomersSummary(
      totalCustomers: optionalInt(map, const ['totalCustomers']) ?? 0,
      activeCustomers: optionalInt(map, const ['activeCustomers']) ?? 0,
      inactiveCustomers: optionalInt(map, const ['inactiveCustomers']) ?? 0,
      newThisMonth: optionalInt(map, const ['newThisMonth']) ?? 0,
      totalOutstanding: optionalNum(map, const ['totalOutstanding']) ?? 0,
      withOutstanding: optionalInt(map, const ['withOutstanding']) ?? 0,
      missingGps: optionalInt(map, const ['missingGps']) ?? 0,
    );
  }
}

class AdminCustomerRow {
  const AdminCustomerRow({
    required this.id,
    required this.code,
    required this.businessName,
    this.category = '',
    this.status = 'Active',
    this.phone = '',
    this.area = '',
    this.city = '',
    this.address = '',
    this.routeId = '',
    this.routeName = '',
    this.zoneId,
    this.zoneName,
    this.outstanding = 0,
    this.bottlesHeld = 0,
    this.bottlesIssued = 0,
    this.bottlesReturned = 0,
    this.hasGps = false,
    this.latitude,
    this.longitude,
  });

  final String id;
  final String code;
  final String businessName;
  final String category;
  final String status;
  final String phone;
  final String area;
  final String city;
  final String address;
  final String routeId;
  final String routeName;
  final String? zoneId;
  final String? zoneName;
  final num outstanding;
  final int bottlesHeld;
  final int bottlesIssued;
  final int bottlesReturned;
  final bool hasGps;
  final num? latitude;
  final num? longitude;

  factory AdminCustomerRow.fromJson(Object? data) {
    final map = jsonMap(data) ?? const <String, dynamic>{};
    return AdminCustomerRow(
      id: jsonString(map, const ['id']) ?? '',
      code: jsonString(map, const ['code']) ?? '',
      businessName: jsonString(map, const ['businessName']) ?? '',
      category: jsonString(map, const ['category']) ?? '',
      status: jsonString(map, const ['status']) ?? 'Active',
      phone: jsonString(map, const ['phone']) ?? '',
      area: jsonString(map, const ['area']) ?? '',
      city: jsonString(map, const ['city']) ?? '',
      address: jsonString(map, const ['address']) ?? '',
      routeId: jsonString(map, const ['routeId']) ?? '',
      routeName: jsonString(map, const ['routeName']) ?? '',
      zoneId: jsonString(map, const ['zoneId']),
      zoneName: jsonString(map, const ['zoneName']),
      outstanding: optionalNum(map, const ['outstanding']) ?? 0,
      bottlesHeld: optionalInt(map, const ['bottlesHeld']) ?? 0,
      bottlesIssued: optionalInt(map, const ['bottlesIssued']) ?? 0,
      bottlesReturned: optionalInt(map, const ['bottlesReturned']) ?? 0,
      hasGps: jsonBool(map, const ['hasGps']) ?? false,
      latitude: optionalNum(map, const ['latitude']),
      longitude: optionalNum(map, const ['longitude']),
    );
  }
}

class AdminCustomerPage {
  const AdminCustomerPage({
    required this.rows,
    this.page = 1,
    this.pageSize = 20,
    this.totalRecords = 0,
    this.totalPages = 1,
  });

  final List<AdminCustomerRow> rows;
  final int page;
  final int pageSize;
  final int totalRecords;
  final int totalPages;
}

class AdminLedgerRow {
  const AdminLedgerRow({
    required this.id,
    required this.description,
    required this.occurredAt,
    required this.amount,
    required this.balanceAfter,
    this.kind = 'Opening',
    this.reference,
  });

  final String id;
  final String description;
  final DateTime occurredAt;
  final num amount;
  final num balanceAfter;
  final String kind;
  final String? reference;

  factory AdminLedgerRow.fromJson(Object? data) {
    final map = jsonMap(data) ?? const <String, dynamic>{};
    final raw = jsonString(map, const ['occurredAt']) ?? '';
    return AdminLedgerRow(
      id: jsonString(map, const ['id']) ?? '',
      description: jsonString(map, const ['description']) ?? '',
      occurredAt: DateTime.tryParse(raw)?.toLocal() ?? DateTime.fromMillisecondsSinceEpoch(0),
      amount: optionalNum(map, const ['amount']) ?? 0,
      balanceAfter: optionalNum(map, const ['balanceAfter']) ?? 0,
      kind: jsonString(map, const ['kind']) ?? 'Opening',
      reference: jsonString(map, const ['reference']),
    );
  }
}

class AdminCustomerDetail {
  const AdminCustomerDetail({
    required this.customer,
    this.contactName,
    this.contactRole,
    this.additionalContact,
    this.cnic,
    this.bottleOwnership = 'Rented',
    this.creditDays = 7,
    this.lastPaymentLabel,
    this.lifetimeSales = 0,
    this.lifetimeCollections = 0,
    this.recentLedger = const [],
    this.availableRoutes = const [],
  });

  final AdminCustomerRow customer;
  final String? contactName;
  final String? contactRole;
  final String? additionalContact;
  final String? cnic;
  final String bottleOwnership;
  final int creditDays;
  final String? lastPaymentLabel;
  final num lifetimeSales;
  final num lifetimeCollections;
  final List<AdminLedgerRow> recentLedger;
  final List<RouteListItem> availableRoutes;

  factory AdminCustomerDetail.fromJson(Object? data) {
    final map = jsonMap(data) ?? const <String, dynamic>{};
    return AdminCustomerDetail(
      customer: AdminCustomerRow.fromJson(map['customer']),
      contactName: jsonString(map, const ['contactName']),
      contactRole: jsonString(map, const ['contactRole']),
      additionalContact: jsonString(map, const ['additionalContact']),
      cnic: jsonString(map, const ['cnic']),
      bottleOwnership: jsonString(map, const ['bottleOwnership']) ?? 'Rented',
      creditDays: optionalInt(map, const ['creditDays']) ?? 7,
      lastPaymentLabel: jsonString(map, const ['lastPaymentLabel']),
      lifetimeSales: optionalNum(map, const ['lifetimeSales']) ?? 0,
      lifetimeCollections: optionalNum(map, const ['lifetimeCollections']) ?? 0,
      recentLedger: [
        for (final row in jsonRows(map['recentLedger']))
          AdminLedgerRow.fromJson(row),
      ],
      availableRoutes: [
        for (final row in jsonRows(map['availableRoutes']))
          RouteListItem.fromJson(row),
      ],
    );
  }
}
