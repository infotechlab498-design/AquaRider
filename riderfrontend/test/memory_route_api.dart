import 'package:riderfrontend/adminDashboard/data/admin_shift_models.dart';
import 'package:riderfrontend/adminDashboard/data/recurring_schedule_models.dart';
import 'package:riderfrontend/adminDashboard/data/fleet_tracking_models.dart';
import 'package:riderfrontend/api/route_api.dart';

class MemoryRouteApi implements RouteApi {
  MemoryRouteApi({
    this.kpisOverride,
    this.collectionsOverride,
    this.locationVerifications = const [],
    this.dispatchSummary,
    this.dispatchCounts,
    this.dispatchPage,
    this.dispatchDetail,
    this.dispatchDetailsById,
    this.dispatchItems,
    this.dispatchLifecycle,
    this.dispatchPickList,
    this.dispatchOperational,
    this.dispatchRiders,
    this.dispatchPrepareError,
    this.dispatchReassignError,
    this.dispatchCancelError,
    this.dispatchLatency,
    this.pricingCoverageValue,
    this.pricingCategories,
    this.pricingCatalogue,
    this.pricingValidation,
    this.pricingHistoryMessage,
  });

  final DashboardKpiSet? kpisOverride;
  final CollectionsSummary? collectionsOverride;
  final List<LocationVerification> locationVerifications;
  DispatchOrderSummary? dispatchSummary;
  DispatchStatusCounts? dispatchCounts;
  DispatchOrderPage? dispatchPage;
  DispatchOrderDetail? dispatchDetail;
  Map<String, DispatchOrderDetail>? dispatchDetailsById;
  List<DispatchOrderItem>? dispatchItems;
  List<DispatchLifecycleEvent>? dispatchLifecycle;
  DispatchPickList? dispatchPickList;
  DispatchOperationalSummary? dispatchOperational;
  List<EligibleRider>? dispatchRiders;
  String? dispatchPrepareError;
  String? dispatchReassignError;
  String? dispatchCancelError;
  Duration? dispatchLatency;
  PricingCoverage? pricingCoverageValue;
  List<ProductCategoryGroup>? pricingCategories;
  ProductCataloguePage? pricingCatalogue;
  BasePriceValidation? pricingValidation;
  String? pricingHistoryMessage;
  final List<PriceListSummary> priceListRows = [];
  final Map<String, PriceListDetail> priceListDetails = {};
  CreatePriceListRequest? lastPriceList;

  Future<T> _maybeDelay<T>(T value) async {
    final latency = dispatchLatency;
    if (latency != null) await Future<void>.delayed(latency);
    return value;
  }

  static const dashboardUnavailable =
      'The command dashboard is not available on this server.';
  static const riderUnavailable =
      'Rider operations are not available on this server.';
  static const dispatchUnavailable =
      'Dispatch orders are not available on this server.';

  var _stock = 80;
  var _billed = 18500;
  var _sales = 9;

  Map<String, dynamic>? lastCustomerRegistration;

  @override
  Future<CustomerRegistration> registerCustomer(Map<String, dynamic> body) async {
    lastCustomerRegistration = body;
    final email = '${body['email'] ?? ''}'.trim().toLowerCase();
    if (email == 'taken@example.com') {
      throw ApiException('An account with this email already exists.', statusCode: 409);
    }
    return CustomerRegistration(
      customerCode: 'CUS-000001',
      fullName: '${body['firstName'] ?? ''} ${body['lastName'] ?? ''}'.trim(),
      email: email,
    );
  }

  @override
  Future<AuthSession?> currentSession() async => null;

  @override
  Future<AuthSession> login(
    String username,
    String password, {
    bool rememberMe = false,
  }) async {
    if ((username == 'usama.admin' ||
            username == 'infotechlab498@gmail.com') &&
        (password == 'admin-pass' || password == 'info498@')) {
      return const AuthSession(
        accessToken: 'access',
        refreshToken: 'refresh',
        fullName: 'HQ Super Admin',
        username: 'infotechlab498@gmail.com',
        riderCode: '',
        routeName: '',
        vehicleName: '',
        vehiclePlate: '',
        fleetCode: '',
        depotGate: '',
        depotName: '',
        role: 'Admin',
      );
    }
    if (username != 'ahmed.khan' || password != 'routeledger1') {
      throw ApiException('Incorrect username or password.');
    }
    return const AuthSession(
      accessToken: 'access',
      refreshToken: 'refresh',
      fullName: 'Ahmed Khan',
      username: 'ahmed.khan',
      riderCode: 'RDR-1042',
      routeName: 'Satellite Town – Route 03',
      vehicleName: 'Toyota HiAce',
      vehiclePlate: 'LEA-8841',
      fleetCode: 'PK-RAW-4482',
      depotGate: 'Zone C - Bay 04',
      depotName: 'Warehouse Depot Hub 02',
    );
  }

  @override
  Future<AdminLoginPreview> adminLoginPreview() async {
    return const AdminLoginPreview(
      operationalDate: '2026-11-19',
      todaysBilledSales: 185000,
      previousBilledSales: 162000,
      billedChangePercent: 14.2,
      cashReconciled: 92500,
      dropsBalanced: 18,
      dropsTotal: 22,
      scopeNote: 'Memory preview',
    );
  }

  @override
  Future<void> logout({bool clearLocal = false}) async {}

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {}

  @override
  Future<void> forgotPassword(String username) async {}

  @override
  Future<DashboardData> dashboard() async {
    return DashboardData(
      greeting: 'Good Morning, Ahmed',
      serviceDate: '2026-11-17',
      shiftOpen: false,
      riderName: 'Ahmed Khan',
      riderCode: 'RDR-1042',
      routeName: 'Satellite Town – Route 03',
      vehicleName: 'Toyota HiAce',
      vehiclePlate: 'LEA-8841',
      fleetCode: 'PK-RAW-4482',
      depotGate: 'Zone C - Bay 04',
      depotName: 'Warehouse Depot Hub 02',
      billedSales: _billed,
      salesCount: _sales,
      cashCollected: 7200,
      visitedCount: 12,
      totalStops: 28,
      pendingDeliveries: 4,
      pendingNote: 'Urgent · before 12:00',
      remainingStops: 16,
      nextStopName: 'Al-Rehman Mart',
      nextDistanceMeters: 400,
      remainingDistanceKm: 14.8,
      openTodoCount: 16,
    );
  }

  final List<StopItem> _queueStops = [
    const StopItem(
      id: 'stop-1',
      customerId: 'c-ali',
      sequence: 2,
      customerName: 'Ali General Store',
      customerCode: 'CUS-1001',
      address: 'Commercial Market, Satellite Town',
      phone: '+92 300 1234567',
      status: 'Pending',
      scheduledTime: '09:30 AM',
      outstanding: 2500,
      emptyBottles: 3,
      distanceMeters: 900,
      actionLabel: 'Start Delivery',
      receiptSaleId: null,
      invoiceNumber: null,
    ),
  ];

  @override
  Future<List<StopItem>> stops({String? search, String? filter}) async {
    final term = search?.trim().toLowerCase() ?? '';
    return [
      for (final stop in _queueStops)
        if (term.isEmpty ||
            stop.customerName.toLowerCase().contains(term) ||
            stop.customerCode.toLowerCase().contains(term) ||
            stop.phone.toLowerCase().contains(term) ||
            stop.address.toLowerCase().contains(term))
          stop,
    ];
  }

  @override
  Future<List<StopItem>> sequenceTodayStops({
    required List<String> orderedStopIds,
  }) async {
    if (orderedStopIds.toSet().length != _queueStops.length ||
        orderedStopIds.length != _queueStops.length) {
      throw StateError('Sequence must include every stop for the day exactly once.');
    }
    final map = {for (final stop in _queueStops) stop.id: stop};
    final next = <StopItem>[];
    for (var index = 0; index < orderedStopIds.length; index++) {
      final stop = map[orderedStopIds[index]];
      if (stop == null) {
        throw StateError('Sequence includes a stop that is not on today\'s route.');
      }
      next.add(
        StopItem(
          id: stop.id,
          customerId: stop.customerId,
          sequence: index + 1,
          customerName: stop.customerName,
          customerCode: stop.customerCode,
          address: stop.address,
          phone: stop.phone,
          status: stop.status,
          scheduledTime: stop.scheduledTime,
          outstanding: stop.outstanding,
          emptyBottles: stop.emptyBottles,
          distanceMeters: stop.distanceMeters,
          actionLabel: stop.actionLabel,
          receiptSaleId: stop.receiptSaleId,
          invoiceNumber: stop.invoiceNumber,
          latitude: stop.latitude,
          longitude: stop.longitude,
        ),
      );
    }
    _queueStops
      ..clear()
      ..addAll(next);
    return List<StopItem>.of(_queueStops);
  }

