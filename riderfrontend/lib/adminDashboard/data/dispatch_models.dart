import 'package:riderfrontend/adminDashboard/data/admin_format.dart';
import 'package:riderfrontend/adminDashboard/data/admin_json.dart';

/// Locked V1 dispatch cards. Values are omitted when the payload has no count.
const lockedDispatchKpiLabels = <String>[
  'Total',
  'Pending dispatch',
  'Assigned',
  'In progress',
];

class DispatchStatusTab {
  const DispatchStatusTab(this.value, this.label);

  final String value;
  final String label;
}

const dispatchStatusTabs = <DispatchStatusTab>[
  DispatchStatusTab('all', 'All'),
  DispatchStatusTab('pendingAssignment', 'Pending assignment'),
  DispatchStatusTab('assigned', 'Assigned'),
  DispatchStatusTab('inProgress', 'In progress'),
  DispatchStatusTab('completed', 'Completed'),
  DispatchStatusTab('cancelled', 'Cancelled'),
];

class DispatchKpi {
  const DispatchKpi({
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

class DispatchOrderSummary {
  const DispatchOrderSummary({
    this.kpis = const [],
    this.total,
    this.pendingDispatch,
    this.assigned,
    this.inProgress,
  });

  final List<DispatchKpi> kpis;
  final int? total;
  final int? pendingDispatch;
  final int? assigned;
  final int? inProgress;

  factory DispatchOrderSummary.fromJson(Object? data) {
    if (data is List) {
      return DispatchOrderSummary(kpis: _kpisFromList(data));
    }
    final map = jsonMap(data);
    if (map == null) return const DispatchOrderSummary();
    final source = jsonMap(jsonPick(map, const ['summary'])) ?? map;
    final listed = jsonPick(source, const ['kpis', 'cards', 'items']);
    final fromList = listed is List
        ? _kpisFromList(listed)
        : const <DispatchKpi>[];
    final total = optionalInt(source, const [
      'total',
      'totalOrders',
      'orderCount',
    ]);
    final pending = optionalInt(source, const [
      'pendingDispatch',
      'pendingAssignment',
      'pending',
    ]);
    final assigned = optionalInt(source, const ['assigned', 'assignedCount']);
    final inProgress = optionalInt(source, const [
      'inProgress',
      'inProgressCount',
    ]);
    final kpis = listed is List && fromList.isNotEmpty
        ? fromList
        : _kpisFromCounts(
            source,
            total: total,
            pending: pending,
            assigned: assigned,
            inProgress: inProgress,
          );
    return DispatchOrderSummary(
      kpis: kpis,
      total: total,
      pendingDispatch: pending,
      assigned: assigned,
      inProgress: inProgress,
    );
  }
}

List<DispatchKpi> _kpisFromList(List<dynamic> raw) {
  final cards = <DispatchKpi>[];
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
      DispatchKpi(
        key: key,
        label: label,
        value: value,
        detail: jsonString(row, const ['detail', 'subtitle', 'note']),
      ),
    );
  }
  return cards;
}

List<DispatchKpi> _kpisFromCounts(
  Map<String, dynamic> json, {
  required int? total,
  required int? pending,
  required int? assigned,
  required int? inProgress,
}) {
  DispatchKpi? card(String key, String label, int? count, List<String> details) {
    if (count == null) return null;
    return DispatchKpi(
      key: key,
      label: label,
      value: formatGrouped(count),
      detail: jsonString(json, details),
    );
  }

  return [
    ?card('total', lockedDispatchKpiLabels[0], total, const [
      'totalDetail',
      'totalOrdersDetail',
    ]),
    ?card('pendingDispatch', lockedDispatchKpiLabels[1], pending, const [
      'pendingDispatchDetail',
      'pendingDetail',
    ]),
    ?card('assigned', lockedDispatchKpiLabels[2], assigned, const [
      'assignedDetail',
    ]),
    ?card('inProgress', lockedDispatchKpiLabels[3], inProgress, const [
      'inProgressDetail',
    ]),
  ];
}

class DispatchStatusCounts {
  const DispatchStatusCounts({
    this.all,
    this.pendingAssignment,
    this.assigned,
    this.inProgress,
    this.completed,
    this.cancelled,
  });

