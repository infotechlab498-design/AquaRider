import 'admin_format.dart';
import 'admin_json.dart';

const lockedRiderKpiLabels = <String>[
  'Riders registered',
  'Available for assignment',
  'Active assignments',
  'Deliveries in progress',
  'Requiring attention',
];

class RiderKpi {
  const RiderKpi({
    required this.key,
    required this.label,
    required this.value,
    this.detail,
  });

  final String key;
  final String label;
  final String value;
  final String? detail;
}

class RiderOperationsSummary {
  const RiderOperationsSummary({
    this.kpis = const [],
    this.ridersRegistered,
    this.availableForAssignment,
    this.activeAssignments,
    this.deliveriesInProgress,
    this.requiringAttention,
  });

  final List<RiderKpi> kpis;
  final int? ridersRegistered;
  final int? availableForAssignment;
  final int? activeAssignments;
  final int? deliveriesInProgress;
  final int? requiringAttention;

  factory RiderOperationsSummary.fromJson(Object? data) {
    final map = jsonMap(data);
    if (map == null) return const RiderOperationsSummary();
    final registered = optionalInt(map, const [
      'ridersRegistered',
      'registeredCount',
    ]);
    final available = optionalInt(map, const [
      'availableForAssignment',
      'availableCount',
    ]);
    final active = optionalInt(map, const [
      'activeAssignments',
      'activeAssignmentCount',
    ]);
    final deliveries = optionalInt(map, const [
      'deliveriesInProgress',
      'inProgressDeliveries',
    ]);
    final attention = optionalInt(map, const [
      'requiringAttention',
      'attentionCount',
    ]);
    final listed = jsonPick(map, const ['kpis', 'cards', 'items']);
    final fromList = listed is List
        ? _kpisFromList(listed)
        : const <RiderKpi>[];
    final kpis = listed is List && fromList.isNotEmpty
        ? fromList
        : _kpisFromCounts(
            map,
            registered: registered,
            available: available,
            active: active,
            deliveries: deliveries,
            attention: attention,
          );
    return RiderOperationsSummary(
      kpis: kpis,
      ridersRegistered: registered,
      availableForAssignment: available,
      activeAssignments: active,
      deliveriesInProgress: deliveries,
      requiringAttention: attention,
    );
  }
}

List<RiderKpi> _kpisFromList(List<dynamic> raw) {
  final cards = <RiderKpi>[];
  for (final item in raw) {
    final row = jsonMap(item);
    if (row == null) continue;
    final key = jsonString(row, const ['key', 'id', 'code']) ?? '';
    final label = jsonString(row, const ['label', 'title', 'name']) ?? key;
    if (isDisallowedOperationsLabel('$label $key')) continue;
    final explicit = jsonString(row, const ['displayValue', 'valueText']);
    final number = jsonNum(row, const ['value', 'count', 'total']);
    final value = explicit ?? (number == null ? '' : formatGrouped(number));
    if (value.isEmpty) continue;
    cards.add(
      RiderKpi(
        key: key,
        label: label,
        value: value,
        detail: jsonString(row, const ['detail', 'subtitle', 'note']),
      ),
    );
  }
  return cards;
}

List<RiderKpi> _kpisFromCounts(
  Map<String, dynamic> json, {
  required int? registered,
  required int? available,
  required int? active,
  required int? deliveries,
  required int? attention,
}) {
  RiderKpi? card(
    String key,
    String label,
    int? count,
    List<String> detailKeys,
  ) {
    if (count == null) return null;
    return RiderKpi(
      key: key,
      label: label,
      value: formatGrouped(count),
      detail: jsonString(json, detailKeys),
    );
  }

  return [
    ?card('ridersRegistered', lockedRiderKpiLabels[0], registered, const [
      'ridersRegisteredDetail',
    ]),
    ?card('availableForAssignment', lockedRiderKpiLabels[1], available, const [
      'availableForAssignmentDetail',
    ]),
    ?card('activeAssignments', lockedRiderKpiLabels[2], active, const [
      'activeAssignmentsDetail',
    ]),
    ?card('deliveriesInProgress', lockedRiderKpiLabels[3], deliveries, const [
      'deliveriesInProgressDetail',
    ]),
    ?card('requiringAttention', lockedRiderKpiLabels[4], attention, const [
      'requiringAttentionDetail',
    ]),
  ];
}

