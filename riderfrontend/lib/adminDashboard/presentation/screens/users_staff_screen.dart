import 'dart:async';

import 'package:flutter/material.dart';

import 'package:riderfrontend/adminDashboard/data/admin_format.dart';
import 'package:riderfrontend/adminDashboard/presentation/admin_load.dart';
import 'package:riderfrontend/adminDashboard/presentation/admin_nav.dart';
import 'package:riderfrontend/adminDashboard/presentation/widgets/admin_shell.dart';
import 'package:riderfrontend/adminDashboard/theme/admin_tokens.dart';
import 'package:riderfrontend/api/route_api.dart';

class UsersStaffScreen extends StatefulWidget {
  const UsersStaffScreen({required this.onNavigate, this.session, super.key});

  final AuthSession? session;
  final ValueChanged<String> onNavigate;

  @override
  State<UsersStaffScreen> createState() => _UsersStaffScreenState();
}

class _UsersStaffScreenState extends State<UsersStaffScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  var _started = false;
  var _loading = true;
  var _page = 1;
  var _role = 'all';
  bool? _activeFilter;
  String? _selectedId;

  AdminLoad<StaffSummary>? _summary;
  AdminLoad<List<RoleReference>>? _roles;
  AdminLoad<StaffUserPage>? _pageData;
  AdminLoad<StaffUser>? _detail;
  AdminLoad<List<RouteListItem>>? _routes;

  @override
  void initState() {
    super.initState();
    _search.addListener(_scheduleSearch);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _reload();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _scheduleSearch() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() => _page = 1);
      _reload();
    });
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final api = ApiScope.of(context);
    final summary = await guardAdminLoad(api.staffSummary);
    final roles = await guardAdminLoad(api.staffRoleReference);
    final routes = await guardAdminLoad(() => api.listRoutes());
    final page = await guardAdminLoad(
      () => api.staffUsers(
        search: _search.text.trim().isEmpty ? null : _search.text.trim(),
        role: _role == 'all' ? null : _role,
        isActive: _activeFilter,
        page: _page,
        pageSize: 20,
      ),
    );
    if (!mounted) return;
    final rows = page.value?.rows ?? const <StaffUser>[];
    var selected = _selectedId;
    if (selected == null || !rows.any((item) => item.id == selected)) {
      selected = rows.isEmpty ? null : rows.first.id;
    }
    AdminLoad<StaffUser>? detail;
    if (selected != null) {
      detail = await guardAdminLoad(() => api.staffUser(selected!));
    }
    if (!mounted) return;
    setState(() {
      _summary = summary;
      _roles = roles;
      _routes = routes;
      _pageData = page;
      _selectedId = selected;
      _detail = detail;
      _loading = false;
    });
  }

  Future<void> _select(String id) async {
    setState(() => _selectedId = id);
    final detail = await guardAdminLoad(
      () => ApiScope.of(context).staffUser(id),
    );
    if (!mounted) return;
    setState(() => _detail = detail);
  }

  Future<void> _setActive(bool isActive) async {
    final id = _selectedId;
    if (id == null) return;
    try {
      final api = ApiScope.of(context);
      await api.setStaffUserStatus(id, isActive: isActive);
      if (!mounted) return;
      showAdminNotice(
        context,
        isActive ? 'User activated.' : 'User deactivated.',
      );
      await _reload();
    } on ApiException catch (error) {
      if (mounted) showAdminNotice(context, error.message);
    }
  }

  Future<void> _resetPassword() async {
    final id = _selectedId;
    if (id == null) return;
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset password'),
        content: TextField(
          controller: controller,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'New password (min 8, include a digit)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    final password = controller.text;
    controller.dispose();
    if (ok != true || !mounted) return;
    try {
      await ApiScope.of(context).resetStaffUserPassword(
        id,
        newPassword: password,
      );
      if (!mounted) return;
      showAdminNotice(context, 'Password reset. Active sessions were revoked.');
    } on ApiException catch (error) {
      if (mounted) showAdminNotice(context, error.message);
    }
  }

  Future<void> _createUser() async {
    final routes = _routes?.value ?? const <RouteListItem>[];
    final username = TextEditingController();
    final password = TextEditingController();
    final fullName = TextEditingController();
    final phone = TextEditingController();
    final riderCode = TextEditingController();
    var role = 'Rider';
    String? routeId = routes.isEmpty ? null : routes.first.id;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Add staff user'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: username,
                    decoration: const InputDecoration(labelText: 'Username'),
                  ),
                  TextField(
                    controller: password,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Password'),
                  ),
                  TextField(
                    controller: fullName,
                    decoration: const InputDecoration(labelText: 'Full name'),
                  ),
                  TextField(
                    controller: phone,
                    decoration: const InputDecoration(labelText: 'Phone'),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: role,
                    decoration: const InputDecoration(labelText: 'Role'),
                    items: const [
                      DropdownMenuItem(value: 'Admin', child: Text('Admin')),
                      DropdownMenuItem(value: 'Rider', child: Text('Rider')),
                    ],
                    onChanged: (value) => setLocal(() => role = value ?? role),
                  ),
                  if (role == 'Rider') ...[
                    TextField(
                      controller: riderCode,
                      decoration: const InputDecoration(
                        labelText: 'Rider code',
                      ),
                    ),
                    if (routes.isNotEmpty)
                      DropdownButtonFormField<String>(
                        initialValue: routeId,
                        decoration: const InputDecoration(labelText: 'Route'),
                        items: [
                          for (final route in routes)
                            DropdownMenuItem(
                              value: route.id,
                              child: Text(route.name),
                            ),
                        ],
                        onChanged: (value) =>
                            setLocal(() => routeId = value ?? routeId),
                      ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
    final payload = (
      username.text.trim(),
      password.text,
      fullName.text.trim(),
      phone.text.trim(),
      riderCode.text.trim(),
      role,
      routeId,
    );
    username.dispose();
    password.dispose();
    fullName.dispose();
    phone.dispose();
    riderCode.dispose();
    if (ok != true || !mounted) return;
    if (payload.$1.isEmpty || payload.$2.isEmpty || payload.$3.isEmpty) {
      showAdminNotice(context, 'Username, password, and full name are required.');
      return;
    }
    try {
      final created = await ApiScope.of(context).createStaffUser(
        username: payload.$1,
        password: payload.$2,
        fullName: payload.$3,
        phone: payload.$4.isEmpty ? null : payload.$4,
        riderCode: payload.$5.isEmpty ? null : payload.$5,
        role: payload.$6,
        routeId: payload.$6 == 'Rider' ? payload.$7 : null,
      );
      if (!mounted) return;
      setState(() => _selectedId = created.id);
      showAdminNotice(context, 'User created.');
      await _reload();
    } on ApiException catch (error) {
      if (mounted) showAdminNotice(context, error.message);
    }
  }

  Future<void> _reassignRoute() async {
    final detail = _detail?.value;
    final routes = _routes?.value ?? const <RouteListItem>[];
    if (detail == null || !detail.isRider || routes.isEmpty) return;
    final chosen = await showDialog<RouteListItem>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Assign route'),
        children: [
          for (final route in routes)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, route),
              child: Text(route.name),
            ),
        ],
      ),
    );
    if (chosen == null || !mounted) return;
    try {
      await ApiScope.of(context).updateStaffUser(
        detail.id,
        fullName: detail.fullName,
        phone: detail.phone,
        riderCode: detail.riderCode,
        routeId: chosen.id,
        vehicleId: detail.vehicleId,
        depotId: detail.depotId,
      );
      if (!mounted) return;
      showAdminNotice(context, 'Route assignment updated.');
      await _reload();
    } on ApiException catch (error) {
      if (mounted) showAdminNotice(context, error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loads = <AdminLoad<dynamic>>[?_summary, ?_pageData, ?_detail];
    final summary = _summary?.value;
    final page = _pageData?.value;
    final detail = _detail?.value;
    final roles = _roles?.value ?? const <RoleReference>[];

    return AdminShell(
      screenKey: const Key('users-staff-screen'),
      session: widget.session,
      activeKey: AdminNav.usersStaff,
      serverReachable: adminServerReachable(loads),
      search: _search,
      onSearch: (_) {},
      searchHint: 'Search name, username, rider code, phone',
      onNavigate: widget.onNavigate,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton.icon(
            onPressed: _loading ? null : _createUser,
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text('Add user'),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _reload,
            icon: const Icon(Icons.refresh, color: AdminTokens.secondary),
          ),
        ],
      ),
      body: _loading && _summary == null
          ? const AdminLoadingPane(label: 'Loading users & staff…')
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
              children: [
                Text(
                  'Team Management  ›  Users & Staff',
                  style: adminType(
                    12,
                    FontWeight.w600,
                    AdminTokens.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Users & Staff Management',
                  style: adminType(
                    28,
                    FontWeight.w700,
                    AdminTokens.text,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Manage Admin and Rider accounts on ASP.NET Identity. No custom RBAC roles.',
                  style: adminType(
                    14,
                    FontWeight.w500,
                    AdminTokens.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _Kpi('Total staff', '${summary?.totalStaff ?? 0}', 'All accounts'),
                    _Kpi('Active', '${summary?.activeUsers ?? 0}', 'Can sign in'),
                    _Kpi('Riders', '${summary?.activeRiders ?? 0}', 'Field couriers'),
                    _Kpi('Admins', '${summary?.admins ?? 0}', 'HQ operators'),
                    _Kpi(
                      'Inactive',
                      '${summary?.inactiveUsers ?? 0}',
                      'Suspended access',
                    ),
                    _Kpi(
                      'Logged in today',
                      '${summary?.loggedInToday ?? 0}',
                      'UTC calendar day',
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final role in roles)
                      Container(
                        width: 280,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AdminTokens.primarySoft,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AdminTokens.line),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${role.title} (${role.assignedCount})',
                              style: adminType(
                                13,
                                FontWeight.w700,
                                AdminTokens.text,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              role.description,
                              style: adminType(
                                11,
                                FontWeight.w500,
                                AdminTokens.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    DropdownButton<String>(
                      value: _role,
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('All roles')),
                        DropdownMenuItem(value: 'Admin', child: Text('Admins')),
                        DropdownMenuItem(value: 'Rider', child: Text('Riders')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _role = value ?? 'all';
                          _page = 1;
                        });
                        _reload();
                      },
                    ),
                    DropdownButton<String>(
                      value: _activeFilter == null
                          ? 'all'
                          : (_activeFilter! ? 'active' : 'inactive'),
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('All statuses')),
                        DropdownMenuItem(value: 'active', child: Text('Active')),
                        DropdownMenuItem(
                          value: 'inactive',
                          child: Text('Inactive'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _activeFilter = value == 'all'
                              ? null
                              : value == 'active';
                          _page = 1;
                        });
                        _reload();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 1100;
                    final table = _StaffTable(
                      rows: page?.rows ?? const [],
                      selectedId: _selectedId,
                      onSelect: _select,
                      page: page?.page ?? 1,
                      totalPages: page?.totalPages ?? 1,
                      totalRecords: page?.totalRecords ?? 0,
                      onPrev: _page <= 1
                          ? null
                          : () {
                              setState(() => _page -= 1);
                              _reload();
                            },
                      onNext: page == null || _page >= page.totalPages
                          ? null
                          : () {
                              setState(() => _page += 1);
                              _reload();
                            },
                    );
                    final drawer = _StaffDrawer(
                      detail: detail,
                      onActivate: () => _setActive(true),
                      onDeactivate: () => _setActive(false),
                      onResetPassword: _resetPassword,
                      onAssignRoute: _reassignRoute,
                      onOpenFleet: () => widget.onNavigate(AdminNav.fleet),
                    );
                    if (wide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 3, child: table),
                          const SizedBox(width: 14),
                          Expanded(flex: 2, child: drawer),
                        ],
                      );
                    }
                    return Column(
                      children: [
                        table,
                        const SizedBox(height: 14),
                        drawer,
                      ],
                    );
                  },
                ),
              ],
            ),
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi(this.label, this.value, this.hint);

  final String label;
  final String value;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AdminTokens.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminTokens.line),
        boxShadow: AdminTokens.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: adminType(12, FontWeight.w600, AdminTokens.textSecondary),
          ),
          const SizedBox(height: 6),
          Text(value, style: adminType(20, FontWeight.w700, AdminTokens.text)),
          const SizedBox(height: 4),
          Text(
            hint,
            style: adminType(11, FontWeight.w500, AdminTokens.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _StaffTable extends StatelessWidget {
  const _StaffTable({
    required this.rows,
    required this.selectedId,
    required this.onSelect,
    required this.page,
    required this.totalPages,
    required this.totalRecords,
    required this.onPrev,
    required this.onNext,
  });

  final List<StaffUser> rows;
  final String? selectedId;
  final ValueChanged<String> onSelect;
  final int page;
  final int totalPages;
  final int totalRecords;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AdminTokens.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminTokens.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Staff directory',
                  style: adminType(15, FontWeight.w700, AdminTokens.text),
                ),
              ),
              Text(
                '$totalRecords · page $page / $totalPages',
                style: adminType(12, FontWeight.w500, AdminTokens.textSecondary),
              ),
              IconButton(onPressed: onPrev, icon: const Icon(Icons.chevron_left)),
              IconButton(
                onPressed: onNext,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (rows.isEmpty)
            Text(
              'No staff matched these filters.',
              style: adminType(13, FontWeight.w500, AdminTokens.textSecondary),
            )
          else
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: row.id == selectedId
                      ? AdminTokens.primarySoft
                      : AdminTokens.field,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => onSelect(row.id),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  row.fullName,
                                  style: adminType(
                                    13,
                                    FontWeight.w700,
                                    AdminTokens.text,
                                  ),
                                ),
                                Text(
                                  '${row.username}${row.riderCode == null ? '' : ' · ${row.riderCode}'}',
                                  style: adminType(
                                    11,
                                    FontWeight.w500,
                                    AdminTokens.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Text(
                              row.primaryRole.isEmpty
                                  ? row.roles.join(', ')
                                  : row.primaryRole,
                              style: adminType(
                                12,
                                FontWeight.w600,
                                AdminTokens.textSecondary,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              row.routeName ?? '—',
                              style: adminType(
                                12,
                                FontWeight.w500,
                                AdminTokens.textSecondary,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 72,
                            child: Text(
                              row.isActive ? 'Active' : 'Inactive',
                              textAlign: TextAlign.right,
                              style: adminType(
                                12,
                                FontWeight.w700,
                                row.isActive
                                    ? AdminTokens.success
                                    : AdminTokens.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _StaffDrawer extends StatelessWidget {
  const _StaffDrawer({
    required this.detail,
    required this.onActivate,
    required this.onDeactivate,
    required this.onResetPassword,
    required this.onAssignRoute,
    required this.onOpenFleet,
  });

  final StaffUser? detail;
  final VoidCallback onActivate;
  final VoidCallback onDeactivate;
  final VoidCallback onResetPassword;
  final VoidCallback onAssignRoute;
  final VoidCallback onOpenFleet;

  @override
  Widget build(BuildContext context) {
    if (detail == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AdminTokens.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AdminTokens.line),
        ),
        child: Text(
          'Select a staff account to inspect identity details.',
          style: adminType(13, FontWeight.w500, AdminTokens.textSecondary),
        ),
      );
    }

    final user = detail!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdminTokens.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminTokens.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            user.fullName,
            style: adminType(18, FontWeight.w700, AdminTokens.text),
          ),
          const SizedBox(height: 4),
          Text(
            '${user.primaryRole.isEmpty ? user.roles.join(', ') : user.primaryRole}'
            ' · ${user.isActive ? 'Active' : 'Inactive'}',
            style: adminType(12, FontWeight.w600, AdminTokens.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            user.username,
            style: adminType(12, FontWeight.w500, AdminTokens.textSecondary),
          ),
          if (user.email != null)
            Text(
              user.email!,
              style: adminType(12, FontWeight.w500, AdminTokens.textSecondary),
            ),
          if (user.phone != null)
            Text(
              user.phone!,
              style: adminType(12, FontWeight.w500, AdminTokens.textSecondary),
            ),
          if (user.riderCode != null)
            Text(
              'Rider code ${user.riderCode}',
              style: adminType(12, FontWeight.w500, AdminTokens.textSecondary),
            ),
          const SizedBox(height: 10),
          Text(
            'Route: ${user.routeName ?? 'Not assigned'}',
            style: adminType(12, FontWeight.w600, AdminTokens.text),
          ),
          Text(
            'Vehicle: ${user.vehiclePlate ?? user.vehicleName ?? 'Not assigned'}',
            style: adminType(12, FontWeight.w500, AdminTokens.textSecondary),
          ),
          Text(
            'Depot: ${user.depotName ?? 'Not assigned'}',
            style: adminType(12, FontWeight.w500, AdminTokens.textSecondary),
          ),
          Text(
            user.lastLoginAtUtc == null
                ? 'Last login: never'
                : 'Last login: ${formatAdminStamp(user.lastLoginAtUtc!)}',
            style: adminType(12, FontWeight.w500, AdminTokens.textSecondary),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (user.isRider)
                OutlinedButton(
                  onPressed: onAssignRoute,
                  child: const Text('Assign route'),
                ),
              if (user.isRider)
                OutlinedButton(
                  onPressed: onOpenFleet,
                  child: const Text('Open Fleet Couriers'),
                ),
              OutlinedButton(
                onPressed: onResetPassword,
                child: const Text('Reset password'),
              ),
              if (user.isActive)
                OutlinedButton(
                  onPressed: onDeactivate,
                  child: const Text('Deactivate'),
                )
              else
                OutlinedButton(
                  onPressed: onActivate,
                  child: const Text('Activate'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
