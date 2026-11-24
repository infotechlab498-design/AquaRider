using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using RouteLedger.Application;
using RouteLedger.Domain;
using RouteLedger.Infrastructure.Data;

namespace RouteLedger.Infrastructure.Services;

public sealed class LiveTrackingService : ILiveTrackingService
{
    private readonly AppDbContext _db;
    private readonly ICurrentUser _current;
    private readonly FleetTrackingOptions _options;

    public LiveTrackingService(AppDbContext db, ICurrentUser current, IOptions<FleetTrackingOptions> options)
    {
        _db = db;
        _current = current;
        _options = options.Value;
    }

    public async Task<ServiceResult<TrackingSessionDto>> StartAsync(CancellationToken cancellationToken)
    {
        if (_current.UserId is null)
        {
            return ServiceResult<TrackingSessionDto>.Fail(401, "Sign in required.");
        }

        var today = ReportingWindow.Today();
        var shift = await _db.Shifts.AsNoTracking()
            .Where(item => item.RiderId == _current.UserId && item.ServiceDate == today && item.Status == "Open")
            .OrderByDescending(item => item.StartedAt)
            .FirstOrDefaultAsync(cancellationToken);
        if (shift is null)
        {
            return ServiceResult<TrackingSessionDto>.Fail(409, "Start an authorized shift before location sharing.");
        }

        var existing = await _db.TrackingSessions
            .FirstOrDefaultAsync(
                item => item.RiderUserId == _current.UserId && item.Status == TrackingSessionStatus.Active,
                cancellationToken);
        if (existing is not null)
        {
            if (existing.ShiftId == shift.Id)
            {
                return ServiceResult<TrackingSessionDto>.Ok(ToSessionDto(existing), "Tracking session already active.");
            }

            existing.Status = TrackingSessionStatus.Ended;
            existing.EndedAtUtc = DateTime.UtcNow;
            existing.EndReason = "ReplacedByNewSession";
        }

        var rider = await _db.Users.AsNoTracking().FirstAsync(user => user.Id == _current.UserId, cancellationToken);
        var session = new TrackingSession
        {
            RiderUserId = _current.UserId,
            ShiftId = shift.Id,
            RouteId = shift.RouteId,
            VehicleId = shift.VehicleId,
            DepotId = rider.DepotId,
            Status = TrackingSessionStatus.Active,
            StartedAtUtc = DateTime.UtcNow
        };
        _db.TrackingSessions.Add(session);
        _db.AuditLogs.Add(new AuditLog
        {
            UserId = _current.UserId,
            Action = "TrackingStart",
            EntityName = nameof(TrackingSession),
            EntityId = session.Id.ToString("N")
        });
        await _db.SaveChangesAsync(cancellationToken);
        return ServiceResult<TrackingSessionDto>.Created(ToSessionDto(session), "Location sharing started.");
    }

    public async Task<ServiceResult<TrackingSessionDto>> StopAsync(TrackingStopRequest request, CancellationToken cancellationToken)
    {
        if (_current.UserId is null)
        {
            return ServiceResult<TrackingSessionDto>.Fail(401, "Sign in required.");
        }

        var session = await _db.TrackingSessions
            .FirstOrDefaultAsync(
                item => item.RiderUserId == _current.UserId && item.Status == TrackingSessionStatus.Active,
                cancellationToken);
        if (session is null)
        {
            return ServiceResult<TrackingSessionDto>.Fail(404, "No active tracking session.");
        }

        session.Status = TrackingSessionStatus.Ended;
        session.EndedAtUtc = DateTime.UtcNow;
        session.EndReason = string.IsNullOrWhiteSpace(request.Reason) ? "StoppedByRider" : request.Reason.Trim();
        _db.AuditLogs.Add(new AuditLog
        {
            UserId = _current.UserId,
            Action = "TrackingStop",
            EntityName = nameof(TrackingSession),
            EntityId = session.Id.ToString("N")
        });
        await _db.SaveChangesAsync(cancellationToken);
        return ServiceResult<TrackingSessionDto>.Ok(ToSessionDto(session), "Location sharing stopped.");
    }

    public async Task<ServiceResult<object>> IngestLocationsAsync(TrackingLocationBatchRequest request, CancellationToken cancellationToken)
    {
        if (_current.UserId is null)
        {
            return ServiceResult<object>.Fail(401, "Sign in required.");
        }

        if (request.Points.Count == 0)
        {
            return ServiceResult<object>.Fail(400, "No location points supplied.");
        }

        var session = await ResolveActiveSessionAsync(request.SessionId, cancellationToken);
        if (session is null)
        {
            return ServiceResult<object>.Fail(409, "No active tracking session for this rider.");
        }

        var accepted = 0;
        var rejected = 0;
        RiderLocationTelemetry? lastAccepted = null;
        var previous = await _db.RiderLocationTelemetries.AsNoTracking()
            .Where(item => item.TrackingSessionId == session.Id && !item.Rejected)
            .OrderByDescending(item => item.DeviceTimestampUtc)
            .FirstOrDefaultAsync(cancellationToken);

        foreach (var point in request.Points.OrderBy(item => item.DeviceTimestampUtc))
        {
            var rejectReason = ValidatePoint(point, previous);
            var row = new RiderLocationTelemetry
            {
                TrackingSessionId = session.Id,
                RiderUserId = _current.UserId,
                Latitude = point.Latitude,
                Longitude = point.Longitude,
                AccuracyMeters = point.AccuracyMeters,
                SpeedMetersPerSecond = point.SpeedMetersPerSecond,
                HeadingDegrees = point.HeadingDegrees,
                DeviceTimestampUtc = DateTime.SpecifyKind(point.DeviceTimestampUtc, DateTimeKind.Utc),
                ServerReceivedAtUtc = DateTime.UtcNow,
                BatteryPercent = point.BatteryPercent,
                NetworkStatus = Truncate(point.NetworkStatus, 40),
                IsStale = false,
                Rejected = rejectReason is not null,
                RejectReason = rejectReason
            };

            if (rejectReason is not null)
            {
                rejected++;
                _db.RiderLocationTelemetries.Add(row);
                continue;
            }

            try
            {
                _db.RiderLocationTelemetries.Add(row);
                await _db.SaveChangesAsync(cancellationToken);
                accepted++;
                previous = row;
                lastAccepted = row;
            }
            catch (DbUpdateException)
            {
                _db.ChangeTracker.Clear();
                session = await ResolveActiveSessionAsync(request.SessionId, cancellationToken)
                    ?? session;
                rejected++;
            }
        }

        if (lastAccepted is not null)
        {
            await EvaluateComplianceAsync(session, lastAccepted, cancellationToken);
            await _db.SaveChangesAsync(cancellationToken);
        }

        return ServiceResult<object>.Ok(
            new { accepted, rejected, sessionId = session.Id },
            accepted > 0 ? "Location batch stored." : "No valid location points accepted.");
    }

