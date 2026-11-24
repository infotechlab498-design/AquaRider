class RecurringBoard {
  const RecurringBoard({
    required this.activePlans,
    required this.deliveriesThisMonth,
    required this.paused,
    required this.unassigned,
    required this.ridersAssigned,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.tabs,
    required this.rows,
    required this.depots,
  });

  final int activePlans;
  final int deliveriesThisMonth;
  final int paused;
  final int unassigned;
  final int ridersAssigned;
  final int total;
  final int page;
  final int pageSize;
  final RecurringTabCounts tabs;
  final List<RecurringScheduleRow> rows;
  final List<ScheduleDepotOption> depots;

  static const empty = RecurringBoard(
    activePlans: 0,
    deliveriesThisMonth: 0,
    paused: 0,
    unassigned: 0,
    ridersAssigned: 0,
    total: 0,
    page: 1,
    pageSize: 20,
    tabs: RecurringTabCounts.empty,
    rows: [],
    depots: [],
  );

  factory RecurringBoard.fromJson(Map<String, dynamic> json) {
    return RecurringBoard(
      activePlans: _int(json['activePlans']),
      deliveriesThisMonth: _int(json['deliveriesThisMonth']),
      paused: _int(json['paused']),
      unassigned: _int(json['unassigned']),
      ridersAssigned: _int(json['ridersAssigned']),
      total: _int(json['total']),
      page: _int(json['page'], fallback: 1),
      pageSize: _int(json['pageSize'], fallback: 20),
      tabs: json['tabs'] is Map
          ? RecurringTabCounts.fromJson(Map<String, dynamic>.from(json['tabs'] as Map))
          : RecurringTabCounts.empty,
      rows: [
        for (final row in _list(json['rows'])) RecurringScheduleRow.fromJson(row),
      ],
      depots: [
        for (final row in _list(json['depots'])) ScheduleDepotOption.fromJson(row),
      ],
    );
  }
}

class RecurringTabCounts {
  const RecurringTabCounts({
    required this.all,
    required this.weekly,
    required this.monthly,
    required this.paused,
    required this.expiring,
    required this.exceptions,
    required this.unassigned,
  });

  final int all;
  final int weekly;
  final int monthly;
  final int paused;
  final int expiring;
  final int exceptions;
  final int unassigned;

  static const empty = RecurringTabCounts(
    all: 0,
    weekly: 0,
    monthly: 0,
    paused: 0,
    expiring: 0,
    exceptions: 0,
    unassigned: 0,
  );

  factory RecurringTabCounts.fromJson(Map<String, dynamic> json) {
    return RecurringTabCounts(
      all: _int(json['all']),
      weekly: _int(json['weekly']),
      monthly: _int(json['monthly']),
      paused: _int(json['paused']),
      expiring: _int(json['expiring']),
      exceptions: _int(json['exceptions']),
      unassigned: _int(json['unassigned']),
    );
  }
}

class ScheduleDepotOption {
  const ScheduleDepotOption({required this.id, required this.name});

  final String id;
  final String name;

  factory ScheduleDepotOption.fromJson(Map<String, dynamic> json) {
    return ScheduleDepotOption(id: '${json['id'] ?? ''}', name: '${json['name'] ?? ''}');
  }
}

class RecurringScheduleRow {
  const RecurringScheduleRow({
    required this.id,
    required this.scheduleCode,
    required this.customerId,
    required this.customerName,
    required this.customerCode,
    required this.phone,
    required this.address,
    required this.productSummary,
    required this.quantityPerVisit,
    required this.frequency,
    required this.monthlyCount,
    required this.riderId,
    required this.riderName,
    required this.riderCode,
    required this.nextDate,
    required this.status,
    required this.version,
  });

  final String id;
  final String scheduleCode;
  final String customerId;
  final String customerName;
  final String customerCode;
  final String phone;
  final String address;
  final String productSummary;
  final int quantityPerVisit;
  final String frequency;
  final int monthlyCount;
  final String? riderId;
  final String? riderName;
  final String? riderCode;
  final String? nextDate;
  final String status;
  final int version;

  factory RecurringScheduleRow.fromJson(Map<String, dynamic> json) {
    return RecurringScheduleRow(
      id: '${json['id'] ?? ''}',
      scheduleCode: '${json['scheduleCode'] ?? ''}',
      customerId: '${json['customerId'] ?? ''}',
      customerName: '${json['customerName'] ?? ''}',
      customerCode: '${json['customerCode'] ?? ''}',
      phone: '${json['phone'] ?? ''}',
      address: '${json['address'] ?? ''}',
      productSummary: '${json['productSummary'] ?? ''}',
      quantityPerVisit: _int(json['quantityPerVisit']),
      frequency: '${json['frequency'] ?? ''}',
      monthlyCount: _int(json['monthlyCount']),
      riderId: json['riderId'] as String?,
      riderName: json['riderName'] as String?,
      riderCode: json['riderCode'] as String?,
      nextDate: json['nextDate'] as String?,
      status: '${json['status'] ?? ''}',
      version: _int(json['version'], fallback: 1),
    );
  }
}

