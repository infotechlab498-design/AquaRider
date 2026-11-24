import 'dart:async';

import 'package:flutter/material.dart';

import '../adminDashboard/data/fleet_tracking_models.dart';
import '../api/route_api.dart';
import '../screens/route_compliance_screen.dart';
import '../ui/route_ui.dart';

/// Rider home bell. The badge is the unread count returned by the API.
class RiderInboxButton extends StatefulWidget {
  const RiderInboxButton({this.refreshEvery = const Duration(seconds: 20), this.iconColor = RouteColors.ink, super.key});

  final Duration? refreshEvery;
  final Color iconColor;

  @override
  State<RiderInboxButton> createState() => _RiderInboxButtonState();
}

class _RiderInboxButtonState extends State<RiderInboxButton> {
  List<RiderNotificationInfo> _items = const [];
  Timer? _timer;
  var _started = false;
  var _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    final every = widget.refreshEvery;
    if (every != null) {
      _timer = Timer.periodic(every, (_) => _load());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    final api = ApiScope.of(context);
    try {
      final items = await api.riderNotifications();
      if (!mounted || generation != _loadGeneration) return;
      setState(() => _items = items);
    } catch (_) {}
  }

  Future<void> _open() async {
    await _load();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: _items.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Text('No messages have been sent to this rider.'),
              )
            : ListView(
                key: const Key('rider-inbox-sheet'),
                shrinkWrap: true,
                children: [
                  for (final item in _items)
                    ListTile(
                      key: Key('rider-inbox-${item.id}'),
                      title: Text(item.title),
                      subtitle: Text(item.body),
                      trailing: item.isRead
                          ? null
                          : const CircleAvatar(
                              radius: 4,
                              backgroundColor: RouteColors.danger,
                            ),
                      onTap: () => _openItem(sheet, item),
                    ),
                ],
              ),
      ),
    );
  }

  Future<void> _openItem(BuildContext sheet, RiderNotificationInfo item) async {
    try {
      await ApiScope.of(context).markRiderNotificationRead(item.id);
    } catch (_) {}
    if (!sheet.mounted) return;
    Navigator.pop(sheet);
    if (!mounted) return;
    if (item.deepLink == 'route-compliance') {
      pushRoute(context, const RouteComplianceScreen());
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final unread = _items.where((item) => !item.isRead).length;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          key: const Key('rider-inbox-button'),
          onPressed: _open,
          icon: Icon(Icons.notifications_none, color: widget.iconColor),
        ),
        if (unread > 0)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              key: const Key('rider-inbox-badge'),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: const BoxDecoration(
                color: RouteColors.danger,
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
              alignment: Alignment.center,
              child: Text(
                unread > 9 ? '9+' : '$unread',
                style: routeType(9, FontWeight.w700, Colors.white, 11, 0),
              ),
            ),
          ),
      ],
    );
  }
}
