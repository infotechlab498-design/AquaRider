import 'package:riderfrontend/adminDashboard/data/admin_json.dart';

class StaffSummary {
  const StaffSummary({
    this.totalStaff = 0,
    this.activeUsers = 0,
    this.inactiveUsers = 0,
    this.activeRiders = 0,
    this.admins = 0,
    this.loggedInToday = 0,
  });

  final int totalStaff;
  final int activeUsers;
  final int inactiveUsers;
  final int activeRiders;
  final int admins;
  final int loggedInToday;

  factory StaffSummary.fromJson(Object? data) {
    final map = jsonMap(data);
    if (map == null) return const StaffSummary();
    return StaffSummary(
      totalStaff: optionalInt(map, const ['totalStaff']) ?? 0,
      activeUsers: optionalInt(map, const ['activeUsers']) ?? 0,
      inactiveUsers: optionalInt(map, const ['inactiveUsers']) ?? 0,
      activeRiders: optionalInt(map, const ['activeRiders']) ?? 0,
      admins: optionalInt(map, const ['admins']) ?? 0,
      loggedInToday: optionalInt(map, const ['loggedInToday']) ?? 0,
    );
  }
}

class RoleReference {
  const RoleReference({
    required this.role,
    required this.title,
    this.description = '',
    this.assignedCount = 0,
  });

  final String role;
  final String title;
  final String description;
  final int assignedCount;

  factory RoleReference.fromJson(Object? data) {
    final map = jsonMap(data) ?? const <String, dynamic>{};
    return RoleReference(
      role: jsonString(map, const ['role']) ?? '',
      title: jsonString(map, const ['title']) ?? '',
      description: jsonString(map, const ['description']) ?? '',
      assignedCount: optionalInt(map, const ['assignedCount']) ?? 0,
    );
  }
}

class StaffUser {
  const StaffUser({
    required this.id,
    required this.username,
    required this.fullName,
    this.riderCode,
    this.phone,
    this.isActive = true,
    this.roles = const [],
    this.routeId,
    this.email,
    this.vehicleId,
    this.vehicleName,
    this.vehiclePlate,
    this.depotId,
    this.depotName,
    this.routeName,
    this.lastLoginAtUtc,
    this.createdAt,
    this.primaryRole = '',
  });

  final String id;
  final String username;
  final String fullName;
  final String? riderCode;
  final String? phone;
  final bool isActive;
  final List<String> roles;
  final String? routeId;
  final String? email;
  final String? vehicleId;
  final String? vehicleName;
  final String? vehiclePlate;
  final String? depotId;
  final String? depotName;
  final String? routeName;
  final DateTime? lastLoginAtUtc;
  final DateTime? createdAt;
  final String primaryRole;

  bool get isRider =>
      primaryRole == 'Rider' || roles.any((role) => role == 'Rider');
  bool get isAdmin =>
      primaryRole == 'Admin' || roles.any((role) => role == 'Admin');

  factory StaffUser.fromJson(Object? data) {
    final map = jsonMap(data) ?? const <String, dynamic>{};
    final roleRows = jsonPick(map, const ['roles']);
    final roles = <String>[];
    if (roleRows is List) {
      for (final row in roleRows) {
        if (row is String && row.trim().isNotEmpty) roles.add(row.trim());
      }
    }
    DateTime? parseStamp(String? raw) {
      if (raw == null || raw.isEmpty) return null;
      return DateTime.tryParse(raw)?.toLocal();
    }

    return StaffUser(
      id: jsonString(map, const ['id']) ?? '',
      username: jsonString(map, const ['username']) ?? '',
      fullName: jsonString(map, const ['fullName']) ?? '',
      riderCode: jsonString(map, const ['riderCode']),
      phone: jsonString(map, const ['phone']),
      isActive: jsonBool(map, const ['isActive']) ?? true,
      roles: roles,
      routeId: jsonString(map, const ['routeId']),
      email: jsonString(map, const ['email']),
      vehicleId: jsonString(map, const ['vehicleId']),
      vehicleName: jsonString(map, const ['vehicleName']),
      vehiclePlate: jsonString(map, const ['vehiclePlate']),
      depotId: jsonString(map, const ['depotId']),
      depotName: jsonString(map, const ['depotName']),
      routeName: jsonString(map, const ['routeName']),
      lastLoginAtUtc: parseStamp(jsonString(map, const ['lastLoginAtUtc'])),
      createdAt: parseStamp(jsonString(map, const ['createdAt'])),
      primaryRole: jsonString(map, const ['primaryRole']) ?? '',
    );
  }
}

