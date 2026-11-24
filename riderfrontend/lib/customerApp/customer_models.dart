class CustomerPlan {
  const CustomerPlan({
    required this.scheduleId,
    required this.code,
    required this.status,
    required this.product,
    required this.quantity,
    required this.frequency,
    required this.startDate,
    required this.address,
    required this.timeWindow,
    this.endDate,
    this.riderName,
    this.depotName = '',
    this.zoneName = '',
    this.addressLabel = 'Route address',
  });

  final String scheduleId;
  final String code;
  final String status;
  final String product;
  final int quantity;
  final String frequency;
  final String startDate;
  final String? endDate;
  final String address;
  final String timeWindow;
  final String? riderName;
  final String depotName;
  final String zoneName;
  final String addressLabel;

  factory CustomerPlan.fromJson(Map<String, dynamic> map) {
    return CustomerPlan(
      scheduleId: _s(map, 'scheduleId'),
      code: _s(map, 'code'),
      status: _s(map, 'status'),
      product: _s(map, 'product'),
      quantity: _i(map, 'quantity'),
      frequency: _s(map, 'frequency'),
      startDate: _s(map, 'startDate'),
      endDate: _optional(map, 'endDate'),
      address: _s(map, 'address'),
      timeWindow: _s(map, 'timeWindow'),
      riderName: _optional(map, 'riderName'),
      depotName: _s(map, 'depotName'),
      zoneName: _s(map, 'zoneName'),
      addressLabel: _s(map, 'addressLabel').isEmpty ? 'Route address' : _s(map, 'addressLabel'),
    );
  }
}

class CustomerCounts {
  const CustomerCounts({
    required this.scheduled,
    required this.completed,
    required this.upcoming,
    required this.skippedOrCancelled,
    this.total = 0,
  });

  final int scheduled;
  final int completed;
  final int upcoming;
  final int skippedOrCancelled;
  final int total;

  factory CustomerCounts.fromJson(Map<String, dynamic>? map) {
    final row = map ?? const <String, dynamic>{};
    return CustomerCounts(
      scheduled: _i(row, 'scheduled'),
      completed: _i(row, 'completed'),
      upcoming: _i(row, 'upcoming'),
      skippedOrCancelled: _i(row, 'skippedOrCancelled'),
      total: _i(row, 'total'),
    );
  }
}

class CustomerMoney {
  const CustomerMoney({
    required this.totalBilled,
    required this.totalPaid,
    required this.outstanding,
    required this.overdue,
    required this.note,
    this.lastPaymentDate,
    this.lastPaymentAmount,
  });

  final num totalBilled;
  final num totalPaid;
  final num outstanding;
  final num overdue;
  final String? lastPaymentDate;
  final num? lastPaymentAmount;
  final String note;

  factory CustomerMoney.fromJson(Map<String, dynamic>? map) {
    final row = map ?? const <String, dynamic>{};
    return CustomerMoney(
      totalBilled: _n(row, 'totalBilled'),
      totalPaid: _n(row, 'totalPaid'),
      outstanding: _n(row, 'outstanding'),
      overdue: _n(row, 'overdue'),
      lastPaymentDate: _optional(row, 'lastPaymentDate'),
      lastPaymentAmount: row['lastPaymentAmount'] == null ? null : _n(row, 'lastPaymentAmount'),
      note: _s(row, 'note'),
    );
  }
}

class CustomerVisit {
  const CustomerVisit({
    required this.date,
    required this.quantity,
    required this.status,
    required this.address,
    required this.timeWindow,
    required this.reference,
    required this.product,
    this.completedAt,
    this.proof,
    this.weekday = '',
    this.addressLabel = 'Route address',
    this.scheduleCode = '',
    this.scheduleId = '',
    this.addressFromSnapshot = false,
    this.instructions,
  });

  final String date;
  final int quantity;
  final String status;
  final String address;
  final String timeWindow;
  final String reference;
  final String product;
  final String? completedAt;
  final String? proof;
  final String weekday;
  final String addressLabel;
  final String scheduleCode;
  final String scheduleId;
  final bool addressFromSnapshot;
  final String? instructions;

