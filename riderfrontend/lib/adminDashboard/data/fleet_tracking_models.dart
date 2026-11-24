import 'package:riderfrontend/adminDashboard/data/admin_json.dart';

class TrackingSessionInfo {
  const TrackingSessionInfo({
    required this.id,
    required this.shiftId,
    this.routeId,
    required this.status,
    required this.startedAtUtc,
    this.endedAtUtc,
    this.endReason,
  });

  final String id;
  final String shiftId;
  final String? routeId;
  final String status;
  final String startedAtUtc;
  final String? endedAtUtc;
  final String? endReason;

  factory TrackingSessionInfo.fromJson(Object? data) {
    final map = jsonMap(data) ?? const <String, dynamic>{};
    return TrackingSessionInfo(
      id: jsonString(map, const ['id']) ?? '',
      shiftId: jsonString(map, const ['shiftId']) ?? '',
      routeId: jsonString(map, const ['routeId']),
      status: jsonString(map, const ['status']) ?? '',
      startedAtUtc: jsonString(map, const ['startedAtUtc']) ?? '',
      endedAtUtc: jsonString(map, const ['endedAtUtc']),
      endReason: jsonString(map, const ['endReason']),
    );
  }
}

class TrackingStatusInfo {
  const TrackingStatusInfo({
    this.trackingActive = false,
    this.session,
    this.lastFixAtUtc,
    this.lastLatitude,
    this.lastLongitude,
    this.lastAccuracyMeters,
    this.lastSpeedMps,
    this.lastBatteryPercent,
    this.networkStatus,
    this.lastFixStale = false,
    this.locationSharingLabel = 'Inactive',
  });

  final bool trackingActive;
  final TrackingSessionInfo? session;
  final String? lastFixAtUtc;
  final num? lastLatitude;
  final num? lastLongitude;
  final num? lastAccuracyMeters;
  final num? lastSpeedMps;
  final int? lastBatteryPercent;
  final String? networkStatus;
  final bool lastFixStale;
  final String locationSharingLabel;

  factory TrackingStatusInfo.fromJson(Object? data) {
    final map = jsonMap(data) ?? const <String, dynamic>{};
    return TrackingStatusInfo(
      trackingActive: map['trackingActive'] == true,
      session: map['session'] == null
          ? null
          : TrackingSessionInfo.fromJson(map['session']),
      lastFixAtUtc: jsonString(map, const ['lastFixAtUtc']),
      lastLatitude: optionalNum(map, const ['lastLatitude']),
      lastLongitude: optionalNum(map, const ['lastLongitude']),
      lastAccuracyMeters: optionalNum(map, const ['lastAccuracyMeters']),
      lastSpeedMps: optionalNum(map, const ['lastSpeedMps']),
      lastBatteryPercent: optionalInt(map, const ['lastBatteryPercent']),
      networkStatus: jsonString(map, const ['networkStatus']),
      lastFixStale: map['lastFixStale'] == true,
      locationSharingLabel:
          jsonString(map, const ['locationSharingLabel']) ?? 'Inactive',
    );
  }
}

class AssignmentStopInfo {
  const AssignmentStopInfo({
    required this.stopId,
    required this.customerId,
    required this.customerName,
    required this.sequence,
    required this.status,
    this.latitude,
    this.longitude,
  });

  final String stopId;
  final String customerId;
  final String customerName;
  final int sequence;
  final String status;
  final num? latitude;
  final num? longitude;

  factory AssignmentStopInfo.fromJson(Object? data) {
    final map = jsonMap(data) ?? const <String, dynamic>{};
    return AssignmentStopInfo(
      stopId: jsonString(map, const ['stopId']) ?? '',
      customerId: jsonString(map, const ['customerId']) ?? '',
      customerName: jsonString(map, const ['customerName']) ?? '',
      sequence: optionalInt(map, const ['sequence']) ?? 0,
      status: jsonString(map, const ['status']) ?? '',
      latitude: optionalNum(map, const ['latitude']),
      longitude: optionalNum(map, const ['longitude']),
    );
  }
}

