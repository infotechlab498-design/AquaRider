import 'package:flutter/material.dart';

import 'package:riderfrontend/adminDashboard/presentation/admin_load.dart';
import 'package:riderfrontend/adminDashboard/presentation/admin_nav.dart';
import 'package:riderfrontend/adminDashboard/presentation/widgets/admin_shell.dart';
import 'package:riderfrontend/adminDashboard/theme/admin_tokens.dart';
import 'package:riderfrontend/api/route_api.dart';

class RolesPermissionsScreen extends StatefulWidget {
  const RolesPermissionsScreen({required this.onNavigate, this.session, super.key});

  final AuthSession? session;
  final ValueChanged<String> onNavigate;

  @override
  State<RolesPermissionsScreen> createState() => _RolesPermissionsScreenState();
}

class _RolesPermissionsScreenState extends State<RolesPermissionsScreen> {
  final _search = TextEditingController();
  final _filter = TextEditingController();
  var _started = false;
  var _loading = true;
  var _saving = false;
  String? _selectedRole;
  Set<String> _draft = {};

  AdminLoad<RoleAccessMatrix>? _matrix;
  AdminLoad<StaffUserPage>? _staff;

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
    _search.dispose();
    _filter.dispose();
    super.dispose();
  }

  RoleAccessRow? get _role {
    final rows = _matrix?.value?.roles ?? const <RoleAccessRow>[];
    for (final row in rows) {
      if (row.role == _selectedRole) return row;
    }
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final matrix = await guardAdminLoad(() => ApiScope.of(context).roleAccess());
    final staff = await guardAdminLoad(() => ApiScope.of(context).staffUsers(pageSize: 100));
    if (!mounted) return;
    final rows = matrix.value?.roles ?? const <RoleAccessRow>[];
    final keep = _selectedRole != null && rows.any((row) => row.role == _selectedRole)
        ? _selectedRole
        : (rows.isEmpty ? null : rows.first.role);
    final selected = rows.where((row) => row.role == keep).firstOrNull;
    setState(() {
      _matrix = matrix;
      _staff = staff;
      _selectedRole = keep;
      _draft = {...?selected?.screenKeys};
      _loading = false;
    });
  }

  void _select(RoleAccessRow row) {
    setState(() {
      _selectedRole = row.role;
      _draft = {...row.screenKeys};
    });
  }

  Future<void> _save() async {
    final role = _role;
    if (role == null) return;
    if (role.role.toLowerCase() == 'admin') {
      showAdminNotice(context, 'The Admin role keeps every screen.');
      return;
    }
    setState(() => _saving = true);
    try {
      final saved = await ApiScope.of(context).saveRoleAccess(role.role, _draft.toList());
      if (!mounted) return;
      showAdminNotice(context, 'Saved screen access for ${saved.role}.');
      await _reload();
    } on ApiException catch (error) {
      if (mounted) showAdminNotice(context, error.message);
    } catch (_) {
      if (mounted) showAdminNotice(context, adminUnreachableMessage);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _createRole() async {
    final roles = _matrix?.value?.roles ?? const <RoleAccessRow>[];
    if (roles.isEmpty) {
      showAdminNotice(context, 'Roles were not loaded.');
      return;
    }
    List<ZoneListItem> zones;
    try {
      zones = await ApiScope.of(context).listZones(activeOnly: true);
    } on ApiException catch (error) {
      if (mounted) showAdminNotice(context, error.message);
      return;
    } catch (_) {
      if (mounted) showAdminNotice(context, adminUnreachableMessage);
      return;
    }
    if (!mounted) return;
    final draft = await showDialog<_PersonDraft>(
      context: context,
      builder: (context) => _AddPersonDialog(
        roles: roles,
        zones: zones,
        staff: _staff?.value?.rows ?? const <StaffUser>[],
        staffLoaded: _staff != null && !_staff!.failed,
      ),
    );
    if (draft == null || !mounted) return;
    try {
      final api = ApiScope.of(context);
      var roleName = draft.role;
      if (draft.isNewRole) {
        final row = await api.createAccessRole(name: draft.newRoleName);
        roleName = row.role;
      }
      final created = await api.createStaffUser(
        username: draft.username,
        password: draft.password,
        fullName: draft.fullName,
        role: roleName,
        depotId: draft.depotId,
        zoneId: draft.zoneId,
        warehousePersonUserId: draft.warehousePersonId,
      );
      if (!mounted) return;
      final rider = roleName.toLowerCase() == 'rider';
      final saved = _matrix?.value?.roles.where((row) => row.role == roleName).firstOrNull;
      final hasScreens = roleName.toLowerCase() == 'admin' || (saved?.screenKeys.isNotEmpty ?? false);
      final where = rider
          ? 'They sign in on the Rider app with ${created.username}.'
          : hasScreens
          ? 'They sign in on the portal with ${created.username}.'
          : 'Save the screens for $roleName, then they can sign in on the portal with ${created.username}.';
      final label = rider && (draft.warehousePersonId == null || draft.warehousePersonId!.isEmpty)
          ? ' No warehouse person is stored for this warehouse.'
          : '';
      showAdminNotice(context, 'Created ${created.fullName}. $where$label');
      setState(() => _selectedRole = roleName);
      await _reload();
    } on ApiException catch (error) {
      if (mounted) showAdminNotice(context, error.message);
    } catch (_) {
      if (mounted) showAdminNotice(context, adminUnreachableMessage);
    }
  }

  Future<void> _assign() async {
    final role = _role;
    final people = _staff?.value?.rows ?? const <StaffUser>[];
    if (role == null) return;
    if (people.isEmpty) {
      showAdminNotice(context, 'No staff accounts were returned.');
      return;
    }
    var userId = people.first.id;
    final assigned = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          key: const Key('role-assign-dialog'),
          title: Text('Assign ${role.role}'),
          content: SizedBox(
            width: 420,
            child: DropdownButtonFormField<String>(
              initialValue: userId,
              isExpanded: true,
              items: [
                for (final person in people)
                  DropdownMenuItem(value: person.id, child: Text(person.fullName)),
              ],
              onChanged: (value) {
                if (value == null) return;
                setLocal(() => userId = value);
              },
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(
              key: const Key('role-assign-confirm'),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Assign'),
            ),
          ],
        ),
      ),
    );
    if (assigned != true || !mounted) return;
    try {
      await ApiScope.of(context).assignRoleMember(role.role, userId);
      if (!mounted) return;
      showAdminNotice(context, 'Assigned ${role.role}.');
      await _reload();
    } on ApiException catch (error) {
      if (mounted) showAdminNotice(context, error.message);
    } catch (_) {
      if (mounted) showAdminNotice(context, adminUnreachableMessage);
    }
  }

  ButtonStyle _button() {
    return FilledButton.styleFrom(
      backgroundColor: AdminTokens.button,
      foregroundColor: Colors.white,
      elevation: 0,
      minimumSize: const Size(0, 40),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final matrix = _matrix?.value;
    final roles = matrix?.roles ?? const <RoleAccessRow>[];
    final query = _filter.text.trim().toLowerCase();
    final visible = [
      for (final role in roles)
        if (query.isEmpty || role.role.toLowerCase().contains(query) || role.description.toLowerCase().contains(query))
          role,
    ];
    return AdminShell(
      screenKey: const Key('users-staff-screen'),
      session: widget.session,
      activeKey: AdminNav.usersStaff,
      serverReachable: adminServerReachable([?_matrix]),
      search: _search,
      onSearch: (_) {},
      searchHint: 'Search roles or staff…',
      onNavigate: widget.onNavigate,
      body: _loading && matrix == null
          ? const AdminLoadingPane(label: 'Loading roles and permissions…')
          : ListView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              children: [
                _header(matrix, roles),
                const SizedBox(height: 16),
                if (_matrix?.error != null && matrix == null)
                  Text(_matrix!.error!, style: adminType(13, FontWeight.w600, const Color(0xFFC62828)))
                else
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final roster = _roster(visible);
                      final profile = _profile(matrix);
                      if (constraints.maxWidth < 980) {
                        return Column(children: [roster, const SizedBox(height: 16), profile]);
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(width: 320, child: roster),
                          const SizedBox(width: 16),
                          Expanded(child: profile),
                        ],
                      );
                    },
                  ),
              ],
            ),
    );
  }

  Widget _header(RoleAccessMatrix? matrix, List<RoleAccessRow> roles) {
    final custom = roles.where((row) => !row.isSystem).length;
    final cards = [
      _kpi('Total roles', '${roles.length}'),
      _kpi('System roles', '${roles.where((row) => row.isSystem).length}'),
      _kpi('Custom roles', '$custom'),
      _kpi('Assigned staff', '${matrix?.assignedStaff ?? 0}'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Team Management  ›  Roles & Permissions', style: adminType(12, FontWeight.w600, AdminTokens.textSecondary)),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (context, constraints) {
            final title = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Roles & Permissions', style: adminType(26, FontWeight.w700, AdminTokens.text, height: 1.2)),
                const SizedBox(height: 6),
                Text(
                  'Choose which screens each role can open. A person only sees the screens saved for their role.',
                  style: adminType(13.5, FontWeight.w500, AdminTokens.textSecondary),
                ),
                if ((matrix?.policyNote ?? '').isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(matrix!.policyNote, style: adminType(12, FontWeight.w600, AdminTokens.textSecondary)),
                ],
              ],
            );
            final action = FilledButton.icon(
              key: const Key('role-create'),
              style: _button(),
              onPressed: _createRole,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add person'),
            );
            if (constraints.maxWidth < 860) {
              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [title, const SizedBox(height: 12), action]);
            }
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: title), action]);
          },
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 900) {
              return Wrap(spacing: 12, runSpacing: 12, children: [for (final card in cards) SizedBox(width: 200, child: card)]);
            }
            return Row(
              children: [
                for (var i = 0; i < cards.length; i++) ...[
                  if (i > 0) const SizedBox(width: 12),
                  Expanded(child: cards[i]),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _kpi(String title, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminTokens.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(), style: adminType(11, FontWeight.w700, AdminTokens.textSecondary, letterSpacing: 0.3)),
          const SizedBox(height: 8),
          Text(value, style: adminType(26, FontWeight.w700, AdminTokens.text)),
        ],
      ),
    );
  }

  Widget _roster(List<RoleAccessRow> roles) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminTokens.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Role Roster', style: adminType(16, FontWeight.w700, AdminTokens.text)),
          const SizedBox(height: 8),
          TextField(
            key: const Key('role-filter'),
            controller: _filter,
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Filter roles…', isDense: true),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          if (roles.isEmpty)
            Text('No roles were returned.', style: adminType(13, FontWeight.w500, AdminTokens.textSecondary))
          else
            for (final role in roles)
              InkWell(
                key: Key('role-row-${role.role}'),
                onTap: () => _select(role),
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: role.role == _selectedRole ? AdminTokens.primary.withValues(alpha: 0.08) : const Color(0xFFF7F9FC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: role.role == _selectedRole ? AdminTokens.primary : AdminTokens.line),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(role.role, style: adminType(14, FontWeight.w700, AdminTokens.text)),
                      const SizedBox(height: 4),
                      Text(role.description, style: adminType(12, FontWeight.w500, AdminTokens.textSecondary)),
                      const SizedBox(height: 4),
                      Text(
                        '${role.assignedCount} assigned · ${role.isSystem ? 'System' : 'Custom'}',
                        style: adminType(12, FontWeight.w600, AdminTokens.primary),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Widget _profile(RoleAccessMatrix? matrix) {
    final role = _role;
    final screens = matrix?.screens ?? const <RoleAccessScreen>[];
    final groups = <String, List<RoleAccessScreen>>{};
    for (final screen in screens) {
      groups.putIfAbsent(screen.group, () => []).add(screen);
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminTokens.line),
      ),
      child: role == null
          ? Text('Select a role.', style: adminType(13, FontWeight.w500, AdminTokens.textSecondary))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(role.role, style: adminType(20, FontWeight.w700, AdminTokens.text))),
                    TextButton(
                      onPressed: () => setState(() => _draft = {...role.screenKeys}),
                      child: const Text('Discard Changes'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      key: const Key('role-save'),
                      style: _button(),
                      onPressed: _saving ? null : _save,
                      child: Text(_saving ? 'Saving…' : 'Save Role Permissions'),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(role.description, style: adminType(13, FontWeight.w500, AdminTokens.textSecondary)),
                const SizedBox(height: 12),
                if (role.members.isEmpty)
                  Text('No staff assigned.', style: adminType(13, FontWeight.w600, AdminTokens.text))
                else
                  for (final member in role.members)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(_memberLine(member), style: adminType(13, FontWeight.w600, AdminTokens.text)),
                    ),
                const SizedBox(height: 8),
                OutlinedButton(
                  key: const Key('role-assign'),
                  onPressed: _assign,
                  child: const Text('Assign staff'),
                ),
                const SizedBox(height: 16),
                for (final entry in groups.entries) ...[
                  Row(
                    children: [
                      Expanded(child: Text(entry.key, style: adminType(15, FontWeight.w700, AdminTokens.text))),
                      TextButton(
                        onPressed: role.role.toLowerCase() == 'admin'
                            ? null
                            : () => setState(() {
                                final keys = entry.value.map((screen) => screen.key);
                                if (keys.every(_draft.contains)) {
                                  _draft.removeAll(keys);
                                } else {
                                  _draft.addAll(keys);
                                }
                              }),
                        child: const Text('Select All'),
                      ),
                    ],
                  ),
                  for (final screen in entry.value)
                    InkWell(
                      key: Key('role-screen-${role.role}-${screen.key}'),
                      onTap: role.role.toLowerCase() == 'admin'
                          ? null
                          : () => setState(() {
                              if (_draft.contains(screen.key)) {
                                _draft.remove(screen.key);
                              } else {
                                _draft.add(screen.key);
                              }
                            }),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Checkbox(
                              value: _draft.contains(screen.key),
                              onChanged: role.role.toLowerCase() == 'admin'
                                  ? null
                                  : (value) => setState(() {
                                      if (value ?? false) {
                                        _draft.add(screen.key);
                                      } else {
                                        _draft.remove(screen.key);
                                      }
                                    }),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(screen.label, style: adminType(13.5, FontWeight.w600, AdminTokens.text)),
                                  Text(screen.detail, style: adminType(12, FontWeight.w500, AdminTokens.textSecondary)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
    );
  }

  String _memberLine(RoleAccessMember member) {
    final parts = <String>[member.fullName];
    final zone = member.zoneName?.trim() ?? '';
    final depot = member.depotName?.trim() ?? '';
    final person = member.warehousePersonName?.trim() ?? '';
    if (zone.isNotEmpty) parts.add(zone);
    if (depot.isNotEmpty) parts.add(depot);
    if (person.isNotEmpty) parts.add('with $person');
    return parts.join(' · ');
  }
}

class _PersonDraft {
  const _PersonDraft({
    required this.fullName,
    required this.username,
    required this.password,
    required this.role,
    required this.isNewRole,
    this.newRoleName = '',
    this.zoneId,
    this.depotId,
    this.warehousePersonId,
  });

  final String fullName;
  final String username;
  final String password;
  final String role;
  final bool isNewRole;
  final String newRoleName;
  final String? zoneId;
  final String? depotId;
  final String? warehousePersonId;
}

class _AddPersonDialog extends StatefulWidget {
  const _AddPersonDialog({
    required this.roles,
    required this.zones,
    required this.staff,
    required this.staffLoaded,
  });

  final List<RoleAccessRow> roles;
  final List<ZoneListItem> zones;
  final List<StaffUser> staff;
  final bool staffLoaded;

  @override
  State<_AddPersonDialog> createState() => _AddPersonDialogState();
}

class _AddPersonDialogState extends State<_AddPersonDialog> {
  static const _newRole = 'new-role';

  final _name = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _roleName = TextEditingController();
  late String _role;
  String? _zoneId;
  String? _depotId;
  String? _personId;

  @override
  void initState() {
    super.initState();
    _role = widget.roles.first.role;
    _applyZone(widget.zones.isEmpty ? null : widget.zones.first.id);
  }

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _password.dispose();
    _roleName.dispose();
    super.dispose();
  }

  bool get _rider => _role.toLowerCase() == 'rider';

  List<ZoneListItem> get _zoneChoices =>
      widget.zones.where((zone) => zone.id.isNotEmpty).toList();

  List<({String id, String name})> _warehouses() {
    final source = _rider
        ? _zoneChoices.where((zone) => zone.id == _zoneId)
        : _zoneChoices;
    final seen = <String>{};
    final rows = <({String id, String name})>[];
    for (final zone in source) {
      if (zone.depotId.isEmpty || !seen.add(zone.depotId)) continue;
      final label = zone.depotName.trim().isEmpty
          ? 'Warehouse name was not returned'
          : zone.depotName.trim();
      rows.add((id: zone.depotId, name: label));
    }
    return rows;
  }

  List<StaffUser> _people(String? depotId) {
    if (depotId == null || depotId.isEmpty) return const [];
    return [
      for (final person in widget.staff)
        if (person.isActive && !person.isRider && person.depotId == depotId) person,
    ];
  }

  void _applyZone(String? zoneId) {
    _zoneId = zoneId;
    final warehouses = _warehouses();
    _depotId = warehouses.isEmpty ? null : warehouses.first.id;
    final people = _people(_depotId);
    _personId = people.isEmpty ? null : people.first.id;
  }

  void _submit() {
    final fullName = _name.text.trim();
    final username = _username.text.trim();
    final password = _password.text;
    final newName = _roleName.text.trim();
    if (fullName.isEmpty || username.isEmpty || password.isEmpty) {
      showAdminNotice(context, 'Name, username, and password are required.');
      return;
    }
    final passwordOk = password.length >= 8 &&
        RegExp(r'[a-z]').hasMatch(password) &&
        RegExp(r'[0-9]').hasMatch(password);
    if (!passwordOk) {
      showAdminNotice(context, 'Use at least 8 characters, with a lowercase letter and a number.');
      return;
    }
    final isNew = _role == _newRole;
    if (isNew && newName.length < 2) {
      showAdminNotice(context, 'Enter a role name.');
      return;
    }
    if (_rider && (_zoneId == null || _zoneId!.isEmpty)) {
      showAdminNotice(context, _zoneChoices.isEmpty ? 'No zones were returned.' : 'Choose a zone for the rider.');
      return;
    }
    if (_rider && (_depotId == null || _depotId!.isEmpty)) {
      showAdminNotice(context, 'Choose a warehouse on that zone.');
      return;
    }
    Navigator.pop(
      context,
      _PersonDraft(
        fullName: fullName,
        username: username,
        password: password,
        role: isNew ? newName : _role,
        isNewRole: isNew,
        newRoleName: newName,
        zoneId: _rider ? _zoneId : null,
        depotId: _depotId,
        warehousePersonId: _rider ? _personId : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final warehouses = _warehouses();
    final people = _people(_depotId);
    final destination = _rider
        ? 'These credentials sign in on the Rider app.'
        : 'These credentials sign in on the portal. The role only opens the screens you save.';
    return AlertDialog(
      key: const Key('role-create-dialog'),
      title: const Text('Add a person'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                key: const Key('role-create-name'),
                controller: _name,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 8),
              TextField(
                key: const Key('role-person-username'),
                controller: _username,
                decoration: const InputDecoration(labelText: 'Username'),
              ),
              const SizedBox(height: 8),
              TextField(
                key: const Key('role-person-password'),
                controller: _password,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  helperText: 'At least 8 characters, with a lowercase letter and a number.',
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                key: const Key('role-person-role'),
                initialValue: _role,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Role type'),
                items: [
                  for (final role in widget.roles)
                    DropdownMenuItem(value: role.role, child: Text(role.role)),
                  const DropdownMenuItem(value: _newRole, child: Text('New role')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _role = value;
                    _applyZone(_zoneId ?? (_zoneChoices.isEmpty ? null : _zoneChoices.first.id));
                  });
                },
              ),
              if (_role == _newRole) ...[
                const SizedBox(height: 8),
                TextField(
                  key: const Key('role-person-new-role'),
                  controller: _roleName,
                  decoration: const InputDecoration(labelText: 'New role name'),
                ),
              ],
              const SizedBox(height: 8),
              Text(destination, style: adminType(12, FontWeight.w600, AdminTokens.textSecondary)),
              if (_rider) ...[
                const SizedBox(height: 8),
                if (_zoneChoices.isEmpty)
                  Text('No zones were returned.', style: adminType(13, FontWeight.w600, AdminTokens.text))
                else
                  DropdownButtonFormField<String>(
                    key: ValueKey('role-person-zone-$_zoneId'),
                    initialValue: _zoneId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Zone'),
                    items: [
                      for (final zone in _zoneChoices)
                        DropdownMenuItem(value: zone.id, child: Text(zone.name.isEmpty ? zone.id : zone.name)),
                    ],
                    onChanged: (value) => setState(() => _applyZone(value)),
                  ),
              ],
              const SizedBox(height: 8),
              if (warehouses.isEmpty)
                Text(
                  _rider ? 'This zone has no warehouse.' : 'No warehouses were returned.',
                  style: adminType(13, FontWeight.w600, AdminTokens.text),
                )
              else
                DropdownButtonFormField<String>(
                  key: ValueKey('role-person-warehouse-$_depotId'),
                  initialValue: _depotId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Warehouse'),
                  items: [
                    for (final depot in warehouses)
                      DropdownMenuItem(value: depot.id, child: Text(depot.name)),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _depotId = value;
                      final next = _people(value);
                      _personId = next.isEmpty ? null : next.first.id;
                    });
                  },
                ),
              if (_rider) ...[
                const SizedBox(height: 8),
                if (!widget.staffLoaded)
                  Text('Staff accounts were not loaded.', style: adminType(13, FontWeight.w600, AdminTokens.text))
                else if (people.isEmpty)
                  Text(
                    'No warehouse person is assigned to this warehouse.',
                    style: adminType(13, FontWeight.w600, AdminTokens.text),
                  )
                else
                  DropdownButtonFormField<String>(
                    key: ValueKey('role-person-person-$_personId'),
                    initialValue: _personId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Warehouse person'),
                    items: [
                      for (final person in people)
                        DropdownMenuItem(value: person.id, child: Text(person.fullName)),
                    ],
                    onChanged: (value) => setState(() => _personId = value),
                  ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          key: const Key('role-create-confirm'),
          onPressed: _submit,
          child: const Text('Create'),
        ),
      ],
    );
  }
}