    public async Task<ServiceResult<TrackingStatusDto>> StatusAsync(CancellationToken cancellationToken)
    {
        if (_current.UserId is null)
        {
            return ServiceResult<TrackingStatusDto>.Fail(401, "Sign in required.");
        }

        var session = await _db.TrackingSessions.AsNoTracking()
            .Where(item => item.RiderUserId == _current.UserId && item.Status == TrackingSessionStatus.Active)
            .OrderByDescending(item => item.StartedAtUtc)
            .FirstOrDefaultAsync(cancellationToken);
        var last = session is null
            ? null
            : await _db.RiderLocationTelemetries.AsNoTracking()
                .Where(item => item.TrackingSessionId == session.Id && !item.Rejected)
                .OrderByDescending(item => item.DeviceTimestampUtc)
                .FirstOrDefaultAsync(cancellationToken);
        var stale = last is not null
            && (DateTime.UtcNow - last.DeviceTimestampUtc).TotalSeconds > _options.FreshnessSeconds;

        var dto = new TrackingStatusDto(
            session is not null,
            session is null ? null : ToSessionDto(session),
            last?.DeviceTimestampUtc,
            last?.Latitude,
            last?.Longitude,
            last?.AccuracyMeters,
            last?.SpeedMetersPerSecond,
            last?.BatteryPercent,
            last?.NetworkStatus,
            stale,
            session is null ? "Inactive" : stale ? "Active (stale fix)" : "Active");
        return ServiceResult<TrackingStatusDto>.Ok(dto, "Tracking status loaded.");
    }

    public async Task<ServiceResult<ActiveAssignmentDto>> ActiveAssignmentAsync(string? riderUserId, CancellationToken cancellationToken)
    {
        var targetId = string.IsNullOrWhiteSpace(riderUserId) ? _current.UserId : riderUserId.Trim();
        if (targetId is null)
        {
            return ServiceResult<ActiveAssignmentDto>.Fail(401, "Sign in required.");
        }

        if (!string.Equals(targetId, _current.UserId, StringComparison.Ordinal)
            && !_current.IsAdmin)
        {
            return ServiceResult<ActiveAssignmentDto>.Fail(403, "Not allowed to view this assignment.");
        }

        var rider = await _db.Users.AsNoTracking()
            .Include(user => user.Route)
            .Include(user => user.Vehicle)
            .Include(user => user.Depot)
            .FirstOrDefaultAsync(user => user.Id == targetId, cancellationToken);
        if (rider is null)
        {
            return ServiceResult<ActiveAssignmentDto>.Fail(404, "Rider not found.");
        }

        var today = ReportingWindow.Today();
        var shift = await _db.Shifts.AsNoTracking()
            .Where(item => item.RiderId == targetId && item.ServiceDate == today)
            .OrderByDescending(item => item.StartedAt)
            .FirstOrDefaultAsync(cancellationToken);
        var routeId = shift?.RouteId ?? rider.RouteId;
        var stops = routeId is null
            ? []
            : await _db.RouteStops.AsNoTracking()
                .Include(item => item.Customer)
                .Where(item => item.RouteId == routeId && item.ServiceDate == today)
                .OrderBy(item => item.Sequence)
                .ToListAsync(cancellationToken);

        var mapped = stops.Select(ToStopDto).ToList();
        var next = mapped.FirstOrDefault(item =>
            item.Status is nameof(StopStatus.Pending) or nameof(StopStatus.InProgress));
        var dto = new ActiveAssignmentDto(
            rider.Id,
            rider.RiderCode ?? "",
            rider.FullName,
            rider.Depot?.Name,
            rider.Vehicle?.Name,
            rider.Vehicle?.Plate,
            rider.Vehicle?.FleetCode,
            routeId,
            rider.Route?.Name,
            shift?.Id,
            shift?.Status,
            next,
            mapped,
            mapped.Count(item => item.Status == nameof(StopStatus.Completed)),
            mapped.Count(item => item.Status is nameof(StopStatus.Pending) or nameof(StopStatus.InProgress)),
            mapped.Count);
        return ServiceResult<ActiveAssignmentDto>.Ok(dto, "Active assignment loaded.");
    }

    public async Task<ServiceResult<RouteComplianceStateDto>> CurrentComplianceAsync(CancellationToken cancellationToken)
    {
        if (_current.UserId is null)
        {
            return ServiceResult<RouteComplianceStateDto>.Fail(401, "Sign in required.");
        }

        var open = await _db.RouteComplianceAnomalies.AsNoTracking()
            .Where(item => item.RiderUserId == _current.UserId
                && item.Status != RouteAnomalyStatus.Resolved
                && item.Status != RouteAnomalyStatus.Cancelled
                && item.Status != RouteAnomalyStatus.FalsePositive
                && item.Status != RouteAnomalyStatus.Approved)
            .OrderByDescending(item => item.DetectedAtUtc)
            .FirstOrDefaultAsync(cancellationToken);

        if (open is null)
        {
            return ServiceResult<RouteComplianceStateDto>.Ok(
                new RouteComplianceStateDto("OnRoute", "No open route anomalies.", null, null, null, DateTime.UtcNow),
                "Compliance state loaded.");
        }

        var state = open.Status switch
        {
            RouteAnomalyStatus.ExplanationSubmitted or RouteAnomalyStatus.UnderAdminReview => "ExplanationSubmitted",
            RouteAnomalyStatus.AwaitingRiderResponse or RouteAnomalyStatus.AwaitingResponseOverdue
                or RouteAnomalyStatus.NotificationSent or RouteAnomalyStatus.Detected
                or RouteAnomalyStatus.Rejected or RouteAnomalyStatus.Reopened => "ExplanationRequired",
            _ => "RouteDeviationDetected"
        };
        return ServiceResult<RouteComplianceStateDto>.Ok(
            new RouteComplianceStateDto(
                state,
                $"{open.Category} · {open.Status}",
                open.Id,
                open.AnomalyNumber,
                open.Category.ToString(),
                open.DetectedAtUtc),
            "Compliance state loaded.");
    }

