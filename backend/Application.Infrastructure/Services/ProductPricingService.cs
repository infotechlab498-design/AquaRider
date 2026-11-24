using Microsoft.EntityFrameworkCore;
using RouteLedger.Application;
using RouteLedger.Domain;
using RouteLedger.Infrastructure.Data;

namespace RouteLedger.Infrastructure.Services;

public sealed class ProductPricingService : IProductPricingService
{
    private readonly AppDbContext _db;

    public ProductPricingService(AppDbContext db)
    {
        _db = db;
    }

    public async Task<ServiceResult<PricingCoverageDto>> CoverageAsync(CancellationToken cancellationToken)
    {
        var products = await _db.Products.AsNoTracking().ToListAsync(cancellationToken);
        var active = products.Count(IsActiveCatalogue);
        var priced = products.Count(item => IsActiveCatalogue(item) && HasValidPrice(item));
        var unpriced = products.Count(item => IsActiveCatalogue(item) && !HasValidPrice(item));
        var customers = await _db.Customers.AsNoTracking().CountAsync(item => !item.IsDeleted, cancellationToken);
        var categories = CategoryKeys(products).Count;
        var dto = new PricingCoverageDto(
            active,
            categories,
            priced,
            active == 0 ? null : ReportingWindow.Percent(priced, active),
            customers,
            unpriced);
        return ServiceResult<PricingCoverageDto>.Ok(dto, "Pricing coverage loaded.");
    }

    public async Task<ServiceResult<IReadOnlyList<ProductCategoryDto>>> CategoriesAsync(CancellationToken cancellationToken)
    {
        var products = await _db.Products.AsNoTracking().ToListAsync(cancellationToken);
        IReadOnlyList<ProductCategoryDto> categories = CategoryKeys(products)
            .Select(key =>
            {
                var rows = products.Where(item => CategoryKey(item) == key).ToList();
                return new ProductCategoryDto(
                    key,
                    CategoryLabel(key),
                    CategoryDescription(key),
                    rows.Count,
                    rows.Any(IsActiveCatalogue));
            })
            .OrderBy(item => item.Label)
            .ToList();
        return ServiceResult<IReadOnlyList<ProductCategoryDto>>.Ok(
            categories,
            categories.Count == 0 ? "No product categories were returned." : "Product categories loaded.");
    }

    public async Task<ServiceResult<IReadOnlyList<ProductBasePriceRowDto>>> CatalogueAsync(
        string? categoryKey,
        string? search,
        string? status,
        int page,
        int pageSize,
        CancellationToken cancellationToken)
    {
        var (pageIndex, size) = ReportingWindow.NormalizePage(page, pageSize);
        var products = await _db.Products.AsNoTracking().OrderBy(item => item.Name).ToListAsync(cancellationToken);
        IEnumerable<Product> query = products;
        if (!string.IsNullOrWhiteSpace(categoryKey) && !categoryKey.Equals("all", StringComparison.OrdinalIgnoreCase))
        {
            query = query.Where(item => CategoryKey(item).Equals(categoryKey.Trim(), StringComparison.OrdinalIgnoreCase));
        }

        if (!string.IsNullOrWhiteSpace(search))
        {
            var term = search.Trim();
            query = query.Where(item =>
                item.Name.Contains(term, StringComparison.OrdinalIgnoreCase)
                || item.Sku.Contains(term, StringComparison.OrdinalIgnoreCase));
        }

        if (!string.IsNullOrWhiteSpace(status) && !status.Equals("all", StringComparison.OrdinalIgnoreCase))
        {
            if (status.Equals("unpriced", StringComparison.OrdinalIgnoreCase))
            {
                query = query.Where(item => !HasValidPrice(item));
            }
            else if (status.Equals("active", StringComparison.OrdinalIgnoreCase))
            {
                query = query.Where(IsActiveCatalogue);
            }
            else if (status.Equals("inactive", StringComparison.OrdinalIgnoreCase))
            {
                query = query.Where(item => !IsActiveCatalogue(item));
            }
        }

        var filtered = query.Select(ToRow).ToList();
        var total = filtered.Count;
        IReadOnlyList<ProductBasePriceRowDto> rows = filtered.Skip((pageIndex - 1) * size).Take(size).ToList();
        var pages = size == 0 ? 0 : (int)Math.Ceiling(total / (double)size);
        return ServiceResult<IReadOnlyList<ProductBasePriceRowDto>>.Ok(
            rows,
            total == 0 ? "No approved base-priced products found." : "Product catalogue loaded.",
            new PaginationMeta { Page = pageIndex, PageSize = size, TotalRecords = total, TotalPages = pages });
    }

