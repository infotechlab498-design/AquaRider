import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riderfrontend/adminDashboard/data/admin_shift_models.dart';
import 'package:riderfrontend/adminDashboard/presentation/screens/shift_records_screen.dart';
import 'package:riderfrontend/api/route_api.dart';

import 'memory_route_api.dart';

void main() {
  testWidgets('shift records show the saved load and odometer', (tester) async {
    tester.view.physicalSize = const Size(1440, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ApiScope(
        api: _ShiftApi(),
        child: const MaterialApp(home: ShiftRecordsScreen(onNavigate: _ignore)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('shift-records-screen')), findsOneWidget);
    expect(find.text('Shift Records'), findsWidgets);
    expect(find.text('Infotech Lab'), findsWidgets);
    expect(find.text('Day started'), findsWidgets);
    expect(find.text('19L Water Bottle'), findsWidgets);
    expect(find.textContaining('loaded 80'), findsOneWidget);
    expect(find.textContaining('Short by 10'), findsOneWidget);
    expect(find.textContaining('3 orders · 40 units'), findsOneWidget);
    expect(find.textContaining('opening 45820 km'), findsOneWidget);
    expect(find.text('No photo was stored.'), findsWidgets);
    expect(find.textContaining('Verified'), findsNothing);
    expect(find.textContaining('Satellite Town'), findsNothing);
  });
}

void _ignore(String _) {}

class _ShiftApi extends MemoryRouteApi {
  @override
  Future<ShiftDayRecord> adminShiftDay({String? date, String? riderId}) async {
    const rider = ShiftRiderDay(
      riderId: 'rider-1',
      riderName: 'Infotech Lab',
      riderCode: 'RDR-1043',
      routeName: 'Chaklala - Route 01',
      vehicleName: 'Toyota HiAce',
      plate: 'LEA-8841',
      fleetCode: '',
      depotName: 'Warehouse Depot Hub 02',
      status: 'Open',
      startedAt: '2026-11-20T04:10:00Z',
      endedAt: null,
      openingOdometer: 45820,
      closingOdometer: null,
      openingPhotoStored: false,
      closingPhotoStored: false,
      openingInspectionStored: false,
      closingInspectionStored: false,
      openingOdometerPhoto: null,
      closingOdometerPhoto: null,
      openingInspectionPhoto: null,
      closingInspectionPhoto: null,
      loadedUnits: 80,
      expectedUnits: 90,
      toDeliverUnits: 40,
      orderCount: 3,
      loaded: [
        LoadedBottle(
          productName: '19L Water Bottle',
          unitLabel: 'units',
          depotExpected: 90,
          loaded: 80,
          closing: null,
        ),
      ],
      toDeliver: [
        DeliverBottle(productName: '19L Water Bottle', unitLabel: 'units', quantity: 40),
      ],
    );
    return ShiftDayRecord(
      serviceDate: date ?? '2026-11-20',
      riders: const [rider],
      selected: rider,
      odometer: const [
        OdometerDay(
          serviceDate: '2026-11-20',
          status: 'Open',
          openingOdometer: 45820,
          closingOdometer: null,
          distanceKm: null,
        ),
      ],
    );
  }
}