    public async Task<ServiceResult<IReadOnlyList<RouteAnomalyDto>>> RiderAnomaliesAsync(CancellationToken cancellationToken)
    {
        if (_current.UserId is null)
        {
            return ServiceResult<IReadOnlyList<RouteAnomalyDto>>.Fail(401, "Sign in required.");
        }

        var rows = await LoadAnomaliesQuery()
            .Where(item => item.RiderUserId == _current.UserId)
            .OrderByDescending(item => item.DetectedAtUtc)
            .Take(50)
            .ToListAsync(cancellationToken);
        return ServiceResult<IReadOnlyList<RouteAnomalyDto>>.Ok(await MapAnomaliesAsync(rows, cancellationToken), "Anomalies loaded.");
    }

    public async Task<ServiceResult<RouteAnomalyDto>> SubmitExplanationAsync(
        Guid anomalyId,
        AnomalyExplanationRequest request,
        CancellationToken cancellationToken)
    {
        if (_current.UserId is null)
        {
            return ServiceResult<RouteAnomalyDto>.Fail(401, "Sign in required.");
        }

        var anomaly = await _db.RouteComplianceAnomalies
            .Include(item => item.Explanations)
            .FirstOrDefaultAsync(item => item.Id == anomalyId, cancellationToken);
        if (anomaly is null || anomaly.RiderUserId != _current.UserId)
        {
            return ServiceResult<RouteAnomalyDto>.Fail(404, "Anomaly not found.");
        }

        if (request.Reason == AnomalyExplanationReason.Other && string.IsNullOrWhiteSpace(request.ExplanationText))
        {
            return ServiceResult<RouteAnomalyDto>.Fail(400, "Explanation text is required for Other.");
        }

        if (string.IsNullOrWhiteSpace(request.ExplanationText) && request.Reason == AnomalyExplanationReason.Other)
        {
            return ServiceResult<RouteAnomalyDto>.Fail(400, "Explanation text is required.");
        }

        var text = (request.ExplanationText ?? "").Trim();
        if (text.Length == 0)
        {
            text = request.Reason.ToString();
        }

        var hasPrimary = anomaly.Explanations.Any(item => !item.IsCorrection);
        if (hasPrimary && !request.IsCorrection)
        {
            return ServiceResult<RouteAnomalyDto>.Fail(
                409,
                "Explanation already submitted. Send a correction comment instead.");
        }

        anomaly.Explanations.Add(new RiderAnomalyExplanation
        {
            RiderUserId = _current.UserId,
            Reason = request.Reason,
            ExplanationText = Truncate(text, 1000)!,
            SupportingNote = Truncate(request.SupportingNote, 1000),
            IsCorrection = request.IsCorrection || hasPrimary,
            SubmittedAtUtc = DateTime.UtcNow
        });
        Transition(anomaly, RouteAnomalyStatus.ExplanationSubmitted, _current.UserId, "Rider explanation submitted");
        await NotifyRiderAsync(
            anomaly.RiderUserId,
            anomaly.Id,
            "Explanation received",
            $"Your explanation for {anomaly.AnomalyNumber} was recorded.",
            $"explain-ack:{anomaly.Id:N}",
            cancellationToken);
        await _db.SaveChangesAsync(cancellationToken);
        return ServiceResult<RouteAnomalyDto>.Ok(
            (await MapAnomaliesAsync([anomaly], cancellationToken)).Single(),
            "Explanation submitted.");
    }

    public async Task<ServiceResult<IReadOnlyList<RiderNotificationDto>>> RiderNotificationsAsync(CancellationToken cancellationToken)
    {
        if (_current.UserId is null)
        {
            return ServiceResult<IReadOnlyList<RiderNotificationDto>>.Fail(401, "Sign in required.");
        }

        var rows = await _db.RiderInAppNotifications.AsNoTracking()
            .Where(item => item.RiderUserId == _current.UserId)
            .OrderByDescending(item => item.CreatedAtUtc)
            .Take(50)
            .ToListAsync(cancellationToken);
        var dto = rows.Select(item => new RiderNotificationDto(
            item.Id, item.Title, item.Body, item.DeepLink, item.AnomalyId, item.IsRead, item.CreatedAtUtc)).ToList();
        return ServiceResult<IReadOnlyList<RiderNotificationDto>>.Ok(dto, "Notifications loaded.");
    }

    public async Task<ServiceResult<object>> MarkNotificationReadAsync(Guid id, CancellationToken cancellationToken)
    {
        if (_current.UserId is null)
        {
            return ServiceResult<object>.Fail(401, "Sign in required.");
        }

        var row = await _db.RiderInAppNotifications
            .FirstOrDefaultAsync(item => item.Id == id && item.RiderUserId == _current.UserId, cancellationToken);
        if (row is null)
        {
            return ServiceResult<object>.Fail(404, "Notification not found.");
        }

        row.IsRead = true;
        await _db.SaveChangesAsync(cancellationToken);
        return ServiceResult<object>.Ok(new { row.Id }, "Notification marked read.");
    }

    public async Task<ServiceResult<LiveTrackingOverviewDto>> OverviewAsync(CancellationToken cancellationToken)
    {
        if (!_current.IsAdmin)
        {
            return ServiceResult<LiveTrackingOverviewDto>.Fail(403, "Admin role required.");
        }

        var riders = await BuildLiveCardsAsync(cancellationToken);
        var fleetTotal = await _db.Users.AsNoTracking()
            .CountAsync(user => user.RiderCode != null && user.IsActive, cancellationToken);
        var moving = riders.Count(item => item.MotionState == "Moving");
        var delivering = riders.Count(item => item.MotionState == "Delivering");
        var idle = riders.Count(item => item.MotionState == "Idle");
        var stale = riders.Count(item => item.LastFixStale || item.MotionState == "Offline");
        var speeds = riders.Where(item => item.SpeedKmh is not null).Select(item => item.SpeedKmh!.Value).ToList();
        var batteries = riders.Where(item => item.BatteryPercent is not null).Select(item => (double)item.BatteryPercent!.Value).ToList();
        var openAnomalies = await _db.RouteComplianceAnomalies.AsNoTracking()
            .CountAsync(item => item.Status != RouteAnomalyStatus.Resolved
                && item.Status != RouteAnomalyStatus.Cancelled
                && item.Status != RouteAnomalyStatus.FalsePositive
                && item.Status != RouteAnomalyStatus.Approved, cancellationToken);

        var dto = new LiveTrackingOverviewDto(
            riders.Count,
            fleetTotal,
            moving,
            speeds.Count == 0 ? null : Math.Round(speeds.Average(), 1),
            delivering,
            idle,
            stale,
            riders.Count(item => item.TrackingActive && !item.LastFixStale),
            batteries.Count == 0 ? null : Math.Round(batteries.Average(), 0),
            openAnomalies);
        return ServiceResult<LiveTrackingOverviewDto>.Ok(dto, "Live tracking overview loaded.");
    }

