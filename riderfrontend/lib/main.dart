import 'package:flutter/material.dart';

import 'api/field_store.dart';
import 'api/route_api.dart';
import 'core/rider_store.dart';
import 'core/theme.dart';
import 'screens/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = RiderStore();
  await store.init();
  final api = HttpRouteApi();
  await api.restore();
  runApp(AquaRiderApp(store: store, api: api));
}

class AquaRiderApp extends StatelessWidget {
  AquaRiderApp({required this.store, required this.api, super.key})
    : field = FieldStore(api);

  final RiderStore store;
  final RouteApi api;
  final FieldStore field;

  @override
  Widget build(BuildContext context) {
    return ApiScope(
      api: api,
      child: FieldScope(
        store: field,
        child: RiderScope(
          store: store,
          child: MaterialApp(
            title: 'RouteLedger',
            debugShowCheckedModeBanner: false,
            theme: buildAquaTheme(),
            home: const SplashScreen(),
          ),
        ),
      ),
    );
  }
}
