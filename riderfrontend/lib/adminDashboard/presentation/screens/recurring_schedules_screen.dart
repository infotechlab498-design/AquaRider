import 'package:flutter/material.dart';

import 'package:riderfrontend/adminDashboard/data/recurring_schedule_models.dart';
import 'package:riderfrontend/adminDashboard/presentation/admin_load.dart';
import 'package:riderfrontend/adminDashboard/presentation/admin_nav.dart';
import 'package:riderfrontend/adminDashboard/presentation/widgets/admin_shell.dart';
import 'package:riderfrontend/adminDashboard/theme/admin_tokens.dart';
import 'package:riderfrontend/api/route_api.dart';

class RecurringSchedulesScreen extends StatefulWidget {
  const RecurringSchedulesScreen({required this.onNavigate, this.session, super.key});

  final AuthSession? session;
  final ValueChanged<String> onNavigate;

  @override
  State<RecurringSchedulesScreen> createState() => _RecurringSchedulesScreenState();
}

class _RecurringSchedulesScreenState extends State<RecurringSchedulesScreen> {
  final _search = TextEditingController();
  final _query = TextEditingController();
  var _started = false;
  var _loading = true;
  var _busy = false;
  var _page = 1;
  var _tab = 'all';
  String? _depotId;
  String? _error;
  RecurringBoard? _board;
  _Pane _pane = _Pane.directory;
  RecurringScheduleDetail? _editing;
  ScheduleCalendar? _calendar;
  ScheduleCalendarDay? _selectedDay;
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

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
    _query.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final api = ApiScope.of(context);
    final loaded = await guardAdminLoad(
      () => api.recurringSchedules(
        search: _query.text.trim(),
        tab: _tab,
        depotId: _depotId,
        page: _page,
      ),
    );
    if (!mounted) return;
    setState(() {
      _board = loaded.value;
      _error = loaded.error;
      _loading = false;
    });
  }

  Future<void> _openCalendar({String? scheduleId}) async {
    setState(() {
      _pane = _Pane.calendar;
      _loading = true;
      _selectedDay = null;
    });
    final api = ApiScope.of(context);
    final loaded = await guardAdminLoad(
      () => api.recurringCalendar(year: _month.year, month: _month.month, scheduleId: scheduleId),
    );
    if (!mounted) return;
    setState(() {
      _calendar = loaded.value;
      _error = loaded.error;
      _loading = false;
    });
  }

  Future<void> _onSaved(RecurringScheduleDetail detail, String message, {required bool activated}) async {
    if (activated) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Schedule activated'),
          content: Text('${detail.scheduleCode} for ${detail.customerName} is active. The directory is up to date.'),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Back to directory'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      setState(() {
        _pane = _Pane.directory;
        _editing = null;
      });
    } else {
      setState(() => _editing = detail);
      showAdminNotice(context, message);
    }
    await _reload();
  }

  Future<void> _act(Future<RecurringScheduleDetail> Function() call, String fallback) async {
    setState(() => _busy = true);
    final loaded = await guardAdminLoad(call);
    if (!mounted) return;
    setState(() => _busy = false);
    showAdminNotice(context, loaded.error ?? fallback);
    if (loaded.value != null) {
      setState(() {
        _editing = loaded.value;
        _pane = _Pane.editor;
      });
    }
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final board = _board;
    return AdminShell(
      screenKey: const Key('recurring-schedules-screen'),
      session: widget.session,
      activeKey: AdminNav.recurringSchedules,
      serverReachable: _error == null || board != null,
      search: _search,
      onSearch: (_) {},
      searchHint: 'Search schedules',
      onNavigate: widget.onNavigate,
      trailing: IconButton(
        tooltip: 'Refresh',
        onPressed: _loading ? null : _reload,
        icon: const Icon(Icons.refresh, color: AdminTokens.secondary),
      ),
      body: _loading && board == null && _pane == _Pane.directory
          ? const AdminLoadingPane(label: 'Loading recurring schedules…')
          : ListView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              children: [
                _title(),
                if (_error != null) _banner(_error!),
                const SizedBox(height: 12),
                if (_pane == _Pane.directory) ..._directory(board),
                if (_pane == _Pane.editor)
                  _Editor(
                    detail: _editing,
                    busy: _busy,
                    onClose: () => setState(() => _pane = _Pane.directory),
                    onSaved: _onSaved,
                  ),
                if (_pane == _Pane.calendar) ..._calendarPane(),
              ],
            ),
    );
  }

  Widget _title() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Recurring Delivery Schedule Planner', style: adminType(26, FontWeight.w700, AdminTokens.text, height: 1.2)),
            const SizedBox(height: 6),
            SizedBox(
              width: 640,
              child: Text(
                'Plan customer deliveries weekly or monthly, assign riders, and publish the day’s delivery onto the rider’s route.',
                style: adminType(13.5, FontWeight.w500, AdminTokens.textSecondary),
              ),
            ),
          ],
        ),
        FilledButton.icon(
          key: const Key('recurring-create'),
          onPressed: () => setState(() {
            _editing = null;
            _pane = _Pane.editor;
          }),
          style: FilledButton.styleFrom(
            backgroundColor: AdminTokens.button,
            foregroundColor: Colors.white,
            minimumSize: const Size(0, 40),
          ),
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Create Schedule'),
        ),
        OutlinedButton.icon(
          key: const Key('recurring-calendar'),
          onPressed: () => _openCalendar(),
          icon: const Icon(Icons.calendar_month_outlined, size: 16),
          label: const Text('Schedule Calendar'),
        ),
        if (_pane != _Pane.directory)
          TextButton(onPressed: () => setState(() => _pane = _Pane.directory), child: const Text('Back to directory')),
      ],
    );
  }

  List<Widget> _directory(RecurringBoard? board) {
    final tabs = board?.tabs ?? RecurringTabCounts.empty;
    return [
      const SizedBox(height: 8),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _kpi('Active plans', board?.activePlans, 'all', const Key('kpi-active')),
          _kpi('Deliveries this month', board?.deliveriesThisMonth, 'all', const Key('kpi-month')),
          _kpi('Paused', board?.paused, 'paused', const Key('kpi-paused')),
          _kpi('Unassigned', board?.unassigned, 'unassigned', const Key('kpi-unassigned')),
          _kpi('Riders assigned', board?.ridersAssigned, 'all', const Key('kpi-riders')),
        ],
      ),
      const SizedBox(height: 14),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _tabChip('All', tabs.all, 'all'),
          _tabChip('Weekly', tabs.weekly, 'weekly'),
          _tabChip('Monthly', tabs.monthly, 'monthly'),
          _tabChip('Paused', tabs.paused, 'paused'),
          _tabChip('Expiring', tabs.expiring, 'expiring'),
          _tabChip('Exceptions', tabs.exceptions, 'exceptions'),
          _tabChip('Unassigned', tabs.unassigned, 'unassigned'),
        ],
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 280,
            child: TextField(
              key: const Key('recurring-search'),
              controller: _query,
              decoration: const InputDecoration(isDense: true, labelText: 'Customer, phone, schedule, or rider'),
              onSubmitted: (_) {
                _page = 1;
                _reload();
              },
            ),
          ),
          SizedBox(
            width: 220,
            child: DropdownButtonFormField<String>(
              key: ValueKey('depot-${_depotId ?? 'all'}'),
              initialValue: _depotId,
              isExpanded: true,
              decoration: const InputDecoration(isDense: true, labelText: 'Warehouse'),
              items: [
                const DropdownMenuItem(value: null, child: Text('All warehouses')),
                for (final depot in board?.depots ?? const <ScheduleDepotOption>[])
                  DropdownMenuItem(value: depot.id, child: Text(depot.name, overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (value) => setState(() => _depotId = value),
            ),
          ),
          FilledButton(
            onPressed: () {
              _page = 1;
              _reload();
            },
            child: const Text('Apply'),
          ),
          TextButton(
            onPressed: () {
              _query.clear();
              _depotId = null;
              _tab = 'all';
              _page = 1;
              _reload();
            },
            child: const Text('Reset'),
          ),
        ],
      ),
      const SizedBox(height: 12),
      if (board == null)
        const SizedBox.shrink()
      else if (board.rows.isEmpty)
        Text('No recurring schedules are saved.', style: adminType(14, FontWeight.w600, AdminTokens.textSecondary))
      else
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingTextStyle: adminType(12, FontWeight.w700, AdminTokens.textSecondary),
            dataTextStyle: adminType(13, FontWeight.w500, AdminTokens.text),
            columns: const [
              DataColumn(label: Text('Schedule')),
              DataColumn(label: Text('Customer')),
              DataColumn(label: Text('Address')),
              DataColumn(label: Text('Product')),
              DataColumn(label: Text('Qty')),
              DataColumn(label: Text('Frequency')),
              DataColumn(label: Text('This month')),
              DataColumn(label: Text('Rider')),
              DataColumn(label: Text('Next')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Actions')),
            ],
            rows: [
              for (final row in board.rows)
                DataRow(cells: [
                  DataCell(Text(row.scheduleCode)),
                  DataCell(Text('${row.customerName}\n${row.customerCode}')),
                  DataCell(SizedBox(width: 180, child: Text(row.address))),
                  DataCell(SizedBox(width: 180, child: Text(row.productSummary))),
                  DataCell(Text('${row.quantityPerVisit}')),
                  DataCell(Text(row.frequency)),
                  DataCell(Text('${row.monthlyCount}')),
                  DataCell(Text(row.riderName == null ? 'Unassigned' : '${row.riderName} · ${row.riderCode ?? ''}')),
                  DataCell(Text(row.nextDate ?? '—')),
                  DataCell(Text(row.status)),
                  DataCell(_rowMenu(row)),
                ]),
            ],
          ),
        ),
      if (board != null && board.total > board.pageSize)
        Row(
          children: [
            TextButton(onPressed: _page > 1 ? () { _page -= 1; _reload(); } : null, child: const Text('Previous')),
            Text('Page $_page'),
            TextButton(onPressed: _page * board.pageSize < board.total ? () { _page += 1; _reload(); } : null, child: const Text('Next')),
          ],
        ),
    ];
  }

  Widget _kpi(String label, int? value, String tab, Key key) {
    return InkWell(
      key: key,
      onTap: value == null
          ? null
          : () {
              _tab = tab;
              _page = 1;
              _reload();
            },
      child: Container(
        width: 180,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AdminTokens.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AdminTokens.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: adminType(12, FontWeight.w600, AdminTokens.textSecondary)),
            const SizedBox(height: 6),
            Text(value == null ? '—' : '$value', style: adminType(22, FontWeight.w700, AdminTokens.text)),
          ],
        ),
      ),
    );
  }

  Widget _tabChip(String label, int count, String id) {
    final selected = _tab == id;
    return ChoiceChip(
      label: Text('$label · $count'),
      selected: selected,
      onSelected: (_) {
        _tab = id;
        _page = 1;
        _reload();
      },
    );
  }

  Widget _link(String label, VoidCallback onTap) {
    return TextButton(onPressed: _busy ? null : onTap, child: Text(label));
  }

  Widget _rowMenu(RecurringScheduleRow row) {
    return PopupMenuButton<String>(
      key: Key('schedule-actions-${row.id}'),
      tooltip: 'Actions',
      enabled: !_busy,
      padding: EdgeInsets.zero,
      icon: const Icon(Icons.more_vert, color: AdminTokens.button),
      onSelected: (action) => _runRowAction(row, action),
      itemBuilder: (context) => [
        _menuItem('view', Icons.visibility_outlined, 'View'),
        _menuItem('edit', Icons.edit_outlined, 'Edit'),
        _menuItem('pause', Icons.pause_circle_outline, 'Pause'),
        _menuItem('resume', Icons.play_circle_outline, 'Resume'),
        _menuItem('duplicate', Icons.copy_outlined, 'Duplicate'),
        _menuItem('calendar', Icons.calendar_month_outlined, 'Calendar'),
        _menuItem('cancel', Icons.cancel_outlined, 'Cancel', color: AdminTokens.error),
      ],
    );
  }

  PopupMenuItem<String> _menuItem(String value, IconData icon, String label, {Color? color}) {
    final ink = color ?? AdminTokens.text;
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 18, color: color ?? AdminTokens.button),
          const SizedBox(width: 10),
          Text(label, style: adminType(14, FontWeight.w600, ink)),
        ],
      ),
    );
  }

  void _runRowAction(RecurringScheduleRow row, String action) {
    final api = ApiScope.of(context);
    switch (action) {
      case 'view':
      case 'edit':
        _load(row.id);
      case 'pause':
        _pause(row);
      case 'resume':
        _confirm('Resume ${row.scheduleCode}?', () => api.resumeRecurringSchedule(row.id), 'Schedule resumed.');
      case 'duplicate':
        _confirm('Copy ${row.scheduleCode} as a draft?', () => api.duplicateRecurringSchedule(row.id), 'A draft copy was saved.');
      case 'calendar':
        _openCalendar(scheduleId: row.id);
      case 'cancel':
        _cancel(row);
    }
  }

  Future<void> _load(String id) async {
    final loaded = await guardAdminLoad(() => ApiScope.of(context).recurringSchedule(id));
    if (!mounted) return;
    if (loaded.value == null) {
      showAdminNotice(context, loaded.error ?? 'Schedule not found.');
      return;
    }
    setState(() {
      _editing = loaded.value;
      _pane = _Pane.editor;
    });
  }

  Future<void> _confirm(String message, Future<RecurringScheduleDetail> Function() call, String fallback) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm'),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Back')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Continue')),
        ],
      ),
    );
    if (yes == true) await _act(call, fallback);
  }

  Future<void> _pause(RecurringScheduleRow row) async {
    final reason = TextEditingController();
    final start = TextEditingController();
    final end = TextEditingController();
    var range = false;
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text('Pause ${row.scheduleCode}'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${row.customerName} · ${row.riderName ?? 'No rider'}'),
                const SizedBox(height: 8),
                TextField(controller: reason, decoration: const InputDecoration(labelText: 'Reason')),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: range,
                  onChanged: (value) => setLocal(() => range = value ?? false),
                  title: const Text('Pause a date range only'),
                ),
                if (range) ...[
                  TextField(controller: start, decoration: const InputDecoration(labelText: 'Start yyyy-MM-dd')),
                  TextField(controller: end, decoration: const InputDecoration(labelText: 'End yyyy-MM-dd')),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Back')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Pause')),
          ],
        ),
      ),
    );
    if (saved != true || !mounted) return;
    await _act(
      () => ApiScope.of(context).pauseRecurringSchedule(
        row.id,
        reason: reason.text,
        startDate: range ? start.text.trim() : null,
        endDate: range ? end.text.trim() : null,
      ),
      'Schedule paused.',
    );
  }

  Future<void> _cancel(RecurringScheduleRow row) async {
    final reason = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Cancel ${row.scheduleCode}'),
        content: TextField(controller: reason, decoration: const InputDecoration(labelText: 'Reason')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Back')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Cancel schedule')),
        ],
      ),
    );
    if (saved != true || !mounted) return;
    await _act(() => ApiScope.of(context).cancelRecurringSchedule(row.id, reason: reason.text), 'Schedule cancelled.');
  }

  List<Widget> _calendarPane() {
    final calendar = _calendar;
    final days = calendar?.days ?? const <ScheduleCalendarDay>[];
    final first = days.isEmpty ? _month : DateTime.parse(days.first.date);
    final lead = first.weekday % 7;
    const names = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    return [
      Container(
        padding: const EdgeInsets.fromLTRB(8, 6, 12, 10),
        decoration: BoxDecoration(
          color: AdminTokens.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AdminTokens.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(visualDensity: VisualDensity.compact, onPressed: () => _shiftMonth(-1), icon: const Icon(Icons.chevron_left)),
                Text('${_monthName(_month.month)} ${_month.year}', style: adminType(16, FontWeight.w700, AdminTokens.text)),
                IconButton(visualDensity: VisualDensity.compact, onPressed: () => _shiftMonth(1), icon: const Icon(Icons.chevron_right)),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    _month = DateTime(DateTime.now().year, DateTime.now().month);
                    _openCalendar();
                  },
                  child: const Text('This month'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final status in const ['Scheduled', 'Published', 'Completed', 'Paused', 'Cancelled'])
                  _legend(status),
              ],
            ),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                const gap = 4.0;
                final cellWidth = (constraints.maxWidth - gap * 6) / 7;
                return Column(
                  children: [
                    SizedBox(
                      height: 22,
                      child: Row(
                        children: [
                          for (final name in names)
                            Expanded(
                              child: Center(child: Text(name, style: adminType(11, FontWeight.w700, AdminTokens.textSecondary))),
                            ),
                        ],
                      ),
                    ),
                    GridView.count(
                      crossAxisCount: 7,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: gap,
                      crossAxisSpacing: gap,
                      childAspectRatio: cellWidth / 58,
                      children: [
                        for (var i = 0; i < lead; i++) const SizedBox.shrink(),
                        for (final day in days) _dayCell(day),
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
      if (_selectedDay != null) _dayPanel(_selectedDay!),
    ];
  }

  Widget _legend(String status) {
    final paint = _paint(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: paint.fill, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 7, height: 7, decoration: BoxDecoration(color: paint.ink, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(status, style: adminType(11, FontWeight.w700, paint.ink)),
        ],
      ),
    );
  }

  Widget _dayCell(ScheduleCalendarDay day) {
    final selected = _selectedDay?.date == day.date;
    final number = day.date.length >= 10 ? day.date.substring(8) : day.date;
    final today = day.date == _iso(DateTime.now());
    final statuses = day.items.map((item) => item.status).toSet().take(4).toList();
    final dominant = day.items.isEmpty ? '' : day.items.first.status;
    final paint = _paint(dominant);
    return Material(
      color: day.deliveries == 0 ? const Color(0xFFF8FAFC) : paint.fill,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => setState(() => _selectedDay = day),
        child: Container(
          padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: selected ? paint.ink : const Color(0xFFE6EDF5), width: selected ? 1.6 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 18,
                    height: 18,
                    alignment: Alignment.center,
                    decoration: today ? BoxDecoration(color: AdminTokens.button, shape: BoxShape.circle) : null,
                    child: Text(number, style: adminType(11, FontWeight.w700, today ? Colors.white : AdminTokens.text)),
                  ),
                  const Spacer(),
                  if (day.deliveries > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(color: paint.ink, borderRadius: BorderRadius.circular(8)),
                      child: Text('${day.deliveries}', style: adminType(10, FontWeight.w700, Colors.white)),
                    ),
                ],
              ),
              const Spacer(),
              if (statuses.isNotEmpty)
                Row(
                  children: [
                    for (final status in statuses) ...[
                      Container(width: 6, height: 6, decoration: BoxDecoration(color: _paint(status).ink, shape: BoxShape.circle)),
                      const SizedBox(width: 3),
                    ],
                    if (day.bottles > 0)
                      Flexible(
                        child: Text('${day.bottles}', maxLines: 1, overflow: TextOverflow.ellipsis, style: adminType(10, FontWeight.w600, paint.ink)),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dayPanel(ScheduleCalendarDay day) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AdminTokens.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AdminTokens.line)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(day.date, style: adminType(15, FontWeight.w700, AdminTokens.text)),
          Text(
            day.deliveries == 0 ? 'No deliveries on this date.' : '${day.deliveries} deliveries · ${day.bottles} units',
            style: adminType(12.5, FontWeight.w600, AdminTokens.textSecondary),
          ),
          for (final item in day.items) _occurrence(item),
        ],
      ),
    );
  }

  Widget _occurrence(ScheduleCalendarItem item) {
    final paint = _paint(item.status);
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
      decoration: BoxDecoration(
        color: paint.fill,
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: paint.ink, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('${item.customerName} · ${item.customerCode}', style: adminType(13.5, FontWeight.w700, AdminTokens.text))),
              Text(item.status, style: adminType(11, FontWeight.w700, paint.ink)),
            ],
          ),
          const SizedBox(height: 2),
          Text('${item.productSummary} · ${item.quantity} · ${item.timeWindow}', style: adminType(12, FontWeight.w500, AdminTokens.textSecondary)),
          Text('${item.riderName ?? 'Unassigned'} ${item.riderCode ?? ''}', style: adminType(12, FontWeight.w600, AdminTokens.text)),
          Wrap(
            spacing: 4,
            children: [
              _link('Skip', () => _occurrenceCall(() => ApiScope.of(context).skipOccurrence(item.occurrenceId))),
              _link('Quantity', () => _quantity(item)),
              _link('Move', () => _move(item)),
              _link('Reassign', () => _reassign(item)),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _occurrenceCall(Future<ScheduleCalendarItem> Function() call) async {
    final loaded = await guardAdminLoad(call);
    if (!mounted) return;
    showAdminNotice(context, loaded.error ?? 'Delivery updated.');
    await _openCalendar(scheduleId: loaded.value?.scheduleId);
  }

  Future<void> _quantity(ScheduleCalendarItem item) async {
    final field = TextEditingController(text: '${item.quantity}');
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change this delivery only'),
        content: TextField(controller: field, decoration: const InputDecoration(labelText: 'Quantity'), keyboardType: TextInputType.number),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Back')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
        ],
      ),
    );
    if (yes != true) return;
    await _occurrenceCall(() => ApiScope.of(context).changeOccurrenceQuantity(item.occurrenceId, int.tryParse(field.text) ?? 0));
  }

  Future<void> _move(ScheduleCalendarItem item) async {
    final picked = await showDatePicker(context: context, initialDate: DateTime.tryParse(item.occurrenceId) ?? DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 120)));
    if (picked == null) return;
    final iso = '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    await _occurrenceCall(() => ApiScope.of(context).rescheduleOccurrence(item.occurrenceId, iso));
  }

  Future<void> _reassign(ScheduleCalendarItem item) async {
    final riders = await guardAdminLoad(() => ApiScope.of(context).riderOperationsRiders(date: _todayIso(), status: 'all'));
    if (!mounted) return;
    if (riders.value == null) {
      showAdminNotice(context, riders.error ?? 'Riders could not be loaded.');
      return;
    }
    String? riderId = item.riderId;
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reassign this delivery'),
        content: DropdownButtonFormField<String>(
          initialValue: riders.value!.any((rider) => rider.id == riderId) ? riderId : null,
          items: [for (final rider in riders.value!) DropdownMenuItem(value: rider.id, child: Text('${rider.fullName} · ${rider.riderCode}'))],
          onChanged: (value) => riderId = value,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Back')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Assign')),
        ],
      ),
    );
    if (yes != true || riderId == null) return;
    await _occurrenceCall(() => ApiScope.of(context).reassignOccurrence(item.occurrenceId, riderId!));
  }

  void _shiftMonth(int delta) {
    _month = DateTime(_month.year, _month.month + delta);
    _openCalendar();
  }

  Widget _banner(String message) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(message, style: adminType(13, FontWeight.w600, AdminTokens.error)),
    );
  }
}

