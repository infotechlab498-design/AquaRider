import 'package:riderfrontend/adminDashboard/data/admin_json.dart';

class DepotDetail {
  const DepotDetail({
    required this.id,
    required this.name,
    this.gate = '',
    this.address = '',
    this.classification = 'PRIMARY DEPOT',
    this.status = 'Active',
    this.code = '',
  });

  final String id;
  final String name;
  final String gate;
  final String address;
  final String classification;
  final String status;
  final String code;

  factory DepotDetail.fromJson(Object? data) {
    final map = jsonMap(data) ?? const <String, dynamic>{};
    return DepotDetail(
      id: jsonString(map, const ['id']) ?? '',
      name: jsonString(map, const ['name']) ?? '',
      gate: jsonString(map, const ['gate']) ?? '',
      address: jsonString(map, const ['address']) ?? '',
      classification: jsonString(map, const ['classification']) ?? 'PRIMARY DEPOT',
      status: jsonString(map, const ['status']) ?? 'Active',
      code: jsonString(map, const ['code']) ?? '',
    );
  }
}

class DepotKpis {
  const DepotKpis({
    this.totalDepots = 0,
    this.centralWarehouses = 0,
    this.satelliteHubs = 0,
    this.activeWarehouses = 0,
    this.activePercent = 0,
    this.assignedFleet = 0,
    this.activeVehicles = 0,
    this.todaysDispatchOrders = 0,
    this.todaysDispatchVolume = 0,
    this.dispatchUnit = 'units',
    this.linkedStores = 0,
  });

  final int totalDepots;
  final int centralWarehouses;
  final int satelliteHubs;
  final int activeWarehouses;
  final num activePercent;
  final int assignedFleet;
  final int activeVehicles;
  final int todaysDispatchOrders;
  final int todaysDispatchVolume;
  final String dispatchUnit;
  final int linkedStores;

  factory DepotKpis.fromJson(Object? data) {
    final map = jsonMap(data) ?? const <String, dynamic>{};
    return DepotKpis(
      totalDepots: optionalInt(map, const ['totalDepots']) ?? 0,
      centralWarehouses: optionalInt(map, const ['centralWarehouses']) ?? 0,
      satelliteHubs: optionalInt(map, const ['satelliteHubs']) ?? 0,
      activeWarehouses: optionalInt(map, const ['activeWarehouses']) ?? 0,
      activePercent: optionalNum(map, const ['activePercent']) ?? 0,
      assignedFleet: optionalInt(map, const ['assignedFleet']) ?? 0,
      activeVehicles: optionalInt(map, const ['activeVehicles']) ?? 0,
      todaysDispatchOrders: optionalInt(map, const ['todaysDispatchOrders']) ?? 0,
      todaysDispatchVolume: optionalInt(map, const ['todaysDispatchVolume']) ?? 0,
      dispatchUnit: jsonString(map, const ['dispatchUnit']) ?? 'units',
      linkedStores: optionalInt(map, const ['linkedStores']) ?? 0,
    );
  }
}

class DepotCapacity {
  const DepotCapacity({
    this.occupiedUnits = 0,
    this.expectedUnits = 0,
    this.availableUnits = 0,
    this.utilizationPercent = 0,
    this.unitLabel = 'units',
  });

  final int occupiedUnits;
  final int expectedUnits;
  final int availableUnits;
  final num utilizationPercent;
  final String unitLabel;

  factory DepotCapacity.fromJson(Object? data) {
    final map = jsonMap(data) ?? const <String, dynamic>{};
    return DepotCapacity(
      occupiedUnits: optionalInt(map, const ['occupiedUnits']) ?? 0,
      expectedUnits: optionalInt(map, const ['expectedUnits']) ?? 0,
      availableUnits: optionalInt(map, const ['availableUnits']) ?? 0,
      utilizationPercent: optionalNum(map, const ['utilizationPercent']) ?? 0,
      unitLabel: jsonString(map, const ['unitLabel']) ?? 'units',
    );
  }
}

