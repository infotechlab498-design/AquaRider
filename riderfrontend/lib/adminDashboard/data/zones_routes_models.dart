import 'package:riderfrontend/adminDashboard/data/admin_json.dart';

class ZonesRoutesSummary {
  const ZonesRoutesSummary({
    this.totalZones = 0,
    this.activeZones = 0,
    this.activeRoutes = 0,
    this.assignedRiders = 0,
    this.assignedStores = 0,
    this.customersMissingGps = 0,
    this.depotName,
  });

  final int totalZones;
  final int activeZones;
  final int activeRoutes;
  final int assignedRiders;
  final int assignedStores;
  final int customersMissingGps;
  final String? depotName;

  factory ZonesRoutesSummary.fromJson(Object? data) {
    final map = jsonMap(data);
    if (map == null) return const ZonesRoutesSummary();
    return ZonesRoutesSummary(
      totalZones: optionalInt(map, const ['totalZones']) ?? 0,
      activeZones: optionalInt(map, const ['activeZones']) ?? 0,
      activeRoutes: optionalInt(map, const ['activeRoutes']) ?? 0,
      assignedRiders: optionalInt(map, const ['assignedRiders']) ?? 0,
      assignedStores: optionalInt(map, const ['assignedStores']) ?? 0,
      customersMissingGps: optionalInt(map, const ['customersMissingGps']) ?? 0,
      depotName: jsonString(map, const ['depotName']),
    );
  }
}

class ZoneListItem {
  const ZoneListItem({
    required this.id,
    required this.name,
    this.sector = '',
    this.city = '',
    this.depotId = '',
    this.depotName = '',
    this.isActive = true,
    this.routeCount = 0,
    this.customerCount = 0,
    this.assignedRiderCount = 0,
  });

  final String id;
  final String name;
  final String sector;
  final String city;
  final String depotId;
  final String depotName;
  final bool isActive;
  final int routeCount;
  final int customerCount;
  final int assignedRiderCount;

  factory ZoneListItem.fromJson(Object? data) {
    final map = jsonMap(data) ?? const <String, dynamic>{};
    return ZoneListItem(
      id: jsonString(map, const ['id']) ?? '',
      name: jsonString(map, const ['name']) ?? '',
      sector: jsonString(map, const ['sector']) ?? '',
      city: jsonString(map, const ['city']) ?? '',
      depotId: jsonString(map, const ['depotId']) ?? '',
      depotName: jsonString(map, const ['depotName']) ?? '',
      isActive: jsonBool(map, const ['isActive']) ?? true,
      routeCount: optionalInt(map, const ['routeCount']) ?? 0,
      customerCount: optionalInt(map, const ['customerCount']) ?? 0,
      assignedRiderCount: optionalInt(map, const ['assignedRiderCount']) ?? 0,
    );
  }
}

class ZoneDetail {
  const ZoneDetail({
    required this.id,
    required this.name,
    this.sector = '',
    this.city = '',
    this.depotId = '',
    this.depotName = '',
    this.isActive = true,
    this.routeCount = 0,
    this.customerCount = 0,
    this.routes = const [],
  });

  final String id;
  final String name;
  final String sector;
  final String city;
  final String depotId;
  final String depotName;
  final bool isActive;
  final int routeCount;
  final int customerCount;
  final List<RouteListItem> routes;

  factory ZoneDetail.fromJson(Object? data) {
    final map = jsonMap(data) ?? const <String, dynamic>{};
    return ZoneDetail(
      id: jsonString(map, const ['id']) ?? '',
      name: jsonString(map, const ['name']) ?? '',
      sector: jsonString(map, const ['sector']) ?? '',
      city: jsonString(map, const ['city']) ?? '',
      depotId: jsonString(map, const ['depotId']) ?? '',
      depotName: jsonString(map, const ['depotName']) ?? '',
      isActive: jsonBool(map, const ['isActive']) ?? true,
      routeCount: optionalInt(map, const ['routeCount']) ?? 0,
      customerCount: optionalInt(map, const ['customerCount']) ?? 0,
      routes: [
        for (final row in jsonRows(map['routes'])) RouteListItem.fromJson(row),
      ],
    );
  }
}

class RouteListItem {
  const RouteListItem({
    required this.id,
    required this.name,
    this.sector = '',
    this.city = '',
    this.zoneId = '',
    this.zoneName = '',
    this.depotId = '',
    this.depotName = '',
    this.customerCount = 0,
    this.stopCountToday = 0,
    this.riders = const [],
    this.hasRider = false,
  });

  final String id;
  final String name;
  final String sector;
  final String city;
  final String zoneId;
  final String zoneName;
  final String depotId;
  final String depotName;
  final int customerCount;
  final int stopCountToday;
  final List<RouteRider> riders;
  final bool hasRider;