enum _Pane { directory, editor, calendar }

class _Editor extends StatefulWidget {
  const _Editor({required this.detail, required this.busy, required this.onClose, required this.onSaved});

  final RecurringScheduleDetail? detail;
  final bool busy;
  final VoidCallback onClose;
  final Future<void> Function(RecurringScheduleDetail detail, String message, {required bool activated}) onSaved;

  @override
  State<_Editor> createState() => _EditorState();
}

class _EditorState extends State<_Editor> {
  var _started = false;
  var _loading = true;
  String? _customerId;
  String? _riderId;
  var _frequency = 'Weekly';
  var _interval = 1;
  var _window = 'Morning';
  var _publish = true;
  var _mode = 'Fixed';
  final _monthDays = TextEditingController();
  final _time = TextEditingController(text: '05:00');
  final _instructions = TextEditingController();
  final _weekdays = <int>{1, 3, 5};
  final _custom = <String>[];
  final _lines = <_ProductLine>[];
  DateTime _start = DateTime.now();
  List<AdminCustomerRow> _customers = const [];
  List<ProductBasePriceRow> _products = const [];
  List<RiderRecord> _riders = const [];
  SchedulePreview? _preview;
  String? _formError;

  @override
  void initState() {
    super.initState();
    final detail = widget.detail;
    if (detail != null) {
      _customerId = detail.customerId;
      _riderId = detail.riderId;
      _frequency = detail.frequency;
      _interval = detail.interval;
      _window = detail.timeWindow;
      _publish = detail.autoPublish;
      _time.text = detail.publicationTime;
      _mode = detail.assignmentMode;
      _instructions.text = detail.instructions ?? '';
      _weekdays
        ..clear()
        ..addAll(detail.weekdays);
      _monthDays.text = detail.monthDays.join(', ');
      _custom.addAll(detail.customDates);
      _start = DateTime.tryParse(detail.startDate) ?? DateTime.now();
      if (detail.lines.isEmpty) {
        _lines.add(_ProductLine());
      } else {
        for (final line in detail.lines) {
          _lines.add(_ProductLine(productId: line.productId, quantity: '${line.quantity}', empties: '${line.expectedEmpties}'));
        }
      }
    } else {
      _lines.add(_ProductLine());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _loadLists();
  }

  @override
  void dispose() {
    _monthDays.dispose();
    _time.dispose();
    _instructions.dispose();
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  Future<void> _loadLists() async {
    final api = ApiScope.of(context);
    final customers = await guardAdminLoad(() => api.adminCustomers(status: 'Active', pageSize: 50));
    final products = await guardAdminLoad(() => api.productCatalogue(pageSize: 50));
    final riders = await guardAdminLoad(() => api.riderOperationsRiders(date: _todayIso(), status: 'all'));
    if (!mounted) return;
    setState(() {
      _customers = customers.value?.rows ?? const [];
      _products = products.value?.rows ?? const [];
      _riders = riders.value ?? const [];
      _formError = customers.error ?? products.error ?? riders.error;
      _loading = false;
    });
  }

  Map<String, dynamic> _body({required bool activate}) {
    return {
      'customerId': _customerId,
      'riderId': _riderId,
      'frequency': _frequency,
      'interval': _interval,
      'weekdays': _weekdays.toList(),
      'monthDays': _monthDays.text.split(',').map((part) => int.tryParse(part.trim()) ?? 0).where((day) => day > 0).toList(),
      'customDates': _custom,
      'startDate': _iso(_start),
      'timeWindow': _window,
      'timeZoneId': 'Asia/Karachi',
      'autoPublish': _publish,
      'publicationTime': _time.text.trim(),
      'assignmentMode': _mode,
      'instructions': _instructions.text.trim(),
      'version': widget.detail?.version,
      'activate': activate,
      'lines': [
        for (final line in _lines)
          if (line.productId != null)
            {
              'productId': line.productId,
              'quantity': int.tryParse(line.quantity.text) ?? 0,
              'expectedEmpties': int.tryParse(line.empties.text) ?? 0,
            },
      ],
    };
  }

  Future<void> _save(bool activate) async {
    final chosen = _lines.where((line) => line.productId != null && (int.tryParse(line.quantity.text) ?? 0) > 0).toList();
    final ids = chosen.map((line) => line.productId).toSet();
    if (_customerId == null || chosen.isEmpty) {
      setState(() => _formError = 'Choose a customer and at least one product with a quantity.');
      return;
    }
    if (ids.length != chosen.length) {
      setState(() => _formError = 'Each product can be added once. Set the quantity on its own row.');
      return;
    }
    if (activate && (_riderId == null || _riderId!.isEmpty)) {
      setState(() => _formError = 'Choose a rider before activating the schedule.');
      return;
    }
    final api = ApiScope.of(context);
    final body = _body(activate: activate);
    final loaded = await guardAdminLoad(() => widget.detail == null ? api.createRecurringSchedule(body) : api.updateRecurringSchedule(widget.detail!.id, body));
    if (!mounted) return;
    if (loaded.value == null) {
      setState(() => _formError = loaded.error ?? 'The schedule was not saved.');
      return;
    }
    await widget.onSaved(loaded.value!, activate ? 'Schedule activated.' : 'Schedule saved.', activated: activate);
  }

  Future<void> _previewPlan() async {
    final loaded = await guardAdminLoad(() => ApiScope.of(context).previewRecurringSchedule(_body(activate: false)));
    if (!mounted) return;
    setState(() {
      _preview = loaded.value;
      _formError = loaded.error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final detail = widget.detail;
    final customer = _customers.cast<AdminCustomerRow?>().firstWhere((row) => row?.id == _customerId, orElse: () => null);
    final rider = _riders.cast<RiderRecord?>().firstWhere((row) => row?.id == _riderId, orElse: () => null);
    if (_loading) return const Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator());
    final used = _lines.map((line) => line.productId).whereType<String>().toSet();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(detail == null ? 'New schedule' : detail.scheduleCode, style: adminType(20, FontWeight.w700, AdminTokens.text)),
        if (detail != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('${detail.status} · ${detail.depotName} · ${detail.routeName}', style: adminType(13, FontWeight.w500, AdminTokens.textSecondary)),
          ),
        if (_formError != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_formError!, style: adminType(13, FontWeight.w600, AdminTokens.error)),
          ),
        _card('Customer', 'The plan uses the customer already saved in the directory.', [
          _drop<String>(
            'Customer',
            _customerId,
            [for (final row in _customers) DropdownMenuItem(value: row.id, child: Text('${row.businessName} · ${row.code}', overflow: TextOverflow.ellipsis))],
            (value) => setState(() => _customerId = value),
          ),
          if (customer != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '${customer.phone} · ${customer.address} · ${customer.category}${customer.hasGps ? ' · GPS ${customer.latitude}, ${customer.longitude}' : ' · No GPS is stored'}',
                style: adminType(12.5, FontWeight.w500, AdminTokens.textSecondary),
              ),
            ),
        ]),
        _card('Products on each visit', 'Add every bottle or pack, and set the quantity for that product.', [
          for (var index = 0; index < _lines.length; index++) _productRow(index, used),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const Key('schedule-add-product'),
            onPressed: used.length >= _products.length
                ? null
                : () => setState(() => _lines.add(_ProductLine())),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add product'),
          ),
        ]),
        _card('When it repeats', 'Weekly days, dates in the month, or dates you pick one by one.', [
          Wrap(
            spacing: 8,
            children: [
              for (final mode in const ['Weekly', 'Monthly', 'Custom'])
                ChoiceChip(label: Text(mode), selected: _frequency == mode, onSelected: (_) => setState(() => _frequency = mode)),
            ],
          ),
          if (_frequency == 'Weekly') ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              children: [
                for (final day in const [1, 2, 3, 4, 5, 6, 0])
                  FilterChip(
                    label: Text(const ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'][day]),
                    selected: _weekdays.contains(day),
                    onSelected: (selected) => setState(() => selected ? _weekdays.add(day) : _weekdays.remove(day)),
                  ),
              ],
            ),
            _drop<int>('Repeat', _interval, const [
              DropdownMenuItem(value: 1, child: Text('Every week')),
              DropdownMenuItem(value: 2, child: Text('Every 2 weeks')),
            ], (value) => setState(() => _interval = value ?? 1)),
          ],
          if (_frequency == 'Monthly')
            TextField(controller: _monthDays, decoration: const InputDecoration(labelText: 'Days of the month, for example 1, 15, 31')),
          if (_frequency == 'Custom')
            Wrap(
              spacing: 6,
              children: [
                for (final date in _custom) Chip(label: Text(date), onDeleted: () => setState(() => _custom.remove(date))),
                TextButton(
                  onPressed: () async {
                    final picked = await showDatePicker(context: context, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)), initialDate: DateTime.now());
                    if (picked == null) return;
                    setState(() => _custom.add(_iso(picked)));
                  },
                  child: const Text('Add date'),
                ),
              ],
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton(
                onPressed: () async {
                  final picked = await showDatePicker(context: context, initialDate: _start, firstDate: DateTime(2024), lastDate: DateTime.now().add(const Duration(days: 365)));
                  if (picked != null) setState(() => _start = picked);
                },
                child: Text('Starts ${_iso(_start)}'),
              ),
              SizedBox(
                width: 220,
                child: _drop<String>('Window', _window, const [
                  DropdownMenuItem(value: 'Morning', child: Text('Morning')),
                  DropdownMenuItem(value: 'Afternoon', child: Text('Afternoon')),
                  DropdownMenuItem(value: 'Evening', child: Text('Evening')),
                ], (value) => setState(() => _window = value ?? 'Morning')),
              ),
            ],
          ),
        ]),
        _card('Rider', 'Every rider is listed. Choose whether that rider stays on every visit.', [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _modeTile('Fixed', 'Fix this rider for every delivery', 'The same rider is assigned to each visit on this plan.'),
              _modeTile('Flexible', 'Choose a rider for this delivery', 'This rider is the usual choice. A single visit can be given to another rider.'),
            ],
          ),
          _drop<String>(
            'Rider',
            _riderId,
            [
              for (final row in _riders)
                DropdownMenuItem(
                  value: row.id,
                  child: Text('${row.fullName} · ${row.riderCode} · ${_riderStatus(row.status)}', overflow: TextOverflow.ellipsis),
                ),
            ],
            (value) => setState(() => _riderId = value),
          ),
          if (_riders.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('No riders were returned.', style: adminType(12.5, FontWeight.w600, AdminTokens.textSecondary)),
            ),
          if (rider != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '${_riderStatus(rider.status)} · ${rider.routeName} · ${rider.vehicleName}. Vehicle capacity is not recorded.',
                style: adminType(12.5, FontWeight.w500, AdminTokens.textSecondary),
              ),
            ),
          if (detail != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Shift ${detail.shiftOpen ? 'open' : 'not open'} · ${detail.riderWorkload} deliveries today.',
                style: adminType(12.5, FontWeight.w500, AdminTokens.textSecondary),
              ),
            ),
        ]),
        _card('Publishing', 'Eligible visits are written onto the rider route at the chosen time.', [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _publish,
            onChanged: (value) => setState(() => _publish = value),
            title: const Text('Automatically publish the day’s delivery to the rider route'),
            subtitle: const Text('Default 05:00 Asia/Karachi. The server uses Pakistan Standard Time when that zone id is not installed.'),
          ),
          SizedBox(width: 180, child: TextField(controller: _time, decoration: const InputDecoration(labelText: 'Publish time'))),
          TextField(controller: _instructions, decoration: const InputDecoration(labelText: 'Delivery instructions')),
        ]),
        if (detail != null && detail.monthDayRule.isNotEmpty)
          Padding(padding: const EdgeInsets.only(top: 10), child: Text(detail.monthDayRule, style: adminType(12.5, FontWeight.w500, AdminTokens.textSecondary))),
        if (detail != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('This month from the schedule rule: ${detail.monthlyCount} deliveries, ${detail.monthlyBottles} units.', style: adminType(12.5, FontWeight.w600, AdminTokens.text)),
          ),
        if (_preview != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Preview: ${_preview!.totalDeliveries} deliveries, ${_preview!.totalBottles} units. ${_preview!.dates.join(', ')}. ${_preview!.monthDayRule}', style: adminType(12.5, FontWeight.w600, AdminTokens.text)),
          ),
        if (detail != null && detail.exceptions.isNotEmpty)
          for (final exception in detail.exceptions)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('${exception.status} pause ${exception.startDate} to ${exception.endDate}: ${exception.reason}'),
            ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            TextButton(onPressed: widget.onClose, child: const Text('Cancel')),
            OutlinedButton(onPressed: widget.busy ? null : _previewPlan, child: const Text('Preview Schedule')),
            OutlinedButton(onPressed: widget.busy ? null : () => _save(false), child: const Text('Save')),
            FilledButton(
              key: const Key('recurring-activate'),
              onPressed: widget.busy ? null : () => _save(true),
              style: FilledButton.styleFrom(backgroundColor: AdminTokens.button, foregroundColor: Colors.white, minimumSize: const Size(0, 44)),
              child: const Text('Save & Activate'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _productRow(int index, Set<String> used) {
    final line = _lines[index];
    final choices = [
      for (final product in _products)
        if (product.id == line.productId || !used.contains(product.id)) product,
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 340,
            child: _drop<String>(
              'Product',
              line.productId,
              id: '$index',
              [
                for (final product in choices)
                  DropdownMenuItem(
                    value: product.id,
                    child: Text('${product.name} · ${product.sku} · ${product.baseSystemPrice ?? 'no price'}', overflow: TextOverflow.ellipsis),
                  ),
              ],
              (value) => setState(() => line.productId = value),
            ),
          ),
          SizedBox(width: 110, child: TextField(controller: line.quantity, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantity', isDense: true))),
          SizedBox(width: 130, child: TextField(controller: line.empties, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Empty returns', isDense: true))),
          if (_lines.length > 1)
            IconButton(
              tooltip: 'Remove product',
              onPressed: () => setState(() {
                _lines.removeAt(index).dispose();
              }),
              icon: const Icon(Icons.close, size: 18),
            ),
        ],
      ),
    );
  }

  Widget _modeTile(String value, String title, String detail) {
    final selected = _mode == value;
    return Material(
      color: selected ? AdminTokens.primarySoft : AdminTokens.field,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        key: Key('assignment-$value'),
        borderRadius: BorderRadius.circular(10),
        onTap: () => setState(() => _mode = value),
        child: Container(
          width: 300,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: selected ? AdminTokens.button : AdminTokens.line, width: selected ? 1.6 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: adminType(13.5, FontWeight.w700, AdminTokens.text)),
              const SizedBox(height: 4),
              Text(detail, style: adminType(12, FontWeight.w500, AdminTokens.textSecondary, height: 1.35)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card(String title, String subtitle, List<Widget> children) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminTokens.line),
      ),
      child: Material(
        color: AdminTokens.surface,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: adminType(15, FontWeight.w700, AdminTokens.text)),
              const SizedBox(height: 4),
              Text(subtitle, style: adminType(12.5, FontWeight.w500, AdminTokens.textSecondary)),
              const SizedBox(height: 10),
              ...children,
            ],
          ),
        ),
      ),
    );
  }

  Widget _drop<T>(String label, T? value, List<DropdownMenuItem<T>> items, ValueChanged<T?> onChanged, {String? id}) {
    final known = items.any((item) => item.value == value);
    return DropdownButtonFormField<T>(
      key: ValueKey('$label-${id ?? value}-${items.length}'),
      initialValue: known ? value : null,
      isExpanded: true,
      decoration: InputDecoration(labelText: label, isDense: true, filled: true, fillColor: AdminTokens.field),
      items: items,
      onChanged: onChanged,
    );
  }
}