  factory CustomerVisit.fromJson(Map<String, dynamic> map) {
    return CustomerVisit(
      date: _s(map, 'date'),
      quantity: _i(map, 'quantity'),
      status: _s(map, 'status'),
      address: _s(map, 'address'),
      timeWindow: _s(map, 'timeWindow'),
      reference: _s(map, 'reference'),
      product: _s(map, 'product'),
      completedAt: _optional(map, 'completedAt'),
      proof: _optional(map, 'proof'),
      weekday: _s(map, 'weekday'),
      addressLabel: _s(map, 'addressLabel').isEmpty ? 'Route address' : _s(map, 'addressLabel'),
      scheduleCode: _s(map, 'scheduleCode'),
      scheduleId: _s(map, 'scheduleId'),
      addressFromSnapshot: map['addressFromSnapshot'] == true,
      instructions: _optional(map, 'instructions'),
    );
  }
}

class CustomerHome {
  const CustomerHome({
    required this.firstName,
    required this.fullName,
    required this.customerCode,
    required this.accountStatus,
    required this.linked,
    required this.linkMessage,
    required this.overview,
    required this.payments,
    required this.upcoming,
    required this.unreadNotifications,
    this.subscription,
    this.activeSchedules = 0,
    this.city = '',
    this.pendingRequests = 0,
  });

  final String firstName;
  final String fullName;
  final String customerCode;
  final String accountStatus;
  final bool linked;
  final String linkMessage;
  final CustomerPlan? subscription;
  final CustomerCounts overview;
  final CustomerMoney payments;
  final List<CustomerVisit> upcoming;
  final int unreadNotifications;
  final int activeSchedules;
  final String city;
  final int pendingRequests;

  factory CustomerHome.fromJson(Map<String, dynamic> map) {
    final subscription = map['subscription'];
    return CustomerHome(
      firstName: _s(map, 'firstName'),
      fullName: _s(map, 'fullName'),
      customerCode: _s(map, 'customerCode'),
      accountStatus: _s(map, 'accountStatus'),
      linked: map['linked'] == true,
      linkMessage: _s(map, 'linkMessage'),
      subscription: subscription is Map ? CustomerPlan.fromJson(Map<String, dynamic>.from(subscription)) : null,
      overview: CustomerCounts.fromJson(_map(map['overview'])),
      payments: CustomerMoney.fromJson(_map(map['payments'])),
      upcoming: _list(map['upcoming'], CustomerVisit.fromJson),
      unreadNotifications: _i(map, 'unreadNotifications'),
      activeSchedules: _i(map, 'activeSchedules'),
      city: _s(map, 'city'),
      pendingRequests: _i(map, 'pendingRequests'),
    );
  }
}

class CustomerCalendarDay {
  const CustomerCalendarDay({
    required this.date,
    required this.status,
    required this.count,
    required this.items,
  });

  final String date;
  final String status;
  final int count;
  final List<CustomerVisit> items;

  factory CustomerCalendarDay.fromJson(Map<String, dynamic> map) {
    return CustomerCalendarDay(
      date: _s(map, 'date'),
      status: _s(map, 'status'),
      count: _i(map, 'count'),
      items: _list(map['items'], CustomerVisit.fromJson),
    );
  }
}

class CustomerCalendar {
  const CustomerCalendar({required this.year, required this.month, required this.days});

  final int year;
  final int month;
  final List<CustomerCalendarDay> days;

  factory CustomerCalendar.fromJson(Map<String, dynamic> map) {
    return CustomerCalendar(
      year: _i(map, 'year'),
      month: _i(map, 'month'),
      days: _list(map['days'], CustomerCalendarDay.fromJson),
    );
  }
}

class CustomerPaymentRow {
  const CustomerPaymentRow({
    required this.reference,
    required this.date,
    required this.amount,
    required this.method,
    required this.status,
    this.relatedReference,
  });

  final String reference;
  final String date;
  final num amount;
  final String method;
  final String status;
  final String? relatedReference;

  factory CustomerPaymentRow.fromJson(Map<String, dynamic> map) {
    return CustomerPaymentRow(
      reference: _s(map, 'reference'),
      date: _s(map, 'date'),
      amount: _n(map, 'amount'),
      method: _s(map, 'method'),
      status: _s(map, 'status'),
      relatedReference: _optional(map, 'relatedReference'),
    );
  }
}

class CustomerInvoiceDetail {
  const CustomerInvoiceDetail({
    required this.number,
    required this.date,
    required this.amount,
    required this.paid,
    required this.remaining,
    required this.status,
    required this.lines,
    required this.payments,
    required this.pdfNote,
  });