class RiderRecord {
  const RiderRecord({
    required this.id,
    required this.fullName,
    this.riderCode = '',
    this.status = '',
    this.routeName = '',
    this.vehicleName = '',
    this.vehiclePlate = '',
    this.phone = '',
    this.completedStops,
    this.totalStops,
    this.cashInHand,
    this.salesAmount,
    this.returnsCount,
    this.nextStop,
    this.lastActivity,
    this.notes,
  });

  final String id;
  final String fullName;
  final String riderCode;
  final String status;
  final String routeName;
  final String vehicleName;
  final String vehiclePlate;
  final String phone;
  final int? completedStops;
  final int? totalStops;
  final num? cashInHand;
  final num? salesAmount;
  final int? returnsCount;
  final String? nextStop;
  final String? lastActivity;
  final String? notes;

  bool get hasPhone => phone.trim().isNotEmpty;

  String get initials {
    final parts = fullName.split(' ').where((part) => part.isNotEmpty).take(2);
    if (parts.isEmpty) return 'R';
    return parts.map((part) => part[0]).join().toUpperCase();
  }

  factory RiderRecord.fromJson(Map<String, dynamic> json) {
    final nested = jsonMap(jsonPick(json, const ['rider']));
    final source = nested ?? json;
    return RiderRecord(
      id: jsonString(source, const ['id', 'riderId', 'userId']) ?? '',
      fullName:
          jsonString(source, const ['fullName', 'name', 'riderName']) ?? '',
      riderCode: jsonString(source, const ['riderCode', 'code']) ?? '',
      status: jsonString(source, const ['status', 'dutyStatus']) ?? '',
      routeName: jsonString(source, const ['routeName', 'route']) ?? '',
      vehicleName: jsonString(source, const ['vehicleName', 'vehicle']) ?? '',
      vehiclePlate: jsonString(source, const ['vehiclePlate', 'plate']) ?? '',
      phone: jsonString(source, const ['phone', 'mobile', 'phoneNumber']) ?? '',
      completedStops: optionalInt(source, const [
        'completedStops',
        'visitsCompleted',
      ]),
      totalStops: optionalInt(source, const ['totalStops', 'visitsTotal']),
      cashInHand: optionalNum(source, const ['cashInHand', 'cash']),
      salesAmount: optionalNum(source, const ['salesAmount', 'sales']),
      returnsCount: optionalInt(source, const ['returnsCount', 'returns']),
      nextStop: jsonString(source, const [
        'nextStop',
        'nextAssignment',
        'nextWaypoint',
      ]),
      lastActivity: jsonString(source, const [
        'lastActivity',
        'lastActivityTitle',
      ]),
      notes: jsonString(source, const ['notes', 'note']),
    );
  }

  static List<RiderRecord> listFromJson(Object? data) {
    return [
      for (final row in jsonRows(
        data,
        keys: const ['items', 'rows', 'riders', 'results'],
      ))
        if (RiderRecord.fromJson(row) case final rider)
          if (rider.id.isNotEmpty || rider.fullName.isNotEmpty) rider,
    ];
  }
}

class RiderAssignment {
  const RiderAssignment({
    required this.id,
    required this.customerName,
    this.status = '',
    this.sequence,
    this.address,
    this.scheduledTime,
  });

  final String id;
  final String customerName;
  final String status;
  final int? sequence;
  final String? address;
  final String? scheduledTime;

  factory RiderAssignment.fromJson(Map<String, dynamic> json) {
    return RiderAssignment(
      id: jsonString(json, const ['id', 'stopId']) ?? '',
      customerName:
          jsonString(json, const ['customerName', 'name', 'party']) ?? '',
      status: jsonString(json, const ['status']) ?? '',
      sequence: optionalInt(json, const ['sequence', 'stopSequence']),
      address: jsonString(json, const ['address']),
      scheduledTime: jsonString(json, const ['scheduledTime', 'window']),
    );
  }