class ActiveAssignmentInfo {
  const ActiveAssignmentInfo({
    required this.riderUserId,
    this.riderCode = '',
    this.fullName = '',
    this.depotName,
    this.vehicleName,
    this.vehiclePlate,
    this.fleetCode,
    this.routeId,
    this.routeName,
    this.shiftId,
    this.shiftStatus,
    this.nextStop,
    this.stops = const [],
    this.completedStops = 0,
    this.pendingStops = 0,
    this.totalStops = 0,
  });

  final String riderUserId;
  final String riderCode;
  final String fullName;
  final String? depotName;
  final String? vehicleName;
  final String? vehiclePlate;
  final String? fleetCode;
  final String? routeId;
  final String? routeName;
  final String? shiftId;
  final String? shiftStatus;
  final AssignmentStopInfo? nextStop;
  final List<AssignmentStopInfo> stops;
  final int completedStops;
  final int pendingStops;
  final int totalStops;

  factory ActiveAssignmentInfo.fromJson(Object? data) {
    final map = jsonMap(data) ?? const <String, dynamic>{};
    final stops = (map['stops'] as List?)
            ?.map(AssignmentStopInfo.fromJson)
            .toList() ??
        const <AssignmentStopInfo>[];
    return ActiveAssignmentInfo(
      riderUserId: jsonString(map, const ['riderUserId']) ?? '',
      riderCode: jsonString(map, const ['riderCode']) ?? '',
      fullName: jsonString(map, const ['fullName']) ?? '',
      depotName: jsonString(map, const ['depotName']),
      vehicleName: jsonString(map, const ['vehicleName']),
      vehiclePlate: jsonString(map, const ['vehiclePlate']),
      fleetCode: jsonString(map, const ['fleetCode']),
      routeId: jsonString(map, const ['routeId']),
      routeName: jsonString(map, const ['routeName']),
      shiftId: jsonString(map, const ['shiftId']),
      shiftStatus: jsonString(map, const ['shiftStatus']),
      nextStop: map['nextStop'] == null
          ? null
          : AssignmentStopInfo.fromJson(map['nextStop']),
      stops: stops,
      completedStops: optionalInt(map, const ['completedStops']) ?? 0,
      pendingStops: optionalInt(map, const ['pendingStops']) ?? 0,
      totalStops: optionalInt(map, const ['totalStops']) ?? 0,
    );
  }
}

class RouteComplianceStateInfo {
  const RouteComplianceStateInfo({
    this.state = 'OnRoute',
    this.summary = '',
    this.openAnomalyId,
    this.openAnomalyNumber,
    this.openAnomalyCategory,
    this.lastEvaluatedAtUtc,
  });

  final String state;
  final String summary;
  final String? openAnomalyId;
  final String? openAnomalyNumber;
  final String? openAnomalyCategory;
  final String? lastEvaluatedAtUtc;

  factory RouteComplianceStateInfo.fromJson(Object? data) {
    final map = jsonMap(data) ?? const <String, dynamic>{};
    return RouteComplianceStateInfo(
      state: jsonString(map, const ['state']) ?? 'OnRoute',
      summary: jsonString(map, const ['summary']) ?? '',
      openAnomalyId: jsonString(map, const ['openAnomalyId']),
      openAnomalyNumber: jsonString(map, const ['openAnomalyNumber']),
      openAnomalyCategory: jsonString(map, const ['openAnomalyCategory']),
      lastEvaluatedAtUtc: jsonString(map, const ['lastEvaluatedAtUtc']),
    );
  }
}

class RouteAnomalyInfo {
  const RouteAnomalyInfo({
    required this.id,
    required this.anomalyNumber,
    required this.riderUserId,
    this.riderName = '',
    this.riderCode,
    this.trackingSessionId = '',
    this.routeId,
    this.routeName,
    this.category = '',
    this.severity = '',
    this.status = '',
    this.detectedAtUtc = '',
    this.lastLatitude,
    this.lastLongitude,
    this.expectedWaypoint,
    this.actualHeadingDegrees,
    this.expectedHeadingDegrees,
    this.evidenceJson = '{}',
    this.responseDueAtUtc,
    this.resolvedAtUtc,
    this.resolutionNotes,
    this.explanations = const [],
    this.reviews = const [],
  });