    public async Task<ServiceResult<IReadOnlyList<ProductBasePriceRowDto>>> UnpricedAsync(CancellationToken cancellationToken)
    {
        var products = await _db.Products.AsNoTracking().ToListAsync(cancellationToken);
        IReadOnlyList<ProductBasePriceRowDto> rows = products
            .Where(item => IsActiveCatalogue(item) && !HasValidPrice(item))
            .OrderBy(item => item.Name)
            .Select(ToRow)
            .ToList();
        return ServiceResult<IReadOnlyList<ProductBasePriceRowDto>>.Ok(
            rows,
            rows.Count == 0 ? "No unpriced active products." : "Unpriced products loaded.");
    }

    public async Task<ServiceResult<ProductBasePriceRowDto>> BasePriceAsync(Guid id, CancellationToken cancellationToken)
    {
        var product = await _db.Products.AsNoTracking().FirstOrDefaultAsync(item => item.Id == id, cancellationToken);
        return product is null
            ? ServiceResult<ProductBasePriceRowDto>.Fail(404, "Product not found.")
            : ServiceResult<ProductBasePriceRowDto>.Ok(ToRow(product), "Base price loaded.");
    }

    public Task<ServiceResult<IReadOnlyList<object>>> PriceHistoryAsync(Guid id, CancellationToken cancellationToken) =>
        Task.FromResult(ServiceResult<IReadOnlyList<object>>.Ok(
            Array.Empty<object>(),
            "No base-price change history is stored. The pricing matrix is read-only under Locked V1."));

    public async Task<ServiceResult<BasePriceValidationDto>> ValidateAsync(Guid productId, int quantity, CancellationToken cancellationToken)
    {
        if (quantity < 1)
        {
            return ServiceResult<BasePriceValidationDto>.Fail(400, "Quantity must be at least 1.");
        }

        var product = await _db.Products.AsNoTracking().FirstOrDefaultAsync(item => item.Id == productId, cancellationToken);
        if (product is null)
        {
            return ServiceResult<BasePriceValidationDto>.Fail(404, "Product not found.");
        }

        if (!HasValidPrice(product))
        {
            return ServiceResult<BasePriceValidationDto>.Fail(409, "This product has no valid approved base price for new transactions.");
        }

        var subtotal = decimal.Round(product.UnitPrice * quantity, 2, MidpointRounding.AwayFromZero);
        var dto = new BasePriceValidationDto(
            product.Id,
            product.Name,
            product.Sku,
            product.UnitLabel,
            product.UnitPrice,
            PriceStatus(product),
            CategoryKey(product),
            quantity,
            subtotal);
        return ServiceResult<BasePriceValidationDto>.Ok(dto, "Base price validation calculated.");
    }

    public async Task<ServiceResult<CustomerBasePriceLookupDto>> CustomerLookupAsync(Guid customerId, CancellationToken cancellationToken)
    {
        var customer = await _db.Customers.AsNoTracking().FirstOrDefaultAsync(item => item.Id == customerId && !item.IsDeleted, cancellationToken);
        if (customer is null)
        {
            return ServiceResult<CustomerBasePriceLookupDto>.Fail(404, "Customer not found.");
        }

        var products = await _db.Products.AsNoTracking().OrderBy(item => item.Name).ToListAsync(cancellationToken);
        IReadOnlyList<ProductBasePriceRowDto> rows = products.Select(ToRow).ToList();
        var dto = new CustomerBasePriceLookupDto(
            customer.Id,
            customer.Code,
            customer.BusinessName,
            customer.Status,
            "Approved base pricing",
            rows);
        return ServiceResult<CustomerBasePriceLookupDto>.Ok(dto, "Customer base-price lookup loaded.");
    }

    public async Task<ServiceResult<IReadOnlyList<PriceListSummaryDto>>> PriceListsAsync(CancellationToken cancellationToken)
    {
        var lists = await _db.PriceLists.AsNoTracking()
            .Include(item => item.Route)
            .Include(item => item.Zone)
            .Include(item => item.Lines)
            .OrderByDescending(item => item.IsDefault)
            .ThenBy(item => item.Name)
            .ToListAsync(cancellationToken);
        IReadOnlyList<PriceListSummaryDto> rows = lists.Select(ToSummary).ToList();
        return ServiceResult<IReadOnlyList<PriceListSummaryDto>>.Ok(
            rows,
            rows.Count == 0 ? "No price lists were returned." : "Price lists loaded.");
    }

