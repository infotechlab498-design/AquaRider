import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riderfrontend/adminDashboard/presentation/admin_nav.dart';
import 'package:riderfrontend/adminDashboard/presentation/admin_workspace.dart';
import 'package:riderfrontend/api/route_api.dart';

import 'memory_route_api.dart';

class _StaffMemoryApi extends MemoryRouteApi {
  @override
  Future<StaffSummary> staffSummary() async {
    return const StaffSummary(
      totalStaff: 3,
      activeUsers: 3,
      activeRiders: 2,
      admins: 1,
      loggedInToday: 1,
    );
  }

  @override
  Future<RoleAccessMatrix> roleAccess() async {
    return const RoleAccessMatrix(
      assignedStaff: 2,
      policyNote: 'Screen access is stored per role.',
      screens: [
        RoleAccessScreen(
          key: 'dispatchOrders',
          group: 'Field Operations & Dispatch Board',
          label: 'Dispatch & Orders',
          detail: 'Create and manage orders.',
        ),
      ],
      roles: [
        RoleAccessRow(
          role: 'Admin',
          description: 'Full HQ access to every stored screen.',
          assignedCount: 1,
          isSystem: true,
          screenKeys: ['dispatchOrders'],
          members: [RoleAccessMember(id: 'u1', fullName: 'Fleet Admin')],
        ),
        RoleAccessRow(
          role: 'Dispatcher',
          description: 'Orders and route stops.',
          assignedCount: 1,
          screenKeys: ['dispatchOrders'],
          members: [RoleAccessMember(id: 'u2', fullName: 'Ahmed Khan', riderCode: 'RDR-1042')],
        ),
      ],
    );
  }

  @override
  Future<RoleAccessRow> saveRoleAccess(String role, List<String> screenKeys) async {
    return RoleAccessRow(role: role, screenKeys: screenKeys);
  }

  @override
  Future<List<RoleReference>> staffRoleReference() async {
    return const [
      RoleReference(
        role: 'Admin',
        title: 'Administrator',
        description: 'HQ access',
        assignedCount: 1,
      ),
      RoleReference(
        role: 'Rider',
        title: 'Delivery Rider',
        description: 'Field access',
        assignedCount: 2,
      ),
    ];
  }

  @override
  Future<List<RouteListItem>> listRoutes({String? zoneId, String? search}) async {
    return const [
      RouteListItem(
        id: 'route-1',
        name: 'Satellite Town – Route 03',
        zoneName: 'Satellite Town',
      ),
    ];
  }

  @override
  Future<StaffUserPage> staffUsers({
    String? search,
    String? role,
    bool? isActive,
    int page = 1,
    int pageSize = 50,
  }) async {
    return const StaffUserPage(
      rows: [
        StaffUser(
          id: 'u1',
          username: 'admin',
          fullName: 'Fleet Admin',
          primaryRole: 'Admin',
          roles: ['Admin'],
          isActive: true,
        ),
        StaffUser(
          id: 'u2',
          username: 'ahmed.khan',
          fullName: 'Ahmed Khan',
          riderCode: 'RDR-1042',
          primaryRole: 'Rider',
          roles: ['Rider'],
          routeName: 'Satellite Town – Route 03',
          isActive: true,
        ),
      ],
      totalRecords: 2,
      totalPages: 1,
    );
  }

  @override
  Future<StaffUser> staffUser(String id) async {
    return const StaffUser(
      id: 'u2',
      username: 'ahmed.khan',
      fullName: 'Ahmed Khan',
      riderCode: 'RDR-1042',
      primaryRole: 'Rider',
      roles: ['Rider'],
      routeName: 'Satellite Town – Route 03',
      vehiclePlate: 'LEA-8841',
      depotName: 'Warehouse Depot Hub 02',
      isActive: true,
    );
  }
}

void main() {
  testWidgets('users and staff screen loads summary and directory', (tester) async {
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

    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ApiScope(
        api: _StaffMemoryApi(),
        child: MaterialApp(
          home: AdminWorkspace(
            session: admin,
            initialKey: AdminNav.usersStaff,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('users-staff-screen')), findsOneWidget);
    expect(find.text('Roles & Permissions'), findsWidgets);
    expect(find.text('Dispatcher'), findsWidgets);
    await tester.tap(find.byKey(const Key('role-row-Dispatcher')));
    await tester.pump();
    expect(find.textContaining('Ahmed Khan'), findsWidgets);
    expect(find.textContaining('No custom RBAC'), findsNothing);
    expect(find.textContaining('Knox'), findsNothing);
  });
}
