import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riderfrontend/adminDashboard/presentation/admin_nav.dart';
import 'package:riderfrontend/adminDashboard/presentation/admin_workspace.dart';
import 'package:riderfrontend/adminDashboard/presentation/widgets/dashboard/collections_summary_card.dart';
import 'package:riderfrontend/api/route_api.dart';

import 'memory_route_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  test('missing command figures are not replaced with screenshot totals', () {
    expect(DashboardKpiSet.fromJson(const {}).cards, isEmpty);
    expect(DashboardKpiSet.fromJson(const {'invoiceCount': 4}).cards, isEmpty);
    final parsed = DashboardKpiSet.fromJson(const {'totalBilledSales': 1200});
    expect(parsed.cards, hasLength(1));
    expect(parsed.cards.single.value, 'PKR 1,200');
    expect(parsed.cards.single.label, 'Total billed sales');
    expect(parsed.cards.single.value.contains('185'), isFalse);
  });

  test('nested command KPI payload from ASP.NET maps all six cards', () {
    final parsed = DashboardKpiSet.fromJson(const {
      'sales': {'totalBilledSales': 2500, 'invoiceCount': 2, 'changePercent': 10},
      'collections': {'collectionsReceived': 800, 'collectionCount': 1, 'recoveryPercent': 32},
      'fleet': {'fleetRegistered': 2, 'fleetOnDuty': 1},
      'deliveries': {'deliveriesCompleted': 5, 'deliveriesTotal': 10, 'percent': 50},
      'orders': {'pendingOrders': 3, 'unassignedOrders': 1},
      'outstanding': {'outstandingDues': 1200, 'accountsWithDues': 4},
    });
    expect(parsed.cards, hasLength(6));
    expect(parsed.cards.map((c) => c.label).toList(), lockedCommandKpiLabels);
    expect(parsed.cards.first.value, 'PKR 2,500');
    expect(parsed.cards.first.value.contains('185'), isFalse);
  });

  test('locked labels exclude wallet, raast, and live trackboard claims', () {
    final labels = [
      ...lockedCommandKpiLabels,
      ...approvedCollectionLabels,
      ...lockedRiderKpiLabels,
    ];
    final blob = labels.join(' ').toLowerCase();
    expect(lockedCommandKpiLabels, hasLength(6));
    expect(approvedCollectionLabels, ['Cash', 'Full credit', 'Partial cash']);
    expect(lockedRiderKpiLabels, hasLength(5));
    expect(blob.contains('wallet'), isFalse);
    expect(blob.contains('raast'), isFalse);
    expect(blob.contains('ibft'), isFalse);
    expect(blob.contains('radar'), isFalse);
    expect(blob.contains('trackboard'), isFalse);
  });

  test('collection parsing drops wallet, raast, and bank channels', () {
    final summary = CollectionsSummary.fromJson(const {
      'cash': 10,
      'fullCredit': 20,
      'partialCash': 30,
      'wallet': 999,
      'raast': 888,
      'bankTransfer': 777,
    });
    expect(
      summary.channels.map((channel) => channel.label).toList(),
      approvedCollectionLabels,
    );
    expect(summary.cash.amount, 10);
    expect(summary.fullCredit.amount, 20);
    expect(summary.partialCash.amount, 30);
    expect(summary.reportedTotal, 60);
    expect(
      summary.channels.any(
        (channel) =>
            channel.amount == 999 ||
            channel.amount == 888 ||
            channel.amount == 777,
      ),
      isFalse,
    );
  });

  test(
    'rider summary ignores moving-speed cards and keeps registered counts',
    () {
      final summary = RiderOperationsSummary.fromJson(const {
        'ridersRegistered': 4,
        'kpis': [
          {'key': 'speed', 'label': 'Moving speed', 'value': 26},
          {'key': 'radar', 'label': 'LIVE RADAR', 'value': 1},
        ],
      });
      expect(summary.kpis.map((kpi) => kpi.label).toList(), [
        'Riders registered',
      ]);
      expect(
        summary.kpis.any((kpi) => kpi.label.toLowerCase().contains('speed')),
        isFalse,
      );
      expect(
        summary.kpis.any((kpi) => kpi.label.toLowerCase().contains('radar')),
        isFalse,
      );
      expect(summary.ridersRegistered, 4);
      final counted = RiderOperationsSummary.fromJson(const {
        'ridersRegistered': 4,
        'availableForAssignment': 1,
      });
      expect(counted.kpis.map((kpi) => kpi.label).toList(), [
        'Riders registered',
        'Available for assignment',
      ]);
      expect(counted.kpis.first.value, '4');
    },
  );

  test('location verification parsing stays empty and does not require coordinates', () {
    expect(LocationVerification.listFromJson(const []), isEmpty);
    expect(LocationVerification.listFromJson(const {'items': []}), isEmpty);
  });

  testWidgets('collections card renders only the approved channels', (
    tester,
  ) async {
    final summary = CollectionsSummary.fromJson(const {
      'cash': 10,
      'fullCredit': 20,
      'partialCash': 30,
      'wallet': 999,
      'raast': 888,
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CollectionsSummaryCard(summary: summary)),
      ),
    );
    expect(find.text('Cash'), findsOneWidget);
    expect(find.text('Full credit'), findsOneWidget);
    expect(find.text('Partial cash'), findsOneWidget);
    expect(find.text('PKR 10'), findsOneWidget);
    expect(find.textContaining('Wallet'), findsNothing);
    expect(find.textContaining('Raast'), findsNothing);
    expect(find.textContaining('999'), findsNothing);
  });

  testWidgets(
    'sidebar opens rider operations and the checklist without live claims',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ApiScope(
          api: MemoryRouteApi(
            kpisOverride: DashboardKpiSet.fromJson(const {
              'totalBilledSales': 1200,
            }),
          ),
          child: const MaterialApp(home: AdminWorkspace(session: admin)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('PKR 1,200'), findsOneWidget);
      expect(find.textContaining('185,000'), findsNothing);
      expect(find.textContaining('185000'), findsNothing);
      expect(find.text('TOTAL BILLED SALES'), findsOneWidget);

      await tester.tap(find.byKey(const Key('admin-nav-fleetCouriers')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('rider-operations-screen')), findsOneWidget);
      expect(find.text('Rider Operations'), findsOneWidget);
      expect(
        find.text('No location verifications are recorded.'),
        findsOneWidget,
      );
      expect(find.textContaining('LIVE RADAR'), findsNothing);
      expect(find.text('Live Trackboard'), findsNothing);
      expect(find.text('Live Tracking'), findsNothing);
      expect(find.text('History Playback'), findsNothing);
      expect(find.textContaining('Battery'), findsNothing);
      expect(find.textContaining('GPS'), findsNothing);
      expect(find.text('Price Lists'), findsNothing);
      expect(find.text('Dispatch & Orders'), findsOneWidget);
      expect(find.text('Notify'), findsNothing);
      expect(find.textContaining('km/h'), findsNothing);
      expect(find.textContaining('Knox'), findsNothing);

      await tester.tap(find.byKey(const Key('admin-nav-setupChecklist')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('onboarding-screen')), findsOneWidget);
      expect(find.text('Plant Details'), findsWidgets);
      expect(
        find.text(
          'The onboarding endpoints are not available on this server yet.',
        ),
        findsOneWidget,
      );
      expect(find.text('Live Trackboard'), findsNothing);
      expect(find.text('Spot Billing Ledger'), findsNothing);
      final pending = find.text('Pending (0)');
      await tester.ensureVisible(pending);
      await tester.tap(pending);
      await tester.pumpAndSettle();
      expect(find.text('No steps match this filter.'), findsOneWidget);

      await tester.tap(find.byKey(const Key('admin-nav-routeManifests')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('route-manifests-screen')), findsOneWidget);
      expect(find.text(MemoryRouteApi.zonesUnavailable), findsWidgets);
      expect(
        find.text('Route manifests are not available on this server yet.'),
        findsNothing,
      );
      expect(
        find.byKey(const Key('admin-nav-${AdminNav.manifests}')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'create order stays on the dialog when required fields are empty',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
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
      await tester.tap(find.byKey(const Key('create-order-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('create-order-submit')));
      await tester.pumpAndSettle();
      expect(find.text('Enter the customer id.'), findsOneWidget);
      expect(find.textContaining('was saved'), findsNothing);
    },
  );
}