class RecurringScheduleDetail {
  const RecurringScheduleDetail({
    required this.id,
    required this.scheduleCode,
    required this.status,
    required this.version,
    required this.customerId,
    required this.customerName,
    required this.customerCode,
    required this.phone,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.routeName,
    required this.depotName,
    required this.depotId,
    required this.riderId,
    required this.riderName,
    required this.riderCode,
    required this.riderActive,
    required this.shiftOpen,
    required this.riderWorkload,
    required this.frequency,
    required this.interval,
    required this.weekdays,
    required this.monthDays,
    required this.customDates,
    required this.startDate,
    required this.endDate,
    required this.timeWindow,
    required this.timeZoneId,
    required this.autoPublish,
    required this.publicationTime,
    required this.assignmentMode,
    required this.instructions,
    required this.monthlyCount,
    required this.monthlyBottles,
    required this.lines,
    required this.exceptions,
    required this.monthDayRule,
  });

  final String id;
  final String scheduleCode;
  final String status;
  final int version;
  final String customerId;
  final String customerName;
  final String customerCode;
  final String phone;
  final String address;
  final num? latitude;
  final num? longitude;
  final String routeName;
  final String depotName;
  final String depotId;
  final String? riderId;
  final String? riderName;
  final String? riderCode;
  final bool riderActive;
  final bool shiftOpen;
  final int riderWorkload;
  final String frequency;
  final int interval;
  final List<int> weekdays;
  final List<int> monthDays;
  final List<String> customDates;
  final String startDate;
  final String? endDate;
  final String timeWindow;
  final String timeZoneId;
  final bool autoPublish;
  final String publicationTime;
  final String assignmentMode;
  final String? instructions;
  final int monthlyCount;
  final int monthlyBottles;
  final List<ScheduleLine> lines;
  final List<ScheduleExceptionRow> exceptions;
  final String monthDayRule;

  factory RecurringScheduleDetail.fromJson(Map<String, dynamic> json) {
    return RecurringScheduleDetail(
      id: '${json['id'] ?? ''}',
      scheduleCode: '${json['scheduleCode'] ?? ''}',
      status: '${json['status'] ?? ''}',
      version: _int(json['version'], fallback: 1),
      customerId: '${json['customerId'] ?? ''}',
      customerName: '${json['customerName'] ?? ''}',
      customerCode: '${json['customerCode'] ?? ''}',
      phone: '${json['phone'] ?? ''}',
      address: '${json['address'] ?? ''}',
      latitude: json['latitude'] as num?,
      longitude: json['longitude'] as num?,
      routeName: '${json['routeName'] ?? ''}',
      depotName: '${json['depotName'] ?? ''}',
      depotId: '${json['depotId'] ?? ''}',
      riderId: json['riderId'] as String?,
      riderName: json['riderName'] as String?,
      riderCode: json['riderCode'] as String?,
      riderActive: json['riderActive'] == true,
      shiftOpen: json['shiftOpen'] == true,
      riderWorkload: _int(json['riderWorkload']),
      frequency: '${json['frequency'] ?? 'Weekly'}',
      interval: _int(json['interval'], fallback: 1),
      weekdays: _ints(json['weekdays']),
      monthDays: _ints(json['monthDays']),
      customDates: _strings(json['customDates']),
      startDate: '${json['startDate'] ?? ''}',
      endDate: json['endDate'] as String?,
      timeWindow: '${json['timeWindow'] ?? 'Morning'}',
      timeZoneId: '${json['timeZoneId'] ?? 'Asia/Karachi'}',
      autoPublish: json['autoPublish'] != false,
      publicationTime: '${json['publicationTime'] ?? '05:00'}',
      assignmentMode: '${json['assignmentMode'] ?? 'Fixed'}',
      instructions: json['instructions'] as String?,
      monthlyCount: _int(json['monthlyCount']),
      monthlyBottles: _int(json['monthlyBottles']),
      lines: [for (final row in _list(json['lines'])) ScheduleLine.fromJson(row)],
      exceptions: [
        for (final row in _list(json['exceptions'])) ScheduleExceptionRow.fromJson(row),
      ],
      monthDayRule: '${json['monthDayRule'] ?? ''}',
    );
  }
}

class ScheduleLine {
  const ScheduleLine({
    required this.productId,
    required this.name,
    required this.sku,
    required this.unitLabel,
    required this.quantity,
    required this.expectedEmpties,
    required this.unitPrice,
  });

  final String productId;
  final String name;
  final String sku;
  final String unitLabel;
  final int quantity;
  final int expectedEmpties;
  final num unitPrice;

