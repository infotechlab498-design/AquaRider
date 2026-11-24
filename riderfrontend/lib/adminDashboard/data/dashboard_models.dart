import 'admin_format.dart';
import 'admin_json.dart';

const lockedCommandKpiLabels = <String>[
  'Total billed sales',
  'Collections received',
  'Fleet / couriers',
  'Deliveries',
  'Pending orders',
  'Outstanding dues',
];

const approvedCollectionLabels = <String>[
  'Cash',
  'Full credit',
  'Partial cash',
];

class CommandOverview {
  const CommandOverview({
    this.greeting,
    this.businessName,
    this.facilityName,
    this.subtitle,
    this.serviceDate,
    this.onDutyRiders,
    this.databaseLatencyMs,
  });

  final String? greeting;
  final String? businessName;
  final String? facilityName;
  final String? subtitle;
  final String? serviceDate;
  final int? onDutyRiders;
  final int? databaseLatencyMs;

  factory CommandOverview.fromJson(Object? data) {
    final json = jsonMap(data) ?? const <String, dynamic>{};
    final business = jsonMap(
      jsonPick(json, const ['business', 'businessProfile', 'profile']),
    );
    final facility = jsonMap(jsonPick(json, const ['facility', 'depot']));
    final period = jsonMap(jsonPick(json, const ['period']));
    final adminName = jsonString(json, const ['adminFullName', 'fullName']);
    final businessName =
        jsonString(json, const [
          'businessDisplayName',
          'businessName',
          'displayName',
          'companyName',
        ]) ??
        (business == null
            ? null
            : jsonString(business, const [
                'displayName',
                'legalName',
                'businessName',
                'name',
              ]));
    final greeting =
        jsonString(json, const ['greeting', 'headline']) ??
        (adminName == null || adminName.isEmpty
            ? null
            : 'Good day, ${adminName.split(' ').first}');
    return CommandOverview(
      greeting: greeting,
      businessName: businessName,
      facilityName:
          jsonString(json, const [
            'facilityDepotName',
            'facilityName',
            'depotName',
          ]) ??
          (facility == null
              ? null
              : jsonString(facility, const [
                  'name',
                  'depotName',
                  'facilityName',
                ])),
      subtitle: jsonString(json, const ['subtitle', 'summary']) ??
          (businessName == null
              ? null
              : "Here's the operational status across $businessName for the selected period."),
      serviceDate: jsonString(json, const ['serviceDate', 'date']) ??
          (period == null
              ? null
              : [
                  jsonString(period, const ['from']),
                  jsonString(period, const ['to']),
                ].whereType<String>().join(' → ').ifEmptyNull),
      onDutyRiders: optionalInt(json, const ['onDutyRiders', 'ridersOnDuty']),
      databaseLatencyMs: optionalInt(json, const [
        'databaseLatencyMs',
        'dbLatencyMs',
        'latencyMs',
      ]),
    );
  }
}

class DashboardKpi {
  const DashboardKpi({
    required this.key,
    required this.label,
    required this.value,
    this.detail,
    this.delta,
  });

  final String key;
  final String label;
  final String value;
  final String? detail;
  final String? delta;

  factory DashboardKpi.fromJson(Map<String, dynamic> json) {
    final key = jsonString(json, const ['key', 'id', 'code']) ?? '';
    final label = jsonString(json, const ['label', 'title', 'name']) ?? key;
    final format = (jsonString(json, const ['format', 'valueFormat']) ?? '')
        .toLowerCase();
    final explicit = jsonString(json, const [
      'displayValue',
      'valueText',
      'formattedValue',
    ]);
    final number = jsonNum(json, const ['value', 'amount', 'total']);
    final money =
        format == 'currency' || format == 'pkr' || _moneyKey('$key $label');
    final value =
        explicit ??
        (number == null
            ? ''
            : (money ? formatPkr(number) : formatGrouped(number)));
    final delta = jsonString(json, const ['delta', 'change', 'deltaLabel']);
    final deltaNum = optionalNum(json, const ['deltaPercent', 'changePercent']);
    return DashboardKpi(
      key: key,
      label: label,
      value: value,
      detail: jsonString(json, const ['detail', 'subtitle', 'note', 'caption']),
      delta:
          delta ??
          (deltaNum == null
              ? null
              : '${deltaNum > 0 ? '+' : ''}${formatGrouped(deltaNum)}%'),
    );
  }
}

