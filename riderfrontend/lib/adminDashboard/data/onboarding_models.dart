class LockedOnboardingStep {
  const LockedOnboardingStep(this.order, this.code, this.title, this.aliases);

  final int order;
  final String code;
  final String title;
  final List<String> aliases;
}

/// Locked V1 has six steps. Marketing screens that show seven are not the contract.
const lockedOnboardingSteps = <LockedOnboardingStep>[
  LockedOnboardingStep(1, 'plant-details', 'Plant Details', [
    'plant',
    'business profile',
    'depot',
    'entity',
    'branch',
    'warehouse',
  ]),
  LockedOnboardingStep(2, 'items-openings', 'Items & Openings', [
    'item',
    'product',
    'opening',
    'catalog',
  ]),
  LockedOnboardingStep(3, 'customers', 'Customers', ['customer']),
  LockedOnboardingStep(4, 'zones', 'Zones', ['zone', 'delivery route']),
  LockedOnboardingStep(5, 'rider-load', 'Rider & Load', [
    'rider',
    'courier',
    'vehicle stock',
    'team member',
    'load',
  ]),
  LockedOnboardingStep(6, 'first-synced-sale', 'First Synced Sale', [
    'synced sale',
    'first sale',
    'first synced',
  ]),
];

enum OnboardingStepStatus { completed, inProgress, notStarted, unavailable }

class OnboardingStep {
  const OnboardingStep({
    required this.code,
    required this.order,
    required this.title,
    required this.summary,
    required this.status,
    this.recommended = false,
    this.actionLabel,
    this.checks = const [],
    this.badges = const [],
    this.note,
  });

  final String code;
  final int order;
  final String title;
  final String summary;
  final OnboardingStepStatus status;
  final bool recommended;
  final String? actionLabel;
  final List<String> checks;
  final List<String> badges;
  final String? note;

  bool get isCompleted => status == OnboardingStepStatus.completed;

  bool get isPending =>
      status == OnboardingStepStatus.inProgress ||
      status == OnboardingStepStatus.notStarted;

  factory OnboardingStep.fromJson(Map<String, dynamic> json) {
    return OnboardingStep(
      code: _str(json, const ['stepCode', 'code', 'key', 'id']) ?? '',
      order: _int(json, const ['order', 'sequence', 'step']) ?? 0,
      title: _str(json, const ['title', 'name']) ?? '',
      summary:
          _str(json, const [
            'validationNotes',
            'summary',
            'description',
            'detail',
            'notes',
          ]) ??
          '',
      status: _status(_str(json, const ['status', 'state'])),
      recommended:
          _bool(json, const ['recommended', 'recommendedNow']) ?? false,
      actionLabel: _str(json, const ['actionLabel', 'action']),
      checks: _strings(json['checks'] ?? json['requirements'] ?? json['items']),
      badges: _strings(json['badges'] ?? json['tags']),
      note: _str(json, const ['note', 'footnote', 'validationNotes']),
    );
  }
}

class OnboardingFacility {
  const OnboardingFacility({
    this.name,
    this.address,
    this.status,
    this.assignedItems,
  });

  final String? name;
  final String? address;
  final String? status;
  final String? assignedItems;

  factory OnboardingFacility.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const OnboardingFacility();
    final products = _int(json, const ['productCount']);
    final customers = _int(json, const ['customerCount']);
    final zones = _int(json, const ['zoneCount']);
    final riders = _int(json, const ['activeRiderCount']);
    final stock = _int(json, const ['vehicleStockCount']);
    final sales = _int(json, const ['syncedSaleCount']);
    final parts = <String>[
      if (products != null) '$products products',
      if (customers != null) '$customers customers',
      if (zones != null) '$zones zones',
      if (riders != null) '$riders riders',
      if (stock != null) '$stock stock rows',
      if (sales != null) '$sales synced sales',
    ];
    return OnboardingFacility(
      name: _str(json, const ['depotName', 'name', 'facilityName']),
      address: _str(json, const ['address', 'location']),
      status:
          _str(json, const ['status']) ??
          ((products ?? 0) > 0 || (customers ?? 0) > 0 ? 'Active' : null),
      assignedItems:
          _str(json, const ['assignedItems', 'items']) ??
          (parts.isEmpty ? null : parts.join(' · ')),
    );
  }
}