  factory ScheduleLine.fromJson(Map<String, dynamic> json) {
    return ScheduleLine(
      productId: '${json['productId'] ?? ''}',
      name: '${json['name'] ?? ''}',
      sku: '${json['sku'] ?? ''}',
      unitLabel: '${json['unitLabel'] ?? ''}',
      quantity: _int(json['quantity']),
      expectedEmpties: _int(json['expectedEmpties']),
      unitPrice: json['unitPrice'] as num? ?? 0,
    );
  }
}

class ScheduleExceptionRow {
  const ScheduleExceptionRow({
    required this.id,
    required this.startDate,
    required this.endDate,
    required this.reason,
    required this.status,
  });

  final String id;
  final String startDate;
  final String endDate;
  final String reason;
  final String status;

  factory ScheduleExceptionRow.fromJson(Map<String, dynamic> json) {
    return ScheduleExceptionRow(
      id: '${json['id'] ?? ''}',
      startDate: '${json['startDate'] ?? ''}',
      endDate: '${json['endDate'] ?? ''}',
      reason: '${json['reason'] ?? ''}',
      status: '${json['status'] ?? ''}',
    );
  }
}

class SchedulePreview {
  const SchedulePreview({
    required this.dates,
    required this.totalDeliveries,
    required this.totalBottles,
    required this.monthDayRule,
  });

  final List<String> dates;
  final int totalDeliveries;
  final int totalBottles;
  final String monthDayRule;

  factory SchedulePreview.fromJson(Map<String, dynamic> json) {
    return SchedulePreview(
      dates: _strings(json['dates']),
      totalDeliveries: _int(json['totalDeliveries']),
      totalBottles: _int(json['totalBottles']),
      monthDayRule: '${json['monthDayRule'] ?? ''}',
    );
  }
}

class ScheduleCalendar {
  const ScheduleCalendar({required this.year, required this.month, required this.days});

  final int year;
  final int month;
  final List<ScheduleCalendarDay> days;

  factory ScheduleCalendar.fromJson(Map<String, dynamic> json) {
    return ScheduleCalendar(
      year: _int(json['year']),
      month: _int(json['month']),
      days: [for (final row in _list(json['days'])) ScheduleCalendarDay.fromJson(row)],
    );
  }
}

class ScheduleCalendarDay {
  const ScheduleCalendarDay({
    required this.date,
    required this.deliveries,
    required this.bottles,
    required this.items,
  });

  final String date;
  final int deliveries;
  final int bottles;
  final List<ScheduleCalendarItem> items;

  factory ScheduleCalendarDay.fromJson(Map<String, dynamic> json) {
    return ScheduleCalendarDay(
      date: '${json['date'] ?? ''}',
      deliveries: _int(json['deliveries']),
      bottles: _int(json['bottles']),
      items: [for (final row in _list(json['items'])) ScheduleCalendarItem.fromJson(row)],
    );
  }
}

class ScheduleCalendarItem {
  const ScheduleCalendarItem({
    required this.occurrenceId,
    required this.scheduleId,
    required this.scheduleCode,
    required this.customerName,
    required this.customerCode,
    required this.address,
    required this.productSummary,
    required this.quantity,
    required this.timeWindow,
    required this.riderId,
    required this.riderName,
    required this.riderCode,
    required this.status,
  });

  final String occurrenceId;
  final String scheduleId;
  final String scheduleCode;
  final String customerName;
  final String customerCode;
  final String address;
  final String productSummary;
  final int quantity;
  final String timeWindow;
  final String? riderId;
  final String? riderName;
  final String? riderCode;
  final String status;

  factory ScheduleCalendarItem.fromJson(Map<String, dynamic> json) {
    return ScheduleCalendarItem(
      occurrenceId: '${json['occurrenceId'] ?? ''}',
      scheduleId: '${json['scheduleId'] ?? ''}',
      scheduleCode: '${json['scheduleCode'] ?? ''}',
      customerName: '${json['customerName'] ?? ''}',
      customerCode: '${json['customerCode'] ?? ''}',
      address: '${json['address'] ?? ''}',
      productSummary: '${json['productSummary'] ?? ''}',
      quantity: _int(json['quantity']),
      timeWindow: '${json['timeWindow'] ?? ''}',
      riderId: json['riderId'] as String?,
      riderName: json['riderName'] as String?,
      riderCode: json['riderCode'] as String?,
      status: '${json['status'] ?? ''}',
    );
  }
}

int _int(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? fallback;
}

List<int> _ints(Object? value) {
  if (value is! List) return const [];
  return [for (final item in value) _int(item)];
}

List<String> _strings(Object? value) {
  if (value is! List) return const [];
  return [for (final item in value) '$item'];
}

List<Map<String, dynamic>> _list(Object? value) {
  if (value is! List) return const [];
  return [
    for (final item in value)
      if (item is Map) Map<String, dynamic>.from(item),
  ];
}