class DashboardKpiSet {
  const DashboardKpiSet(this.cards);

  final List<DashboardKpi> cards;

  factory DashboardKpiSet.fromJson(Object? data) {
    if (data is List) {
      return DashboardKpiSet(_cardsFromList(data));
    }
    final map = jsonMap(data);
    if (map == null) return const DashboardKpiSet([]);
    final listed = jsonPick(map, const ['cards', 'kpis', 'items', 'metrics']);
    if (listed is List) return DashboardKpiSet(_cardsFromList(listed));
    return DashboardKpiSet(_cardsFromFields(map));
  }
}

List<DashboardKpi> _cardsFromList(List<dynamic> raw) {
  return [
    for (final item in raw)
      if (jsonMap(item) case final row?)
        if (DashboardKpi.fromJson(row) case final card)
          if (card.value.isNotEmpty &&
              !isDisallowedOperationsLabel('${card.label} ${card.key}'))
            card,
  ];
}

List<DashboardKpi> _cardsFromFields(Map<String, dynamic> json) {
  // ASP.NET CommandKpisDto nests Sales/Collections/Fleet/Deliveries/Orders/Outstanding.
  final sales = jsonMap(jsonPick(json, const ['sales'])) ?? json;
  final collections = jsonMap(jsonPick(json, const ['collections'])) ?? json;
  final fleet = jsonMap(jsonPick(json, const ['fleet'])) ?? json;
  final deliveries = jsonMap(jsonPick(json, const ['deliveries'])) ?? json;
  final orders = jsonMap(jsonPick(json, const ['orders'])) ?? json;
  final outstandingMap = jsonMap(jsonPick(json, const ['outstanding'])) ?? json;

  final cards = <DashboardKpi>[];

  final billed = optionalNum(sales, const ['totalBilledSales', 'billedSales']);
  if (billed != null) {
    final invoices = optionalInt(sales, const ['invoiceCount', 'salesCount']);
    final delta = optionalNum(sales, const [
      'changePercent',
      'salesDeltaPercent',
      'billedSalesDeltaPercent',
    ]);
    cards.add(
      DashboardKpi(
        key: 'billedSales',
        label: lockedCommandKpiLabels[0],
        value: formatPkr(billed),
        detail: invoices == null ? null : '$invoices invoices',
        delta: delta == null
            ? null
            : '${delta > 0 ? '+' : ''}${formatGrouped(delta)}%',
      ),
    );
  }

  final collected = optionalNum(collections, const [
    'collectionsReceived',
    'collections',
  ]);
  if (collected != null) {
    final recovered = optionalNum(collections, const [
      'recoveryPercent',
      'collectionsRecoveredPercent',
      'recoveredPercent',
    ]);
    final count = optionalInt(collections, const ['collectionCount']);
    cards.add(
      DashboardKpi(
        key: 'collections',
        label: lockedCommandKpiLabels[1],
        value: formatPkr(collected),
        detail: [
          if (count != null) '$count collections',
          if (recovered != null) '${formatGrouped(recovered)}% recovered',
        ].join(' · ').ifEmptyNull,
      ),
    );
  }

  final fleetOnDuty = optionalInt(fleet, const [
    'fleetOnDuty',
    'fleetActive',
    'activeCouriers',
  ]);
  final fleetRegistered = optionalInt(fleet, const [
    'fleetRegistered',
    'fleetTotal',
    'courierCount',
  ]);
  if (fleetOnDuty != null || fleetRegistered != null) {
    final notStarted = (fleetRegistered != null && fleetOnDuty != null)
        ? (fleetRegistered - fleetOnDuty).clamp(0, fleetRegistered)
        : optionalInt(fleet, const ['fleetNotStarted', 'notStarted']);
    final value = fleetOnDuty != null && fleetRegistered != null
        ? '${formatGrouped(fleetOnDuty)} / ${formatGrouped(fleetRegistered)}'
        : formatGrouped((fleetOnDuty ?? fleetRegistered)!);
    cards.add(
      DashboardKpi(
        key: 'fleet',
        label: lockedCommandKpiLabels[2],
        value: value,
        detail: notStarted == null ? null : '$notStarted yet to start',
      ),
    );
  }

  final done = optionalInt(deliveries, const [
    'deliveriesCompleted',
    'deliveriesDone',
    'completedDeliveries',
  ]);
  final deliveryTotal = optionalInt(deliveries, const [
    'deliveriesTotal',
    'deliveryCount',
  ]);
  if (done != null || deliveryTotal != null) {
    final percent = optionalNum(deliveries, const ['percent']);
    final remaining = (done != null && deliveryTotal != null)
        ? (deliveryTotal - done).clamp(0, deliveryTotal)
        : optionalInt(deliveries, const ['deliveriesRemaining', 'remainingDeliveries']);
    final parts = <String>[
      if (deliveryTotal != null && done != null) 'of $deliveryTotal',
      if (percent != null)
        '${formatGrouped(percent)}%'
      else if (done != null && deliveryTotal != null && deliveryTotal > 0)
        '${((done / deliveryTotal) * 100).round()}%',
      if (remaining != null) '$remaining remaining',
    ];
    cards.add(
      DashboardKpi(
        key: 'deliveries',
        label: lockedCommandKpiLabels[3],
        value: formatGrouped((done ?? deliveryTotal)!),
        detail: parts.isEmpty ? null : parts.join(' · '),
      ),
    );
  }

  final pending = optionalInt(orders, const ['pendingOrders', 'scheduledOrders']);
  if (pending != null) {
    final unassigned = optionalInt(orders, const ['unassignedOrders']);
    cards.add(
      DashboardKpi(
        key: 'pendingOrders',
        label: lockedCommandKpiLabels[4],
        value: formatGrouped(pending),
        detail: unassigned == null ? null : '$unassigned unassigned',
      ),
    );
  }

  final outstanding = optionalNum(outstandingMap, const [
    'outstandingDues',
    'outstanding',
  ]);
  if (outstanding != null) {
    final accounts = optionalInt(outstandingMap, const [
      'accountsWithDues',
      'outstandingAccounts',
      'accountCount',
    ]);
    cards.add(
      DashboardKpi(
        key: 'outstanding',
        label: lockedCommandKpiLabels[5],
        value: formatPkr(outstanding),
        detail: accounts == null ? null : '$accounts accounts',
      ),
    );
  }

  return cards;
}