  final String id;
  final String anomalyNumber;
  final String riderUserId;
  final String riderName;
  final String? riderCode;
  final String trackingSessionId;
  final String? routeId;
  final String? routeName;
  final String category;
  final String severity;
  final String status;
  final String detectedAtUtc;
  final num? lastLatitude;
  final num? lastLongitude;
  final String? expectedWaypoint;
  final num? actualHeadingDegrees;
  final num? expectedHeadingDegrees;
  final String evidenceJson;
  final String? responseDueAtUtc;
  final String? resolvedAtUtc;
  final String? resolutionNotes;
  final List<AnomalyExplanationInfo> explanations;
  final List<AnomalyReviewInfo> reviews;

  factory RouteAnomalyInfo.fromJson(Object? data) {
    final map = jsonMap(data) ?? const <String, dynamic>{};
    return RouteAnomalyInfo(
      id: jsonString(map, const ['id']) ?? '',
      anomalyNumber: jsonString(map, const ['anomalyNumber']) ?? '',
      riderUserId: jsonString(map, const ['riderUserId']) ?? '',
      riderName: jsonString(map, const ['riderName']) ?? '',
      riderCode: jsonString(map, const ['riderCode']),
      trackingSessionId: jsonString(map, const ['trackingSessionId']) ?? '',
      routeId: jsonString(map, const ['routeId']),
      routeName: jsonString(map, const ['routeName']),
      category: jsonString(map, const ['category']) ?? '',
      severity: jsonString(map, const ['severity']) ?? '',
      status: jsonString(map, const ['status']) ?? '',
      detectedAtUtc: jsonString(map, const ['detectedAtUtc']) ?? '',
      lastLatitude: optionalNum(map, const ['lastLatitude']),
      lastLongitude: optionalNum(map, const ['lastLongitude']),
      expectedWaypoint: jsonString(map, const ['expectedWaypoint']),
      actualHeadingDegrees: optionalNum(map, const ['actualHeadingDegrees']),
      expectedHeadingDegrees: optionalNum(map, const ['expectedHeadingDegrees']),
      evidenceJson: jsonString(map, const ['evidenceJson']) ?? '{}',
      responseDueAtUtc: jsonString(map, const ['responseDueAtUtc']),
      resolvedAtUtc: jsonString(map, const ['resolvedAtUtc']),
      resolutionNotes: jsonString(map, const ['resolutionNotes']),
      explanations: (map['explanations'] as List?)
              ?.map(AnomalyExplanationInfo.fromJson)
              .toList() ??
          const [],
      reviews: (map['reviews'] as List?)
              ?.map(AnomalyReviewInfo.fromJson)
              .toList() ??
          const [],
    );
  }
}

class AnomalyExplanationInfo {
  const AnomalyExplanationInfo({
    required this.id,
    required this.reason,
    required this.explanationText,
    this.supportingNote,
    required this.submittedAtUtc,
    this.isCorrection = false,
  });

  final String id;
  final String reason;
  final String explanationText;
  final String? supportingNote;
  final String submittedAtUtc;
  final bool isCorrection;

  factory AnomalyExplanationInfo.fromJson(Object? data) {
    final map = jsonMap(data) ?? const <String, dynamic>{};
    return AnomalyExplanationInfo(
      id: jsonString(map, const ['id']) ?? '',
      reason: jsonString(map, const ['reason']) ?? '',
      explanationText: jsonString(map, const ['explanationText']) ?? '',
      supportingNote: jsonString(map, const ['supportingNote']),
      submittedAtUtc: jsonString(map, const ['submittedAtUtc']) ?? '',
      isCorrection: map['isCorrection'] == true,
    );
  }
}

class AnomalyReviewInfo {
  const AnomalyReviewInfo({
    required this.id,
    required this.adminUserId,
    required this.action,
    this.notes,
    required this.occurredAtUtc,
  });

  final String id;
  final String adminUserId;
  final String action;
  final String? notes;
  final String occurredAtUtc;

  factory AnomalyReviewInfo.fromJson(Object? data) {
    final map = jsonMap(data) ?? const <String, dynamic>{};
    return AnomalyReviewInfo(
      id: jsonString(map, const ['id']) ?? '',
      adminUserId: jsonString(map, const ['adminUserId']) ?? '',
      action: jsonString(map, const ['action']) ?? '',
      notes: jsonString(map, const ['notes']),
      occurredAtUtc: jsonString(map, const ['occurredAtUtc']) ?? '',
    );
  }
}