    public async Task<ServiceResult<PriceListDetailDto>> PriceListAsync(Guid id, CancellationToken cancellationToken)
    {
        var list = await LoadListAsync(id, cancellationToken);
        return list is null
            ? ServiceResult<PriceListDetailDto>.Fail(404, "Price list not found.")
            : ServiceResult<PriceListDetailDto>.Ok(ToDetail(list), "Price list loaded.");
    }

    public async Task<ServiceResult<PriceListDetailDto>> CreatePriceListAsync(CreatePriceListRequest request, CancellationToken cancellationToken)
    {
        var code = request.Code.Trim();
        var name = request.Name.Trim();
        if (string.IsNullOrWhiteSpace(name))
        {
            return ServiceResult<PriceListDetailDto>.Fail(400, "Enter a list name.");
        }

        if (string.IsNullOrWhiteSpace(code))
        {
            return ServiceResult<PriceListDetailDto>.Fail(400, "Enter a list code.");
        }

        if (request.EffectiveFrom == default)
        {
            return ServiceResult<PriceListDetailDto>.Fail(400, "Choose the date this list starts.");
        }

        if (request.EffectiveTo is DateOnly end && end < request.EffectiveFrom)
        {
            return ServiceResult<PriceListDetailDto>.Fail(400, "The end date cannot be before the start date.");
        }

        var scope = request.Scope.Trim().ToLowerInvariant();
        if (scope is not ("all" or "route" or "zone"))
        {
            return ServiceResult<PriceListDetailDto>.Fail(400, "Choose whether the list applies to all customers, a route, or a zone.");
        }

        if (scope == "route" && request.RouteId is null)
        {
            return ServiceResult<PriceListDetailDto>.Fail(400, "Choose a route for this list.");
        }

        if (scope == "zone" && request.ZoneId is null)
        {
            return ServiceResult<PriceListDetailDto>.Fail(400, "Choose a zone for this list.");
        }

        var duplicate = await _db.PriceLists.AnyAsync(
            item => item.Code == code,
            cancellationToken);
        if (duplicate)
        {
            return ServiceResult<PriceListDetailDto>.Fail(409, "That list code is already used.");
        }

        if (request.IsDefault && request.IsActive)
        {
            var existingDefault = await _db.PriceLists.AnyAsync(
                item => item.IsDefault && item.IsActive,
                cancellationToken);
            if (existingDefault)
            {
                return ServiceResult<PriceListDetailDto>.Fail(409, "Another active list is already the default fallback.");
            }
        }

        if (scope == "route" && !await _db.DeliveryRoutes.AnyAsync(item => item.Id == request.RouteId, cancellationToken))
        {
            return ServiceResult<PriceListDetailDto>.Fail(404, "Route not found.");
        }

        if (scope == "zone" && !await _db.Zones.AnyAsync(item => item.Id == request.ZoneId, cancellationToken))
        {
            return ServiceResult<PriceListDetailDto>.Fail(404, "Zone not found.");
        }

        var requested = (request.Lines ?? [])
            .Where(line => line.Included)
            .ToList();
        if (requested.Count == 0)
        {
            return ServiceResult<PriceListDetailDto>.Fail(400, "Include at least one product.");
        }

        if (requested.Any(line => line.ListRate < 0))
        {
            return ServiceResult<PriceListDetailDto>.Fail(400, "List rate cannot be negative.");
        }

        if (requested.Select(line => line.ProductId).Distinct().Count() != requested.Count)
        {
            return ServiceResult<PriceListDetailDto>.Fail(400, "A product can appear only once on a list.");
        }

        var productIds = requested.Select(line => line.ProductId).ToList();
        var products = await _db.Products.Where(item => productIds.Contains(item.Id))
            .ToDictionaryAsync(item => item.Id, cancellationToken);
        if (products.Count != productIds.Count)
        {
            return ServiceResult<PriceListDetailDto>.Fail(404, "One of the products was not found.");
        }

        var list = new PriceList
        {
            Code = code,
            Name = name,
            Description = request.Description?.Trim() ?? "",
            IsDefault = request.IsDefault,
            IsActive = request.IsActive,
            EffectiveFrom = request.EffectiveFrom,
            EffectiveTo = request.EffectiveTo,
            Scope = scope,
            RouteId = scope == "route" ? request.RouteId : null,
            ZoneId = scope == "zone" ? request.ZoneId : null,
            Lines = requested.Select(line => new PriceListLine
            {
                ProductId = line.ProductId,
                ListRate = decimal.Round(line.ListRate, 2, MidpointRounding.AwayFromZero),
                BaseSystemPrice = products[line.ProductId].UnitPrice
            }).ToList()
        };
        _db.PriceLists.Add(list);
        await _db.SaveChangesAsync(cancellationToken);
        var saved = await LoadListAsync(list.Id, cancellationToken);
        return ServiceResult<PriceListDetailDto>.Created(ToDetail(saved!), "Price list saved.");
    }