  final int? all;
  final int? pendingAssignment;
  final int? assigned;
  final int? inProgress;
  final int? completed;
  final int? cancelled;

  int? countFor(String status) {
    return switch (status) {
      'all' => all,
      'pendingAssignment' => pendingAssignment,
      'assigned' => assigned,
      'inProgress' => inProgress,
      'completed' => completed,
      'cancelled' => cancelled,
      _ => null,
    };
  }

  factory DispatchStatusCounts.fromJson(Object? data) {
    if (data is List) return _countsFromRows(data);
    final map = jsonMap(data);
    if (map == null) return const DispatchStatusCounts();
    final listed = jsonPick(map, const [
      'counts',
      'statuses',
      'statusCounts',
      'items',
      'tabs',
    ]);
    if (listed is List) return _countsFromRows(listed);
    final nested = jsonMap(jsonPick(map, const ['counts', 'statusCounts']));
    return _countsFromMap(nested ?? map);
  }
}

DispatchStatusCounts _countsFromMap(Map<String, dynamic> json) {
  return DispatchStatusCounts(
    all: optionalInt(json, const ['all', 'total', 'allCount']),
    pendingAssignment: optionalInt(json, const [
      'pendingAssignment',
      'pendingDispatch',
      'pending',
    ]),
    assigned: optionalInt(json, const ['assigned', 'assignedCount']),
    inProgress: optionalInt(json, const ['inProgress', 'inProgressCount']),
    completed: optionalInt(json, const ['completed', 'delivered']),
    cancelled: optionalInt(json, const ['cancelled', 'canceled']),
  );
}

DispatchStatusCounts _countsFromRows(List<dynamic> rows) {
  int? all;
  int? pending;
  int? assigned;
  int? inProgress;
  int? completed;
  int? cancelled;
  for (final row in rows) {
    final map = jsonMap(row);
    if (map == null) continue;
    final status = _statusKey(
      jsonString(map, const ['status', 'key', 'name']) ?? '',
    );
    final count = optionalInt(map, const ['count', 'total', 'value']);
    switch (status) {
      case 'all':
      case 'total':
        all = count;
      case 'pendingassignment':
      case 'pendingdispatch':
      case 'pending':
        pending = count;
      case 'assigned':
        assigned = count;
      case 'inprogress':
        inProgress = count;
      case 'completed':
      case 'delivered':
        completed = count;
      case 'cancelled':
      case 'canceled':
        cancelled = count;
    }
  }
  return DispatchStatusCounts(
    all: all,
    pendingAssignment: pending,
    assigned: assigned,
    inProgress: inProgress,
    completed: completed,
    cancelled: cancelled,
  );
}

String dispatchTabText(DispatchStatusTab tab, DispatchStatusCounts? counts) {
  final count = counts?.countFor(tab.value);
  if (count == null) return tab.label;
  return '${tab.label} ($count)';
}

class DispatchOrderRow {
  const DispatchOrderRow({
    required this.id,
    this.reference = '',
    this.customerName = '',
    this.customerCode = '',
    this.address = '',
    this.scheduledDate = '',
    this.timeWindow = '',
    this.riderName = '',
    this.riderId = '',
    this.riderCode = '',
    this.estimatedValue,
    this.status = '',
    this.priority,
    this.origin = '',
  });

  final String id;
  final String reference;
  final String customerName;
  final String customerCode;
  final String address;
  final String scheduledDate;
  final String timeWindow;
  final String riderName;
  final String riderId;
  final String riderCode;
  final num? estimatedValue;
  final String status;
  final String? priority;
  final String origin;

  bool get scheduledByRider => origin.toLowerCase() == 'rider';

