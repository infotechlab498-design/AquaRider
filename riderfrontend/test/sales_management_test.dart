import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riderfrontend/adminDashboard/presentation/screens/sales_management_screen.dart';
import 'package:riderfrontend/api/route_api.dart';

import 'memory_route_api.dart';

void main() {
  testWidgets('sales screen uses returned ledger figures', (tester) async {
    tester.view.physicalSize = const Size(1440, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final api = _SalesApi();
    await tester.pumpWidget(
      ApiScope(
        api: api,
        child: const MaterialApp(
          home: SalesManagementScreen(
            onNavigate: _ignore,
            refreshEvery: null,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('sales-management-screen')), findsOneWidget);
    expect(find.text('Sales Management & Transactions'), findsOneWidget);
    expect(find.text('PKR 860'), findsWidgets);
    expect(find.text('Ali General Store'), findsWidgets);
    expect(find.text('RCP-TEST-1'), findsWidgets);
    expect(find.textContaining('Mineral Bottle'), findsOneWidget);
    expect(find.text('Showing 1–1 of 1'), findsOneWidget);
    expect(find.text('No sale lines were returned.'), findsNothing);
    expect(find.text('PKR 185,000'), findsNothing);
    expect(find.text('RCP-20261110-0042'), findsNothing);
    expect(find.textContaining('Rawalpindi'), findsNothing);
    expect(find.textContaining('SUNMI'), findsNothing);
    expect(api.lastType, 'All');
    expect(api.lastPageSize, 5);

    await tester.tap(find.byKey(const Key('sales-tab-Cash')));
    await tester.pumpAndSettle();
    expect(api.lastType, 'Cash');

    await tester.tap(find.byKey(const Key('sales-print')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('sales-slip-dialog')), findsOneWidget);
    expect(find.textContaining('Mineral Bottle'), findsWidgets);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async => null,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.tap(find.byKey(const Key('sales-export')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(api.lastPageSize, 100);
    expect(find.text('Copied 1 sale as CSV.'), findsOneWidget);
  });

  testWidgets('sales screen stays empty when the ledger is unavailable', (tester) async {
    tester.view.physicalSize = const Size(1440, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ApiScope(
        api: MemoryRouteApi(),
        child: const MaterialApp(
          home: SalesManagementScreen(
            onNavigate: _ignore,
            refreshEvery: null,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(MemoryRouteApi.salesUnavailable), findsOneWidget);
    expect(find.text('PKR 185,000'), findsNothing);
    expect(find.text('146'), findsNothing);
    expect(find.text('RCP-20261110-0042'), findsNothing);
  });
}

void _ignore(String key) {}

class _SalesApi extends MemoryRouteApi {
  String? lastType;
  String? lastSync;
  String? lastRider;
  String? lastSearch;
  int? lastPage;
  int? lastPageSize;

  @override
  Future<AdminSalesSummary> adminSalesSummary({String? date}) async {
    return const AdminSalesSummary(
      operationalDate: '2026-11-19',
      todaysBilledSales: 860,
      billedTransactionCount: 2,
      cashSalesInward: 500,
      cashSaleCount: 1,
      creditReceivablesFromSales: 360,
      creditSaleCount: 1,
      completedSales: 2,
      averageSaleValue: 430,
      pendingSyncCount: 0,
      failedSyncCount: 0,
    );
  }

  @override
  Future<AdminSalePage> adminSales({
    String? date,
    String? type,
    String? syncStatus,
    String? riderId,
    String? search,
    int page = 1,
    int pageSize = 20,
  }) async {
    lastType = type;
    lastSync = syncStatus;
    lastRider = riderId;
    lastSearch = search;
    lastPage = page;
    lastPageSize = pageSize;
    return AdminSalePage(
      rows: [
        AdminSaleRow(
          id: 'sale-1',
          receiptNumber: 'RCP-TEST-1',
          createdAtUtc: DateTime.utc(2026, 11, 19, 6, 40),
          customerId: 'c1',
          customerCode: 'CUS-1',
          customerName: 'Ali General Store',
          riderId: 'r1',
          riderName: 'Ahmed Khan',
          vehicleLabel: 'LEA-8841',
          itemsSummary: '2x 19L',
          itemCount: 2,
          grossAmount: 500,
          amountReceived: 500,
          creditAmount: 0,
          tenderLabel: 'Cash',
          tenderClass: 'Cash',
          status: 'Completed',
          syncStatus: 'Synced',
        ),
      ],
      page: 1,
      pageSize: pageSize,
      totalRecords: 1,
      totalPages: 1,
    );
  }

  @override
  Future<AdminSaleDetail> adminSaleDetail(String id) async {
    return AdminSaleDetail(
      id: id,
      receiptNumber: 'RCP-TEST-1',
      createdAtUtc: DateTime.utc(2026, 11, 19, 6, 40),
      status: 'Completed',
      syncStatus: 'Synced',
      customerId: 'c1',
      customerCode: 'CUS-1',
      customerName: 'Ali General Store',
      customerAddress: 'Satellite Town',
      customerPhone: '03001234567',
      riderId: 'r1',
      riderName: 'Ahmed Khan',
      riderCode: 'RDR-1042',
      vehicleLabel: 'LEA-8841',
      lines: const [
        AdminSaleLineDetail(
          productId: 'p1',
          productName: 'Mineral Bottle',
          quantity: 2,
          unit: 'Bottle',
          unitPrice: 250,
          lineTotal: 500,
        ),
      ],
      grossAmount: 500,
      previousOutstanding: 40,
      amountReceived: 500,
      creditAmount: 0,
      remainingFromSale: 0,
      paymentChannel: 'Cash',
      tenderClass: 'Cash',
      depotName: 'Warehouse Depot Hub 02',
    );
  }
}
