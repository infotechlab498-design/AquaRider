import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riderfrontend/adminDashboard/presentation/screens/customer_accounts_screen.dart';
import 'package:riderfrontend/api/route_api.dart';
import 'package:riderfrontend/customerApp/customer_shell.dart';

import 'memory_route_api.dart';

AuthSession _session() => const AuthSession(
      accessToken: 'token',
      refreshToken: 'refresh',
      fullName: 'Ayesha Khan',
      username: 'ayesha@example.com',
      riderCode: '',
      routeName: '',
      vehicleName: '',
      vehiclePlate: '',
      fleetCode: '',
      depotGate: '',
      depotName: '',
      role: 'Customer',
      customerCode: 'CUS-000001',
    );

void main() {
  testWidgets('customer home stays empty until a route is linked', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(ApiScope(
      api: MemoryRouteApi(),
      child: MaterialApp(home: CustomerShell(session: _session())),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Hello, Ayesha'), findsOneWidget);
    await tester.tap(find.byKey(const Key('customer-open-profile')));
    await tester.pump();
    expect(find.byKey(const Key('customer-tab-profile')), findsOneWidget);
    expect(find.text('My Profile'), findsWidgets);
    await tester.tap(find.byKey(const Key('customer-tab-home')));
    await tester.pump();
    expect(find.text('The office has not placed this account on a delivery route yet.'), findsWidgets);
    expect(find.text('No Active Schedule'), findsOneWidget);

    await tester.tap(find.byKey(const Key('customer-tab-schedule')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('My Delivery Schedule'), findsOneWidget);
    expect(find.text('No Delivery Schedule Yet'), findsOneWidget);
    expect(find.byKey(const Key('customer-schedule-contact-support')), findsOneWidget);

    await tester.tap(find.byKey(const Key('customer-tab-payments')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.textContaining('Online payment is not enabled'), findsWidgets);
    expect(find.text('Payments'), findsWidgets);
    expect(find.text('Your invoices and payment history'), findsOneWidget);
    expect(find.text('Billed'), findsOneWidget);
    expect(find.text('No invoices yet'), findsOneWidget);
    await tester.drag(find.byKey(const Key('customer-payments-screen')), const Offset(0, -360));
    await tester.pump();
    expect(find.textContaining('payment History'), findsWidgets);

    tester.view.physicalSize = const Size(800, 420);
    await tester.pump();
    expect(find.byKey(const Key('customer-payments-screen')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('quantity request stays pending until the office approves it', (tester) async {
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final api = MemoryRouteApi()
      ..customerPlans = [
        const CustomerPlan(
          scheduleId: 'sch-1',
          code: 'SCH-20261120-0001',
          status: 'Active',
          product: '19L Water Bottle',
          quantity: 5,
          frequency: 'Weekly on Mon, Wed, Fri',
          startDate: '2026-11-20',
          address: 'Lane 7, Chaklala, Rawalpindi',
          timeWindow: 'Morning',
        ),
      ]
      ..customerHomeOverride = const CustomerHome(
        firstName: 'Ayesha',
        fullName: 'Ayesha Khan',
        customerCode: 'CUS-000001',
        accountStatus: 'Active',
        linked: true,
        linkMessage: 'Requests do not change this schedule until the office approves them.',
        subscription: CustomerPlan(
          scheduleId: 'sch-1',
          code: 'SCH-20261120-0001',
          status: 'Active',
          product: '19L Water Bottle',
          quantity: 5,
          frequency: 'Weekly on Mon, Wed, Fri',
          startDate: '2026-11-20',
          address: 'Lane 7, Chaklala, Rawalpindi',
          timeWindow: 'Morning',
        ),
        overview: CustomerCounts(scheduled: 1, completed: 0, upcoming: 1, skippedOrCancelled: 0),
        payments: CustomerMoney(totalBilled: 0, totalPaid: 0, outstanding: 0, overdue: 0, note: 'Online payment is not enabled.'),
        upcoming: [],
        unreadNotifications: 0,
      );

    await tester.pumpWidget(ApiScope(
      api: api,
      child: MaterialApp(home: CustomerShell(session: _session())),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    final homeList = find.descendant(of: find.byKey(const Key('customer-home-screen')), matching: find.byType(Scrollable)).first;
    final bottle = find.byKey(const Key('customer-action-change-bottle-quantity'));
    await tester.scrollUntilVisible(bottle, 400, scrollable: homeList);
    await tester.drag(homeList, const Offset(0, -280));
    await tester.pumpAndSettle();
    await tester.tap(bottle);
    await tester.pumpAndSettle();
    expect(find.text('This request does not change the active schedule. The office reviews it first.'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('customer-quantity')), '8');
    await tester.enterText(find.byKey(const Key('customer-request-reason')), 'Need more bottles');
    final list = find.descendant(of: find.byKey(const Key('customer-request-list')), matching: find.byType(Scrollable)).first;
    await tester.scrollUntilVisible(find.byKey(const Key('customer-request-submit')), 300, scrollable: list);
    await tester.tap(find.byKey(const Key('customer-request-submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('customer-request-confirm-submit')));
    await tester.pumpAndSettle();

    expect(find.text('CSR-000001'), findsOneWidget);
    expect(find.text('Status: Pending'), findsOneWidget);
    expect(api.lastCustomerRequestBody?['type'], 'QuantityChange');
    expect(api.lastCustomerRequestBody?['quantity'], 8);
    expect(api.lastCustomerReviewAction, isNull);
  });

  testWidgets('schedule tab shows the live active plan and adapts to landscape', (tester) async {
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final api = MemoryRouteApi()
      ..customerPlans = [
        const CustomerPlan(
          scheduleId: 'sch-1',
          code: 'SCH-20261120-0001',
          status: 'Active',
          product: '19L Water Bottle',
          quantity: 2,
          frequency: 'Weekly on Mon, Wed, Fri',
          startDate: '2026-11-20',
          address: '542, Chaklala Street 18, Lane 7, Rawalpindi',
          timeWindow: 'Morning',
          addressLabel: 'Home',
        ),
      ]
      ..customerHomeOverride = CustomerHome(
        firstName: 'Ayesha',
        fullName: 'Ayesha Khan',
        customerCode: 'CUS-000001',
        accountStatus: 'Active',
        linked: true,
        linkMessage: 'Linked to the delivery route.',
        subscription: const CustomerPlan(
          scheduleId: 'sch-1',
          code: 'SCH-20261120-0001',
          status: 'Active',
          product: '19L Water Bottle',
          quantity: 2,
          frequency: 'Weekly on Mon, Wed, Fri',
          startDate: '2026-11-20',
          address: '542, Chaklala Street 18, Lane 7, Rawalpindi',
          timeWindow: 'Morning',
          addressLabel: 'Home',
        ),
        overview: const CustomerCounts(scheduled: 1, completed: 0, upcoming: 1, skippedOrCancelled: 0),
        payments: const CustomerMoney(totalBilled: 0, totalPaid: 0, outstanding: 0, overdue: 0, note: 'Online payment is not enabled.'),
        upcoming: const [
          CustomerVisit(
            date: '2026-11-26',
            quantity: 2,
            status: 'Scheduled',
            address: '542, Chaklala Street 18, Lane 7, Rawalpindi',
            timeWindow: 'Morning',
            reference: 'SCH-20261120-0001',
            product: '19L Water Bottle',
            weekday: 'Wednesday',
            scheduleId: 'sch-1',
            addressLabel: 'Home',
          ),
        ],
        unreadNotifications: 0,
      );

    await tester.pumpWidget(ApiScope(
      api: api,
      child: MaterialApp(home: CustomerShell(session: _session())),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byKey(const Key('customer-tab-schedule')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('My Delivery Schedule'), findsOneWidget);
    expect(find.text('Active Schedule'), findsOneWidget);
    expect(find.text('Mon, Wed, Fri'), findsOneWidget);
    expect(find.textContaining('2 Bottles'), findsWidgets);
    expect(find.text('Home'), findsWidgets);
    expect(find.textContaining('Next Delivery: Wed, 26 Nov 2026'), findsOneWidget);
    expect(find.byKey(const Key('customer-request-schedule-change')), findsOneWidget);

    tester.view.physicalSize = const Size(860, 420);
    await tester.pump();
    expect(find.byKey(const Key('customer-schedule-screen')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('admin request queue requires a rejection comment', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const request = CustomerRequest(
      id: 'req-1',
      code: 'CSR-000002',
      type: 'Pause',
      status: 'Pending',
      currentSummary: 'SCH-20261120-0001 weekly',
      requestedSummary: 'Pause 2026-12-01 through 2026-12-07.',
      reason: 'Travel',
      affectedDates: '2026-12-01 (Scheduled)',
      createdAt: '2026-11-20 13:40',
      customerCode: 'CUS-000001',
      customerName: 'Ayesha Khan',
    );
    final api = MemoryRouteApi()
      ..customerRequestQueueOverride = [request]
      ..customerAccountBoardOverride = const CustomerAccountBoard(
        total: 1,
        active: 1,
        inactive: 0,
        withSchedules: 0,
        withBalance: 0,
        pendingRequests: 1,
        rows: [
          CustomerAccountRow(
            id: 'acc-1',
            code: 'CUS-000001',
            name: 'Ayesha Khan',
            phone: '+923001234567',
            email: 'ayesha@example.com',
            city: 'Rawalpindi',
            area: 'Chaklala',
            status: 'Active',
            createdAt: '2026-11-20',
            linked: false,
            activeSchedules: 0,
            outstanding: 0,
            pendingRequests: 1,
          ),
        ],
      );

    await tester.pumpWidget(ApiScope(
      api: api,
      child: MaterialApp(home: CustomerAccountsScreen(onNavigate: (_) {}, session: _session())),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Customer Management'), findsOneWidget);
    await tester.tap(find.byKey(const Key('admin-customer-requests-tab')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('admin-request-CSR-000002')));
    await tester.pumpAndSettle();
    expect(find.text('2026-12-01 (Scheduled)'), findsOneWidget);

    await tester.tap(find.byKey(const Key('admin-review-reject')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('A comment is required.'), findsOneWidget);
    expect(api.lastCustomerReviewAction, isNull);

    await tester.tap(find.byKey(const Key('admin-request-CSR-000002')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('admin-review-comment')), 'Dates overlap a dispatched visit.');
    await tester.tap(find.byKey(const Key('admin-review-reject')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(api.lastCustomerReviewAction, 'reject');
    expect(find.text('Rejected'), findsWidgets);
  });

  testWidgets('password change rejects a mismatch before calling the server', (tester) async {
    await tester.pumpWidget(ApiScope(
      api: MemoryRouteApi(),
      child: MaterialApp(home: CustomerShell(session: _session())),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byKey(const Key('customer-tab-profile')));
    await tester.pumpAndSettle();
    final profileList = find.descendant(of: find.byKey(const Key('customer-profile-screen')), matching: find.byType(Scrollable)).first;
    await tester.scrollUntilVisible(find.byKey(const Key('customer-open-password')), 200, scrollable: profileList);
    await tester.tap(find.byKey(const Key('customer-open-password')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('customer-password-current')), 'old-pass');
    await tester.enterText(find.byKey(const Key('customer-password-next')), 'newpass1');
    await tester.enterText(find.byKey(const Key('customer-password-confirm')), 'otherpass1');
    await tester.tap(find.byKey(const Key('customer-password-save')));
    await tester.pump();
    expect(find.text('The new passwords do not match.'), findsOneWidget);
  });

  testWidgets('profile shows the signed-in customer and confirms logout', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(ApiScope(
      api: MemoryRouteApi(),
      child: MaterialApp(home: CustomerShell(session: _session())),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byKey(const Key('customer-tab-profile')));
    await tester.pumpAndSettle();

    expect(find.text('My Profile'), findsOneWidget);
    expect(find.text('Ayesha Khan'), findsOneWidget);
    expect(find.text('Customer ID · CUS-000001'), findsOneWidget);
    expect(find.text('ayesha@example.com'), findsOneWidget);
    expect(find.text('No active delivery schedule yet'), findsOneWidget);
    expect(find.text('18, Lane 7, Chaklala, Rawalpindi'), findsOneWidget);
    expect(find.text('Active · since 20 Nov 2026'), findsOneWidget);

    final profileList = find.descendant(of: find.byKey(const Key('customer-profile-screen')), matching: find.byType(Scrollable)).first;
    await tester.scrollUntilVisible(find.text('Deactivate'), 200, scrollable: profileList);
    await tester.tap(find.text('Deactivate'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Keep at least one active address.'), findsOneWidget);
    expect(find.text('Deactivate this address?'), findsNothing);

    await tester.pump(const Duration(seconds: 4));
    await tester.scrollUntilVisible(find.byKey(const Key('customer-logout')), 200, scrollable: profileList);
    await tester.drag(profileList, const Offset(0, -220));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('customer-logout')));
    await tester.pumpAndSettle();
    expect(find.text('Log out?'), findsOneWidget);
    await tester.tap(find.text('Stay'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('customer-profile-screen')), findsOneWidget);
    expect(find.text('Log out?'), findsNothing);
  });

  testWidgets('a blank address is rejected before it is saved', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = _CountingApi();

    await tester.pumpWidget(ApiScope(
      api: api,
      child: MaterialApp(home: CustomerShell(session: _session())),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byKey(const Key('customer-tab-profile')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('customer-add-address')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save address'));
    await tester.pump();
    expect(find.text('Label, city, area, street, and house number are required.'), findsOneWidget);
    expect(api.addressSaves, 0);
  });

  testWidgets('profile fits a narrow phone and a landscape tablet', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final size in const [Size(320, 640), Size(800, 420)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(ApiScope(
        api: MemoryRouteApi(),
        child: MaterialApp(home: CustomerShell(session: _session())),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byKey(const Key('customer-tab-profile')));
      await tester.pumpAndSettle();
      expect(find.text('My Profile'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}

class _CountingApi extends MemoryRouteApi {
  var addressSaves = 0;

  @override
  Future<CustomerAddress> saveCustomerAddress(Map<String, dynamic> body, {String? id}) async {
    addressSaves += 1;
    return super.saveCustomerAddress(body, id: id);
  }
}
