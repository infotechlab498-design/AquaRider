import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riderfrontend/adminDashboard/presentation/admin_nav.dart';
import 'package:riderfrontend/adminDashboard/presentation/admin_routing.dart';
import 'package:riderfrontend/adminDashboard/presentation/admin_workspace.dart';
import 'package:riderfrontend/adminDashboard/presentation/screens/enterprise_login_screen.dart';
import 'package:riderfrontend/api/route_api.dart';

import 'memory_route_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'locked onboarding keeps six steps and drops the extra marketing task',
    () {
      final merged = mergeLockedSteps(const [
        OnboardingStep(
          code: 'profile',
          order: 1,
          title: 'Business Profile',
          summary: 'Legal name saved',
          status: OnboardingStepStatus.completed,
        ),
        OnboardingStep(
          code: 'branches',
          order: 2,
          title: 'Branches & Warehouses',
          summary: 'Hub created',
          status: OnboardingStepStatus.completed,
        ),
        OnboardingStep(
          code: 'products',
          order: 3,
          title: 'Products & Items',
          summary: 'Catalog open',
          status: OnboardingStepStatus.inProgress,
          recommended: true,
        ),
        OnboardingStep(
          code: 'zones',
          order: 4,
          title: 'Zones & Routes',
          summary: '',
          status: OnboardingStepStatus.notStarted,
        ),
        OnboardingStep(
          code: 'customers',
          order: 5,
          title: 'Customers',
          summary: '',
          status: OnboardingStepStatus.notStarted,
        ),
        OnboardingStep(
          code: 'team',
          order: 6,
          title: 'Team Members & Riders',
          summary: '',
          status: OnboardingStepStatus.notStarted,
        ),
        OnboardingStep(
          code: 'comms',
          order: 7,
          title: 'Communication Setup',
          summary: 'SMS',
          status: OnboardingStepStatus.notStarted,
        ),
      ]);

      expect(merged, hasLength(6));
      expect(merged.map((step) => step.title).toList(), [
        'Plant Details',
        'Items & Openings',
        'Customers',
        'Zones',
        'Rider & Load',
        'First Synced Sale',
      ]);
      expect(merged.first.status, OnboardingStepStatus.completed);
      expect(merged.first.summary, 'Legal name saved');
      expect(merged[1].status, OnboardingStepStatus.inProgress);
      expect(merged[1].recommended, isTrue);
      expect(merged.last.status, OnboardingStepStatus.unavailable);
      expect(
        merged.any((step) => step.title.contains('Communication')),
        isFalse,
      );
    },
  );

  test('a missing onboarding payload does not invent a percentage', () {
    expect(mergeLockedSteps(null), hasLength(6));
    expect(
      mergeLockedSteps(null)
          .every((step) => step.status == OnboardingStepStatus.unavailable),
      isTrue,
    );
    const progress = OnboardingProgress();
    expect(progress.displayPercent, isNull);
    const reported = OnboardingProgress(completed: 2, total: 6);
    expect(reported.displayPercent, 33);
  });

  test('admin sessions open the command dashboard and riders stay in the field app', () {
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
    const rider = AuthSession(
      accessToken: 'a',
      refreshToken: 'r',
      fullName: 'Ahmed Khan',
      username: 'ahmed.khan',
      riderCode: 'R-03',
      routeName: 'Zone',
      vehicleName: 'Van',
      vehiclePlate: 'A',
      fleetCode: 'F',
      depotGate: 'G',
      depotName: 'D',
    );
    expect(admin.isAdmin, isTrue);
    expect(isAdminRole(' Admin '), isTrue);
    final adminHome = homeForSession(admin);
    expect(adminHome, isA<AdminWorkspace>());
    expect((adminHome as AdminWorkspace).initialKey, AdminNav.dashboard);
    expect(rider.isAdmin, isFalse);
    expect(homeForSession(rider), isNot(isA<AdminWorkspace>()));
  });

  testWidgets(
    'enterprise login starts empty and does not fake single sign-on',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ApiScope(
          api: MemoryRouteApi(),
          child: const MaterialApp(home: EnterpriseLoginScreen()),
        ),
      );
      await tester.pumpAndSettle();

      final username = tester.widget<TextField>(
        find.byKey(const Key('admin-username-field')),
      );
      final password = tester.widget<TextField>(
        find.byKey(const Key('admin-password-field')),
      );
      expect(username.controller!.text, isEmpty);
      expect(password.controller!.text, isEmpty);
      expect(find.text('usama.admin@aquapure.pk'), findsNothing);
      expect(find.text('EnterprisePass2026#'), findsNothing);
      expect(find.text('Secured with AES-256 session storage'), findsOneWidget);
      expect(find.text('AES-256 Knox'), findsNothing);

      await tester.tap(find.byKey(const Key('admin-sso-button')));
      await tester.pumpAndSettle();
      expect(
        find.text('Corporate single sign-on is not available on this server.'),
        findsOneWidget,
      );
      expect(find.text('Welcome Back'), findsOneWidget);
    },
  );

  testWidgets(
    'an admin sign-in opens the command dashboard without invented totals',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ApiScope(
          api: MemoryRouteApi(),
          child: const MaterialApp(home: EnterpriseLoginScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('admin-username-field')),
        'usama.admin',
      );
      await tester.enterText(
        find.byKey(const Key('admin-password-field')),
        'admin-pass',
      );
      await tester.tap(find.byKey(const Key('admin-login-button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('business-overview-screen')), findsOneWidget);
      expect(find.byKey(const Key('admin-error-banner')), findsOneWidget);
      expect(find.text('Setup Checklist'), findsOneWidget);
      expect(find.text('Live Trackboard'), findsNothing);
      expect(find.text('Spot Billing Ledger'), findsNothing);
      expect(find.textContaining('LIVE RADAR'), findsNothing);
      expect(find.textContaining('185,000'), findsNothing);
      expect(find.textContaining('185000'), findsNothing);
      expect(find.text('PKR 185,000'), findsNothing);
      expect(find.text('Marcus Sterling'), findsNothing);
      expect(find.text('AquaPure Distributors'), findsNothing);
      expect(find.textContaining('Auto-Refresh'), findsNothing);
      expect(
        find.text('Enterprise System Ver 0.1.0 · Build 1'),
        findsOneWidget,
      );
    },
  );
}
