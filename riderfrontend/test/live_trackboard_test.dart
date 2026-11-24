import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riderfrontend/adminDashboard/presentation/admin_nav.dart';
import 'package:riderfrontend/adminDashboard/presentation/screens/live_trackboard_screen.dart';
import 'package:riderfrontend/api/route_api.dart';

import 'memory_route_api.dart';

void main() {
  testWidgets('Live Trackboard loads empty fleet KPIs', (tester) async {
    await tester.pumpWidget(
      ApiScope(
        api: MemoryRouteApi(),
        child: MaterialApp(
          home: LiveTrackboardScreen(onNavigate: (_) {}),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const Key('live-trackboard-screen')), findsOneWidget);
    expect(find.text('Riders on Duty'), findsOneWidget);
    expect(find.textContaining('0 Active'), findsWidgets);
    expect(find.text('Every 1 min'), findsWidgets);
    expect(AdminNav.liveTrackboard, 'liveTrackboard');
  });

  testWidgets('location fetch interval can be a preset or a custom time', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ApiScope(
        api: MemoryRouteApi(),
        child: MaterialApp(
          home: LiveTrackboardScreen(onNavigate: (_) {}),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.byKey(const Key('live-track-fetch')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const Key('live-track-fetch-600')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Every 10 min'), findsWidgets);
    expect(find.byKey(const Key('live-track-fetch-600')), findsNothing);

    await tester.tap(find.byKey(const Key('live-track-fetch')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const Key('live-track-fetch-custom')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Custom location fetch'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('live-track-fetch-amount')), '2');
    await tester.tap(find.byKey(const Key('live-track-fetch-save')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Every 2 min'), findsOneWidget);
    expect(find.text('Custom location fetch'), findsNothing);
  });
}