  final String number;
  final String date;
  final num amount;
  final num paid;
  final num remaining;
  final String status;
  final List<CustomerInvoiceLine> lines;
  final List<CustomerPaymentRow> payments;
  final String pdfNote;

  factory CustomerInvoiceDetail.fromJson(Map<String, dynamic> map) {
    return CustomerInvoiceDetail(
      number: _s(map, 'number'),
      date: _s(map, 'date'),
      amount: _n(map, 'amount'),
      paid: _n(map, 'paid'),
      remaining: _n(map, 'remaining'),
      status: _s(map, 'status'),
      lines: _list(map['lines'], CustomerInvoiceLine.fromJson),
      payments: _list(map['payments'], CustomerPaymentRow.fromJson),
      pdfNote: _s(map, 'pdfNote'),
    );
  }
}

class CustomerInvoiceLine {
  const CustomerInvoiceLine({required this.product, required this.quantity, required this.unitPrice, required this.amount});

  final String product;
  final int quantity;
  final num unitPrice;
  final num amount;

  factory CustomerInvoiceLine.fromJson(Map<String, dynamic> map) {
    return CustomerInvoiceLine(product: _s(map, 'product'), quantity: _i(map, 'quantity'), unitPrice: _n(map, 'unitPrice'), amount: _n(map, 'amount'));
  }
}

class CustomerInvoiceRow {
  const CustomerInvoiceRow({
    required this.number,
    required this.date,
    required this.amount,
    required this.paid,
    required this.remaining,
    required this.status,
  });

  final String number;
  final String date;
  final num amount;
  final num paid;
  final num remaining;
  final String status;

  factory CustomerInvoiceRow.fromJson(Map<String, dynamic> map) {
    return CustomerInvoiceRow(
      number: _s(map, 'number'),
      date: _s(map, 'date'),
      amount: _n(map, 'amount'),
      paid: _n(map, 'paid'),
      remaining: _n(map, 'remaining'),
      status: _s(map, 'status'),
    );
  }
}

class CustomerPayments {
  const CustomerPayments({required this.summary, required this.payments, required this.invoices});

  final CustomerMoney summary;
  final List<CustomerPaymentRow> payments;
  final List<CustomerInvoiceRow> invoices;

  factory CustomerPayments.fromJson(Map<String, dynamic> map) {
    return CustomerPayments(
      summary: CustomerMoney.fromJson(_map(map['summary'])),
      payments: _list(map['payments'], CustomerPaymentRow.fromJson),
      invoices: _list(map['invoices'], CustomerInvoiceRow.fromJson),
    );
  }
}

class CustomerRequestPreview {
  const CustomerRequestPreview({
    required this.summary,
    required this.affectedDates,
    required this.scheduledCount,
    required this.publishedCount,
    required this.completedCount,
    required this.dispatchedNote,
    required this.inventoryNote,
    required this.pricingNote,
  });

  final String summary;
  final String affectedDates;
  final int scheduledCount;
  final int publishedCount;
  final int completedCount;
  final String dispatchedNote;
  final String inventoryNote;
  final String pricingNote;

  factory CustomerRequestPreview.fromJson(Map<String, dynamic> map) {
    return CustomerRequestPreview(
      summary: _s(map, 'summary'),
      affectedDates: _s(map, 'affectedDates'),
      scheduledCount: _i(map, 'scheduledCount'),
      publishedCount: _i(map, 'publishedCount'),
      completedCount: _i(map, 'completedCount'),
      dispatchedNote: _s(map, 'dispatchedNote'),
      inventoryNote: _s(map, 'inventoryNote'),
      pricingNote: _s(map, 'pricingNote'),
    );
  }
}

class CustomerRequest {
  const CustomerRequest({
    required this.id,
    required this.code,
    required this.type,
    required this.status,
    required this.currentSummary,
    required this.requestedSummary,
    required this.reason,
    required this.affectedDates,
    required this.createdAt,
    required this.customerCode,
    required this.customerName,
    this.scheduleCode,
    this.notes,
    this.effectiveDate,
    this.pauseStart,
    this.resumeDate,
    this.adminComment,
    this.reviewedAt,
    this.scheduleId,
    this.currentQuantity,
    this.requestedQuantity,
    this.city,
  });