    public async Task<ServiceResult<IReadOnlyList<LiveRiderCardDto>>> LiveRidersAsync(CancellationToken cancellationToken)
    {
        if (!_current.IsAdmin)
        {
            return ServiceResult<IReadOnlyList<LiveRiderCardDto>>.Fail(403, "Admin role required.");
        }

        var cards = await BuildLiveCardsAsync(cancellationToken);
        return ServiceResult<IReadOnlyList<LiveRiderCardDto>>.Ok(cards, "Live riders loaded.");
    }

    public async Task<ServiceResult<LiveRiderDetailDto>> LiveRiderAsync(string riderUserId, CancellationToken cancellationToken)
    {
        if (!_current.IsAdmin)
        {
            return ServiceResult<LiveRiderDetailDto>.Fail(403, "Admin role required.");
        }

        var cards = await BuildLiveCardsAsync(cancellationToken);
        var card = cards.FirstOrDefault(item => item.RiderUserId == riderUserId);
        if (card is null)
        {
            return ServiceResult<LiveRiderDetailDto>.Fail(404, "Rider not on live trackboard.");
        }

        var sessionId = card.SessionId;
        var trail = sessionId is null
            ? []
            : await _db.RiderLocationTelemetries.AsNoTracking()
                .Where(item => item.TrackingSessionId == sessionId && !item.Rejected)
                .OrderByDescending(item => item.DeviceTimestampUtc)
                .Take(120)
                .Select(item => new LiveRiderTelemetryPointDto(
                    item.Latitude,
                    item.Longitude,
                    item.DeviceTimestampUtc,
                    item.SpeedMetersPerSecond,
                    item.HeadingDegrees))
                .ToListAsync(cancellationToken);
        trail = trail.AsEnumerable().Reverse().ToList();

        var assignment = await ActiveAssignmentAsync(riderUserId, cancellationToken);
        var anomalies = await LoadAnomaliesQuery()
            .Where(item => item.RiderUserId == riderUserId)
            .OrderByDescending(item => item.DetectedAtUtc)
            .Take(10)
            .ToListAsync(cancellationToken);

        var dto = new LiveRiderDetailDto(
            card,
            trail,
            assignment.Data?.Stops ?? [],
            await MapAnomaliesAsync(anomalies, cancellationToken));
        return ServiceResult<LiveRiderDetailDto>.Ok(dto, "Live rider detail loaded.");
    }

    public async Task<ServiceResult<IReadOnlyList<RouteAnomalyDto>>> AdminAnomaliesAsync(
        string? status,
        string? riderUserId,
        CancellationToken cancellationToken)
    {
        if (!_current.IsAdmin)
        {
            return ServiceResult<IReadOnlyList<RouteAnomalyDto>>.Fail(403, "Admin role required.");
        }

        var query = LoadAnomaliesQuery();
        if (!string.IsNullOrWhiteSpace(riderUserId))
        {
            query = query.Where(item => item.RiderUserId == riderUserId);
        }

        if (!string.IsNullOrWhiteSpace(status)
            && Enum.TryParse<RouteAnomalyStatus>(status, true, out var parsed))
        {
            query = query.Where(item => item.Status == parsed);
        }

        var rows = await query.OrderByDescending(item => item.DetectedAtUtc).Take(100).ToListAsync(cancellationToken);
        return ServiceResult<IReadOnlyList<RouteAnomalyDto>>.Ok(await MapAnomaliesAsync(rows, cancellationToken), "Anomalies loaded.");
    }

    public async Task<ServiceResult<RouteAnomalyDto>> AdminAnomalyAsync(Guid id, CancellationToken cancellationToken)
    {
        if (!_current.IsAdmin)
        {
            return ServiceResult<RouteAnomalyDto>.Fail(403, "Admin role required.");
        }

        var row = await LoadAnomaliesQuery().FirstOrDefaultAsync(item => item.Id == id, cancellationToken);
        if (row is null)
        {
            return ServiceResult<RouteAnomalyDto>.Fail(404, "Anomaly not found.");
        }

        return ServiceResult<RouteAnomalyDto>.Ok((await MapAnomaliesAsync([row], cancellationToken)).Single(), "Anomaly loaded.");
    }

    public async Task<ServiceResult<RouteAnomalyDto>> ReviewAsync(
        Guid id,
        AnomalyReviewRequest request,
        CancellationToken cancellationToken)
    {
        if (!_current.IsAdmin)
        {
            return ServiceResult<RouteAnomalyDto>.Fail(403, "Admin role required.");
        }

        var anomaly = await _db.RouteComplianceAnomalies
            .Include(item => item.StatusHistory)
            .Include(item => item.Reviews)
            .FirstOrDefaultAsync(item => item.Id == id, cancellationToken);
        if (anomaly is null)
        {
            return ServiceResult<RouteAnomalyDto>.Fail(404, "Anomaly not found.");
        }

        var action = (request.Action ?? "").Trim().ToLowerInvariant();
        if (action is not ("approve" or "reject" or "review"))
        {
            return ServiceResult<RouteAnomalyDto>.Fail(400, "Action must be approve, reject, or review.");
        }

        anomaly.Reviews.Add(new RouteComplianceReview
        {
            AdminUserId = _current.UserId!,
            Action = action,
            Notes = Truncate(request.Notes, 1000),
            OccurredAtUtc = DateTime.UtcNow
        });

        var next = action switch
        {
            "approve" => RouteAnomalyStatus.Approved,
            "reject" => RouteAnomalyStatus.Rejected,
            _ => RouteAnomalyStatus.UnderAdminReview
        };
        Transition(anomaly, next, _current.UserId, request.Notes);
        _db.AuditLogs.Add(new AuditLog
        {
            UserId = _current.UserId!,
            Action = $"Anomaly{char.ToUpper(action[0])}{action[1..]}",
            EntityName = nameof(RouteComplianceAnomaly),
            EntityId = anomaly.Id.ToString("N")
        });
        await NotifyRiderAsync(
            anomaly.RiderUserId,
            anomaly.Id,
            $"Anomaly {action}",
            $"HQ {action}d {anomaly.AnomalyNumber}.",
            $"review:{anomaly.Id:N}:{action}",
            cancellationToken);
        await _db.SaveChangesAsync(cancellationToken);
        return await AdminAnomalyAsync(id, cancellationToken);
    }