class StaffUserPage {
  const StaffUserPage({
    required this.rows,
    this.page = 1,
    this.pageSize = 50,
    this.totalRecords = 0,
    this.totalPages = 1,
  });

  final List<StaffUser> rows;
  final int page;
  final int pageSize;
  final int totalRecords;
  final int totalPages;
}

class RoleAccessScreen {
  const RoleAccessScreen({
    required this.key,
    required this.group,
    required this.label,
    this.detail = '',
  });

  final String key;
  final String group;
  final String label;
  final String detail;

  factory RoleAccessScreen.fromJson(Object? data) {
    final map = jsonMap(data) ?? const <String, dynamic>{};
    return RoleAccessScreen(
      key: jsonString(map, const ['key']) ?? '',
      group: jsonString(map, const ['group']) ?? '',
      label: jsonString(map, const ['label']) ?? '',
      detail: jsonString(map, const ['detail']) ?? '',
    );
  }
}

class RoleAccessMember {
  const RoleAccessMember({
    required this.id,
    required this.fullName,
    this.riderCode,
    this.depotName,
    this.warehousePersonName,
    this.zoneName,
  });

  final String id;
  final String fullName;
  final String? riderCode;
  final String? depotName;
  final String? warehousePersonName;
  final String? zoneName;

  factory RoleAccessMember.fromJson(Object? data) {
    final map = jsonMap(data) ?? const <String, dynamic>{};
    return RoleAccessMember(
      id: jsonString(map, const ['id']) ?? '',
      fullName: jsonString(map, const ['fullName']) ?? '',
      riderCode: jsonString(map, const ['riderCode']),
      depotName: jsonString(map, const ['depotName']),
      warehousePersonName: jsonString(map, const ['warehousePersonName']),
      zoneName: jsonString(map, const ['zoneName']),
    );
  }
}

class RoleAccessRow {
  const RoleAccessRow({
    required this.role,
    this.title = '',
    this.description = '',
    this.assignedCount = 0,
    this.isSystem = false,
    this.screenKeys = const [],
    this.members = const [],
  });

  final String role;
  final String title;
  final String description;
  final int assignedCount;
  final bool isSystem;
  final List<String> screenKeys;
  final List<RoleAccessMember> members;

  factory RoleAccessRow.fromJson(Object? data) {
    final map = jsonMap(data) ?? const <String, dynamic>{};
    return RoleAccessRow(
      role: jsonString(map, const ['role']) ?? '',
      title: jsonString(map, const ['title']) ?? '',
      description: jsonString(map, const ['description']) ?? '',
      assignedCount: optionalInt(map, const ['assignedCount']) ?? 0,
      isSystem: jsonBool(map, const ['isSystem']) ?? false,
      screenKeys: [
        for (final row in (map['screenKeys'] is List ? map['screenKeys'] as List : const []))
          if (row is String) row,
      ],
      members: [
        for (final row in jsonRows(map['members'])) RoleAccessMember.fromJson(row),
      ],
    );
  }
}

class RoleAccessMatrix {
  const RoleAccessMatrix({
    this.screens = const [],
    this.roles = const [],
    this.assignedStaff = 0,
    this.policyNote = '',
  });

  final List<RoleAccessScreen> screens;
  final List<RoleAccessRow> roles;
  final int assignedStaff;
  final String policyNote;

  factory RoleAccessMatrix.fromJson(Object? data) {
    final map = jsonMap(data) ?? const <String, dynamic>{};
    return RoleAccessMatrix(
      screens: [
        for (final row in jsonRows(map['screens'])) RoleAccessScreen.fromJson(row),
      ],
      roles: [
        for (final row in jsonRows(map['roles'])) RoleAccessRow.fromJson(row),
      ],
      assignedStaff: optionalInt(map, const ['assignedStaff']) ?? 0,
      policyNote: jsonString(map, const ['policyNote']) ?? '',
    );
  }
}
