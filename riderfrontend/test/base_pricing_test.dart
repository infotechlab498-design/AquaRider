import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riderfrontend/adminDashboard/presentation/screens/base_pricing_screen.dart';
import 'package:riderfrontend/api/route_api.dart';

import 'memory_route_api.dart';

void main() {
  testWidgets('pricing screen uses returned catalogue figures', (tester) async {
    tester.view.physicalSize = const Size(1440, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final api = MemoryRouteApi(
      pricingCoverageValue: const PricingCoverage(
        activeProducts: 2,
        categoryCount: 1,
        pricedProducts: 1,
        coveragePercent: 50,
        customerAccounts: 7,
        unpricedProducts: 1,
      ),
      pricingCategories: const [
        ProductCategoryGroup(
          key: 'saleUnits',
          label: 'Sale units',
          description: 'Standard sale units.',
          productCount: 1,
        ),
      ],
      pricingCatalogue: const ProductCataloguePage(
        rows: [
          ProductBasePriceRow(
            id: 'p1',
            name: 'Mineral Bottle',
            sku: 'MIN-175',
            unitLabel: 'Bottle',
            baseSystemPrice: 175,
            effectiveBasePrice: 175,
            priceStatus: 'active',
            categoryKey: 'saleUnits',
          ),
        ],
        page: 1,
        pageSize: 6,
        totalRecords: 1,
        totalPages: 1,
      ),
      pricingValidation: const BasePriceValidation(
        productId: 'p1',
        name: 'Mineral Bottle',
        sku: 'MIN-175',
        unitLabel: 'Bottle',
        basePrice: 175,
        quantity: 1,
        subtotal: 175,
      ),
      pricingHistoryMessage:
          'No base-price change history is stored. The pricing matrix is read-only under Locked V1.',
    );

    await tester.pumpWidget(
      ApiScope(
        api: api,
        child: const MaterialApp(
          home: BasePricingScreen(onNavigate: _ignore),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('base-pricing-screen')), findsOneWidget);
    expect(find.text('Price Lists & Customer Pricing'), findsOneWidget);
    expect(find.text('Approved base price'), findsWidgets);
    expect(find.text('Mineral Bottle'), findsWidgets);
    expect(find.text('PKR 175'), findsWidgets);
    expect(find.text('PKR 0'), findsOneWidget);
    expect(find.text('Showing 1–1 of 1'), findsOneWidget);
    expect(find.textContaining('50% catalog coverage'), findsOneWidget);
    expect(find.text('Gross margin is not shown. Product cost was not returned.'), findsOneWidget);
    expect(find.text('PL-001'), findsNothing);
    expect(find.textContaining('320'), findsNothing);
    expect(find.textContaining('87.5'), findsNothing);
    expect(find.textContaining('1,800'), findsNothing);
    expect(find.text('Standard Retail'), findsNothing);

    await tester.tap(find.byKey(const Key('pricing-audit')));
    await tester.pumpAndSettle();
    expect(find.textContaining('No base-price change history is stored'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('pricing-create')));
    await tester.pumpAndSettle();
    expect(find.text('Create price list'), findsOneWidget);
    expect(find.text('Mineral Bottle'), findsWidgets);
    await tester.enterText(find.byKey(const Key('pricing-list-name')), 'Morning shops');
    await tester.enterText(find.byKey(const Key('pricing-list-code')), 'PL-TEST');
    await tester.ensureVisible(find.byKey(const Key('pricing-list-save')));
    await tester.tap(find.byKey(const Key('pricing-list-save')));
    await tester.pumpAndSettle();
    expect(api.lastPriceList?.name, 'Morning shops');
    expect(api.lastPriceList?.lines.single.productId, 'p1');
    expect(api.lastPriceList?.lines.single.listRate, 175);
    expect(find.text('Morning shops'), findsWidgets);
  });

  testWidgets('pricing screen stays empty when pricing is unavailable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ApiScope(
        api: MemoryRouteApi(),
        child: const MaterialApp(
          home: BasePricingScreen(onNavigate: _ignore),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Product base pricing is not available on this server.'),
      findsWidgets,
    );
    expect(find.text('No approved base-priced products found.'), findsNothing);
    expect(find.textContaining('320'), findsNothing);
    expect(find.text('PL-001'), findsNothing);
  });
}

void _ignore(String key) {}