  String get displayReference => reference.isNotEmpty ? reference : id;

  bool get hasRider => riderName.trim().isNotEmpty || riderId.trim().isNotEmpty;

  factory DispatchOrderRow.fromJson(Map<String, dynamic> json) {
    final customer = jsonMap(jsonPick(json, const ['customer'])) ?? const {};
    final rider = jsonMap(jsonPick(json, const ['rider'])) ?? const {};
    final totals = jsonMap(jsonPick(json, const ['totals'])) ?? const {};
    return DispatchOrderRow(
      id: jsonString(json, const ['id', 'orderId']) ?? '',
      reference:
          jsonString(json, const [
            'referenceNumber',
            'reference',
            'orderNumber',
          ]) ??
          '',
      customerName:
          jsonString(json, const ['customerName']) ??
          jsonString(customer, const [
            'businessName',
            'name',
            'customerName',
          ]) ??
          _stringOrEmpty(jsonPick(json, const ['customer'])),
      customerCode:
          jsonString(json, const ['customerCode', 'code']) ??
          jsonString(customer, const ['code', 'customerCode']) ??
          '',
      address: _address(json, customer),
      scheduledDate:
          jsonString(json, const [
            'scheduledDate',
            'deliveryDate',
            'date',
          ]) ??
          '',
      timeWindow:
          jsonString(json, const [
            'timeSlot',
            'timeWindow',
            'window',
            'deliveryWindow',
          ]) ??
          '',
      riderName:
          jsonString(json, const ['riderName']) ??
          jsonString(rider, const ['fullName', 'name', 'riderName']) ??
          '',
      riderId:
          jsonString(json, const ['riderId']) ??
          jsonString(rider, const ['id', 'riderId']) ??
          '',
      riderCode:
          jsonString(json, const ['riderCode']) ??
          jsonString(rider, const ['riderCode', 'code']) ??
          '',
      estimatedValue: optionalNum(json, const [
            'estimatedValue',
            'value',
            'amount',
          ]) ??
          optionalNum(totals, const ['estimatedValue', 'value', 'amount']),
      status: jsonString(json, const ['dispatchStatus', 'status']) ?? '',
      priority: jsonString(json, const ['priority', 'priorityLabel']),
      origin: jsonString(json, const ['origin']) ?? '',
    );
  }
}

String _stringOrEmpty(Object? value) {
  if (value is String && value.trim().isNotEmpty) return value.trim();
  return '';
}

String _address(Map<String, dynamic> json, Map<String, dynamic> customer) {
  final direct = jsonString(json, const [
    'deliveryAddress',
    'address',
    'street',
  ]);
  if (direct != null) return direct;
  final parts = [
    jsonString(customer, const ['street', 'address']),
    jsonString(customer, const ['area']),
    jsonString(customer, const ['city']),
  ].whereType<String>();
  return parts.join(', ');
}

class DispatchOrderPage {
  const DispatchOrderPage({
    required this.rows,
    required this.page,
    required this.pageSize,
    this.totalRecords,
    this.totalPages,
  });

  final List<DispatchOrderRow> rows;
  final int page;
  final int pageSize;
  final int? totalRecords;
  final int? totalPages;

