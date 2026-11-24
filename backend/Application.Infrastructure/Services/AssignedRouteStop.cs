using Microsoft.EntityFrameworkCore;
using RouteLedger.Domain;
using RouteLedger.Infrastructure.Data;

namespace RouteLedger.Infrastructure.Services;

/// <summary>
/// A rider's day is the route-stop list. An assigned order has to become a stop
/// for that rider and delivery date, or the Rider app never shows it.
/// One stop exists per customer per date.
/// </summary>
internal static class AssignedRouteStop
{
    public static async Task<bool> EnsureAsync(
        AppDbContext db,
        Guid routeId,
        Guid customerId,
        DateOnly serviceDate,
        CancellationToken cancellationToken)
    {
        var existing = await db.RouteStops.FirstOrDefaultAsync(
            stop => stop.CustomerId == customerId && stop.ServiceDate == serviceDate,
            cancellationToken);
        if (existing is not null)
        {
            var changed = false;
            if (existing.RouteId != routeId)
            {
                existing.RouteId = routeId;
                changed = true;
            }

            if (existing.Status == StopStatus.Completed)
            {
                existing.Status = StopStatus.Pending;
                changed = true;
            }

            return changed;
        }

        var sequence = await db.RouteStops
            .Where(stop => stop.RouteId == routeId && stop.ServiceDate == serviceDate)
            .Select(stop => (int?)stop.Sequence)
            .MaxAsync(cancellationToken) ?? 0;
        db.RouteStops.Add(new RouteStop
        {
            CustomerId = customerId,
            RouteId = routeId,
            ServiceDate = serviceDate,
            Sequence = sequence + 1,
            Status = StopStatus.Pending
        });
        return true;
    }
}