    public async Task<ServiceResult<RouteAnomalyDto>> QueryRiderAsync(
        Guid id,
        AnomalyQueryRequest request,
        CancellationToken cancellationToken)
    {
        if (!_current.IsAdmin)
        {
            return ServiceResult<RouteAnomalyDto>.Fail(403, "Admin role required.");
        }

        if (string.IsNullOrWhiteSpace(request.Message))
        {
            return ServiceResult<RouteAnomalyDto>.Fail(400, "Query message is required.");
        }

        var anomaly = await _db.RouteComplianceAnomalies
            .Include(item => item.StatusHistory)
            .Include(item => item.Reviews)
            .FirstOrDefaultAsync(item => item.Id == id, cancellationToken);
        if (anomaly is null)
        {
            return ServiceResult<RouteAnomalyDto>.Fail(404, "Anomaly not found.");
        }

        anomaly.Reviews.Add(new RouteComplianceReview
        {
            AdminUserId = _current.UserId!,
            Action = "query",
            Notes = Truncate(request.Message, 1000),
            OccurredAtUtc = DateTime.UtcNow
        });
        Transition(anomaly, RouteAnomalyStatus.AwaitingRiderResponse, _current.UserId, request.Message);
        anomaly.ResponseDueAtUtc = DateTime.UtcNow.AddHours(_options.ExplanationResponseHours);
        await NotifyRiderAsync(
            anomaly.RiderUserId,
            anomaly.Id,
            "HQ needs clarification",
            Truncate(request.Message, 500)!,
            $"query:{anomaly.Id:N}:{DateTime.UtcNow.Ticks}",
            cancellationToken);
        _db.AuditLogs.Add(new AuditLog
        {
            UserId = _current.UserId!,
            Action = "AnomalyQuery",
            EntityName = nameof(RouteComplianceAnomaly),
            EntityId = anomaly.Id.ToString("N")
        });
        await _db.SaveChangesAsync(cancellationToken);
        return await AdminAnomalyAsync(id, cancellationToken);
    }

    public async Task<ServiceResult<RouteAnomalyDto>> ResolveAsync(
        Guid id,
        AnomalyResolveRequest request,
        CancellationToken cancellationToken)
    {
        if (!_current.IsAdmin)
        {
            return ServiceResult<RouteAnomalyDto>.Fail(403, "Admin role required.");
        }

        var anomaly = await _db.RouteComplianceAnomalies
            .Include(item => item.StatusHistory)
            .Include(item => item.Reviews)
            .FirstOrDefaultAsync(item => item.Id == id, cancellationToken);
        if (anomaly is null)
        {
            return ServiceResult<RouteAnomalyDto>.Fail(404, "Anomaly not found.");
        }

        var next = request.MarkFalsePositive ? RouteAnomalyStatus.FalsePositive : RouteAnomalyStatus.Resolved;
        anomaly.ResolutionNotes = Truncate(request.Notes, 1000);
        anomaly.ResolvedAtUtc = DateTime.UtcNow;
        anomaly.Reviews.Add(new RouteComplianceReview
        {
            AdminUserId = _current.UserId!,
            Action = request.MarkFalsePositive ? "falsePositive" : "resolve",
            Notes = Truncate(request.Notes, 1000),
            OccurredAtUtc = DateTime.UtcNow
        });
        Transition(anomaly, next, _current.UserId, request.Notes);
        _db.AuditLogs.Add(new AuditLog
        {
            UserId = _current.UserId!,
            Action = "AnomalyResolve",
            EntityName = nameof(RouteComplianceAnomaly),
            EntityId = anomaly.Id.ToString("N")
        });
        await NotifyRiderAsync(
            anomaly.RiderUserId,
            anomaly.Id,
            "Anomaly closed",
            $"{anomaly.AnomalyNumber} was closed by HQ.",
            $"resolve:{anomaly.Id:N}",
            cancellationToken);
        await _db.SaveChangesAsync(cancellationToken);
        return await AdminAnomalyAsync(id, cancellationToken);
    }