  @override
  Future<CustomerDetail> customer(String id) async => _ali;

  @override
  Future<SaleContext> saleContext(String customerId) async {
    return SaleContext(
      customer: _ali,
      products: [
        ProductItem(
          id: 'p19',
          name: '19L Water Bottle',
          unitPrice: 180,
          unitLabel: 'unit',
          vanStock: _stock,
          depotExpected: 80,
          isReturnable: true,
        ),
        const ProductItem(
          id: 'p500',
          name: '500ml Water Bottle Pack',
          unitPrice: 250,
          unitLabel: 'pack',
          vanStock: 120,
          depotExpected: 120,
          isReturnable: false,
        ),
        const ProductItem(
          id: 'p15',
          name: '1.5L Water Bottle Pack',
          unitPrice: 320,
          unitLabel: 'pack',
          vanStock: 45,
          depotExpected: 45,
          isReturnable: false,
        ),
      ],
      emptyBottlesHeld: 3,
    );
  }

  @override
  Future<SaleDraft> createSale({
    required String customerId,
    String? stopId,
    required Map<String, int> quantities,
    int? emptyBottlesReturned,
  }) async {
    final qty = quantities['p19'] ?? 0;
    final amount = qty * 180;
    final returned = emptyBottlesReturned ?? (qty > 3 ? 3 : qty);
    return SaleDraft(
      id: 'sale-1',
      customerId: customerId,
      saleAmount: amount,
      previousOutstanding: 2500,
      amountDue: amount + 2500,
      emptyBottlesReturned: returned,
      emptyBottlesRemaining: returned >= 3 ? 0 : 3 - returned,
      receiptNumber: 'DFT-4091',
      lines: [
        SaleLineItem(
          productId: 'p19',
          name: '19L Water Bottle',
          quantity: qty,
          unitPrice: 180,
          lineTotal: amount,
        ),
      ],
    );
  }

  @override
  Future<ReceiptData> completeSale({
    required String saleId,
    required String method,
    required String signerName,
    String? signerRole,
    int? amountReceived,
    bool closeStop = true,
    String? signatureImage,
    String? signatureNote,
  }) async {
    _stock -= 2;
    _billed += 360;
    _sales += 1;
    return _receipt;
  }

  @override
  Future<ReceiptData> receipt(String saleId) async => _receipt;

  @override
  Future<ReceiptData> collect({
    required String customerId,
    required num amount,
    required String channel,
    required String signerName,
    String? signerRole,
    String? signatureImage,
    String? signatureNote,
    int withholdingTax = 0,
    String? note,
  }) async => _receipt;

  @override
  Future<void> createOrder({
    required String customerId,
    required Map<String, int> quantities,
    required String window,
    String? deliveryDate,
    String? note,
    bool showOnManifest = true,
  }) async {}

  @override
  Future<LedgerData> ledger(String customerId) async {
    return LedgerData(
      customerId: customerId,
      customerName: 'Ali General Store',
      customerCode: 'CUS-1001',
      outstanding: 2500,
      creditDays: 7,
      bottlesIssued: 10,
      bottlesReturned: 7,
      bottlesHeld: 3,
      openOrders: 1,
      todayCollected: 0,
      stopSequence: 2,
      entries: [
        LedgerRow(
          id: 'sale-1',
          description: 'Previous Sale (19L x 3)',
          occurredAt: DateTime.utc(2026, 11, 14, 9, 15),
          amount: 540,
          balanceAfter: 2500,
          kind: 'Sale',
          reference: 'INV-3980',
          detail: 'Ahmed Khan',
        ),
        LedgerRow(
          id: 'pay-1',
          description: 'Cash collection',
          occurredAt: DateTime.utc(2026, 3, 14, 9),
          amount: -3000,
          balanceAfter: 1960,
          kind: 'Payment',
          detail: 'Cash',
        ),
      ],
      movements: [
        BottleMovement(
          occurredAt: DateTime.utc(2026, 11, 14, 9, 15),
          fullGiven: 3,
          emptiesReturned: 1,
          holdingAfter: 3,
          note: 'Regular delivery',
        ),
      ],
    );
  }

  @override
  Future<ShiftData> currentShift() async {
    return const ShiftData(
      id: null,
      status: 'Closed',
      serviceDate: '2026-11-17',
      openingOdometer: 45820,
      fleetCode: 'PK-RAW-4482',
      routeLabel: 'Satellite Town – Route 03 · Sector 4B',
      depotLabel: 'Satellite Town, Rawalpindi',
      lines: [],
    );
  }

  @override
  Future<ShiftData> startShift(
    List<Map<String, dynamic>> stock, {
    required int openingOdometer,
    String? odometerPhoto,
    String? inspectionPhoto,
  }) => currentShift();

  @override
  Future<ShiftData> endShift({
    required int closingOdometer,
    String? odometerPhoto,
    String? inspectionPhoto,
    List<Map<String, dynamic>> stock = const [],
  }) => currentShift();

  @override
  Future<HistoryData> history({String? search, String? date}) async {
    return const HistoryData(synced: 1, pending: 1, failed: 1, items: []);
  }

  @override
  Future<SettingsData> settings() async {
    return const SettingsData(
      autoSync: true,
      showOrdersTab: true,
      language: 'English (US)',
      autoPrint: false,
      deleteOnLogout: false,
      paperSize: '58mm',
      printerId: null,
      printerName: null,
    );
  }

  @override
  Future<SettingsData> updateSettings(SettingsData value) async => value;

  @override
  Future<List<PrinterItem>> printers() async => [];

  @override
  Future<String> printReceipt(String saleId) async => 'Print job queued.';

  @override
  Future<CustomerDetail> saveCustomer(CustomerDraft draft) async => _ali;

  @override
  Future<void> logVisit(String customerId, String outcome) async {}

  @override
  Future<SsoStatus> ssoStatus() async {
    return const SsoStatus(
      available: false,
      message: 'Corporate single sign-on is not available on this server.',
    );
  }

  @override
  Future<OnboardingOverview?> onboardingOverview() async => null;

  @override
  Future<List<OnboardingStep>?> onboardingSteps() async => null;

  @override
  Future<OnboardingProgress?> onboardingProgress() async => null;

  @override
  Future<OnboardingReadiness?> onboardingReadiness() async => null;

  @override
  Future<OnboardingNextStep?> onboardingNextStep() async => null;

  @override
  Future<List<OnboardingActivity>?> onboardingActivity() async => null;

  @override
  Future<CommandOverview> commandOverview({
    required String from,
    required String to,
  }) async {
    throw ApiException(dashboardUnavailable, statusCode: 404);
  }

  @override
  Future<DashboardKpiSet> commandKpis({
    required String from,
    required String to,
  }) async {
    final override = kpisOverride;
    if (override == null) {
      throw ApiException(dashboardUnavailable, statusCode: 404);
    }
    return override;
  }

  @override
  Future<OperationalSummary> operationalSummary({
    required String from,
    required String to,
  }) async {
    throw ApiException(dashboardUnavailable, statusCode: 404);
  }

  @override
  Future<List<AttentionItem>> attentionItems({
    required String from,
    required String to,
  }) async {
    throw ApiException(dashboardUnavailable, statusCode: 404);
  }

  @override
  Future<SalesSummary> salesSummary({
    required String from,
    required String to,
    required String bucket,
  }) async {
    throw ApiException(dashboardUnavailable, statusCode: 404);
  }

  @override
  Future<CollectionsSummary> collectionsSummary({
    required String from,
    required String to,
  }) async {
    final override = collectionsOverride;
    if (override == null) {
      throw ApiException(dashboardUnavailable, statusCode: 404);
    }
    return override;
  }

  @override
  Future<ActivityLedgerPage> activityLedger({
    required String from,
    required String to,
    String? search,
    String? status,
    int page = 1,
    int pageSize = 8,
  }) async {
    throw ApiException(dashboardUnavailable, statusCode: 404);
  }

  @override
  Future<AdminOrderResult> createDashboardOrder(
    AdminOrderRequest request,
  ) async {
    throw ApiException(dashboardUnavailable, statusCode: 404);
  }

  @override
  Future<RiderOperationsSummary> riderOperationsSummary({
    required String date,
  }) async {
    throw ApiException(riderUnavailable, statusCode: 404);
  }

  @override
  Future<List<RiderRecord>> riderOperationsRiders({
    String? search,
    String? status,
    required String date,
  }) async {
    throw ApiException(riderUnavailable, statusCode: 404);
  }

  @override
  Future<RiderRecord> riderOperationsRider(
    String id, {
    required String date,
  }) async {
    throw ApiException(riderUnavailable, statusCode: 404);
  }

  @override
  Future<List<RiderActivityItem>> riderOperationsActivity(String id) async {
    throw ApiException(riderUnavailable, statusCode: 404);
  }

