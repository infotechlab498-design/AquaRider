import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riderfrontend/adminDashboard/data/fleet_tracking_models.dart';
import 'package:riderfrontend/adminDashboard/presentation/screens/communication_engine_screen.dart';
import 'package:riderfrontend/api/route_api.dart';
import 'package:riderfrontend/widgets/rider_inbox_button.dart';

import 'memory_route_api.dart';

void main() {
  testWidgets('communication screen uses the recorded message log', (tester) async {
    tester.view.physicalSize = const Size(1440, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final api = _CommApi();
    await tester.pumpWidget(
      ApiScope(
        api: api,
        child: const MaterialApp(home: CommunicationEngineScreen(onNavigate: _ignore)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('communication-engine-screen')), findsOneWidget);
    expect(find.text('Transactional Communication Engine'), findsOneWidget);
    expect(find.text('2'), findsWidgets);
    await tester.tap(find.text('Live Communication History'));
    await tester.pumpAndSettle();
    expect(find.textContaining('In-app'), findsWidgets);
    expect(find.textContaining('Not configured'), findsWidgets);
    expect(find.text('186'), findsNothing);
    expect(find.textContaining('WhatsApp Business'), findsNothing);
    expect(find.textContaining('Telco'), findsNothing);
    expect(find.textContaining('MSG-9821'), findsNothing);

    await tester.tap(find.byKey(const Key('communication-send-rider')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('communication-send-dialog')), findsOneWidget);
    await tester.tap(find.byKey(const Key('communication-send-confirm')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(api.lastRiderId, 'rider-1');
    expect(
      find.text('Recorded MSG-TEST for Infotech Lab. The rider inbox will show it.'),
      findsOneWidget,
    );
  });

  testWidgets('communication screen stays empty when the log is unavailable', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ApiScope(
        api: MemoryRouteApi(),
        child: const MaterialApp(home: CommunicationEngineScreen(onNavigate: _ignore)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(MemoryRouteApi.communicationUnavailable), findsWidgets);
    expect(find.text('186'), findsNothing);
    expect(find.textContaining('WhatsApp'), findsNothing);
  });

  testWidgets('rider inbox badge follows unread notifications', (tester) async {
    final api = _InboxApi();
    await tester.pumpWidget(
      ApiScope(
        api: api,
        child: const MaterialApp(home: Scaffold(body: RiderInboxButton(refreshEvery: null))),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('rider-inbox-badge')), findsOneWidget);
    expect(find.text('1'), findsOneWidget);

    await tester.tap(find.byKey(const Key('rider-inbox-button')));
    await tester.pumpAndSettle();
    expect(find.text('Delivery recorded'), findsOneWidget);
    expect(find.textContaining('PKR 400'), findsOneWidget);

    await tester.tap(find.byKey(const Key('rider-inbox-n1')));
    await tester.pumpAndSettle();
    expect(api.readId, 'n1');
    expect(find.byKey(const Key('rider-inbox-badge')), findsNothing);
  });
}

void _ignore(String _) {}

class _CommApi extends MemoryRouteApi {
  String? lastRiderId;

  @override
  Future<CommunicationDashboardSummary> adminCommunicationSummary({String? date}) async =>
      CommunicationDashboardSummary(
        operationalDate: '2026-11-19',
        messagesDispatchedToday: 2,
        deliveredSuccessfully: 0,
        pendingOrQueued: 0,
        failedOrExceptions: 0,
        gateway: const CommunicationGatewayStatus(
          providerName: 'Not configured',
          status: 'NotConfigured',
          message: 'No SMS credentials are configured.',
        ),
        scopeNote: 'Locked V1: transactional SMS only. WhatsApp and fabricated delivery receipts are disabled.',
      );

  @override
  Future<List<CommunicationTemplate>> adminCommunicationTemplates() async => const [
    CommunicationTemplate(id: 'tpl-1', templateCode: 'T-01', name: 'Sale delivery slip'),
  ];

  @override
  Future<List<CommunicationTrigger>> adminCommunicationTriggers() async => const [];

  @override
  Future<CommunicationMessagePage> adminCommunicationMessages({
    String? date,
    String? status,
    String? search,
    int page = 1,
    int pageSize = 20,
  }) async =>
      CommunicationMessagePage(
        items: const [
          CommunicationMessageRow(
            id: 'm1',
            messageReference: 'MSG-TEST',
            channel: 'In-app',
            status: 'InApp',
            destinationNumber: 'in-app',
          ),
        ],
        totalRecords: 1,
        totalPages: 1,
      );

  @override
  Future<CommunicationPreview> adminCommunicationPreview({
    required String templateId,
    Map<String, String>? variables,
  }) async =>
      const CommunicationPreview(renderedContent: 'Sale recorded.');

  @override
  Future<StaffUserPage> staffUsers({
    String? search,
    String? role,
    bool? isActive,
    int page = 1,
    int pageSize = 50,
  }) async =>
      const StaffUserPage(
        rows: [
          StaffUser(
            id: 'rider-1',
            username: 'infotech',
            fullName: 'Infotech Lab',
            riderCode: 'RDR-1043',
            phone: '03001234567',
          ),
        ],
        totalRecords: 1,
      );

  @override
  Future<CommunicationMessageDetail> adminEnqueueCommunicationMessage({
    String? customerId,
    required String templateId,
    required String destinationNumber,
    String? transactionReference,
    Map<String, String>? variables,
    String? idempotencyKey,
    String? riderUserId,
  }) async {
    lastRiderId = riderUserId;
    return const CommunicationMessageDetail(id: 'm2', messageReference: 'MSG-TEST', status: 'InApp');
  }
}

class _InboxApi extends MemoryRouteApi {
  String? readId;
  var _read = false;

  @override
  Future<List<RiderNotificationInfo>> riderNotifications() async => [
    RiderNotificationInfo(
      id: 'n1',
      title: 'Delivery recorded',
      body: 'Collected PKR 400.',
      deepLink: 'message:m1',
      isRead: _read,
      createdAtUtc: '2026-11-19T10:00:00Z',
    ),
  ];

  @override
  Future<void> markRiderNotificationRead(String id) async {
    readId = id;
    _read = true;
  }
}