  final String id;
  final String code;
  final String type;
  final String status;
  final String? scheduleCode;
  final String currentSummary;
  final String requestedSummary;
  final String reason;
  final String? notes;
  final String? effectiveDate;
  final String? pauseStart;
  final String? resumeDate;
  final String affectedDates;
  final String? adminComment;
  final String? reviewedAt;
  final String createdAt;
  final String customerCode;
  final String customerName;
  final String? scheduleId;
  final int? currentQuantity;
  final int? requestedQuantity;
  final String? city;

  factory CustomerRequest.fromJson(Map<String, dynamic> map) {
    return CustomerRequest(
      id: _s(map, 'id'),
      code: _s(map, 'code'),
      type: _s(map, 'type'),
      status: _s(map, 'status'),
      scheduleCode: _optional(map, 'scheduleCode'),
      currentSummary: _s(map, 'currentSummary'),
      requestedSummary: _s(map, 'requestedSummary'),
      reason: _s(map, 'reason'),
      notes: _optional(map, 'notes'),
      effectiveDate: _optional(map, 'effectiveDate'),
      pauseStart: _optional(map, 'pauseStart'),
      resumeDate: _optional(map, 'resumeDate'),
      affectedDates: _s(map, 'affectedDates'),
      adminComment: _optional(map, 'adminComment'),
      reviewedAt: _optional(map, 'reviewedAt'),
      createdAt: _s(map, 'createdAt'),
      customerCode: _s(map, 'customerCode'),
      customerName: _s(map, 'customerName'),
      scheduleId: _optional(map, 'scheduleId'),
      currentQuantity: map['currentQuantity'] is num ? (map['currentQuantity'] as num).toInt() : int.tryParse('${map['currentQuantity']}'),
      requestedQuantity: map['requestedQuantity'] is num ? (map['requestedQuantity'] as num).toInt() : int.tryParse('${map['requestedQuantity']}'),
      city: _optional(map, 'city'),
    );
  }
}

class CustomerAddress {
  const CustomerAddress({
    required this.id,
    required this.label,
    required this.city,
    required this.area,
    required this.street,
    required this.houseNumber,
    required this.isDefault,
    required this.isActive,
    this.landmark,
    this.instructions,
    this.latitude,
    this.longitude,
  });

  final String id;
  final String label;
  final String city;
  final String area;
  final String street;
  final String houseNumber;
  final String? landmark;
  final String? instructions;
  final num? latitude;
  final num? longitude;
  final bool isDefault;
  final bool isActive;

  String get summary => [houseNumber, street, area, city].where((item) => item.isNotEmpty).join(', ');

  factory CustomerAddress.fromJson(Map<String, dynamic> map) {
    return CustomerAddress(
      id: _s(map, 'id'),
      label: _s(map, 'label'),
      city: _s(map, 'city'),
      area: _s(map, 'area'),
      street: _s(map, 'street'),
      houseNumber: _s(map, 'houseNumber'),
      landmark: _optional(map, 'landmark'),
      instructions: _optional(map, 'instructions'),
      latitude: map['latitude'] == null ? null : _n(map, 'latitude'),
      longitude: map['longitude'] == null ? null : _n(map, 'longitude'),
      isDefault: map['isDefault'] == true,
      isActive: map['isActive'] != false,
    );
  }
}

class CustomerProfile {
  const CustomerProfile({
    required this.customerCode,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.accountStatus,
    required this.createdAt,
    required this.linked,
    required this.addresses,
    this.deliveryCustomerCode,
    this.deliveryCustomerName,
  });

  final String customerCode;
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String accountStatus;
  final String createdAt;
  final bool linked;
  final String? deliveryCustomerCode;
  final String? deliveryCustomerName;
  final List<CustomerAddress> addresses;

  factory CustomerProfile.fromJson(Map<String, dynamic> map) {
    return CustomerProfile(
      customerCode: _s(map, 'customerCode'),
      firstName: _s(map, 'firstName'),
      lastName: _s(map, 'lastName'),
      email: _s(map, 'email'),
      phone: _s(map, 'phone'),
      accountStatus: _s(map, 'accountStatus'),
      createdAt: _s(map, 'createdAt'),
      linked: map['linked'] == true,
      deliveryCustomerCode: _optional(map, 'deliveryCustomerCode'),
      deliveryCustomerName: _optional(map, 'deliveryCustomerName'),
      addresses: _list(map['addresses'], CustomerAddress.fromJson),
    );
  }
}