  @override
  Future<List<RiderAssignment>> riderOperationsAssignments(
    String id, {
    required String date,
  }) async {
    throw ApiException(riderUnavailable, statusCode: 404);
  }

  @override
  Future<List<RiderExceptionItem>> riderOperationsExceptions({
    required String date,
  }) async {
    throw ApiException(riderUnavailable, statusCode: 404);
  }

  @override
  Future<List<LocationVerification>>
  riderOperationsLocationVerifications() async => locationVerifications;

  @override
  Future<DispatchOrderSummary> dispatchOrdersSummary({
    String? from,
    String? to,
  }) async {
    final value = dispatchSummary;
    if (value == null) {
      throw ApiException(dispatchUnavailable, statusCode: 404);
    }
    return value;
  }

  @override
  Future<DispatchStatusCounts> dispatchStatusCounts({
    String? from,
    String? to,
    String? search,
  }) async {
    final value = dispatchCounts;
    if (value == null) {
      throw ApiException(dispatchUnavailable, statusCode: 404);
    }
    return value;
  }

  @override
  Future<DispatchOrderPage> dispatchOrders({
    int page = 1,
    int pageSize = 10,
    String? search,
    String? status,
    String? from,
    String? to,
    String? riderId,
    bool unassignedOnly = false,
  }) async {
    final value = dispatchPage;
    if (value == null) {
      throw ApiException(dispatchUnavailable, statusCode: 404);
    }
    return value;
  }

  @override
  Future<DispatchOrderDetail> dispatchOrder(String id) async {
    final mapped = dispatchDetailsById?[id];
    if (mapped != null) return _maybeDelay(mapped);
    final value = dispatchDetail;
    if (value == null) {
      throw ApiException(dispatchUnavailable, statusCode: 404);
    }
    if (value.order.id.isNotEmpty && value.order.id != id) {
      throw ApiException('Order was not found.', statusCode: 404);
    }
    return _maybeDelay(value);
  }

  @override
  Future<List<DispatchOrderItem>> dispatchOrderItems(String id) async {
    final mapped = dispatchDetailsById?[id];
    if (mapped != null) return _maybeDelay(mapped.items);
    final value = dispatchItems;
    if (value == null) {
      throw ApiException(dispatchUnavailable, statusCode: 404);
    }
    return _maybeDelay(value);
  }

  @override
  Future<List<DispatchLifecycleEvent>> dispatchOrderLifecycle(String id) async {
    final mapped = dispatchDetailsById?[id];
    if (mapped != null) return _maybeDelay(mapped.events);
    final value = dispatchLifecycle;
    if (value == null) {
      throw ApiException(dispatchUnavailable, statusCode: 404);
    }
    return _maybeDelay(value);
  }

  @override
  Future<DispatchPickList> dispatchOrderPickList(String id) async {
    final value = dispatchPickList;
    if (value == null) {
      throw ApiException(dispatchUnavailable, statusCode: 404);
    }
    return _maybeDelay(value);
  }

  @override
  Future<List<EligibleRider>> dispatchEligibleRiders({
    String? orderId,
    String? search,
  }) async {
    final value = dispatchRiders;
    if (value == null) {
      throw ApiException(dispatchUnavailable, statusCode: 404);
    }
    return value;
  }

  @override
  Future<DispatchOperationalSummary> dispatchOperationalSummary({
    String? from,
    String? to,
  }) async {
    final value = dispatchOperational;
    if (value == null) {
      throw ApiException(dispatchUnavailable, statusCode: 404);
    }
    return value;
  }

  @override
  Future<DispatchActionResult> dispatchAssignRider(
    String id, {
    required String riderId,
  }) async {
    return _applyRider(id, riderId, assign: true);
  }

  @override
  Future<DispatchActionResult> dispatchReassignRider(
    String id, {
    required String riderId,
  }) async {
    final error = dispatchReassignError;
    if (error != null && error.trim().isNotEmpty) {
      throw ApiException(error.trim(), statusCode: 400);
    }
    return _applyRider(id, riderId, assign: false);
  }

  @override
  Future<DispatchActionResult> dispatchCancelOrder(
    String id, {
    required String reason,
  }) async {
    final error = dispatchCancelError;
    if (error != null && error.trim().isNotEmpty) {
      throw ApiException(error.trim(), statusCode: 409);
    }
    final current = await dispatchOrder(id);
    final cancelled = DispatchOrderRow(
      id: current.order.id,
      reference: current.order.reference,
      customerName: current.order.customerName,
      customerCode: current.order.customerCode,
      address: current.order.address,
      scheduledDate: current.order.scheduledDate,
      timeWindow: current.order.timeWindow,
      riderName: current.order.riderName,
      riderId: current.order.riderId,
      riderCode: current.order.riderCode,
      estimatedValue: current.order.estimatedValue,
      status: 'cancelled',
      priority: current.order.priority,
    );
    final event = DispatchLifecycleEvent(
      id: 'cancel-${DateTime.now().microsecondsSinceEpoch}',
      title: 'Order cancelled',
      detail: reason,
      occurredAt: DateTime.now().toUtc(),
    );
    _storeDetail(
      DispatchOrderDetail(
        order: cancelled,
        notes: current.notes,
        vehicleName: current.vehicleName,
        phone: current.phone,
        items: current.items,
        events: [...current.events, event],
      ),
    );
    _replaceRow(cancelled);
    return DispatchActionResult(
      message: 'Order cancelled.',
      orderId: id,
      status: 'cancelled',
    );
  }

  @override
  Future<DispatchPickList> dispatchPreparePickList(String id) async {
    final error = dispatchPrepareError;
    if (error != null && error.trim().isNotEmpty) {
      throw ApiException(error.trim(), statusCode: 400);
    }
    final value = dispatchPickList;
    if (value == null) {
      throw ApiException(dispatchUnavailable, statusCode: 404);
    }
    final current = await dispatchOrder(id);
    final event = DispatchLifecycleEvent(
      id: 'pick-${DateTime.now().microsecondsSinceEpoch}',
      title: 'Pick list prepared',
      detail: 'Prepared ${value.lines.length} line(s).',
      occurredAt: DateTime.now().toUtc(),
    );
    _storeDetail(
      DispatchOrderDetail(
        order: current.order,
        notes: current.notes,
        vehicleName: current.vehicleName,
        phone: current.phone,
        items: current.items,
        events: [...current.events, event],
      ),
    );
    dispatchLifecycle = [...(dispatchLifecycle ?? const []), event];
    return value;
  }

  DispatchActionResult _applyRider(
    String id,
    String riderId, {
    required bool assign,
  }) {
    final riders = dispatchRiders ?? const <EligibleRider>[];
    EligibleRider? match;
    for (final rider in riders) {
      if (rider.id == riderId) {
        match = rider;
        break;
      }
    }
    if (match == null) {
      throw ApiException('Choose an eligible rider.', statusCode: 400);
    }
    final page = dispatchPage;
    if (page == null) {
      throw ApiException(dispatchUnavailable, statusCode: 404);
    }
    DispatchOrderRow? currentRow;
    for (final row in page.rows) {
      if (row.id == id) {
        currentRow = row;
        break;
      }
    }
    final previousDetail = dispatchDetailsById?[id] ?? dispatchDetail;
    final previous = previousDetail?.order ?? currentRow;
    if (previous == null) {
      throw ApiException('Order was not found.', statusCode: 404);
    }
    final updated = DispatchOrderRow(
      id: previous.id,
      reference: previous.reference,
      customerName: previous.customerName,
      customerCode: previous.customerCode,
      address: previous.address,
      scheduledDate: previous.scheduledDate,
      timeWindow: previous.timeWindow,
      riderName: match.fullName,
      riderId: match.id,
      riderCode: match.riderCode,
      estimatedValue: previous.estimatedValue,
      status: previous.status.isEmpty ? 'assigned' : previous.status,
      priority: previous.priority,
    );
    final previousLabel = previous.hasRider
        ? '${previous.riderName} (${previous.riderId})'
        : previous.riderId;
    final event = DispatchLifecycleEvent(
      id: 'rider-${DateTime.now().microsecondsSinceEpoch}',
      title: assign ? 'Rider assigned' : 'Rider reassigned',
      detail: assign
          ? 'Assigned rider ${match.fullName} (${match.id}).'
          : 'Previous rider $previousLabel; new rider ${match.fullName} (${match.id}).',
      occurredAt: DateTime.now().toUtc(),
    );
    final existingEvents = previousDetail?.events ?? dispatchLifecycle ?? const [];
    _storeDetail(
      DispatchOrderDetail(
        order: updated,
        notes: previousDetail?.notes,
        vehicleName: previousDetail?.vehicleName ?? '',
        phone: previousDetail?.phone ?? '',
        items: previousDetail?.items ?? dispatchItems ?? const [],
        events: [...existingEvents, event],
      ),
    );
    _replaceRow(updated);
    return DispatchActionResult(
      message: assign ? 'Rider assigned.' : 'Rider reassigned.',
      orderId: id,
      status: updated.status,
    );
  }