    private async Task<PriceList?> LoadListAsync(Guid id, CancellationToken cancellationToken) =>
        await _db.PriceLists.AsNoTracking()
            .Include(item => item.Route)
            .Include(item => item.Zone)
            .Include(item => item.Lines).ThenInclude(line => line.Product)
            .FirstOrDefaultAsync(item => item.Id == id, cancellationToken);

    private static PriceListSummaryDto ToSummary(PriceList list) =>
        new(
            list.Id,
            list.Code,
            list.Name,
            list.Description,
            list.IsDefault,
            list.IsActive,
            list.EffectiveFrom,
            list.EffectiveTo,
            list.Scope,
            list.RouteId,
            list.Route?.Name,
            list.ZoneId,
            list.Zone?.Name,
            list.Lines.Count);

    private static PriceListDetailDto ToDetail(PriceList list)
    {
        var summary = ToSummary(list);
        IReadOnlyList<PriceListLineDto> lines = list.Lines
            .OrderBy(line => line.Product.Name)
            .Select(line => new PriceListLineDto(
                line.ProductId,
                line.Product.Name,
                line.Product.Sku,
                line.Product.UnitLabel,
                CategoryKey(line.Product),
                PriceStatus(line.Product),
                line.BaseSystemPrice,
                line.ListRate))
            .ToList();
        return new PriceListDetailDto(
            summary.Id,
            summary.Code,
            summary.Name,
            summary.Description,
            summary.IsDefault,
            summary.IsActive,
            summary.EffectiveFrom,
            summary.EffectiveTo,
            summary.Scope,
            summary.RouteId,
            summary.RouteName,
            summary.ZoneId,
            summary.ZoneName,
            summary.LineCount,
            lines);
    }

    private static bool IsActiveCatalogue(Product product) => product.ShowOnSale || product.ShowOnShift || product.IsReturnable;

    private static bool HasValidPrice(Product product)
    {
        // Empty/asset SKUs may legitimately be 0; sale catalogue items require price > 0.
        if (product.ShowOnSale)
        {
            return product.UnitPrice > 0;
        }

        return product.UnitPrice >= 0;
    }

    private static string PriceStatus(Product product)
    {
        if (!IsActiveCatalogue(product))
        {
            return "inactive";
        }

        return HasValidPrice(product) ? "active" : "unpriced";
    }

    private static string CategoryKey(Product product)
    {
        if (product.IsReturnable)
        {
            return "returnable";
        }

        if (!product.ShowOnSale && product.ShowOnShift)
        {
            return "shiftAssets";
        }

        if (product.UnitLabel.Equals("pack", StringComparison.OrdinalIgnoreCase))
        {
            return "packs";
        }

        return "saleUnits";
    }

    private static string CategoryLabel(string key) => key switch
    {
        "returnable" => "Returnable units",
        "shiftAssets" => "Shift & asset SKUs",
        "packs" => "Pack products",
        _ => "Sale units"
    };

    private static string CategoryDescription(string key) => key switch
    {
        "returnable" => "Returnable catalogue items used on sale and stock counts.",
        "shiftAssets" => "Shift-load assets that are not sold through the POS catalogue.",
        "packs" => "Case and pack products priced per pack unit.",
        _ => "Standard sale units using approved base prices."
    };

    private static HashSet<string> CategoryKeys(IEnumerable<Product> products) =>
        products.Select(CategoryKey).ToHashSet(StringComparer.OrdinalIgnoreCase);

    private static ProductBasePriceRowDto ToRow(Product product) =>
        new(
            product.Id,
            product.Name,
            product.Sku,
            product.UnitLabel,
            product.UnitPrice,
            product.UnitPrice,
            PriceStatus(product),
            product.ShowOnSale,
            product.ShowOnShift,
            product.IsReturnable,
            CategoryKey(product));

