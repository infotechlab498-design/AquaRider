import 'package:flutter/material.dart';

import 'api/field_store.dart';
import 'api/route_api.dart';
import 'adminDashboard/presentation/screens/enterprise_login_screen.dart';
import 'adminDashboard/theme/admin_tokens.dart';
import 'core/rider_store.dart';

/// Chrome / desktop entry for the RouteLedger admin HQ dashboard only.
/// Rider field UI stays on [main.dart] (Android emulator / phone).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = RiderStore();
  await store.init();
  final api = HttpRouteApi();
  await api.restore();
  runApp(RouteLedgerAdminApp(store: store, api: api));
}

class RouteLedgerAdminApp extends StatelessWidget {
  RouteLedgerAdminApp({required this.store, required this.api, super.key})
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
            title: 'RouteLedger Admin',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: AdminTokens.primary,
                primary: AdminTokens.primary,
                secondary: AdminTokens.secondary,
                surface: AdminTokens.surface,
                error: AdminTokens.error,
              ),
              scaffoldBackgroundColor: AdminTokens.background,
              fontFamily: 'Noto Sans',
            ),
            home: const EnterpriseLoginScreen(),
          ),
        ),
      ),
    );
  }
}
