import 'package:flutter/material.dart';

import '../../theme/admin_tokens.dart';
import '../admin_nav.dart';

class AdminSidebar extends StatefulWidget {
  const AdminSidebar({
    required this.serverReachable,
    required this.activeKey,
    required this.onNavigate,
    this.allowedScreens,
    super.key,
  });

  final bool serverReachable;
  final String activeKey;
  final ValueChanged<String> onNavigate;
  final Set<String>? allowedScreens;

  @override
  State<AdminSidebar> createState() => _AdminSidebarState();
}

class _AdminSidebarState extends State<AdminSidebar> {
  final _scroll = ScrollController();

  List<_NavSpec> _visible(List<_NavSpec> items) {
    final allowed = widget.allowedScreens;
    if (allowed == null) return items;
    return [for (final item in items) if (allowed.contains(item.navKey)) item];
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AdminTokens.sidebar,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AdminTokens.button,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.alt_route,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'RouteLedger',
                    style: adminType(
                      16,
                      FontWeight.w700,
                      Colors.white,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Expanded(
                child: Scrollbar(
                  controller: _scroll,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _scroll,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _SectionLabel('OPERATIONS FLEET'),
                        for (final item in _operations)
                          _NavTile(
                            item: item,
                            active: item.navKey == widget.activeKey,
                            onTap: () => widget.onNavigate(item.navKey),
                          ),
                        const SizedBox(height: 16),
                        const _SectionLabel('ADMINISTRATION'),
                        for (final item in _visible(_administration))
                          _NavTile(
                            item: item,
                            active: item.navKey == widget.activeKey,
                            onTap: () => widget.onNavigate(item.navKey),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: widget.serverReachable
                          ? const Color(0xFF4ADE80)
                          : AdminTokens.error,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.serverReachable
                          ? 'Server reachable'
                          : 'Server unreachable',
                      style: adminType(
                        12,
                        FontWeight.w500,
                        AdminTokens.sidebarMuted,
                        height: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavSpec {
  const _NavSpec(this.navKey, this.icon, this.label);

  final String navKey;
  final IconData icon;
  final String label;
}

const _operations = <_NavSpec>[
  _NavSpec(
    AdminNav.dashboard,
    Icons.space_dashboard_outlined,
    'Admin Dashboard',
  ),
  _NavSpec(
    AdminNav.liveTrackboard,
    Icons.radar_outlined,
    'Live Trackboard',
  ),
  _NavSpec(
    AdminNav.dispatch,
    Icons.assignment_outlined,
    'Dispatch & Orders',
  ),
  _NavSpec(
    AdminNav.recurringSchedules,
    Icons.event_repeat_outlined,
    'Recurring Schedules',
  ),
  _NavSpec(
    AdminNav.dayClose,
    Icons.account_balance_wallet_outlined,
    'Day Close & Recon',
  ),
  _NavSpec(
    AdminNav.shiftRecords,
    Icons.fact_check_outlined,
    'Shift Records',
  ),
  _NavSpec(
    AdminNav.salesManagement,
    Icons.receipt_long_outlined,
    'Sales',
  ),
  _NavSpec(
    AdminNav.collectionsManagement,
    Icons.payments_outlined,
    'Collections',
  ),
  _NavSpec(AdminNav.manifests, Icons.alt_route, 'Route Manifests'),
  _NavSpec(AdminNav.audits, Icons.inventory_2_outlined, 'Inventory Audits'),
];

const _administration = <_NavSpec>[
  _NavSpec(AdminNav.checklist, Icons.fact_check_outlined, 'Setup Checklist'),
  _NavSpec(AdminNav.fleet, Icons.local_shipping_outlined, 'Fleet Couriers'),
  _NavSpec(
    AdminNav.basePricing,
    Icons.sell_outlined,
    'Products & Base Pricing',
  ),
  _NavSpec(
    AdminNav.zonesRoutes,
    Icons.map_outlined,
    'Zones & Routes',
  ),
  _NavSpec(
    AdminNav.branchesWarehouses,
    Icons.warehouse_outlined,
    'Branches & Warehouses',
  ),
  _NavSpec(
    AdminNav.customersParties,
    Icons.storefront_outlined,
    'Customers & Parties',
  ),
  _NavSpec(
    AdminNav.customerAccounts,
    Icons.person_outline,
    'Customer Accounts',
  ),
  _NavSpec(
    AdminNav.usersStaff,
    Icons.badge_outlined,
    'Roles & Permissions',
  ),
  _NavSpec(
    AdminNav.reportsAnalytics,
    Icons.insights_outlined,
    'Reports & Analytics',
  ),
  _NavSpec(
    AdminNav.communication,
    Icons.sms_outlined,
    'Communication',
  ),
  _NavSpec(
    AdminNav.securityAudit,
    Icons.policy_outlined,
    'Audit Log',
  ),
  _NavSpec(AdminNav.settings, Icons.settings_outlined, 'HQ Settings'),
];

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 8, 8),
      child: Text(
        text,
        style: adminType(
          11,
          FontWeight.w700,
          AdminTokens.sidebarMuted,
          height: 1.2,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.item,
    required this.active,
    required this.onTap,
  });

  final _NavSpec item;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? Colors.white : const Color(0xFFD5DEE8);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: active ? AdminTokens.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          key: Key('admin-nav-${item.navKey}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              children: [
                Icon(item.icon, size: 18, color: color),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.label,
                    style: adminType(13.5, FontWeight.w600, color, height: 1.2),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
