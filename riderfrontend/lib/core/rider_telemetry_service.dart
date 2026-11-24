import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:location/location.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/route_api.dart';

/// Foreground GPS collector for authorized shifts. Queues offline and syncs.
class RiderTelemetryService {
  RiderTelemetryService._();
  static final RiderTelemetryService instance = RiderTelemetryService._();

  static const _queueKey = 'rider_telemetry_queue_v1';

  final Location _location = Location();
  RouteApi? _api;
  String? _sessionId;
  Timer? _timer;
  StreamSubscription<LocationData>? _stream;
  var _running = false;
  var _flushing = false;

  bool get isRunning => _running;
  String? get sessionId => _sessionId;

  void bindApi(RouteApi api) => _api = api;

  Future<void> startForShift(RouteApi api) async {
    _api = api;
    if (_running) return;
    final ready = await _ensurePermission();
    if (!ready) {
      throw StateError('Location permission is required for route compliance.');
    }

    if (!kIsWeb) {
      try {
        await _location.enableBackgroundMode(enable: true);
      } catch (_) {}
    }

    final session = await api.startTracking();
    _sessionId = session.id;
    _running = true;
    _timer?.cancel();
    _timer = Timer.periodic(
      const Duration(seconds: 45),
      (_) => _captureAndFlush(),
    );
    try {
      _stream = _location.onLocationChanged.listen((_) {});
    } catch (_) {}
    await _captureAndFlush();
  }

  Future<void> stop({String? reason}) async {
    _timer?.cancel();
    _timer = null;
    await _stream?.cancel();
    _stream = null;
    final api = _api;
    final session = _sessionId;
    _running = false;
    _sessionId = null;
    if (!kIsWeb) {
      try {
        await _location.enableBackgroundMode(enable: false);
      } catch (_) {}
    }
    if (api != null && session != null) {
      try {
        await _flushQueue(force: true);
        await api.stopTracking(reason: reason ?? 'StoppedByRider');
      } catch (_) {}
    }
  }

  Future<bool> _ensurePermission() async {
    var serviceOn = await _location.serviceEnabled();
    if (!serviceOn) {
      serviceOn = await _location.requestService();
      if (!serviceOn) return false;
    }
    var permission = await _location.hasPermission();
    if (permission == PermissionStatus.denied) {
      permission = await _location.requestPermission();
    }
    return permission == PermissionStatus.granted ||
        permission == PermissionStatus.grantedLimited;
  }

  Future<void> _captureAndFlush() async {
    if (!_running || _api == null) return;
    try {
      final fix = await _location.getLocation();
      final point = <String, dynamic>{
        'latitude': fix.latitude,
        'longitude': fix.longitude,
        'accuracyMeters': fix.accuracy,
        'speedMetersPerSecond': fix.speed,
        'headingDegrees': fix.heading,
        'deviceTimestampUtc': DateTime.now().toUtc().toIso8601String(),
        'batteryPercent': null,
        'networkStatus': kIsWeb ? 'web' : 'mobile',
      };
      await _enqueue(point);
      await _flushQueue();
    } catch (error, stack) {
      debugPrint('Telemetry capture failed: $error\n$stack');
    }
  }

  Future<List<Map<String, dynamic>>> _readQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_queueKey);
      if (raw == null || raw.isEmpty) return [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _writeQueue(List<Map<String, dynamic>> rows) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_queueKey, jsonEncode(rows));
  }

  Future<void> _enqueue(Map<String, dynamic> point) async {
    final rows = await _readQueue();
    rows.add(point);
    if (rows.length > 200) {
      rows.removeRange(0, rows.length - 200);
    }
    await _writeQueue(rows);
  }

  Future<void> _flushQueue({bool force = false}) async {
    if (_flushing && !force) return;
    final api = _api;
    final sessionId = _sessionId;
    if (api == null) return;
    _flushing = true;
    try {
      final rows = await _readQueue();
      if (rows.isEmpty) return;
      const chunk = 20;
      var offset = 0;
      while (offset < rows.length) {
        final end =
            (offset + chunk > rows.length) ? rows.length : offset + chunk;
        final batch = rows.sublist(offset, end);
        await api.uploadTrackingLocations(
          sessionId: sessionId,
          points: batch,
        );
        offset = end;
      }
      await _writeQueue([]);
    } catch (error, stack) {
      debugPrint('Telemetry flush failed: $error\n$stack');
    } finally {
      _flushing = false;
    }
  }
}