class RiderNotificationInfo {
  const RiderNotificationInfo({
    required this.id,
    required this.title,
    required this.body,
    this.deepLink = 'route-compliance',
    this.anomalyId,
    this.isRead = false,
    required this.createdAtUtc,
  });

  final String id;
  final String title;
  final String body;
  final String deepLink;
  final String? anomalyId;
  final bool isRead;
  final String createdAtUtc;

  factory RiderNotificationInfo.fromJson(Object? data) {
    final map = jsonMap(data) ?? const <String, dynamic>{};
    return RiderNotificationInfo(
      id: jsonString(map, const ['id']) ?? '',
      title: jsonString(map, const ['title']) ?? '',
      body: jsonString(map, const ['body']) ?? '',
      deepLink: jsonString(map, const ['deepLink']) ?? 'route-compliance',
      anomalyId: jsonString(map, const ['anomalyId']),
      isRead: map['isRead'] == true,
      createdAtUtc: jsonString(map, const ['createdAtUtc']) ?? '',
    );
  }
}

class LiveTrackingOverview {
  const LiveTrackingOverview({
    this.ridersOnDuty = 0,
    this.fleetTotal = 0,
    this.movingCount = 0,
    this.averageSpeedKmh,
    this.deliveringCount = 0,
    this.stationaryAlertCount = 0,
    this.staleOrOfflineCount = 0,
    this.transmittingCount = 0,
    this.averageBatteryPercent,
    this.openAnomalies = 0,
  });

  final int ridersOnDuty;
  final int fleetTotal;
  final int movingCount;
  final num? averageSpeedKmh;
  final int deliveringCount;
  final int stationaryAlertCount;
  final int staleOrOfflineCount;
  final int transmittingCount;
  final num? averageBatteryPercent;
  final int openAnomalies;

  factory LiveTrackingOverview.fromJson(Object? data) {
    final map = jsonMap(data) ?? const <String, dynamic>{};
    return LiveTrackingOverview(
      ridersOnDuty: optionalInt(map, const ['ridersOnDuty']) ?? 0,
      fleetTotal: optionalInt(map, const ['fleetTotal']) ?? 0,
      movingCount: optionalInt(map, const ['movingCount']) ?? 0,
      averageSpeedKmh: optionalNum(map, const ['averageSpeedKmh']),
      deliveringCount: optionalInt(map, const ['deliveringCount']) ?? 0,
      stationaryAlertCount:
          optionalInt(map, const ['stationaryAlertCount']) ?? 0,
      staleOrOfflineCount: optionalInt(map, const ['staleOrOfflineCount']) ?? 0,
      transmittingCount: optionalInt(map, const ['transmittingCount']) ?? 0,
      averageBatteryPercent: optionalNum(map, const ['averageBatteryPercent']),
      openAnomalies: optionalInt(map, const ['openAnomalies']) ?? 0,
    );
  }
}

class LiveRiderCard {
  const LiveRiderCard({
    required this.riderUserId,
    required this.fullName,
    this.riderCode,
    this.vehicleName,
    this.vehiclePlate,
    this.fleetCode,
    this.routeName,
    this.routeId,
    this.sessionId,
    this.trackingActive = false,
    this.motionState = 'Offline',
    this.latitude,
    this.longitude,
    this.lastFixAtUtc,
    this.lastFixStale = false,
    this.speedKmh,
    this.accuracyMeters,
    this.batteryPercent,
    this.networkStatus,
    this.nextWaypoint,
    this.completedStops = 0,
    this.totalStops = 0,
    this.todaySales = 0,
    this.cashInHand = 0,
    this.emptyReturns = 0,
    this.openAnomalies = 0,
    this.pendingExplanations = 0,
  });

  final String riderUserId;
  final String fullName;
  final String? riderCode;
  final String? vehicleName;
  final String? vehiclePlate;
  final String? fleetCode;
  final String? routeName;
  final String? routeId;
  final String? sessionId;
  final bool trackingActive;
  final String motionState;
  final num? latitude;
  final num? longitude;
  final String? lastFixAtUtc;
  final bool lastFixStale;
  final num? speedKmh;
  final num? accuracyMeters;
  final int? batteryPercent;
  final String? networkStatus;
  final String? nextWaypoint;
  final int completedStops;
  final int totalStops;
  final num todaySales;
  final num cashInHand;
  final int emptyReturns;
  final int openAnomalies;
  final int pendingExplanations;

