import 'package:flutter/material.dart';

import '../../api/route_api.dart';
import '../../screens/location_access.dart';
import 'admin_nav.dart';
import 'admin_workspace.dart';

bool isAdminRole(String role) => role.trim().toLowerCase() == 'admin';

/// Admin sessions open the command dashboard. Rider sessions keep the field flow.
/// Setup Checklist stays on the sidebar and is not the landing page.
Widget homeForSession(AuthSession session) {
  if (session.isAdmin) {
    return AdminWorkspace(session: session, initialKey: AdminNav.dashboard);
  }
  return const LocationAccessScreen();
}
