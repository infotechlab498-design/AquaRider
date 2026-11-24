import 'package:riderfrontend/adminDashboard/data/admin_json.dart';

class PricingCoverage {
  const PricingCoverage({
    this.activeProducts,
    this.categoryCount,
    this.pricedProducts,
    this.coveragePercent,
    this.customerAccounts,
    this.unpricedProducts,
  });

  final int? activeProducts;
  final int? categoryCount;
  final int? pricedProducts;
  final num? coveragePercent;
  final int? customerAccounts;
  final int? unpricedProducts;

  factory PricingCoverage.fromJson(Object? data) {
    final map = jsonMap(data);
    if (map == null) return const PricingCoverage();
    return PricingCoverage(
      activeProducts: optionalInt(map, const ['activeProducts']),
      categoryCount: optionalInt(map, const ['categoryCount']),
      pricedProducts: optionalInt(map, const ['pricedProducts']),
      coveragePercent: optionalNum(map, const ['coveragePercent']),
      customerAccounts: optionalInt(map, const ['customerAccounts']),
      unpricedProducts: optionalInt(map, const ['unpricedProducts']),
    );
  }
}

class ProductCategoryGroup {
  const ProductCategoryGroup({
    required this.key,
    this.label = '',
    this.description = '',
    this.productCount = 0,
    this.active = true,
  });

  final String key;
  final String label;
  final String description;
  final int productCount;
  final bool active;

  factory ProductCategoryGroup.fromJson(Map<String, dynamic> json) {
    return ProductCategoryGroup(
      key: jsonString(json, const ['key', 'id']) ?? '',
      label: jsonString(json, const ['label', 'name']) ?? '',
      description: jsonString(json, const ['description']) ?? '',
      productCount: optionalInt(json, const ['productCount']) ?? 0,
      active: json['active'] != false,
    );
  }
}

class ProductBasePriceRow {
  const ProductBasePriceRow({
    required this.id,
    this.name = '',
    this.sku = '',
    this.unitLabel = '',
    this.baseSystemPrice,
    this.effectiveBasePrice,
    this.priceStatus = '',
    this.categoryKey = '',
  });

  final String id;
  final String name;
  final String sku;
  final String unitLabel;
  final num? baseSystemPrice;
  final num? effectiveBasePrice;
  final String priceStatus;
  final String categoryKey;

  factory ProductBasePriceRow.fromJson(Map<String, dynamic> json) {
    return ProductBasePriceRow(
      id: jsonString(json, const ['id']) ?? '',
      name: jsonString(json, const ['name']) ?? '',
      sku: jsonString(json, const ['sku']) ?? '',
      unitLabel: jsonString(json, const ['unitLabel', 'unit']) ?? '',
      baseSystemPrice: optionalNum(json, const ['baseSystemPrice', 'unitPrice']),
      effectiveBasePrice: optionalNum(json, const [
        'effectiveBasePrice',
        'baseSystemPrice',
        'unitPrice',
      ]),
      priceStatus: jsonString(json, const ['priceStatus', 'status']) ?? '',
      categoryKey: jsonString(json, const ['categoryKey']) ?? '',
    );
  }
}

class ProductCataloguePage {
  const ProductCataloguePage({
    this.rows = const [],
    this.page = 1,
    this.pageSize = 20,
    this.totalRecords = 0,
    this.totalPages = 0,
  });

  final List<ProductBasePriceRow> rows;
  final int page;
  final int pageSize;
  final int totalRecords;
  final int totalPages;
}

class BasePriceValidation {
  const BasePriceValidation({
    this.productId = '',
    this.name = '',
    this.sku = '',
    this.unitLabel = '',
    this.basePrice,
    this.priceStatus = '',
    this.quantity = 1,
    this.subtotal,
  });

  final String productId;
  final String name;
  final String sku;
  final String unitLabel;
  final num? basePrice;
  final String priceStatus;
  final int quantity;
  final num? subtotal;

  factory BasePriceValidation.fromJson(Object? data) {
    final map = jsonMap(data);
    if (map == null) return const BasePriceValidation();
    return BasePriceValidation(
      productId: jsonString(map, const ['productId', 'id']) ?? '',
      name: jsonString(map, const ['name']) ?? '',
      sku: jsonString(map, const ['sku']) ?? '',
      unitLabel: jsonString(map, const ['unitLabel']) ?? '',
      basePrice: optionalNum(map, const ['basePrice', 'unitPrice']),
      priceStatus: jsonString(map, const ['priceStatus']) ?? '',
      quantity: optionalInt(map, const ['quantity']) ?? 1,
      subtotal: optionalNum(map, const ['subtotal']),
    );
  }
}

class CustomerBasePriceLookup {
  const CustomerBasePriceLookup({
    this.customerId = '',
    this.customerCode = '',
    this.businessName = '',
    this.status = '',
    this.pricingModel = '',
    this.products = const [],
  });

  final String customerId;
  final String customerCode;
  final String businessName;
  final String status;
  final String pricingModel;
  final List<ProductBasePriceRow> products;

  factory CustomerBasePriceLookup.fromJson(Object? data) {
    final map = jsonMap(data);
    if (map == null) return const CustomerBasePriceLookup();
    final products = jsonRows(map['products']);
    return CustomerBasePriceLookup(
      customerId: jsonString(map, const ['customerId', 'id']) ?? '',
      customerCode: jsonString(map, const ['customerCode', 'code']) ?? '',
      businessName: jsonString(map, const ['businessName', 'name']) ?? '',
      status: jsonString(map, const ['status']) ?? '',
      pricingModel: jsonString(map, const ['pricingModel']) ?? '',
      products: [
        for (final row in products) ProductBasePriceRow.fromJson(row),
      ],
    );
  }
}