  void _storeDetail(DispatchOrderDetail detail) {
    dispatchDetail = detail;
    final map = Map<String, DispatchOrderDetail>.from(
      dispatchDetailsById ?? const {},
    );
    map[detail.order.id] = detail;
    dispatchDetailsById = map;
    dispatchLifecycle = detail.events;
    dispatchItems = detail.items;
  }

  void _replaceRow(DispatchOrderRow updated) {
    final page = dispatchPage;
    if (page == null) return;
    final rows = [
      for (final row in page.rows)
        if (row.id == updated.id) updated else row,
    ];
    dispatchPage = DispatchOrderPage(
      rows: rows,
      page: page.page,
      pageSize: page.pageSize,
      totalRecords: page.totalRecords,
      totalPages: page.totalPages,
    );
  }

  static const dayCloseUnavailable =
      'Day close settlements are not available on this server.';
  static const pricingUnavailable =
      'Product base pricing is not available on this server.';

  @override
  Future<DayCloseSummary> dayCloseSummary({String? date}) async {
    throw ApiException(dayCloseUnavailable, statusCode: 404);
  }

  @override
  Future<SettlementStatusCounts> settlementStatusCounts({
    String? date,
    String? search,
  }) async {
    throw ApiException(dayCloseUnavailable, statusCode: 404);
  }

  @override
  Future<SettlementSessionPage> settlementSessions({
    String? date,
    String? status,
    String? search,
    int page = 1,
    int pageSize = 20,
  }) async {
    throw ApiException(dayCloseUnavailable, statusCode: 404);
  }

  @override
  Future<SettlementSessionDetail> settlementSession(String id) async {
    throw ApiException(dayCloseUnavailable, statusCode: 404);
  }

  @override
  Future<SettlementSessionDetail> settlementSaveDraft(
    String id, {
    num? cashierVerifiedCash,
    String? resolutionCategory,
    String? remarks,
    String? riderAnnotation,
  }) async {
    throw ApiException(dayCloseUnavailable, statusCode: 404);
  }

  @override
  Future<SettlementSessionDetail> settlementVerifyCash(
    String id, {
    required num verifiedAmount,
    String? batchReference,
    String? notes,
  }) async {
    throw ApiException(dayCloseUnavailable, statusCode: 404);
  }

  @override
  Future<SettlementSessionDetail> settlementResolve(
    String id, {
    num? cashierVerifiedCash,
    String? resolutionCategory,
    String? remarks,
  }) async {
    throw ApiException(dayCloseUnavailable, statusCode: 404);
  }

  @override
  Future<DayLockReadiness> settlementLockReadiness(String date) async {
    throw ApiException(dayCloseUnavailable, statusCode: 404);
  }

  @override
  Future<DayLockResult> settlementLockDay(String date, {String? note}) async {
    throw ApiException(dayCloseUnavailable, statusCode: 404);
  }

  @override
  Future<PricingCoverage> pricingCoverage() async {
    final value = pricingCoverageValue;
    if (value == null) {
      throw ApiException(pricingUnavailable, statusCode: 404);
    }
    return value;
  }

  @override
  Future<List<ProductCategoryGroup>> productCategories() async {
    final value = pricingCategories;
    if (value == null) {
      throw ApiException(pricingUnavailable, statusCode: 404);
    }
    return value;
  }

  @override
  Future<ProductCataloguePage> productCatalogue({
    String? categoryKey,
    String? search,
    String? status,
    int page = 1,
    int pageSize = 20,
  }) async {
    final value = pricingCatalogue;
    if (value == null) {
      throw ApiException(pricingUnavailable, statusCode: 404);
    }
    return value;
  }

  @override
  Future<BasePriceValidation> basePriceValidate({
    required String productId,
    int quantity = 1,
  }) async {
    final value = pricingValidation;
    if (value == null) {
      throw ApiException(pricingUnavailable, statusCode: 404);
    }
    return value;
  }

  @override
  Future<CustomerBasePriceLookup> customerBasePriceLookup(
    String customerId,
  ) async {
    throw ApiException(pricingUnavailable, statusCode: 404);
  }

  @override
  Future<String> productPriceHistory(String productId) async {
    final message = pricingHistoryMessage;
    if (message == null) {
      throw ApiException(pricingUnavailable, statusCode: 404);
    }
    return message;
  }

  @override
  Future<List<PriceListSummary>> priceLists() async =>
      List<PriceListSummary>.from(priceListRows);

  @override
  Future<PriceListDetail> priceList(String id) async {
    final detail = priceListDetails[id];
    if (detail == null) {
      throw ApiException('Price list not found.', statusCode: 404);
    }
    return detail;
  }

  @override
  Future<PriceListDetail> createPriceList(CreatePriceListRequest request) async {
    lastPriceList = request;
    final id = 'list-${priceListRows.length + 1}';
    final detail = PriceListDetail(
      id: id,
      code: request.code,
      name: request.name,
      description: request.description ?? '',
      isDefault: request.isDefault,
      isActive: request.isActive,
      effectiveFrom: request.effectiveFrom,
      scope: request.scope,
      routeId: request.routeId ?? '',
      zoneId: request.zoneId ?? '',
      lineCount: request.lines.length,
      lines: [
        for (final line in request.lines)
          PriceListLine(productId: line.productId, listRate: line.listRate),
      ],
    );
    priceListRows.add(detail);
    priceListDetails[id] = detail;
    return detail;
  }

  static const zonesUnavailable =
      'Zones and routes are not available in this test double.';

  @override
  Future<ZonesRoutesSummary> zonesRoutesSummary() async {
    throw ApiException(zonesUnavailable, statusCode: 404);
  }

  @override
  Future<List<ZoneListItem>> listZones({String? search, bool? activeOnly}) async {
    throw ApiException(zonesUnavailable, statusCode: 404);
  }

  @override
  Future<ZoneDetail> zoneDetail(String id) async {
    throw ApiException(zonesUnavailable, statusCode: 404);
  }

  @override
  Future<ZoneDetail> createZone({
    required String name,
    required String sector,
    required String city,
    String? depotId,
    bool isActive = true,
  }) async {
    throw ApiException(zonesUnavailable, statusCode: 404);
  }

  @override
  Future<ZoneDetail> updateZone(
    String id, {
    required String name,
    required String sector,
    required String city,
    String? depotId,
    bool isActive = true,
  }) async {
    throw ApiException(zonesUnavailable, statusCode: 404);
  }

  @override
  Future<void> deactivateZone(String id) async {
    throw ApiException(zonesUnavailable, statusCode: 404);
  }

  @override
  Future<List<RouteListItem>> listRoutes({String? zoneId, String? search}) async {
    throw ApiException(zonesUnavailable, statusCode: 404);
  }

  @override
  Future<RouteDetail> routeDetail(String id) async {
    throw ApiException(zonesUnavailable, statusCode: 404);
  }

  @override
  Future<RouteDetail> createRoute({
    required String name,
    required String zoneId,
    String? sector,
    String? city,
    String? depotId,
  }) async {
    throw ApiException(zonesUnavailable, statusCode: 404);
  }

  @override
  Future<RouteDetail> updateRoute(
    String id, {
    required String name,
    required String zoneId,
    String? sector,
    String? city,
    String? depotId,
  }) async {
    throw ApiException(zonesUnavailable, statusCode: 404);
  }

  @override
  Future<void> deleteRoute(String id) async {
    throw ApiException(zonesUnavailable, statusCode: 404);
  }

  @override
  Future<List<EligibleRouteRider>> eligibleRouteRiders({String? search}) async {
    throw ApiException(zonesUnavailable, statusCode: 404);
  }

  @override
  Future<RouteDetail> assignRouteRider(
    String routeId, {
    required String riderUserId,
  }) async {
    throw ApiException(zonesUnavailable, statusCode: 404);
  }

  @override
  Future<RouteDetail> unassignRouteRider(
    String routeId, {
    required String riderUserId,
  }) async {
    throw ApiException(zonesUnavailable, statusCode: 404);
  }

  @override
  Future<List<RouteCustomerRow>> routeCustomers(String routeId) async {
    throw ApiException(zonesUnavailable, statusCode: 404);
  }

  @override
  Future<List<RouteCustomerRow>> allocateRouteCustomers(
    String routeId, {
    required List<String> customerIds,
  }) async {
    throw ApiException(zonesUnavailable, statusCode: 404);
  }

  @override
  Future<List<RouteCustomerRow>> sequenceRouteCustomers(
    String routeId, {
    required List<String> orderedCustomerIds,
  }) async {
    throw ApiException(zonesUnavailable, statusCode: 404);
  }

  @override
  Future<List<RouteStopRow>> routeStops(String routeId, {String? date}) async {
    throw ApiException(zonesUnavailable, statusCode: 404);
  }

