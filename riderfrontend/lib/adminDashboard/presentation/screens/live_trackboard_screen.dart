import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../api/route_api.dart';
import '../../data/admin_format.dart';
import '../../data/fleet_tracking_models.dart';
import '../../theme/admin_tokens.dart';
import '../admin_nav.dart';
import '../widgets/admin_shell.dart';

class LiveTrackboardScreen extends StatefulWidget {
  const LiveTrackboardScreen({
    required this.onNavigate,
    this.session,
    super.key,
  });

  final AuthSession? session;
  final ValueChanged<String> onNavigate;

  @override
  State<LiveTrackboardScreen> createState() => _LiveTrackboardScreenState();
}

class _LiveTrackboardScreenState extends State<LiveTrackboardScreen> {
  static const _intervalKey = 'live_track_fetch_seconds';

  final _search = TextEditingController();
  final _map = MapController();
  Timer? _poll;
  var _started = false;
  var _loading = true;
  var _fetchSeconds = 60;
  String? _error;
  String? _selectedId;
  LiveTrackingOverview? _overview;
  List<LiveRiderCard> _riders = const [];
  LiveRiderDetail? _detail;
  List<RouteAnomalyInfo> _anomalies = const [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _reload();
      _armPoll();
      _restoreInterval();
    });
  }

  void _armPoll() {
    _poll?.cancel();
    _poll = Timer.periodic(
      Duration(seconds: _fetchSeconds),
      (_) => _reload(silent: true),
    );
  }

  Future<void> _restoreInterval() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getInt(_intervalKey);
      if (!mounted || stored == null) return;
      final seconds = stored.clamp(15, 3600);
      if (seconds == _fetchSeconds) return;
      setState(() => _fetchSeconds = seconds);
      _armPoll();
    } catch (_) {}
  }

  Future<void> _setFetchSeconds(int seconds) async {
    final next = seconds.clamp(15, 3600);
    setState(() => _fetchSeconds = next);
    _armPoll();
    _reload(silent: true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_intervalKey, next);
    } catch (_) {}
  }

  Future<void> _pickCustomInterval() async {
    final chosen = await showDialog<int>(
      context: context,
      builder: (context) => _CustomFetchDialog(initialSeconds: _fetchSeconds),
    );
    if (chosen == null) return;
    await _setFetchSeconds(chosen);
  }

  @override
  void dispose() {
    _poll?.cancel();
    _search.dispose();
    super.dispose();
  }

  List<LiveRiderCard> get _filtered {
    final term = _search.text.trim().toLowerCase();
    if (term.isEmpty) return _riders;
    return _riders
        .where(
          (row) =>
              row.fullName.toLowerCase().contains(term) ||
              (row.riderCode ?? '').toLowerCase().contains(term) ||
              (row.routeName ?? '').toLowerCase().contains(term),
        )
        .toList();
  }

  Future<void> _reload({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final api = ApiScope.of(context);
      final overview = await api.liveTrackingOverview();
      final riders = await api.liveTrackingRiders();
      final anomalies = await api.adminRouteAnomalies();
      LiveRiderDetail? detail;
      final selected =
          _selectedId ?? (riders.isEmpty ? null : riders.first.riderUserId);
      if (selected != null &&
          riders.any((row) => row.riderUserId == selected)) {
        detail = await api.liveTrackingRider(selected);
      }
      if (!mounted) return;
      setState(() {
        _overview = overview;
        _riders = riders;
        _anomalies = anomalies;
        _selectedId = selected;
        _detail = detail;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _selectRider(String id) async {
    setState(() {
      _selectedId = id;
      _detail = null;
    });
    try {
      final detail = await ApiScope.of(context).liveTrackingRider(id);
      if (!mounted) return;
      setState(() => _detail = detail);
      final lat = detail.card.latitude;
      final lng = detail.card.longitude;
      if (lat != null && lng != null) {
        _map.move(LatLng(lat.toDouble(), lng.toDouble()), 14);
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _review(RouteAnomalyInfo anomaly, String action) async {
    final notes = await _promptNotes(
      action == 'approve'
          ? 'Approve explanation'
          : 'Reject / request clarification',
    );
    if (notes == null || !mounted) return;
    try {
      await ApiScope.of(context).reviewRouteAnomaly(
        id: anomaly.id,
        action: action,
        notes: notes.isEmpty ? null : notes,
      );
      await _reload();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _resolve(
    RouteAnomalyInfo anomaly, {
    bool falsePositive = false,
  }) async {
    final notes = await _promptNotes(
      falsePositive ? 'Mark false positive' : 'Close anomaly',
    );
    if (notes == null || !mounted) return;
    try {
      await ApiScope.of(context).resolveRouteAnomaly(
        id: anomaly.id,
        notes: notes.isEmpty ? null : notes,
        markFalsePositive: falsePositive,
      );
      await _reload();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<String?> _promptNotes(String title) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Notes',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, controller.text.trim()),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final overview = _overview;
    final riders = _filtered;
    return AdminShell(
      screenKey: const Key('live-trackboard-screen'),
      activeKey: AdminNav.liveTrackboard,
      session: widget.session,
      serverReachable: _error == null,
      search: _search,
      onSearch: (_) => setState(() {}),
      searchHint: 'Search waypoint, tracking ID...',
      onNavigate: widget.onNavigate,
      trailing: IconButton(
        tooltip: 'Refresh',
        onPressed: _reload,
        icon: const Icon(Icons.refresh, color: AdminTokens.secondary),
      ),
      body: Column(
        children: [
          _FetchIntervalBar(
            seconds: _fetchSeconds,
            onSelect: _setFetchSeconds,
            onCustom: _pickCustomInterval,
          ),
          Expanded(
            child: _loading && overview == null
          ? const Center(child: CircularProgressIndicator())
          : _error != null && overview == null
          ? Center(child: Text(_error!))
          : Column(
              children: [
                _KpiStrip(overview: overview),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth >= 980;
                      final map = _FleetMap(
                        controller: _map,
                        riders: riders,
                        detail: _detail,
                        selectedId: _selectedId,
                        onSelect: _selectRider,
                      );
                      final side = _RiderSidePanel(
                        riders: riders,
                        detail: _detail,
                        anomalies: _anomalies
                            .where(
                              (item) =>
                                  _selectedId == null ||
                                  item.riderUserId == _selectedId,
                            )
                            .toList(),
                        selectedId: _selectedId,
                        onSelect: _selectRider,
                        onApprove: (row) => _review(row, 'approve'),
                        onReject: (row) => _review(row, 'reject'),
                        onResolve: (row) => _resolve(row),
                        onFalsePositive: (row) =>
                            _resolve(row, falsePositive: true),
                      );
                      if (!wide) {
                        return ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            SizedBox(height: 360, child: map),
                            const SizedBox(height: 12),
                            SizedBox(height: 520, child: side),
                          ],
                        );
                      }
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(flex: 7, child: map),
                            const SizedBox(width: 12),
                            SizedBox(width: 360, child: side),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                _FooterBar(overview: overview),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FetchIntervalBar extends StatelessWidget {
  const _FetchIntervalBar({
    required this.seconds,
    required this.onSelect,
    required this.onCustom,
  });

  final int seconds;
  final ValueChanged<int> onSelect;
  final VoidCallback onCustom;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AdminTokens.primarySoft,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AdminTokens.line),
        ),
        child: Wrap(
          spacing: 10,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Icon(Icons.schedule, size: 18, color: AdminTokens.button),
            Text(
              'Fetch location every',
              style: adminType(13, FontWeight.w700, AdminTokens.text),
            ),
            PopupMenuButton<int>(
              key: const Key('live-track-fetch'),
              tooltip: 'Location fetch interval',
              initialValue: _intervalChoices.contains(seconds) ? seconds : null,
              onSelected: (value) {
                if (value == 0) {
                  onCustom();
                  return;
                }
                onSelect(value);
              },
              itemBuilder: (context) => [
                for (final choice in _intervalChoices)
                  PopupMenuItem(
                    key: Key('live-track-fetch-$choice'),
                    value: choice,
                    child: Text(liveTrackFetchLabel(choice)),
                  ),
                const PopupMenuItem(
                  key: Key('live-track-fetch-custom'),
                  value: 0,
                  child: Text('Custom time'),
                ),
              ],
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AdminTokens.button,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      liveTrackFetchLabel(seconds),
                      style: adminType(13, FontWeight.w700, Colors.white),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_drop_down, color: Colors.white, size: 18),
                  ],
                ),
              ),
            ),
            Text(
              'Each request loads the latest fix for every rider on this list.',
              style: adminType(12.5, FontWeight.w600, AdminTokens.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

const _intervalChoices = <int>[15, 30, 60, 120, 300, 600];

String liveTrackFetchLabel(int seconds) {
  if (seconds >= 60 && seconds % 60 == 0) {
    final minutes = seconds ~/ 60;
    return minutes == 1 ? 'Every 1 min' : 'Every $minutes min';
  }
  return 'Every $seconds sec';
}

class _CustomFetchDialog extends StatefulWidget {
  const _CustomFetchDialog({required this.initialSeconds});

  final int initialSeconds;

  @override
  State<_CustomFetchDialog> createState() => _CustomFetchDialogState();
}

class _CustomFetchDialogState extends State<_CustomFetchDialog> {
  late final TextEditingController _amount;
  var _minutes = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _minutes = widget.initialSeconds >= 60 && widget.initialSeconds % 60 == 0;
    final shown = _minutes ? widget.initialSeconds ~/ 60 : widget.initialSeconds;
    _amount = TextEditingController(text: '$shown');
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _save() {
    final amount = int.tryParse(_amount.text.trim());
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter a whole number greater than zero.');
      return;
    }
    final seconds = _minutes ? amount * 60 : amount;
    if (seconds < 15 || seconds > 3600) {
      setState(() => _error = 'Choose a time from 15 seconds to 60 minutes.');
      return;
    }
    Navigator.of(context).pop(seconds);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'Custom location fetch',
        style: adminType(18, FontWeight.w700, AdminTokens.text),
      ),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'How often should this screen request a location for every listed rider?',
              style: adminType(13, FontWeight.w500, AdminTokens.textSecondary, height: 1.35),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('live-track-fetch-amount'),
              controller: _amount,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Time',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  key: const Key('live-track-fetch-minutes'),
                  label: const Text('Minutes'),
                  selected: _minutes,
                  onSelected: (_) => setState(() => _minutes = true),
                ),
                ChoiceChip(
                  key: const Key('live-track-fetch-seconds'),
                  label: const Text('Seconds'),
                  selected: !_minutes,
                  onSelected: (_) => setState(() => _minutes = false),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: adminType(12.5, FontWeight.w600, AdminTokens.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Back'),
        ),
        FilledButton(
          key: const Key('live-track-fetch-save'),
          onPressed: _save,
          child: const Text('Use this time'),
        ),
      ],
    );
  }
}

class _KpiStrip extends StatelessWidget {
  const _KpiStrip({required this.overview});

  final LiveTrackingOverview? overview;

  @override
  Widget build(BuildContext context) {
    final o = overview;
    final fleetPct = (o == null || o.fleetTotal == 0)
        ? '—'
        : '${((o.ridersOnDuty / o.fleetTotal) * 100).round()}% of fleet';
    final cards = [
      _Kpi('Riders on Duty', '${o?.ridersOnDuty ?? 0} Active', fleetPct),
      _Kpi(
        'Moving',
        '${o?.movingCount ?? 0} in Transit',
        o?.averageSpeedKmh == null
            ? 'No speed samples'
            : 'Avg ${o!.averageSpeedKmh} km/h',
      ),
      _Kpi(
        'Doorstep Drop',
        '${o?.deliveringCount ?? 0} Delivering',
        'Near stop',
      ),
      _Kpi(
        'Stationary Alert',
        '${o?.stationaryAlertCount ?? 0} Idle',
        'Idle beyond threshold',
      ),
      _Kpi(
        'Device Health',
        '${o?.staleOrOfflineCount ?? 0} Stale/Offline',
        'Freshness window',
      ),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          for (final card in cards) ...[
            Container(
              width: 180,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AdminTokens.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    card.label,
                    style: adminType(
                      11,
                      FontWeight.w600,
                      AdminTokens.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    card.value,
                    style: adminType(16, FontWeight.w700, AdminTokens.text),
                  ),
                  Text(
                    card.note,
                    style: adminType(
                      11,
                      FontWeight.w500,
                      AdminTokens.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
          ],
        ],
      ),
    );
  }
}

class _Kpi {
  const _Kpi(this.label, this.value, this.note);
  final String label;
  final String value;
  final String note;
}

class _FleetMap extends StatelessWidget {
  const _FleetMap({
    required this.controller,
    required this.riders,
    required this.detail,
    required this.selectedId,
    required this.onSelect,
  });

  final MapController controller;
  final List<LiveRiderCard> riders;
  final LiveRiderDetail? detail;
  final String? selectedId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final points = <LatLng>[
      for (final rider in riders)
        if (rider.latitude != null && rider.longitude != null)
          LatLng(rider.latitude!.toDouble(), rider.longitude!.toDouble()),
      for (final stop in detail?.stops ?? const <AssignmentStopInfo>[])
        if (stop.latitude != null && stop.longitude != null)
          LatLng(stop.latitude!.toDouble(), stop.longitude!.toDouble()),
      for (final point in detail?.trail ?? const <LiveRiderTrailPoint>[])
        LatLng(point.latitude.toDouble(), point.longitude.toDouble()),
    ];
    final center = points.isEmpty
        ? const LatLng(33.5651, 73.0169)
        : points.first;
    final expected = [
      for (final stop in detail?.stops ?? const <AssignmentStopInfo>[])
        if (stop.latitude != null && stop.longitude != null)
          LatLng(stop.latitude!.toDouble(), stop.longitude!.toDouble()),
    ];
    final trail = [
      for (final point in detail?.trail ?? const <LiveRiderTrailPoint>[])
        LatLng(point.latitude.toDouble(), point.longitude.toDouble()),
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminTokens.line),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            FlutterMap(
              mapController: controller,
              options: MapOptions(
                initialCenter: center,
                initialZoom: points.length > 1 ? 12.5 : 13.5,
                initialCameraFit: points.length > 1
                    ? CameraFit.bounds(
                        bounds: LatLngBounds.fromPoints(points),
                        padding: const EdgeInsets.all(40),
                        maxZoom: 16,
                      )
                    : null,
              ),
              children: [
                if (WidgetsBinding.instance.runtimeType
                    .toString()
                    .contains('Test'))
                  const ColoredBox(color: Color(0xFFE2E8F0))
                else
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.riderfrontend',
                  ),
                if (expected.length > 1)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: expected,
                        strokeWidth: 3,
                        color: AdminTokens.primary.withValues(alpha: 0.55),
                      ),
                    ],
                  ),
                if (trail.length > 1)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: trail,
                        strokeWidth: 3.5,
                        color: const Color(0xFF0F172A),
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    for (final rider in riders)
                      if (rider.latitude != null && rider.longitude != null)
                        Marker(
                          point: LatLng(
                            rider.latitude!.toDouble(),
                            rider.longitude!.toDouble(),
                          ),
                          width: 140,
                          height: 54,
                          child: GestureDetector(
                            onTap: () => onSelect(rider.riderUserId),
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: rider.riderUserId == selectedId
                                        ? AdminTokens.button
                                        : rider.motionState == 'Idle'
                                        ? const Color(0xFFDC2626)
                                        : const Color(0xFF0F172A),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${rider.fullName.split(' ').first} · ${rider.motionState}',
                                    style: adminType(
                                      10,
                                      FontWeight.w700,
                                      Colors.white,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.navigation,
                                  color: rider.riderUserId == selectedId
                                      ? AdminTokens.button
                                      : const Color(0xFF0F172A),
                                  size: 22,
                                ),
                              ],
                            ),
                          ),
                        ),
                  ],
                ),
              ],
            ),
            Positioned(
              left: 12,
              bottom: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AdminTokens.line),
                ),
                child: Text(
                  riders.isEmpty
                      ? 'No active tracking sessions'
                      : 'Live Radar · ${riders.length} riders',
                  style: adminType(11, FontWeight.w600, AdminTokens.text),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RiderSidePanel extends StatelessWidget {
  const _RiderSidePanel({
    required this.riders,
    required this.detail,
    required this.anomalies,
    required this.selectedId,
    required this.onSelect,
    required this.onApprove,
    required this.onReject,
    required this.onResolve,
    required this.onFalsePositive,
  });

  final List<LiveRiderCard> riders;
  final LiveRiderDetail? detail;
  final List<RouteAnomalyInfo> anomalies;
  final String? selectedId;
  final ValueChanged<String> onSelect;
  final ValueChanged<RouteAnomalyInfo> onApprove;
  final ValueChanged<RouteAnomalyInfo> onReject;
  final ValueChanged<RouteAnomalyInfo> onResolve;
  final ValueChanged<RouteAnomalyInfo> onFalsePositive;

  @override
  Widget build(BuildContext context) {
    final card = detail?.card;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminTokens.line),
      ),
      child: ListView(
        children: [
          if (card != null) ...[
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AdminTokens.primarySoft,
                  child: Text(
                    card.fullName
                        .split(' ')
                        .where((part) => part.isNotEmpty)
                        .take(2)
                        .map((part) => part[0])
                        .join()
                        .toUpperCase(),
                    style: adminType(12, FontWeight.w700, AdminTokens.primary),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        card.fullName,
                        style: adminType(15, FontWeight.w700, AdminTokens.text),
                      ),
                      Text(
                        '${card.riderCode ?? '—'} · ${card.vehicleName ?? 'No vehicle'} ${card.vehiclePlate ?? ''}',
                        style: adminType(
                          11,
                          FontWeight.w500,
                          AdminTokens.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '${card.motionState} · ${card.speedKmh?.toStringAsFixed(0) ?? '—'} km/h · Batt ${card.batteryPercent ?? '—'}%',
              style: adminType(12, FontWeight.w600, AdminTokens.text),
            ),
            Text(
              'Next: ${card.nextWaypoint ?? '—'}',
              style: adminType(12, FontWeight.w500, AdminTokens.textSecondary),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: card.totalStops == 0
                  ? 0
                  : card.completedStops / card.totalStops,
              backgroundColor: AdminTokens.field,
              color: AdminTokens.button,
            ),
            const SizedBox(height: 4),
            Text(
              '${card.completedStops}/${card.totalStops} stops · ${card.routeName ?? 'Route'}',
              style: adminType(11, FontWeight.w500, AdminTokens.textSecondary),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                Text(
                  'Sales ${formatPkr(card.todaySales)}',
                  style: adminType(11, FontWeight.w600, AdminTokens.text),
                ),
                Text(
                  'Cash ${formatPkr(card.cashInHand)}',
                  style: adminType(11, FontWeight.w600, AdminTokens.text),
                ),
                Text(
                  'Returns ${card.emptyReturns}',
                  style: adminType(11, FontWeight.w600, AdminTokens.text),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(),
          ],
          Text(
            'Riders',
            style: adminType(13, FontWeight.w700, AdminTokens.text),
          ),
          for (final rider in riders)
            ListTile(
              contentPadding: EdgeInsets.zero,
              selected: rider.riderUserId == selectedId,
              title: Text(rider.fullName),
              subtitle: Text(
                '${rider.motionState} · ${rider.completedStops}/${rider.totalStops} · Cash ${formatPkr(rider.cashInHand)}',
              ),
              trailing: rider.motionState == 'Idle'
                  ? const Text(
                      'Idle',
                      style: TextStyle(
                        color: Color(0xFFDC2626),
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  : null,
              onTap: () => onSelect(rider.riderUserId),
            ),
          const Divider(),
          Text(
            'Anomalies',
            style: adminType(13, FontWeight.w700, AdminTokens.text),
          ),
          if (anomalies.isEmpty)
            Text(
              'No open anomalies for this selection.',
              style: adminType(12, FontWeight.w500, AdminTokens.textSecondary),
            ),
          for (final anomaly in anomalies.take(8)) ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('${anomaly.anomalyNumber} · ${anomaly.category}'),
              subtitle: Text(
                '${anomaly.status}\n${anomaly.expectedWaypoint ?? '—'} · ${anomaly.detectedAtUtc}',
              ),
              isThreeLine: true,
            ),
            Wrap(
              spacing: 6,
              children: [
                TextButton(
                  onPressed: () => onApprove(anomaly),
                  child: const Text('Approve'),
                ),
                TextButton(
                  onPressed: () => onReject(anomaly),
                  child: const Text('Reject'),
                ),
                TextButton(
                  onPressed: () => onResolve(anomaly),
                  child: const Text('Close'),
                ),
                TextButton(
                  onPressed: () => onFalsePositive(anomaly),
                  child: const Text('False +'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _FooterBar extends StatelessWidget {
  const _FooterBar({required this.overview});

  final LiveTrackingOverview? overview;

  @override
  Widget build(BuildContext context) {
    final o = overview;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      color: const Color(0xFFF8FAFC),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 8,
        children: [
          Text(
            'Fleet telemetry: ${o?.transmittingCount ?? 0}/${o?.ridersOnDuty ?? 0} transmitting · avg battery ${o?.averageBatteryPercent?.toStringAsFixed(0) ?? '—'}% · open anomalies ${o?.openAnomalies ?? 0}',
            style: adminType(12, FontWeight.w500, AdminTokens.textSecondary),
          ),
          Text(
            'Encrypted TLS telemetry',
            style: adminType(11, FontWeight.w600, AdminTokens.textSecondary),
          ),
        ],
      ),
    );
  }
}