    private async Task EvaluateComplianceAsync(
        TrackingSession session,
        RiderLocationTelemetry latest,
        CancellationToken cancellationToken)
    {
        var recent = await _db.RiderLocationTelemetries.AsNoTracking()
            .Where(item => item.TrackingSessionId == session.Id && !item.Rejected)
            .OrderByDescending(item => item.DeviceTimestampUtc)
            .Take(Math.Max(5, _options.ConsecutiveFixesRequired + 2))
            .ToListAsync(cancellationToken);
        recent.Reverse();
        if (recent.Count < _options.ConsecutiveFixesRequired)
        {
            return;
        }

        var accurate = recent
            .Where(item => item.AccuracyMeters is null || item.AccuracyMeters <= _options.MaxAccuracyMeters)
            .TakeLast(_options.ConsecutiveFixesRequired)
            .ToList();
        if (accurate.Count < _options.ConsecutiveFixesRequired)
        {
            await RaiseAnomalyAsync(
                session,
                latest,
                RouteAnomalyCategory.GpsInaccurate,
                RouteAnomalySeverity.Info,
                null,
                null,
                null,
                new { reason = "Accuracy below threshold across consecutive fixes" },
                cancellationToken);
            return;
        }

        var today = ReportingWindow.Today();
        var stops = session.RouteId is null
            ? []
            : await _db.RouteStops.AsNoTracking()
                .Include(item => item.Customer)
                .Where(item => item.RouteId == session.RouteId && item.ServiceDate == today)
                .OrderBy(item => item.Sequence)
                .ToListAsync(cancellationToken);

        var pending = stops.Where(item => item.Status is StopStatus.Pending or StopStatus.InProgress).ToList();
        var next = pending.FirstOrDefault();
        var corridorPoints = stops
            .Where(item => item.Customer.Latitude is not null && item.Customer.Longitude is not null)
            .Select(item => ((double)item.Customer.Latitude!, (double)item.Customer.Longitude!))
            .ToList();

        if (corridorPoints.Count >= 1)
        {
            var distance = GeoMath.DistanceToPolylineMeters(latest.Latitude, latest.Longitude, corridorPoints);
            if (distance > _options.CorridorMeters)
            {
                var outsideCount = accurate.Count(item =>
                    GeoMath.DistanceToPolylineMeters(item.Latitude, item.Longitude, corridorPoints) > _options.CorridorMeters);
                if (outsideCount >= _options.ConsecutiveFixesRequired)
                {
                    await RaiseAnomalyAsync(
                        session,
                        latest,
                        RouteAnomalyCategory.RouteDeviation,
                        RouteAnomalySeverity.Warning,
                        next,
                        latest.HeadingDegrees,
                        null,
                        new { corridorMeters = _options.CorridorMeters, distanceMeters = Math.Round(distance, 1) },
                        cancellationToken);
                }
            }
        }

        if (next?.Customer.Latitude is not null && next.Customer.Longitude is not null && accurate.Count >= 2)
        {
            var expected = GeoMath.BearingDegrees(
                accurate[^2].Latitude,
                accurate[^2].Longitude,
                (double)next.Customer.Latitude!,
                (double)next.Customer.Longitude!);
            var actual = latest.HeadingDegrees
                ?? GeoMath.BearingDegrees(
                    accurate[^2].Latitude,
                    accurate[^2].Longitude,
                    accurate[^1].Latitude,
                    accurate[^1].Longitude);
            var delta = GeoMath.HeadingDeltaDegrees(actual, expected);
            var movingAway = accurate
                .Skip(1)
                .Select((fix, index) =>
                {
                    var prev = accurate[index];
                    var before = GeoMath.DistanceMeters(
                        prev.Latitude, prev.Longitude, (double)next.Customer.Latitude!, (double)next.Customer.Longitude!);
                    var after = GeoMath.DistanceMeters(
                        fix.Latitude, fix.Longitude, (double)next.Customer.Latitude!, (double)next.Customer.Longitude!);
                    return after > before + 25;
                })
                .Count(away => away);
            if (delta > 120 && movingAway >= _options.ConsecutiveFixesRequired - 1)
            {
                await RaiseAnomalyAsync(
                    session,
                    latest,
                    RouteAnomalyCategory.WrongDirection,
                    RouteAnomalySeverity.Warning,
                    next,
                    actual,
                    expected,
                    new { headingDelta = Math.Round(delta, 1), movingAway },
                    cancellationToken);
            }
        }

        if (accurate.Count >= 2)
        {
            var first = accurate[0];
            var moved = accurate.Skip(1).Sum(item =>
            {
                var idx = accurate.IndexOf(item);
                var prev = accurate[idx - 1];
                return GeoMath.DistanceMeters(prev.Latitude, prev.Longitude, item.Latitude, item.Longitude);
            });
            var spanMinutes = (accurate[^1].DeviceTimestampUtc - first.DeviceTimestampUtc).TotalMinutes;
            var nearCustomer = pending.Any(stop =>
                stop.Customer.Latitude is not null
                && stop.Customer.Longitude is not null
                && GeoMath.DistanceMeters(
                    latest.Latitude,
                    latest.Longitude,
                    (double)stop.Customer.Latitude!,
                    (double)stop.Customer.Longitude!) <= 60);
            if (spanMinutes >= _options.StationaryMinutes && moved < 40 && !nearCustomer)
            {
                await RaiseAnomalyAsync(
                    session,
                    latest,
                    RouteAnomalyCategory.UnexpectedLongStop,
                    RouteAnomalySeverity.Warning,
                    next,
                    latest.HeadingDegrees,
                    null,
                    new { spanMinutes = Math.Round(spanMinutes, 1), movedMeters = Math.Round(moved, 1) },
                    cancellationToken);
            }
        }

        if (pending.Count >= 2 && latest is not null)
        {
            var second = pending[1];
            if (second.Customer.Latitude is not null
                && second.Customer.Longitude is not null
                && next?.Customer.Latitude is not null
                && next.Customer.Longitude is not null)
            {
                var toNext = GeoMath.DistanceMeters(
                    latest.Latitude, latest.Longitude, (double)next.Customer.Latitude!, (double)next.Customer.Longitude!);
                var toSecond = GeoMath.DistanceMeters(
                    latest.Latitude, latest.Longitude, (double)second.Customer.Latitude!, (double)second.Customer.Longitude!);
                if (toSecond + 80 < toNext && toSecond < 80)
                {
                    await RaiseAnomalyAsync(
                        session,
                        latest,
                        RouteAnomalyCategory.CustomerStopSkipped,
                        RouteAnomalySeverity.Critical,
                        next,
                        latest.HeadingDegrees,
                        null,
                        new { skippedStopId = next.Id, approachedStopId = second.Id },
                        cancellationToken);
                }
            }
        }
    }

    private async Task RaiseAnomalyAsync(
        TrackingSession session,
        RiderLocationTelemetry latest,
        RouteAnomalyCategory category,
        RouteAnomalySeverity severity,
        RouteStop? next,
        double? actualHeading,
        double? expectedHeading,
        object evidence,
        CancellationToken cancellationToken)
    {
        var openSame = await _db.RouteComplianceAnomalies.AnyAsync(
            item => item.TrackingSessionId == session.Id
                && item.Category == category
                && item.Status != RouteAnomalyStatus.Resolved
                && item.Status != RouteAnomalyStatus.Cancelled
                && item.Status != RouteAnomalyStatus.FalsePositive
                && item.Status != RouteAnomalyStatus.Approved
                && item.DetectedAtUtc >= DateTime.UtcNow.AddHours(-2),
            cancellationToken);
        if (openSame)
        {
            return;
        }

        var number = await NextAnomalyNumberAsync(cancellationToken);
        var anomaly = new RouteComplianceAnomaly
        {
            AnomalyNumber = number,
            RiderUserId = session.RiderUserId,
            TrackingSessionId = session.Id,
            ShiftId = session.ShiftId,
            RouteId = session.RouteId,
            Category = category,
            Severity = severity,
            Status = RouteAnomalyStatus.Detected,
            DetectedAtUtc = DateTime.UtcNow,
            LastLatitude = latest.Latitude,
            LastLongitude = latest.Longitude,
            ExpectedWaypoint = next?.Customer.BusinessName,
            ExpectedStopId = next?.Id,
            ActualHeadingDegrees = actualHeading,
            ExpectedHeadingDegrees = expectedHeading,
            EvidenceJson = JsonSerializer.Serialize(evidence),
            ResponseDueAtUtc = DateTime.UtcNow.AddHours(_options.ExplanationResponseHours)
        };
        Transition(anomaly, RouteAnomalyStatus.NotificationSent, null, "Auto notification");
        Transition(anomaly, RouteAnomalyStatus.AwaitingRiderResponse, null, "Awaiting rider explanation");
        _db.RouteComplianceAnomalies.Add(anomaly);
        await NotifyRiderAsync(
            session.RiderUserId,
            anomaly.Id,
            "Route compliance alert",
            $"{category} detected near {next?.Customer.BusinessName ?? "your route"}. Please explain.",
            $"anomaly:{anomaly.Id:N}:{category}",
            cancellationToken);
    }

    private async Task NotifyRiderAsync(
        string riderUserId,
        Guid? anomalyId,
        string title,
        string body,
        string idempotencyKey,
        CancellationToken cancellationToken)
    {
        var exists = await _db.RiderInAppNotifications.AnyAsync(
            item => item.IdempotencyKey == idempotencyKey,
            cancellationToken);
        if (exists)
        {
            return;
        }

        _db.RiderInAppNotifications.Add(new RiderInAppNotification
        {
            RiderUserId = riderUserId,
            AnomalyId = anomalyId,
            Title = Truncate(title, 160)!,
            Body = Truncate(body, 500)!,
            DeepLink = "route-compliance",
            IdempotencyKey = Truncate(idempotencyKey, 120)!
        });
    }