  @override
  Future<List<RouteStopRow>> ensureRouteStops(
    String routeId, {
    String? date,
  }) async {
    throw ApiException(zonesUnavailable, statusCode: 404);
  }

  @override
  Future<List<RouteStopRow>> sequenceRouteStops(
    String routeId, {
    required List<String> orderedStopIds,
  }) async {
    throw ApiException(zonesUnavailable, statusCode: 404);
  }

  @override
  Future<RouteMapData> routeMapPins(String routeId, {String? date}) async {
    throw ApiException(zonesUnavailable, statusCode: 404);
  }

  static const customersUnavailable =
      'Admin customers are not available in this test double.';

  @override
  Future<AdminCustomersSummary> adminCustomersSummary() async {
    throw ApiException(customersUnavailable, statusCode: 404);
  }

  @override
  Future<AdminCustomerPage> adminCustomers({
    String? search,
    String? status,
    String? routeId,
    String? zoneId,
    String? area,
    bool? withOutstanding,
    bool? missingGps,
    int page = 1,
    int pageSize = 20,
  }) async {
    throw ApiException(customersUnavailable, statusCode: 404);
  }

  @override
  Future<AdminCustomerDetail> adminCustomerDetail(String id) async {
    throw ApiException(customersUnavailable, statusCode: 404);
  }

  @override
  Future<AdminCustomerDetail> adminCreateCustomer({
    required String businessName,
    required String primaryMobile,
    String? additionalContact,
    required String category,
    required String street,
    required String area,
    required String city,
    num? latitude,
    num? longitude,
    required String routeId,
    required String bottleOwnership,
    num? openingDebt,
    int? openingEmpties,
    String? cnic,
    String? contactName,
    String? contactRole,
    String? status,
    int? creditDays,
  }) async {
    throw ApiException(customersUnavailable, statusCode: 404);
  }

  @override
  Future<AdminCustomerDetail> adminUpdateCustomer(
    String id, {
    required String businessName,
    required String primaryMobile,
    String? additionalContact,
    required String category,
    required String street,
    required String area,
    required String city,
    num? latitude,
    num? longitude,
    required String routeId,
    required String bottleOwnership,
    num? openingDebt,
    int? openingEmpties,
    String? cnic,
    String? contactName,
    String? contactRole,
    String? status,
    int? creditDays,
  }) async {
    throw ApiException(customersUnavailable, statusCode: 404);
  }

  @override
  Future<AdminCustomerDetail> adminChangeCustomerRoute(
    String id, {
    required String routeId,
  }) async {
    throw ApiException(customersUnavailable, statusCode: 404);
  }

  @override
  Future<AdminCustomerDetail> adminSetCustomerStatus(
    String id, {
    required String status,
  }) async {
    throw ApiException(customersUnavailable, statusCode: 404);
  }

  @override
  Future<LedgerData> adminCustomerLedger(String id) async {
    throw ApiException(customersUnavailable, statusCode: 404);
  }

  static const depotUnavailable =
      'Depot operations are not available in this test double.';
  static const salesUnavailable =
      'Admin sales are not available in this test double.';

  @override
  Future<DepotDetail> depotDetail() async {
    throw ApiException(depotUnavailable, statusCode: 404);
  }

  @override
  Future<DepotOperations> depotSummary({String? date}) async {
    throw ApiException(depotUnavailable, statusCode: 404);
  }

  @override
  Future<List<DepotFleetMember>> depotFleet() async {
    throw ApiException(depotUnavailable, statusCode: 404);
  }

  @override
  Future<List<DepotStockLine>> depotStock() async {
    throw ApiException(depotUnavailable, statusCode: 404);
  }

  @override
  Future<DepotDetail> updateDepot({
    required String name,
    required String gate,
    required String address,
  }) async {
    throw ApiException(depotUnavailable, statusCode: 404);
  }

  @override
  Future<AdminSalesSummary> adminSalesSummary({String? date}) async {
    throw ApiException(salesUnavailable, statusCode: 404);
  }

  @override
  Future<ShiftDayRecord> adminShiftDay({String? date, String? riderId}) async {
    return ShiftDayRecord(
      serviceDate: date ?? '2026-11-20',
      riders: const [],
      selected: null,
      odometer: const [],
    );
  }

  @override
  Future<RecurringBoard> recurringSchedules({
    String? search,
    String? tab,
    String? depotId,
    String? productId,
    String? riderId,
    int page = 1,
    int pageSize = 20,
  }) async => RecurringBoard.empty;

  @override
  Future<RecurringScheduleDetail> recurringSchedule(String id) async => throw ApiException('No schedule is saved.', statusCode: 404);

  @override
  Future<RecurringScheduleDetail> createRecurringSchedule(Map<String, dynamic> body) async => throw ApiException('No schedule is saved.', statusCode: 404);

  @override
  Future<RecurringScheduleDetail> updateRecurringSchedule(String id, Map<String, dynamic> body) async => throw ApiException('No schedule is saved.', statusCode: 404);

  @override
  Future<SchedulePreview> previewRecurringSchedule(Map<String, dynamic> body) async =>
      const SchedulePreview(dates: [], totalDeliveries: 0, totalBottles: 0, monthDayRule: '');

  @override
  Future<RecurringScheduleDetail> pauseRecurringSchedule(String id, {required String reason, String? startDate, String? endDate}) async =>
      throw ApiException('No schedule is saved.', statusCode: 404);

  @override
  Future<RecurringScheduleDetail> resumeRecurringSchedule(String id) async => throw ApiException('No schedule is saved.', statusCode: 404);

  @override
  Future<RecurringScheduleDetail> cancelRecurringSchedule(String id, {required String reason}) async => throw ApiException('No schedule is saved.', statusCode: 404);

  @override
  Future<RecurringScheduleDetail> duplicateRecurringSchedule(String id) async => throw ApiException('No schedule is saved.', statusCode: 404);

  @override
  Future<ScheduleCalendar> recurringCalendar({required int year, required int month, String? scheduleId}) async =>
      ScheduleCalendar(year: year, month: month, days: const []);

  @override
  Future<ScheduleCalendarItem> skipOccurrence(String id) async => throw ApiException('No delivery is saved.', statusCode: 404);

  @override
  Future<ScheduleCalendarItem> rescheduleOccurrence(String id, String date) async => throw ApiException('No delivery is saved.', statusCode: 404);

  @override
  Future<ScheduleCalendarItem> reassignOccurrence(String id, String riderId) async => throw ApiException('No delivery is saved.', statusCode: 404);

  @override
  Future<ScheduleCalendarItem> changeOccurrenceQuantity(String id, int quantity) async => throw ApiException('No delivery is saved.', statusCode: 404);

  @override
  Future<AdminSalePage> adminSales({
    String? date,
    String? type,
    String? syncStatus,
    String? riderId,
    String? search,
    int page = 1,
    int pageSize = 20,
  }) async {
    throw ApiException(salesUnavailable, statusCode: 404);
  }

  @override
  Future<AdminSaleDetail> adminSaleDetail(String id) async {
    throw ApiException(salesUnavailable, statusCode: 404);
  }

  @override
  Future<AdminSaleDraft> adminCreateSaleDraft({
    required String riderUserId,
    required String customerId,
    String? stopId,
    required List<Map<String, dynamic>> lines,
    int? emptyBottlesReturned,
  }) async {
    throw ApiException(salesUnavailable, statusCode: 404);
  }

  @override
  Future<ReceiptData> adminCompleteSale(
    String id, {
    required String paymentMethod,
    num? amountReceived,
    required String signerName,
    String? signerRole,
    bool closeStop = true,
    String? signatureImage,
    String? signatureNote,
  }) async {
    throw ApiException(salesUnavailable, statusCode: 404);
  }

  @override
  Future<ReceiptData> adminSaleReceipt(String id) async {
    throw ApiException(salesUnavailable, statusCode: 404);
  }

  static const collectionsUnavailable =
      'Collections management is not available in this test double.';
  static const reportsUnavailable =
      'Reports and analytics are not available in this test double.';

  @override
  Future<AdminCollectionsSummary> adminCollectionsSummary({String? date}) async {
    throw ApiException(collectionsUnavailable, statusCode: 404);
  }

  @override
  Future<AdminCollectionPage> adminCollections({
    String? date,
    String? type,
    String? riderId,
    String? search,
    int page = 1,
    int pageSize = 20,
  }) async {
    throw ApiException(collectionsUnavailable, statusCode: 404);
  }

  @override
  Future<AdminCollectionDetail> adminCollectionDetail(String id) async {
    throw ApiException(collectionsUnavailable, statusCode: 404);
  }

  @override
  Future<ReceiptData> adminRecordCollection({
    required String riderUserId,
    required String customerId,
    required num amount,
    required String signerName,
    num? withholdingTax,
    String? note,
    String? idempotencyKey,
  }) async {
    throw ApiException(collectionsUnavailable, statusCode: 404);
  }

