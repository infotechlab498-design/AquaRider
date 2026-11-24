import 'package:flutter/material.dart';

import '../api/field_store.dart';
import '../ui/route_ui.dart';
import 'field_screens.dart';
import 'route_map_screen.dart';

class RouteShell extends StatefulWidget {
  const RouteShell({super.key});

  @override
  State<RouteShell> createState() => _RouteShellState();
}

class _RouteShellState extends State<RouteShell> with WidgetsBindingObserver {
  var _index = 0;
  var _started = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted) return;
    final store = FieldScope.of(context);
    store.loadHome();
    store.loadStops();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final store = FieldScope.of(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      store.loadHome();
      store.loadStops();
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = FieldScope.of(context);
    final pages = <Widget>[
      HomeDashboard(
        onOpenProfile: () {
          setState(() => _index = 3);
          store.loadSettings();
        },
        onOpenTodo: () {
          setState(() => _index = 1);
          store.loadStops();
        },
        onOpenMap: () {
          setState(() => _index = 2);
          store.loadStops();
        },
      ),
      RouteQueueScreen(
        onOpenProfile: () {
          setState(() => _index = 3);
          store.loadSettings();
        },
      ),
      RouteMapScreen(
        onOpenProfile: () {
          setState(() => _index = 3);
          store.loadSettings();
        },
      ),
      const SettingsScreen(),
    ];
    final wide = MediaQuery.sizeOf(context).width >= 700;
    return Scaffold(
      backgroundColor: const Color(0xFFE7F4FC),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: wide ? 980 : 560),
            child: pages[_index],
          ),
        ),
      ),
      bottomNavigationBar: RouteBottomNav(
        index: _index,
        onChanged: (index) {
          setState(() => _index = index);
          if (index == 0) store.loadHome();
          if (index == 0 || index == 1 || index == 2) store.loadStops();
          if (index == 3) store.loadSettings();
        },
      ),
    );
  }
}
