import 'package:flutter/material.dart';

import 'package:riderfrontend/api/route_api.dart';
import 'package:riderfrontend/customerApp/customer_request_screen.dart';
import 'package:riderfrontend/customerApp/customer_theme.dart';

const _navy = Color(0xFF102448);
const _blue = Color(0xFF0875E8);
const _muted = Color(0xFF6A7C90);
const _ok = Color(0xFF16834A);

class CustomerScheduleScreen extends StatefulWidget {
  const CustomerScheduleScreen({this.standalone = false, this.reloadToken = 0, super.key});

  final bool standalone;
  final int reloadToken;

  @override
  State<CustomerScheduleScreen> createState() => _CustomerScheduleScreenState();
}

class _CustomerScheduleScreenState extends State<CustomerScheduleScreen> {
  var _started = false;
  var _loading = true;
  String? _error;
  List<CustomerPlan> _plans = const [];
  String? _scheduleId;
  CustomerCalendar? _calendar;
  CustomerCalendarDay? _selected;
  CustomerVisit? _nextVisit;
  String _linkMessage = 'Your account is not linked to a delivery schedule.';
  int _unread = 0;
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _load();
  }

  @override
  void didUpdateWidget(covariant CustomerScheduleScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reloadToken != widget.reloadToken) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ApiScope.of(context);
      final plans = await api.customerSchedules();
      CustomerHome? home;
      try {
        home = await api.customerHome();
      } catch (_) {}
      if (!mounted) return;
      final selected = _scheduleId != null && plans.any((item) => item.scheduleId == _scheduleId)
          ? _scheduleId!
          : (plans.isEmpty ? null : plans.first.scheduleId);
      CustomerCalendar? calendar;
      if (selected != null) {
        calendar = await api.customerCalendar(selected, _month.year, _month.month);
      }
      if (!mounted) return;
      final upcoming = home?.upcoming ?? const <CustomerVisit>[];
      CustomerVisit? next;
      for (final visit in upcoming) {
        if (selected == null || visit.scheduleId.isEmpty || visit.scheduleId == selected) {
          next = visit;
          break;
        }
      }
      setState(() {
        _plans = plans;
        _scheduleId = selected;
        _calendar = calendar;
        _selected = null;
        _nextVisit = next;
        _unread = home?.unreadNotifications ?? 0;
        if (home != null && home.linkMessage.isNotEmpty) _linkMessage = home.linkMessage;
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

  CustomerPlan? get _plan {
    for (final plan in _plans) {
      if (plan.scheduleId == _scheduleId) return plan;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final plan = _plan;
    final body = LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 720;
        final landscape = constraints.maxHeight > 0 && constraints.maxWidth / constraints.maxHeight > 1.15;
        return Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Color(0xFFF2F8FE)),
            Positioned.fill(
              child: Image.asset(
                'assets/customer_home/schedule/schedule_bg.jpg',
                fit: BoxFit.cover,
                alignment: landscape ? Alignment.center : Alignment.topCenter,
              ),
            ),
            SafeArea(
              bottom: widget.standalone,
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: wide ? 980 : 560),
                  child: RefreshIndicator(
                    color: _blue,
                    onRefresh: _load,
                    child: ListView(
                      key: const Key('customer-schedule-screen'),
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(16, 8, 16, widget.standalone ? 24 : 12),
                      children: [
                        _header(),
                        const SizedBox(height: 8),
                        if (_loading) const LinearProgressIndicator(color: _blue, minHeight: 2),
                        if (_error != null) ...[
                          const SizedBox(height: 8),
                          Text(_error!, style: customerType(14, FontWeight.w600, const Color(0xFFDC2626))),
                          TextButton(onPressed: _load, child: const Text('Try again')),
                        ],
                        if (!_loading && _plans.isEmpty) ...[
                          const SizedBox(height: 12),
                          _emptyCard(),
                        ],
                        if (_plans.length > 1) ...[
                          const SizedBox(height: 12),
                          _schedulePicker(),
                        ],
                        if (plan != null) ...[
                          const SizedBox(height: 12),
                          if (wide)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 6, child: _activeCard(plan, compact: false)),
                                const SizedBox(width: 14),
                                Expanded(flex: 5, child: _calendarPanel()),
                              ],
                            )
                          else ...[
                            _activeCard(plan, compact: landscape),
                            const SizedBox(height: 14),
                            _calendarPanel(),
                          ],
                          const SizedBox(height: 14),
                          _requestActions(),
                        ],
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
    if (!widget.standalone) return body;
    return Scaffold(
      backgroundColor: const Color(0xFFF2F8FE),
      appBar: AppBar(backgroundColor: Colors.transparent, foregroundColor: _navy, elevation: 0, title: const Text('Schedule')),
      body: body,
    );
  }

  Widget _header() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Image.asset('assets/customer_home/branding/aquarider_logo.png', height: 36, fit: BoxFit.contain),
            const Spacer(),
            Material(
              color: Colors.white,
              elevation: 1,
              shadowColor: const Color(0x220875E8),
              shape: const CircleBorder(),
              child: IconButton(
                key: const Key('customer-schedule-notifications'),
                tooltip: 'Notifications',
                onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const CustomerNotificationsScreen())),
                style: IconButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(34, 34),
                  fixedSize: const Size(34, 34),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: Badge(
                  isLabelVisible: _unread > 0,
                  backgroundColor: const Color(0xFFE23B4A),
                  smallSize: 8,
                  child: const Icon(Icons.notifications_none_rounded, color: _navy, size: 18),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text('My Delivery Schedule', style: customerType(26, FontWeight.w800, _navy, height: 1.15)),
        const SizedBox(height: 4),
        Text('View and manage your recurring water deliveries.', style: customerType(14, FontWeight.w500, _muted)),
      ],
    );
  }

  Widget _schedulePicker() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x140875C8), blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: DropdownButtonFormField<String>(
        key: const Key('customer-schedule-picker'),
        initialValue: _scheduleId,
        decoration: const InputDecoration(border: InputBorder.none, labelText: 'Schedule'),
        items: [
          for (final item in _plans)
            DropdownMenuItem(value: item.scheduleId, child: Text('${item.code} · ${item.addressLabel} · ${item.status}')),
        ],
        onChanged: (value) {
          setState(() => _scheduleId = value);
          _load();
        },
      ),
    );
  }

  Widget _activeCard(CustomerPlan plan, {required bool compact}) {
    final active = plan.status.toLowerCase() == 'active';
    final days = _deliveryDays(plan.frequency);
    final bottles = _bottleLine(plan);
    final nextLabel = _nextDeliveryLabel(_nextVisit);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [BoxShadow(color: Color(0x180875C8), blurRadius: 20, offset: Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: const Color(0xFFE8F4FF), borderRadius: BorderRadius.circular(12)),
                  child: Image.asset('assets/customer_home/icons/ic_calendar.png', width: 20, height: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Active Schedule', style: customerType(16, FontWeight.w800, _navy)),
                      Text(plan.code.isEmpty ? 'Recurring delivery to your selected address' : plan.code, style: customerType(12, FontWeight.w500, _muted)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: active ? const Color(0xFFE6F7ED) : const Color(0xFFFFF4E5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(active ? Icons.check_circle : Icons.pause_circle_filled, size: 14, color: active ? _ok : const Color(0xFFE99A22)),
                      const SizedBox(width: 4),
                      Text(plan.status, style: customerType(12, FontWeight.w700, active ? _ok : const Color(0xFFE99A22))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: compact
                ? Column(
                    children: [
                      Image.asset('assets/customer_home/images/schedule_delivery_illustration.png', height: 96, fit: BoxFit.contain),
                      const SizedBox(height: 10),
                      _detailRows(plan, days, bottles),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Image.asset('assets/customer_home/images/schedule_delivery_illustration.png', width: 108, height: 112, fit: BoxFit.contain),
                      const SizedBox(width: 12),
                      Expanded(child: _detailRows(plan, days, bottles)),
                    ],
                  ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: const BoxDecoration(
              color: Color(0xFFEAF4FF),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
            ),
            child: Row(
              children: [
                Image.asset('assets/customer_home/icons/ic_truck.png', width: 18, height: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    nextLabel == null ? 'No upcoming delivery is scheduled.' : 'Next Delivery: $nextLabel',
                    style: customerType(13, FontWeight.w800, _blue),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.water_drop_outlined, size: 14, color: _blue),
                      const SizedBox(width: 4),
                      Text('${plan.quantity} Bottle${plan.quantity == 1 ? '' : 's'}', style: customerType(12, FontWeight.w700, _navy)),
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

  Widget _detailRows(CustomerPlan plan, String days, String bottles) {
    return Column(
      children: [
        _infoRow(Icons.calendar_month_outlined, 'Delivery Days', days),
        const SizedBox(height: 12),
        _infoRow(Icons.inventory_2_outlined, 'Bottle Quantity', bottles),
        const SizedBox(height: 12),
        _addressRow(plan),
        if (plan.timeWindow.isNotEmpty) ...[
          const SizedBox(height: 12),
          _infoRow(Icons.schedule_outlined, 'Time Window', plan.timeWindow),
        ],
      ],
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: const Color(0xFFE8F4FF), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 15, color: _blue),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: customerType(11, FontWeight.w600, _muted)),
              Text(value, style: customerType(14, FontWeight.w800, _navy, height: 1.25)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _addressRow(CustomerPlan plan) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: const Color(0xFFE8F4FF), borderRadius: BorderRadius.circular(8)),
          child: Image.asset('assets/customer_home/icons/ic_location.png', width: 15, height: 15),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text('Delivery Address', style: customerType(11, FontWeight.w600, _muted))),
                  TextButton(
                    key: const Key('customer-schedule-edit-address'),
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const CustomerRequestForm(type: 'AddressChange'))),
                    style: TextButton.styleFrom(
                      foregroundColor: _blue,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.edit_outlined, size: 13),
                        const SizedBox(width: 3),
                        Text('Edit', style: customerType(12, FontWeight.w700, _blue)),
                      ],
                    ),
                  ),
                ],
              ),
              Text(plan.addressLabel, style: customerType(14, FontWeight.w800, _navy, height: 1.2)),
              if (plan.address.isNotEmpty) Text(plan.address, style: customerType(12, FontWeight.w500, _muted, height: 1.3)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _calendarPanel() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [BoxShadow(color: Color(0x140875C8), blurRadius: 16, offset: Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 4,
            runSpacing: 4,
            children: [
              Text('Delivery Calendar', style: customerType(16, FontWeight.w800, _navy)),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(onPressed: () => _shift(-1), visualDensity: VisualDensity.compact, icon: const Icon(Icons.chevron_left, color: _navy)),
                  Text(_monthLabel(_month), style: customerType(13, FontWeight.w700, _navy)),
                  IconButton(onPressed: () => _shift(1), visualDensity: VisualDensity.compact, icon: const Icon(Icons.chevron_right, color: _navy)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              _Legend('Delivered', customerSuccess),
              _Legend('Upcoming', _blue),
              _Legend('Paused', customerWarning),
              _Legend('Skipped', customerWarning),
              _Legend('Cancelled', customerMuted),
            ],
          ),
          const SizedBox(height: 8),
          if (_calendar != null) _grid(_calendar!),
          if (_selected != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFF4F9FF), borderRadius: BorderRadius.circular(14)),
              child: _selected!.items.isEmpty
                  ? Text('No delivery is scheduled for ${_selected!.date}.', style: customerType(13, FontWeight.w600, _navy))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final item in _selected!.items)
                          InkWell(
                            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => CustomerVisitDetail(visit: item))),
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                '${item.date} · ${item.reference}\n${item.product} · ${item.quantity}\n${item.addressLabel}: ${item.address}\n${item.timeWindow} · ${item.status}',
                                style: customerType(13, FontWeight.w600, _navy),
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _requestActions() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            key: const Key('customer-request-schedule-change'),
            style: FilledButton.styleFrom(
              backgroundColor: _blue,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const CustomerRequestForm(type: 'ScheduleChange'))),
            child: const Text('Request Schedule Change'),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const CustomerRequestForm(type: 'Pause'))),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _navy,
                  side: const BorderSide(color: Color(0xFFB7D6F5)),
                  minimumSize: const Size(0, 44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Request Pause'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const CustomerRequestForm(type: 'QuantityChange'))),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _navy,
                  side: const BorderSide(color: Color(0xFFB7D6F5)),
                  minimumSize: const Size(0, 44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Change Quantity'),
              ),
            ),
          ],
        ),
        TextButton(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const CustomerHistoryScreen())),
          child: Text('View delivery history', style: customerType(13, FontWeight.w700, _blue)),
        ),
      ],
    );
  }

  Widget _emptyCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [BoxShadow(color: Color(0x180875C8), blurRadius: 20, offset: Offset(0, 8))],
      ),
      child: Column(
        children: [
          const _EmptyScheduleArt(),
          const SizedBox(height: 14),
          Text('No Delivery Schedule Yet', textAlign: TextAlign.center, style: customerType(18, FontWeight.w800, _navy)),
          const SizedBox(height: 6),
          Text(_linkMessage, textAlign: TextAlign.center, style: customerType(13, FontWeight.w500, _muted)),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              key: const Key('customer-schedule-contact-support'),
              onPressed: _contactSupport,
              icon: const Icon(Icons.headset_mic_outlined, size: 18),
              label: const Text('Contact Support'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _blue,
                side: const BorderSide(color: _blue, width: 1.4),
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _contactSupport() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Contact Support', style: customerType(18, FontWeight.w800, _navy)),
              const SizedBox(height: 8),
              Text(_linkMessage, style: customerType(14, FontWeight.w500, _muted)),
              const SizedBox(height: 8),
              Text('A schedule appears here after the office links your account and creates a recurring delivery plan.', style: customerType(13, FontWeight.w500, _muted)),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const CustomerRequestForm(type: 'ScheduleChange')));
                  },
                  style: FilledButton.styleFrom(backgroundColor: _blue, minimumSize: const Size(double.infinity, 46)),
                  child: const Text('Request a schedule review'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _shift(int months) {
    setState(() => _month = DateTime(_month.year, _month.month + months));
    _load();
  }

  Widget _grid(CustomerCalendar calendar) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: calendar.days.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, mainAxisExtent: 46),
      itemBuilder: (context, index) {
        final day = calendar.days[index];
        final date = DateTime.tryParse(day.date);
        final color = day.count == 0 ? _muted : customerStatusColor(day.status);
        final selected = _selected?.date == day.date;
        return InkWell(
          key: Key('customer-day-${day.date}'),
          borderRadius: BorderRadius.circular(10),
          onTap: () => setState(() => _selected = day),
          child: Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFFE8F4FF) : null,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('${date?.day ?? ''}', style: customerType(13, FontWeight.w700, color)),
                if (day.count > 0) Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              ],
            ),
          ),
        );
      },
    );
  }

  String _monthLabel(DateTime value) {
    const names = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    return '${names[value.month - 1]} ${value.year}';
  }

  String _deliveryDays(String frequency) {
    final value = frequency.trim();
    if (value.toLowerCase().startsWith('weekly on ')) return value.substring(10);
    if (value.isEmpty) return 'Not set by office yet';
    return value;
  }

  String _bottleLine(CustomerPlan plan) {
    final unit = plan.product.toLowerCase().contains('19')
        ? '19 L each'
        : (plan.product.isEmpty ? 'per delivery' : plan.product);
    return '${plan.quantity} Bottle${plan.quantity == 1 ? '' : 's'} ($unit)';
  }

  String? _nextDeliveryLabel(CustomerVisit? visit) {
    if (visit == null) return null;
    final date = DateTime.tryParse(visit.date);
    final weekday = visit.weekday.isEmpty
        ? (date == null ? '' : _weekdayShort(date.weekday))
        : (visit.weekday.length <= 3 ? visit.weekday : visit.weekday.substring(0, 3));
    if (date == null) return '$weekday ${visit.date}'.trim();
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '$weekday, ${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _weekdayShort(int weekday) {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return names[(weekday - 1).clamp(0, 6)];
  }
}

