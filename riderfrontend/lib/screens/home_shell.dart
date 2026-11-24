import 'package:flutter/material.dart';

import '../core/rider_store.dart';
import '../core/theme.dart';
import '../widgets/aqua_widgets.dart';
import 'customerselection.dart';
import 'todayentries.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      RiderScope.of(context).prepareCustomers();
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = RiderScope.of(context);
    return HomeTab(
      index: _index,
      select: (index) => setState(() => _index = index),
      child: Scaffold(
        backgroundColor: AquaColors.background,
        body: SafeArea(
          bottom: false,
          child: IndexedStack(
            index: _index,
            children: const [CustomerSelectionScreen(), TodayEntriesScreen()],
          ),
        ),
        bottomNavigationBar: AppBottomNav(
          index: _index,
          todayCount: store.today.length,
          onChanged: (index) => setState(() => _index = index),
        ),
      ),
    );
  }
}
