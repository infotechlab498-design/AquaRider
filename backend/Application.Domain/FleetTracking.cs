namespace RouteLedger.Domain;

public enum TrackingSessionStatus
{
    Active,
    Ended
}

public enum RouteAnomalyCategory
{
    WrongDirection,
    RouteDeviation,
    UnexpectedBacktracking,
    CustomerStopSkipped,
    UnexpectedLongStop,
    GpsUnavailable,
    GpsInaccurate,
    AssignmentMismatch
}

public enum RouteAnomalySeverity
{
    Info,
    Warning,
    Critical
}

public enum RouteAnomalyStatus
{
    Detected,
    NotificationSent,
    AwaitingRiderResponse,
    AwaitingResponseOverdue,
    ExplanationSubmitted,
    UnderAdminReview,
    Approved,
    Rejected,
    Resolved,
    FalsePositive,
    Cancelled,
    Reopened
}

public enum AnomalyExplanationReason
{
    RoadBlocked,
    TrafficCongestion,
    CustomerRequestedDifferentLocation,
    VehicleProblem,
    Emergency,
    WarehouseInstruction,
    GpsNavigationError,
    Other
}

/// <summary>Authorized GPS tracking window bound to an open field shift.</summary>
public sealed class TrackingSession : Entity
{
    public string RiderUserId { get; set; } = "";
    public Guid ShiftId { get; set; }
    public Guid? RouteId { get; set; }
    public Guid? VehicleId { get; set; }
    public Guid? DepotId { get; set; }
    public TrackingSessionStatus Status { get; set; } = TrackingSessionStatus.Active;
    public DateTime StartedAtUtc { get; set; } = DateTime.UtcNow;
    public DateTime? EndedAtUtc { get; set; }
    public string? EndReason { get; set; }
    public List<RiderLocationTelemetry> Locations { get; set; } = [];
}

/// <summary>Immutable GPS evidence for a tracking session.</summary>
public sealed class RiderLocationTelemetry : Entity
{
    public Guid TrackingSessionId { get; set; }
    public TrackingSession TrackingSession { get; set; } = null!;
    public string RiderUserId { get; set; } = "";
    public double Latitude { get; set; }
    public double Longitude { get; set; }
    public double? AccuracyMeters { get; set; }
    public double? SpeedMetersPerSecond { get; set; }
    public double? HeadingDegrees { get; set; }
    public DateTime DeviceTimestampUtc { get; set; }
    public DateTime ServerReceivedAtUtc { get; set; } = DateTime.UtcNow;
    public int? BatteryPercent { get; set; }
    public string? NetworkStatus { get; set; }
    public bool IsStale { get; set; }
    public bool Rejected { get; set; }
    public string? RejectReason { get; set; }
}

public sealed class RouteComplianceAnomaly : Entity
{
    public string AnomalyNumber { get; set; } = "";
    public string RiderUserId { get; set; } = "";
    public Guid TrackingSessionId { get; set; }
    public TrackingSession TrackingSession { get; set; } = null!;
    public Guid? ShiftId { get; set; }
    public Guid? RouteId { get; set; }
    public RouteAnomalyCategory Category { get; set; }
    public RouteAnomalySeverity Severity { get; set; } = RouteAnomalySeverity.Warning;
    public RouteAnomalyStatus Status { get; set; } = RouteAnomalyStatus.Detected;
    public DateTime DetectedAtUtc { get; set; } = DateTime.UtcNow;
    public double? LastLatitude { get; set; }
    public double? LastLongitude { get; set; }
    public string? ExpectedWaypoint { get; set; }
    public Guid? ExpectedStopId { get; set; }
    public double? ActualHeadingDegrees { get; set; }
    public double? ExpectedHeadingDegrees { get; set; }
    public string EvidenceJson { get; set; } = "{}";
    public DateTime? ResponseDueAtUtc { get; set; }
    public DateTime? ResolvedAtUtc { get; set; }
    public string? ResolutionNotes { get; set; }
    public List<RiderAnomalyExplanation> Explanations { get; set; } = [];
    public List<RouteComplianceReview> Reviews { get; set; } = [];
    public List<RouteAnomalyStatusEvent> StatusHistory { get; set; } = [];
}

public sealed class RiderAnomalyExplanation : Entity
{
    public Guid AnomalyId { get; set; }
    public RouteComplianceAnomaly Anomaly { get; set; } = null!;
    public string RiderUserId { get; set; } = "";
    public AnomalyExplanationReason Reason { get; set; }
    public string ExplanationText { get; set; } = "";
    public string? SupportingNote { get; set; }
    public DateTime SubmittedAtUtc { get; set; } = DateTime.UtcNow;
    public bool IsCorrection { get; set; }
}

public sealed class RouteComplianceReview : Entity
{
    public Guid AnomalyId { get; set; }
    public RouteComplianceAnomaly Anomaly { get; set; } = null!;
    public string AdminUserId { get; set; } = "";
    public string Action { get; set; } = "";
    public string? Notes { get; set; }
    public DateTime OccurredAtUtc { get; set; } = DateTime.UtcNow;
}

public sealed class RouteAnomalyStatusEvent : Entity
{
    public Guid AnomalyId { get; set; }
    public RouteComplianceAnomaly Anomaly { get; set; } = null!;
    public RouteAnomalyStatus FromStatus { get; set; }
    public RouteAnomalyStatus ToStatus { get; set; }
    public string? ActorUserId { get; set; }
    public string? Note { get; set; }
    public DateTime OccurredAtUtc { get; set; } = DateTime.UtcNow;
}

public sealed class RiderInAppNotification : Entity
{
    public string RiderUserId { get; set; } = "";
    public Guid? AnomalyId { get; set; }
    public string Title { get; set; } = "";
    public string Body { get; set; } = "";
    public string DeepLink { get; set; } = "route-compliance";
    public string IdempotencyKey { get; set; } = "";
    public bool IsRead { get; set; }
    public DateTime CreatedAtUtc { get; set; } = DateTime.UtcNow;
}