    public async Task<ServiceResult<PriceListDetailDto>> UpdatePriceListAsync(Guid id, CreatePriceListRequest request, CancellationToken cancellationToken)
    {
        var list = await _db.PriceLists.Include(item => item.Lines).FirstOrDefaultAsync(item => item.Id == id, cancellationToken);
        if (list is null) return ServiceResult<PriceListDetailDto>.Fail(404, "Price list not found.");
        if (string.IsNullOrWhiteSpace(request.Name)) return ServiceResult<PriceListDetailDto>.Fail(400, "Enter a list name.");
        if (request.EffectiveTo is DateOnly end && end < request.EffectiveFrom) return ServiceResult<PriceListDetailDto>.Fail(400, "The end date cannot be before the start date.");
        var requested = (request.Lines ?? []).Where(line => line.Included).ToList();
        if (requested.Count == 0) return ServiceResult<PriceListDetailDto>.Fail(400, "Include at least one product.");
        if (requested.Any(line => line.ListRate < 0)) return ServiceResult<PriceListDetailDto>.Fail(400, "List rate cannot be negative.");
        if (requested.Select(line => line.ProductId).Distinct().Count() != requested.Count) return ServiceResult<PriceListDetailDto>.Fail(400, "A product can appear only once on a list.");
        if (request.IsDefault && list.IsActive)
        {
            var otherDefault = await _db.PriceLists.AnyAsync(item => item.Id != id && item.IsDefault && item.IsActive, cancellationToken);
            if (otherDefault) return ServiceResult<PriceListDetailDto>.Fail(409, "Another active list is already the default fallback.");
        }

        var productIds = requested.Select(line => line.ProductId).ToList();
        var products = await _db.Products.Where(item => productIds.Contains(item.Id)).ToDictionaryAsync(item => item.Id, cancellationToken);
        if (products.Count != productIds.Count) return ServiceResult<PriceListDetailDto>.Fail(404, "One of the products was not found.");
        list.Name = request.Name.Trim();
        list.Description = request.Description?.Trim() ?? "";
        list.IsDefault = request.IsDefault;
        list.IsActive = request.IsActive;
        list.EffectiveFrom = request.EffectiveFrom;
        list.EffectiveTo = request.EffectiveTo;
        list.Scope = string.IsNullOrWhiteSpace(request.Scope) ? list.Scope : request.Scope.Trim();
        list.RouteId = request.RouteId;
        list.ZoneId = request.ZoneId;
        _db.PriceListLines.RemoveRange(list.Lines);
        list.Lines = requested.Select(line => new PriceListLine { ProductId = line.ProductId, ListRate = line.ListRate, BaseSystemPrice = products[line.ProductId].UnitPrice }).ToList();
        await _db.SaveChangesAsync(cancellationToken);
        var saved = await LoadListAsync(list.Id, cancellationToken);
        return ServiceResult<PriceListDetailDto>.Ok(ToDetail(saved!), "Price list updated.");
    }

    public async Task<ServiceResult<PriceListDetailDto>> DuplicatePriceListAsync(Guid id, DuplicatePriceListRequest request, CancellationToken cancellationToken)
    {
        var source = await LoadListAsync(id, cancellationToken);
        if (source is null) return ServiceResult<PriceListDetailDto>.Fail(404, "Price list not found.");
        var copy = new CreatePriceListRequest(
            request.Code,
            request.Name,
            source.Description,
            false,
            source.IsActive,
            source.EffectiveFrom,
            source.EffectiveTo,
            source.Scope,
            source.RouteId,
            source.ZoneId,
            source.Lines.Select(line => new PriceListLineRequest(line.ProductId, line.ListRate)).ToList());
        return await CreatePriceListAsync(copy, cancellationToken);
    }

    public async Task<ServiceResult<PriceListDetailDto>> AssignPriceListAsync(Guid id, AssignPriceListRequest request, CancellationToken cancellationToken)
    {
        var list = await _db.PriceLists.FirstOrDefaultAsync(item => item.Id == id, cancellationToken);
        if (list is null) return ServiceResult<PriceListDetailDto>.Fail(404, "Price list not found.");
        var ids = (request.CustomerIds ?? []).Distinct().ToList();
        var found = await _db.Customers.CountAsync(item => ids.Contains(item.Id) && !item.IsDeleted, cancellationToken);
        if (found != ids.Count) return ServiceResult<PriceListDetailDto>.Fail(400, "One or more route customers were not found.");
        var existing = await _db.PriceListAssignments.Where(item => item.PriceListId == id || ids.Contains(item.CustomerId)).ToListAsync(cancellationToken);
        _db.PriceListAssignments.RemoveRange(existing);
        foreach (var customerId in ids)
        {
            _db.PriceListAssignments.Add(new PriceListAssignment { PriceListId = id, CustomerId = customerId });
        }

        await _db.SaveChangesAsync(cancellationToken);
        var saved = await LoadListAsync(id, cancellationToken);
        return ServiceResult<PriceListDetailDto>.Ok(ToDetail(saved!), "Customers assigned to this price list.");
    }
}