  @override
  Future<List<AdminReceivableExposure>> adminReceivablesExposure() async {
    throw ApiException(collectionsUnavailable, statusCode: 404);
  }

  @override
  Future<AdminReportsSummary> adminReportsSummary({
    String? from,
    String? to,
  }) async {
    throw ApiException(reportsUnavailable, statusCode: 404);
  }

  @override
  Future<List<AdminReportCatalogItem>> adminReportsCatalog() async {
    throw ApiException(reportsUnavailable, statusCode: 404);
  }

  @override
  Future<AdminReportTable> adminReportRun(
    String key, {
    String? from,
    String? to,
  }) async {
    throw ApiException(reportsUnavailable, statusCode: 404);
  }

  @override
  Future<String> adminReportExportCsv(
    String key, {
    String? from,
    String? to,
  }) async {
    throw ApiException(reportsUnavailable, statusCode: 404);
  }

  static const auditUnavailable =
      'Security audit is not available in this test double.';
  static const communicationUnavailable =
      'Transactional SMS is not available in this test double.';

  @override
  Future<AdminAuditSummary> adminAuditSummary({String? date}) async {
    throw ApiException(auditUnavailable, statusCode: 404);
  }

  @override
  Future<AdminAuditEventPage> adminAuditEvents({
    String? date,
    String? category,
    String? search,
    String? outcome,
    int page = 1,
    int pageSize = 20,
  }) async {
    throw ApiException(auditUnavailable, statusCode: 404);
  }

  @override
  Future<AdminAuditEventDetail> adminAuditEvent(String id) async {
    throw ApiException(auditUnavailable, statusCode: 404);
  }

  @override
  Future<AdminAuditVerifyResult> adminAuditVerify(String id) async {
    throw ApiException(auditUnavailable, statusCode: 404);
  }

  @override
  Future<String> adminAuditExportCsv({
    String? date,
    String? category,
    String? search,
  }) async {
    throw ApiException(auditUnavailable, statusCode: 404);
  }

  @override
  Future<CommunicationDashboardSummary> adminCommunicationSummary({
    String? date,
  }) async {
    throw ApiException(communicationUnavailable, statusCode: 404);
  }

  @override
  Future<CommunicationGatewayStatus> adminCommunicationGateway() async {
    throw ApiException(communicationUnavailable, statusCode: 404);
  }

  @override
  Future<CommunicationGatewayStatus> adminCommunicationTestGateway() async {
    throw ApiException(communicationUnavailable, statusCode: 404);
  }

  @override
  Future<List<CommunicationTemplate>> adminCommunicationTemplates() async {
    throw ApiException(communicationUnavailable, statusCode: 404);
  }

  @override
  Future<CommunicationTemplate> adminCreateCommunicationTemplate({
    required String name,
    required String language,
    required String triggerType,
    required String content,
    String? templateCode,
  }) async {
    throw ApiException(communicationUnavailable, statusCode: 404);
  }

  @override
  Future<CommunicationTemplate> adminUpdateCommunicationTemplate(
    String id, {
    required String name,
    required String language,
    required String triggerType,
    required String content,
  }) async {
    throw ApiException(communicationUnavailable, statusCode: 404);
  }

  @override
  Future<CommunicationTemplate> adminSetCommunicationTemplateActive(
    String id, {
    required bool isActive,
  }) async {
    throw ApiException(communicationUnavailable, statusCode: 404);
  }

  @override
  Future<void> adminArchiveCommunicationTemplate(String id) async {
    throw ApiException(communicationUnavailable, statusCode: 404);
  }

  @override
  Future<CommunicationPreview> adminCommunicationPreview({
    required String templateId,
    Map<String, String>? variables,
  }) async {
    throw ApiException(communicationUnavailable, statusCode: 404);
  }

  @override
  Future<List<CommunicationTrigger>> adminCommunicationTriggers() async {
    throw ApiException(communicationUnavailable, statusCode: 404);
  }

  @override
  Future<CommunicationMessagePage> adminCommunicationMessages({
    String? date,
    String? status,
    String? search,
    int page = 1,
    int pageSize = 20,
  }) async {
    throw ApiException(communicationUnavailable, statusCode: 404);
  }

  @override
  Future<CommunicationMessageDetail> adminCommunicationMessage(String id) async {
    throw ApiException(communicationUnavailable, statusCode: 404);
  }

  @override
  Future<CommunicationMessageDetail> adminEnqueueCommunicationMessage({
    String? customerId,
    required String templateId,
    required String destinationNumber,
    String? transactionReference,
    Map<String, String>? variables,
    String? idempotencyKey,
    String? riderUserId,
  }) async {
    throw ApiException(communicationUnavailable, statusCode: 404);
  }

  @override
  Future<CommunicationMessageDetail> adminRetryCommunicationMessage(
    String id,
  ) async {
    throw ApiException(communicationUnavailable, statusCode: 404);
  }

  @override
  Future<String> adminCommunicationMessagesExportCsv({
    String? date,
    String? status,
  }) async {
    throw ApiException(communicationUnavailable, statusCode: 404);
  }

  static const staffUnavailable =
      'Users and staff are not available in this test double.';

  @override
  Future<StaffSummary> staffSummary() async {
    throw ApiException(staffUnavailable, statusCode: 404);
  }

  @override
  Future<List<RoleReference>> staffRoleReference() async {
    throw ApiException(staffUnavailable, statusCode: 404);
  }

  @override
  Future<RoleAccessMatrix> roleAccess() async {
    throw ApiException(staffUnavailable, statusCode: 404);
  }

  @override
  Future<RoleAccessRow> saveRoleAccess(String role, List<String> screenKeys) async {
    throw ApiException(staffUnavailable, statusCode: 404);
  }

  @override
  Future<RoleAccessRow> createAccessRole({required String name, String? description}) async {
    throw ApiException(staffUnavailable, statusCode: 404);
  }

  @override
  Future<RoleAccessRow> assignRoleMember(String role, String userId) async {
    throw ApiException(staffUnavailable, statusCode: 404);
  }

  @override
  Future<StaffUserPage> staffUsers({
    String? search,
    String? role,
    bool? isActive,
    int page = 1,
    int pageSize = 50,
  }) async {
    throw ApiException(staffUnavailable, statusCode: 404);
  }

  @override
  Future<StaffUser> staffUser(String id) async {
    throw ApiException(staffUnavailable, statusCode: 404);
  }

  @override
  Future<StaffUser> createStaffUser({
    required String username,
    required String password,
    required String fullName,
    String? phone,
    String? riderCode,
    required String role,
    String? routeId,
    String? vehicleId,
    String? depotId,
    String? email,
    String? zoneId,
    String? warehousePersonUserId,
  }) async {
    throw ApiException(staffUnavailable, statusCode: 404);
  }

  @override
  Future<StaffUser> updateStaffUser(
    String id, {
    required String fullName,
    String? phone,
    String? riderCode,
    String? routeId,
    String? vehicleId,
    String? depotId,
  }) async {
    throw ApiException(staffUnavailable, statusCode: 404);
  }

  @override
  Future<StaffUser> setStaffUserStatus(
    String id, {
    required bool isActive,
  }) async {
    throw ApiException(staffUnavailable, statusCode: 404);
  }

  @override
  Future<void> resetStaffUserPassword(
    String id, {
    required String newPassword,
  }) async {
    throw ApiException(staffUnavailable, statusCode: 404);
  }

  static const _ali = CustomerDetail(
    id: 'c-ali',
    code: 'CUS-1001',
    businessName: 'Ali General Store',
    category: 'Retail Store',
    status: 'Active',
    phone: '+92 300 1234567',
    additionalContact: '+92 51 5551234',
    street: 'Shop 14, Commercial Market',
    area: 'Satellite Town',
    city: 'Rawalpindi',
    latitude: 33.6425,
    longitude: 73.0789,
    routeName: 'Satellite Town – Route 03',
    routeId: 'route-1',
    outstanding: 2500,
    lastDropAt: null,
    openOrders: 1,
    bottlesIssued: 10,
    bottlesReturned: 7,
    bottlesHeld: 3,
    bottleOwnership: 'Rented',
    cnic: '37405-1234567-1',
    contactName: 'Tariq Ali',
    contactRole: 'Store Manager',
    creditDays: 7,
    lastPaymentLabel: '14 Mar (PKR 3000)',
    nextOrderProduct: '19L Mineral Water Bottle',
    nextOrderQuantity: 4,
    nextOrderDate: '2026-11-10',
  );

