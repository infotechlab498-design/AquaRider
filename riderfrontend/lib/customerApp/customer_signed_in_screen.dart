import 'package:flutter/material.dart';

import 'package:riderfrontend/api/route_api.dart';
import 'package:riderfrontend/customerApp/customer_shell.dart';

class CustomerSignedInScreen extends StatelessWidget {
  const CustomerSignedInScreen({required this.session, super.key});

  final AuthSession session;

  @override
  Widget build(BuildContext context) => CustomerShell(session: session);
}