    private async Task<string> NextAnomalyNumberAsync(CancellationToken cancellationToken)
    {
        var day = DateTime.UtcNow.ToString("yyyyMMdd");
        var prefix = $"RCA-{day}-";
        var latest = await _db.RouteComplianceAnomalies.AsNoTracking()
            .Where(item => item.AnomalyNumber.StartsWith(prefix))
            .OrderByDescending(item => item.AnomalyNumber)
            .Select(item => item.AnomalyNumber)
            .FirstOrDefaultAsync(cancellationToken);
        var next = 1;
        if (latest is not null && int.TryParse(latest[(prefix.Length)..], out var parsed))
        {
            next = parsed + 1;
        }

        return $"{prefix}{next:D4}";
    }

    private async Task<List<LiveRiderCardDto>> BuildLiveCardsAsync(CancellationToken cancellationToken)
    {
        var today = ReportingWindow.Today();
        var (start, end) = ReportingWindow.UtcBounds(today, today);
        var sessions = await _db.TrackingSessions.AsNoTracking()
            .Where(item => item.Status == TrackingSessionStatus.Active)
            .ToListAsync(cancellationToken);
        if (sessions.Count == 0)
        {
            return [];
        }

        var riderIds = sessions.Select(item => item.RiderUserId).Distinct().ToList();
        var riders = await _db.Users.AsNoTracking()
            .Include(user => user.Route)
            .Include(user => user.Vehicle)
            .Where(user => riderIds.Contains(user.Id))
            .ToDictionaryAsync(user => user.Id, cancellationToken);
        var sessionIds = sessions.Select(item => item.Id).ToList();
        var telemetry = await _db.RiderLocationTelemetries.AsNoTracking()
            .Where(item => sessionIds.Contains(item.TrackingSessionId) && !item.Rejected)
            .Select(item => new
            {
                item.TrackingSessionId,
                item.Latitude,
                item.Longitude,
                item.DeviceTimestampUtc,
                item.SpeedMetersPerSecond,
                item.AccuracyMeters,
                item.BatteryPercent,
                item.NetworkStatus
            })
            .ToListAsync(cancellationToken);
        var fixBySession = telemetry
            .GroupBy(item => item.TrackingSessionId)
            .ToDictionary(
                group => group.Key,
                group => group.OrderByDescending(item => item.DeviceTimestampUtc).First());

        var stops = await _db.RouteStops.AsNoTracking()
            .Include(item => item.Customer)
            .Where(item => item.ServiceDate == today)
            .ToListAsync(cancellationToken);
        var sales = await _db.Sales.AsNoTracking()
            .Where(item => riderIds.Contains(item.RiderId)
                && item.Status == SaleStatus.Completed
                && item.CreatedAt >= start
                && item.CreatedAt < end)
            .GroupBy(item => item.RiderId)
            .Select(group => new
            {
                RiderId = group.Key,
                Sales = group.Sum(item => item.SaleAmount),
                Cash = group.Sum(item => item.AmountReceived),
                Empties = group.Sum(item => item.EmptyBottlesReturned)
            })
            .ToListAsync(cancellationToken);
        var salesMap = sales.ToDictionary(item => item.RiderId);
        var anomalyCounts = await _db.RouteComplianceAnomalies.AsNoTracking()
            .Where(item => riderIds.Contains(item.RiderUserId)
                && item.Status != RouteAnomalyStatus.Resolved
                && item.Status != RouteAnomalyStatus.Cancelled
                && item.Status != RouteAnomalyStatus.FalsePositive
                && item.Status != RouteAnomalyStatus.Approved)
            .GroupBy(item => item.RiderUserId)
            .Select(group => new
            {
                RiderId = group.Key,
                Open = group.Count(),
                PendingExplain = group.Count(item =>
                    item.Status == RouteAnomalyStatus.AwaitingRiderResponse
                    || item.Status == RouteAnomalyStatus.AwaitingResponseOverdue
                    || item.Status == RouteAnomalyStatus.NotificationSent
                    || item.Status == RouteAnomalyStatus.Detected
                    || item.Status == RouteAnomalyStatus.Rejected)
            })
            .ToListAsync(cancellationToken);
        var anomalyMap = anomalyCounts.ToDictionary(item => item.RiderId);

        var cards = new List<LiveRiderCardDto>();
        foreach (var session in sessions)
        {
            if (!riders.TryGetValue(session.RiderUserId, out var rider))
            {
                continue;
            }

            fixBySession.TryGetValue(session.Id, out var fix);
            salesMap.TryGetValue(session.RiderUserId, out var saleRow);
            anomalyMap.TryGetValue(session.RiderUserId, out var anomalyRow);
            var routeStops = stops.Where(item => item.RouteId == session.RouteId).OrderBy(item => item.Sequence).ToList();
            var next = routeStops.FirstOrDefault(item => item.Status is StopStatus.Pending or StopStatus.InProgress);
            var stale = fix is null
                || (DateTime.UtcNow - fix.DeviceTimestampUtc).TotalSeconds > _options.FreshnessSeconds;
            var speedKmh = fix?.SpeedMetersPerSecond is null ? null : fix.SpeedMetersPerSecond * 3.6;
            var motion = ResolveMotion(
                fix?.Latitude,
                fix?.Longitude,
                fix?.SpeedMetersPerSecond,
                stale,
                next);
            cards.Add(new LiveRiderCardDto(
                rider.Id,
                rider.FullName,
                rider.RiderCode,
                rider.Vehicle?.Name,
                rider.Vehicle?.Plate,
                rider.Vehicle?.FleetCode,
                rider.Route?.Name,
                session.RouteId,
                session.Id,
                true,
                motion,
                fix?.Latitude,
                fix?.Longitude,
                fix?.DeviceTimestampUtc,
                stale,
                speedKmh is null ? null : Math.Round(speedKmh.Value, 1),
                fix?.AccuracyMeters,
                fix?.BatteryPercent,
                fix?.NetworkStatus,
                next?.Customer.BusinessName,
                routeStops.Count(item => item.Status == StopStatus.Completed),
                routeStops.Count,
                saleRow?.Sales ?? 0,
                saleRow?.Cash ?? 0,
                saleRow?.Empties ?? 0,
                anomalyRow?.Open ?? 0,
                anomalyRow?.PendingExplain ?? 0));
        }

        return cards.OrderBy(item => item.FullName).ToList();
    }

