import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../api/route_api.dart';
import '../../data/admin_format.dart';
import '../../data/admin_json.dart';
import '../../data/dashboard_period.dart';
import '../../theme/admin_tokens.dart';
import '../admin_load.dart';
import '../admin_nav.dart';
import '../widgets/admin_shell.dart';
import '../widgets/rider_operations/rider_operations_panels.dart';

class RiderOperationsScreen extends StatefulWidget {
  const RiderOperationsScreen({
    required this.onNavigate,
    this.session,
    super.key,
  });

  final AuthSession? session;
  final ValueChanged<String> onNavigate;

  @override
  State<RiderOperationsScreen> createState() => _RiderOperationsScreenState();
}

class _RiderOperationsScreenState extends State<RiderOperationsScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  var _started = false;
  var _loading = true;
  var _generation = 0;
  var _status = 'all';
  DateTime _date = DateTime.now();
  String? _selectedId;

  AdminLoad<RiderOperationsSummary>? _summary;
  AdminLoad<List<RiderRecord>>? _riders;
  AdminLoad<List<RiderExceptionItem>>? _exceptions;
  AdminLoad<List<LocationVerification>>? _verifications;
  AdminLoad<RiderRecord>? _detail;
  AdminLoad<List<RiderActivityItem>>? _activity;
  AdminLoad<List<RiderAssignment>>? _assignments;

  @override
  void initState() {
    super.initState();
    _search.addListener(_scheduleSearch);
  }

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
    _generation++;
    _debounce?.cancel();
    _search.removeListener(_scheduleSearch);
    _search.dispose();
    super.dispose();
  }

  void _scheduleSearch() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      _reload();
    });
  }

  List<RiderRecord> _matching(List<RiderRecord> riders) {
    final query = _search.text.trim().toLowerCase();
    if (query.isEmpty) return riders;
    return [
      for (final rider in riders)
        if ('${rider.fullName} ${rider.riderCode} ${rider.routeName} ${rider.phone} ${rider.vehicleName}'
            .toLowerCase()
            .contains(query))
          rider,
    ];
  }

  Future<void> _reload() async {
    final generation = ++_generation;
    final date = isoDate(_date);
    final preserve = _selectedId;
    if (mounted && !_loading) setState(() => _loading = true);
    final api = ApiScope.of(context);
    final summaryF = guardAdminLoad(
      () => api.riderOperationsSummary(date: date),
    );
    final ridersF = guardAdminLoad(
      () => api.riderOperationsRiders(
        date: date,
        search: _search.text.trim().isEmpty ? null : _search.text.trim(),
        status: _status,
      ),
    );
    final exceptionsF = guardAdminLoad(
      () => api.riderOperationsExceptions(date: date),
    );
    final verificationsF = guardAdminLoad(
      api.riderOperationsLocationVerifications,
    );
    final summary = await summaryF;
    final riders = await ridersF;
    final exceptions = await exceptionsF;
    final verifications = await verificationsF;
    if (!mounted || generation != _generation) return;

    String? selected;
    if (!riders.failed) {
      final visible = _matching(riders.value!);
      if (visible.isNotEmpty) {
        selected = visible.any((rider) => rider.id == preserve)
            ? preserve
            : visible.first.id;
      }
    }

    AdminLoad<RiderRecord>? detail;
    AdminLoad<List<RiderActivityItem>>? activity;
    AdminLoad<List<RiderAssignment>>? assignments;
    if (selected != null && selected.isNotEmpty) {
      final riderId = selected;
      final detailF = guardAdminLoad(
        () => api.riderOperationsRider(riderId, date: date),
      );
      final activityF = guardAdminLoad(
        () => api.riderOperationsActivity(riderId),
      );
      final assignmentsF = guardAdminLoad(
        () => api.riderOperationsAssignments(riderId, date: date),
      );
      detail = await detailF;
      activity = await activityF;
      assignments = await assignmentsF;
      if (!mounted || generation != _generation) return;
    }

    setState(() {
      _summary = summary;
      _riders = riders;
      _exceptions = exceptions;
      _verifications = verifications;
      _selectedId = selected;
      _detail = detail;
      _activity = activity;
      _assignments = assignments;
      _loading = false;
    });
  }

  Future<void> _select(String id) async {
    if (id.isEmpty || id == _selectedId && _detail != null) {
      setState(() => _selectedId = id);
      return;
    }
    final generation = ++_generation;
    final date = isoDate(_date);
    setState(() => _selectedId = id);
    final api = ApiScope.of(context);
    final detail = await guardAdminLoad(
      () => api.riderOperationsRider(id, date: date),
    );
    final activity = await guardAdminLoad(
      () => api.riderOperationsActivity(id),
    );
    final assignments = await guardAdminLoad(
      () => api.riderOperationsAssignments(id, date: date),
    );
    if (!mounted || generation != _generation || _selectedId != id) return;
    setState(() {
      _detail = detail;
      _activity = activity;
      _assignments = assignments;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked == null || !mounted) return;
    setState(() => _date = DateTime(picked.year, picked.month, picked.day));
    _reload();
  }

  Future<void> _call(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone.replaceAll(' ', ''));
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      showAdminNotice(context, 'The phone dialer could not be opened.');
    }
  }

  void _showLines(String title, List<String> lines, String empty) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          title,
          style: adminType(18, FontWeight.w700, AdminTokens.text),
        ),
        content: SizedBox(
          width: 420,
          child: lines.isEmpty
              ? Text(
                  empty,
                  style: adminType(
                    14,
                    FontWeight.w500,
                    AdminTokens.textSecondary,
                    height: 1.4,
                  ),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final line in lines)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          line,
                          style: adminType(
                            14,
                            FontWeight.w500,
                            AdminTokens.text,
                            height: 1.35,
                          ),
                        ),
                      ),
                  ],
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  RiderRecord? get _directorySelection {
    final riders = _riders?.value;
    if (riders == null || _selectedId == null) return null;
    for (final rider in riders) {
      if (rider.id == _selectedId) return rider;
    }
    return null;
  }

  RiderRecord? get _shown => _detail?.value ?? _directorySelection;

  @override
  Widget build(BuildContext context) {
    final loads = <AdminLoad<dynamic>>[
      ?_summary,
      ?_riders,
      ?_exceptions,
      ?_verifications,
      ?_detail,
      ?_activity,
      ?_assignments,
    ];
    final banner = adminErrorBanner(loads);
    final visible = _riders?.value == null
        ? const <RiderRecord>[]
        : _matching(_riders!.value!);
    final phone = _shown?.phone ?? '';
    return AdminShell(
      screenKey: const Key('rider-operations-screen'),
      activeKey: AdminNav.fleet,
      session: widget.session,
      serverReachable: adminServerReachable(loads),
      search: _search,
      onSearch: (_) {},
      searchHint: 'Search rider by name, ID, or route',
      onNavigate: widget.onNavigate,
      trailing: IconButton(
        key: const Key('rider-refresh'),
        tooltip: 'Refresh',
        onPressed: _reload,
        icon: const Icon(Icons.refresh, color: AdminTokens.secondary),
      ),
      body: _loading
          ? const AdminLoadingPane(label: 'Loading rider operations…')
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
              children: [
                Text(
                  'Field Operations  ›  Rider Operations',
                  style: adminType(
                    12,
                    FontWeight.w600,
                    AdminTokens.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Rider Operations',
                      style: adminType(
                        28,
                        FontWeight.w700,
                        AdminTokens.text,
                        height: 1.15,
                      ),
                    ),
                    TextButton(
                      key: const Key('rider-date-button'),
                      onPressed: _pickDate,
                      child: Text(
                        formatAdminDay(_date),
                        style: adminType(
                          13,
                          FontWeight.w700,
                          AdminTokens.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Assignments, stop progress, and exceptions for the selected day.',
                  style: adminType(
                    14,
                    FontWeight.w500,
                    AdminTokens.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                if (banner != null) ...[
                  AdminSectionMessage(
                    key: const Key('admin-error-banner'),
                    message: banner,
                    onRetry: _reload,
                    error: true,
                  ),
                  const SizedBox(height: 16),
                ],
                _summaryBlock(),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final overview = RiderOverviewPanel(
                      selected: _shown,
                      assignments: _assignments?.value ?? const [],
                      assignmentsFailed: _assignments?.failed == true,
                      activity: _activity?.value ?? const [],
                      activityFailed: _activity?.failed == true,
                      exceptions: _exceptions?.value ?? const [],
                      exceptionsFailed: _exceptions?.failed == true,
                    );
                    final directory = _directoryBlock(visible, phone);
                    if (constraints.maxWidth < 980) {
                      return Column(
                        children: [
                          overview,
                          const SizedBox(height: 16),
                          directory,
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: overview),
                        const SizedBox(width: 16),
                        Expanded(flex: 2, child: directory),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                LocationVerificationsSection(
                  items: _verifications?.value ?? const [],
                  failed: _verifications?.failed == true,
                ),
              ],
            ),
    );
  }

  Widget _summaryBlock() {
    final load = _summary;
    if (load == null || load.failed) {
      return const AdminSectionMessage(
        message: 'Rider operations figures could not be loaded.',
        error: true,
      );
    }
    if (load.value!.kpis.isEmpty) {
      return const AdminSectionMessage(
        message: 'No rider operations figures were returned for this date.',
      );
    }
    return RiderKpiWrap(kpis: load.value!.kpis);
  }

  Widget _directoryBlock(List<RiderRecord> visible, String phone) {
    final load = _riders;
    if (load == null || load.failed) {
      return const AdminSectionMessage(
        message: 'Riders could not be loaded.',
        error: true,
      );
    }
    final shown = _shown;
    return RiderDirectory(
      emptyMessage: load.value!.isEmpty
          ? 'No riders were returned for this date.'
          : 'No riders match this search.',
      search: _search,
      status: _status,
      onStatus: (value) {
        _status = value;
        _reload();
      },
      riders: visible,
      selectedId: _selectedId,
      onSelect: (id) => _select(id),
      detail: shown,
      detailFailed: _detail?.failed == true,
      onCall: phone.trim().isEmpty ? null : () => _call(phone),
      onProfile: shown == null
          ? null
          : () => _showLines(
              'Profile',
              _profileLines(shown),
              'No profile fields were returned.',
            ),
      onAssignments: () => _showLines(
        'Assignments',
        [
          for (final stop in _assignments?.value ?? const <RiderAssignment>[])
            '${stop.customerName}${stop.status.isEmpty ? '' : ' · ${stop.status}'}',
        ],
        _assignments?.failed == true
            ? 'Assignments could not be loaded.'
            : 'No assignments were returned.',
      ),
      onActivity: () => _showLines(
        'Activity',
        [
          for (final item
              in _activity?.value ?? const <RiderActivityItem>[])
            ?_activityDialogLine(item),
        ],
        _activity?.failed == true
            ? 'Activity could not be loaded.'
            : 'No activity was returned.',
      ),
    );
  }

  List<String> _profileLines(RiderRecord rider) {
    final status = operationsDisplayText(rider.status);
    final route = operationsDisplayText(rider.routeName);
    final vehicle = operationsDisplayText(
      '${rider.vehicleName} ${rider.vehiclePlate}'.trim(),
    );
    final next = operationsDisplayText(rider.nextStop);
    final notes = operationsDisplayText(rider.notes);
    return [
      if (rider.fullName.isNotEmpty) rider.fullName,
      if (rider.riderCode.isNotEmpty) 'Code ${rider.riderCode}',
      if (status != null) 'Status $status',
      ?route,
      ?vehicle,
      if (rider.phone.isNotEmpty) rider.phone,
      if (next != null) 'Next stop $next',
      ?notes,
    ];
  }
}

String? _activityDialogLine(RiderActivityItem item) {
  final title = operationsDisplayText(item.title);
  final detail = operationsDisplayText(item.detail);
  final text = [title, detail].whereType<String>().join(' — ');
  if (text.isEmpty) return null;
  if (item.occurredAt == null) return text;
  return '$text · ${formatAdminStamp(item.occurredAt!)}';
}