class OnboardingCompliance {
  const OnboardingCompliance({
    this.entityName,
    this.taxId,
    this.status,
    this.autoTax,
    this.fiscalDevice,
  });

  final String? entityName;
  final String? taxId;
  final String? status;
  final bool? autoTax;
  final bool? fiscalDevice;

  factory OnboardingCompliance.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const OnboardingCompliance();
    return OnboardingCompliance(
      entityName: _str(json, const ['entityName', 'legalName', 'name']),
      taxId: _str(json, const ['taxId', 'ntn', 'strn']),
      status: _str(json, const ['status']),
      autoTax: _bool(json, const ['autoTax', 'autoTaxDeductions']),
      fiscalDevice: _bool(json, const ['fiscalDevice', 'fbrPos', 'posEnabled']),
    );
  }
}

class OnboardingDevice {
  const OnboardingDevice({
    this.build,
    this.status,
    this.companion,
    this.smsReady,
  });

  final String? build;
  final String? status;
  final String? companion;
  final bool? smsReady;

  factory OnboardingDevice.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const OnboardingDevice();
    return OnboardingDevice(
      build: _str(json, const ['build', 'version']),
      status: _str(json, const ['status']),
      companion: _str(json, const ['companion', 'companionBuild']),
      smsReady: _bool(json, const ['smsReady', 'smsLink']),
    );
  }
}

class OnboardingOverview {
  const OnboardingOverview({
    required this.businessName,
    required this.legalName,
    required this.setupLabel,
    required this.statusLabel,
    required this.accountName,
    required this.accountRole,
    required this.welcomeTitle,
    required this.welcomeBody,
    required this.facility,
    required this.compliance,
    required this.device,
  });

  final String businessName;
  final String legalName;
  final String setupLabel;
  final String statusLabel;
  final String accountName;
  final String accountRole;
  final String welcomeTitle;
  final String welcomeBody;
  final OnboardingFacility facility;
  final OnboardingCompliance compliance;
  final OnboardingDevice device;

  factory OnboardingOverview.fromJson(Map<String, dynamic> json) {
    final business = _map(json['business']) ?? _map(json['profile']) ?? json;
    final name =
        _str(business, const ['displayName', 'businessName', 'name']) ?? '';
    final legal = _str(business, const ['legalName', 'registeredName']) ?? '';
    final status =
        _str(business, const ['status']) ??
        _str(json, const ['statusLabel']) ??
        '';
    final support = _map(json['support']);
    final ready = json['ready'] == true;
    return OnboardingOverview(
      businessName: name.isEmpty ? legal : name,
      legalName: legal,
      setupLabel:
          _str(json, const ['setupLabel', 'phaseLabel']) ??
          (ready ? 'Setup complete' : 'Business Onboarding'),
      statusLabel:
          _str(json, const ['statusLabel']) ??
          _str(_map(json['status']) ?? const {}, const ['label']) ??
          (status.isEmpty ? (ready ? 'Ready' : 'Setup in Progress') : status),
      accountName: _str(json, const ['accountName', 'adminName']) ?? '',
      accountRole: _str(json, const ['accountRole']) ?? '',
      welcomeTitle:
          _str(json, const ['welcomeTitle', 'title']) ??
          (name.isEmpty
              ? 'Welcome to RouteLedger'
              : 'Welcome to RouteLedger, $name!'),
      welcomeBody:
          _str(json, const ['welcomeBody', 'summary', 'description']) ?? "Let's prepare your business workspace so dispatch managers and route couriers can coordinate daily operations.",
      facility: OnboardingFacility.fromJson(
        _map(json['facility']) ?? _map(json['depot']),
      ),
      compliance: OnboardingCompliance.fromJson(
        _map(json['compliance']) ??
            _map(json['fiscal']) ??
            <String, dynamic>{
              'legalName': legal,
              'taxId': _str(business, const [
                'taxNumber',
                'taxId',
                'ntn',
                'strn',
              ]),
              'status':
                  _str(business, const ['status']) ?? 'Pending Verification',
            },
      ),
      device: OnboardingDevice.fromJson(
        _map(json['device']) ??
            _map(json['handheld']) ??
            <String, dynamic>{
              'companion': 'RouteLedger Rider Companion',
              'status': support == null
                  ? 'Configured by fleet policy'
                  : ((support['chatAvailable'] == true)
                        ? 'Support channel ready'
                        : 'Companion app compatible'),
              'build': 'Locked V1',
            },
      ),
    );
  }
}