extension on String {
  String? get ifEmptyNull => isEmpty ? null : this;
}

bool _moneyKey(String blob) {
  final value = blob.toLowerCase();
  return value.contains('sale') ||
      value.contains('collection') ||
      value.contains('outstanding') ||
      value.contains('amount') ||
      value.contains('pkr');
}

class OperationalActivity {
  const OperationalActivity({
    required this.id,
    required this.title,
    required this.detail,
    this.occurredAt,
  });

  final String id;
  final String title;
  final String detail;
  final DateTime? occurredAt;

  factory OperationalActivity.fromJson(Map<String, dynamic> json) {
    return OperationalActivity(
      id: jsonString(json, const ['id']) ?? '',
      title: jsonString(json, const ['title', 'name', 'summary']) ?? '',
      detail: jsonString(json, const ['detail', 'description', 'note']) ?? '',
      occurredAt: jsonDate(json, const ['occurredAt', 'timestamp', 'at']),
    );
  }
}

class OperationalSummary {
  const OperationalSummary({
    this.activeRoutes,
    this.ridersOnDuty,
    this.stopsCompleted,
    this.stopsRemaining,
    this.exceptions,
    this.recent = const [],
    this.note,
  });

  final int? activeRoutes;
  final int? ridersOnDuty;
  final int? stopsCompleted;
  final int? stopsRemaining;
  final int? exceptions;
  final List<OperationalActivity> recent;
  final String? note;

  bool get hasContent =>
      activeRoutes != null ||
      ridersOnDuty != null ||
      stopsCompleted != null ||
      stopsRemaining != null ||
      exceptions != null ||
      recent.isNotEmpty ||
      (note != null && note!.isNotEmpty);

  factory OperationalSummary.fromJson(Object? data) {
    final json = jsonMap(data) ?? const <String, dynamic>{};
    final recentRaw = jsonPick(json, const [
      'recent',
      'activity',
      'activities',
    ]);
    final rows = recentRaw is List
        ? jsonRows(recentRaw)
        : jsonRows(json, keys: const ['recent', 'activity', 'activities']);
    return OperationalSummary(
      activeRoutes: optionalInt(json, const ['activeRoutes', 'routeCount']),
      ridersOnDuty: optionalInt(json, const ['ridersOnDuty', 'onDutyRiders']),
      stopsCompleted: optionalInt(json, const [
        'stopsCompleted',
        'completedStops',
      ]),
      stopsRemaining: optionalInt(json, const [
        'stopsRemaining',
        'remainingStops',
      ]),
      exceptions: optionalInt(json, const ['exceptions', 'exceptionCount']),
      note: jsonString(json, const ['note', 'summary']),
      recent: [
        for (final row in rows)
          if (OperationalActivity.fromJson(row) case final item)
            if (item.title.isNotEmpty || item.detail.isNotEmpty) item,
      ],
    );
  }
}

