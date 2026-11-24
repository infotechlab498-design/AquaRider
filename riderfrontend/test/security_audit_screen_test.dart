import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riderfrontend/adminDashboard/presentation/screens/security_audit_screen.dart';
import 'package:riderfrontend/api/route_api.dart';

import 'memory_route_api.dart';

void main() {
  testWidgets('audit log page renders when the trail is unavailable', (tester) async {
    tester.view.physicalSize = const Size(1440, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ApiScope(
        api: MemoryRouteApi(),
        child: const MaterialApp(home: SecurityAuditScreen(onNavigate: _ignore)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('security-audit-screen')), findsOneWidget);
    expect(find.text('Security & Operations Audit Trail'), findsOneWidget);
    expect(find.text(MemoryRouteApi.auditUnavailable), findsWidgets);
  });
}

void _ignore(String _) {}