  factory LiveRiderCard.fromJson(Object? data) {
    final map = jsonMap(data) ?? const <String, dynamic>{};
    return LiveRiderCard(
      riderUserId: jsonString(map, const ['riderUserId']) ?? '',
      fullName: jsonString(map, const ['fullName']) ?? '',
      riderCode: jsonString(map, const ['riderCode']),
      vehicleName: jsonString(map, const ['vehicleName']),
      vehiclePlate: jsonString(map, const ['vehiclePlate']),
      fleetCode: jsonString(map, const ['fleetCode']),
      routeName: jsonString(map, const ['routeName']),
      routeId: jsonString(map, const ['routeId']),
      sessionId: jsonString(map, const ['sessionId']),
      trackingActive: map['trackingActive'] == true,
      motionState: jsonString(map, const ['motionState']) ?? 'Offline',
      latitude: optionalNum(map, const ['latitude']),
      longitude: optionalNum(map, const ['longitude']),
      lastFixAtUtc: jsonString(map, const ['lastFixAtUtc']),
      lastFixStale: map['lastFixStale'] == true,
      speedKmh: optionalNum(map, const ['speedKmh']),
      accuracyMeters: optionalNum(map, const ['accuracyMeters']),
      batteryPercent: optionalInt(map, const ['batteryPercent']),
      networkStatus: jsonString(map, const ['networkStatus']),
      nextWaypoint: jsonString(map, const ['nextWaypoint']),
      completedStops: optionalInt(map, const ['completedStops']) ?? 0,
      totalStops: optionalInt(map, const ['totalStops']) ?? 0,
      todaySales: optionalNum(map, const ['todaySales']) ?? 0,
      cashInHand: optionalNum(map, const ['cashInHand']) ?? 0,
      emptyReturns: optionalInt(map, const ['emptyReturns']) ?? 0,
      openAnomalies: optionalInt(map, const ['openAnomalies']) ?? 0,
      pendingExplanations: optionalInt(map, const ['pendingExplanations']) ?? 0,
    );
  }
}

class LiveRiderTrailPoint {
  const LiveRiderTrailPoint({
    required this.latitude,
    required this.longitude,
    required this.deviceTimestampUtc,
    this.speedMetersPerSecond,
    this.headingDegrees,
  });

  final num latitude;
  final num longitude;
  final String deviceTimestampUtc;
  final num? speedMetersPerSecond;
  final num? headingDegrees;

  factory LiveRiderTrailPoint.fromJson(Object? data) {
    final map = jsonMap(data) ?? const <String, dynamic>{};
    return LiveRiderTrailPoint(
      latitude: optionalNum(map, const ['latitude']) ?? 0,
      longitude: optionalNum(map, const ['longitude']) ?? 0,
      deviceTimestampUtc: jsonString(map, const ['deviceTimestampUtc']) ?? '',
      speedMetersPerSecond: optionalNum(map, const ['speedMetersPerSecond']),
      headingDegrees: optionalNum(map, const ['headingDegrees']),
    );
  }
}

class LiveRiderDetail {
  const LiveRiderDetail({
    required this.card,
    this.trail = const [],
    this.stops = const [],
    this.recentAnomalies = const [],
  });

  final LiveRiderCard card;
  final List<LiveRiderTrailPoint> trail;
  final List<AssignmentStopInfo> stops;
  final List<RouteAnomalyInfo> recentAnomalies;

  factory LiveRiderDetail.fromJson(Object? data) {
    final map = jsonMap(data) ?? const <String, dynamic>{};
    return LiveRiderDetail(
      card: LiveRiderCard.fromJson(map['card']),
      trail: (map['trail'] as List?)
              ?.map(LiveRiderTrailPoint.fromJson)
              .toList() ??
          const [],
      stops: (map['stops'] as List?)
              ?.map(AssignmentStopInfo.fromJson)
              .toList() ??
          const [],
      recentAnomalies: (map['recentAnomalies'] as List?)
              ?.map(RouteAnomalyInfo.fromJson)
              .toList() ??
          const [],
    );
  }
}