  factory RouteListItem.fromJson(Object? data) {
    final map = jsonMap(data) ?? const <String, dynamic>{};
    return RouteListItem(
      id: jsonString(map, const ['id']) ?? '',
      name: jsonString(map, const ['name']) ?? '',
      sector: jsonString(map, const ['sector']) ?? '',
      city: jsonString(map, const ['city']) ?? '',
      zoneId: jsonString(map, const ['zoneId']) ?? '',
      zoneName: jsonString(map, const ['zoneName']) ?? '',
      depotId: jsonString(map, const ['depotId']) ?? '',
      depotName: jsonString(map, const ['depotName']) ?? '',
      customerCount: optionalInt(map, const ['customerCount']) ?? 0,
      stopCountToday: optionalInt(map, const ['stopCountToday']) ?? 0,
      riders: [
        for (final row in jsonRows(map['riders'])) RouteRider.fromJson(row),
      ],
      hasRider: jsonBool(map, const ['hasRider']) ?? false,
    );
  }
}

class RouteRider {
  const RouteRider({
    required this.userId,
    required this.fullName,
    this.riderCode,
    this.vehiclePlate,
    this.isActive = true,
  });

  final String userId;
  final String fullName;
  final String? riderCode;
  final String? vehiclePlate;
  final bool isActive;

  factory RouteRider.fromJson(Object? data) {
    final map = jsonMap(data) ?? const <String, dynamic>{};
    return RouteRider(
      userId: jsonString(map, const ['userId']) ?? '',
      fullName: jsonString(map, const ['fullName']) ?? '',
      riderCode: jsonString(map, const ['riderCode']),
      vehiclePlate: jsonString(map, const ['vehiclePlate']),
      isActive: jsonBool(map, const ['isActive']) ?? true,
    );
  }
}

class RouteDetail {
  const RouteDetail({
    required this.id,
    required this.name,
    this.sector = '',
    this.city = '',
    this.zoneId = '',
    this.zoneName = '',
    this.depotId = '',
    this.depotName = '',
    this.customerCount = 0,
    this.customersWithGps = 0,
    this.stopCountToday = 0,
    this.riders = const [],
    this.customers = const [],
  });

  final String id;
  final String name;
  final String sector;
  final String city;
  final String zoneId;
  final String zoneName;
  final String depotId;
  final String depotName;
  final int customerCount;
  final int customersWithGps;
  final int stopCountToday;
  final List<RouteRider> riders;
  final List<RouteCustomerRow> customers;

  factory RouteDetail.fromJson(Object? data) {
    final map = jsonMap(data) ?? const <String, dynamic>{};
    return RouteDetail(
      id: jsonString(map, const ['id']) ?? '',
      name: jsonString(map, const ['name']) ?? '',
      sector: jsonString(map, const ['sector']) ?? '',
      city: jsonString(map, const ['city']) ?? '',
      zoneId: jsonString(map, const ['zoneId']) ?? '',
      zoneName: jsonString(map, const ['zoneName']) ?? '',
      depotId: jsonString(map, const ['depotId']) ?? '',
      depotName: jsonString(map, const ['depotName']) ?? '',
      customerCount: optionalInt(map, const ['customerCount']) ?? 0,
      customersWithGps: optionalInt(map, const ['customersWithGps']) ?? 0,
      stopCountToday: optionalInt(map, const ['stopCountToday']) ?? 0,
      riders: [
        for (final row in jsonRows(map['riders'])) RouteRider.fromJson(row),
      ],
      customers: [
        for (final row in jsonRows(map['customers']))
          RouteCustomerRow.fromJson(row),
      ],
    );
  }
}

class RouteCustomerRow {
  const RouteCustomerRow({
    required this.id,
    required this.code,
    required this.businessName,
    this.status = 'Active',
    this.phone = '',
    this.address = '',
    this.area = '',
    this.routeSortOrder = 0,
    this.latitude,
    this.longitude,
    this.outstanding = 0,
    this.hasGps = false,
  });

  final String id;
  final String code;
  final String businessName;
  final String status;
  final String phone;
  final String address;
  final String area;
  final int routeSortOrder;
  final num? latitude;
  final num? longitude;
  final num outstanding;
  final bool hasGps;