  static List<RiderAssignment> listFromJson(Object? data) {
    return [
      for (final row in jsonRows(
        data,
        keys: const ['items', 'rows', 'assignments', 'stops'],
      ))
        if (RiderAssignment.fromJson(row) case final item)
          if (item.customerName.isNotEmpty || item.id.isNotEmpty) item,
    ];
  }
}

class RiderActivityItem {
  const RiderActivityItem({
    required this.id,
    required this.title,
    this.detail = '',
    this.occurredAt,
    this.reference,
  });

  final String id;
  final String title;
  final String detail;
  final DateTime? occurredAt;
  final String? reference;

  factory RiderActivityItem.fromJson(Map<String, dynamic> json) {
    return RiderActivityItem(
      id: jsonString(json, const ['id']) ?? '',
      title: jsonString(json, const ['title', 'name', 'summary']) ?? '',
      detail: jsonString(json, const ['detail', 'description']) ?? '',
      occurredAt: jsonDate(json, const ['occurredAt', 'timestamp', 'at']),
      reference: jsonString(json, const ['reference', 'referenceNumber']),
    );
  }

  static List<RiderActivityItem> listFromJson(Object? data) {
    return [
      for (final row in jsonRows(
        data,
        keys: const ['items', 'rows', 'activity', 'activities'],
      ))
        if (RiderActivityItem.fromJson(row) case final item)
          if (item.title.isNotEmpty || item.detail.isNotEmpty) item,
    ];
  }
}

class RiderExceptionItem {
  const RiderExceptionItem({
    required this.id,
    required this.title,
    this.detail = '',
    this.riderName,
    this.severity = 'info',
    this.occurredAt,
  });

  final String id;
  final String title;
  final String detail;
  final String? riderName;
  final String severity;
  final DateTime? occurredAt;

  factory RiderExceptionItem.fromJson(Map<String, dynamic> json) {
    return RiderExceptionItem(
      id: jsonString(json, const ['id']) ?? '',
      title: jsonString(json, const ['title', 'name', 'summary']) ?? '',
      detail:
          jsonString(json, const ['detail', 'description', 'message']) ?? '',
      riderName: jsonString(json, const ['riderName', 'rider']),
      severity: (jsonString(json, const ['severity', 'level']) ?? 'info')
          .toLowerCase(),
      occurredAt: jsonDate(json, const ['occurredAt', 'timestamp', 'at']),
    );
  }

  static List<RiderExceptionItem> listFromJson(Object? data) {
    return [
      for (final row in jsonRows(
        data,
        keys: const ['items', 'rows', 'exceptions'],
      ))
        if (RiderExceptionItem.fromJson(row) case final item)
          if (item.title.isNotEmpty || item.detail.isNotEmpty) item,
    ];
  }
}

class LocationVerification {
  const LocationVerification({
    required this.id,
    this.riderName = '',
    this.outcome = '',
    this.recordedAt,
    this.note,
  });

  final String id;
  final String riderName;
  final String outcome;
  final DateTime? recordedAt;
  final String? note;

  factory LocationVerification.fromJson(Map<String, dynamic> json) {
    return LocationVerification(
      id: jsonString(json, const ['id']) ?? '',
      riderName: jsonString(json, const ['riderName', 'rider']) ?? '',
      outcome: jsonString(json, const ['outcome', 'result', 'status']) ?? '',
      recordedAt: jsonDate(json, const [
        'recordedAt',
        'occurredAt',
        'verifiedAt',
      ]),
      note: jsonString(json, const ['note', 'detail']),
    );
  }

  static List<LocationVerification> listFromJson(Object? data) {
    return [
      for (final row in jsonRows(
        data,
        keys: const ['items', 'rows', 'verifications', 'results'],
      ))
        LocationVerification.fromJson(row),
    ];
  }
}
