import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riderfrontend/adminDashboard/presentation/admin_nav.dart';
import 'package:riderfrontend/adminDashboard/presentation/admin_workspace.dart';
import 'package:riderfrontend/api/route_api.dart';

import 'memory_route_api.dart';

class _CustomersMemoryApi extends MemoryRouteApi {
  @override
  Future<AdminCustomersSummary> adminCustomersSummary() async {
    return const AdminCustomersSummary(
      totalCustomers: 2,
      activeCustomers: 2,
      totalOutstanding: 2500,
      withOutstanding: 1,
      missingGps: 1,
    );
  }

  @override
  Future<List<RouteListItem>> listRoutes({String? zoneId, String? search}) async {
    return const [
      RouteListItem(
        id: 'route-1',
        name: 'Satellite Town – Route 03',
        zoneId: 'zone-1',
        zoneName: 'Satellite Town',
        customerCount: 2,
      ),
    ];
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
    return const AdminCustomerPage(
      rows: [
        AdminCustomerRow(
          id: 'c1',
          code: 'CUS-1001',
          businessName: 'Ali General Store',
          routeName: 'Satellite Town – Route 03',
          outstanding: 2500,
        ),
        AdminCustomerRow(
          id: 'c2',
          code: 'CUS-1002',
          businessName: 'City Mart',
          routeName: 'Satellite Town – Route 03',
        ),
      ],
      totalRecords: 2,
      totalPages: 1,
    );
  }

  @override
  Future<AdminCustomerDetail> adminCustomerDetail(String id) async {
    return AdminCustomerDetail(
      customer: const AdminCustomerRow(
        id: 'c1',
        code: 'CUS-1001',
        businessName: 'Ali General Store',
        routeName: 'Satellite Town – Route 03',
        zoneName: 'Satellite Town',
        outstanding: 2500,
        bottlesHeld: 3,
        address: 'Shop 4, Satellite Town',
        city: 'Rawalpindi',
        phone: '+92 300 1234567',
      ),
      lifetimeSales: 360,
      lifetimeCollections: 3000,
      recentLedger: [
        AdminLedgerRow(
          id: 'l1',
          description: 'Sale RCP-0042',
          occurredAt: DateTime(2026, 11, 10, 9, 30),
          amount: 360,
          balanceAfter: 2860,
          kind: 'Sale',
          reference: 'RCP-0042',
        ),
      ],
    );
  }
}

void main() {
  testWidgets('customers directory loads summary and detail drawer', (tester) async {
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

    await tester.pumpWidget(
      ApiScope(
        api: _CustomersMemoryApi(),
        child: MaterialApp(
          home: AdminWorkspace(
            session: admin,
            initialKey: AdminNav.customersParties,
          ),
        ),
      ),
    );
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pump(); // schedule post-frame reload
    await tester.pump(); // start async reload
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('customers-directory-screen')), findsOneWidget);
    expect(find.text('Customers & Parties Directory'), findsOneWidget);
    expect(find.text('No customers matched these filters.'), findsNothing);
    expect(find.textContaining('Ali General Store'), findsWidgets);
    expect(find.textContaining('Recent ledger'), findsOneWidget);
  });
}