  factory RouteCustomerRow.fromJson(Object? data) {
    final map = jsonMap(data) ?? const <String, dynamic>{};
    return RouteCustomerRow(
      id: jsonString(map, const ['id']) ?? '',
      code: jsonString(map, const ['code']) ?? '',
      businessName: jsonString(map, const ['businessName']) ?? '',
      status: jsonString(map, const ['status']) ?? 'Active',
      phone: jsonString(map, const ['phone']) ?? '',
      address: jsonString(map, const ['address']) ?? '',
      area: jsonString(map, const ['area']) ?? '',
      routeSortOrder: optionalInt(map, const ['routeSortOrder']) ?? 0,
      latitude: optionalNum(map, const ['latitude']),
      longitude: optionalNum(map, const ['longitude']),
      outstanding: optionalNum(map, const ['outstanding']) ?? 0,
      hasGps: jsonBool(map, const ['hasGps']) ?? false,
    );
  }
}

class RouteStopRow {
  const RouteStopRow({
    required this.id,
    required this.customerId,
    required this.customerCode,
    required this.customerName,
    this.address = '',
    this.phone = '',
    this.sequence = 0,
    this.status = 'Pending',
    this.latitude,
    this.longitude,
  });

  final String id;
  final String customerId;
  final String customerCode;
  final String customerName;
  final String address;
  final String phone;
  final int sequence;
  final String status;
  final num? latitude;
  final num? longitude;

  factory RouteStopRow.fromJson(Object? data) {
    final map = jsonMap(data) ?? const <String, dynamic>{};
    return RouteStopRow(
      id: jsonString(map, const ['id']) ?? '',
      customerId: jsonString(map, const ['customerId']) ?? '',
      customerCode: jsonString(map, const ['customerCode']) ?? '',
      customerName: jsonString(map, const ['customerName']) ?? '',
      address: jsonString(map, const ['address']) ?? '',
      phone: jsonString(map, const ['phone']) ?? '',
      sequence: optionalInt(map, const ['sequence']) ?? 0,
      status: jsonString(map, const ['status']) ?? 'Pending',
      latitude: optionalNum(map, const ['latitude']),
      longitude: optionalNum(map, const ['longitude']),
    );
  }
}

class EligibleRouteRider {
  const EligibleRouteRider({
    required this.userId,
    required this.fullName,
    this.riderCode,
    this.currentRouteId,
    this.currentRouteName,
    this.vehiclePlate,
    this.isActive = true,
  });

  final String userId;
  final String fullName;
  final String? riderCode;
  final String? currentRouteId;
  final String? currentRouteName;
  final String? vehiclePlate;
  final bool isActive;

  factory EligibleRouteRider.fromJson(Object? data) {
    final map = jsonMap(data) ?? const <String, dynamic>{};
    return EligibleRouteRider(
      userId: jsonString(map, const ['userId']) ?? '',
      fullName: jsonString(map, const ['fullName']) ?? '',
      riderCode: jsonString(map, const ['riderCode']),
      currentRouteId: jsonString(map, const ['currentRouteId']),
      currentRouteName: jsonString(map, const ['currentRouteName']),
      vehiclePlate: jsonString(map, const ['vehiclePlate']),
      isActive: jsonBool(map, const ['isActive']) ?? true,
    );
  }
}

class RouteMapData {
  const RouteMapData({
    required this.routeId,
    required this.routeName,
    this.zoneName = '',
    this.serviceDate = '',
    this.pins = const [],
  });

  final String routeId;
  final String routeName;
  final String zoneName;
  final String serviceDate;
  final List<RouteMapPin> pins;

  factory RouteMapData.fromJson(Object? data) {
    final map = jsonMap(data) ?? const <String, dynamic>{};
    return RouteMapData(
      routeId: jsonString(map, const ['routeId']) ?? '',
      routeName: jsonString(map, const ['routeName']) ?? '',
      zoneName: jsonString(map, const ['zoneName']) ?? '',
      serviceDate: jsonString(map, const ['serviceDate']) ?? '',
      pins: [
        for (final row in jsonRows(map['pins'])) RouteMapPin.fromJson(row),
      ],
    );
  }
}

class RouteMapPin {
  const RouteMapPin({
    required this.customerId,
    required this.label,
    required this.code,
    required this.latitude,
    required this.longitude,
    this.sequence = 0,
    this.isStop = false,
  });

  final String customerId;
  final String label;
  final String code;
  final num latitude;
  final num longitude;
  final int sequence;
  final bool isStop;

  factory RouteMapPin.fromJson(Object? data) {
    final map = jsonMap(data) ?? const <String, dynamic>{};
    return RouteMapPin(
      customerId: jsonString(map, const ['customerId']) ?? '',
      label: jsonString(map, const ['label']) ?? '',
      code: jsonString(map, const ['code']) ?? '',
      latitude: optionalNum(map, const ['latitude']) ?? 0,
      longitude: optionalNum(map, const ['longitude']) ?? 0,
      sequence: optionalInt(map, const ['sequence']) ?? 0,
      isStop: jsonBool(map, const ['isStop']) ?? false,
    );
  }
}
