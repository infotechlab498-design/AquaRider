import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riderfrontend/adminDashboard/presentation/screens/warehouse_screen.dart';
import 'package:riderfrontend/api/route_api.dart';

import 'memory_route_api.dart';

void main() {
  testWidgets('warehouse screen uses the registered depot', (tester) async {
    tester.view.physicalSize = const Size(1440, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final api = _DepotApi();
    await tester.pumpWidget(
      ApiScope(
        api: api,
        child: const MaterialApp(home: WarehouseScreen(onNavigate: _ignore)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('warehouse-screen')), findsOneWidget);
    expect(find.text('Branches & Warehouses Management'), findsOneWidget);
    expect(find.text('Warehouse Depot Hub 02'), findsWidgets);
    expect(find.text('WH-02'), findsWidgets);
    expect(find.text('Mineral Bottle'), findsOneWidget);
    expect(find.textContaining('PKR 500'), findsOneWidget);
    expect(find.textContaining('Rawalpindi'), findsNothing);
    expect(find.textContaining('Islamabad'), findsNothing);
    expect(find.text('248'), findsNothing);
    expect(find.text('1,850'), findsNothing);
    expect(api.lastDate, isNotNull);

    await tester.tap(find.byKey(const Key('warehouse-tab-satellite')));
    await tester.pump();
    expect(find.text('No warehouse matched this location filter.'), findsOneWidget);
    expect(find.text('Mineral Bottle'), findsNothing);

    await tester.tap(find.byKey(const Key('warehouse-tab-all')));
    await tester.pump();
    expect(find.text('Warehouse Depot Hub 02'), findsWidgets);

    await tester.ensureVisible(find.byKey(const Key('warehouse-fleet')));
    await tester.tap(find.byKey(const Key('warehouse-fleet')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('warehouse-fleet-dialog')), findsOneWidget);
    expect(find.textContaining('LEA-8841'), findsWidgets);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async => null,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.ensureVisible(find.byKey(const Key('warehouse-export')));
    await tester.tap(find.byKey(const Key('warehouse-export')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Copied the depot directory as CSV.'), findsOneWidget);
  });

  testWidgets('warehouse screen stays empty when the depot is unavailable', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ApiScope(
        api: MemoryRouteApi(),
        child: const MaterialApp(home: WarehouseScreen(onNavigate: _ignore)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(MemoryRouteApi.depotUnavailable), findsOneWidget);
    expect(find.textContaining('Rawalpindi'), findsNothing);
    expect(find.text('248'), findsNothing);
  });
}

void _ignore(String key) {}

class _DepotApi extends MemoryRouteApi {
  String? lastDate;

  @override
  Future<DepotOperations> depotSummary({String? date}) async {
    lastDate = date;
    return const DepotOperations(
      depot: DepotDetail(
        id: 'depot-1',
        name: 'Warehouse Depot Hub 02',
        gate: 'Gate 2',
        address: 'Industrial Area, Rawat',
        classification: 'PRIMARY DEPOT',
        status: 'Active',
        code: 'WH-02',
      ),
      kpis: DepotKpis(
        totalDepots: 1,
        centralWarehouses: 1,
        satelliteHubs: 0,
        activeWarehouses: 1,
        activePercent: 100,
        assignedFleet: 2,
        activeVehicles: 1,
        todaysDispatchOrders: 3,
        todaysDispatchVolume: 40,
        dispatchUnit: 'units',
        linkedStores: 6,
      ),
      capacity: DepotCapacity(
        occupiedUnits: 10,
        expectedUnits: 20,
        availableUnits: 10,
        utilizationPercent: 50,
        unitLabel: 'units on assigned vans',
      ),
      fleet: [
        DepotFleetMember(
          vehicleId: 'v1',
          vehicleName: 'Toyota HiAce',
          plate: 'LEA-8841',
          riderName: 'Ahmed Khan',
          riderCode: 'RDR-1042',
          riderActive: true,
          stockUnits: 10,
        ),
      ],
      stock: [
        DepotStockLine(
          productId: 'p1',
          productName: 'Mineral Bottle',
          sku: 'MIN-19',
          quantityOnVans: 10,
          depotExpected: 20,
        ),
      ],
      todaysCompletedSales: 2,
      todaysBilledSales: 500,
      managerName: 'Ahmed Khan',
      scopeNote: 'Locked V1: single Main Warehouse. Multi-depot network is not available.',
    );
  }
}