class _ProductLine {
  _ProductLine({this.productId, String quantity = '1', String empties = '0'})
      : quantity = TextEditingController(text: quantity),
        empties = TextEditingController(text: empties);

  String? productId;
  final TextEditingController quantity;
  final TextEditingController empties;

  void dispose() {
    quantity.dispose();
    empties.dispose();
  }
}

String _riderStatus(String status) {
  return switch (status) {
    'onDuty' => 'On duty',
    'available' => 'Available',
    'inactive' => 'Inactive',
    'attention' => 'Needs attention',
    _ => status.isEmpty ? 'Status not recorded' : status,
  };
}

class _StatusPaint {
  const _StatusPaint(this.fill, this.ink);

  final Color fill;
  final Color ink;
}

_StatusPaint _paint(String status) {
  return switch (status) {
    'Completed' => const _StatusPaint(AdminTokens.successSoft, AdminTokens.success),
    'Published' => const _StatusPaint(Color(0xFFEDE7F6), Color(0xFF5E4B8B)),
    'Paused' => const _StatusPaint(AdminTokens.warningBg, AdminTokens.warning),
    'Cancelled' || 'Skipped' => const _StatusPaint(Color(0xFFEEF2F6), Color(0xFF64748B)),
    'Scheduled' => const _StatusPaint(AdminTokens.primarySoft, AdminTokens.button),
    _ => const _StatusPaint(Color(0xFFF8FAFC), AdminTokens.textSecondary),
  };
}

String _monthName(int month) {
  return const ['', 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'][month];
}

String _iso(DateTime date) => '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

String _todayIso() => _iso(DateTime.now());
