import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riderfrontend/adminDashboard/data/admin_json.dart';
import 'package:riderfrontend/adminDashboard/presentation/admin_nav.dart';
import 'package:riderfrontend/adminDashboard/presentation/admin_workspace.dart';
import 'package:riderfrontend/adminDashboard/presentation/widgets/admin_sidebar.dart';
import 'package:riderfrontend/adminDashboard/presentation/widgets/dispatch/dispatch_manifest.dart';
import 'package:riderfrontend/api/route_api.dart';

import 'memory_route_api.dart';

const admin = AuthSession(
    accessToken: 'a',
    refreshToken: 'r',
    fullName: 'Usama Admin',
    username: 'usama.admin',
    riderCode: '',
    routeName: '',
    vehicleName: '',
    vehiclePlate: '',
    fleetCode: '',
    depotGate: '',
    depotName: '',
    role: 'Admin',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const order = DispatchOrderRow(
    id: 'ord-1',
    reference: 'ORD-OPEN-ALI',
    customerName: 'Ali General Store',
    customerCode: 'CUS-1001',
    address: 'Commercial Market, Satellite Town',
    scheduledDate: '2026-11-18',
    timeWindow: 'Morning',
    riderName: 'Ahmed Khan',
    riderId: 'rider-1',
    riderCode: 'RDR-1042',
    estimatedValue: 970,
    status: 'Scheduled',
  );

  test('dispatch figures stay empty until the payload includes them', () {
    expect(DispatchOrderSummary.fromJson(const {}).kpis, isEmpty);
    expect(DispatchStatusCounts.fromJson(const {}).all, isNull);
    expect(DispatchStatusCounts.fromJson(const {}).pendingAssignment, isNull);
    final one = DispatchOrderSummary.fromJson(const {'totalOrders': 1});
    expect(one.kpis.single.label, 'Total');
    expect(one.kpis.single.value, '1');
    expect(one.kpis.single.value.contains('248'), isFalse);

    final dropped = DispatchOrderSummary.fromJson(const {
      'kpis': [
        {'label': 'LIVE RADAR', 'value': 248},
        {'label': 'Live Tracking', 'value': 18},
      ],
      'totalOrders': 1,
      'assigned': 1,
    });
    expect(dropped.kpis.map((kpi) => kpi.label).toList(), [
      'Total',
      'Assigned',
    ]);
    expect(dropped.kpis.any((kpi) => kpi.value == '248'), isFalse);

    final page = DispatchOrderPage.fromParts(
      const {
        'orders': [
          {
            'id': 'ord-1',
            'referenceNumber': 'ORD-OPEN-ALI',
            'customerName': 'Ali General Store',
            'estimatedValue': 970,
          },
        ],
        'totalCount': 1,
      },
      null,
      page: 1,
      pageSize: 10,
    );
    expect(page.rows, hasLength(1));
    expect(page.totalRecords, 1);
    expect(page.rows.single.estimatedValue, 970);

    final shift = DispatchOperationalSummary.fromJson(const {
      'shift': {'completedDeliveries': 4, 'percent': 62},
    });
    expect(shift.shift.hasTarget, isFalse);
    expect(shift.shift.percent, isNull);
    expect(shift.shift.completed, 4);
    final configured = DispatchOperationalSummary.fromJson(const {
      'shift': {'completedDeliveries': 5, 'targetDeliveries': 10},
    });
    expect(configured.shift.percent, 0.5);
    expect(combinedEstimatedValue(const [970, null]), 970);
    expect(combinedEstimatedValue(const [null]), isNull);
    expect(lockedDispatchKpiLabels.join(' '), isNot(contains('248')));
  });

  test('rider and dispatch labels drop telemetry claims', () {
    expect(isDisallowedOperationsLabel('Live Tracking'), isTrue);
    expect(isDisallowedOperationsLabel('History Playback'), isTrue);
    expect(isDisallowedOperationsLabel('Battery 78%'), isTrue);
    expect(isDisallowedOperationsLabel('GPS fix'), isTrue);
    expect(isDisallowedOperationsLabel('28 km/h'), isTrue);
    expect(isDisallowedOperationsLabel('Price Lists'), isTrue);
    expect(operationsDisplayText('Idle'), 'Idle');
    expect(operationsDisplayText('Moving 28 km/h'), isNull);
    expect(operationsDisplayText('LIVE RADAR'), isNull);
  });

  testWidgets('sidebar labels omit live trackboard and price lists', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminSidebar(
            serverReachable: true,
            activeKey: AdminNav.dashboard,
            onNavigate: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Dispatch & Orders'), findsOneWidget);
    expect(find.text('Fleet Couriers'), findsOneWidget);
    expect(find.text('Admin Dashboard'), findsOneWidget);
    expect(find.text('Live Trackboard'), findsNothing);
    expect(find.text('LIVE RADAR'), findsNothing);
    expect(find.text('Live Tracking'), findsNothing);
    expect(find.text('Price Lists'), findsNothing);
    expect(find.text('Spot Billing Ledger'), findsNothing);
    expect(find.byKey(const Key('admin-nav-dispatchOrders')), findsOneWidget);
  });

  testWidgets('sidebar scrolls when the window is shorter than the menu', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(248, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final overflows = <String>[];
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      final message = details.exceptionAsString();
      if (message.contains('overflowed')) overflows.add(message);
      previous?.call(details);
    };
    addTearDown(() => FlutterError.onError = previous);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminSidebar(
            serverReachable: true,
            activeKey: AdminNav.dashboard,
            onNavigate: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(overflows, isEmpty);
    expect(find.text('Server reachable'), findsOneWidget);
    final settings = find.text('HQ Settings');
    expect(settings, findsOneWidget);
    await tester.ensureVisible(settings);
    await tester.pumpAndSettle();
    expect(overflows, isEmpty);
  });

  testWidgets('dispatch screen shows an error without invented totals', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ApiScope(
        api: MemoryRouteApi(),
        child: const MaterialApp(home: AdminWorkspace(session: admin)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('admin-nav-dispatchOrders')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('dispatch-orders-screen')), findsOneWidget);
    expect(find.text('Dispatch & Order Management'), findsOneWidget);
    expect(
      find.text('Field Operations  ›  Dispatch & Orders'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Dispatch orders are not available'),
      findsOneWidget,
    );
    expect(find.textContaining('248'), findsNothing);
    expect(find.text('64'), findsNothing);
    expect(find.textContaining('PKR 8,660'), findsNothing);
    expect(find.text('Live Trackboard'), findsNothing);
    expect(find.text('Price Lists'), findsNothing);
  });

  testWidgets('an empty dispatch payload does not invent order totals', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ApiScope(
        api: MemoryRouteApi(
          dispatchSummary: DispatchOrderSummary.fromJson(const {}),
          dispatchCounts: DispatchStatusCounts.fromJson(const {}),
          dispatchPage: const DispatchOrderPage(
            rows: [],
            page: 1,
            pageSize: 10,
            totalRecords: 0,
            totalPages: 0,
          ),
          dispatchOperational: DispatchOperationalSummary.fromJson(const {}),
        ),
        child: const MaterialApp(
          home: AdminWorkspace(session: admin, initialKey: AdminNav.dispatch),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No order totals were returned.'), findsOneWidget);
    expect(find.text('No orders were returned.'), findsOneWidget);
    expect(find.text('No operational zones were returned.'), findsOneWidget);
    expect(find.text('Not configured'), findsOneWidget);
    expect(find.text('Showing 0 of 0'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    expect(find.textContaining('248'), findsNothing);
    expect(find.textContaining('62%'), findsNothing);
  });

  testWidgets('order drawer opens and closes from one returned order', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ApiScope(
        api: MemoryRouteApi(
          dispatchSummary: DispatchOrderSummary.fromJson(const {
            'totalOrders': 1,
            'pendingDispatch': 0,
            'assigned': 1,
            'inProgress': 0,
          }),
          dispatchCounts: DispatchStatusCounts.fromJson(const {
            'all': 1,
            'pendingAssignment': 0,
            'assigned': 1,
            'inProgress': 0,
            'completed': 0,
            'cancelled': 0,
          }),
          dispatchPage: const DispatchOrderPage(
            rows: [order],
            page: 1,
            pageSize: 10,
            totalRecords: 1,
            totalPages: 1,
          ),
          dispatchDetail: const DispatchOrderDetail(
            order: order,
            notes: 'Deliver before noon.',
          ),
          dispatchItems: const [],
          dispatchLifecycle: const [],
          dispatchPickList: const DispatchPickList(),
          dispatchOperational: DispatchOperationalSummary.fromJson(const {
            'zones': [
              {'name': 'Satellite Town', 'activeStops': 2, 'orderCount': 1},
            ],
            'shift': {'completedDeliveries': 1},
          }),
          dispatchPrepareError: 'No order lines are available for a pick-list.',
        ),
        child: const MaterialApp(
          home: AdminWorkspace(session: admin, initialKey: AdminNav.dispatch),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ORD-OPEN-ALI'), findsOneWidget);
    expect(find.text('1'), findsWidgets);
    expect(find.textContaining('248'), findsNothing);
    expect(find.textContaining('62%'), findsNothing);
    expect(find.text('Not configured'), findsOneWidget);
    expect(find.text('19L Water Bottle'), findsNothing);

    await tester.ensureVisible(find.byKey(const Key('dispatch-select-ord-1')));
    await tester.tap(find.byKey(const Key('dispatch-select-ord-1')));
    await tester.pumpAndSettle();
    expect(find.text('1 order selected'), findsOneWidget);
    expect(find.textContaining('Combined estimated value PKR 970'), findsOneWidget);
    expect(find.byKey(const Key('dispatch-order-drawer')), findsNothing);

    await tester.ensureVisible(find.byKey(const Key('dispatch-order-ord-1')));
    await tester.tap(find.byKey(const Key('dispatch-order-ord-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('dispatch-order-drawer')), findsOneWidget);
    expect(find.text('Deliver before noon.'), findsOneWidget);
    expect(find.text('No order lines were returned.'), findsOneWidget);
    expect(find.text('No pick-list lines were returned.'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const Key('dispatch-prepare-picklist')),
    );
    await tester.tap(find.byKey(const Key('dispatch-prepare-picklist')));
    await tester.pumpAndSettle();
    expect(
      find.text('No order lines are available for a pick-list.'),
      findsOneWidget,
    );
    expect(find.text('19L Water Bottle'), findsNothing);
    expect(find.textContaining('248'), findsNothing);

    await tester.tap(find.byKey(const Key('dispatch-drawer-close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('dispatch-order-drawer')), findsNothing);
    expect(find.text('ORD-OPEN-ALI'), findsOneWidget);
    expect(find.text('Deliver before noon.'), findsNothing);
  });

  testWidgets('drawer drops prior notes while switching orders', (tester) async {
    tester.view.physicalSize = const Size(1440, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const second = DispatchOrderRow(
      id: 'ord-2',
      reference: 'ORD-MADINA',
      customerName: 'Madina Dairy & Mart',
      customerCode: 'CUS-1002',
      address: 'Main Road',
      scheduledDate: '2026-11-18',
      timeWindow: 'Afternoon',
      riderName: 'Infotech',
      riderId: 'rider-2',
      riderCode: 'RDR-1498',
      estimatedValue: 420,
      status: 'Scheduled',
    );

    final api = MemoryRouteApi(
      dispatchLatency: const Duration(milliseconds: 200),
      dispatchSummary: DispatchOrderSummary.fromJson(const {
        'totalOrders': 2,
        'assigned': 2,
      }),
      dispatchCounts: DispatchStatusCounts.fromJson(const {
        'all': 2,
        'pendingAssignment': 0,
        'assigned': 2,
        'inProgress': 0,
        'completed': 0,
        'cancelled': 0,
      }),
      dispatchPage: const DispatchOrderPage(
        rows: [order, second],
        page: 1,
        pageSize: 10,
        totalRecords: 2,
        totalPages: 1,
      ),
      dispatchDetailsById: {
        'ord-1': const DispatchOrderDetail(
          order: order,
          notes: 'Ali note must not linger.',
          phone: '0300-111',
        ),
        'ord-2': const DispatchOrderDetail(
          order: second,
          notes: 'Madina note after switch.',
          phone: '0300-222',
        ),
      },
      dispatchItems: const [],
      dispatchLifecycle: const [],
      dispatchPickList: const DispatchPickList(),
      dispatchOperational: DispatchOperationalSummary.fromJson(const {}),
      dispatchRiders: const [
        EligibleRider(
          id: 'rider-2',
          fullName: 'Infotech',
          riderCode: 'RDR-1498',
        ),
      ],
    );

    await tester.pumpWidget(
      ApiScope(
        api: api,
        child: const MaterialApp(
          home: AdminWorkspace(session: admin, initialKey: AdminNav.dispatch),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('dispatch-order-ord-1')));
    await tester.tap(find.byKey(const Key('dispatch-order-ord-1')));
    await tester.pumpAndSettle();
    expect(find.text('Ali note must not linger.'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('dispatch-order-ord-2')));
    await tester.tap(find.byKey(const Key('dispatch-order-ord-2')));
    await tester.pump();
    expect(find.text('Ali note must not linger.'), findsNothing);
    expect(find.text('Madina note after switch.'), findsNothing);

    await tester.pumpAndSettle();
    expect(find.text('Madina note after switch.'), findsOneWidget);
    expect(find.text('Ali note must not linger.'), findsNothing);
    expect(find.textContaining('Madina Dairy & Mart'), findsWidgets);
  });

  testWidgets('reassign updates drawer rider after confirm', (tester) async {
    tester.view.physicalSize = const Size(1440, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final api = MemoryRouteApi(
      dispatchSummary: DispatchOrderSummary.fromJson(const {
        'totalOrders': 1,
        'assigned': 1,
      }),
      dispatchCounts: DispatchStatusCounts.fromJson(const {
        'all': 1,
        'assigned': 1,
      }),
      dispatchPage: const DispatchOrderPage(
        rows: [order],
        page: 1,
        pageSize: 10,
        totalRecords: 1,
        totalPages: 1,
      ),
      dispatchDetail: const DispatchOrderDetail(order: order),
      dispatchItems: const [],
      dispatchLifecycle: const [],
      dispatchPickList: const DispatchPickList(),
      dispatchOperational: DispatchOperationalSummary.fromJson(const {}),
      dispatchRiders: const [
        EligibleRider(
          id: 'rider-2',
          fullName: 'Infotech',
          riderCode: 'RDR-1498',
          routeName: 'Satellite Town – Route 03',
        ),
      ],
    );

    await tester.pumpWidget(
      ApiScope(
        api: api,
        child: const MaterialApp(
          home: AdminWorkspace(session: admin, initialKey: AdminNav.dispatch),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('dispatch-order-ord-1')));
    await tester.tap(find.byKey(const Key('dispatch-order-ord-1')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Ahmed Khan'), findsWidgets);

    await tester.tap(find.byKey(const Key('dispatch-reassign')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('dispatch-rider-rider-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('dispatch-reassign-confirm')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Rider reassigned'), findsWidgets);
    expect(find.textContaining('Infotech'), findsWidgets);
    expect(api.dispatchDetail?.order.riderId, 'rider-2');
    expect(
      api.dispatchLifecycle?.last.detail.contains('Previous rider'),
      isTrue,
    );
    expect(
      api.dispatchLifecycle?.last.detail.contains('new rider'),
      isTrue,
    );
  });

  test('selected manifest pdf uses the returned order lines', () async {
    final bytes = await buildDispatchManifestPdf(
      const [
        DispatchManifestSheet(
          order: order,
          lines: [
            DispatchOrderItem(
              name: '19L Water Bottle',
              sku: '19L',
              quantity: 5,
              lineTotal: 900,
            ),
          ],
        ),
      ],
      dateLabel: '20 Nov 2026',
    );
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(bytes.length, greaterThan(400));
    expect(dispatchManifestFilename('20 Nov 2026'), 'dispatch-manifest-20-nov-2026.pdf');
  });

  testWidgets('unassigned selection assigns a chosen rider', (tester) async {
    tester.view.physicalSize = const Size(1440, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const open = DispatchOrderRow(
      id: 'ord-open',
      reference: 'ORD-OPEN',
      customerName: 'Zahid A',
      customerCode: 'CUS-1',
      address: 'Chaklala',
      scheduledDate: '2026-11-20',
      timeWindow: 'Morning',
      estimatedValue: 900,
      status: 'Scheduled',
    );
    final api = _dispatchApi(
      rows: const [open],
      riders: const [
        EligibleRider(id: 'rider-1', fullName: 'Ahmed Khan', riderCode: 'RDR-1042'),
        EligibleRider(id: 'rider-2', fullName: 'Infotech Lab', riderCode: 'RDR-1043'),
      ],
    );

    await _pumpDispatch(tester, api);
    await tester.ensureVisible(find.byKey(const Key('dispatch-select-ord-open')));
    await tester.tap(find.byKey(const Key('dispatch-select-ord-open')));
    await tester.pumpAndSettle();
    expect(find.text('Assign Rider'), findsOneWidget);

    await tester.tap(find.byKey(const Key('dispatch-assign-rider')));
    await tester.pumpAndSettle();
    expect(find.text('Assign rider'), findsWidgets);
    expect(find.text('ORD-OPEN · Zahid A · Unassigned'), findsOneWidget);
    expect(find.byKey(const Key('dispatch-bulk-rider-rider-2')), findsOneWidget);

    await tester.tap(find.byKey(const Key('dispatch-bulk-rider-rider-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('dispatch-assignment-confirm')));
    await tester.pumpAndSettle();

    expect(find.text('Rider assigned.'), findsOneWidget);
    expect(api.dispatchPage?.rows.single.riderId, 'rider-2');
    expect(find.text('Infotech Lab'), findsWidgets);
  });

  testWidgets('assigned selection reassigns to a different rider', (tester) async {
    tester.view.physicalSize = const Size(1440, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final api = _dispatchApi(
      rows: const [order],
      riders: const [
        EligibleRider(id: 'rider-1', fullName: 'Ahmed Khan', riderCode: 'RDR-1042'),
        EligibleRider(id: 'rider-2', fullName: 'Infotech Lab', riderCode: 'RDR-1043'),
      ],
    );

    await _pumpDispatch(tester, api);
    await tester.ensureVisible(find.byKey(const Key('dispatch-select-ord-1')));
    await tester.tap(find.byKey(const Key('dispatch-select-ord-1')));
    await tester.pumpAndSettle();
    expect(find.text('Reassign Rider'), findsOneWidget);

    await tester.tap(find.byKey(const Key('dispatch-assign-rider')));
    await tester.pumpAndSettle();
    expect(find.text('Reassign rider'), findsWidgets);
    expect(find.byKey(const Key('dispatch-bulk-rider-rider-1')), findsNothing);
    expect(find.byKey(const Key('dispatch-bulk-rider-rider-2')), findsOneWidget);

    await tester.tap(find.byKey(const Key('dispatch-bulk-rider-rider-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('dispatch-assignment-confirm')));
    await tester.pumpAndSettle();

    expect(find.text('Rider reassigned.'), findsOneWidget);
    expect(api.dispatchPage?.rows.single.riderId, 'rider-2');
  });

  testWidgets('print opens the manifest and export saves a pdf', (tester) async {
    tester.view.physicalSize = const Size(1440, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final saved = _SavedManifest();
    final previous = DispatchManifestPublisher.current;
    DispatchManifestPublisher.current = saved;
    addTearDown(() => DispatchManifestPublisher.current = previous);

    final api = _dispatchApi(
      rows: const [order],
      items: const [
        DispatchOrderItem(
          name: '19L Water Bottle',
          sku: '19L',
          quantity: 5,
          lineTotal: 900,
        ),
      ],
    );

    await _pumpDispatch(tester, api);
    await tester.ensureVisible(find.byKey(const Key('dispatch-select-ord-1')));
    await tester.tap(find.byKey(const Key('dispatch-select-ord-1')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('dispatch-print-manifest')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('dispatch-manifest-preview')), findsOneWidget);
    expect(find.text('ORD-OPEN-ALI'), findsWidgets);
    expect(find.textContaining('19L Water Bottle'), findsOneWidget);

    await tester.tap(find.byKey(const Key('dispatch-manifest-print')));
    await tester.pumpAndSettle();
    expect(saved.prints, 1);
    expect(String.fromCharCodes(saved.bytes!.take(5)), '%PDF-');

    await tester.tap(find.byKey(const Key('dispatch-manifest-download')));
    await tester.pumpAndSettle();
    expect(saved.downloads, 1);

    await tester.tap(find.byKey(const Key('dispatch-manifest-close')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('dispatch-export-selected')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(saved.downloads, 2);
    expect(find.text('Manifest downloaded.'), findsOneWidget);
    expect(find.byKey(const Key('dispatch-manifest-preview')), findsNothing);
  });
}

MemoryRouteApi _dispatchApi({
  required List<DispatchOrderRow> rows,
  List<EligibleRider> riders = const [],
  List<DispatchOrderItem> items = const [],
}) {
  return MemoryRouteApi(
    dispatchSummary: DispatchOrderSummary.fromJson({
      'totalOrders': rows.length,
      'assigned': rows.where((row) => row.hasRider).length,
    }),
    dispatchCounts: DispatchStatusCounts.fromJson({
      'all': rows.length,
      'pendingAssignment': rows.where((row) => !row.hasRider).length,
      'assigned': rows.where((row) => row.hasRider).length,
      'inProgress': 0,
      'completed': 0,
      'cancelled': 0,
    }),
    dispatchPage: DispatchOrderPage(
      rows: rows,
      page: 1,
      pageSize: 10,
      totalRecords: rows.length,
      totalPages: 1,
    ),
    dispatchItems: items,
    dispatchLifecycle: const [],
    dispatchPickList: const DispatchPickList(),
    dispatchOperational: DispatchOperationalSummary.fromJson(const {}),
    dispatchRiders: riders,
  );
}

Future<void> _pumpDispatch(WidgetTester tester, MemoryRouteApi api) async {
  await tester.pumpWidget(
    ApiScope(
      api: api,
      child: const MaterialApp(
        home: AdminWorkspace(session: admin, initialKey: AdminNav.dispatch),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _SavedManifest extends DispatchManifestPublisher {
  Uint8List? bytes;
  var downloads = 0;
  var prints = 0;

  @override
  Future<void> download(Uint8List bytes, String filename) async {
    this.bytes = bytes;
    downloads++;
  }

  @override
  Future<void> openForPrint(Uint8List bytes, String filename) async {
    this.bytes = bytes;
    prints++;
  }
}