class CustomerNote {
  const CustomerNote({
    required this.id,
    required this.title,
    required this.body,
    required this.kind,
    required this.read,
    required this.createdAt,
    this.requestId = '',
  });

  final String id;
  final String title;
  final String body;
  final String kind;
  final bool read;
  final String createdAt;
  final String requestId;

  factory CustomerNote.fromJson(Map<String, dynamic> map) {
    return CustomerNote(
      id: _s(map, 'id'),
      title: _s(map, 'title'),
      body: _s(map, 'body'),
      kind: _s(map, 'kind'),
      read: map['read'] == true,
      createdAt: _s(map, 'createdAt'),
      requestId: _s(map, 'requestId'),
    );
  }
}

class CustomerAccountRow {
  const CustomerAccountRow({
    required this.id,
    required this.code,
    required this.name,
    required this.phone,
    required this.email,
    required this.city,
    required this.area,
    required this.status,
    required this.createdAt,
    required this.linked,
    required this.activeSchedules,
    required this.outstanding,
    required this.pendingRequests,
    this.deliveryCustomerId,
    this.deliveryCustomerCode,
    this.deliveryCustomerName,
  });

  final String id;
  final String code;
  final String name;
  final String phone;
  final String email;
  final String city;
  final String area;
  final String status;
  final String createdAt;
  final bool linked;
  final String? deliveryCustomerId;
  final String? deliveryCustomerCode;
  final String? deliveryCustomerName;
  final int activeSchedules;
  final num outstanding;
  final int pendingRequests;

  factory CustomerAccountRow.fromJson(Map<String, dynamic> map) {
    return CustomerAccountRow(
      id: _s(map, 'id'),
      code: _s(map, 'code'),
      name: _s(map, 'name'),
      phone: _s(map, 'phone'),
      email: _s(map, 'email'),
      city: _s(map, 'city'),
      area: _s(map, 'area'),
      status: _s(map, 'status'),
      createdAt: _s(map, 'createdAt'),
      linked: map['linked'] == true,
      deliveryCustomerId: _optional(map, 'deliveryCustomerId'),
      deliveryCustomerCode: _optional(map, 'deliveryCustomerCode'),
      deliveryCustomerName: _optional(map, 'deliveryCustomerName'),
      activeSchedules: _i(map, 'activeSchedules'),
      outstanding: _n(map, 'outstanding'),
      pendingRequests: _i(map, 'pendingRequests'),
    );
  }
}

class CustomerTimelineEntry {
  const CustomerTimelineEntry({
    required this.action,
    required this.previousValue,
    required this.newValue,
    required this.performedBy,
    required this.timestamp,
    required this.reason,
    required this.reference,
  });

  final String action;
  final String previousValue;
  final String newValue;
  final String performedBy;
  final String timestamp;
  final String reason;
  final String reference;

  factory CustomerTimelineEntry.fromJson(Map<String, dynamic> map) {
    return CustomerTimelineEntry(
      action: _s(map, 'action'),
      previousValue: _s(map, 'previousValue'),
      newValue: _s(map, 'newValue'),
      performedBy: _s(map, 'performedBy'),
      timestamp: _s(map, 'timestamp'),
      reason: _s(map, 'reason'),
      reference: _s(map, 'reference'),
    );
  }
}

class CustomerAccountBoard {
  const CustomerAccountBoard({
    required this.total,
    required this.active,
    required this.inactive,
    required this.withSchedules,
    required this.withBalance,
    required this.pendingRequests,
    required this.rows,
  });

  final int total;
  final int active;
  final int inactive;
  final int withSchedules;
  final int withBalance;
  final int pendingRequests;
  final List<CustomerAccountRow> rows;

  factory CustomerAccountBoard.fromJson(Map<String, dynamic> map) {
    return CustomerAccountBoard(
      total: _i(map, 'total'),
      active: _i(map, 'active'),
      inactive: _i(map, 'inactive'),
      withSchedules: _i(map, 'withSchedules'),
      withBalance: _i(map, 'withBalance'),
      pendingRequests: _i(map, 'pendingRequests'),
      rows: _list(map['rows'], CustomerAccountRow.fromJson),
    );
  }
}