  static final _receipt = ReceiptData(
    id: 'sale-1',
    kind: 'Sale',
    receiptNumber: 'RCP-20261117-0001',
    issuedAt: DateTime(2026, 11, 17, 10, 42),
    riderName: 'Ahmed Khan',
    riderCode: 'RDR-1042',
    customerName: 'Ali General Store',
    customerCode: 'CUS-1001',
    lines: [
      const SaleLineItem(
        productId: 'p19',
        name: '19L Water Bottle',
        quantity: 2,
        unitPrice: 180,
        lineTotal: 360,
      ),
    ],
    saleAmount: 360,
    previousOutstanding: 2500,
    amountReceived: 2860,
    balanceAfter: 0,
    paymentMethod: 'Cash',
    signerName: 'Tariq Ali',
    signerRole: 'Store Manager',
    syncStatus: 'Synced',
    customerAddress: 'Shop 14, Commercial Market, Satellite Town, Rawalpindi',
    customerPhone: '+92 300 1234567',
    depotName: 'Warehouse Depot Hub 02',
    depotAddress: 'Zone C - Bay 04',
    emptyBottlesReturned: 2,
    emptyBottlesHeld: 1,
  );

  @override
  Future<TrackingSessionInfo> startTracking() async =>
      const TrackingSessionInfo(
        id: 'session-1',
        shiftId: 'shift-1',
        status: 'Active',
        startedAtUtc: '2026-11-19T08:00:00Z',
      );

  @override
  Future<TrackingSessionInfo> stopTracking({String? reason}) async =>
      TrackingSessionInfo(
        id: 'session-1',
        shiftId: 'shift-1',
        status: 'Ended',
        startedAtUtc: '2026-11-19T08:00:00Z',
        endedAtUtc: '2026-11-19T16:00:00Z',
        endReason: reason,
      );

  @override
  Future<void> uploadTrackingLocations({
    String? sessionId,
    required List<Map<String, dynamic>> points,
  }) async {}

  @override
  Future<TrackingStatusInfo> trackingStatus() async =>
      const TrackingStatusInfo(
        trackingActive: false,
        locationSharingLabel: 'Inactive',
      );

  @override
  Future<ActiveAssignmentInfo> activeAssignment() async =>
      const ActiveAssignmentInfo(
        riderUserId: 'rider-1',
        riderCode: 'RDR-1042',
        fullName: 'Ahmed Khan',
      );

  @override
  Future<RouteComplianceStateInfo> routeComplianceCurrent() async =>
      const RouteComplianceStateInfo(
        state: 'OnRoute',
        summary: 'No open route anomalies.',
      );

  @override
  Future<List<RouteAnomalyInfo>> riderRouteAnomalies() async => const [];

  @override
  Future<RouteAnomalyInfo> submitAnomalyExplanation({
    required String anomalyId,
    required String reason,
    required String explanationText,
    String? supportingNote,
    bool isCorrection = false,
  }) async => RouteAnomalyInfo(
        id: anomalyId,
        anomalyNumber: 'RCA-TEST',
        riderUserId: 'rider-1',
        status: 'ExplanationSubmitted',
        category: 'RouteDeviation',
      );

  @override
  Future<List<RiderNotificationInfo>> riderNotifications() async => const [];

  @override
  Future<void> markRiderNotificationRead(String id) async {}

  @override
  Future<LiveTrackingOverview> liveTrackingOverview() async =>
      const LiveTrackingOverview();

  @override
  Future<List<LiveRiderCard>> liveTrackingRiders() async => const [];

  @override
  Future<LiveRiderDetail> liveTrackingRider(String riderUserId) async =>
      LiveRiderDetail(
        card: LiveRiderCard(
          riderUserId: riderUserId,
          fullName: 'Ahmed Khan',
          riderCode: 'RDR-1042',
        ),
      );

  @override
  Future<List<RouteAnomalyInfo>> adminRouteAnomalies({
    String? status,
    String? riderUserId,
  }) async => const [];

  @override
  Future<RouteAnomalyInfo> adminRouteAnomaly(String id) async => RouteAnomalyInfo(
        id: id,
        anomalyNumber: 'RCA-TEST',
        riderUserId: 'rider-1',
      );

  @override
  Future<RouteAnomalyInfo> reviewRouteAnomaly({
    required String id,
    required String action,
    String? notes,
  }) async => adminRouteAnomaly(id);

  @override
  Future<RouteAnomalyInfo> queryRouteAnomaly({
    required String id,
    required String message,
  }) async => adminRouteAnomaly(id);

  @override
  Future<RouteAnomalyInfo> resolveRouteAnomaly({
    required String id,
    String? notes,
    bool markFalsePositive = false,
  }) async => adminRouteAnomaly(id);

  CustomerHome? customerHomeOverride;
  List<CustomerPlan> customerPlans = const [];
  Map<String, dynamic>? lastCustomerRequestBody;
  Map<String, dynamic>? lastCustomerProfile;
  String? lastCustomerReviewAction;
  CustomerAccountBoard? customerAccountBoardOverride;
  List<CustomerRequest> customerRequestQueueOverride = const [];

  CustomerHome _customerHome() => customerHomeOverride ??
      const CustomerHome(
        firstName: 'Ayesha',
        fullName: 'Ayesha Khan',
        customerCode: 'CUS-000001',
        accountStatus: 'Active',
        linked: false,
        linkMessage: 'The office has not placed this account on a delivery route yet.',
        overview: CustomerCounts(scheduled: 0, completed: 0, upcoming: 0, skippedOrCancelled: 0),
        payments: CustomerMoney(
          totalBilled: 0,
          totalPaid: 0,
          outstanding: 0,
          overdue: 0,
          note: 'Online payment is not enabled. Cash collected by a rider or the office is shown after it is recorded. This screen cannot mark a payment as verified.',
        ),
        upcoming: [],
        unreadNotifications: 0,
      );

  CustomerProfile _customerProfile() => const CustomerProfile(
        customerCode: 'CUS-000001',
        firstName: 'Ayesha',
        lastName: 'Khan',
        email: 'ayesha@example.com',
        phone: '+923001234567',
        accountStatus: 'Active',
        createdAt: '2026-11-20',
        linked: false,
        addresses: [
          CustomerAddress(
            id: 'addr-1',
            label: 'Home',
            city: 'Rawalpindi',
            area: 'Chaklala',
            street: 'Lane 7',
            houseNumber: '18',
            isDefault: true,
            isActive: true,
          ),
        ],
      );

  @override
  Future<CustomerHome> customerHome() async => _customerHome();

  @override
  Future<List<CustomerPlan>> customerSchedules() async => customerPlans;

  @override
  Future<CustomerCalendar> customerCalendar(String scheduleId, int year, int month) async => CustomerCalendar(
        year: year,
        month: month,
        days: [
          for (var day = 1; day <= 28; day++)
            CustomerCalendarDay(
              date: '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}',
              status: '',
              count: 0,
              items: const [],
            ),
        ],
      );

  @override
  Future<List<CustomerVisit>> customerHistory({String? scheduleId, String? status, String? from, String? to}) async => const [];

  @override
  Future<CustomerPayments> customerPayments() async => CustomerPayments(summary: _customerHome().payments, payments: const [], invoices: const []);

  @override
  Future<CustomerInvoiceDetail> customerInvoice(String number) async => CustomerInvoiceDetail(
        number: number,
        date: '',
        amount: 0,
        paid: 0,
        remaining: 0,
        status: 'Unpaid',
        lines: const [],
        payments: const [],
        pdfNote: 'A PDF copy is not generated for this invoice.',
      );

  @override
  Future<CustomerProfile> updateCustomerProfile({required String firstName, required String lastName, required String phone}) async {
    lastCustomerProfile = {'firstName': firstName, 'lastName': lastName, 'phone': phone};
    return _customerProfile();
  }

  @override
  Future<List<CustomerRequest>> customerRequests() async => customerRequestQueueOverride;

  @override
  Future<CustomerRequest> submitCustomerRequest(Map<String, dynamic> body) async {
    lastCustomerRequestBody = body;
    return CustomerRequest(
      id: 'req-1',
      code: 'CSR-000001',
      type: body['type']?.toString() ?? '',
      status: 'Pending',
      currentSummary: 'Current approved schedule',
      requestedSummary: 'Waiting for office review. The schedule is unchanged.',
      reason: body['reason']?.toString() ?? '',
      affectedDates: '',
      createdAt: '2026-11-20 13:40',
      customerCode: 'CUS-000001',
      customerName: 'Ayesha Khan',
    );
  }

  @override
  Future<CustomerRequestPreview> previewCustomerRequest(Map<String, dynamic> body) async => const CustomerRequestPreview(
        summary: 'Waiting for office review. The schedule is unchanged.',
        affectedDates: '',
        scheduledCount: 0,
        publishedCount: 0,
        completedCount: 0,
        dispatchedNote: 'Dispatched visits stay assigned.',
        inventoryNote: 'Inventory availability is not calculated on this request.',
        pricingNote: 'Issued invoices stay as recorded.',
      );