class _EmptyScheduleArt extends StatelessWidget {
  const _EmptyScheduleArt();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      height: 110,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(left: 18, top: 18, child: _cloud(34)),
          Positioned(right: 16, top: 12, child: _cloud(28)),
          Positioned(right: 28, bottom: 18, child: _cloud(22)),
          Container(
            width: 72,
            height: 78,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F4FF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFB7D6F5)),
              boxShadow: const [BoxShadow(color: Color(0x220875E8), blurRadius: 12, offset: Offset(0, 6))],
            ),
            child: Column(
              children: [
                Container(
                  height: 16,
                  decoration: const BoxDecoration(
                    color: Color(0xFF0875E8),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(13)),
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 3,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                    children: [
                      for (var i = 0; i < 6; i++)
                        Container(
                          decoration: BoxDecoration(
                            color: i == 2 ? const Color(0xFF0875E8) : const Color(0xFFD6E9FB),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: i == 2 ? const Icon(Icons.water_drop, size: 12, color: Colors.white) : null,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _cloud(double size) {
    return Container(
      width: size,
      height: size * 0.55,
      decoration: BoxDecoration(color: const Color(0xFFD9ECFF), borderRadius: BorderRadius.circular(20)),
    );
  }
}

class CustomerHistoryScreen extends StatefulWidget {
  const CustomerHistoryScreen({super.key});

  @override
  State<CustomerHistoryScreen> createState() => _CustomerHistoryScreenState();
}

class _CustomerHistoryScreenState extends State<CustomerHistoryScreen> {
  var _started = false;
  var _loading = true;
  String? _error;
  var _status = 'all';
  String? _scheduleId;
  List<CustomerPlan> _plans = const [];
  final _from = TextEditingController();
  final _to = TextEditingController();
  List<CustomerVisit> _rows = const [];

  @override
  void dispose() {
    _from.dispose();
    _to.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final api = ApiScope.of(context);
      final plans = await api.customerSchedules();
      final rows = await api.customerHistory(
        status: _status,
        scheduleId: _scheduleId,
        from: _from.text.trim().isEmpty ? null : _from.text.trim(),
        to: _to.text.trim().isEmpty ? null : _to.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _plans = plans;
        _rows = rows;
        _loading = false;
        _error = null;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('customer-history-screen'),
      backgroundColor: customerPage,
      appBar: AppBar(backgroundColor: customerPage, foregroundColor: customerNavy, elevation: 0, title: const Text('Delivery History')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Review your previous deliveries. Completed visits stay as they were recorded.', style: customerType(13, FontWeight.w500, customerMuted)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _summary('Total', _rows.length),
                  _summary('Delivered', _rows.where((item) => item.status == 'Delivered').length),
                  _summary('Missed', _rows.where((item) => item.status == 'Missed').length),
                  _summary('Skipped or cancelled', _rows.where((item) => item.status == 'Skipped' || item.status == 'Cancelled').length),
                ],
              ),
              const SizedBox(height: 12),
              TextField(controller: _from, decoration: customerField('From date', hint: 'YYYY-MM-DD'), onSubmitted: (_) => _load()),
              const SizedBox(height: 8),
              TextField(controller: _to, decoration: customerField('To date', hint: 'YYYY-MM-DD'), onSubmitted: (_) => _load()),
              const SizedBox(height: 8),
              if (_plans.isNotEmpty)
                DropdownButtonFormField<String>(
                  initialValue: _scheduleId ?? 'all',
                  decoration: customerField('Schedule'),
                  items: [
                    const DropdownMenuItem(value: 'all', child: Text('All schedules')),
                    for (final plan in _plans) DropdownMenuItem(value: plan.scheduleId, child: Text('${plan.code} · ${plan.addressLabel}')),
                  ],
                  onChanged: (value) {
                    setState(() => _scheduleId = value == 'all' ? null : value);
                    _load();
                  },
                ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                key: const Key('customer-history-status'),
                initialValue: _status,
                decoration: customerField('Status'),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All')),
                  DropdownMenuItem(value: 'Scheduled', child: Text('Scheduled')),
                  DropdownMenuItem(value: 'Assigned', child: Text('Assigned')),
                  DropdownMenuItem(value: 'Out for Delivery', child: Text('Out for Delivery')),
                  DropdownMenuItem(value: 'Delivered', child: Text('Delivered')),
                  DropdownMenuItem(value: 'Missed', child: Text('Missed')),
                  DropdownMenuItem(value: 'Skipped', child: Text('Skipped')),
                  DropdownMenuItem(value: 'Cancelled', child: Text('Cancelled')),
                  DropdownMenuItem(value: 'Paused', child: Text('Paused')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _status = value);
                  _load();
                },
              ),
              const SizedBox(height: 12),
              if (_loading) const LinearProgressIndicator(color: customerPrimary),
              if (_error != null) Text(_error!, style: customerType(14, FontWeight.w600, customerError)),
              if (!_loading && _rows.isEmpty) const CustomerCard(child: Text('No deliveries match this filter.')),
              for (final row in _rows) ...[
                InkWell(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => CustomerVisitDetail(visit: row))),
                  child: CustomerCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${row.reference} · ${row.date}', style: customerType(15, FontWeight.w700, customerNavy)),
                        Text('${row.product} · ${row.quantity} bottles', style: customerType(14, FontWeight.w600, customerNavy)),
                        Text('${row.addressLabel} · ${row.timeWindow}', style: customerType(13, FontWeight.w500, customerMuted)),
                        Text(row.status, style: customerType(13, FontWeight.w700, customerStatusColor(row.status))),
                        Text(row.addressFromSnapshot ? row.address : 'Address saved with this visit was not stored. Current route address: ${row.address}', style: customerType(12, FontWeight.w500, customerMuted)),
                        Text(row.completedAt == null ? 'Completion time is not stored for this visit.' : 'Signed ${row.completedAt}', style: customerType(12, FontWeight.w500, customerMuted)),
                        if (row.proof != null) Text(row.proof!, style: customerType(12, FontWeight.w600, customerNavy)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _summary(String label, int value) {
    return SizedBox(
      width: 150,
      child: CustomerCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$value', style: customerType(20, FontWeight.w700, customerNavy)),
            Text(label, style: customerType(12, FontWeight.w600, customerMuted)),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend(this.label, this.color);

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: customerType(12, FontWeight.w600, customerMuted)),
      ],
    );
  }
}

class CustomerVisitDetail extends StatelessWidget {
  const CustomerVisitDetail({required this.visit, super.key});

  final CustomerVisit visit;

  @override
  Widget build(BuildContext context) {
    final reached = switch (visit.status) {
      'Assigned' => 2,
      'Out for Delivery' => 3,
      'Delivered' => 4,
      _ => 1,
    };
    const stages = ['Scheduled', 'Assigned to Rider', 'Out for Delivery', 'Delivered'];
    return Scaffold(
      key: const Key('customer-visit-detail'),
      backgroundColor: customerPage,
      appBar: AppBar(backgroundColor: customerPage, foregroundColor: customerNavy, elevation: 0, title: const Text('Delivery')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          CustomerCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(visit.reference, style: customerType(18, FontWeight.w700, customerNavy)),
                if (visit.scheduleCode.isNotEmpty) Text('Schedule ${visit.scheduleCode}', style: customerType(13, FontWeight.w600, customerMuted)),
                const SizedBox(height: 8),
                Text('${visit.weekday} ${visit.date} · ${visit.timeWindow}', style: customerType(15, FontWeight.w700, customerNavy)),
                Text('${visit.product} · ${visit.quantity} bottles', style: customerType(14, FontWeight.w600, customerNavy)),
                Text('${visit.addressLabel}: ${visit.address}', style: customerType(14, FontWeight.w500, customerNavy)),
                if (!visit.addressFromSnapshot) Text('This visit has no saved address. The line above is the current route address.', style: customerType(12, FontWeight.w500, customerMuted)),
                if (visit.instructions != null && visit.instructions!.isNotEmpty) Text(visit.instructions!, style: customerType(13, FontWeight.w500, customerMuted)),
                const SizedBox(height: 8),
                Text(visit.status, style: customerType(14, FontWeight.w700, customerStatusColor(visit.status))),
                Text(visit.completedAt == null ? 'Completion time is not stored for this visit.' : 'Signed ${visit.completedAt}', style: customerType(12, FontWeight.w500, customerMuted)),
                if (visit.proof != null) Text(visit.proof!, style: customerType(13, FontWeight.w600, customerNavy)),
              ],
            ),
          ),
          if (visit.status == 'Scheduled' || visit.status == 'Assigned' || visit.status == 'Out for Delivery' || visit.status == 'Delivered') ...[
            const SizedBox(height: 12),
            CustomerCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Status', style: customerType(16, FontWeight.w700, customerNavy)),
                  const SizedBox(height: 8),
                  for (var index = 0; index < stages.length; index++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text('${index < reached ? '●' : '○'} ${stages[index]}', style: customerType(14, FontWeight.w600, index < reached ? customerNavy : customerMuted)),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
