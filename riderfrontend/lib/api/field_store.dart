import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import '../core/rider_telemetry_service.dart';
import 'route_api.dart';

class FieldStore extends ChangeNotifier {
  FieldStore(this.api);

  final RouteApi api;
  DashboardData? dashboard;
  List<StopItem> stops = [];
  String stopSearch = '';
  String stopFilter = 'all';
  StopItem? selectedStop;
  CustomerDetail? customer;
  SaleContext? saleContext;
  SaleDraft? draft;
  String paymentMethod = 'Cash';
  int? amountReceived;
  bool closeStop = true;
  int collectionAmount = 0;
  String collectionChannel = 'Cash';
  int collectionWithholding = 0;
  String collectionNote = '';
  bool collecting = false;
  ReceiptData? receipt;
  LedgerData? ledger;
  ShiftData? shift;
  HistoryData? history;
  SettingsData? settings;
  List<PrinterItem> printers = [];
  final Map<String, Uint8List> storefronts = {};
  int? salePrefill;
  bool loading = false;
  String? error;

  Future<void> loadHome() => _guard(() async {
    dashboard = await api.dashboard();
  });

  Future<void> loadStops() => _guard(() async {
    stops = await api.stops(search: stopSearch, filter: stopFilter);
  });

  Future<void> saveStopOrder(List<String> orderedStopIds) => _guard(() async {
    stopFilter = 'all';
    stops = await api.sequenceTodayStops(orderedStopIds: orderedStopIds);
  });

  Future<void> openStop(StopItem stop) => _guard(() async {
    selectedStop = stop;
    customer = await api.customer(stop.customerId);
    draft = null;
    receipt = null;
    collecting = false;
  });

  Future<void> loadSale() => _guard(() async {
    final id = customer?.id;
    if (id == null) return;
    saleContext = await api.saleContext(id);
  });

  Future<void> saveDraft(
    Map<String, int> quantities, {
    int? emptyBottlesReturned,
  }) => _guard(() async {
    final id = customer?.id;
    if (id == null) return;
    draft = await api.createSale(
      customerId: id,
      stopId: selectedStop?.id,
      quantities: quantities,
      emptyBottlesReturned: emptyBottlesReturned,
    );
  });

  Future<void> completeSale({
    String? signerName,
    String? signerRole,
    String? signatureImage,
    String? signatureNote,
  }) => _guard(() async {
    final id = draft?.id;
    if (id == null) return;
    receipt = await api.completeSale(
      saleId: id,
      method: paymentMethod,
      signerName:
          signerName ??
          customer?.contactName ??
          customer?.businessName ??
          'Customer',
      signerRole: signerRole ?? customer?.contactRole,
      amountReceived: amountReceived,
      closeStop: closeStop,
      signatureImage: signatureImage,
      signatureNote: signatureNote,
    );
    collecting = false;
  });

  Future<void> completeCollection({
    String? signerName,
    String? signerRole,
    String? signatureImage,
    String? signatureNote,
  }) => _guard(() async {
    final id = customer?.id;
    if (id == null) return;
    receipt = await api.collect(
      customerId: id,
      amount: collectionAmount,
      channel: collectionChannel,
      signerName:
          signerName ??
          customer?.contactName ??
          customer?.businessName ??
          'Customer',
      signerRole: signerRole ?? customer?.contactRole,
      signatureImage: signatureImage,
      signatureNote: signatureNote,
      withholdingTax: collectionWithholding,
      note: collectionNote.isEmpty ? null : collectionNote,
    );
  });

  Future<void> placeOrder(
    Map<String, int> quantities,
    String window, {
    String? deliveryDate,
    String? note,
    bool showOnManifest = true,
  }) => _guard(() async {
    final id = customer?.id;
    if (id == null) return;
    await api.createOrder(
      customerId: id,
      quantities: quantities,
      window: window,
      deliveryDate: deliveryDate,
      note: note,
      showOnManifest: showOnManifest,
    );
  });

  Future<void> loadLedger() => _guard(() async {
    final id = customer?.id;
    if (id == null) return;
    ledger = await api.ledger(id);
  });

  Future<void> loadShift() => _guard(() async {
    shift = await api.currentShift();
  });

  Future<void> startShift(
    List<Map<String, dynamic>> stock, {
    required int openingOdometer,
    String? odometerPhoto,
    String? inspectionPhoto,
  }) => _guard(() async {
    shift = await api.startShift(
      stock,
      openingOdometer: openingOdometer,
      odometerPhoto: odometerPhoto,
      inspectionPhoto: inspectionPhoto,
    );
    try {
      await RiderTelemetryService.instance.startForShift(api);
    } catch (_) {
      // Shift remains open; rider can retry location sharing from compliance screen.
    }
    await loadHome();
  });

  Future<void> endShift({
    required int closingOdometer,
    String? odometerPhoto,
    String? inspectionPhoto,
    List<Map<String, dynamic>> stock = const [],
  }) => _guard(() async {
    await RiderTelemetryService.instance.stop(reason: 'ShiftEnded');
    shift = await api.endShift(
      closingOdometer: closingOdometer,
      odometerPhoto: odometerPhoto,
      inspectionPhoto: inspectionPhoto,
      stock: stock,
    );
    await loadHome();
  });

  Future<void> loadHistory(String search, {String? date}) => _guard(() async {
    history = await api.history(search: search, date: date);
  });

  Future<void> loadSettings() => _guard(() async {
    settings = await api.settings();
    printers = await api.printers();
  });

  void reset() {
    dashboard = null;
    stops = [];
    stopSearch = '';
    stopFilter = 'all';
    selectedStop = null;
    customer = null;
    saleContext = null;
    draft = null;
    paymentMethod = 'Cash';
    amountReceived = null;
    closeStop = true;
    collectionAmount = 0;
    collectionChannel = 'Cash';
    collectionWithholding = 0;
    collectionNote = '';
    collecting = false;
    receipt = null;
    ledger = null;
    shift = null;
    history = null;
    settings = null;
    printers = [];
    storefronts.clear();
    salePrefill = null;
    loading = false;
    error = null;
    notifyListeners();
  }

  Future<void> saveSettings(SettingsData value) => _guard(() async {
    settings = await api.updateSettings(value);
    printers = await api.printers();
  });

  Future<String> printReceipt() async {
    final id = receipt?.id;
    if (id == null || receipt?.kind != 'Sale') {
      return 'This document cannot be printed yet.';
    }
    return api.printReceipt(id);
  }

  void saveStorefront(String customerId, Uint8List bytes) {
    storefronts[customerId] = bytes;
    notifyListeners();
  }

  Future<void> logVisit(String outcome) => _guard(() async {
    final id = customer?.id;
    if (id == null) return;
    await api.logVisit(id, outcome);
  });

  Future<CustomerDetail> saveCustomer(CustomerDraft draft) async {
    final saved = await api.saveCustomer(draft);
    customer = saved;
    notifyListeners();
    return saved;
  }

  Future<void> _guard(Future<void> Function() action) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      await action();
    } on ApiException catch (exception) {
      error = exception.message;
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}

class FieldScope extends InheritedNotifier<FieldStore> {
  const FieldScope({required FieldStore store, required super.child, super.key})
    : super(notifier: store);

  static FieldStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<FieldScope>();
    assert(scope != null, 'FieldScope is missing above this widget.');
    return scope!.notifier!;
  }
}
