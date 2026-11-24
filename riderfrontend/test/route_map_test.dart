import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riderfrontend/api/field_store.dart';
import 'package:riderfrontend/api/route_api.dart';
import 'package:riderfrontend/screens/route_map_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'memory_route_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('route map shows live stats next stop and adapts to landscape', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = FieldStore(MemoryRouteApi());
    await store.loadHome();
    await store.loadStops();

    await tester.pumpWidget(
      ApiScope(
        api: store.api,
        child: FieldScope(
          store: store,
          child: const MaterialApp(home: Scaffold(body: RouteMapScreen())),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Route Map'), findsOneWidget);
    expect(find.textContaining('Stops Left'), findsOneWidget);
    expect(find.textContaining('Remaining'), findsWidgets);
    expect(find.textContaining('Est. Time'), findsOneWidget);
    expect(find.text('Open in Google Maps'), findsOneWidget);
    expect(find.text('Next Stop'), findsOneWidget);
    expect(find.byKey(const Key('route-map-layer')), findsOneWidget);
    expect(find.byKey(const Key('route-map-recenter')), findsOneWidget);

    tester.view.physicalSize = const Size(860, 420);
    await tester.pump();
    expect(find.byKey(const Key('route-map-screen')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
