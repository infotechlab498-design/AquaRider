namespace RouteLedger.Domain;

public static class CashCollectionStatus
{
    public const string CollectedByRider = "CollectedByRider";
    public const string CashReceived = "CashReceived";
}

public static class LinkReviewStatus
{
    public const string Pending = "Pending";
    public const string Approved = "Approved";
    public const string Rejected = "Rejected";
}

public static class CashHandoverStatus
{
    public const string Submitted = "Submitted";
    public const string Received = "Received";
}

/// <summary>Admin proposal to connect a portal account to one route customer. Approval writes the link.</summary>
public sealed class CustomerLinkReview : Entity
{
    public Guid CustomerAccountId { get; set; }
    public CustomerAccount Account { get; set; } = null!;
    public Guid DeliveryCustomerId { get; set; }
    public string MatchBasis { get; set; } = "EmailAndCustomerId";
    public string Status { get; set; } = LinkReviewStatus.Pending;
    public string RequestedByUserId { get; set; } = "";
    public string? ReviewedByUserId { get; set; }
    public string? Comment { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime? ReviewedAt { get; set; }
}

/// <summary>Rider submission of collected cash. Warehouse receipt is a separate confirmation.</summary>
public sealed class CashHandover : Entity
{
    public string ReferenceNumber { get; set; } = "";
    public string RiderId { get; set; } = "";
    public Guid DepotId { get; set; }
    public DateOnly BusinessDate { get; set; }
    public decimal ExpectedAmount { get; set; }
    public decimal? ActualAmount { get; set; }
    public string Status { get; set; } = CashHandoverStatus.Submitted;
    public string SubmittedByUserId { get; set; } = "";
    public DateTime SubmittedAt { get; set; } = DateTime.UtcNow;
    public string? ReceivedByUserId { get; set; }
    public DateTime? ReceivedAt { get; set; }
    public string? Note { get; set; }
}

public sealed class PriceListAssignment : Entity
{
    public Guid PriceListId { get; set; }
    public PriceList PriceList { get; set; } = null!;
    public Guid CustomerId { get; set; }
    public Customer Customer { get; set; } = null!;
}

public sealed class WarehouseStock : Entity
{
    public Guid DepotId { get; set; }
    public Depot Depot { get; set; } = null!;
    public Guid ProductId { get; set; }
    public Product Product { get; set; } = null!;
    public int Quantity { get; set; }
}

public sealed class InventoryCountLine : Entity
{
    public Guid DepotId { get; set; }
    public Guid ProductId { get; set; }
    public int ExpectedQuantity { get; set; }
    public int CountedQuantity { get; set; }
    public int Variance { get; set; }
    public string CountedByUserId { get; set; } = "";
    public DateTime CountedAt { get; set; } = DateTime.UtcNow;
    public string? Note { get; set; }
}