  factory DispatchOrderPage.fromParts(
    Object? data,
    Object? pagination, {
    required int page,
    required int pageSize,
  }) {
    final map = jsonMap(data);
    final meta = jsonMap(pagination);
    final rows = [
      for (final row in jsonRows(
        data,
        keys: const ['items', 'rows', 'orders', 'results'],
      ))
        if (DispatchOrderRow.fromJson(row) case final order)
          if (order.id.isNotEmpty) order,
    ];
    final total = meta != null
        ? optionalInt(meta, const ['totalRecords', 'total', 'totalCount'])
        : (map == null
              ? null
              : optionalInt(map, const [
                  'totalRecords',
                  'totalCount',
                  'total',
                ]));
    final size = meta == null
        ? pageSize
        : (optionalInt(meta, const ['pageSize']) ?? pageSize);
    final current = meta == null
        ? page
        : (optionalInt(meta, const ['page']) ?? page);
    final pages = meta == null ? null : optionalInt(meta, const ['totalPages']);
    final derivedPages =
        pages ??
        (total == null || size <= 0
            ? null
            : ((total + size - 1) / size).ceil());
    return DispatchOrderPage(
      rows: rows,
      page: current,
      pageSize: size,
      totalRecords: total,
      totalPages: derivedPages,
    );
  }
}

String dispatchPageLabel({
  required int page,
  required int pageSize,
  required int rowCount,
  int? totalRecords,
  int? totalPages,
}) {
  if (totalRecords == null) {
    return totalPages == null ? 'Page $page' : 'Page $page of $totalPages';
  }
  if (totalRecords == 0 || rowCount == 0) {
    return 'Showing 0 of $totalRecords';
  }
  final start = ((page - 1) * pageSize) + 1;
  final end = start + rowCount - 1;
  return 'Showing $start–$end of $totalRecords';
}

num? combinedEstimatedValue(Iterable<num?> values) {
  num? total;
  for (final value in values) {
    if (value == null) continue;
    total = (total ?? 0) + value;
  }
  return total;
}

bool dispatchStatusIsClosed(String status) {
  final value = _statusKey(status);
  return value == 'cancelled' ||
      value == 'canceled' ||
      value == 'completed' ||
      value == 'delivered';
}

String _statusKey(String status) =>
    status.toLowerCase().replaceAll(' ', '').replaceAll('_', '');

class DispatchOrderItem {
  const DispatchOrderItem({
    this.id = '',
    this.name = '',
    this.sku = '',
    this.quantity,
    this.unit = '',
    this.unitPrice,
    this.lineTotal,
  });

  final String id;
  final String name;
  final String sku;
  final int? quantity;
  final String unit;
  final num? unitPrice;
  final num? lineTotal;

  factory DispatchOrderItem.fromJson(Map<String, dynamic> json) {
    final quantity = optionalInt(json, const ['quantity', 'qty']);
    final unitPrice = optionalNum(json, const ['unitPrice', 'price']);
    final explicit = optionalNum(json, const [
      'lineTotal',
      'subtotal',
      'total',
    ]);
    return DispatchOrderItem(
      id: jsonString(json, const ['id', 'lineId']) ?? '',
      name:
          jsonString(json, const [
            'name',
            'description',
            'productName',
          ]) ??
          '',
      sku:
          jsonString(json, const [
            'sku',
            'code',
            'productCode',
          ]) ??
          '',
      quantity: quantity,
      unit: jsonString(json, const ['unit', 'unitLabel']) ?? '',
      unitPrice: unitPrice,
      lineTotal:
          explicit ??
          (quantity != null && unitPrice != null ? quantity * unitPrice : null),
    );
  }

  static List<DispatchOrderItem> listFromJson(Object? data) {
    return [
      for (final row in jsonRows(
        data,
        keys: const ['items', 'lines', 'orderLines', 'rows', 'results'],
      ))
        if (DispatchOrderItem.fromJson(row) case final item)
          if (item.name.isNotEmpty || item.sku.isNotEmpty) item,
    ];
  }
}

class DispatchLifecycleEvent {
  const DispatchLifecycleEvent({
    this.id = '',
    this.title = '',
    this.detail = '',
    this.occurredAt,
  });

  final String id;
  final String title;
  final String detail;
  final DateTime? occurredAt;

  factory DispatchLifecycleEvent.fromJson(Map<String, dynamic> json) {
    return DispatchLifecycleEvent(
      id: jsonString(json, const ['id']) ?? '',
      title:
          jsonString(json, const [
            'title',
            'name',
            'action',
            'event',
          ]) ??
          '',
      detail:
          jsonString(json, const [
            'detail',
            'description',
            'message',
          ]) ??
          '',
      occurredAt: jsonDate(json, const [
        'occurredAt',
        'timestamp',
        'at',
        'createdAt',
      ]),
    );
  }

