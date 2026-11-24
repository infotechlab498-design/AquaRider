import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riderfrontend/api/field_store.dart';
import 'package:riderfrontend/api/route_api.dart';
import 'package:riderfrontend/screens/field_screens.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'memory_route_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('rider settings shows the signed-in rider and keeps account actions', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = FieldStore(MemoryRouteApi());
    await tester.pumpWidget(
      ApiScope(
        api: store.api,
        child: FieldScope(
          store: store,
          child: const MaterialApp(home: SettingsScreen()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Settings & Profile'), findsOneWidget);
    expect(find.text('Ahmed Khan'), findsOneWidget);
    expect(find.text('RDR-1042'), findsOneWidget);
    expect(find.text('Delivery Rider • Satellite Town – Route 03'), findsOneWidget);
    expect(find.text('12 Stops Completed Today'), findsOneWidget);
    expect(find.text('Signed in'), findsOneWidget);
    expect(find.text('Not Connected'), findsOneWidget);
    expect(find.text('Auto Sync'), findsOneWidget);
    expect(find.text('Print Test Receipt'), findsOneWidget);

    await tester.tap(find.byKey(const Key('settings-edit')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Sign out'), findsOneWidget);
    expect(find.text('Change password'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());

    tester.view.physicalSize = const Size(800, 420);
    await tester.pumpWidget(
      ApiScope(
        api: store.api,
        child: FieldScope(
          store: store,
          child: const MaterialApp(home: SettingsScreen()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Settings & Profile'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