List<OnboardingStep> stepsFromOverviewJson(Map<String, dynamic> json) {
  final list = json['steps'];
  if (list is! List) return const [];
  return [
    for (final item in list)
      if (_map(item) case final row?) OnboardingStep.fromJson(row),
  ];
}

class OnboardingProgress {
  const OnboardingProgress({
    this.completed,
    this.total,
    this.percent,
    this.milestoneLabel,
    this.paceLabel,
  });

  final int? completed;
  final int? total;
  final int? percent;
  final String? milestoneLabel;
  final String? paceLabel;

  int? get displayPercent {
    final explicit = percent;
    if (explicit != null) return explicit.clamp(0, 100);
    final done = completed;
    final all = total;
    if (done == null || all == null || all <= 0) return null;
    return ((done / all) * 100).round().clamp(0, 100);
  }

  factory OnboardingProgress.fromJson(Map<String, dynamic> json) {
    return OnboardingProgress(
      completed: _int(json, const [
        'completedCount',
        'completed',
        'completedSteps',
      ]),
      total: _int(json, const ['totalSteps', 'total']),
      percent: _int(json, const ['progressPercent', 'percent', 'percentage']),
      milestoneLabel: _str(json, const ['milestoneLabel', 'milestone']),
      paceLabel: _str(json, const ['paceLabel', 'label']),
    );
  }
}

class OnboardingReadiness {
  const OnboardingReadiness({
    required this.ready,
    required this.title,
    required this.body,
  });

  final bool ready;
  final String title;
  final String body;

  factory OnboardingReadiness.fromJson(Map<String, dynamic> json) {
    return OnboardingReadiness(
      ready: json['ready'] == true || json['isReady'] == true,
      title: _str(json, const ['title', 'heading']) ?? '',
      body:
          _str(json, const ['body', 'summary', 'message', 'description']) ?? '',
    );
  }
}

class OnboardingNextStep {
  const OnboardingNextStep({
    required this.code,
    required this.title,
    required this.taskLabel,
  });

  final String code;
  final String title;
  final String taskLabel;

  factory OnboardingNextStep.fromJson(Map<String, dynamic> json) {
    final nested = _map(json['step']) ?? json;
    return OnboardingNextStep(
      code: _str(nested, const ['stepCode', 'code', 'key', 'id']) ?? '',
      title: _str(nested, const ['title', 'name']) ?? '',
      taskLabel:
          _str(json, const [
            'taskLabel',
            'label',
            'summary',
            'validationNotes',
          ]) ??
          _str(nested, const ['title', 'name', 'validationNotes']) ??
          '',
    );
  }
}

class OnboardingActivity {
  const OnboardingActivity({required this.message, this.at});

  final String message;
  final DateTime? at;

  factory OnboardingActivity.fromJson(Map<String, dynamic> json) {
    final raw = _str(json, const [
      'occurredAtUtc',
      'at',
      'occurredAt',
      'createdAt',
    ]);
    final title = _str(json, const ['title', 'message', 'summary']) ?? '';
    final detail = _str(json, const ['detail', 'notes']) ?? '';
    final message = detail.isEmpty || detail == title
        ? title
        : '$title · $detail';
    return OnboardingActivity(
      message: message,
      at: raw == null ? null : DateTime.tryParse(raw)?.toLocal(),
    );
  }
}