  static List<DispatchLifecycleEvent> listFromJson(Object? data) {
    return [
      for (final row in jsonRows(
        data,
        keys: const ['items', 'events', 'lifecycle', 'timeline', 'rows'],
      ))
        if (DispatchLifecycleEvent.fromJson(row) case final event)
          if (event.title.isNotEmpty || event.detail.isNotEmpty) event,
    ];
  }
}

class DispatchOrderDetail {
  const DispatchOrderDetail({
    required this.order,
    this.notes,
    this.vehicleName = '',
    this.phone = '',
    this.items = const [],
    this.events = const [],
  });

  final DispatchOrderRow order;
  final String? notes;
  final String vehicleName;
  final String phone;
  final List<DispatchOrderItem> items;
  final List<DispatchLifecycleEvent> events;

  bool get hasIdentity =>
      order.id.isNotEmpty || order.reference.isNotEmpty || order.customerName.isNotEmpty;

  factory DispatchOrderDetail.fromJson(Map<String, dynamic> json) {
    final itemData = jsonPick(json, const ['items', 'lines', 'orderLines']);
    final eventData = jsonPick(json, const ['lifecycle', 'events', 'timeline']);
    final rider = jsonMap(jsonPick(json, const ['rider'])) ?? const {};
    final customer = jsonMap(jsonPick(json, const ['customer'])) ?? const {};
    return DispatchOrderDetail(
      order: DispatchOrderRow.fromJson(json),
      notes: jsonString(json, const ['notes', 'note', 'dispatcherNote']),
      vehicleName:
          jsonString(json, const ['vehicleName', 'vehicle']) ??
          jsonString(rider, const ['vehicleName', 'vehicle']) ??
          '',
      phone: jsonString(json, const ['phone', 'customerPhone']) ??
          jsonString(customer, const ['phone', 'primaryMobile']) ??
          '',
      items: itemData == null
          ? const []
          : DispatchOrderItem.listFromJson(itemData),
      events: eventData == null
          ? const []
          : DispatchLifecycleEvent.listFromJson(eventData),
    );
  }
}

class DispatchPickList {
  const DispatchPickList({this.lines = const [], this.message});

  final List<DispatchOrderItem> lines;
  final String? message;

  factory DispatchPickList.fromJson(Object? data, {String? message}) {
    final map = jsonMap(data);
    final serverMessage = map == null
        ? null
        : jsonString(map, const ['message', 'detail', 'note']);
    final combined = (message ?? serverMessage)?.trim();
    return DispatchPickList(
      lines: DispatchOrderItem.listFromJson(data),
      message: combined == null || combined.isEmpty ? null : combined,
    );
  }
}

class DispatchActionResult {
  const DispatchActionResult({
    required this.message,
    this.orderId,
    this.status,
  });

  final String message;
  final String? orderId;
  final String? status;

  String get notice {
    if (message.trim().isNotEmpty) return message.trim();
    return 'The order was updated.';
  }

  factory DispatchActionResult.fromJson(Object? data, {String? message}) {
    final json = jsonMap(data) ?? const <String, dynamic>{};
    final text = (message ?? jsonString(json, const ['message']) ?? '').trim();
    return DispatchActionResult(
      message: text,
      orderId: jsonString(json, const ['id', 'orderId']),
      status: jsonString(json, const ['status']),
    );
  }
}

class EligibleRider {
  const EligibleRider({
    required this.id,
    required this.fullName,
    this.riderCode = '',
    this.routeName = '',
    this.status = '',
  });

  final String id;
  final String fullName;
  final String riderCode;
  final String routeName;
  final String status;