class CustomerAccountDetail {
  const CustomerAccountDetail({
    required this.account,
    required this.profile,
    required this.schedules,
    required this.history,
    required this.payments,
    required this.requests,
    required this.timeline,
  });

  final CustomerAccountRow account;
  final CustomerProfile profile;
  final List<CustomerPlan> schedules;
  final List<CustomerVisit> history;
  final CustomerPayments payments;
  final List<CustomerRequest> requests;
  final List<CustomerTimelineEntry> timeline;

  factory CustomerAccountDetail.fromJson(Map<String, dynamic> map) {
    return CustomerAccountDetail(
      account: CustomerAccountRow.fromJson(_map(map['account']) ?? const {}),
      profile: CustomerProfile.fromJson(_map(map['profile']) ?? const {}),
      schedules: _list(map['schedules'], CustomerPlan.fromJson),
      history: _list(map['history'], CustomerVisit.fromJson),
      payments: CustomerPayments.fromJson(_map(map['payments']) ?? const {}),
      requests: _list(map['requests'], CustomerRequest.fromJson),
      timeline: _list(map['timeline'], CustomerTimelineEntry.fromJson),
    );
  }
}

class CustomerOpsOverview {
  const CustomerOpsOverview({
    required this.totalCustomers,
    required this.activeCustomers,
    required this.withSchedules,
    required this.upcomingDeliveries,
    required this.completedDeliveries,
    required this.withBalance,
    required this.pendingRequests,
    required this.registrations,
    required this.deliveries,
    required this.upcoming,
  });

  final int totalCustomers;
  final int activeCustomers;
  final int withSchedules;
  final int upcomingDeliveries;
  final int completedDeliveries;
  final int withBalance;
  final int pendingRequests;
  final List<CustomerMonthCount> registrations;
  final List<CustomerMonthCount> deliveries;
  final List<CustomerOpsRow> upcoming;

  factory CustomerOpsOverview.fromJson(Map<String, dynamic> map) {
    return CustomerOpsOverview(
      totalCustomers: _i(map, 'totalCustomers'),
      activeCustomers: _i(map, 'activeCustomers'),
      withSchedules: _i(map, 'withSchedules'),
      upcomingDeliveries: _i(map, 'upcomingDeliveries'),
      completedDeliveries: _i(map, 'completedDeliveries'),
      withBalance: _i(map, 'withBalance'),
      pendingRequests: _i(map, 'pendingRequests'),
      registrations: _list(map['registrations'], CustomerMonthCount.fromJson),
      deliveries: _list(map['deliveries'], CustomerMonthCount.fromJson),
      upcoming: _list(map['upcoming'], CustomerOpsRow.fromJson),
    );
  }
}

class CustomerMonthCount {
  const CustomerMonthCount({required this.month, required this.count});

  final String month;
  final int count;

  factory CustomerMonthCount.fromJson(Map<String, dynamic> map) => CustomerMonthCount(month: _s(map, 'month'), count: _i(map, 'count'));
}

class CustomerOpsRow {
  const CustomerOpsRow({
    required this.date,
    required this.customerName,
    required this.scheduleCode,
    required this.quantity,
    required this.status,
    required this.address,
  });

  final String date;
  final String customerName;
  final String scheduleCode;
  final int quantity;
  final String status;
  final String address;

  factory CustomerOpsRow.fromJson(Map<String, dynamic> map) {
    return CustomerOpsRow(
      date: _s(map, 'date'),
      customerName: _s(map, 'customerName'),
      scheduleCode: _s(map, 'scheduleCode'),
      quantity: _i(map, 'quantity'),
      status: _s(map, 'status'),
      address: _s(map, 'address'),
    );
  }
}

class CustomerLinkReview {
  const CustomerLinkReview({
    required this.id,
    required this.customerAccountId,
    required this.accountCode,
    required this.accountName,
    required this.accountEmail,
    required this.deliveryCustomerId,
    required this.customerCode,
    required this.customerName,
    required this.status,
    this.comment,
    required this.createdAt,
  });

  final String id;
  final String customerAccountId;
  final String accountCode;
  final String accountName;
  final String accountEmail;
  final String deliveryCustomerId;
  final String customerCode;
  final String customerName;
  final String status;
  final String? comment;
  final String createdAt;

