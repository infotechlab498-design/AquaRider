import 'package:flutter/material.dart';

import '../ui/route_ui.dart';
import 'login.dart';

void replaceWithLogin(BuildContext context) {
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
    (route) => false,
  );
}

void popToRiderHome(BuildContext context) {
  Navigator.of(context).popUntil(
    (route) => route.settings.name == riderShellRoute || route.isFirst,
  );
}