/// Maps whatever the server returned onto the six Locked V1 steps.
/// A seventh marketing task, such as communication setup, is ignored.
List<OnboardingStep> mergeLockedSteps(List<OnboardingStep>? remote) {
  final source = remote ?? const <OnboardingStep>[];
  final used = <int>{};
  return [
    for (final locked in lockedOnboardingSteps)
      _mergeOne(locked, source, used, remote == null),
  ];
}

OnboardingStep _mergeOne(
  LockedOnboardingStep locked,
  List<OnboardingStep> source,
  Set<int> used,
  bool serviceMissing,
) {
  var bestIndex = -1;
  var bestScore = 99;
  for (var i = 0; i < source.length; i++) {
    if (used.contains(i) || _excluded(source[i])) continue;
    final score = _score(locked, source[i]);
    if (score < bestScore) {
      bestScore = score;
      bestIndex = i;
    }
  }
  if (bestIndex < 0 || bestScore >= 99) {
    return OnboardingStep(
      code: locked.code,
      order: locked.order,
      title: locked.title,
      summary: serviceMissing
          ? 'Waiting for the onboarding service.'
          : 'The server did not return this step.',
      status: OnboardingStepStatus.unavailable,
    );
  }
  used.add(bestIndex);
  final match = source[bestIndex];
  return OnboardingStep(
    code: locked.code,
    order: locked.order,
    title: locked.title,
    summary: match.summary,
    status: match.status,
    recommended: match.recommended,
    actionLabel: match.actionLabel,
    checks: match.checks,
    badges: match.badges,
    note: match.note,
  );
}

int _score(LockedOnboardingStep locked, OnboardingStep step) {
  final code = _norm(step.code);
  final compact = _compact(step.code);
  final title = _norm(step.title);
  if (code.isNotEmpty && code == _norm(locked.code)) return 0;
  if (compact.isNotEmpty && compact == _compact(locked.code)) return 0;
  // Backend enums arrive as PlantDetails / ItemsAndOpenings.
  if (compact.isNotEmpty && compact == _compact(locked.title)) return 0;
  if (title.isNotEmpty && title == _norm(locked.title)) return 1;
  for (final alias in locked.aliases) {
    final needle = _norm(alias);
    final compactNeedle = _compact(alias);
    if (needle.isEmpty) continue;
    if (code.contains(needle) ||
        title.contains(needle) ||
        compact.contains(compactNeedle)) {
      return 2;
    }
  }
  return 99;
}

String _compact(String value) =>
    value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');

bool _excluded(OnboardingStep step) {
  final blob = _norm('${step.code} ${step.title}');
  return blob.contains('communication') ||
      blob.contains('whatsapp') ||
      blob.contains('trackboard') ||
      blob.contains('spot billing') ||
      blob.contains('sms');
}

String _norm(String value) =>
    value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();

OnboardingStepStatus _status(String? raw) {
  final value = _norm(raw ?? '').replaceAll(' ', '');
  if (value.isEmpty) return OnboardingStepStatus.unavailable;
  if (value.contains('complete') || value == 'done') {
    return OnboardingStepStatus.completed;
  }
  if (value.contains('progress') || value == 'current' || value == 'active') {
    return OnboardingStepStatus.inProgress;
  }
  if (value.contains('notstart') ||
      value == 'pending' ||
      value == 'todo' ||
      value == 'open') {
    return OnboardingStepStatus.notStarted;
  }
  return OnboardingStepStatus.notStarted;
}

String? _str(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
  }
  return null;
}

int? _int(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is int) return value;
    if (value is num) return value.round();
    if (value is String) return int.tryParse(value);
  }
  return null;
}

bool? _bool(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is bool) return value;
  }
  return null;
}

List<String> _strings(Object? raw) {
  if (raw is! List) return const [];
  return [
    for (final item in raw)
      if (item is String && item.trim().isNotEmpty)
        item.trim()
      else if (item is Map && item['label'] is String)
        (item['label'] as String).trim(),
  ];
}

Map<String, dynamic>? _map(Object? raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) return Map<String, dynamic>.from(raw);
  return null;
}
