import 'package:flutter/material.dart';

import '../adminDashboard/data/fleet_tracking_models.dart';
import '../api/route_api.dart';
import '../core/rider_telemetry_service.dart';
import '../ui/route_ui.dart';

class RouteComplianceScreen extends StatefulWidget {
  const RouteComplianceScreen({super.key});

  @override
  State<RouteComplianceScreen> createState() => _RouteComplianceScreenState();
}

class _RouteComplianceScreenState extends State<RouteComplianceScreen> {
  var _loading = true;
  String? _error;
  TrackingStatusInfo? _status;
  ActiveAssignmentInfo? _assignment;
  RouteComplianceStateInfo? _compliance;
  List<RouteAnomalyInfo> _anomalies = const [];
  List<RiderNotificationInfo> _notifications = const [];
  String? _selectedAnomalyId;
  String _reason = 'TrafficCongestion';
  final _explanation = TextEditingController();
  var _submitting = false;

  static const _reasons = <String, String>{
    'RoadBlocked': 'Road blocked',
    'TrafficCongestion': 'Traffic congestion',
    'CustomerRequestedDifferentLocation': 'Customer requested a different location',
    'VehicleProblem': 'Vehicle problem',
    'Emergency': 'Emergency',
    'WarehouseInstruction': 'Warehouse instruction',
    'GpsNavigationError': 'GPS/navigation error',
    'Other': 'Other reason',
  };

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _explanation.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ApiScope.of(context);
      final status = await api.trackingStatus();
      final assignment = await api.activeAssignment();
      final compliance = await api.routeComplianceCurrent();
      final anomalies = await api.riderRouteAnomalies();
      final notifications = await api.riderNotifications();
      if (!mounted) return;
      setState(() {
        _status = status;
        _assignment = assignment;
        _compliance = compliance;
        _anomalies = anomalies;
        _notifications = notifications;
        _selectedAnomalyId =
            compliance.openAnomalyId ??
            (anomalies.isEmpty ? null : anomalies.first.id);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _toggleSharing() async {
    final api = ApiScope.of(context);
    try {
      if (RiderTelemetryService.instance.isRunning ||
          (_status?.trackingActive ?? false)) {
        await RiderTelemetryService.instance.stop();
      } else {
        await RiderTelemetryService.instance.startForShift(api);
      }
      await _reload();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _submitExplanation() async {
    final anomalyId = _selectedAnomalyId;
    if (anomalyId == null) return;
    if (_reason == 'Other' && _explanation.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Explanation text is required for Other.')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await ApiScope.of(context).submitAnomalyExplanation(
        anomalyId: anomalyId,
        reason: _reason,
        explanationText: _explanation.text.trim().isEmpty
            ? _reasons[_reason]!
            : _explanation.text.trim(),
      );
      _explanation.clear();
      await _reload();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RouteColors.page,
      appBar: AppBar(
        title: const Text('Route Compliance & Alerts'),
        backgroundColor: Colors.white,
        foregroundColor: RouteColors.ink,
        elevation: 0,
        actions: [
          IconButton(onPressed: _reload, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : RefreshIndicator(
              onRefresh: _reload,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  _section(
                    'Current Assignment',
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _assignment?.routeName ?? 'No route assigned',
                          style: routeType(
                            16,
                            FontWeight.w700,
                            RouteColors.ink,
                            22,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          [
                            if ((_assignment?.riderCode ?? '').isNotEmpty)
                              _assignment!.riderCode,
                            if ((_assignment?.depotName ?? '').isNotEmpty)
                              _assignment!.depotName,
                            if ((_assignment?.vehicleName ?? '').isNotEmpty)
                              '${_assignment!.vehicleName} ${_assignment!.vehiclePlate ?? ''}'
                                  .trim(),
                          ].join(' · '),
                          style: routeType(
                            13,
                            FontWeight.w400,
                            RouteColors.body,
                            18,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Next waypoint: ${_assignment?.nextStop?.customerName ?? 'None pending'}',
                          style: routeType(
                            13,
                            FontWeight.w600,
                            RouteColors.ink,
                            18,
                          ),
                        ),
                        Text(
                          '${_assignment?.completedStops ?? 0} of ${_assignment?.totalStops ?? 0} stops completed',
                          style: routeType(
                            12,
                            FontWeight.w400,
                            RouteColors.body,
                            16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _section(
                    'Tracking Status',
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Location sharing: ${_status?.locationSharingLabel ?? 'Inactive'}',
                          style: routeType(
                            14,
                            FontWeight.w700,
                            (_status?.trackingActive ?? false)
                                ? const Color(0xFF16A34A)
                                : RouteColors.body,
                            20,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Last GPS update: ${_status?.lastFixAtUtc ?? 'None'}',
                          style: routeType(
                            12,
                            FontWeight.w400,
                            RouteColors.body,
                            16,
                          ),
                        ),
                        Text(
                          'Accuracy: ${_status?.lastAccuracyMeters?.toStringAsFixed(0) ?? '—'} m · Network: ${_status?.networkStatus ?? '—'}',
                          style: routeType(
                            12,
                            FontWeight.w400,
                            RouteColors.body,
                            16,
                          ),
                        ),
                        const SizedBox(height: 10),
                        FilledButton(
                          onPressed: _toggleSharing,
                          child: Text(
                            (_status?.trackingActive ?? false)
                                ? 'Stop location sharing'
                                : 'Start location sharing',
                          ),
                        ),
                      ],
                    ),
                  ),
                  _section(
                    'Route Compliance',
                    Text(
                      '${_compliance?.state ?? 'OnRoute'}\n${_compliance?.summary ?? ''}',
                      style: routeType(
                        14,
                        FontWeight.w600,
                        _complianceColor(_compliance?.state),
                        20,
                      ),
                    ),
                  ),
                  _section(
                    'Notifications',
                    _notifications.isEmpty
                        ? Text(
                            'No compliance notifications.',
                            style: routeType(
                              13,
                              FontWeight.w400,
                              RouteColors.body,
                              18,
                            ),
                          )
                        : Column(
                            children: [
                              for (final item in _notifications.take(8))
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(item.title),
                                  subtitle: Text(item.body),
                                  trailing: item.isRead
                                      ? null
                                      : const Icon(
                                          Icons.circle,
                                          size: 10,
                                          color: Color(0xFF2563EB),
                                        ),
                                  onTap: () async {
                                    if (!item.isRead) {
                                      await ApiScope.of(
                                        context,
                                      ).markRiderNotificationRead(item.id);
                                    }
                                    if (item.anomalyId != null) {
                                      setState(
                                        () =>
                                            _selectedAnomalyId = item.anomalyId,
                                      );
                                    }
                                    await _reload();
                                  },
                                ),
                            ],
                          ),
                  ),
                  _section(
                    'Submit Explanation',
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: _selectedAnomalyId,
                          items: [
                            for (final row in _anomalies.where(
                              (item) =>
                                  item.status.contains('Awaiting') ||
                                  item.status.contains('Rejected') ||
                                  item.status.contains('Notification') ||
                                  item.status.contains('Detected') ||
                                  item.status.contains('Reopened'),
                            ))
                              DropdownMenuItem(
                                value: row.id,
                                child: Text(
                                  '${row.anomalyNumber} · ${row.category}',
                                ),
                              ),
                          ],
                          onChanged: (value) =>
                              setState(() => _selectedAnomalyId = value),
                          decoration: const InputDecoration(
                            labelText: 'Anomaly reference',
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          initialValue: _reason,
                          items: [
                            for (final entry in _reasons.entries)
                              DropdownMenuItem(
                                value: entry.key,
                                child: Text(entry.value),
                              ),
                          ],
                          onChanged: (value) {
                            if (value != null) setState(() => _reason = value);
                          },
                          decoration: const InputDecoration(labelText: 'Reason'),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _explanation,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Explanation',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 10),
                        FilledButton(
                          onPressed: _submitting || _selectedAnomalyId == null
                              ? null
                              : _submitExplanation,
                          child: _submitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Submit explanation'),
                        ),
                      ],
                    ),
                  ),
                  _section(
                    'My Route Anomaly History',
                    _anomalies.isEmpty
                        ? Text(
                            'No anomalies recorded.',
                            style: routeType(
                              13,
                              FontWeight.w400,
                              RouteColors.body,
                              18,
                            ),
                          )
                        : Column(
                            children: [
                              for (final row in _anomalies)
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                    '${row.anomalyNumber} · ${row.category}',
                                  ),
                                  subtitle: Text(
                                    '${row.status}\n${row.expectedWaypoint ?? '—'} · ${row.detectedAtUtc}',
                                  ),
                                  isThreeLine: true,
                                  onTap: () => setState(
                                    () => _selectedAnomalyId = row.id,
                                  ),
                                ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _section(String title, Widget child) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: routeSoftShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: routeType(13, FontWeight.w700, RouteColors.ink, 18),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  Color _complianceColor(String? state) {
    switch (state) {
      case 'OnRoute':
        return const Color(0xFF16A34A);
      case 'ExplanationSubmitted':
        return const Color(0xFF2563EB);
      case 'ExplanationRequired':
      case 'RouteDeviationDetected':
        return const Color(0xFFDC2626);
      default:
        return RouteColors.body;
    }
  }
}
