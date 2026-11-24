using RouteLedger.Domain;

namespace RouteLedger.Infrastructure.Services;

internal static class OrderLifecycle
{
    public const string OrderCreated = "OrderCreated";
    public const string RiderAssigned = "RiderAssigned";
    public const string RiderReassigned = "RiderReassigned";
    public const string Cancelled = "Cancelled";
    public const string PickListPrepared = "PickListPrepared";

    public static OrderLifecycleEvent Record(Guid orderId, string code, string title, string? detail, string? actorUserId)
    {
        var text = string.IsNullOrWhiteSpace(detail) ? null : detail.Trim();
        if (text is not null && text.Length > 500)
        {
            text = text[..500];
        }

        return new OrderLifecycleEvent
        {
            OrderId = orderId,
            EventCode = code,
            Title = title.Length <= 160 ? title : title[..160],
            Detail = text,
            ActorUserId = string.IsNullOrWhiteSpace(actorUserId) ? null : actorUserId.Trim(),
            OccurredAtUtc = DateTime.UtcNow
        };
    }
}
