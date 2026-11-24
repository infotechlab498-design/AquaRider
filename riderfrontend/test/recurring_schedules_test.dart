import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riderfrontend/adminDashboard/data/recurring_schedule_models.dart';
import 'package:riderfrontend/adminDashboard/presentation/screens/recurring_schedules_screen.dart';
import 'package:riderfrontend/api/route_api.dart';

import 'memory_route_api.dart';

void main() {
  testWidgets('recurring directory shows the saved schedule', (tester) async {
    tester.view.physicalSize = const Size(1440, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ApiScope(
        api: _SchedulesApi(),
        child: const MaterialApp(home: RecurringSchedulesScreen(onNavigate: _ignore)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('recurring-schedules-screen')), findsOneWidget);
    expect(find.text('Recurring Delivery Schedule Planner'), findsOneWidget);
    expect(find.text('Recurring Schedules'), findsWidgets);
    expect(find.textContaining('Zahid A'), findsOneWidget);
    expect(find.text('SCH-20261120-0001'), findsOneWidget);
    expect(find.text('1'), findsWidgets);
    expect(find.textContaining('Import'), findsNothing);
    expect(find.text('View'), findsNothing);

    final menu = find.byKey(const Key('schedule-actions-schedule-1'));
    await tester.ensureVisible(menu);
    await tester.pumpAndSettle();
    await tester.tap(menu);
    await tester.pumpAndSettle();
    expect(find.text('View'), findsOneWidget);
    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Pause'), findsOneWidget);
    expect(find.text('Resume'), findsOneWidget);
    expect(find.text('Duplicate'), findsOneWidget);
    expect(find.text('Calendar'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);

    await tester.tap(find.text('Pause'));
    await tester.pumpAndSettle();
    expect(find.text('Pause SCH-20261120-0001'), findsOneWidget);
  });

  testWidgets('create schedule adds a product row and lists every rider', (tester) async {
    tester.view.physicalSize = const Size(1440, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ApiScope(
        api: _FormApi(),
        child: const MaterialApp(home: RecurringSchedulesScreen(onNavigate: _ignore)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('recurring-create')));
    await tester.pumpAndSettle();

    expect(find.text('Products on each visit'), findsOneWidget);
    expect(find.text('Fix this rider for every delivery'), findsOneWidget);
    expect(find.text('Choose a rider for this delivery'), findsOneWidget);
    final add = find.byKey(const Key('schedule-add-product'));
    await tester.ensureVisible(add);
    await tester.tap(add);
    await tester.pump();
    expect(find.text('Quantity'), findsNWidgets(2));
    await tester.ensureVisible(find.byKey(const ValueKey('Rider-null-2')));
    await tester.tap(find.byKey(const ValueKey('Rider-null-2')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Infotech Lab'), findsWidgets);
    expect(find.textContaining('Ahmed Khan'), findsWidgets);
  });

  testWidgets('schedule calendar uses compact colored days', (tester) async {
    tester.view.physicalSize = const Size(1440, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ApiScope(
        api: _CalendarApi(),
        child: const MaterialApp(home: RecurringSchedulesScreen(onNavigate: _ignore)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('recurring-calendar')));
    await tester.pumpAndSettle();

    expect(find.text('Sun'), findsOneWidget);
    expect(find.text('Scheduled'), findsWidgets);
    expect(find.text('Published'), findsWidgets);
    await tester.tap(find.text('20'));
    await tester.pump();
    expect(find.text('Zahid A · CUS-1'), findsOneWidget);
  });
}

void _ignore(String _) {}

class _CalendarApi extends _SchedulesApi {
  @override
  Future<ScheduleCalendar> recurringCalendar({required int year, required int month, String? scheduleId}) async {
    final monthText = month.toString().padLeft(2, '0');
    return ScheduleCalendar(
      year: year,
      month: month,
      days: [
        ScheduleCalendarDay(
          date: '$year-$monthText-20',
          deliveries: 2,
          bottles: 7,
          items: const [
            ScheduleCalendarItem(
              occurrenceId: 'occ-1',
              scheduleId: 'schedule-1',
              scheduleCode: 'SCH-20261120-0001',
              customerName: 'Zahid A',
              customerCode: 'CUS-1',
              address: 'Chaklala',
              productSummary: '19L Water Bottle x 5',
              quantity: 5,
              timeWindow: 'Morning',
              riderId: 'r1',
              riderName: 'Infotech Lab',
              riderCode: 'RDR-1043',
              status: 'Scheduled',
            ),
          ],
        ),
      ],
    );
  }
}

class _FormApi extends _SchedulesApi {
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
    return const AdminCustomerPage(rows: [
      AdminCustomerRow(id: 'customer-1', code: 'CUS-1', businessName: 'Zahid A'),
    ]);
  }

  @override
  Future<ProductCataloguePage> productCatalogue({
    String? categoryKey,
    String? search,
    String? status,
    int page = 1,
    int pageSize = 20,
  }) async {
    return const ProductCataloguePage(rows: [
      ProductBasePriceRow(id: 'p-19', name: '19L Water Bottle', sku: '19L', baseSystemPrice: 180),
      ProductBasePriceRow(id: 'p-15', name: '1.5L Water Bottle Pack', sku: '1.5L', baseSystemPrice: 320),
    ]);
  }

  @override
  Future<List<RiderRecord>> riderOperationsRiders({
    String? search,
    String? status,
    required String date,
  }) async {
    expect(status, 'all');
    return const [
      RiderRecord(id: 'r1', fullName: 'Infotech Lab', riderCode: 'RDR-1043', status: 'onDuty'),
      RiderRecord(id: 'r2', fullName: 'Ahmed Khan', riderCode: 'RDR-1042', status: 'available'),
    ];
  }
}

class _SchedulesApi extends MemoryRouteApi {
  @override
  Future<RecurringBoard> recurringSchedules({
    String? search,
    String? tab,
    String? depotId,
    String? productId,
    String? riderId,
    int page = 1,
    int pageSize = 20,
  }) async {
    return const RecurringBoard(
      activePlans: 1,
      deliveriesThisMonth: 4,
      paused: 0,
      unassigned: 0,
      ridersAssigned: 1,
      total: 1,
      page: 1,
      pageSize: 20,
      tabs: RecurringTabCounts(
        all: 1,
        weekly: 1,
        monthly: 0,
        paused: 0,
        expiring: 0,
        exceptions: 0,
        unassigned: 0,
      ),
      rows: [
        RecurringScheduleRow(
          id: 'schedule-1',
          scheduleCode: 'SCH-20261120-0001',
          customerId: 'customer-1',
          customerName: 'Zahid A',
          customerCode: 'CUS-1',
          phone: '03001234567',
          address: 'Chaklala',
          productSummary: '19L Water Bottle x 5',
          quantityPerVisit: 5,
          frequency: 'Weekly',
          monthlyCount: 4,
          riderId: 'rider-1',
          riderName: 'Infotech Lab',
          riderCode: 'RDR-1043',
          nextDate: '2026-11-23',
          status: 'Active',
          version: 1,
        ),
      ],
      depots: [ScheduleDepotOption(id: 'depot-1', name: 'Warehouse Depot Hub 02')],
    );
  }
}
