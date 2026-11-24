import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riderfrontend/adminDashboard/presentation/screens/collections_management_screen.dart';
import 'package:riderfrontend/api/route_api.dart';

import 'memory_route_api.dart';

void main() {
  testWidgets('collections screen uses returned recovery figures', (tester) async {
    tester.view.physicalSize = const Size(1440, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final api = _CollectionsApi();
    await tester.pumpWidget(
      ApiScope(
        api: api,
        child: const MaterialApp(
          home: CollectionsManagementScreen(
            onNavigate: _ignore,
            refreshEvery: null,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('collections-management-screen')), findsOneWidget);
    expect(find.text('Collections & Recovery Management'), findsOneWidget);
    expect(find.text('PKR 400'), findsWidgets);
    expect(find.text('Ali General Store'), findsWidgets);
    expect(find.text('COL-TEST-1'), findsWidgets);
    expect(find.text('Hassan Super'), findsOneWidget);
    expect(find.text('Showing 1–1 of 1'), findsWidgets);
    expect(find.text('PKR 92,500'), findsNothing);
    expect(find.text('PKR 1.85M'), findsNothing);
    expect(find.text('COL-20261110-0018'), findsNothing);
    expect(find.textContaining('Knox'), findsNothing);
    expect(find.textContaining('Raast'), findsNothing);
    expect(find.textContaining('Rawalpindi'), findsNothing);
    expect(api.lastType, 'All');
    expect(api.lastPageSize, 5);

    await tester.tap(find.byKey(const Key('collections-tab-Cash')));
    await tester.pumpAndSettle();
    expect(api.lastType, 'Cash');

    await tester.ensureVisible(find.byKey(const Key('collections-print')));
    await tester.tap(find.byKey(const Key('collections-print')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('collections-slip-dialog')), findsOneWidget);
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
    await tester.ensureVisible(find.byKey(const Key('collections-export')));
    await tester.tap(find.byKey(const Key('collections-export')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(api.lastPageSize, 100);
    expect(find.text('Copied 1 collection as CSV.'), findsOneWidget);
  });

  testWidgets('collections screen stays empty when the ledger is unavailable', (tester) async {
    tester.view.physicalSize = const Size(1440, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ApiScope(
        api: MemoryRouteApi(),
        child: const MaterialApp(
          home: CollectionsManagementScreen(
            onNavigate: _ignore,
            refreshEvery: null,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(MemoryRouteApi.collectionsUnavailable), findsOneWidget);
    expect(find.text('PKR 92,500'), findsNothing);
    expect(find.text('PKR 1.85M'), findsNothing);
    expect(find.textContaining('Knox'), findsNothing);
  });
}

void _ignore(String key) {}

class _CollectionsApi extends MemoryRouteApi {
  String? lastType;
  String? lastRider;
  int? lastPageSize;

  @override
  Future<AdminCollectionsSummary> adminCollectionsSummary({String? date}) async {
    return const AdminCollectionsSummary(
      operationalDate: '2026-11-19',
      todaysCollections: 400,
      todaysCollectionCount: 1,
      monthlyCollections: 900,
      receivablesLedger: 1500,
      accountsOnCredit: 2,
      highRiskAgingAccounts: 1,
      fieldCollectionCount: 1,
      pendingSyncCount: 0,
      failedSyncCount: 0,
      cashSharePercent: 100,
    );
  }

  @override
  Future<AdminCollectionPage> adminCollections({
    String? date,
    String? type,
    String? riderId,
    String? search,
    int page = 1,
    int pageSize = 20,
  }) async {
    lastType = type;
    lastRider = riderId;
    lastPageSize = pageSize;
    return AdminCollectionPage(
      rows: [
        AdminCollectionRow(
          id: 'col-1',
          referenceNumber: 'COL-TEST-1',
          createdAtUtc: DateTime.utc(2026, 11, 19, 5, 10),
          customerId: 'c1',
          customerCode: 'CUS-1',
          customerName: 'Ali General Store',
          customerArea: 'Satellite Town',
          riderId: 'r1',
          riderName: 'Ahmed Khan',
          channelLabel: 'Cash Spot',
          channelClass: 'Cash',
          amount: 400,
          withholdingTax: 0,
          outstandingBefore: 1900,
          outstandingAfter: 1500,
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
  Future<AdminCollectionDetail> adminCollectionDetail(String id) async {
    return AdminCollectionDetail(
      id: id,
      referenceNumber: 'COL-TEST-1',
      createdAtUtc: DateTime.utc(2026, 11, 19, 5, 10),
      syncStatus: 'Synced',
      customerId: 'c1',
      customerCode: 'CUS-1',
      customerName: 'Ali General Store',
      customerAddress: 'Satellite Town',
      customerPhone: '03001234567',
      riderId: 'r1',
      riderName: 'Ahmed Khan',
      riderCode: 'RDR-1042',
      channelLabel: 'Cash Spot',
      amount: 400,
      withholdingTax: 0,
      outstandingBefore: 1900,
      outstandingAfter: 1500,
      signerName: 'Store Manager',
    );
  }

  @override
  Future<List<AdminReceivableExposure>> adminReceivablesExposure() async {
    return const [
      AdminReceivableExposure(
        customerId: 'c2',
        customerCode: 'CUS-2',
        customerName: 'Hassan Super',
        area: 'Commercial Market',
        outstanding: 1200,
        daysOverdue: 8,
        riskLabel: 'Past terms',
      ),
    ];
  }
}