  factory EligibleRider.fromJson(Map<String, dynamic> json) {
    return EligibleRider(
      id: jsonString(json, const ['id', 'riderId']) ?? '',
      fullName:
          jsonString(json, const ['fullName', 'name', 'riderName']) ?? '',
      riderCode: jsonString(json, const ['riderCode', 'code']) ?? '',
      routeName: jsonString(json, const ['routeName', 'route']) ?? '',
      status: jsonString(json, const ['status']) ?? '',
    );
  }

  static List<EligibleRider> listFromJson(Object? data) {
    return [
      for (final row in jsonRows(
        data,
        keys: const ['items', 'riders', 'results', 'rows'],
      ))
        if (EligibleRider.fromJson(row) case final rider)
          if (rider.id.isNotEmpty) rider,
    ];
  }
}

class DispatchZoneSummary {
  const DispatchZoneSummary({
    required this.name,
    this.detail = '',
    this.activeStops,
    this.orderCount,
  });

  final String name;
  final String detail;
  final int? activeStops;
  final int? orderCount;
}

class DispatchShiftProgress {
  const DispatchShiftProgress({
    this.completed,
    this.target,
    this.averageStopMinutes,
    this.firstAttemptPercent,
  });

  final int? completed;
  final int? target;
  final num? averageStopMinutes;
  final num? firstAttemptPercent;

  bool get hasTarget => target != null;

  double? get percent {
    final goal = target;
    final done = completed;
    if (goal == null || goal <= 0 || done == null) return null;
    return done / goal;
  }
}

class DispatchOperationalSummary {
  const DispatchOperationalSummary({
    this.zones = const [],
    this.shift = const DispatchShiftProgress(),
  });

  final List<DispatchZoneSummary> zones;
  final DispatchShiftProgress shift;

  factory DispatchOperationalSummary.fromJson(Object? data) {
    final map = jsonMap(data);
    if (map == null) return const DispatchOperationalSummary();
    final zoneData = jsonPick(map, const ['zones', 'routes', 'areas']);
    final zones = zoneData == null
        ? const <DispatchZoneSummary>[]
        : [
            for (final row in jsonRows(
              zoneData,
              keys: const ['items', 'zones', 'routes', 'rows'],
            ))
              ?_zoneFromJson(row),
          ];
    final shiftMap =
        jsonMap(jsonPick(map, const ['shift', 'shiftProgress'])) ?? map;
    return DispatchOperationalSummary(
      zones: zones,
      shift: DispatchShiftProgress(
        completed: optionalInt(shiftMap, const [
          'completedDeliveries',
          'completed',
          'deliveriesCompleted',
        ]),
        target: optionalInt(shiftMap, const [
          'targetDeliveries',
          'target',
          'shiftTarget',
        ]),
        averageStopMinutes: optionalNum(shiftMap, const [
          'averageStopDurationMinutes',
          'averageStopMinutes',
        ]),
        firstAttemptPercent: optionalNum(shiftMap, const [
          'firstAttemptSuccessPercent',
          'firstAttemptPercent',
        ]),
      ),
    );
  }
}

DispatchZoneSummary? _zoneFromJson(Map<String, dynamic> json) {
  final name = operationsDisplayText(
    jsonString(json, const ['name', 'zoneName', 'routeName']),
  );
  if (name == null) return null;
  return DispatchZoneSummary(
    name: name,
    detail:
        operationsDisplayText(
          jsonString(json, const ['detail', 'note', 'sector']),
        ) ??
        '',
    activeStops: optionalInt(json, const [
      'activeStops',
      'stops',
      'stopCount',
    ]),
    orderCount: optionalInt(json, const ['orderCount', 'orders']),
  );
}

String formatDispatchDate(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return '';
  final parsed = DateTime.tryParse(trimmed);
  if (parsed == null) return trimmed;
  return formatAdminDay(parsed.toLocal());
}

String formatDispatchNumber(num value) {
  if ((value - value.round()).abs() < 0.0000001) {
    return formatGrouped(value.round());
  }
  return value.toString();
}
