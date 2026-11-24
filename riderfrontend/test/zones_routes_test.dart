import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riderfrontend/adminDashboard/presentation/admin_nav.dart';
import 'package:riderfrontend/adminDashboard/presentation/admin_workspace.dart';
import 'package:riderfrontend/api/route_api.dart';

import 'memory_route_api.dart';

class _ZonesMemoryApi extends MemoryRouteApi {
  @override
  Future<ZonesRoutesSummary> zonesRoutesSummary() async {
    return const ZonesRoutesSummary(
      totalZones: 1,
      activeZones: 1,
      activeRoutes: 1,
      assignedRiders: 1,
      assignedStores: 2,
      customersMissingGps: 1,
      depotName: 'Warehouse Depot Hub 02',
    );
  }

  @override
  Future<List<ZoneListItem>> listZones({String? search, bool? activeOnly}) async {
    return const [
      ZoneListItem(
        id: 'zone-1',
        name: 'Satellite Town',
        sector: '4B',
        city: 'Rawalpindi',
        depotId: 'depot-1',
        depotName: 'Warehouse Depot Hub 02',
        routeCount: 1,
        customerCount: 2,
        assignedRiderCount: 1,
      ),
    ];
  }

  @override
  Future<ZoneDetail> zoneDetail(String id) async {
    return const ZoneDetail(
      id: 'zone-1',
      name: 'Satellite Town',
      sector: '4B',
      city: 'Rawalpindi',
      depotId: 'depot-1',
      depotName: 'Warehouse Depot Hub 02',
      routeCount: 1,
      customerCount: 2,
      routes: [
        RouteListItem(
          id: 'route-1',
          name: 'Satellite Town – Route 03',
          zoneId: 'zone-1',
          zoneName: 'Satellite Town',
          customerCount: 2,
          stopCountToday: 2,
          hasRider: true,
          riders: [
            RouteRider(
              userId: 'rider-1',
              fullName: 'Ahmed Khan',
              riderCode: 'RDR-1042',
            ),
          ],
        ),
      ],
    );
  }

  @override
  Future<RouteDetail> routeDetail(String id) async {
    return const RouteDetail(
      id: 'route-1',
      name: 'Satellite Town – Route 03',
      zoneId: 'zone-1',
      zoneName: 'Satellite Town',
      customerCount: 2,
      customersWithGps: 1,
      stopCountToday: 2,
      riders: [
        RouteRider(
          userId: 'rider-1',
          fullName: 'Ahmed Khan',
          riderCode: 'RDR-1042',
        ),
      ],
      customers: [
        RouteCustomerRow(
          id: 'c1',
          code: 'CUS-1001',
          businessName: 'Ali General Store',
          routeSortOrder: 1,
          hasGps: true,
          outstanding: 2500,
          address: 'Shop 4, Satellite Town',
        ),
        RouteCustomerRow(
          id: 'c2',
          code: 'CUS-1002',
          businessName: 'City Mart',
          routeSortOrder: 2,
          outstanding: 0,
          address: 'Main Bazaar',
        ),
      ],
    );
  }

  @override
  Future<List<RouteStopRow>> routeStops(String routeId, {String? date}) async {
    return const [
      RouteStopRow(
        id: 's1',
        customerId: 'c1',
        customerCode: 'CUS-1001',
        customerName: 'Ali General Store',
        sequence: 1,
        status: 'Pending',
      ),
      RouteStopRow(
        id: 's2',
        customerId: 'c2',
        customerCode: 'CUS-1002',
        customerName: 'City Mart',
        sequence: 2,
        status: 'Pending',
      ),
    ];
  }

  @override
  Future<RouteMapData> routeMapPins(String routeId, {String? date}) async {
    // Empty pins avoid flutter_map tile HTTP during widget tests.
    return const RouteMapData(
      routeId: 'route-1',
      routeName: 'Satellite Town – Route 03',
      zoneName: 'Satellite Town',
      pins: [],
    );
  }

  @override
  Future<List<EligibleRouteRider>> eligibleRouteRiders({String? search}) async {
    return const [
      EligibleRouteRider(
        userId: 'rider-1',
        fullName: 'Ahmed Khan',
        riderCode: 'RDR-1042',
        currentRouteId: 'route-1',
        currentRouteName: 'Satellite Town – Route 03',
      ),
    ];
  }
}

void main() {
  testWidgets('zones and routes screen loads SQL-shaped summary and route detail', (
    tester,
  ) async {
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
        api: _ZonesMemoryApi(),
        child: MaterialApp(
          home: AdminWorkspace(
            session: admin,
            initialKey: AdminNav.zonesRoutes,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byKey(const Key('zones-routes-screen')), findsOneWidget);
    expect(find.text('Zones & Routes Management'), findsOneWidget);
    expect(find.text('Satellite Town'), findsWidgets);
    expect(find.textContaining('Ali General Store'), findsWidgets);
    expect(
      find.textContaining('No GPS pins are available for this route.'),
      findsOneWidget,
    );
  });
}
