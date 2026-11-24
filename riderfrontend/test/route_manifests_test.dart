import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riderfrontend/adminDashboard/presentation/screens/route_manifests_screen.dart';
import 'package:riderfrontend/api/route_api.dart';

import 'memory_route_api.dart';

void main() {
  testWidgets('route manifests uses the saved route and its stops', (tester) async {
    tester.view.physicalSize = const Size(1440, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final api = _ManifestApi();
    await tester.pumpWidget(
      ApiScope(
        api: api,
        child: const MaterialApp(home: RouteManifestsScreen(onNavigate: _ignore)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('route-manifests-screen')), findsOneWidget);
    expect(find.text('Chaklala - Route 01'), findsOneWidget);
    expect(find.text('Ali General Store'), findsOneWidget);
    expect(find.text('No stops were returned for this date.'), findsNothing);
    expect(find.textContaining('Rawalpindi'), findsNothing);

    await tester.tap(find.byKey(const Key('route-manifests-down-s1')));
    await tester.pumpAndSettle();
    expect(api.lastOrder, ['s2', 's1']);

    await tester.tap(find.byKey(const Key('route-manifests-print')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      find.text('The manifest PDF could not be created.'),
      findsOneWidget,
    );
  });
}

void _ignore(String _) {}

class _ManifestApi extends MemoryRouteApi {
  List<String>? lastOrder;
  var _stops = const [
    RouteStopRow(
      id: 's1',
      customerId: 'c1',
      customerCode: 'C-1',
      customerName: 'Ali General Store',
      address: 'Street 4',
      sequence: 1,
      status: 'Pending',
    ),
    RouteStopRow(
      id: 's2',
      customerId: 'c2',
      customerCode: 'C-2',
      customerName: 'Hassan Super',
      address: 'Street 9',
      sequence: 2,
      status: 'Pending',
    ),
  ];

  @override
  Future<List<RouteListItem>> listRoutes({String? zoneId, String? search}) async => const [
    RouteListItem(
      id: 'r1',
      name: 'Chaklala - Route 01',
      zoneName: 'Chaklala',
      depotName: 'Warehouse Depot Hub 02',
      customerCount: 2,
      stopCountToday: 2,
      hasRider: true,
      riders: [
        RouteRider(userId: 'u1', fullName: 'Infotech Lab', riderCode: 'RDR-1043'),
      ],
    ),
  ];

  @override
  Future<List<RouteStopRow>> routeStops(String routeId, {String? date}) async => _stops;

  @override
  Future<List<RouteStopRow>> sequenceRouteStops(
    String routeId, {
    required List<String> orderedStopIds,
  }) async {
    lastOrder = orderedStopIds;
    _stops = [
      for (var i = 0; i < orderedStopIds.length; i++)
        RouteStopRow(
          id: orderedStopIds[i],
          customerId: orderedStopIds[i],
          customerCode: orderedStopIds[i],
          customerName: orderedStopIds[i] == 's1' ? 'Ali General Store' : 'Hassan Super',
          sequence: i + 1,
        ),
    ];
    return _stops;
  }
}