class AttentionItem {
  const AttentionItem({
    required this.id,
    required this.title,
    required this.detail,
    this.severity = 'info',
    this.count,
    this.actionLabel,
  });

  final String id;
  final String title;
  final String detail;
  final String severity;
  final int? count;
  final String? actionLabel;

  factory AttentionItem.fromJson(Map<String, dynamic> json) {
    return AttentionItem(
      id: jsonString(json, const ['id']) ?? '',
      title: jsonString(json, const ['title', 'name']) ?? '',
      detail:
          jsonString(json, const ['detail', 'description', 'message']) ?? '',
      severity:
          (jsonString(json, const ['severity', 'level', 'tone']) ?? 'info')
              .toLowerCase(),
      count: optionalInt(json, const ['count']),
      actionLabel: jsonString(json, const ['actionLabel', 'action']),
    );
  }

  static List<AttentionItem> listFromJson(Object? data) {
    return [
      for (final row in jsonRows(
        data,
        keys: const ['items', 'rows', 'attentionItems'],
      ))
        if (AttentionItem.fromJson(row) case final item)
          if (item.title.isNotEmpty || item.detail.isNotEmpty) item,
    ];
  }
}

class SalesBucket {
  const SalesBucket({required this.label, required this.amount});

  final String label;
  final num amount;

  factory SalesBucket.fromJson(Map<String, dynamic> json) {
    return SalesBucket(
      label: jsonString(json, const ['label', 'bucket', 'name', 'hour']) ?? '',
      amount: jsonNum(json, const ['amount', 'total', 'value', 'sales']) ?? 0,
    );
  }
}

class SalesSummary {
  const SalesSummary({this.buckets = const [], this.peakLabel, this.total});

  final List<SalesBucket> buckets;
  final String? peakLabel;
  final num? total;

  String? get derivedPeakLabel {
    if (peakLabel != null && peakLabel!.isNotEmpty) return peakLabel;
    if (buckets.isEmpty || buckets.every((bucket) => bucket.amount == 0)) {
      return null;
    }
    var best = buckets.first;
    for (final bucket in buckets.skip(1)) {
      if (bucket.amount > best.amount) best = bucket;
    }
    return best.label.isEmpty ? null : best.label;
  }

  factory SalesSummary.fromJson(Object? data) {
    final map = jsonMap(data);
    final list = data is List
        ? data
        : (map == null
              ? const []
              : (jsonPick(map, const ['buckets', 'items', 'points']) as List? ??
                    const []));
    return SalesSummary(
      buckets: [
        for (final item in list)
          if (jsonMap(item) case final row?)
            if (SalesBucket.fromJson(row) case final bucket)
              if (bucket.label.isNotEmpty) bucket,
      ],
      peakLabel: map == null
          ? null
          : jsonString(map, const ['peakLabel', 'peak']),
      total: map == null
          ? null
          : optionalNum(map, const ['total', 'totalSales']),
    );
  }
}

class CollectionChannel {
  const CollectionChannel({
    required this.key,
    required this.label,
    this.amount,
    this.percent,
    this.count,
  });

  final String key;
  final String label;
  final num? amount;
  final num? percent;
  final int? count;

  CollectionChannel copyWith({num? percent}) {
    return CollectionChannel(
      key: key,
      label: label,
      amount: amount,
      percent: percent ?? this.percent,
      count: count,
    );
  }
}

class CollectionsSummary {
  const CollectionsSummary({
    required this.cash,
    required this.fullCredit,
    required this.partialCash,
    this.balanced,
    this.note,
  });

  final CollectionChannel cash;
  final CollectionChannel fullCredit;
  final CollectionChannel partialCash;
  final bool? balanced;
  final String? note;

  List<CollectionChannel> get channels => [cash, fullCredit, partialCash];

