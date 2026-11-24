import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riderfrontend/api/route_api.dart';
import 'package:riderfrontend/customerApp/account_type_screen.dart';
import 'package:riderfrontend/customerApp/customer_registration_screen.dart';

import 'memory_route_api.dart';

void main() {
  testWidgets('account type opens customer registration or rider login', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ApiScope(
        api: MemoryRouteApi(),
        child: const MaterialApp(home: AccountTypeSelectionScreen()),
      ),
    );
    expect(find.byKey(const Key('account-type-screen')), findsOneWidget);
    expect(find.text("I'm a Customer"), findsOneWidget);
    expect(find.text("I'm a Rider"), findsOneWidget);

    await tester.tap(find.byKey(const Key('account-type-customer')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('customer-registration-screen')), findsOneWidget);
    expect(find.text('Create Your Customer Account'), findsOneWidget);

    await tester.tap(find.byKey(const Key('customer-registration-back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('account-type-screen')), findsOneWidget);

    await tester.tap(find.byKey(const Key('account-type-rider')));
    await tester.pumpAndSettle();
    expect(find.text('ahmed.khan'), findsOneWidget);
  });

  testWidgets('customer registration keeps entered details and shows the server id', (tester) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final api = MemoryRouteApi();
    await tester.pumpWidget(
      ApiScope(
        api: api,
        child: const MaterialApp(home: CustomerRegistrationScreen()),
      ),
    );

    final submit = find.byKey(const Key('customer-register-submit'));
    final list = find.descendant(
      of: find.byKey(const Key('customer-registration-list')),
      matching: find.byType(Scrollable),
    ).first;
    Future<void> reveal(Finder target) async {
      await tester.scrollUntilVisible(target, 400, scrollable: list);
    }

    await reveal(submit);
    await tester.tap(submit);
    await tester.pump();
    expect(find.text('First name is required.'), findsOneWidget);
    expect(api.lastCustomerRegistration, isNull);

    await tester.enterText(find.byKey(const Key('customer-first')), 'Ayesha');
    await tester.enterText(find.byKey(const Key('customer-last')), 'Khan');
    await tester.enterText(find.byKey(const Key('customer-phone')), '03001234567');
    await tester.enterText(find.byKey(const Key('customer-email')), 'taken@example.com');
    await tester.enterText(find.byKey(const Key('customer-city')), 'Rawalpindi');
    await tester.enterText(find.byKey(const Key('customer-area')), 'Chaklala');
    await tester.enterText(find.byKey(const Key('customer-street')), 'Lane 7');
    await tester.enterText(find.byKey(const Key('customer-house')), '18');
    await tester.enterText(find.byKey(const Key('customer-password')), 'routeledger1');
    await tester.enterText(find.byKey(const Key('customer-confirm')), 'routeledger1');
    await reveal(find.byKey(const Key('customer-terms')));
    await tester.tap(find.byKey(const Key('customer-terms')));
    await tester.pump();
    await reveal(submit);
    await tester.tap(submit);
    await tester.pump();
    expect(find.text('An account with this email already exists.'), findsWidgets);
    expect(find.text('Ayesha'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('customer-email')), 'ayesha@example.com');
    await reveal(submit);
    await tester.tap(submit);
    await tester.pump();
    expect(find.byKey(const Key('customer-registration-success')), findsOneWidget);
    expect(find.text('Customer ID: CUS-000001'), findsOneWidget);
    expect(api.lastCustomerRegistration?['acceptedTerms'], true);
    expect(api.lastCustomerRegistration?['password'], 'routeledger1');
  });
}
