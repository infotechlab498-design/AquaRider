import 'package:flutter/material.dart';

import '../../api/route_api.dart';
import '../theme/admin_tokens.dart';
import 'admin_nav.dart';
import 'screens/admin_unavailable_screen.dart';
import 'screens/base_pricing_screen.dart';
import 'screens/business_overview_screen.dart';
import 'screens/day_close_screen.dart';
import 'screens/dispatch_orders_screen.dart';
import 'screens/onboarding_checklist_screen.dart';
import 'screens/rider_operations_screen.dart';
import 'screens/customers_directory_screen.dart';
import 'screens/customer_accounts_screen.dart';
import 'screens/collections_management_screen.dart';
import 'screens/communication_engine_screen.dart';
import 'screens/recurring_schedules_screen.dart';
import 'screens/reports_analytics_screen.dart';
import 'screens/route_manifests_screen.dart';
import 'screens/sales_management_screen.dart';
import 'screens/security_audit_screen.dart';
import 'screens/shift_records_screen.dart';
import 'screens/roles_permissions_screen.dart';
import 'screens/warehouse_screen.dart';
import 'screens/hq_settings_screen.dart';
import 'screens/live_trackboard_screen.dart';
import 'screens/zones_routes_screen.dart';

class AdminWorkspace extends StatefulWidget {
  const AdminWorkspace({
    required this.session,
    this.initialKey = AdminNav.dashboard,
    super.key,
  });

  final AuthSession? session;
  final String initialKey;

  @override
  State<AdminWorkspace> createState() => _AdminWorkspaceState();
}

class _AdminWorkspaceState extends State<AdminWorkspace> {
  late String _key = widget.initialKey;

  void _open(String key) {
    if (key == _key) return;
    final session = widget.session;
    if (session != null && !session.allowsScreen(key)) {
      showAdminNotice(context, 'This role cannot open that screen.');
      return;
    }
    setState(() => _key = key);
  }

  @override
  Widget build(BuildContext context) {
    return switch (_key) {
      AdminNav.checklist => OnboardingChecklistScreen(
        session: widget.session,
        onNavigate: _open,
      ),
      AdminNav.fleet => RiderOperationsScreen(
        session: widget.session,
        onNavigate: _open,
      ),
      AdminNav.liveTrackboard => LiveTrackboardScreen(
        session: widget.session,
        onNavigate: _open,
      ),
      AdminNav.dispatch => DispatchOrdersScreen(
        session: widget.session,
        onNavigate: _open,
      ),
      AdminNav.recurringSchedules => RecurringSchedulesScreen(
        session: widget.session,
        onNavigate: _open,
      ),
      AdminNav.shiftRecords => ShiftRecordsScreen(
        session: widget.session,
        onNavigate: _open,
      ),
      AdminNav.dayClose => DayCloseScreen(
        session: widget.session,
        onNavigate: _open,
      ),
      AdminNav.salesManagement => SalesManagementScreen(
        session: widget.session,
        onNavigate: _open,
      ),
      AdminNav.collectionsManagement => CollectionsManagementScreen(
        session: widget.session,
        onNavigate: _open,
      ),
      AdminNav.reportsAnalytics => ReportsAnalyticsScreen(
        session: widget.session,
        onNavigate: _open,
      ),
      AdminNav.communication => CommunicationEngineScreen(
        session: widget.session,
        onNavigate: _open,
      ),
      AdminNav.securityAudit => SecurityAuditScreen(
        session: widget.session,
        onNavigate: _open,
      ),
      AdminNav.basePricing => BasePricingScreen(
        session: widget.session,
        onNavigate: _open,
      ),
      AdminNav.zonesRoutes => ZonesRoutesScreen(
        session: widget.session,
        onNavigate: _open,
      ),
      AdminNav.branchesWarehouses => WarehouseScreen(
        session: widget.session,
        onNavigate: _open,
      ),
      AdminNav.customersParties => CustomersDirectoryScreen(
        session: widget.session,
        onNavigate: _open,
      ),
      AdminNav.customerAccounts => CustomerAccountsScreen(
        session: widget.session,
        onNavigate: _open,
      ),
      AdminNav.usersStaff => RolesPermissionsScreen(
        session: widget.session,
        onNavigate: _open,
      ),
      AdminNav.manifests => RouteManifestsScreen(
        session: widget.session,
        onNavigate: _open,
      ),
      AdminNav.settings => HqSettingsScreen(
        key: ValueKey(_key),
        session: widget.session,
        onNavigate: _open,
      ),
      AdminNav.audits => AdminUnavailableScreen(
        key: ValueKey(_key),
        session: widget.session,
        activeKey: _key,
        onNavigate: _open,
      ),
      _ => BusinessOverviewScreen(session: widget.session, onNavigate: _open),
    };
  }
}