  @override
  Future<CustomerRequest> cancelCustomerRequest(String id) async => CustomerRequest(
        id: id,
        code: 'CSR-000001',
        type: 'Pause',
        status: 'Cancelled',
        currentSummary: '',
        requestedSummary: '',
        reason: '',
        affectedDates: '',
        createdAt: '',
        customerCode: 'CUS-000001',
        customerName: 'Ayesha Khan',
      );

  @override
  Future<CustomerRequest> replyCustomerRequest(String id, String notes) async => CustomerRequest(
        id: id,
        code: 'CSR-000001',
        type: 'Pause',
        status: 'Pending',
        currentSummary: '',
        requestedSummary: '',
        reason: '',
        notes: notes,
        affectedDates: '',
        createdAt: '',
        customerCode: 'CUS-000001',
        customerName: 'Ayesha Khan',
      );

  @override
  Future<CustomerProfile> customerProfile() async => _customerProfile();

  @override
  Future<CustomerAddress> saveCustomerAddress(Map<String, dynamic> body, {String? id}) async => const CustomerAddress(
        id: 'addr-2',
        label: 'Office',
        city: 'Rawalpindi',
        area: 'Chaklala',
        street: 'Lane 8',
        houseNumber: '2',
        isDefault: false,
        isActive: true,
      );

  @override
  Future<CustomerAddress> defaultCustomerAddress(String id) async => const CustomerAddress(
        id: 'addr-1',
        label: 'Home',
        city: 'Rawalpindi',
        area: 'Chaklala',
        street: 'Lane 7',
        houseNumber: '18',
        isDefault: true,
        isActive: true,
      );

  @override
  Future<CustomerAddress> deactivateCustomerAddress(String id) async => const CustomerAddress(
        id: 'addr-2',
        label: 'Office',
        city: 'Rawalpindi',
        area: 'Chaklala',
        street: 'Lane 8',
        houseNumber: '2',
        isDefault: false,
        isActive: false,
      );

  @override
  Future<List<CustomerNote>> customerNotifications() async => const [];

  @override
  Future<void> readCustomerNotification(String id) async {}

  @override
  Future<void> readAllCustomerNotifications() async {}

  @override
  Future<CustomerAccountBoard> customerAccountBoard({String? search, String? status}) async =>
      customerAccountBoardOverride ??
      const CustomerAccountBoard(total: 0, active: 0, inactive: 0, withSchedules: 0, withBalance: 0, pendingRequests: 0, rows: []);

  @override
  Future<CustomerOpsOverview> customerOpsOverview() async => const CustomerOpsOverview(
        totalCustomers: 0,
        activeCustomers: 0,
        withSchedules: 0,
        upcomingDeliveries: 0,
        completedDeliveries: 0,
        withBalance: 0,
        pendingRequests: 0,
        registrations: [],
        deliveries: [],
        upcoming: [],
      );

  @override
  Future<CustomerAccountDetail> customerAccountDetail(String id) async {
    final board = await customerAccountBoard();
    final account = board.rows.where((item) => item.id == id).firstOrNull ??
        const CustomerAccountRow(
          id: 'missing',
          code: '',
          name: '',
          phone: '',
          email: '',
          city: '',
          area: '',
          status: 'Active',
          createdAt: '',
          linked: false,
          activeSchedules: 0,
          outstanding: 0,
          pendingRequests: 0,
        );
    return CustomerAccountDetail(
      account: account,
      profile: _customerProfile(),
      schedules: customerPlans,
      history: const [],
      payments: await customerPayments(),
      requests: customerRequestQueueOverride,
      timeline: const [],
    );
  }

  @override
  Future<CustomerAccountDetail> linkCustomerAccount(String id, {String? deliveryCustomerId}) async => customerAccountDetail(id);

  @override
  Future<List<CustomerAccountRow>> unlinkedCustomerAccounts() async =>
      (await customerAccountBoard()).rows.where((row) => !row.linked).toList();

  @override
  Future<List<CustomerLinkReview>> customerLinkReviews({String? status}) async => const [];

  @override
  Future<CustomerLinkReview> proposeCustomerLink(String accountId, {required String email, required String customerCode}) async =>
      const CustomerLinkReview(
        id: 'review-1',
        customerAccountId: 'account',
        accountCode: 'CUS-000001',
        accountName: 'Ayesha Khan',
        accountEmail: 'ayesha@example.com',
        deliveryCustomerId: 'customer',
        customerCode: 'CUS-1001',
        customerName: 'Ali',
        status: 'Pending',
        createdAt: '2026-11-21',
      );

  @override
  Future<CustomerLinkReview> reviewCustomerLink(String reviewId, {required String action, String? comment}) async =>
      proposeCustomerLink(reviewId, email: '', customerCode: '');

  @override
  Future<PolicyDocument> policyDocument(String kind) async => PolicyDocument(title: kind == 'terms' ? 'Terms & Conditions' : 'Privacy Policy', body: 'Published policy text.');

  @override
  Future<HqSettings> hqSettings() async => const HqSettings(
        legalName: 'AquaRider',
        displayName: 'AquaRider',
        supportEmail: '',
        supportPhone: '',
        supportAddress: '',
        website: '',
        receiptFooter: '',
      );

  @override
  Future<HqSettings> updateHqSettings(Map<String, dynamic> body) async => hqSettings();

  @override
  Future<List<CashHandover>> cashHandovers({String? status}) async => const [];

  @override
  Future<CashHandover> submitCashHandover({required String businessDate, String? depotId}) async => const CashHandover(
        id: 'handover-1',
        referenceNumber: 'HO-1',
        riderId: 'rider',
        depotId: 'depot',
        businessDate: '2026-11-21',
        expectedAmount: 0,
        status: 'Submitted',
        collectionCount: 0,
        submittedAt: '2026-11-21',
      );

  @override
  Future<CashHandover> confirmCashHandover(String id, {required num actualAmount, String? note}) async => submitCashHandover(businessDate: '2026-11-21');

  @override
  Future<OfficeDocument> invoicePdf(String number) async => OfficeDocument(fileName: '$number.pdf', contentType: 'application/pdf', contentBase64: '');

  @override
  Future<OfficeDocument> orderPdf(String id) async => OfficeDocument(fileName: '$id.pdf', contentType: 'application/pdf', contentBase64: '');

  @override
  Future<OfficeDocument> orderCsv(String id) async => OfficeDocument(fileName: '$id.csv', contentType: 'text/csv', contentBase64: '');

  @override
  Future<OfficeDocument> manifestPdf({required String routeId, required String date}) async =>
      OfficeDocument(fileName: 'manifest.pdf', contentType: 'application/pdf', contentBase64: '');

  @override
  Future<void> updatePriceList(String id, Map<String, dynamic> body) async {}

  @override
  Future<void> duplicatePriceList(String id, {required String code, required String name}) async {}

  @override
  Future<void> assignPriceList(String id, List<String> customerIds) async {}

  @override
  Future<void> createWarehouse({required String name, required String gate, required String address}) async {}

  @override
  Future<void> recordInventoryCount({required String depotId, required String productId, required int countedQuantity, String? note}) async {}

  @override
  Future<CustomerAccountDetail> setCustomerAccountStatus(String id, String status) async => customerAccountDetail(id);

  @override
  Future<List<CustomerRequest>> customerRequestQueue({String? type, String? status, String? search, String? city}) async => customerRequestQueueOverride;

  @override
  Future<CustomerRequest> reviewCustomerRequest(String id, {required String action, String? comment}) async {
    lastCustomerReviewAction = action;
    final current = customerRequestQueueOverride.where((item) => item.id == id).firstOrNull;
    final updated = CustomerRequest(
      id: id,
      code: current?.code ?? 'CSR-000001',
      type: current?.type ?? '',
      status: action == 'approve' ? 'Applied' : action == 'reject' ? 'Rejected' : 'MoreInformationRequired',
      currentSummary: current?.currentSummary ?? '',
      requestedSummary: current?.requestedSummary ?? '',
      reason: current?.reason ?? '',
      affectedDates: current?.affectedDates ?? '',
      createdAt: current?.createdAt ?? '',
      customerCode: current?.customerCode ?? '',
      customerName: current?.customerName ?? '',
      adminComment: comment,
    );
    customerRequestQueueOverride = [
      for (final item in customerRequestQueueOverride)
        if (item.id == id) updated else item,
    ];
    return updated;
  }

  @override
  Future<CustomerRequestPreview> customerRequestImpact(String id) async => const CustomerRequestPreview(
        summary: 'Eligible future deliveries only.',
        affectedDates: '',
        scheduledCount: 0,
        publishedCount: 0,
        completedCount: 0,
        dispatchedNote: 'Dispatched visits stay assigned.',
        inventoryNote: 'Inventory availability is not calculated on this request.',
        pricingNote: 'Issued invoices stay as recorded.',
      );
}
