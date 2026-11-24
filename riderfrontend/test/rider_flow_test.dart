import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riderfrontend/api/field_store.dart';
import 'package:riderfrontend/api/route_api.dart';
import 'package:riderfrontend/core/format.dart';
import 'package:riderfrontend/core/rider_store.dart';
import 'package:riderfrontend/screens/location_access.dart';
import 'package:riderfrontend/screens/login.dart';

import 'memory_route_api.dart';

import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    DeviceLocation.override = () async => true;
    SharedPreferences.setMockInitialValues({});
    final loader = FontLoader('Noto Sans');
    for (final name in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      loader.addFont(rootBundle.load('assets/fonts/NotoSans-$name.ttf'));
    }
    await loader.load();
  });

  tearDown(() {
    DeviceLocation.override = null;
  });

  test(
    'a saved entry stays on the phone until the server confirms it',
    () async {
      final store = await _store();
      store.draft.customer = store.customers.first;
      store.setFull(2);
      store.setEmpty(2);
      store.setMethod(PaymentMethod.cash);
      store.setAmount(300, touched: true);

      final first = store.saveDraft();
      final second = store.saveDraft();
      final saved = await first;
      expect(await second, isNull);
      expect(saved, isNotNull);
      expect(saved!.synced, isFalse);
      expect(saved.statusLabel, 'Saved');
      expect(store.entries, hasLength(1));
      expect(store.draft.customer, isNull);

      store.draft.customer = store.customers[1];
      store.setFull(3);
      store.setEmpty(2);
      store.setMethod(PaymentMethod.online);
      store.setProof('/tmp/proof.jpg');
      store.setAmount(450, touched: true);
      final online = await store.saveDraft();
      expect(online!.statusLabel, 'Awaiting Verification');
      expect(online.synced, isFalse);

      store.draft.customer = store.customers[2];
      store.setFull(1);
      store.setEmpty(1);
      store.setMethod(PaymentMethod.unpaid);
      final unpaid = await store.saveDraft();
      expect(unpaid!.statusLabel, 'Unpaid');
      expect(unpaid.amount, 0);

      expect(store.filtered(EntryFilter.cash), hasLength(1));
      expect(store.filtered(EntryFilter.online), hasLength(1));
      expect(store.filtered(EntryFilter.unpaid), hasLength(1));

      await store.confirmServerSync(saved.id);
      expect(
        store.entries.firstWhere((entry) => entry.id == saved.id).synced,
        isTrue,
      );

      final reloaded = await _store();
      expect(reloaded.entries, hasLength(3));
      expect(
        reloaded.entries.firstWhere((entry) => entry.id == saved.id).synced,
        isTrue,
      );
      expect(
        reloaded.entries.firstWhere((entry) => entry.id == online.id).synced,
        isFalse,
      );
    },
  );

  testWidgets('login blocks empty credentials and a wrong password', (
    tester,
  ) async {
    await _pumpLogin(tester);
    await tester.enterText(find.byKey(const Key('username-field')), '');
    await tester.enterText(find.byKey(const Key('password-field')), '');
    await tester.tap(find.byKey(const Key('login-button')));
    await tester.pump();
    expect(find.text('Enter your username and password.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('username-field')),
      'ahmed.khan',
    );
    await tester.enterText(find.byKey(const Key('password-field')), '0000');
    await tester.tap(find.byKey(const Key('login-button')));
    await tester.pumpAndSettle();
    expect(find.text('Incorrect username or password.'), findsOneWidget);
  });

  testWidgets('a rider can open a stop and record a sale', (tester) async {
    await _pumpLogin(tester);
    await tester.tap(find.byKey(const Key('login-button')));
    await tester.pumpAndSettle();

    expect(find.text('Enable Location Access'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('allow-location')),
      200,
    );
    await tester.tap(find.byKey(const Key('allow-location')));
    await tester.pumpAndSettle();
    expect(find.text('Good Morning, Ahmed'), findsOneWidget);

    await tester.tap(find.byKey(const Key('nav-todo')));
    await tester.pumpAndSettle();
    expect(find.text('Ali General Store'), findsWidgets);
    await tester.ensureVisible(find.byKey(const Key('stop-ali')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('stop-ali')));
    await tester.pumpAndSettle();
    expect(find.text('Customer Operations'), findsOneWidget);

    await tester.scrollUntilVisible(find.byKey(const Key('action-sale')), 200);
    await tester.tap(find.byKey(const Key('action-sale')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('continue-payment')));
    await tester.pumpAndSettle();
    expect(find.text('Payment Details'), findsOneWidget);

    await tester.tap(find.byKey(const Key('continue-signature')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-signature')));
    await tester.pumpAndSettle();
    expect(find.text('Transaction Recorded'), findsOneWidget);
  });
}

Future<RiderStore> _store() async {
  final store = RiderStore(
    authDelay: Duration.zero,
    customerLoadDelay: Duration.zero,
  );
  await store.init();
  return store;
}

Future<void> _pumpLogin(WidgetTester tester) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final store = await _store();
  final api = MemoryRouteApi();
  await tester.pumpWidget(
    ApiScope(
      api: api,
      child: FieldScope(
        store: FieldStore(api),
        child: RiderScope(
          store: store,
          child: const MaterialApp(home: LoginScreen()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