    private string ResolveMotion(
        double? lat,
        double? lon,
        double? speedMps,
        bool stale,
        RouteStop? next)
    {
        if (lat is null || lon is null || stale)
        {
            return "Offline";
        }

        if (next?.Customer.Latitude is not null
            && next.Customer.Longitude is not null
            && GeoMath.DistanceMeters(
                lat.Value,
                lon.Value,
                (double)next.Customer.Latitude!,
                (double)next.Customer.Longitude!) <= 60)
        {
            return "Delivering";
        }

        if ((speedMps ?? 0) >= _options.MovingSpeedMps)
        {
            return "Moving";
        }

        return "Idle";
    }

    private IQueryable<RouteComplianceAnomaly> LoadAnomaliesQuery() =>
        _db.RouteComplianceAnomalies
            .AsNoTracking()
            .Include(item => item.Explanations)
            .Include(item => item.Reviews)
            .Include(item => item.StatusHistory);

    private async Task<IReadOnlyList<RouteAnomalyDto>> MapAnomaliesAsync(
        List<RouteComplianceAnomaly> rows,
        CancellationToken cancellationToken)
    {
        var riderIds = rows.Select(item => item.RiderUserId).Distinct().ToList();
        var riders = await _db.Users.AsNoTracking()
            .Where(user => riderIds.Contains(user.Id))
            .ToDictionaryAsync(user => user.Id, cancellationToken);
        var routeIds = rows.Where(item => item.RouteId is not null).Select(item => item.RouteId!.Value).Distinct().ToList();
        var routes = await _db.DeliveryRoutes.AsNoTracking()
            .Where(item => routeIds.Contains(item.Id))
            .ToDictionaryAsync(item => item.Id, cancellationToken);

        return rows.Select(item =>
        {
            riders.TryGetValue(item.RiderUserId, out var rider);
            string? routeName = null;
            if (item.RouteId is not null && routes.TryGetValue(item.RouteId.Value, out var route))
            {
                routeName = route.Name;
            }

            return new RouteAnomalyDto(
                item.Id,
                item.AnomalyNumber,
                item.RiderUserId,
                rider?.FullName ?? item.RiderUserId,
                rider?.RiderCode,
                item.TrackingSessionId,
                item.RouteId,
                routeName,
                item.Category.ToString(),
                item.Severity.ToString(),
                item.Status.ToString(),
                item.DetectedAtUtc,
                item.LastLatitude,
                item.LastLongitude,
                item.ExpectedWaypoint,
                item.ActualHeadingDegrees,
                item.ExpectedHeadingDegrees,
                item.EvidenceJson,
                item.ResponseDueAtUtc,
                item.ResolvedAtUtc,
                item.ResolutionNotes,
                item.Explanations.OrderBy(e => e.SubmittedAtUtc).Select(e => new AnomalyExplanationDto(
                    e.Id, e.Reason.ToString(), e.ExplanationText, e.SupportingNote, e.SubmittedAtUtc, e.IsCorrection)).ToList(),
                item.Reviews.OrderBy(r => r.OccurredAtUtc).Select(r => new AnomalyReviewDto(
                    r.Id, r.AdminUserId, r.Action, r.Notes, r.OccurredAtUtc)).ToList(),
                item.StatusHistory.OrderBy(s => s.OccurredAtUtc).Select(s => new AnomalyStatusEventDto(
                    s.FromStatus.ToString(), s.ToStatus.ToString(), s.ActorUserId, s.Note, s.OccurredAtUtc)).ToList());
        }).ToList();
    }

    private async Task<TrackingSession?> ResolveActiveSessionAsync(Guid? sessionId, CancellationToken cancellationToken)
    {
        if (sessionId is not null)
        {
            return await _db.TrackingSessions.FirstOrDefaultAsync(
                item => item.Id == sessionId
                    && item.RiderUserId == _current.UserId
                    && item.Status == TrackingSessionStatus.Active,
                cancellationToken);
        }

        return await _db.TrackingSessions.FirstOrDefaultAsync(
            item => item.RiderUserId == _current.UserId && item.Status == TrackingSessionStatus.Active,
            cancellationToken);
    }

    private string? ValidatePoint(TrackingLocationPointDto point, RiderLocationTelemetry? previous)
    {
        if (point.Latitude is < -90 or > 90 || point.Longitude is < -180 or > 180)
        {
            return "Invalid coordinates";
        }

        if (point.DeviceTimestampUtc > DateTime.UtcNow.AddMinutes(5))
        {
            return "Device timestamp in the future";
        }

        if (previous is not null && point.DeviceTimestampUtc <= previous.DeviceTimestampUtc)
        {
            return "Out-of-order timestamp";
        }

        if (previous is not null
            && Math.Abs(previous.Latitude - point.Latitude) < 0.0000001
            && Math.Abs(previous.Longitude - point.Longitude) < 0.0000001
            && previous.DeviceTimestampUtc == DateTime.SpecifyKind(point.DeviceTimestampUtc, DateTimeKind.Utc))
        {
            return "Duplicate fix";
        }

        if (point.AccuracyMeters is > 500)
        {
            return "Accuracy too poor";
        }

        return null;
    }

    private static void Transition(
        RouteComplianceAnomaly anomaly,
        RouteAnomalyStatus to,
        string? actorUserId,
        string? note)
    {
        var from = anomaly.Status;
        if (from == to && anomaly.StatusHistory.Count > 0)
        {
            return;
        }

        anomaly.StatusHistory.Add(new RouteAnomalyStatusEvent
        {
            FromStatus = from,
            ToStatus = to,
            ActorUserId = actorUserId,
            Note = Truncate(note, 500),
            OccurredAtUtc = DateTime.UtcNow
        });
        anomaly.Status = to;
    }

    private static TrackingSessionDto ToSessionDto(TrackingSession session) =>
        new(session.Id, session.ShiftId, session.RouteId, session.Status.ToString(), session.StartedAtUtc, session.EndedAtUtc, session.EndReason);

    private static AssignmentStopDto ToStopDto(RouteStop stop) =>
        new(
            stop.Id,
            stop.CustomerId,
            stop.Customer.BusinessName,
            stop.Sequence,
            stop.Status.ToString(),
            stop.Customer.Latitude is null ? null : (double)stop.Customer.Latitude,
            stop.Customer.Longitude is null ? null : (double)stop.Customer.Longitude);

    private static string? Truncate(string? value, int max)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return null;
        }

        var trimmed = value.Trim();
        return trimmed.Length <= max ? trimmed : trimmed[..max];
    }
}