class PriceListLine {
  const PriceListLine({
    required this.productId,
    this.name = '',
    this.sku = '',
    this.unitLabel = '',
    this.categoryKey = '',
    this.priceStatus = '',
    this.baseSystemPrice,
    this.listRate,
  });

  final String productId;
  final String name;
  final String sku;
  final String unitLabel;
  final String categoryKey;
  final String priceStatus;
  final num? baseSystemPrice;
  final num? listRate;

  factory PriceListLine.fromJson(Map<String, dynamic> json) {
    return PriceListLine(
      productId: jsonString(json, const ['productId', 'id']) ?? '',
      name: jsonString(json, const ['name']) ?? '',
      sku: jsonString(json, const ['sku']) ?? '',
      unitLabel: jsonString(json, const ['unitLabel', 'unit']) ?? '',
      categoryKey: jsonString(json, const ['categoryKey']) ?? '',
      priceStatus: jsonString(json, const ['priceStatus', 'status']) ?? '',
      baseSystemPrice: optionalNum(json, const ['baseSystemPrice']),
      listRate: optionalNum(json, const ['listRate']),
    );
  }
}

class PriceListSummary {
  const PriceListSummary({
    required this.id,
    this.code = '',
    this.name = '',
    this.description = '',
    this.isDefault = false,
    this.isActive = true,
    this.effectiveFrom = '',
    this.effectiveTo = '',
    this.scope = 'all',
    this.routeId = '',
    this.routeName = '',
    this.zoneId = '',
    this.zoneName = '',
    this.lineCount = 0,
  });

  final String id;
  final String code;
  final String name;
  final String description;
  final bool isDefault;
  final bool isActive;
  final String effectiveFrom;
  final String effectiveTo;
  final String scope;
  final String routeId;
  final String routeName;
  final String zoneId;
  final String zoneName;
  final int lineCount;

  factory PriceListSummary.fromJson(Map<String, dynamic> json) {
    return PriceListSummary(
      id: jsonString(json, const ['id']) ?? '',
      code: jsonString(json, const ['code']) ?? '',
      name: jsonString(json, const ['name']) ?? '',
      description: jsonString(json, const ['description']) ?? '',
      isDefault: jsonBool(json, const ['isDefault']) ?? false,
      isActive: jsonBool(json, const ['isActive']) ?? true,
      effectiveFrom: jsonString(json, const ['effectiveFrom']) ?? '',
      effectiveTo: jsonString(json, const ['effectiveTo']) ?? '',
      scope: jsonString(json, const ['scope']) ?? 'all',
      routeId: jsonString(json, const ['routeId']) ?? '',
      routeName: jsonString(json, const ['routeName']) ?? '',
      zoneId: jsonString(json, const ['zoneId']) ?? '',
      zoneName: jsonString(json, const ['zoneName']) ?? '',
      lineCount: optionalInt(json, const ['lineCount']) ?? 0,
    );
  }
}

class PriceListDetail extends PriceListSummary {
  const PriceListDetail({
    required super.id,
    super.code,
    super.name,
    super.description,
    super.isDefault,
    super.isActive,
    super.effectiveFrom,
    super.effectiveTo,
    super.scope,
    super.routeId,
    super.routeName,
    super.zoneId,
    super.zoneName,
    super.lineCount,
    this.lines = const [],
  });

  final List<PriceListLine> lines;

  factory PriceListDetail.fromJson(Map<String, dynamic> json) {
    final summary = PriceListSummary.fromJson(json);
    return PriceListDetail(
      id: summary.id,
      code: summary.code,
      name: summary.name,
      description: summary.description,
      isDefault: summary.isDefault,
      isActive: summary.isActive,
      effectiveFrom: summary.effectiveFrom,
      effectiveTo: summary.effectiveTo,
      scope: summary.scope,
      routeId: summary.routeId,
      routeName: summary.routeName,
      zoneId: summary.zoneId,
      zoneName: summary.zoneName,
      lineCount: summary.lineCount,
      lines: [
        for (final row in jsonRows(json['lines'])) PriceListLine.fromJson(row),
      ],
    );
  }
}

class CreatePriceListLine {
  const CreatePriceListLine({
    required this.productId,
    required this.listRate,
  });

  final String productId;
  final num listRate;
}

class CreatePriceListRequest {
  const CreatePriceListRequest({
    required this.code,
    required this.name,
    required this.effectiveFrom,
    required this.scope,
    required this.lines,
    this.description,
    this.isDefault = false,
    this.isActive = true,
    this.effectiveTo,
    this.routeId,
    this.zoneId,
  });

  final String code;
  final String name;
  final String? description;
  final bool isDefault;
  final bool isActive;
  final String effectiveFrom;
  final String? effectiveTo;
  final String scope;
  final String? routeId;
  final String? zoneId;
  final List<CreatePriceListLine> lines;

  Map<String, dynamic> toJson() => {
    'code': code,
    'name': name,
    'description': ?description,
    'isDefault': isDefault,
    'isActive': isActive,
    'effectiveFrom': effectiveFrom,
    'effectiveTo': ?effectiveTo,
    'scope': scope,
    'routeId': ?routeId,
    'zoneId': ?zoneId,
    'lines': [
      for (final line in lines)
        {'productId': line.productId, 'listRate': line.listRate, 'included': true},
    ],
  };
}