  factory CustomerLinkReview.fromJson(Map<String, dynamic> map) => CustomerLinkReview(
        id: _s(map, 'id'),
        customerAccountId: _s(map, 'customerAccountId'),
        accountCode: _s(map, 'accountCode'),
        accountName: _s(map, 'accountName'),
        accountEmail: _s(map, 'accountEmail'),
        deliveryCustomerId: _s(map, 'deliveryCustomerId'),
        customerCode: _s(map, 'customerCode'),
        customerName: _s(map, 'customerName'),
        status: _s(map, 'status'),
        comment: _optional(map, 'comment'),
        createdAt: _s(map, 'createdAt'),
      );
}

class PolicyDocument {
  const PolicyDocument({required this.title, required this.body});

  final String title;
  final String body;

  factory PolicyDocument.fromJson(Map<String, dynamic> map) => PolicyDocument(title: _s(map, 'title'), body: _s(map, 'body'));
}

class HqSettings {
  const HqSettings({
    required this.legalName,
    required this.displayName,
    required this.supportEmail,
    required this.supportPhone,
    required this.supportAddress,
    required this.website,
    required this.receiptFooter,
  });

  final String legalName;
  final String displayName;
  final String supportEmail;
  final String supportPhone;
  final String supportAddress;
  final String website;
  final String receiptFooter;

  factory HqSettings.fromJson(Map<String, dynamic> map) => HqSettings(
        legalName: _s(map, 'legalName'),
        displayName: _s(map, 'displayName'),
        supportEmail: _s(map, 'supportEmail'),
        supportPhone: _s(map, 'supportPhone'),
        supportAddress: _s(map, 'supportAddress'),
        website: _s(map, 'website'),
        receiptFooter: _s(map, 'receiptFooter'),
      );
}

class CashHandover {
  const CashHandover({
    required this.id,
    required this.referenceNumber,
    required this.riderId,
    required this.depotId,
    required this.businessDate,
    required this.expectedAmount,
    this.actualAmount,
    this.difference,
    required this.status,
    required this.collectionCount,
    required this.submittedAt,
    this.receivedAt,
  });

  final String id;
  final String referenceNumber;
  final String riderId;
  final String depotId;
  final String businessDate;
  final num expectedAmount;
  final num? actualAmount;
  final num? difference;
  final String status;
  final int collectionCount;
  final String submittedAt;
  final String? receivedAt;

  factory CashHandover.fromJson(Map<String, dynamic> map) => CashHandover(
        id: _s(map, 'id'),
        referenceNumber: _s(map, 'referenceNumber'),
        riderId: _s(map, 'riderId'),
        depotId: _s(map, 'depotId'),
        businessDate: _s(map, 'businessDate'),
        expectedAmount: _n(map, 'expectedAmount'),
        actualAmount: map['actualAmount'] == null ? null : _n(map, 'actualAmount'),
        difference: map['difference'] == null ? null : _n(map, 'difference'),
        status: _s(map, 'status'),
        collectionCount: _i(map, 'collectionCount'),
        submittedAt: _s(map, 'submittedAt'),
        receivedAt: _optional(map, 'receivedAt'),
      );
}

class OfficeDocument {
  const OfficeDocument({required this.fileName, required this.contentType, required this.contentBase64});

  final String fileName;
  final String contentType;
  final String contentBase64;

  factory OfficeDocument.fromJson(Map<String, dynamic> map) => OfficeDocument(
        fileName: _s(map, 'fileName'),
        contentType: _s(map, 'contentType'),
        contentBase64: _s(map, 'contentBase64'),
      );
}

String customerMoney(num value) => value.toStringAsFixed(0);

String _s(Map<String, dynamic> map, String key) => map[key]?.toString() ?? '';

String? _optional(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value == null) return null;
  final text = value.toString();
  return text.isEmpty ? null : text;
}

int _i(Map<String, dynamic> map, String key) => map[key] is num ? (map[key] as num).toInt() : int.tryParse('${map[key]}') ?? 0;

num _n(Map<String, dynamic> map, String key) => map[key] is num ? map[key] as num : num.tryParse('${map[key]}') ?? 0;

Map<String, dynamic>? _map(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

List<T> _list<T>(Object? raw, T Function(Map<String, dynamic>) parse) {
  if (raw is! List) return [];
  return [
    for (final item in raw)
      if (item is Map) parse(Map<String, dynamic>.from(item)),
  ];
}