class DepotFleetMember {
  const DepotFleetMember({
    required this.vehicleId,
    required this.vehicleName,
    this.plate = '',
    this.fleetCode = '',
    this.riderUserId,
    this.riderName,
    this.riderCode,
    this.riderActive = false,
    this.stockUnits = 0,
  });

  final String vehicleId;
  final String vehicleName;
  final String plate;
  final String fleetCode;
  final String? riderUserId;
  final String? riderName;
  final String? riderCode;
  final bool riderActive;
  final int stockUnits;

  factory DepotFleetMember.fromJson(Object? data) {
    final map = jsonMap(data) ?? const <String, dynamic>{};
    return DepotFleetMember(
      vehicleId: jsonString(map, const ['vehicleId']) ?? '',
      vehicleName: jsonString(map, const ['vehicleName']) ?? '',
      plate: jsonString(map, const ['plate']) ?? '',
      fleetCode: jsonString(map, const ['fleetCode']) ?? '',
      riderUserId: jsonString(map, const ['riderUserId']),
      riderName: jsonString(map, const ['riderName']),
      riderCode: jsonString(map, const ['riderCode']),
      riderActive: map['riderActive'] == true,
      stockUnits: optionalInt(map, const ['stockUnits']) ?? 0,
    );
  }
}

class DepotStockLine {
  const DepotStockLine({
    required this.productId,
    required this.productName,
    this.sku = '',
    this.quantityOnVans = 0,
    this.depotExpected = 0,
    this.isReturnable = false,
  });

  final String productId;
  final String productName;
  final String sku;
  final int quantityOnVans;
  final int depotExpected;
  final bool isReturnable;

  factory DepotStockLine.fromJson(Object? data) {
    final map = jsonMap(data) ?? const <String, dynamic>{};
    return DepotStockLine(
      productId: jsonString(map, const ['productId']) ?? '',
      productName: jsonString(map, const ['productName']) ?? '',
      sku: jsonString(map, const ['sku']) ?? '',
      quantityOnVans: optionalInt(map, const ['quantityOnVans']) ?? 0,
      depotExpected: optionalInt(map, const ['depotExpected']) ?? 0,
      isReturnable: map['isReturnable'] == true,
    );
  }
}

class DepotOperations {
  const DepotOperations({
    required this.depot,
    required this.kpis,
    required this.capacity,
    this.fleet = const [],
    this.stock = const [],
    this.todaysCompletedSales = 0,
    this.todaysBilledSales = 0,
    this.managerName,
    this.scopeNote = '',
  });

  final DepotDetail depot;
  final DepotKpis kpis;
  final DepotCapacity capacity;
  final List<DepotFleetMember> fleet;
  final List<DepotStockLine> stock;
  final int todaysCompletedSales;
  final num todaysBilledSales;
  final String? managerName;
  final String scopeNote;

  factory DepotOperations.fromJson(Object? data) {
    final map = jsonMap(data) ?? const <String, dynamic>{};
    return DepotOperations(
      depot: DepotDetail.fromJson(map['depot']),
      kpis: DepotKpis.fromJson(map['kpis']),
      capacity: DepotCapacity.fromJson(map['capacity']),
      fleet: [
        for (final row in jsonRows(map['fleet'])) DepotFleetMember.fromJson(row),
      ],
      stock: [
        for (final row in jsonRows(map['stock'])) DepotStockLine.fromJson(row),
      ],
      todaysCompletedSales: optionalInt(map, const ['todaysCompletedSales']) ?? 0,
      todaysBilledSales: optionalNum(map, const ['todaysBilledSales']) ?? 0,
      managerName: jsonString(map, const ['managerName']),
      scopeNote: jsonString(map, const ['scopeNote']) ?? '',
    );
  }
}
