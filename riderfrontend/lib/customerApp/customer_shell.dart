import 'package:flutter/material.dart';

import 'package:riderfrontend/api/route_api.dart';
import 'package:riderfrontend/customerApp/customer_payments_screen.dart';
import 'package:riderfrontend/customerApp/customer_profile_screen.dart';
import 'package:riderfrontend/customerApp/customer_request_screen.dart';
import 'package:riderfrontend/customerApp/customer_schedule_screen.dart';
import 'package:riderfrontend/customerApp/customer_theme.dart';

const _blue = Color(0xFF1266D5);
const _navy = Color(0xFF10233F);
const _muted = Color(0xFF64748B);
const _ok = Color(0xFF16834C);
const _warn = Color(0xFFE99A22);
const _bad = Color(0xFFD92D35);

class CustomerShell extends StatefulWidget {
  const CustomerShell({required this.session, super.key});

  final AuthSession session;

  @override
  State<CustomerShell> createState() => _CustomerShellState();
}

class _CustomerShellState extends State<CustomerShell> {
  var _tab = 0;
  var _paymentsReload = 0;
  var _scheduleReload = 0;

  void _open(Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  void _openProfile() => setState(() => _tab = 3);

  void _selectTab(int index) {
    setState(() {
      _tab = index;
      if (index == 1) _scheduleReload++;
      if (index == 2) _paymentsReload++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('customer-shell'),
      backgroundColor: customerPage,
      body: IndexedStack(
        index: _tab,
        children: [
          CustomerHomeScreen(session: widget.session, onOpen: _open, onOpenProfile: _openProfile),
          CustomerScheduleScreen(reloadToken: _scheduleReload),
          CustomerPaymentsScreen(reloadToken: _paymentsReload),
          CustomerProfileScreen(session: widget.session, onOpen: _open),
        ],
      ),
      bottomNavigationBar: _CustomerNav(index: _tab, onChanged: _selectTab),
    );
  }
}

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({required this.session, required this.onOpen, this.onOpenProfile, super.key});

  final AuthSession session;
  final ValueChanged<Widget> onOpen;
  final VoidCallback? onOpenProfile;

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  var _started = false;
  var _loading = true;
  CustomerHome? _home;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final home = await ApiScope.of(context).customerHome();
      if (!mounted) return;
      setState(() {
        _home = home;
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Cannot reach the route server.';
        _loading = false;
      });
    }
  }

  void _schedule() => widget.onOpen(const CustomerScheduleScreen(standalone: true));

  @override
  Widget build(BuildContext context) {
    final home = _home;
    final rawName = home?.firstName.isNotEmpty == true ? home!.firstName : widget.session.firstName;
    final trimmed = rawName.trim();
    final name = trimmed.isEmpty ? trimmed : '${trimmed[0].toUpperCase()}${trimmed.substring(1)}';
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 700;
        return Stack(
          fit: StackFit.expand,
          children: [
            const Image(image: AssetImage('assets/customer_home/images/customer_home_bg.png'), fit: BoxFit.cover),
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 72,
              child: IgnorePointer(
                child: Image(image: AssetImage('assets/customer_home/images/customer_home_footer_wave.png'), fit: BoxFit.cover, alignment: Alignment.bottomCenter),
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 980),
                  child: RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      key: const Key('customer-home-screen'),
                      padding: const EdgeInsets.only(bottom: 160),
                      children: [
                        _header(name, home?.unreadNotifications ?? 0),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                          child: Column(
                            children: [
                              if (_loading) const LinearProgressIndicator(color: _blue),
                              if (_error != null) ...[
                                Text(_error!, style: customerType(14, FontWeight.w600, _bad)),
                                const SizedBox(height: 8),
                                OutlinedButton(onPressed: _load, child: const Text('Try again')),
                              ],
                              if (home != null) ...[
                                if (wide)
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(child: Column(children: _primary(home))),
                                      const SizedBox(width: 16),
                                      Expanded(child: Column(children: _secondary(home))),
                                    ],
                                  )
                                else ...[
                                  ..._primary(home),
                                  ..._secondary(home),
                                ],
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  List<Widget> _primary(CustomerHome home) {
    return [
      _identity(home),
      const SizedBox(height: 12),
      _scheduleCard(home),
      const SizedBox(height: 12),
      _stats(home),
      const SizedBox(height: 12),
    ];
  }

  List<Widget> _secondary(CustomerHome home) {
    return [
      _payments(home),
      const SizedBox(height: 16),
      _quickActions(),
      const SizedBox(height: 12),
      _bottles(),
      const SizedBox(height: 12),
      _upcoming(home),
    ];
  }

  Widget _header(String name, int unread) {
    final initial = name.trim().isEmpty ? 'C' : name.trim()[0].toUpperCase();
    return SizedBox(
      height: 188,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Positioned.fill(
            child: Image(image: AssetImage('assets/customer_home/images/customer_home_header_bg.png'), fit: BoxFit.cover, alignment: Alignment.topCenter),
          ),
          const Positioned(
            right: 0,
            bottom: -6,
            child: IgnorePointer(
              child: Image(image: AssetImage('assets/customer_home/images/water_jugs_header.png'), width: 168, height: 118, fit: BoxFit.contain),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Image.asset('assets/customer_home/branding/aquarider_logo.png', height: 36, fit: BoxFit.contain),
                    const Spacer(),
                    Material(
                      color: Colors.white,
                      shape: const CircleBorder(),
                      child: IconButton(
                        key: const Key('customer-notifications'),
                        tooltip: 'Notifications',
                        onPressed: () => widget.onOpen(const CustomerNotificationsScreen()),
                        style: IconButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(32, 32),
                          fixedSize: const Size(32, 32),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: Badge(
                          isLabelVisible: unread > 0,
                          label: Text('$unread'),
                          child: const Icon(Icons.notifications_none_rounded, color: _navy, size: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Material(
                      color: Colors.white,
                      shape: const CircleBorder(side: BorderSide(color: Color(0xFFD8E6F4))),
                      child: InkWell(
                        key: const Key('customer-open-profile'),
                        onTap: widget.onOpenProfile ?? () => widget.onOpen(CustomerProfileScreen(session: widget.session, onOpen: widget.onOpen)),
                        customBorder: const CircleBorder(),
                        child: SizedBox(
                          width: 32,
                          height: 32,
                          child: Center(child: Text(initial, style: customerType(13, FontWeight.w600, _navy))),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.only(right: 150),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text('Hello, $name', style: customerType(26, FontWeight.w700, _navy, height: 1.1)),
                      ),
                      Text('Welcome to your delivery dashboard.', style: customerType(13, FontWeight.w500, const Color(0xFF5C6E84))),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _identity(CustomerHome home) {
    final active = home.accountStatus.toLowerCase() == 'active';
    final schedules = home.activeSchedules;
    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFE5F8EC) : const Color(0xFFFFF4E5),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(active ? Icons.check_circle : Icons.info_outline, size: 14, color: active ? _ok : _warn),
          const SizedBox(width: 4),
          Text(active ? 'Active Account' : home.accountStatus, style: customerType(11, FontWeight.w600, active ? _ok : _warn)),
        ],
      ),
    );
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Customer ID: ${home.customerCode}', style: customerType(15, FontWeight.w700, _navy, height: 1.2)),
        const SizedBox(height: 4),
        Row(
          children: [
            Container(width: 7, height: 7, decoration: BoxDecoration(color: active ? _ok : _warn, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '${home.accountStatus} · $schedules active schedule${schedules == 1 ? '' : 's'}',
                style: customerType(12, FontWeight.w600, active ? _ok : customerStatusColor(home.accountStatus)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            const Icon(Icons.location_on_outlined, size: 14, color: _muted),
            const SizedBox(width: 4),
            Expanded(child: Text(home.city.isEmpty ? 'City is not stored yet.' : home.city, style: customerType(12, FontWeight.w400, _muted))),
          ],
        ),
        if (home.pendingRequests > 0)
          Text('${home.pendingRequests} request${home.pendingRequests == 1 ? '' : 's'} waiting for the office.', style: customerType(12, FontWeight.w700, _warn)),
      ],
    );
    return _panel(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final icon = Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: const Color(0xFFE8F4FF), borderRadius: BorderRadius.circular(16)),
            child: Image.asset('assets/customer_home/icons/ic_user.png', width: 28, height: 28, fit: BoxFit.contain),
          );
          if (constraints.maxWidth < 340) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [icon, const SizedBox(width: 12), Expanded(child: details)]),
                const SizedBox(height: 8),
                badge,
              ],
            );
          }
          return Row(
            children: [
              icon,
              const SizedBox(width: 12),
              Expanded(child: details),
              const SizedBox(width: 8),
              badge,
            ],
          );
        },
      ),
    );
  }

  Widget _scheduleCard(CustomerHome home) {
    final plan = home.subscription;
    final next = home.upcoming.isEmpty ? null : home.upcoming.first;
    return _panel(
      color: const Color(0xFFEFF7FF),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Image.asset('assets/customer_home/images/schedule_delivery_illustration.png', width: 108, height: 96, fit: BoxFit.contain),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(plan == null ? 'No Active Schedule' : plan.code, style: customerType(15, FontWeight.w700, _navy, height: 1.2)),
                const SizedBox(height: 4),
                Text(
                  plan == null ? home.linkMessage : '${plan.product} · ${plan.quantity} bottles · ${plan.frequency}',
                  style: customerType(12, FontWeight.w500, _muted, height: 1.3),
                ),
                if (plan != null) ...[
                  const SizedBox(height: 4),
                  Text('${plan.status} · ${plan.timeWindow}', style: customerType(12, FontWeight.w600, customerStatusColor(plan.status))),
                  if (next != null) Text('Next: ${next.weekday} ${next.date}', style: customerType(12, FontWeight.w600, _navy)),
                ],
                const SizedBox(height: 10),
                _gradientButton(const Key('customer-view-schedule'), 'View Schedule', 'assets/customer_home/icons/ic_calendar.png', _schedule),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stats(CustomerHome home) {
    final counts = home.overview;
    return LayoutBuilder(
      builder: (context, constraints) {
        final tiles = [
          _stat('assets/customer_home/icons/ic_truck.png', '${counts.total}', 'Total Deliveries', const Color(0xFFE8F4FF), _blue),
          _stat('assets/customer_home/icons/ic_check.png', '${counts.completed}', 'Completed', const Color(0xFFE7F8EE), _ok),
          _stat('assets/customer_home/icons/ic_calendar.png', '${counts.upcoming}', 'Upcoming', const Color(0xFFFFF6E8), _warn),
          _stat('assets/customer_home/icons/ic_minus.png', '${counts.skippedOrCancelled}', 'Skipped / Missed', const Color(0xFFFFEEF0), _bad),
        ];
        if (constraints.maxWidth < 280) {
          return Column(children: [for (final tile in tiles) Padding(padding: const EdgeInsets.only(bottom: 8), child: tile)]);
        }
        return Column(
          children: [
            Row(children: [Expanded(child: tiles[0]), const SizedBox(width: 8), Expanded(child: tiles[1])]),
            const SizedBox(height: 8),
            Row(children: [Expanded(child: tiles[2]), const SizedBox(width: 8), Expanded(child: tiles[3])]),
          ],
        );
      },
    );
  }

  Widget _stat(String icon, String value, String label, Color background, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFD8E6F4))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image.asset(icon, width: 24, height: 24, fit: BoxFit.contain),
          const SizedBox(height: 6),
          Text(value, style: customerType(22, FontWeight.w700, color, height: 1.05)),
          Text(label, style: customerType(12, FontWeight.w500, _muted, height: 1.2)),
        ],
      ),
    );
  }

  Widget _payments(CustomerHome home) {
    final money = home.payments;
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Image.asset('assets/customer_home/images/payments_wallet_illustration.png', width: 64, height: 56, fit: BoxFit.contain),
              const SizedBox(width: 8),
              Text('Payments', style: customerType(16, FontWeight.w700, _navy)),
            ],
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final cells = [
                _money('assets/customer_home/icons/ic_coins.png', 'Billed', money.totalBilled, _blue),
                _money('assets/customer_home/icons/ic_check.png', 'Paid', money.totalPaid, _ok),
                _money('assets/customer_home/icons/ic_payments.png', 'Outstanding', money.outstanding, _bad),
              ];
              if (constraints.maxWidth < 320) {
                return Column(children: [for (final cell in cells) Padding(padding: const EdgeInsets.only(bottom: 8), child: cell)]);
              }
              return Row(children: [for (final cell in cells) Expanded(child: cell)]);
            },
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: _gradientButton(
              const Key('customer-view-payments'),
              'View Payments',
              'assets/customer_home/icons/ic_payments.png',
              () => widget.onOpen(const CustomerPaymentsScreen(standalone: true)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _money(String icon, String label, num amount, Color color) {
    return Column(
      children: [
        Image.asset(icon, width: 20, height: 20, fit: BoxFit.contain),
        Text(label, style: customerType(12, FontWeight.w500, _muted)),
        FittedBox(fit: BoxFit.scaleDown, child: Text('PKR ${customerMoney(amount)}', style: customerType(13, FontWeight.w700, color))),
      ],
    );
  }

  Widget _quickActions() {
    final actions = <(String, String, VoidCallback)>[
      ('assets/customer_home/icons/ic_calendar.png', 'View Schedule', _schedule),
      ('assets/customer_home/icons/ic_history.png', 'Delivery History', () => widget.onOpen(const CustomerHistoryScreen())),
      ('assets/customer_home/icons/ic_schedule_edit.png', 'Request Schedule Change', () => widget.onOpen(const CustomerRequestForm(type: 'ScheduleChange'))),
      ('assets/customer_home/icons/ic_pause.png', 'Pause Deliveries', () => widget.onOpen(const CustomerRequestForm(type: 'Pause'))),
      ('assets/customer_home/icons/ic_requests.png', 'My Requests', () => widget.onOpen(const CustomerRequestsScreen())),
      ('assets/customer_home/icons/ic_location.png', 'Address Change', () => widget.onOpen(const CustomerRequestForm(type: 'AddressChange'))),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quick Actions', style: customerType(16, FontWeight.w700, _navy)),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 520 ? 3 : 2;
            return GridView.count(
              crossAxisCount: columns,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: columns == 3 ? 2.6 : 2.15,
              children: [for (final action in actions) _actionTile(action.$1, action.$2, action.$3)],
            );
          },
        ),
      ],
    );
  }

  Widget _actionTile(String icon, String label, VoidCallback onTap) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        key: Key('customer-action-${label.toLowerCase().replaceAll(' ', '-')}'),
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFD8E6F4))),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: const Color(0xFFE8F4FF), borderRadius: BorderRadius.circular(12)),
                child: Image.asset(icon, width: 22, height: 22, fit: BoxFit.contain),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(label, style: customerType(12, FontWeight.w600, _navy))),
              Image.asset('assets/customer_home/icons/ic_arrow_right.png', width: 16, height: 16, fit: BoxFit.contain),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bottles() {
    return Material(
      color: const Color(0xFFF4FAFF),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        key: const Key('customer-action-change-bottle-quantity'),
        borderRadius: BorderRadius.circular(20),
        onTap: () => widget.onOpen(const CustomerRequestForm(type: 'QuantityChange')),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFD8E6F4))),
          child: Row(
            children: [
              Image.asset('assets/customer_home/images/bottle_quantity_illustration.png', width: 78, height: 52, fit: BoxFit.contain),
              Container(width: 1, height: 36, margin: const EdgeInsets.symmetric(horizontal: 10), color: const Color(0xFFD8E6F4)),
              Expanded(child: Text('Change Bottle Quantity', style: customerType(14, FontWeight.w600, _navy))),
              Image.asset('assets/customer_home/icons/ic_arrow_right.png', width: 18, height: 18, fit: BoxFit.contain),
            ],
          ),
        ),
      ),
    );
  }

  Widget _upcoming(CustomerHome home) {
    if (home.upcoming.isEmpty) {
      return _panel(
        child: Row(
          children: [
            Image.asset('assets/customer_home/icons/ic_info.png', width: 22, height: 22, fit: BoxFit.contain),
            const SizedBox(width: 8),
            const Expanded(child: Text('No upcoming delivery is scheduled.', style: TextStyle(fontFamily: 'Noto Sans', fontSize: 13, fontWeight: FontWeight.w500, color: _muted))),
          ],
        ),
      );
    }
    return Column(
      children: [
        for (final visit in home.upcoming) ...[
          InkWell(
            onTap: () => widget.onOpen(CustomerVisitDetail(visit: visit)),
            child: _panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${visit.date} · ${visit.product}', style: customerType(15, FontWeight.w700, _navy)),
                  const SizedBox(height: 4),
                  Text('${visit.quantity} bottles · ${visit.addressLabel}', style: customerType(13, FontWeight.w500, _muted)),
                  Text('${visit.timeWindow} · ${visit.status}', style: customerType(13, FontWeight.w700, customerStatusColor(visit.status))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _gradientButton(Key key, String label, String icon, VoidCallback onTap) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: _blue,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: key,
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: SizedBox(
            height: 44,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(icon, width: 18, height: 18, fit: BoxFit.contain),
                const SizedBox(width: 8),
                Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: customerType(14, FontWeight.w600, Colors.white))),
                const SizedBox(width: 6),
                const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _panel({required Widget child, Color color = Colors.white}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD8E6F4)),
        boxShadow: const [BoxShadow(color: Color(0x120B4F93), blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: child,
    );
  }
}

class _CustomerNav extends StatelessWidget {
  const _CustomerNav({required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Material(
          color: Colors.white,
          elevation: 8,
          shadowColor: const Color(0x3310254A),
          borderRadius: BorderRadius.circular(28),
          child: SizedBox(
            height: 68,
            child: Row(
              children: [
                _item(0, 'assets/customer_home/icons/ic_home.png', 'assets/customer_home/icons/ic_home_active.png', 'Home', 'customer-tab-home'),
                _item(1, 'assets/customer_home/icons/ic_schedule.png', 'assets/customer_home/icons/ic_calendar.png', 'Schedule', 'customer-tab-schedule'),
                _item(2, 'assets/customer_home/icons/ic_payments.png', 'assets/customer_home/icons/ic_payments.png', 'Payments', 'customer-tab-payments'),
                _item(3, 'assets/customer_home/icons/ic_profile.png', 'assets/customer_home/icons/ic_user.png', 'Profile', 'customer-tab-profile'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _item(int value, String icon, String selected, String label, String keyName) {
    final active = index == value;
    return Expanded(
      child: InkWell(
        key: Key(keyName),
        onTap: () => onChanged(value),
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: active ? _blue : Colors.transparent, borderRadius: BorderRadius.circular(18)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(active ? selected : icon, width: 22, height: 22, fit: BoxFit.contain),
                Text(label, style: customerType(11, FontWeight.w600, active ? Colors.white : _navy, height: 1.1)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