  num? get reportedTotal {
    final amounts = [
      cash.amount,
      fullCredit.amount,
      partialCash.amount,
    ].whereType<num>();
    if (amounts.isEmpty) return null;
    return amounts.fold<num>(0, (sum, value) => sum + value);
  }

  factory CollectionsSummary.fromJson(Object? data) {
    final json = jsonMap(data) ?? const <String, dynamic>{};
    var cash = _channelFromValue(
      'cash',
      approvedCollectionLabels[0],
      jsonPick(json, const ['cash', 'handToHandCash', 'cashAmount']),
    );
    var fullCredit = _channelFromValue(
      'fullCredit',
      approvedCollectionLabels[1],
      jsonPick(json, const ['fullCredit', 'fullCreditAmount', 'credit']),
    );
    var partialCash = _channelFromValue(
      'partialCash',
      approvedCollectionLabels[2],
      jsonPick(json, const ['partialCash', 'partialCashAmount', 'partial']),
    );
    final listed = jsonPick(json, const ['channels', 'items']);
    if (listed is List) {
      for (final item in listed) {
        final row = jsonMap(item);
        if (row == null) continue;
        final slot = approvedCollectionSlot(
          jsonString(row, const ['key', 'code', 'channel', 'label', 'name']) ??
              '',
        );
        if (slot == null) continue;
        final parsed = _channelFromMap(slot.$1, slot.$2, row);
        switch (slot.$1) {
          case 'cash':
            cash = parsed;
          case 'fullCredit':
            fullCredit = parsed;
          case 'partialCash':
            partialCash = parsed;
        }
      }
    }
    final filled = _withShares(cash, fullCredit, partialCash);
    return CollectionsSummary(
      cash: filled.$1,
      fullCredit: filled.$2,
      partialCash: filled.$3,
      balanced: jsonBool(json, const ['balanced', 'isBalanced']),
      note: jsonString(json, const ['note', 'reconciliationNote']),
    );
  }
}

(String, String)? approvedCollectionSlot(String raw) {
  final norm = raw.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
  if (norm.isEmpty) return null;
  if (norm.contains('wallet') ||
      norm.contains('raast') ||
      norm.contains('ibft') ||
      norm.contains('bank') ||
      norm.contains('cheque') ||
      norm.contains('check')) {
    return null;
  }
  if (norm == 'partialcash' ||
      norm == 'partial' ||
      norm == 'partialamount' ||
      norm == 'partialcashamount') {
    return ('partialCash', approvedCollectionLabels[2]);
  }
  if (norm == 'fullcredit' || norm == 'credit' || norm == 'fullcreditamount') {
    return ('fullCredit', approvedCollectionLabels[1]);
  }
  if (norm == 'cash' ||
      norm == 'handtohandcash' ||
      norm == 'cashamount' ||
      norm == 'handtohand') {
    return ('cash', approvedCollectionLabels[0]);
  }
  return null;
}

CollectionChannel _channelFromValue(String key, String label, Object? value) {
  if (value is Map) {
    final row = jsonMap(value);
    if (row != null) return _channelFromMap(key, label, row);
  }
  if (value is num) {
    return CollectionChannel(key: key, label: label, amount: value);
  }
  if (value is String) {
    final amount = num.tryParse(value.replaceAll(',', ''));
    if (amount != null) {
      return CollectionChannel(key: key, label: label, amount: amount);
    }
  }
  return CollectionChannel(key: key, label: label);
}

CollectionChannel _channelFromMap(
  String key,
  String label,
  Map<String, dynamic> json,
) {
  return CollectionChannel(
    key: key,
    label: label,
    amount: optionalNum(json, const ['amount', 'total', 'value']),
    percent: optionalNum(json, const ['percent', 'share']),
    count: optionalInt(json, const ['count']),
  );
}

(CollectionChannel, CollectionChannel, CollectionChannel) _withShares(
  CollectionChannel cash,
  CollectionChannel fullCredit,
  CollectionChannel partial,
) {
  if (cash.amount == null ||
      fullCredit.amount == null ||
      partial.amount == null) {
    return (cash, fullCredit, partial);
  }
  final sum = cash.amount! + fullCredit.amount! + partial.amount!;
  num share(num amount) => sum == 0 ? 0 : (amount / sum) * 100;
  CollectionChannel fill(CollectionChannel channel) {
    if (channel.percent != null || channel.amount == null) return channel;
    return channel.copyWith(percent: share(channel.amount!));
  }

  return (fill(cash), fill(fullCredit), fill(partial));
}

