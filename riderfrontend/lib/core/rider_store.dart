import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'format.dart';
import 'models.dart';

class RiderStore extends ChangeNotifier {
  RiderStore({
    this.authDelay = const Duration(milliseconds: 700),
    this.customerLoadDelay = const Duration(milliseconds: 450),
  });

  static const _storageKey = 'aquarider.entries.v1';

  final Duration authDelay;
  final Duration customerLoadDelay;

  final RiderProfile rider = kRider;
  DeliveryDraft _draft = DeliveryDraft();
  List<DeliveryEntry> _entries = [];
  SharedPreferences? _prefs;
  bool _ready = false;
  bool _saving = false;
  bool _customersLoading = false;
  bool _customersReady = false;

  DeliveryDraft get draft => _draft;
  bool get ready => _ready;
  bool get saving => _saving;
  bool get customersLoading => _customersLoading;
  bool get customersReady => _customersReady;

  List<Customer> get customers {
    final copy = [...kCustomers];
    copy.sort((a, b) {
      if (a.scheduledToday != b.scheduledToday) {
        return a.scheduledToday ? -1 : 1;
      }
      return a.name.compareTo(b.name);
    });
    return copy;
  }

  List<DeliveryEntry> get entries => List.unmodifiable(_entries);

  List<DeliveryEntry> get today {
    final now = DateTime.now();
    return _entries.where((entry) => isSameDay(entry.savedAt, now)).toList();
  }

  int get todayFullBottles =>
      today.fold(0, (sum, entry) => sum + entry.fullBottles);

  int get todayCollected => today.fold(0, (sum, entry) {
    if (entry.method == PaymentMethod.unpaid) return sum;
    return sum + entry.amount;
  });

  List<DeliveryEntry> filtered(EntryFilter filter) {
    return switch (filter) {
      EntryFilter.all => today,
      EntryFilter.cash =>
        today.where((entry) => entry.method == PaymentMethod.cash).toList(),
      EntryFilter.online =>
        today.where((entry) => entry.method == PaymentMethod.online).toList(),
      EntryFilter.unpaid =>
        today.where((entry) => entry.method == PaymentMethod.unpaid).toList(),
    };
  }

  int countFor(EntryFilter filter) => filtered(filter).length;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _prefs = prefs;
    final raw = prefs.getString(_storageKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          final loaded = <DeliveryEntry>[];
          for (final item in decoded) {
            if (item is! Map) continue;
            try {
              loaded.add(
                DeliveryEntry.fromJson(Map<String, dynamic>.from(item)),
              );
            } on FormatException {
              // Skip a damaged record instead of blocking the rest of the day.
            } on TypeError {
              // Skip a damaged record instead of blocking the rest of the day.
            } on ArgumentError {
              // Skip a record whose saved payment type is no longer known.
            }
          }
          _entries = loaded;
        }
      } on FormatException {
        // Ignore a damaged local file and start with an empty day.
      }
    }
    _ready = true;
    notifyListeners();
  }

  Future<void> prepareCustomers() async {
    if (_customersReady || _customersLoading) return;
    _customersLoading = true;
    notifyListeners();
    if (customerLoadDelay > Duration.zero) {
      await Future<void>.delayed(customerLoadDelay);
    }
    _customersLoading = false;
    _customersReady = true;
    notifyListeners();
  }

  Future<LoginFailure?> signIn({
    required String phone,
    required String pin,
  }) async {
    if (authDelay > Duration.zero) {
      await Future<void>.delayed(authDelay);
    }
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits != kRegisteredPhone) return LoginFailure.unknownPhone;
    if (pin != kRegisteredPin) return LoginFailure.wrongPin;
    return null;
  }

  void selectCustomer(Customer customer) {
    _draft.customer = customer;
    notifyListeners();
  }

  void setFull(int value) {
    _draft.fullBottles = value < 0 ? 0 : value;
    if (!_draft.amountTouched) _draft.amount = _draft.bill;
    notifyListeners();
  }

  void setEmpty(int value) {
    _draft.emptyBottles = value < 0 ? 0 : value;
    notifyListeners();
  }

  void setMethod(PaymentMethod method) {
    _draft.method = method;
    notifyListeners();
  }

  void setAmount(int? amount, {required bool touched}) {
    _draft.amount = amount;
    _draft.amountTouched = touched;
    notifyListeners();
  }

  void setProvider(PaymentProvider provider) {
    _draft.provider = provider;
    notifyListeners();
  }

  void setReference(String value) {
    _draft.reference = value;
    notifyListeners();
  }

  void setProof(String? path) {
    _draft.proofPath = path;
    notifyListeners();
  }

  void ensureAmountDefault() {
    if (!_draft.amountTouched) _draft.amount = _draft.bill;
    notifyListeners();
  }

  void clearDraft() {
    _draft = DeliveryDraft();
    notifyListeners();
  }

  /// Writes the open draft onto the phone. A second call while a save is
  /// running, or after the draft has been cleared, does not create another
  /// entry. [synced] stays false until [confirmServerSync].
  Future<DeliveryEntry?> saveDraft() async {
    final customer = _draft.customer;
    if (_saving || customer == null || !_draft.hasQuantity) return null;
    _saving = true;
    notifyListeners();

    final entry = DeliveryEntry(
      id: 'AQ-${DateTime.now().microsecondsSinceEpoch}',
      customerId: customer.id,
      customerName: customer.name,
      area: customer.area,
      address: customer.address,
      phone: customer.phone,
      fullBottles: _draft.fullBottles,
      emptyBottles: _draft.emptyBottles,
      method: _draft.method,
      amount: _draft.settledAmount,
      billAmount: _draft.bill,
      previousBalance: customer.balance,
      provider: _draft.method == PaymentMethod.online ? _draft.provider : null,
      reference:
          _draft.method == PaymentMethod.online &&
              _draft.reference.trim().isNotEmpty
          ? _draft.reference.trim()
          : null,
      proofPath: _draft.method == PaymentMethod.online
          ? _draft.proofPath
          : null,
      savedAt: DateTime.now(),
    );

    _entries = [entry, ..._entries];
    try {
      await _persist();
    } on Object {
      _entries = _entries.where((item) => item.id != entry.id).toList();
      _saving = false;
      notifyListeners();
      rethrow;
    }

    _draft = DeliveryDraft();
    _saving = false;
    notifyListeners();
    return entry;
  }

  /// Call this only after a server has confirmed the entry.
  Future<void> confirmServerSync(String id) async {
    final index = _entries.indexWhere((entry) => entry.id == id);
    if (index < 0 || _entries[index].synced) return;
    _entries[index] = _entries[index].copyWith(synced: true);
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = _prefs;
    if (prefs == null) {
      throw StateError('Local storage is not ready.');
    }
    final encoded = jsonEncode(
      _entries.map((entry) => entry.toJson()).toList(),
    );
    final saved = await prefs.setString(_storageKey, encoded);
    if (!saved) {
      throw StateError('The phone could not store this entry.');
    }
  }
}

class RiderScope extends InheritedNotifier<RiderStore> {
  const RiderScope({required RiderStore store, required super.child, super.key})
    : super(notifier: store);

  static RiderStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<RiderScope>();
    assert(scope != null, 'RiderScope is missing above this widget.');
    return scope!.notifier!;
  }
}