class ActivityLedgerRow {
  const ActivityLedgerRow({
    required this.id,
    required this.reference,
    required this.customer,
    required this.rider,
    required this.transactionType,
    this.amount,
    this.occurredAt,
    this.syncStatus,
  });

  final String id;
  final String reference;
  final String customer;
  final String rider;
  final String transactionType;
  final num? amount;
  final DateTime? occurredAt;
  final String? syncStatus;

  factory ActivityLedgerRow.fromJson(Map<String, dynamic> json) {
    return ActivityLedgerRow(
      id: jsonString(json, const ['id']) ?? '',
      reference:
          jsonString(json, const [
            'reference',
            'referenceNumber',
            'referenceId',
          ]) ??
          '',
      customer:
          jsonString(json, const ['customerName', 'customer', 'party']) ?? '',
      rider: jsonString(json, const ['riderName', 'rider']) ?? '',
      transactionType:
          jsonString(json, const ['transactionType', 'type', 'kind']) ?? '',
      amount: optionalNum(json, const ['amount', 'value']),
      occurredAt: jsonDate(json, const [
        'occurredAt',
        'timestamp',
        'createdAt',
      ]),
      syncStatus: jsonString(json, const ['syncStatus', 'status', 'cloudSync']),
    );
  }
}

class ActivityLedgerPage {
  const ActivityLedgerPage({
    required this.rows,
    required this.page,
    required this.pageSize,
    this.totalRecords,
    this.totalPages,
  });

  final List<ActivityLedgerRow> rows;
  final int page;
  final int pageSize;
  final int? totalRecords;
  final int? totalPages;

  factory ActivityLedgerPage.fromParts(
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
        keys: const ['items', 'rows', 'entries', 'ledger'],
      ))
        ActivityLedgerRow.fromJson(row),
    ];
    final total = meta != null
        ? optionalInt(meta, const ['totalRecords', 'total', 'totalCount'])
        : (map == null
              ? null
              : optionalInt(map, const ['totalRecords', 'totalCount']));
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
    return ActivityLedgerPage(
      rows: rows,
      page: current,
      pageSize: size,
      totalRecords: total,
      totalPages: derivedPages,
    );
  }
}

class AdminOrderLine {
  const AdminOrderLine({required this.productId, required this.quantity});

  final String productId;
  final int quantity;
}

class AdminOrderRequest {
  const AdminOrderRequest({
    required this.customerId,
    required this.riderId,
    required this.productId,
    required this.quantity,
    required this.window,
    this.deliveryDate,
    this.note,
    this.showOnManifest = true,
    this.lines = const [],
  });

  final String customerId;
  final String riderId;
  final String productId;
  final int quantity;
  final String window;
  final String? deliveryDate;
  final String? note;
  final bool showOnManifest;
  final List<AdminOrderLine> lines;

  Map<String, dynamic> toJson() {
    final supplied = [
      for (final line in lines)
        if (line.productId.trim().isNotEmpty && line.quantity > 0)
          {'productId': line.productId.trim(), 'quantity': line.quantity},
    ];
    return {
      'customerId': customerId,
      'riderId': riderId,
      'window': window,
      'deliveryDate': ?deliveryDate,
      'note': ?note,
      'showOnManifest': showOnManifest,
      'lines': supplied.isEmpty
          ? [
              {'productId': productId, 'quantity': quantity},
            ]
          : supplied,
    };
  }
}

class AdminOrderResult {
  const AdminOrderResult({
    required this.id,
    required this.reference,
    required this.status,
    required this.message,
  });

  final String id;
  final String reference;
  final String status;
  final String message;

  String get notice {
    if (message.trim().isNotEmpty) return message.trim();
    if (reference.trim().isNotEmpty) {
      return 'Order ${reference.trim()} was saved.';
    }
    return 'The order was saved.';
  }

  factory AdminOrderResult.fromJson(Object? data, {String? message}) {
    final json = jsonMap(data) ?? const <String, dynamic>{};
    return AdminOrderResult(
      id: jsonString(json, const ['id']) ?? '',
      reference:
          jsonString(json, const [
            'referenceNumber',
            'reference',
            'orderNumber',
          ]) ??
          '',
      status: jsonString(json, const ['status']) ?? '',
      message: (message ?? jsonString(json, const ['message']) ?? '').trim(),
    );
  }
}
