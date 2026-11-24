import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:riderfrontend/adminDashboard/data/admin_json.dart';
import 'package:riderfrontend/adminDashboard/data/base_pricing_models.dart';
import 'package:riderfrontend/adminDashboard/data/dashboard_models.dart';
import 'package:riderfrontend/adminDashboard/data/day_close_models.dart';
import 'package:riderfrontend/adminDashboard/data/dispatch_models.dart';
import 'package:riderfrontend/adminDashboard/data/onboarding_models.dart';
import 'package:riderfrontend/adminDashboard/data/rider_operations_models.dart';
import 'package:riderfrontend/adminDashboard/data/admin_audit_models.dart';
import 'package:riderfrontend/adminDashboard/data/admin_collections_models.dart';
import 'package:riderfrontend/adminDashboard/data/admin_communication_models.dart';
import 'package:riderfrontend/adminDashboard/data/admin_customers_models.dart';
import 'package:riderfrontend/adminDashboard/data/admin_login_preview.dart';
import 'package:riderfrontend/adminDashboard/data/admin_reports_models.dart';
import 'package:riderfrontend/adminDashboard/data/admin_sales_models.dart';
import 'package:riderfrontend/adminDashboard/data/admin_shift_models.dart';
import 'package:riderfrontend/adminDashboard/data/recurring_schedule_models.dart';
import 'package:riderfrontend/adminDashboard/data/depot_models.dart';
import 'package:riderfrontend/adminDashboard/data/fleet_tracking_models.dart';
import 'package:riderfrontend/adminDashboard/data/users_staff_models.dart';
import 'package:riderfrontend/adminDashboard/data/zones_routes_models.dart';
import 'package:riderfrontend/customerApp/customer_models.dart';

export 'package:riderfrontend/adminDashboard/data/admin_audit_models.dart';
export 'package:riderfrontend/adminDashboard/data/admin_collections_models.dart';
export 'package:riderfrontend/adminDashboard/data/admin_communication_models.dart';
export 'package:riderfrontend/adminDashboard/data/admin_customers_models.dart';
export 'package:riderfrontend/adminDashboard/data/admin_login_preview.dart';
export 'package:riderfrontend/adminDashboard/data/admin_reports_models.dart';
export 'package:riderfrontend/adminDashboard/data/admin_sales_models.dart';
export 'package:riderfrontend/adminDashboard/data/base_pricing_models.dart';
export 'package:riderfrontend/adminDashboard/data/dashboard_models.dart';
export 'package:riderfrontend/adminDashboard/data/day_close_models.dart';
export 'package:riderfrontend/adminDashboard/data/depot_models.dart';
export 'package:riderfrontend/adminDashboard/data/dispatch_models.dart';
export 'package:riderfrontend/adminDashboard/data/onboarding_models.dart';
export 'package:riderfrontend/adminDashboard/data/rider_operations_models.dart';
export 'package:riderfrontend/adminDashboard/data/users_staff_models.dart';
export 'package:riderfrontend/adminDashboard/data/zones_routes_models.dart';
export 'package:riderfrontend/customerApp/customer_models.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiConfig {
  static const hostOverride = String.fromEnvironment('API_HOST');

  static String get baseUrl {
    if (hostOverride.isNotEmpty) return hostOverride;
    // Physical Android phones reach this PC on the LAN. The emulator address
    // 10.0.2.2 is not reachable from a handset and leaves sign-in spinning.
    // Avoid dart:io Platform so Chrome/web builds stay valid.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://192.168.18.134:5266';
    }
    return 'http://localhost:5266';
  }
}

class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.fullName,
    required this.username,
    required this.riderCode,
    required this.routeName,
    required this.vehicleName,
    required this.vehiclePlate,
    required this.fleetCode,
    required this.depotGate,
    required this.depotName,
    this.role = 'Rider',
    this.allowedScreens,
    this.customerCode = '',
  });

  final String accessToken;
  final String refreshToken;
  final String fullName;
  final String username;
  final String riderCode;
  final String routeName;
  final String vehicleName;
  final String vehiclePlate;
  final String fleetCode;
  final String depotGate;
  final String depotName;
  final String role;
  final List<String>? allowedScreens;
  final String customerCode;

  bool allowsScreen(String key) {
    if (isAdmin || allowedScreens == null) return true;
    return allowedScreens!.contains(key);
  }

  bool get isAdmin => role.trim().toLowerCase() == 'admin';

  String get firstName {
    final parts = fullName.split(' ');
    return parts.isEmpty ? fullName : parts.first;
  }
}

class DashboardData {
  const DashboardData({
    required this.greeting,
    required this.serviceDate,
    required this.shiftOpen,
    required this.riderName,
    required this.riderCode,
    required this.routeName,
    required this.vehicleName,
    required this.vehiclePlate,
    required this.fleetCode,
    required this.depotGate,
    required this.depotName,
    required this.billedSales,
    required this.salesCount,
    required this.cashCollected,
    required this.visitedCount,
    required this.totalStops,
    required this.pendingDeliveries,
    required this.pendingNote,
    required this.remainingStops,
    required this.nextStopName,
    required this.nextDistanceMeters,
    required this.remainingDistanceKm,
    required this.openTodoCount,
    this.nextLatitude,
    this.nextLongitude,
    this.nextAddress,
  });

  final String greeting;
  final String serviceDate;
  final bool shiftOpen;
  final String riderName;
  final String riderCode;
  final String routeName;
  final String vehicleName;
  final String vehiclePlate;
  final String fleetCode;
  final String depotGate;
  final String depotName;
  final num billedSales;
  final int salesCount;
  final num cashCollected;
  final int visitedCount;
  final int totalStops;
  final int pendingDeliveries;
  final String pendingNote;
  final int remainingStops;
  final String? nextStopName;
  final int? nextDistanceMeters;
  final num remainingDistanceKm;
  final int openTodoCount;
  final double? nextLatitude;
  final double? nextLongitude;
  final String? nextAddress;
}

class StopItem {
  const StopItem({
    required this.id,
    required this.customerId,
    required this.sequence,
    required this.customerName,
    required this.customerCode,
    required this.address,
    required this.phone,
    required this.status,
    required this.scheduledTime,
    required this.outstanding,
    required this.emptyBottles,
    required this.distanceMeters,
    required this.actionLabel,
    required this.receiptSaleId,
    required this.invoiceNumber,
    this.latitude,
    this.longitude,
  });

  final String id;
  final String customerId;
  final int sequence;
  final String customerName;
  final String customerCode;
  final String address;
  final String phone;
  final String status;
  final String? scheduledTime;
  final num outstanding;
  final int emptyBottles;
  final int? distanceMeters;
  final String actionLabel;
  final String? receiptSaleId;
  final String? invoiceNumber;
  final num? latitude;
  final num? longitude;

  String get initials {
    final parts = customerName
        .split(' ')
        .where((part) => part.isNotEmpty)
        .take(2);
    return parts.map((part) => part[0]).join().toUpperCase();
  }
}

class CustomerDetail {
  const CustomerDetail({
    required this.id,
    required this.code,
    required this.businessName,
    required this.category,
    required this.status,
    required this.phone,
    required this.additionalContact,
    required this.street,
    required this.area,
    required this.city,
    required this.latitude,
    required this.longitude,
    required this.routeName,
    required this.routeId,
    required this.outstanding,
    required this.lastDropAt,
    required this.openOrders,
    required this.bottlesIssued,
    required this.bottlesReturned,
    required this.bottlesHeld,
    required this.bottleOwnership,
    required this.cnic,
    required this.contactName,
    required this.contactRole,
    required this.creditDays,
    required this.lastPaymentLabel,
    this.nextOrderProduct,
    this.nextOrderQuantity = 0,
    this.nextOrderDate,
  });

  final String id;
  final String code;
  final String businessName;
  final String category;
  final String status;
  final String phone;
  final String? additionalContact;
  final String street;
  final String area;
  final String city;
  final num? latitude;
  final num? longitude;
  final String routeName;
  final String routeId;
  final num outstanding;
  final DateTime? lastDropAt;
  final int openOrders;
  final int bottlesIssued;
  final int bottlesReturned;
  final int bottlesHeld;
  final String bottleOwnership;
  final String? cnic;
  final String? contactName;
  final String? contactRole;
  final int creditDays;
  final String? lastPaymentLabel;
  final String? nextOrderProduct;
  final int nextOrderQuantity;
  final String? nextOrderDate;

  String get initials {
    final parts = businessName
        .split(' ')
        .where((part) => part.isNotEmpty)
        .take(2);
    return parts.map((part) => part[0]).join().toUpperCase();
  }
}

class ProductItem {
  const ProductItem({
    required this.id,
    required this.name,
    required this.unitPrice,
    required this.unitLabel,
    required this.vanStock,
    required this.depotExpected,
    required this.isReturnable,
  });

  final String id;
  final String name;
  final num unitPrice;
  final String unitLabel;
  final int vanStock;
  final int depotExpected;
  final bool isReturnable;
}

class SaleContext {
  const SaleContext({
    required this.customer,
    required this.products,
    required this.emptyBottlesHeld,
  });

  final CustomerDetail customer;
  final List<ProductItem> products;
  final int emptyBottlesHeld;
}

class SaleLineItem {
  const SaleLineItem({
    required this.productId,
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
  });

  final String productId;
  final String name;
  final int quantity;
  final num unitPrice;
  final num lineTotal;
}

class SaleDraft {
  const SaleDraft({
    required this.id,
    required this.customerId,
    required this.saleAmount,
    required this.previousOutstanding,
    required this.amountDue,
    required this.emptyBottlesReturned,
    required this.emptyBottlesRemaining,
    required this.lines,
    this.receiptNumber = '',
  });

  final String id;
  final String customerId;
  final num saleAmount;
  final num previousOutstanding;
  final num amountDue;
  final int emptyBottlesReturned;
  final int emptyBottlesRemaining;
  final List<SaleLineItem> lines;
  final String receiptNumber;
}

class ReceiptData {
  const ReceiptData({
    required this.id,
    required this.kind,
    required this.receiptNumber,
    required this.issuedAt,
    required this.riderName,
    required this.riderCode,
    required this.customerName,
    required this.customerCode,
    required this.lines,
    required this.saleAmount,
    required this.previousOutstanding,
    required this.amountReceived,
    required this.balanceAfter,
    required this.paymentMethod,
    required this.signerName,
    required this.signerRole,
    required this.syncStatus,
    this.customerAddress = '',
    this.customerPhone = '',
    this.depotName = '',
    this.depotAddress = '',
    this.emptyBottlesReturned = 0,
    this.emptyBottlesHeld = 0,
    this.signatureNote,
    this.withholdingTax = 0,
  });

  final String id;
  final String kind;
  final String receiptNumber;
  final DateTime issuedAt;
  final String riderName;
  final String riderCode;
  final String customerName;
  final String customerCode;
  final List<SaleLineItem> lines;
  final num saleAmount;
  final num previousOutstanding;
  final num amountReceived;
  final num balanceAfter;
  final String paymentMethod;
  final String? signerName;
  final String? signerRole;
  final String syncStatus;
  final String customerAddress;
  final String customerPhone;
  final String depotName;
  final String depotAddress;
  final int emptyBottlesReturned;
  final int emptyBottlesHeld;
  final String? signatureNote;
  final int withholdingTax;

  int get previousBottlesHeld => emptyBottlesHeld + emptyBottlesReturned;
}

class LedgerRow {
  const LedgerRow({
    required this.id,
    required this.description,
    required this.occurredAt,
    required this.amount,
    required this.balanceAfter,
    this.kind = 'Opening',
    this.reference,
    this.detail,
  });

  final String id;
  final String description;
  final DateTime occurredAt;
  final num amount;
  final num balanceAfter;
  final String kind;
  final String? reference;
  final String? detail;

  bool get isCredit => kind == 'Payment' || amount < 0;
}

class BottleMovement {
  const BottleMovement({
    required this.occurredAt,
    required this.fullGiven,
    required this.emptiesReturned,
    required this.holdingAfter,
    required this.note,
  });

  final DateTime occurredAt;
  final int fullGiven;
  final int emptiesReturned;
  final int holdingAfter;
  final String note;
}

class LedgerData {
  const LedgerData({
    required this.customerId,
    required this.customerName,
    required this.customerCode,
    required this.outstanding,
    required this.creditDays,
    required this.bottlesIssued,
    required this.bottlesReturned,
    required this.bottlesHeld,
    required this.entries,
    this.openOrders = 0,
    this.todayCollected = 0,
    this.stopSequence,
    this.movements = const [],
  });

  final String customerId;
  final String customerName;
  final String customerCode;
  final num outstanding;
  final int creditDays;
  final int bottlesIssued;
  final int bottlesReturned;
  final int bottlesHeld;
  final List<LedgerRow> entries;
  final int openOrders;
  final num todayCollected;
  final int? stopSequence;
  final List<BottleMovement> movements;
}

class ShiftLine {
  const ShiftLine({
    required this.productId,
    required this.name,
    required this.depotExpected,
    required this.countedQuantity,
    required this.editable,
  });

  final String productId;
  final String name;
  final int depotExpected;
  final int countedQuantity;
  final bool editable;
}

class ShiftData {
  const ShiftData({
    required this.id,
    required this.status,
    required this.serviceDate,
    required this.openingOdometer,
    required this.fleetCode,
    required this.routeLabel,
    required this.depotLabel,
    this.odometerVerified = false,
    required this.lines,
  });

  final String? id;
  final String status;
  final String serviceDate;
  final int openingOdometer;
  final String fleetCode;
  final String routeLabel;
  final String depotLabel;
  final bool odometerVerified;
  final List<ShiftLine> lines;
}

class HistoryItem {
  const HistoryItem({
    required this.id,
    required this.title,
    required this.reference,
    required this.occurredAt,
    required this.amount,
    required this.syncStatus,
    required this.detail,
    this.customerCode,
  });

  final String id;
  final String title;
  final String reference;
  final DateTime occurredAt;
  final num? amount;
  final String syncStatus;
  final String detail;
  final String? customerCode;
}

class HistoryData {
  const HistoryData({
    required this.synced,
    required this.pending,
    required this.failed,
    required this.items,
    this.riderUserId = '',
    this.riderName = '',
    this.riderCode = '',
  });

  final int synced;
  final int pending;
  final int failed;
  final List<HistoryItem> items;
  final String riderUserId;
  final String riderName;
  final String riderCode;
}

class SettingsData {
  const SettingsData({
    required this.autoSync,
    required this.showOrdersTab,
    required this.language,
    required this.autoPrint,
    required this.deleteOnLogout,
    required this.paperSize,
    required this.printerId,
    required this.printerName,
  });

  final bool autoSync;
  final bool showOrdersTab;
  final String language;
  final bool autoPrint;
  final bool deleteOnLogout;
  final String paperSize;
  final String? printerId;
  final String? printerName;

  SettingsData copyWith({
    bool? autoSync,
    bool? showOrdersTab,
    String? language,
    bool? autoPrint,
    bool? deleteOnLogout,
    String? paperSize,
    String? printerId,
    String? printerName,
  }) {
    return SettingsData(
      autoSync: autoSync ?? this.autoSync,
      showOrdersTab: showOrdersTab ?? this.showOrdersTab,
      language: language ?? this.language,
      autoPrint: autoPrint ?? this.autoPrint,
      deleteOnLogout: deleteOnLogout ?? this.deleteOnLogout,
      paperSize: paperSize ?? this.paperSize,
      printerId: printerId ?? this.printerId,
      printerName: printerName ?? this.printerName,
    );
  }
}

class PrinterItem {
  const PrinterItem({
    required this.id,
    required this.name,
    required this.meta,
    required this.isOnline,
    required this.selected,
  });

  final String id;
  final String name;
  final String meta;
  final bool isOnline;
  final bool selected;
}

class CustomerDraft {
  const CustomerDraft({
    required this.businessName,
    required this.primaryMobile,
    required this.additionalContact,
    required this.category,
    required this.street,
    required this.area,
    required this.city,
    required this.latitude,
    required this.longitude,
    required this.bottleOwnership,
    required this.openingDebt,
    required this.openingEmpties,
    required this.cnic,
    required this.contactName,
    required this.contactRole,
    this.id,
  });

  final String? id;
  final String businessName;
  final String primaryMobile;
  final String? additionalContact;
  final String category;
  final String street;
  final String area;
  final String city;
  final num? latitude;
  final num? longitude;
  final String bottleOwnership;
  final num openingDebt;
  final int openingEmpties;
  final String? cnic;
  final String? contactName;
  final String? contactRole;
}

class SsoStatus {
  const SsoStatus({
    required this.available,
    required this.message,
    this.provider,
    this.authorizationUrl,
  });

  final bool available;
  final String message;
  final String? provider;
  final String? authorizationUrl;

  factory SsoStatus.fromJson(Map<String, dynamic> json) {
    final okta = json['okta'] is Map
        ? Map<String, dynamic>.from(json['okta'] as Map)
        : null;
    final azure = json['azureAd'] is Map
        ? Map<String, dynamic>.from(json['azureAd'] as Map)
        : (json['azureAD'] is Map
              ? Map<String, dynamic>.from(json['azureAD'] as Map)
              : null);
    final oktaOn = okta?['enabled'] == true;
    final azureOn = azure?['enabled'] == true;
    final available =
        json['available'] == true ||
        json['enabled'] == true ||
        oktaOn ||
        azureOn;
    final message = (json['message'] as String?)?.trim();
    final url = json['authorizationUrl'] as String? ?? json['url'] as String?;
    final provider = oktaOn
        ? (okta?['name'] as String? ?? 'Okta')
        : azureOn
        ? (azure?['name'] as String? ?? 'Azure AD')
        : json['provider'] as String? ?? json['name'] as String?;
    return SsoStatus(
      available: available && url != null && url.isNotEmpty,
      provider: provider,
      authorizationUrl: url,
      message: (message == null || message.isEmpty)
          ? (available && (url == null || url.isEmpty)
                ? 'Corporate IdP is marked enabled, but no authorization URL is configured yet.'
                : (available
                      ? 'Corporate sign-on is configured.'
                      : 'Corporate Okta / Azure AD single sign-on is not configured on this server.'))
          : message,
    );
  }
}

class CustomerRegistration {
  const CustomerRegistration({
    required this.customerCode,
    required this.fullName,
    required this.email,
  });

  final String customerCode;
  final String fullName;
  final String email;
}

abstract class RouteApi {
  Future<AuthSession> login(
    String username,
    String password, {
    bool rememberMe = false,
  });
  Future<CustomerRegistration> registerCustomer(Map<String, dynamic> body);
  Future<AuthSession?> currentSession();
  Future<CustomerHome> customerHome();
  Future<List<CustomerPlan>> customerSchedules();
  Future<CustomerCalendar> customerCalendar(String scheduleId, int year, int month);
  Future<List<CustomerVisit>> customerHistory({String? scheduleId, String? status, String? from, String? to});
  Future<CustomerPayments> customerPayments();
  Future<CustomerInvoiceDetail> customerInvoice(String number);
  Future<CustomerProfile> updateCustomerProfile({required String firstName, required String lastName, required String phone});
  Future<List<CustomerRequest>> customerRequests();
  Future<CustomerRequest> submitCustomerRequest(Map<String, dynamic> body);
  Future<CustomerRequestPreview> previewCustomerRequest(Map<String, dynamic> body);
  Future<CustomerRequest> cancelCustomerRequest(String id);
  Future<CustomerRequest> replyCustomerRequest(String id, String notes);
  Future<CustomerProfile> customerProfile();
  Future<CustomerAddress> saveCustomerAddress(Map<String, dynamic> body, {String? id});
  Future<CustomerAddress> defaultCustomerAddress(String id);
  Future<CustomerAddress> deactivateCustomerAddress(String id);
  Future<List<CustomerNote>> customerNotifications();
  Future<void> readCustomerNotification(String id);
  Future<void> readAllCustomerNotifications();
  Future<CustomerAccountBoard> customerAccountBoard({String? search, String? status});
  Future<CustomerOpsOverview> customerOpsOverview();
  Future<CustomerAccountDetail> customerAccountDetail(String id);
  Future<CustomerAccountDetail> linkCustomerAccount(String id, {String? deliveryCustomerId});
  Future<List<CustomerAccountRow>> unlinkedCustomerAccounts();
  Future<List<CustomerLinkReview>> customerLinkReviews({String? status});
  Future<CustomerLinkReview> proposeCustomerLink(String accountId, {required String email, required String customerCode});
  Future<CustomerLinkReview> reviewCustomerLink(String reviewId, {required String action, String? comment});
  Future<PolicyDocument> policyDocument(String kind);
  Future<HqSettings> hqSettings();
  Future<HqSettings> updateHqSettings(Map<String, dynamic> body);
  Future<List<CashHandover>> cashHandovers({String? status});
  Future<CashHandover> submitCashHandover({required String businessDate, String? depotId});
  Future<CashHandover> confirmCashHandover(String id, {required num actualAmount, String? note});
  Future<OfficeDocument> invoicePdf(String number);
  Future<OfficeDocument> orderPdf(String id);
  Future<OfficeDocument> orderCsv(String id);
  Future<OfficeDocument> manifestPdf({required String routeId, required String date});
  Future<void> updatePriceList(String id, Map<String, dynamic> body);
  Future<void> duplicatePriceList(String id, {required String code, required String name});
  Future<void> assignPriceList(String id, List<String> customerIds);
  Future<void> createWarehouse({required String name, required String gate, required String address});
  Future<void> recordInventoryCount({required String depotId, required String productId, required int countedQuantity, String? note});
  Future<CustomerAccountDetail> setCustomerAccountStatus(String id, String status);
  Future<List<CustomerRequest>> customerRequestQueue({String? type, String? status, String? search, String? city});
  Future<CustomerRequestPreview> customerRequestImpact(String id);
  Future<CustomerRequest> reviewCustomerRequest(String id, {required String action, String? comment});
  Future<AdminLoginPreview> adminLoginPreview();
  Future<SsoStatus> ssoStatus();
  Future<OnboardingOverview?> onboardingOverview();
  Future<List<OnboardingStep>?> onboardingSteps();
  Future<OnboardingProgress?> onboardingProgress();
  Future<OnboardingReadiness?> onboardingReadiness();
  Future<OnboardingNextStep?> onboardingNextStep();
  Future<List<OnboardingActivity>?> onboardingActivity();
  Future<void> logout({bool clearLocal = false});
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });
  Future<void> forgotPassword(String username);
  Future<DashboardData> dashboard();
  Future<List<StopItem>> stops({String? search, String? filter});
  Future<List<StopItem>> sequenceTodayStops({required List<String> orderedStopIds});
  Future<CustomerDetail> customer(String id);
  Future<SaleContext> saleContext(String customerId);
  Future<SaleDraft> createSale({
    required String customerId,
    String? stopId,
    required Map<String, int> quantities,
    int? emptyBottlesReturned,
  });
  Future<ReceiptData> completeSale({
    required String saleId,
    required String method,
    required String signerName,
    String? signerRole,
    int? amountReceived,
    bool closeStop = true,
    String? signatureImage,
    String? signatureNote,
  });
  Future<ReceiptData> receipt(String saleId);
  Future<ReceiptData> collect({
    required String customerId,
    required num amount,
    required String channel,
    required String signerName,
    String? signerRole,
    String? signatureImage,
    String? signatureNote,
    int withholdingTax = 0,
    String? note,
  });
  Future<void> createOrder({
    required String customerId,
    required Map<String, int> quantities,
    required String window,
    String? deliveryDate,
    String? note,
    bool showOnManifest = true,
  });
  Future<LedgerData> ledger(String customerId);
  Future<ShiftData> currentShift();
  Future<ShiftData> startShift(
    List<Map<String, dynamic>> stock, {
    required int openingOdometer,
    String? odometerPhoto,
    String? inspectionPhoto,
  });
  Future<ShiftData> endShift({
    required int closingOdometer,
    String? odometerPhoto,
    String? inspectionPhoto,
    List<Map<String, dynamic>> stock = const [],
  });
  Future<HistoryData> history({String? search, String? date});
  Future<SettingsData> settings();
  Future<SettingsData> updateSettings(SettingsData value);
  Future<List<PrinterItem>> printers();
  Future<String> printReceipt(String saleId);
  Future<CustomerDetail> saveCustomer(CustomerDraft draft);
  Future<void> logVisit(String customerId, String outcome);
  Future<CommandOverview> commandOverview({
    required String from,
    required String to,
  });
  Future<DashboardKpiSet> commandKpis({
    required String from,
    required String to,
  });
  Future<OperationalSummary> operationalSummary({
    required String from,
    required String to,
  });
  Future<List<AttentionItem>> attentionItems({
    required String from,
    required String to,
  });
  Future<SalesSummary> salesSummary({
    required String from,
    required String to,
    required String bucket,
  });
  Future<CollectionsSummary> collectionsSummary({
    required String from,
    required String to,
  });
  Future<ActivityLedgerPage> activityLedger({
    required String from,
    required String to,
    String? search,
    String? status,
    int page = 1,
    int pageSize = 8,
  });
  Future<AdminOrderResult> createDashboardOrder(AdminOrderRequest request);
  Future<RiderOperationsSummary> riderOperationsSummary({required String date});
  Future<List<RiderRecord>> riderOperationsRiders({
    String? search,
    String? status,
    required String date,
  });
  Future<RiderRecord> riderOperationsRider(String id, {required String date});
  Future<List<RiderActivityItem>> riderOperationsActivity(String id);
  Future<List<RiderAssignment>> riderOperationsAssignments(
    String id, {
    required String date,
  });
  Future<List<RiderExceptionItem>> riderOperationsExceptions({
    required String date,
  });
  Future<List<LocationVerification>> riderOperationsLocationVerifications();
  Future<DispatchOrderSummary> dispatchOrdersSummary({
    String? from,
    String? to,
  });
  Future<DispatchStatusCounts> dispatchStatusCounts({
    String? from,
    String? to,
    String? search,
  });
  Future<DispatchOrderPage> dispatchOrders({
    int page = 1,
    int pageSize = 10,
    String? search,
    String? status,
    String? from,
    String? to,
    String? riderId,
    bool unassignedOnly = false,
  });
  Future<DispatchOrderDetail> dispatchOrder(String id);
  Future<List<DispatchOrderItem>> dispatchOrderItems(String id);
  Future<List<DispatchLifecycleEvent>> dispatchOrderLifecycle(String id);
  Future<DispatchPickList> dispatchOrderPickList(String id);
  Future<List<EligibleRider>> dispatchEligibleRiders({
    String? orderId,
    String? search,
  });
  Future<DispatchOperationalSummary> dispatchOperationalSummary({
    String? from,
    String? to,
  });
  Future<DispatchActionResult> dispatchAssignRider(
    String id, {
    required String riderId,
  });
  Future<DispatchActionResult> dispatchReassignRider(
    String id, {
    required String riderId,
  });
  Future<DispatchActionResult> dispatchCancelOrder(
    String id, {
    required String reason,
  });
  Future<DispatchPickList> dispatchPreparePickList(String id);

  Future<DayCloseSummary> dayCloseSummary({String? date});
  Future<SettlementStatusCounts> settlementStatusCounts({
    String? date,
    String? search,
  });
  Future<SettlementSessionPage> settlementSessions({
    String? date,
    String? status,
    String? search,
    int page = 1,
    int pageSize = 20,
  });
  Future<SettlementSessionDetail> settlementSession(String id);
  Future<SettlementSessionDetail> settlementSaveDraft(
    String id, {
    num? cashierVerifiedCash,
    String? resolutionCategory,
    String? remarks,
    String? riderAnnotation,
  });
  Future<SettlementSessionDetail> settlementVerifyCash(
    String id, {
    required num verifiedAmount,
    String? batchReference,
    String? notes,
  });
  Future<SettlementSessionDetail> settlementResolve(
    String id, {
    num? cashierVerifiedCash,
    String? resolutionCategory,
    String? remarks,
  });
  Future<DayLockReadiness> settlementLockReadiness(String date);
  Future<DayLockResult> settlementLockDay(String date, {String? note});
  Future<PricingCoverage> pricingCoverage();
  Future<List<ProductCategoryGroup>> productCategories();
  Future<ProductCataloguePage> productCatalogue({
    String? categoryKey,
    String? search,
    String? status,
    int page = 1,
    int pageSize = 20,
  });
  Future<BasePriceValidation> basePriceValidate({
    required String productId,
    int quantity = 1,
  });
  Future<CustomerBasePriceLookup> customerBasePriceLookup(String customerId);
  Future<String> productPriceHistory(String productId);
  Future<List<PriceListSummary>> priceLists();
  Future<PriceListDetail> priceList(String id);
  Future<PriceListDetail> createPriceList(CreatePriceListRequest request);

  Future<ZonesRoutesSummary> zonesRoutesSummary();
  Future<List<ZoneListItem>> listZones({String? search, bool? activeOnly});
  Future<ZoneDetail> zoneDetail(String id);
  Future<ZoneDetail> createZone({
    required String name,
    required String sector,
    required String city,
    String? depotId,
    bool isActive = true,
  });
  Future<ZoneDetail> updateZone(
    String id, {
    required String name,
    required String sector,
    required String city,
    String? depotId,
    bool isActive = true,
  });
  Future<void> deactivateZone(String id);
  Future<List<RouteListItem>> listRoutes({String? zoneId, String? search});
  Future<RouteDetail> routeDetail(String id);
  Future<RouteDetail> createRoute({
    required String name,
    required String zoneId,
    String? sector,
    String? city,
    String? depotId,
  });
  Future<RouteDetail> updateRoute(
    String id, {
    required String name,
    required String zoneId,
    String? sector,
    String? city,
    String? depotId,
  });
  Future<void> deleteRoute(String id);
  Future<List<EligibleRouteRider>> eligibleRouteRiders({String? search});
  Future<RouteDetail> assignRouteRider(
    String routeId, {
    required String riderUserId,
  });
  Future<RouteDetail> unassignRouteRider(
    String routeId, {
    required String riderUserId,
  });
  Future<List<RouteCustomerRow>> routeCustomers(String routeId);
  Future<List<RouteCustomerRow>> allocateRouteCustomers(
    String routeId, {
    required List<String> customerIds,
  });
  Future<List<RouteCustomerRow>> sequenceRouteCustomers(
    String routeId, {
    required List<String> orderedCustomerIds,
  });
  Future<List<RouteStopRow>> routeStops(String routeId, {String? date});
  Future<List<RouteStopRow>> ensureRouteStops(String routeId, {String? date});
  Future<List<RouteStopRow>> sequenceRouteStops(
    String routeId, {
    required List<String> orderedStopIds,
  });
  Future<RouteMapData> routeMapPins(String routeId, {String? date});

  Future<AdminCustomersSummary> adminCustomersSummary();
  Future<AdminCustomerPage> adminCustomers({
    String? search,
    String? status,
    String? routeId,
    String? zoneId,
    String? area,
    bool? withOutstanding,
    bool? missingGps,
    int page = 1,
    int pageSize = 20,
  });
  Future<AdminCustomerDetail> adminCustomerDetail(String id);
  Future<AdminCustomerDetail> adminCreateCustomer({
    required String businessName,
    required String primaryMobile,
    String? additionalContact,
    required String category,
    required String street,
    required String area,
    required String city,
    num? latitude,
    num? longitude,
    required String routeId,
    required String bottleOwnership,
    num? openingDebt,
    int? openingEmpties,
    String? cnic,
    String? contactName,
    String? contactRole,
    String? status,
    int? creditDays,
  });
  Future<AdminCustomerDetail> adminUpdateCustomer(
    String id, {
    required String businessName,
    required String primaryMobile,
    String? additionalContact,
    required String category,
    required String street,
    required String area,
    required String city,
    num? latitude,
    num? longitude,
    required String routeId,
    required String bottleOwnership,
    num? openingDebt,
    int? openingEmpties,
    String? cnic,
    String? contactName,
    String? contactRole,
    String? status,
    int? creditDays,
  });
  Future<AdminCustomerDetail> adminChangeCustomerRoute(
    String id, {
    required String routeId,
  });
  Future<AdminCustomerDetail> adminSetCustomerStatus(
    String id, {
    required String status,
  });
  Future<LedgerData> adminCustomerLedger(String id);

  Future<DepotDetail> depotDetail();
  Future<DepotOperations> depotSummary({String? date});
  Future<List<DepotFleetMember>> depotFleet();
  Future<List<DepotStockLine>> depotStock();
  Future<DepotDetail> updateDepot({
    required String name,
    required String gate,
    required String address,
  });

  Future<AdminSalesSummary> adminSalesSummary({String? date});
  Future<ShiftDayRecord> adminShiftDay({String? date, String? riderId});
  Future<RecurringBoard> recurringSchedules({
    String? search,
    String? tab,
    String? depotId,
    String? productId,
    String? riderId,
    int page = 1,
    int pageSize = 20,
  });
  Future<RecurringScheduleDetail> recurringSchedule(String id);
  Future<RecurringScheduleDetail> createRecurringSchedule(Map<String, dynamic> body);
  Future<RecurringScheduleDetail> updateRecurringSchedule(String id, Map<String, dynamic> body);
  Future<SchedulePreview> previewRecurringSchedule(Map<String, dynamic> body);
  Future<RecurringScheduleDetail> pauseRecurringSchedule(
    String id, {
    required String reason,
    String? startDate,
    String? endDate,
  });
  Future<RecurringScheduleDetail> resumeRecurringSchedule(String id);
  Future<RecurringScheduleDetail> cancelRecurringSchedule(String id, {required String reason});
  Future<RecurringScheduleDetail> duplicateRecurringSchedule(String id);
  Future<ScheduleCalendar> recurringCalendar({required int year, required int month, String? scheduleId});
  Future<ScheduleCalendarItem> skipOccurrence(String id);
  Future<ScheduleCalendarItem> rescheduleOccurrence(String id, String date);
  Future<ScheduleCalendarItem> reassignOccurrence(String id, String riderId);
  Future<ScheduleCalendarItem> changeOccurrenceQuantity(String id, int quantity);
  Future<AdminSalePage> adminSales({
    String? date,
    String? type,
    String? syncStatus,
    String? riderId,
    String? search,
    int page = 1,
    int pageSize = 20,
  });
  Future<AdminSaleDetail> adminSaleDetail(String id);
  Future<AdminSaleDraft> adminCreateSaleDraft({
    required String riderUserId,
    required String customerId,
    String? stopId,
    required List<Map<String, dynamic>> lines,
    int? emptyBottlesReturned,
  });
  Future<ReceiptData> adminCompleteSale(
    String id, {
    required String paymentMethod,
    num? amountReceived,
    required String signerName,
    String? signerRole,
    bool closeStop = true,
    String? signatureImage,
    String? signatureNote,
  });
  Future<ReceiptData> adminSaleReceipt(String id);

  Future<AdminCollectionsSummary> adminCollectionsSummary({String? date});
  Future<AdminCollectionPage> adminCollections({
    String? date,
    String? type,
    String? riderId,
    String? search,
    int page = 1,
    int pageSize = 20,
  });
  Future<AdminCollectionDetail> adminCollectionDetail(String id);
  Future<ReceiptData> adminRecordCollection({
    required String riderUserId,
    required String customerId,
    required num amount,
    required String signerName,
    num? withholdingTax,
    String? note,
    String? idempotencyKey,
  });
  Future<List<AdminReceivableExposure>> adminReceivablesExposure();

  Future<AdminReportsSummary> adminReportsSummary({String? from, String? to});
  Future<List<AdminReportCatalogItem>> adminReportsCatalog();
  Future<AdminReportTable> adminReportRun(
    String key, {
    String? from,
    String? to,
  });
  Future<String> adminReportExportCsv(
    String key, {
    String? from,
    String? to,
  });

  Future<AdminAuditSummary> adminAuditSummary({String? date});
  Future<AdminAuditEventPage> adminAuditEvents({
    String? date,
    String? category,
    String? search,
    String? outcome,
    int page = 1,
    int pageSize = 20,
  });
  Future<AdminAuditEventDetail> adminAuditEvent(String id);
  Future<AdminAuditVerifyResult> adminAuditVerify(String id);
  Future<String> adminAuditExportCsv({
    String? date,
    String? category,
    String? search,
  });

  Future<CommunicationDashboardSummary> adminCommunicationSummary({
    String? date,
  });
  Future<CommunicationGatewayStatus> adminCommunicationGateway();
  Future<CommunicationGatewayStatus> adminCommunicationTestGateway();
  Future<List<CommunicationTemplate>> adminCommunicationTemplates();
  Future<CommunicationTemplate> adminCreateCommunicationTemplate({
    required String name,
    required String language,
    required String triggerType,
    required String content,
    String? templateCode,
  });
  Future<CommunicationTemplate> adminUpdateCommunicationTemplate(
    String id, {
    required String name,
    required String language,
    required String triggerType,
    required String content,
  });
  Future<CommunicationTemplate> adminSetCommunicationTemplateActive(
    String id, {
    required bool isActive,
  });
  Future<void> adminArchiveCommunicationTemplate(String id);
  Future<CommunicationPreview> adminCommunicationPreview({
    required String templateId,
    Map<String, String>? variables,
  });
  Future<List<CommunicationTrigger>> adminCommunicationTriggers();
  Future<CommunicationMessagePage> adminCommunicationMessages({
    String? date,
    String? status,
    String? search,
    int page = 1,
    int pageSize = 20,
  });
  Future<CommunicationMessageDetail> adminCommunicationMessage(String id);
  Future<CommunicationMessageDetail> adminEnqueueCommunicationMessage({
    String? customerId,
    required String templateId,
    required String destinationNumber,
    String? transactionReference,
    Map<String, String>? variables,
    String? idempotencyKey,
    String? riderUserId,
  });
  Future<CommunicationMessageDetail> adminRetryCommunicationMessage(String id);
  Future<String> adminCommunicationMessagesExportCsv({
    String? date,
    String? status,
  });

  Future<StaffSummary> staffSummary();
  Future<List<RoleReference>> staffRoleReference();
  Future<RoleAccessMatrix> roleAccess();
  Future<RoleAccessRow> saveRoleAccess(String role, List<String> screenKeys);
  Future<RoleAccessRow> createAccessRole({required String name, String? description});
  Future<RoleAccessRow> assignRoleMember(String role, String userId);
  Future<StaffUserPage> staffUsers({
    String? search,
    String? role,
    bool? isActive,
    int page = 1,
    int pageSize = 50,
  });
  Future<StaffUser> staffUser(String id);
  Future<StaffUser> createStaffUser({
    required String username,
    required String password,
    required String fullName,
    String? phone,
    String? riderCode,
    required String role,
    String? routeId,
    String? vehicleId,
    String? depotId,
    String? email,
    String? zoneId,
    String? warehousePersonUserId,
  });
  Future<StaffUser> updateStaffUser(
    String id, {
    required String fullName,
    String? phone,
    String? riderCode,
    String? routeId,
    String? vehicleId,
    String? depotId,
  });
  Future<StaffUser> setStaffUserStatus(String id, {required bool isActive});
  Future<void> resetStaffUserPassword(String id, {required String newPassword});

  Future<TrackingSessionInfo> startTracking();
  Future<TrackingSessionInfo> stopTracking({String? reason});
  Future<void> uploadTrackingLocations({
    String? sessionId,
    required List<Map<String, dynamic>> points,
  });
  Future<TrackingStatusInfo> trackingStatus();
  Future<ActiveAssignmentInfo> activeAssignment();
  Future<RouteComplianceStateInfo> routeComplianceCurrent();
  Future<List<RouteAnomalyInfo>> riderRouteAnomalies();
  Future<RouteAnomalyInfo> submitAnomalyExplanation({
    required String anomalyId,
    required String reason,
    required String explanationText,
    String? supportingNote,
    bool isCorrection = false,
  });
  Future<List<RiderNotificationInfo>> riderNotifications();
  Future<void> markRiderNotificationRead(String id);

  Future<LiveTrackingOverview> liveTrackingOverview();
  Future<List<LiveRiderCard>> liveTrackingRiders();
  Future<LiveRiderDetail> liveTrackingRider(String riderUserId);
  Future<List<RouteAnomalyInfo>> adminRouteAnomalies({
    String? status,
    String? riderUserId,
  });
  Future<RouteAnomalyInfo> adminRouteAnomaly(String id);
  Future<RouteAnomalyInfo> reviewRouteAnomaly({
    required String id,
    required String action,
    String? notes,
  });
  Future<RouteAnomalyInfo> queryRouteAnomaly({
    required String id,
    required String message,
  });
  Future<RouteAnomalyInfo> resolveRouteAnomaly({
    required String id,
    String? notes,
    bool markFalsePositive = false,
  });
}

class ApiScope extends InheritedWidget {
  const ApiScope({required this.api, required super.child, super.key});

  final RouteApi api;

  static RouteApi of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ApiScope>();
    assert(scope != null, 'ApiScope is missing above this widget.');
    return scope!.api;
  }

  @override
  bool updateShouldNotify(ApiScope oldWidget) => api != oldWidget.api;
}

class HttpRouteApi implements RouteApi {
  HttpRouteApi({http.Client? client, FlutterSecureStorage? storage})
    : _client = client ?? http.Client(),
      _storage = storage ?? const FlutterSecureStorage();

  final http.Client _client;
  final FlutterSecureStorage _storage;
  String? _access;
  String? _refresh;

  Future<void> restore() async {
    _access = await _storage.read(key: 'routeledger.access');
    _refresh = await _storage.read(key: 'routeledger.refresh');
  }

  @override
  Future<AuthSession> login(
    String username,
    String password, {
    bool rememberMe = false,
  }) async {
    final data = await _send(
      'POST',
      '/api/auth/login',
      body: {
        'username': username,
        'password': password,
        'rememberMe': rememberMe,
      },
      auth: false,
    );
    final session = _session(data as Map<String, dynamic>);
    await _store(session);
    return session;
  }

  @override
  Future<CustomerRegistration> registerCustomer(Map<String, dynamic> body) async {
    final decoded = await _raw(
      'POST',
      '/api/auth/register-customer',
      body: body,
      auth: false,
    );
    final data = decoded['data'];
    final map = data is Map<String, dynamic> ? data : const <String, dynamic>{};
    return CustomerRegistration(
      customerCode: map['customerCode'] as String? ?? '',
      fullName: map['fullName'] as String? ?? '',
      email: map['email'] as String? ?? '',
    );
  }

  @override
  Future<AuthSession?> currentSession() async {
    if (_access == null || _access!.isEmpty || _refresh == null || _refresh!.isEmpty) {
      return null;
    }
    try {
      final data = await _send('GET', '/api/auth/me');
      final user = data as Map<String, dynamic>;
      return AuthSession(
        accessToken: _access!,
        refreshToken: _refresh!,
        fullName: user['fullName'] as String? ?? '',
        username: user['username'] as String? ?? '',
        riderCode: user['riderCode'] as String? ?? '',
        routeName: user['routeName'] as String? ?? '',
        vehicleName: user['vehicleName'] as String? ?? '',
        vehiclePlate: user['vehiclePlate'] as String? ?? '',
        fleetCode: user['fleetCode'] as String? ?? '',
        depotGate: user['depotGate'] as String? ?? '',
        depotName: user['depotName'] as String? ?? '',
        role: user['role'] as String? ?? '',
        customerCode: user['customerCode'] as String? ?? '',
        allowedScreens: [
          for (final row in (user['allowedScreens'] is List ? user['allowedScreens'] as List : const []))
            if (row is String) row,
        ],
      );
    } on ApiException catch (error) {
      if (error.statusCode == 401) await logout();
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<CustomerHome> customerHome() async => CustomerHome.fromJson(_asMap(await _send('GET', '/api/customer/home')) ?? const {});

  @override
  Future<List<CustomerPlan>> customerSchedules() async {
    final data = await _send('GET', '/api/customer/schedules');
    if (data is! List) return const [];
    return [for (final item in data) if (item is Map) CustomerPlan.fromJson(Map<String, dynamic>.from(item))];
  }

  @override
  Future<CustomerCalendar> customerCalendar(String scheduleId, int year, int month) async {
    final data = await _send('GET', '/api/customer/schedules/$scheduleId/calendar', query: {'year': '$year', 'month': '$month'});
    return CustomerCalendar.fromJson(_asMap(data) ?? const {});
  }

  @override
  Future<List<CustomerVisit>> customerHistory({String? scheduleId, String? status, String? from, String? to}) async {
    final data = await _send('GET', '/api/customer/history', query: {
      'scheduleId': ?scheduleId,
      'status': ?status,
      'from': ?from,
      'to': ?to,
    });
    if (data is! List) return const [];
    return [for (final item in data) if (item is Map) CustomerVisit.fromJson(Map<String, dynamic>.from(item))];
  }

  @override
  Future<CustomerPayments> customerPayments() async => CustomerPayments.fromJson(_asMap(await _send('GET', '/api/customer/payments')) ?? const {});

  @override
  Future<CustomerInvoiceDetail> customerInvoice(String number) async =>
      CustomerInvoiceDetail.fromJson(_asMap(await _send('GET', '/api/customer/invoices/$number')) ?? const {});

  @override
  Future<CustomerProfile> updateCustomerProfile({required String firstName, required String lastName, required String phone}) async =>
      CustomerProfile.fromJson(_asMap(await _send('PUT', '/api/customer/profile', body: {'firstName': firstName, 'lastName': lastName, 'phone': phone})) ?? const {});

  @override
  Future<List<CustomerRequest>> customerRequests() async {
    final data = await _send('GET', '/api/customer/requests');
    if (data is! List) return const [];
    return [for (final item in data) if (item is Map) CustomerRequest.fromJson(Map<String, dynamic>.from(item))];
  }

  @override
  Future<CustomerRequest> submitCustomerRequest(Map<String, dynamic> body) async =>
      CustomerRequest.fromJson(_asMap(await _send('POST', '/api/customer/requests', body: body)) ?? const {});

  @override
  Future<CustomerRequestPreview> previewCustomerRequest(Map<String, dynamic> body) async =>
      CustomerRequestPreview.fromJson(_asMap(await _send('POST', '/api/customer/requests/preview', body: body)) ?? const {});

  @override
  Future<CustomerRequest> cancelCustomerRequest(String id) async =>
      CustomerRequest.fromJson(_asMap(await _send('POST', '/api/customer/requests/$id/cancel')) ?? const {});

  @override
  Future<CustomerRequest> replyCustomerRequest(String id, String notes) async =>
      CustomerRequest.fromJson(_asMap(await _send('POST', '/api/customer/requests/$id/reply', body: {'notes': notes})) ?? const {});

  @override
  Future<CustomerProfile> customerProfile() async => CustomerProfile.fromJson(_asMap(await _send('GET', '/api/customer/profile')) ?? const {});

  @override
  Future<CustomerAddress> saveCustomerAddress(Map<String, dynamic> body, {String? id}) async {
    final data = id == null
        ? await _send('POST', '/api/customer/addresses', body: body)
        : await _send('PUT', '/api/customer/addresses/$id', body: body);
    return CustomerAddress.fromJson(_asMap(data) ?? const {});
  }

  @override
  Future<CustomerAddress> defaultCustomerAddress(String id) async =>
      CustomerAddress.fromJson(_asMap(await _send('POST', '/api/customer/addresses/$id/default')) ?? const {});

  @override
  Future<CustomerAddress> deactivateCustomerAddress(String id) async =>
      CustomerAddress.fromJson(_asMap(await _send('POST', '/api/customer/addresses/$id/deactivate')) ?? const {});

  @override
  Future<List<CustomerNote>> customerNotifications() async {
    final data = await _send('GET', '/api/customer/notifications');
    if (data is! List) return const [];
    return [for (final item in data) if (item is Map) CustomerNote.fromJson(Map<String, dynamic>.from(item))];
  }

  @override
  Future<void> readCustomerNotification(String id) async {
    await _send('POST', '/api/customer/notifications/$id/read');
  }

  @override
  Future<void> readAllCustomerNotifications() async {
    await _send('POST', '/api/customer/notifications/read-all');
  }

  @override
  Future<CustomerAccountBoard> customerAccountBoard({String? search, String? status}) async {
    final data = await _send('GET', '/api/admin/customer-accounts', query: {
      if (search != null && search.isNotEmpty) 'search': search,
      if (status != null && status.isNotEmpty) 'status': status,
    });
    return CustomerAccountBoard.fromJson(_asMap(data) ?? const {});
  }

  @override
  Future<CustomerOpsOverview> customerOpsOverview() async =>
      CustomerOpsOverview.fromJson(_asMap(await _send('GET', '/api/admin/customer-accounts/overview')) ?? const {});

  @override
  Future<CustomerAccountDetail> customerAccountDetail(String id) async =>
      CustomerAccountDetail.fromJson(_asMap(await _send('GET', '/api/admin/customer-accounts/$id')) ?? const {});

  @override
  Future<CustomerAccountDetail> linkCustomerAccount(String id, {String? deliveryCustomerId}) async =>
      CustomerAccountDetail.fromJson(_asMap(await _send('PATCH', '/api/admin/customer-accounts/$id/link', body: {'deliveryCustomerId': deliveryCustomerId})) ?? const {});

  @override
  Future<List<CustomerAccountRow>> unlinkedCustomerAccounts() async {
    final data = await _send('GET', '/api/admin/customer-accounts/unlinked');
    if (data is! List) return const [];
    return [for (final item in data) if (item is Map) CustomerAccountRow.fromJson(Map<String, dynamic>.from(item))];
  }

  @override
  Future<List<CustomerLinkReview>> customerLinkReviews({String? status}) async {
    final data = await _send('GET', '/api/admin/customer-accounts/link-reviews', query: {if (status != null && status.isNotEmpty) 'status': status});
    if (data is! List) return const [];
    return [for (final item in data) if (item is Map) CustomerLinkReview.fromJson(Map<String, dynamic>.from(item))];
  }

  @override
  Future<CustomerLinkReview> proposeCustomerLink(String accountId, {required String email, required String customerCode}) async =>
      CustomerLinkReview.fromJson(_asMap(await _send('POST', '/api/admin/customer-accounts/$accountId/link-reviews', body: {'email': email, 'customerCode': customerCode})) ?? const {});

  @override
  Future<CustomerLinkReview> reviewCustomerLink(String reviewId, {required String action, String? comment}) async =>
      CustomerLinkReview.fromJson(_asMap(await _send('POST', '/api/admin/customer-accounts/link-reviews/$reviewId/review', body: {'action': action, 'comment': comment})) ?? const {});

  @override
  Future<PolicyDocument> policyDocument(String kind) async =>
      PolicyDocument.fromJson(_asMap(await _send('GET', '/api/policies/$kind')) ?? const {});

  @override
  Future<HqSettings> hqSettings() async => HqSettings.fromJson(_asMap(await _send('GET', '/api/admin/office/settings')) ?? const {});

  @override
  Future<HqSettings> updateHqSettings(Map<String, dynamic> body) async =>
      HqSettings.fromJson(_asMap(await _send('PUT', '/api/admin/office/settings', body: body)) ?? const {});

  @override
  Future<List<CashHandover>> cashHandovers({String? status}) async {
    final data = await _send('GET', '/api/admin/office/cash-handovers', query: {if (status != null && status.isNotEmpty) 'status': status});
    if (data is! List) return const [];
    return [for (final item in data) if (item is Map) CashHandover.fromJson(Map<String, dynamic>.from(item))];
  }

  @override
  Future<CashHandover> submitCashHandover({required String businessDate, String? depotId}) async => CashHandover.fromJson(
        _asMap(await _send('POST', '/api/cash-handovers', body: {'businessDate': businessDate, 'depotId': depotId})) ?? const {},
      );

  @override
  Future<CashHandover> confirmCashHandover(String id, {required num actualAmount, String? note}) async => CashHandover.fromJson(
        _asMap(await _send('POST', '/api/admin/office/cash-handovers/$id/receive', body: {'actualAmount': actualAmount, 'note': note})) ?? const {},
      );

  @override
  Future<OfficeDocument> invoicePdf(String number) async =>
      OfficeDocument.fromJson(_asMap(await _send('GET', '/api/customer/invoices/$number/pdf')) ?? const {});

  @override
  Future<OfficeDocument> orderPdf(String id) async =>
      OfficeDocument.fromJson(_asMap(await _send('GET', '/api/admin/office/documents/orders/$id')) ?? const {});

  @override
  Future<OfficeDocument> orderCsv(String id) async =>
      OfficeDocument.fromJson(_asMap(await _send('GET', '/api/admin/office/documents/orders/$id/export.csv')) ?? const {});

  @override
  Future<OfficeDocument> manifestPdf({required String routeId, required String date}) async => OfficeDocument.fromJson(
        _asMap(await _send('GET', '/api/admin/office/documents/manifests', query: {'routeId': routeId, 'date': date})) ?? const {},
      );

  @override
  Future<void> updatePriceList(String id, Map<String, dynamic> body) async {
    await _send('PUT', '/api/admin/office/price-lists/$id', body: body);
  }

  @override
  Future<void> duplicatePriceList(String id, {required String code, required String name}) async {
    await _send('POST', '/api/admin/office/price-lists/$id/duplicate', body: {'code': code, 'name': name});
  }

  @override
  Future<void> assignPriceList(String id, List<String> customerIds) async {
    await _send('POST', '/api/admin/office/price-lists/$id/assign', body: {'customerIds': customerIds});
  }

  @override
  Future<void> createWarehouse({required String name, required String gate, required String address}) async {
    await _send('POST', '/api/admin/office/warehouses', body: {'name': name, 'gate': gate, 'address': address});
  }

  @override
  Future<void> recordInventoryCount({required String depotId, required String productId, required int countedQuantity, String? note}) async {
    await _send('POST', '/api/admin/office/inventory-counts', body: {'depotId': depotId, 'productId': productId, 'countedQuantity': countedQuantity, 'note': note});
  }

  @override
  Future<CustomerAccountDetail> setCustomerAccountStatus(String id, String status) async =>
      CustomerAccountDetail.fromJson(_asMap(await _send('PATCH', '/api/admin/customer-accounts/$id/status', body: {'status': status})) ?? const {});

  @override
  Future<List<CustomerRequest>> customerRequestQueue({String? type, String? status, String? search, String? city}) async {
    final data = await _send('GET', '/api/admin/customer-requests', query: {
      'type': ?type,
      'status': ?status,
      if (search != null && search.isNotEmpty) 'search': search,
      if (city != null && city.isNotEmpty) 'city': city,
    });
    if (data is! List) return const [];
    return [for (final item in data) if (item is Map) CustomerRequest.fromJson(Map<String, dynamic>.from(item))];
  }

  @override
  Future<CustomerRequest> reviewCustomerRequest(String id, {required String action, String? comment}) async =>
      CustomerRequest.fromJson(_asMap(await _send('POST', '/api/admin/customer-requests/$id/review', body: {'action': action, 'comment': comment})) ?? const {});

  @override
  Future<CustomerRequestPreview> customerRequestImpact(String id) async =>
      CustomerRequestPreview.fromJson(_asMap(await _send('GET', '/api/admin/customer-requests/$id/impact')) ?? const {});

  @override
  Future<AdminLoginPreview> adminLoginPreview() async {
    final decoded = await _raw('GET', '/api/auth/login-preview', auth: false);
    return AdminLoginPreview.fromJson(decoded['data']);
  }

  @override
  Future<void> logout({bool clearLocal = false}) async {
    try {
      await _send('POST', '/api/auth/logout', body: {'refreshToken': _refresh});
    } on ApiException {
      // The local session is cleared even when the server token is already gone.
    }
    _access = null;
    _refresh = null;
    if (clearLocal) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      await _storage.deleteAll();
      return;
    }
    await _storage.delete(key: 'routeledger.access');
    await _storage.delete(key: 'routeledger.refresh');
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _send(
      'POST',
      '/api/auth/change-password',
      body: {'currentPassword': currentPassword, 'newPassword': newPassword},
    );
  }

  @override
  Future<void> forgotPassword(String username) async {
    await _send(
      'POST',
      '/api/auth/forgot-password',
      body: {'username': username},
      auth: false,
    );
  }

  @override
  Future<DashboardData> dashboard() async {
    final data = await _send('GET', '/api/dashboard') as Map<String, dynamic>;
    final rider = data['rider'] as Map<String, dynamic>;
    final performance = data['performance'] as Map<String, dynamic>;
    final route = data['route'] as Map<String, dynamic>;
    return DashboardData(
      greeting: data['greeting'] as String,
      serviceDate: data['serviceDate'] as String,
      shiftOpen: data['shiftOpen'] as bool,
      riderName: rider['fullName'] as String? ?? '',
      riderCode: rider['riderCode'] as String? ?? '',
      routeName: rider['routeName'] as String? ?? '',
      vehicleName: rider['vehicleName'] as String? ?? '',
      vehiclePlate: rider['vehiclePlate'] as String? ?? '',
      fleetCode: rider['fleetCode'] as String? ?? '',
      depotGate: rider['depotGate'] as String? ?? '',
      depotName: rider['depotName'] as String? ?? '',
      billedSales: performance['billedSales'] as num? ?? 0,
      salesCount: performance['salesCount'] as int? ?? 0,
      cashCollected: performance['cashCollected'] as num? ?? 0,
      visitedCount: performance['visitedCount'] as int? ?? 0,
      totalStops: performance['totalStops'] as int? ?? 0,
      pendingDeliveries: performance['pendingDeliveries'] as int? ?? 0,
      pendingNote: performance['pendingNote'] as String? ?? '',
      remainingStops: route['remaining'] as int? ?? 0,
      nextStopName: route['nextStopName'] as String?,
      nextDistanceMeters: route['nextDistanceMeters'] as int?,
      remainingDistanceKm: route['remainingDistanceKm'] as num? ?? 0,
      openTodoCount: data['openTodoCount'] as int? ?? 0,
      nextLatitude: (route['nextLatitude'] as num?)?.toDouble(),
      nextLongitude: (route['nextLongitude'] as num?)?.toDouble(),
      nextAddress: route['nextAddress'] as String?,
    );
  }

  @override
  Future<List<StopItem>> stops({String? search, String? filter}) async {
    final query = <String, String>{
      'page': '1',
      'pageSize': '50',
      if (search != null && search.isNotEmpty) 'search': search,
      if (filter != null && filter.isNotEmpty) 'filter': filter,
    };
    final data =
        await _send('GET', '/api/stops', query: query) as List<dynamic>;
    return data.map((item) => _stop(item as Map<String, dynamic>)).toList();
  }

  @override
  Future<List<StopItem>> sequenceTodayStops({
    required List<String> orderedStopIds,
  }) async {
    final data = await _send(
      'PUT',
      '/api/stops/sequence',
      body: {'orderedStopIds': orderedStopIds},
    );
    if (data is! List) return const [];
    return data.map((item) => _stop(item as Map<String, dynamic>)).toList();
  }

  @override
  Future<CustomerDetail> customer(String id) async {
    return _customer(
      await _send('GET', '/api/customers/$id') as Map<String, dynamic>,
    );
  }

  @override
  Future<SaleContext> saleContext(String customerId) async {
    final data = await _send(
      'GET',
      '/api/customers/$customerId/sale-context',
    ) as Map<String, dynamic>;
    final products = (data['products'] as List<dynamic>)
        .map((item) => _product(item as Map<String, dynamic>))
        .toList();
    return SaleContext(
      customer: _customer(data['customer'] as Map<String, dynamic>),
      products: products,
      emptyBottlesHeld: data['emptyBottlesHeld'] as int? ?? 0,
    );
  }

  @override
  Future<SaleDraft> createSale({
    required String customerId,
    String? stopId,
    required Map<String, int> quantities,
    int? emptyBottlesReturned,
  }) async {
    final lines = [
      for (final entry in quantities.entries)
        if (entry.value > 0) {'productId': entry.key, 'quantity': entry.value},
    ];
    final data = await _send(
      'POST',
      '/api/sales',
      body: {
        'customerId': customerId,
        'stopId': stopId,
        'lines': lines,
        'emptyBottlesReturned': ?emptyBottlesReturned,
      },
    ) as Map<String, dynamic>;
    return _draft(data);
  }

  @override
  Future<ReceiptData> completeSale({
    required String saleId,
    required String method,
    required String signerName,
    String? signerRole,
    int? amountReceived,
    bool closeStop = true,
    String? signatureImage,
    String? signatureNote,
  }) async {
    final data = await _send(
      'POST',
      '/api/sales/$saleId/complete',
      body: {
        'paymentMethod': method,
        'signerName': signerName,
        'signerRole': signerRole,
        'amountReceived': ?amountReceived,
        'closeStop': closeStop,
        'signatureImage': ?signatureImage,
        'signatureNote': ?signatureNote,
      },
    ) as Map<String, dynamic>;
    return _receipt(data);
  }

  @override
  Future<ReceiptData> receipt(String saleId) async {
    return _receipt(
      await _send('GET', '/api/sales/$saleId/receipt') as Map<String, dynamic>,
    );
  }

  @override
  Future<ReceiptData> collect({
    required String customerId,
    required num amount,
    required String channel,
    required String signerName,
    String? signerRole,
    String? signatureImage,
    String? signatureNote,
    int withholdingTax = 0,
    String? note,
  }) async {
    final data = await _send(
      'POST',
      '/api/collections',
      body: {
        'customerId': customerId,
        'amount': amount,
        'channel': channel,
        'signerName': signerName,
        'signerRole': signerRole,
        'signatureImage': ?signatureImage,
        'signatureNote': ?signatureNote,
        'withholdingTax': withholdingTax,
        'note': ?note,
      },
    ) as Map<String, dynamic>;
    return _receipt(data);
  }

  @override
  Future<void> createOrder({
    required String customerId,
    required Map<String, int> quantities,
    required String window,
    String? deliveryDate,
    String? note,
    bool showOnManifest = true,
  }) async {
    final lines = [
      for (final entry in quantities.entries)
        if (entry.value > 0) {'productId': entry.key, 'quantity': entry.value},
    ];
    await _send(
      'POST',
      '/api/orders',
      body: {
        'customerId': customerId,
        'window': window,
        'deliveryDate': ?deliveryDate,
        'note': ?note,
        'showOnManifest': showOnManifest,
        'lines': lines,
      },
    );
  }

  @override
  Future<LedgerData> ledger(String customerId) async {
    final data = await _send(
      'GET',
      '/api/customers/$customerId/ledger',
    ) as Map<String, dynamic>;
    final entries = (data['entries'] as List<dynamic>).map((item) {
      final row = item as Map<String, dynamic>;
      return LedgerRow(
        id: row['id'] as String,
        description: row['description'] as String,
        occurredAt: DateTime.parse(row['occurredAt'] as String).toLocal(),
        amount: row['amount'] as num,
        balanceAfter: row['balanceAfter'] as num,
        kind: row['kind'] as String? ?? 'Opening',
        reference: row['reference'] as String?,
        detail: row['detail'] as String?,
      );
    }).toList();
    final movements = (data['movements'] as List<dynamic>? ?? const []).map((
      item,
    ) {
      final row = item as Map<String, dynamic>;
      return BottleMovement(
        occurredAt: DateTime.parse(row['occurredAt'] as String).toLocal(),
        fullGiven: row['fullGiven'] as int? ?? 0,
        emptiesReturned: row['emptiesReturned'] as int? ?? 0,
        holdingAfter: row['holdingAfter'] as int? ?? 0,
        note: row['note'] as String? ?? '',
      );
    }).toList();
    return LedgerData(
      customerId: data['customerId'] as String,
      customerName: data['customerName'] as String,
      customerCode: data['customerCode'] as String,
      outstanding: data['outstanding'] as num,
      creditDays: data['creditDays'] as int,
      bottlesIssued: data['bottlesIssued'] as int,
      bottlesReturned: data['bottlesReturned'] as int,
      bottlesHeld: data['bottlesHeld'] as int,
      entries: entries,
      openOrders: data['openOrders'] as int? ?? 0,
      todayCollected: data['todayCollected'] as num? ?? 0,
      stopSequence: data['stopSequence'] as int?,
      movements: movements,
    );
  }

  @override
  Future<ShiftData> currentShift() async =>
      _shift(await _send('GET', '/api/shifts/current') as Map<String, dynamic>);

  @override
  Future<ShiftData> startShift(
    List<Map<String, dynamic>> stock, {
    required int openingOdometer,
    String? odometerPhoto,
    String? inspectionPhoto,
  }) async {
    return _shift(
      await _send(
        'POST',
        '/api/shifts/start',
        body: {
          'openingOdometer': openingOdometer,
          'odometerPhoto': odometerPhoto,
          'inspectionPhoto': ?inspectionPhoto,
          'stock': stock,
        },
      ) as Map<String, dynamic>,
    );
  }

  @override
  Future<ShiftData> endShift({
    required int closingOdometer,
    String? odometerPhoto,
    String? inspectionPhoto,
    List<Map<String, dynamic>> stock = const [],
  }) async => _shift(
    await _send(
      'POST',
      '/api/shifts/end',
      body: {
        'closingOdometer': closingOdometer,
        'odometerPhoto': odometerPhoto,
        'inspectionPhoto': ?inspectionPhoto,
        'stock': stock,
      },
    ) as Map<String, dynamic>,
  );

  @override
  Future<ShiftDayRecord> adminShiftDay({String? date, String? riderId}) async {
    final decoded = await _raw(
      'GET',
      '/api/admin/shifts',
      query: _clean({'date': date, 'riderId': riderId}),
    );
    final data = decoded['data'];
    if (data is! Map) {
      return ShiftDayRecord(
        serviceDate: date ?? '',
        riders: const [],
        selected: null,
        odometer: const [],
      );
    }
    return ShiftDayRecord.fromJson(Map<String, dynamic>.from(data));
  }

  RecurringBoard _board(Map<String, dynamic> decoded) {
    final data = decoded['data'];
    if (data is! Map) return RecurringBoard.empty;
    return RecurringBoard.fromJson(Map<String, dynamic>.from(data));
  }

  RecurringScheduleDetail _scheduleDetail(Map<String, dynamic> decoded) {
    return RecurringScheduleDetail.fromJson(Map<String, dynamic>.from(decoded['data'] as Map));
  }

  @override
  Future<RecurringBoard> recurringSchedules({
    String? search,
    String? tab,
    String? depotId,
    String? productId,
    String? riderId,
    int page = 1,
    int pageSize = 20,
  }) async {
    return _board(await _raw(
      'GET',
      '/api/admin/recurring-schedules',
      query: _clean({
        'search': search,
        'tab': tab,
        'depotId': depotId,
        'productId': productId,
        'riderId': riderId,
        'page': '$page',
        'pageSize': '$pageSize',
      }),
    ));
  }

  @override
  Future<RecurringScheduleDetail> recurringSchedule(String id) async {
    return _scheduleDetail(await _raw('GET', '/api/admin/recurring-schedules/$id'));
  }

  @override
  Future<RecurringScheduleDetail> createRecurringSchedule(Map<String, dynamic> body) async {
    return _scheduleDetail(await _raw('POST', '/api/admin/recurring-schedules', body: body));
  }

  @override
  Future<RecurringScheduleDetail> updateRecurringSchedule(String id, Map<String, dynamic> body) async {
    return _scheduleDetail(await _raw('PUT', '/api/admin/recurring-schedules/$id', body: body));
  }

  @override
  Future<SchedulePreview> previewRecurringSchedule(Map<String, dynamic> body) async {
    final decoded = await _raw('POST', '/api/admin/recurring-schedules/preview', body: body);
    return SchedulePreview.fromJson(Map<String, dynamic>.from(decoded['data'] as Map));
  }

  @override
  Future<RecurringScheduleDetail> pauseRecurringSchedule(
    String id, {
    required String reason,
    String? startDate,
    String? endDate,
  }) async {
    return _scheduleDetail(await _raw(
      'PATCH',
      '/api/admin/recurring-schedules/$id/pause',
      body: {
        'mode': startDate == null ? 'schedule' : 'range',
        'reason': reason,
        'startDate': startDate,
        'endDate': endDate,
      },
    ));
  }

  @override
  Future<RecurringScheduleDetail> resumeRecurringSchedule(String id) async {
    return _scheduleDetail(await _raw('PATCH', '/api/admin/recurring-schedules/$id/resume'));
  }

  @override
  Future<RecurringScheduleDetail> cancelRecurringSchedule(String id, {required String reason}) async {
    return _scheduleDetail(await _raw(
      'PATCH',
      '/api/admin/recurring-schedules/$id/cancel',
      body: {'reason': reason},
    ));
  }

  @override
  Future<RecurringScheduleDetail> duplicateRecurringSchedule(String id) async {
    return _scheduleDetail(await _raw('POST', '/api/admin/recurring-schedules/$id/duplicate'));
  }

  @override
  Future<ScheduleCalendar> recurringCalendar({required int year, required int month, String? scheduleId}) async {
    final decoded = await _raw(
      'GET',
      '/api/admin/recurring-schedules/calendar',
      query: _clean({'year': '$year', 'month': '$month', 'scheduleId': scheduleId}),
    );
    return ScheduleCalendar.fromJson(Map<String, dynamic>.from(decoded['data'] as Map));
  }

  @override
  Future<ScheduleCalendarItem> skipOccurrence(String id) async {
    final decoded = await _raw('PATCH', '/api/admin/delivery-occurrences/$id/skip');
    return ScheduleCalendarItem.fromJson(Map<String, dynamic>.from(decoded['data'] as Map));
  }

  @override
  Future<ScheduleCalendarItem> rescheduleOccurrence(String id, String date) async {
    final decoded = await _raw('PATCH', '/api/admin/delivery-occurrences/$id/reschedule', body: {'date': date});
    return ScheduleCalendarItem.fromJson(Map<String, dynamic>.from(decoded['data'] as Map));
  }

  @override
  Future<ScheduleCalendarItem> reassignOccurrence(String id, String riderId) async {
    final decoded = await _raw('PATCH', '/api/admin/delivery-occurrences/$id/reassign-rider', body: {'riderId': riderId});
    return ScheduleCalendarItem.fromJson(Map<String, dynamic>.from(decoded['data'] as Map));
  }

  @override
  Future<ScheduleCalendarItem> changeOccurrenceQuantity(String id, int quantity) async {
    final decoded = await _raw('PATCH', '/api/admin/delivery-occurrences/$id/quantity', body: {'quantity': quantity});
    return ScheduleCalendarItem.fromJson(Map<String, dynamic>.from(decoded['data'] as Map));
  }

  @override
  Future<HistoryData> history({String? search, String? date}) async {
    final data = await _send(
      'GET',
      '/api/history',
      query: {
        if (search != null && search.isNotEmpty) 'search': search,
        if (date != null && date.isNotEmpty) 'date': date,
      },
    ) as Map<String, dynamic>;
    final items = (data['items'] as List<dynamic>).map((item) {
      final row = item as Map<String, dynamic>;
      return HistoryItem(
        id: row['id'] as String,
        title: row['title'] as String,
        reference: row['reference'] as String,
        occurredAt: DateTime.parse(row['occurredAt'] as String).toLocal(),
        amount: row['amount'] as num?,
        syncStatus: row['syncStatus'] as String,
        detail: row['detail'] as String? ?? '',
        customerCode: row['customerCode'] as String?,
      );
    }).toList();
    return HistoryData(
      synced: data['synced'] as int,
      pending: data['pending'] as int,
      failed: data['failed'] as int,
      items: items,
      riderUserId: data['riderUserId'] as String? ?? '',
      riderName: data['riderName'] as String? ?? '',
      riderCode: data['riderCode'] as String? ?? '',
    );
  }

  @override
  Future<SettingsData> settings() async =>
      _settings(await _send('GET', '/api/settings') as Map<String, dynamic>);

  @override
  Future<SettingsData> updateSettings(SettingsData value) async {
    return _settings(
      await _send(
        'PUT',
        '/api/settings',
        body: {
          'autoSync': value.autoSync,
          'showOrdersTab': value.showOrdersTab,
          'language': value.language,
          'autoPrint': value.autoPrint,
          'deleteOnLogout': value.deleteOnLogout,
          'paperSize': value.paperSize,
          'printerId': value.printerId,
        },
      ) as Map<String, dynamic>,
    );
  }

  @override
  Future<List<PrinterItem>> printers() async {
    final data = await _send('GET', '/api/printers') as List<dynamic>;
    return data.map((item) {
      final row = item as Map<String, dynamic>;
      return PrinterItem(
        id: row['id'] as String,
        name: row['name'] as String,
        meta: row['meta'] as String,
        isOnline: row['isOnline'] as bool,
        selected: row['selected'] as bool,
      );
    }).toList();
  }

  @override
  Future<String> printReceipt(String saleId) async {
    final response = await _raw('POST', '/api/receipts/$saleId/print');
    return response['message'] as String? ?? 'Print job queued.';
  }

  @override
  Future<CustomerDetail> saveCustomer(CustomerDraft draft) async {
    final body = {
      'businessName': draft.businessName,
      'primaryMobile': draft.primaryMobile,
      'additionalContact': draft.additionalContact,
      'category': draft.category,
      'street': draft.street,
      'area': draft.area,
      'city': draft.city,
      'latitude': draft.latitude,
      'longitude': draft.longitude,
      'bottleOwnership': draft.bottleOwnership,
      'openingDebt': draft.openingDebt,
      'openingEmpties': draft.openingEmpties,
      'cnic': draft.cnic,
      'contactName': draft.contactName,
      'contactRole': draft.contactRole,
    };
    final path = draft.id == null
        ? '/api/customers'
        : '/api/customers/${draft.id}';
    final data = await _send(
      draft.id == null ? 'POST' : 'PUT',
      path,
      body: body,
    ) as Map<String, dynamic>;
    return _customer(data);
  }

  @override
  Future<void> logVisit(String customerId, String outcome) async {
    await _send(
      'POST',
      '/api/customers/$customerId/visit',
      body: {'outcome': outcome},
    );
  }

  Map<String, String> _clean(Map<String, String?> query) {
    return {
      for (final entry in query.entries)
        if (entry.value != null && entry.value!.trim().isNotEmpty)
          entry.key: entry.value!.trim(),
    };
  }

  Map<String, String> _range(String from, String to) => {
    'from': from,
    'to': to,
  };

  @override
  Future<CommandOverview> commandOverview({
    required String from,
    required String to,
  }) async {
    return CommandOverview.fromJson(
      await _send('GET', '/api/dashboard/overview', query: _range(from, to)),
    );
  }

  @override
  Future<DashboardKpiSet> commandKpis({
    required String from,
    required String to,
  }) async {
    return DashboardKpiSet.fromJson(
      await _send('GET', '/api/dashboard/kpis', query: _range(from, to)),
    );
  }

  @override
  Future<OperationalSummary> operationalSummary({
    required String from,
    required String to,
  }) async {
    return OperationalSummary.fromJson(
      await _send(
        'GET',
        '/api/dashboard/operational-summary',
        query: _range(from, to),
      ),
    );
  }

  @override
  Future<List<AttentionItem>> attentionItems({
    required String from,
    required String to,
  }) async {
    return AttentionItem.listFromJson(
      await _send(
        'GET',
        '/api/dashboard/attention-items',
        query: _range(from, to),
      ),
    );
  }

  @override
  Future<SalesSummary> salesSummary({
    required String from,
    required String to,
    required String bucket,
  }) async {
    return SalesSummary.fromJson(
      await _send(
        'GET',
        '/api/dashboard/sales-summary',
        query: {..._range(from, to), 'bucket': bucket},
      ),
    );
  }

  @override
  Future<CollectionsSummary> collectionsSummary({
    required String from,
    required String to,
  }) async {
    return CollectionsSummary.fromJson(
      await _send(
        'GET',
        '/api/dashboard/collections-summary',
        query: _range(from, to),
      ),
    );
  }

  @override
  Future<ActivityLedgerPage> activityLedger({
    required String from,
    required String to,
    String? search,
    String? status,
    int page = 1,
    int pageSize = 8,
  }) async {
    final decoded = await _raw(
      'GET',
      '/api/dashboard/activity-ledger',
      query: _clean({
        'from': from,
        'to': to,
        'search': search,
        'status': status,
        'page': '$page',
        'pageSize': '$pageSize',
      }),
    );
    return ActivityLedgerPage.fromParts(
      decoded['data'],
      decoded['pagination'],
      page: page,
      pageSize: pageSize,
    );
  }

  @override
  Future<AdminOrderResult> createDashboardOrder(
    AdminOrderRequest request,
  ) async {
    final decoded = await _raw(
      'POST',
      '/api/dashboard/orders',
      body: request.toJson(),
    );
    return AdminOrderResult.fromJson(
      decoded['data'],
      message: decoded['message'] as String?,
    );
  }

  @override
  Future<RiderOperationsSummary> riderOperationsSummary({
    required String date,
  }) async {
    return RiderOperationsSummary.fromJson(
      await _send(
        'GET',
        '/api/rider-operations/summary',
        query: {'date': date},
      ),
    );
  }

  @override
  Future<List<RiderRecord>> riderOperationsRiders({
    String? search,
    String? status,
    required String date,
  }) async {
    final data = await _send(
      'GET',
      '/api/rider-operations/riders',
      query: _clean({
        'date': date,
        'search': search,
        'status': status == null || status == 'all' ? null : status,
      }),
    );
    return RiderRecord.listFromJson(data);
  }

  @override
  Future<RiderRecord> riderOperationsRider(
    String id, {
    required String date,
  }) async {
    final data = await _send(
      'GET',
      '/api/rider-operations/riders/$id',
      query: {'date': date},
    );
    return RiderRecord.fromJson(_asMap(data) ?? const {});
  }

  @override
  Future<List<RiderActivityItem>> riderOperationsActivity(String id) async {
    return RiderActivityItem.listFromJson(
      await _send('GET', '/api/rider-operations/riders/$id/activity'),
    );
  }

  @override
  Future<List<RiderAssignment>> riderOperationsAssignments(
    String id, {
    required String date,
  }) async {
    return RiderAssignment.listFromJson(
      await _send(
        'GET',
        '/api/rider-operations/riders/$id/assignments',
        query: {'date': date},
      ),
    );
  }

  @override
  Future<List<RiderExceptionItem>> riderOperationsExceptions({
    required String date,
  }) async {
    return RiderExceptionItem.listFromJson(
      await _send(
        'GET',
        '/api/rider-operations/exceptions',
        query: {'date': date},
      ),
    );
  }

  @override
  Future<List<LocationVerification>>
  riderOperationsLocationVerifications() async {
    return LocationVerification.listFromJson(
      await _send('GET', '/api/rider-operations/location-verifications'),
    );
  }

  @override
  Future<DispatchOrderSummary> dispatchOrdersSummary({
    String? from,
    String? to,
  }) async {
    return DispatchOrderSummary.fromJson(
      await _send(
        'GET',
        '/api/dispatch/orders/summary',
        query: _clean({'from': from, 'to': to}),
      ),
    );
  }

  @override
  Future<DispatchStatusCounts> dispatchStatusCounts({
    String? from,
    String? to,
    String? search,
  }) async {
    return DispatchStatusCounts.fromJson(
      await _send(
        'GET',
        '/api/dispatch/orders/status-counts',
        query: _clean({'from': from, 'to': to, 'search': search}),
      ),
    );
  }

  @override
  Future<DispatchOrderPage> dispatchOrders({
    int page = 1,
    int pageSize = 10,
    String? search,
    String? status,
    String? from,
    String? to,
    String? riderId,
    bool unassignedOnly = false,
  }) async {
    final decoded = await _raw(
      'GET',
      '/api/dispatch/orders',
      query: _clean({
        'page': '$page',
        'pageSize': '$pageSize',
        'search': search,
        'status': status == null || status == 'all' ? null : status,
        'from': from,
        'to': to,
        'riderId': riderId,
        'unassignedOnly': unassignedOnly ? 'true' : null,
      }),
    );
    return DispatchOrderPage.fromParts(
      decoded['data'],
      decoded['pagination'],
      page: page,
      pageSize: pageSize,
    );
  }

  @override
  Future<DispatchOrderDetail> dispatchOrder(String id) async {
    final data = await _send('GET', '/api/dispatch/orders/$id');
    return DispatchOrderDetail.fromJson(_asMap(data) ?? const {});
  }

  @override
  Future<List<DispatchOrderItem>> dispatchOrderItems(String id) async {
    return DispatchOrderItem.listFromJson(
      await _send('GET', '/api/dispatch/orders/$id/items'),
    );
  }

  @override
  Future<List<DispatchLifecycleEvent>> dispatchOrderLifecycle(String id) async {
    return DispatchLifecycleEvent.listFromJson(
      await _send('GET', '/api/dispatch/orders/$id/lifecycle'),
    );
  }

  @override
  Future<DispatchPickList> dispatchOrderPickList(String id) async {
    return DispatchPickList.fromJson(
      await _send('GET', '/api/dispatch/orders/$id/picklist'),
    );
  }

  @override
  Future<List<EligibleRider>> dispatchEligibleRiders({
    String? orderId,
    String? search,
  }) async {
    return EligibleRider.listFromJson(
      await _send(
        'GET',
        '/api/dispatch/eligible-riders',
        query: _clean({'orderId': orderId, 'search': search}),
      ),
    );
  }

  @override
  Future<DispatchOperationalSummary> dispatchOperationalSummary({
    String? from,
    String? to,
  }) async {
    return DispatchOperationalSummary.fromJson(
      await _send(
        'GET',
        '/api/dispatch/operational-summary',
        query: _clean({'from': from, 'to': to}),
      ),
    );
  }

  @override
  Future<DispatchActionResult> dispatchAssignRider(
    String id, {
    required String riderId,
  }) {
    return _dispatchAction(id, 'assign-rider', {'riderId': riderId});
  }

  @override
  Future<DispatchActionResult> dispatchReassignRider(
    String id, {
    required String riderId,
  }) {
    return _dispatchAction(id, 'reassign-rider', {'riderId': riderId});
  }

  @override
  Future<DispatchActionResult> dispatchCancelOrder(
    String id, {
    required String reason,
  }) {
    return _dispatchAction(id, 'cancel', {'reason': reason});
  }

  @override
  Future<DispatchPickList> dispatchPreparePickList(String id) async {
    final decoded = await _raw(
      'POST',
      '/api/dispatch/orders/$id/prepare-picklist',
      body: const <String, dynamic>{},
    );
    return DispatchPickList.fromJson(
      decoded['data'],
      message: decoded['message'] as String?,
    );
  }

  @override
  Future<DayCloseSummary> dayCloseSummary({String? date}) async {
    final decoded = await _raw(
      'GET',
      '/api/settlements/day-close/summary',
      query: _clean({'date': date}),
    );
    return DayCloseSummary.fromJson(decoded['data']);
  }

  @override
  Future<SettlementStatusCounts> settlementStatusCounts({
    String? date,
    String? search,
  }) async {
    final decoded = await _raw(
      'GET',
      '/api/settlements/sessions/status-counts',
      query: _clean({'date': date, 'search': search}),
    );
    return SettlementStatusCounts.fromJson(decoded['data']);
  }

  @override
  Future<SettlementSessionPage> settlementSessions({
    String? date,
    String? status,
    String? search,
    int page = 1,
    int pageSize = 20,
  }) async {
    final decoded = await _raw(
      'GET',
      '/api/settlements/sessions',
      query: _clean({
        'date': date,
        'status': status,
        'search': search,
        'page': '$page',
        'pageSize': '$pageSize',
      }),
    );
    final rows = [
      for (final row in jsonRows(decoded['data']))
        SettlementSessionRow.fromJson(row),
    ];
    final pagination = decoded['pagination'];
    final pageMap = pagination is Map ? Map<String, dynamic>.from(pagination) : const <String, dynamic>{};
    return SettlementSessionPage(
      rows: rows,
      page: optionalInt(pageMap, const ['page']) ?? page,
      pageSize: optionalInt(pageMap, const ['pageSize']) ?? pageSize,
      totalRecords: optionalInt(pageMap, const ['totalRecords']) ?? rows.length,
      totalPages: optionalInt(pageMap, const ['totalPages']) ?? 1,
    );
  }

  @override
  Future<SettlementSessionDetail> settlementSession(String id) async {
    final decoded = await _raw('GET', '/api/settlements/sessions/$id');
    return SettlementSessionDetail.fromJson(decoded['data']);
  }

  @override
  Future<SettlementSessionDetail> settlementSaveDraft(
    String id, {
    num? cashierVerifiedCash,
    String? resolutionCategory,
    String? remarks,
    String? riderAnnotation,
  }) async {
    final decoded = await _raw(
      'POST',
      '/api/settlements/sessions/$id/save-draft',
      body: {
        'cashierVerifiedCash': cashierVerifiedCash,
        'resolutionCategory': resolutionCategory,
        'remarks': remarks,
        'riderAnnotation': riderAnnotation,
      },
    );
    return SettlementSessionDetail.fromJson(decoded['data']);
  }

  @override
  Future<SettlementSessionDetail> settlementVerifyCash(
    String id, {
    required num verifiedAmount,
    String? batchReference,
    String? notes,
  }) async {
    final decoded = await _raw(
      'POST',
      '/api/settlements/sessions/$id/verify-cash',
      body: {
        'verifiedAmount': verifiedAmount,
        'batchReference': batchReference,
        'notes': notes,
      },
    );
    return SettlementSessionDetail.fromJson(decoded['data']);
  }

  @override
  Future<SettlementSessionDetail> settlementResolve(
    String id, {
    num? cashierVerifiedCash,
    String? resolutionCategory,
    String? remarks,
  }) async {
    final decoded = await _raw(
      'POST',
      '/api/settlements/sessions/$id/resolve',
      body: {
        'cashierVerifiedCash': cashierVerifiedCash,
        'resolutionCategory': resolutionCategory,
        'remarks': remarks,
      },
    );
    return SettlementSessionDetail.fromJson(decoded['data']);
  }

  @override
  Future<DayLockReadiness> settlementLockReadiness(String date) async {
    final decoded = await _raw('GET', '/api/settlements/days/$date/lock-readiness');
    return DayLockReadiness.fromJson(decoded['data']);
  }

  @override
  Future<DayLockResult> settlementLockDay(String date, {String? note}) async {
    final decoded = await _raw(
      'POST',
      '/api/settlements/days/$date/lock',
      body: {'acknowledgementNote': note},
    );
    return DayLockResult.fromJson(
      decoded['data'],
      message: decoded['message'] as String?,
    );
  }

  @override
  Future<PricingCoverage> pricingCoverage() async {
    final decoded = await _raw('GET', '/api/products/pricing/coverage');
    return PricingCoverage.fromJson(decoded['data']);
  }

  @override
  Future<List<ProductCategoryGroup>> productCategories() async {
    final decoded = await _raw('GET', '/api/products/categories');
    return [
      for (final row in jsonRows(decoded['data']))
        ProductCategoryGroup.fromJson(row),
    ];
  }

  @override
  Future<ProductCataloguePage> productCatalogue({
    String? categoryKey,
    String? search,
    String? status,
    int page = 1,
    int pageSize = 20,
  }) async {
    final decoded = await _raw(
      'GET',
      '/api/products/catalogue',
      query: _clean({
        'categoryKey': categoryKey,
        'search': search,
        'status': status,
        'page': '$page',
        'pageSize': '$pageSize',
      }),
    );
    final rows = [
      for (final row in jsonRows(decoded['data']))
        ProductBasePriceRow.fromJson(row),
    ];
    final pagination = decoded['pagination'];
    final pageMap = pagination is Map ? Map<String, dynamic>.from(pagination) : const <String, dynamic>{};
    return ProductCataloguePage(
      rows: rows,
      page: optionalInt(pageMap, const ['page']) ?? page,
      pageSize: optionalInt(pageMap, const ['pageSize']) ?? pageSize,
      totalRecords: optionalInt(pageMap, const ['totalRecords']) ?? rows.length,
      totalPages: optionalInt(pageMap, const ['totalPages']) ?? 1,
    );
  }

  @override
  Future<BasePriceValidation> basePriceValidate({
    required String productId,
    int quantity = 1,
  }) async {
    final decoded = await _raw(
      'GET',
      '/api/products/pricing/validate',
      query: _clean({'productId': productId, 'quantity': '$quantity'}),
    );
    return BasePriceValidation.fromJson(decoded['data']);
  }

  @override
  Future<CustomerBasePriceLookup> customerBasePriceLookup(String customerId) async {
    final decoded = await _raw(
      'GET',
      '/api/customers/$customerId/base-price-lookup',
    );
    return CustomerBasePriceLookup.fromJson(decoded['data']);
  }

  @override
  Future<String> productPriceHistory(String productId) async {
    final decoded = await _raw('GET', '/api/products/$productId/price-history');
    final message = (decoded['message'] as String?)?.trim();
    if (message != null && message.isNotEmpty) return message;
    return 'No base-price change history is stored.';
  }

  @override
  Future<List<PriceListSummary>> priceLists() async {
    final decoded = await _raw('GET', '/api/products/price-lists');
    return [
      for (final row in jsonRows(decoded['data']))
        PriceListSummary.fromJson(row),
    ];
  }

  @override
  Future<PriceListDetail> priceList(String id) async {
    final decoded = await _raw('GET', '/api/products/price-lists/$id');
    return PriceListDetail.fromJson(
      Map<String, dynamic>.from(decoded['data'] as Map),
    );
  }

  @override
  Future<PriceListDetail> createPriceList(CreatePriceListRequest request) async {
    final decoded = await _raw(
      'POST',
      '/api/products/price-lists',
      body: request.toJson(),
    );
    return PriceListDetail.fromJson(
      Map<String, dynamic>.from(decoded['data'] as Map),
    );
  }

  @override
  Future<ZonesRoutesSummary> zonesRoutesSummary() async {
    final decoded = await _raw('GET', '/api/zones/summary');
    return ZonesRoutesSummary.fromJson(decoded['data']);
  }

  @override
  Future<List<ZoneListItem>> listZones({String? search, bool? activeOnly}) async {
    final decoded = await _raw(
      'GET',
      '/api/zones',
      query: _clean({
        'search': search,
        'activeOnly': activeOnly?.toString(),
      }),
    );
    return [
      for (final row in jsonRows(decoded['data'])) ZoneListItem.fromJson(row),
    ];
  }

  @override
  Future<ZoneDetail> zoneDetail(String id) async {
    final decoded = await _raw('GET', '/api/zones/$id');
    return ZoneDetail.fromJson(decoded['data']);
  }

  @override
  Future<ZoneDetail> createZone({
    required String name,
    required String sector,
    required String city,
    String? depotId,
    bool isActive = true,
  }) async {
    final decoded = await _raw(
      'POST',
      '/api/zones',
      body: {
        'name': name,
        'sector': sector,
        'city': city,
        'depotId': depotId,
        'isActive': isActive,
      },
    );
    return ZoneDetail.fromJson(decoded['data']);
  }

  @override
  Future<ZoneDetail> updateZone(
    String id, {
    required String name,
    required String sector,
    required String city,
    String? depotId,
    bool isActive = true,
  }) async {
    final decoded = await _raw(
      'PUT',
      '/api/zones/$id',
      body: {
        'name': name,
        'sector': sector,
        'city': city,
        'depotId': depotId,
        'isActive': isActive,
      },
    );
    return ZoneDetail.fromJson(decoded['data']);
  }

  @override
  Future<void> deactivateZone(String id) async {
    await _raw('DELETE', '/api/zones/$id');
  }

  @override
  Future<List<RouteListItem>> listRoutes({String? zoneId, String? search}) async {
    final decoded = await _raw(
      'GET',
      '/api/routes',
      query: _clean({'zoneId': zoneId, 'search': search}),
    );
    return [
      for (final row in jsonRows(decoded['data'])) RouteListItem.fromJson(row),
    ];
  }

  @override
  Future<RouteDetail> routeDetail(String id) async {
    final decoded = await _raw('GET', '/api/routes/$id');
    return RouteDetail.fromJson(decoded['data']);
  }

  @override
  Future<RouteDetail> createRoute({
    required String name,
    required String zoneId,
    String? sector,
    String? city,
    String? depotId,
  }) async {
    final decoded = await _raw(
      'POST',
      '/api/routes',
      body: {
        'name': name,
        'zoneId': zoneId,
        'sector': sector,
        'city': city,
        'depotId': depotId,
      },
    );
    return RouteDetail.fromJson(decoded['data']);
  }

  @override
  Future<RouteDetail> updateRoute(
    String id, {
    required String name,
    required String zoneId,
    String? sector,
    String? city,
    String? depotId,
  }) async {
    final decoded = await _raw(
      'PUT',
      '/api/routes/$id',
      body: {
        'name': name,
        'zoneId': zoneId,
        'sector': sector,
        'city': city,
        'depotId': depotId,
      },
    );
    return RouteDetail.fromJson(decoded['data']);
  }

  @override
  Future<void> deleteRoute(String id) async {
    await _raw('DELETE', '/api/routes/$id');
  }

  @override
  Future<List<EligibleRouteRider>> eligibleRouteRiders({String? search}) async {
    final decoded = await _raw(
      'GET',
      '/api/routes/eligible-riders',
      query: _clean({'search': search}),
    );
    return [
      for (final row in jsonRows(decoded['data']))
        EligibleRouteRider.fromJson(row),
    ];
  }

  @override
  Future<RouteDetail> assignRouteRider(
    String routeId, {
    required String riderUserId,
  }) async {
    final decoded = await _raw(
      'POST',
      '/api/routes/$routeId/assign-rider',
      body: {'riderUserId': riderUserId},
    );
    return RouteDetail.fromJson(decoded['data']);
  }

  @override
  Future<RouteDetail> unassignRouteRider(
    String routeId, {
    required String riderUserId,
  }) async {
    final decoded = await _raw(
      'POST',
      '/api/routes/$routeId/unassign-rider',
      body: {'riderUserId': riderUserId},
    );
    return RouteDetail.fromJson(decoded['data']);
  }

  @override
  Future<List<RouteCustomerRow>> routeCustomers(String routeId) async {
    final decoded = await _raw('GET', '/api/routes/$routeId/customers');
    return [
      for (final row in jsonRows(decoded['data']))
        RouteCustomerRow.fromJson(row),
    ];
  }

  @override
  Future<List<RouteCustomerRow>> allocateRouteCustomers(
    String routeId, {
    required List<String> customerIds,
  }) async {
    final decoded = await _raw(
      'PUT',
      '/api/routes/$routeId/customers/allocate',
      body: {'customerIds': customerIds},
    );
    return [
      for (final row in jsonRows(decoded['data']))
        RouteCustomerRow.fromJson(row),
    ];
  }

  @override
  Future<List<RouteCustomerRow>> sequenceRouteCustomers(
    String routeId, {
    required List<String> orderedCustomerIds,
  }) async {
    final decoded = await _raw(
      'PUT',
      '/api/routes/$routeId/customers/sequence',
      body: {'orderedCustomerIds': orderedCustomerIds},
    );
    return [
      for (final row in jsonRows(decoded['data']))
        RouteCustomerRow.fromJson(row),
    ];
  }

  @override
  Future<List<RouteStopRow>> routeStops(String routeId, {String? date}) async {
    final decoded = await _raw(
      'GET',
      '/api/routes/$routeId/stops',
      query: _clean({'date': date}),
    );
    return [
      for (final row in jsonRows(decoded['data'])) RouteStopRow.fromJson(row),
    ];
  }

  @override
  Future<List<RouteStopRow>> ensureRouteStops(
    String routeId, {
    String? date,
  }) async {
    final decoded = await _raw(
      'POST',
      '/api/routes/$routeId/stops/ensure',
      body: {'serviceDate': date},
    );
    return [
      for (final row in jsonRows(decoded['data'])) RouteStopRow.fromJson(row),
    ];
  }

  @override
  Future<List<RouteStopRow>> sequenceRouteStops(
    String routeId, {
    required List<String> orderedStopIds,
  }) async {
    final decoded = await _raw(
      'PUT',
      '/api/routes/$routeId/stops/sequence',
      body: {'orderedStopIds': orderedStopIds},
    );
    return [
      for (final row in jsonRows(decoded['data'])) RouteStopRow.fromJson(row),
    ];
  }

  @override
  Future<RouteMapData> routeMapPins(String routeId, {String? date}) async {
    final decoded = await _raw(
      'GET',
      '/api/routes/$routeId/map-pins',
      query: _clean({'date': date}),
    );
    return RouteMapData.fromJson(decoded['data']);
  }

  @override
  Future<AdminCustomersSummary> adminCustomersSummary() async {
    final decoded = await _raw('GET', '/api/admin/customers/summary');
    return AdminCustomersSummary.fromJson(decoded['data']);
  }

  @override
  Future<AdminCustomerPage> adminCustomers({
    String? search,
    String? status,
    String? routeId,
    String? zoneId,
    String? area,
    bool? withOutstanding,
    bool? missingGps,
    int page = 1,
    int pageSize = 20,
  }) async {
    final decoded = await _raw(
      'GET',
      '/api/admin/customers',
      query: _clean({
        'search': search,
        'status': status,
        'routeId': routeId,
        'zoneId': zoneId,
        'area': area,
        'withOutstanding': withOutstanding?.toString(),
        'missingGps': missingGps?.toString(),
        'page': '$page',
        'pageSize': '$pageSize',
      }),
    );
    final rows = [
      for (final row in jsonRows(decoded['data'])) AdminCustomerRow.fromJson(row),
    ];
    final pagination = decoded['pagination'];
    final pageMap = pagination is Map
        ? Map<String, dynamic>.from(pagination)
        : const <String, dynamic>{};
    return AdminCustomerPage(
      rows: rows,
      page: optionalInt(pageMap, const ['page']) ?? page,
      pageSize: optionalInt(pageMap, const ['pageSize']) ?? pageSize,
      totalRecords: optionalInt(pageMap, const ['totalRecords']) ?? rows.length,
      totalPages: optionalInt(pageMap, const ['totalPages']) ?? 1,
    );
  }

  @override
  Future<AdminCustomerDetail> adminCustomerDetail(String id) async {
    final decoded = await _raw('GET', '/api/admin/customers/$id');
    return AdminCustomerDetail.fromJson(decoded['data']);
  }

  @override
  Future<AdminCustomerDetail> adminCreateCustomer({
    required String businessName,
    required String primaryMobile,
    String? additionalContact,
    required String category,
    required String street,
    required String area,
    required String city,
    num? latitude,
    num? longitude,
    required String routeId,
    required String bottleOwnership,
    num? openingDebt,
    int? openingEmpties,
    String? cnic,
    String? contactName,
    String? contactRole,
    String? status,
    int? creditDays,
  }) async {
    final decoded = await _raw(
      'POST',
      '/api/admin/customers',
      body: {
        'businessName': businessName,
        'primaryMobile': primaryMobile,
        'additionalContact': additionalContact,
        'category': category,
        'street': street,
        'area': area,
        'city': city,
        'latitude': latitude,
        'longitude': longitude,
        'routeId': routeId,
        'bottleOwnership': bottleOwnership,
        'openingDebt': openingDebt,
        'openingEmpties': openingEmpties,
        'cnic': cnic,
        'contactName': contactName,
        'contactRole': contactRole,
        'status': status,
        'creditDays': creditDays,
      },
    );
    return AdminCustomerDetail.fromJson(decoded['data']);
  }

  @override
  Future<AdminCustomerDetail> adminUpdateCustomer(
    String id, {
    required String businessName,
    required String primaryMobile,
    String? additionalContact,
    required String category,
    required String street,
    required String area,
    required String city,
    num? latitude,
    num? longitude,
    required String routeId,
    required String bottleOwnership,
    num? openingDebt,
    int? openingEmpties,
    String? cnic,
    String? contactName,
    String? contactRole,
    String? status,
    int? creditDays,
  }) async {
    final decoded = await _raw(
      'PUT',
      '/api/admin/customers/$id',
      body: {
        'businessName': businessName,
        'primaryMobile': primaryMobile,
        'additionalContact': additionalContact,
        'category': category,
        'street': street,
        'area': area,
        'city': city,
        'latitude': latitude,
        'longitude': longitude,
        'routeId': routeId,
        'bottleOwnership': bottleOwnership,
        'openingDebt': openingDebt,
        'openingEmpties': openingEmpties,
        'cnic': cnic,
        'contactName': contactName,
        'contactRole': contactRole,
        'status': status,
        'creditDays': creditDays,
      },
    );
    return AdminCustomerDetail.fromJson(decoded['data']);
  }

  @override
  Future<AdminCustomerDetail> adminChangeCustomerRoute(
    String id, {
    required String routeId,
  }) async {
    final decoded = await _raw(
      'POST',
      '/api/admin/customers/$id/change-route',
      body: {'routeId': routeId},
    );
    return AdminCustomerDetail.fromJson(decoded['data']);
  }

  @override
  Future<AdminCustomerDetail> adminSetCustomerStatus(
    String id, {
    required String status,
  }) async {
    final decoded = await _raw(
      'POST',
      '/api/admin/customers/$id/status',
      body: {'status': status},
    );
    return AdminCustomerDetail.fromJson(decoded['data']);
  }

  @override
  Future<LedgerData> adminCustomerLedger(String id) async {
    final data = await _send('GET', '/api/admin/customers/$id/ledger')
        as Map<String, dynamic>;
    final entries = (data['entries'] as List<dynamic>? ?? const []).map((item) {
      final row = item as Map<String, dynamic>;
      return LedgerRow(
        id: row['id'] as String,
        description: row['description'] as String,
        occurredAt: DateTime.parse(row['occurredAt'] as String).toLocal(),
        amount: row['amount'] as num,
        balanceAfter: row['balanceAfter'] as num,
        kind: row['kind'] as String? ?? 'Opening',
        reference: row['reference'] as String?,
        detail: row['detail'] as String?,
      );
    }).toList();
    return LedgerData(
      customerId: data['customerId'] as String,
      customerName: data['customerName'] as String,
      customerCode: data['customerCode'] as String,
      outstanding: data['outstanding'] as num,
      creditDays: data['creditDays'] as int,
      bottlesIssued: data['bottlesIssued'] as int,
      bottlesReturned: data['bottlesReturned'] as int,
      bottlesHeld: data['bottlesHeld'] as int,
      entries: entries,
      openOrders: data['openOrders'] as int? ?? 0,
      todayCollected: data['todayCollected'] as num? ?? 0,
      stopSequence: data['stopSequence'] as int?,
    );
  }

  @override
  Future<StaffSummary> staffSummary() async {
    final decoded = await _raw('GET', '/api/users/summary');
    return StaffSummary.fromJson(decoded['data']);
  }

  @override
  Future<List<RoleReference>> staffRoleReference() async {
    final decoded = await _raw('GET', '/api/users/role-reference');
    return [
      for (final row in jsonRows(decoded['data'])) RoleReference.fromJson(row),
    ];
  }

  @override
  Future<RoleAccessMatrix> roleAccess() async {
    final decoded = await _raw('GET', '/api/users/access');
    return RoleAccessMatrix.fromJson(decoded['data']);
  }

  @override
  Future<RoleAccessRow> saveRoleAccess(String role, List<String> screenKeys) async {
    final decoded = await _raw(
      'PUT',
      '/api/users/access/${Uri.encodeComponent(role)}',
      body: {'screenKeys': screenKeys},
    );
    return RoleAccessRow.fromJson(decoded['data']);
  }

  @override
  Future<RoleAccessRow> createAccessRole({
    required String name,
    String? description,
  }) async {
    final decoded = await _raw(
      'POST',
      '/api/users/access',
      body: {'name': name, 'description': description},
    );
    return RoleAccessRow.fromJson(decoded['data']);
  }

  @override
  Future<RoleAccessRow> assignRoleMember(String role, String userId) async {
    final decoded = await _raw(
      'POST',
      '/api/users/access/${Uri.encodeComponent(role)}/members',
      body: {'userId': userId},
    );
    return RoleAccessRow.fromJson(decoded['data']);
  }

  @override
  Future<StaffUserPage> staffUsers({
    String? search,
    String? role,
    bool? isActive,
    int page = 1,
    int pageSize = 50,
  }) async {
    final decoded = await _raw(
      'GET',
      '/api/users',
      query: _clean({
        'search': search,
        'role': role,
        'isActive': isActive?.toString(),
        'page': '$page',
        'pageSize': '$pageSize',
      }),
    );
    final rows = [
      for (final row in jsonRows(decoded['data'])) StaffUser.fromJson(row),
    ];
    final pagination = decoded['pagination'];
    final pageMap = pagination is Map
        ? Map<String, dynamic>.from(pagination)
        : const <String, dynamic>{};
    return StaffUserPage(
      rows: rows,
      page: optionalInt(pageMap, const ['page']) ?? page,
      pageSize: optionalInt(pageMap, const ['pageSize']) ?? pageSize,
      totalRecords: optionalInt(pageMap, const ['totalRecords']) ?? rows.length,
      totalPages: optionalInt(pageMap, const ['totalPages']) ?? 1,
    );
  }

  @override
  Future<StaffUser> staffUser(String id) async {
    final decoded = await _raw('GET', '/api/users/$id');
    return StaffUser.fromJson(decoded['data']);
  }

  @override
  Future<StaffUser> createStaffUser({
    required String username,
    required String password,
    required String fullName,
    String? phone,
    String? riderCode,
    required String role,
    String? routeId,
    String? vehicleId,
    String? depotId,
    String? email,
    String? zoneId,
    String? warehousePersonUserId,
  }) async {
    final decoded = await _raw(
      'POST',
      '/api/users',
      body: {
        'username': username,
        'password': password,
        'fullName': fullName,
        'phone': phone,
        'riderCode': riderCode,
        'role': role,
        'routeId': routeId,
        'vehicleId': vehicleId,
        'depotId': depotId,
        'email': email,
        'zoneId': zoneId,
        'warehousePersonUserId': warehousePersonUserId,
      },
    );
    return StaffUser.fromJson(decoded['data']);
  }

  @override
  Future<StaffUser> updateStaffUser(
    String id, {
    required String fullName,
    String? phone,
    String? riderCode,
    String? routeId,
    String? vehicleId,
    String? depotId,
  }) async {
    final decoded = await _raw(
      'PUT',
      '/api/users/$id',
      body: {
        'fullName': fullName,
        'phone': phone,
        'riderCode': riderCode,
        'routeId': routeId,
        'vehicleId': vehicleId,
        'depotId': depotId,
      },
    );
    return StaffUser.fromJson(decoded['data']);
  }

  @override
  Future<StaffUser> setStaffUserStatus(
    String id, {
    required bool isActive,
  }) async {
    final decoded = await _raw(
      'POST',
      '/api/users/$id/status',
      body: {'isActive': isActive},
    );
    return StaffUser.fromJson(decoded['data']);
  }

  @override
  Future<void> resetStaffUserPassword(
    String id, {
    required String newPassword,
  }) async {
    await _raw(
      'POST',
      '/api/users/$id/reset-password',
      body: {'newPassword': newPassword},
    );
  }

  @override
  Future<DepotDetail> depotDetail() async {
    final decoded = await _raw('GET', '/api/depot');
    return DepotDetail.fromJson(decoded['data']);
  }

  @override
  Future<DepotOperations> depotSummary({String? date}) async {
    final decoded = await _raw(
      'GET',
      '/api/depot/summary',
      query: _clean({'date': date}),
    );
    return DepotOperations.fromJson(decoded['data']);
  }

  @override
  Future<List<DepotFleetMember>> depotFleet() async {
    final decoded = await _raw('GET', '/api/depot/fleet');
    return [
      for (final row in jsonRows(decoded['data'])) DepotFleetMember.fromJson(row),
    ];
  }

  @override
  Future<List<DepotStockLine>> depotStock() async {
    final decoded = await _raw('GET', '/api/depot/stock');
    return [
      for (final row in jsonRows(decoded['data'])) DepotStockLine.fromJson(row),
    ];
  }

  @override
  Future<DepotDetail> updateDepot({
    required String name,
    required String gate,
    required String address,
  }) async {
    final decoded = await _raw(
      'PUT',
      '/api/depot',
      body: {'name': name, 'gate': gate, 'address': address},
    );
    return DepotDetail.fromJson(decoded['data']);
  }

  @override
  Future<AdminSalesSummary> adminSalesSummary({String? date}) async {
    final decoded = await _raw(
      'GET',
      '/api/admin/sales/summary',
      query: _clean({'date': date}),
    );
    return AdminSalesSummary.fromJson(decoded['data']);
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
    final decoded = await _raw(
      'GET',
      '/api/admin/sales',
      query: _clean({
        'date': date,
        'type': type,
        'syncStatus': syncStatus,
        'riderId': riderId,
        'search': search,
        'page': '$page',
        'pageSize': '$pageSize',
      }),
    );
    final rows = [
      for (final row in jsonRows(decoded['data'])) AdminSaleRow.fromJson(row),
    ];
    final pagination = decoded['pagination'];
    final pageMap = pagination is Map
        ? Map<String, dynamic>.from(pagination)
        : const <String, dynamic>{};
    return AdminSalePage(
      rows: rows,
      page: optionalInt(pageMap, const ['page']) ?? page,
      pageSize: optionalInt(pageMap, const ['pageSize']) ?? pageSize,
      totalRecords: optionalInt(pageMap, const ['totalRecords']) ?? rows.length,
      totalPages: optionalInt(pageMap, const ['totalPages']) ?? 1,
    );
  }

  @override
  Future<AdminSaleDetail> adminSaleDetail(String id) async {
    final decoded = await _raw('GET', '/api/admin/sales/$id');
    return AdminSaleDetail.fromJson(decoded['data']);
  }

  @override
  Future<AdminSaleDraft> adminCreateSaleDraft({
    required String riderUserId,
    required String customerId,
    String? stopId,
    required List<Map<String, dynamic>> lines,
    int? emptyBottlesReturned,
  }) async {
    final decoded = await _raw(
      'POST',
      '/api/admin/sales/drafts',
      body: {
        'riderUserId': riderUserId,
        'customerId': customerId,
        'stopId': stopId,
        'lines': lines,
        'emptyBottlesReturned': emptyBottlesReturned,
      },
    );
    return AdminSaleDraft.fromJson(decoded['data']);
  }

  @override
  Future<ReceiptData> adminCompleteSale(
    String id, {
    required String paymentMethod,
    num? amountReceived,
    required String signerName,
    String? signerRole,
    bool closeStop = true,
    String? signatureImage,
    String? signatureNote,
  }) async {
    final decoded = await _raw(
      'POST',
      '/api/admin/sales/$id/complete',
      body: {
        'paymentMethod': paymentMethod,
        'amountReceived': amountReceived,
        'signerName': signerName,
        'signerRole': signerRole,
        'closeStop': closeStop,
        'signatureImage': signatureImage,
        'signatureNote': signatureNote,
      },
    );
    return _receipt(Map<String, dynamic>.from(decoded['data'] as Map));
  }

  @override
  Future<ReceiptData> adminSaleReceipt(String id) async {
    final decoded = await _raw('GET', '/api/admin/sales/$id/receipt');
    return _receipt(Map<String, dynamic>.from(decoded['data'] as Map));
  }

  @override
  Future<AdminCollectionsSummary> adminCollectionsSummary({String? date}) async {
    final decoded = await _raw(
      'GET',
      '/api/admin/collections/summary',
      query: _clean({'date': date}),
    );
    return AdminCollectionsSummary.fromJson(decoded['data']);
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
    final decoded = await _raw(
      'GET',
      '/api/admin/collections',
      query: _clean({
        'date': date,
        'type': type,
        'riderId': riderId,
        'search': search,
        'page': '$page',
        'pageSize': '$pageSize',
      }),
    );
    final rows = [
      for (final row in jsonRows(decoded['data']))
        AdminCollectionRow.fromJson(row),
    ];
    final pagination = decoded['pagination'];
    final pageMap = pagination is Map
        ? Map<String, dynamic>.from(pagination)
        : const <String, dynamic>{};
    return AdminCollectionPage(
      rows: rows,
      page: optionalInt(pageMap, const ['page']) ?? page,
      pageSize: optionalInt(pageMap, const ['pageSize']) ?? pageSize,
      totalRecords: optionalInt(pageMap, const ['totalRecords']) ?? rows.length,
      totalPages: optionalInt(pageMap, const ['totalPages']) ?? 1,
    );
  }

  @override
  Future<AdminCollectionDetail> adminCollectionDetail(String id) async {
    final decoded = await _raw('GET', '/api/admin/collections/$id');
    return AdminCollectionDetail.fromJson(decoded['data']);
  }

  @override
  Future<ReceiptData> adminRecordCollection({
    required String riderUserId,
    required String customerId,
    required num amount,
    required String signerName,
    num? withholdingTax,
    String? note,
    String? idempotencyKey,
  }) async {
    final decoded = await _raw(
      'POST',
      '/api/admin/collections',
      body: {
        'riderUserId': riderUserId,
        'customerId': customerId,
        'amount': amount,
        'signerName': signerName,
        'withholdingTax': withholdingTax,
        'note': note,
        'idempotencyKey': idempotencyKey,
      },
    );
    return _receipt(Map<String, dynamic>.from(decoded['data'] as Map));
  }

  @override
  Future<List<AdminReceivableExposure>> adminReceivablesExposure() async {
    final decoded = await _raw('GET', '/api/admin/receivables/exposure');
    return [
      for (final row in jsonRows(decoded['data']))
        AdminReceivableExposure.fromJson(row),
    ];
  }

  @override
  Future<AdminReportsSummary> adminReportsSummary({
    String? from,
    String? to,
  }) async {
    final decoded = await _raw(
      'GET',
      '/api/admin/reports/summary',
      query: _clean({'from': from, 'to': to}),
    );
    return AdminReportsSummary.fromJson(decoded['data']);
  }

  @override
  Future<List<AdminReportCatalogItem>> adminReportsCatalog() async {
    final decoded = await _raw('GET', '/api/admin/reports/catalog');
    return [
      for (final row in jsonRows(decoded['data']))
        AdminReportCatalogItem.fromJson(row),
    ];
  }

  @override
  Future<AdminReportTable> adminReportRun(
    String key, {
    String? from,
    String? to,
  }) async {
    final decoded = await _raw(
      'GET',
      '/api/admin/reports/$key',
      query: _clean({'from': from, 'to': to}),
    );
    return AdminReportTable.fromJson(decoded['data']);
  }

  @override
  Future<String> adminReportExportCsv(
    String key, {
    String? from,
    String? to,
  }) async {
    return _rawText(
      'GET',
      '/api/admin/reports/$key/export.csv',
      query: _clean({'from': from, 'to': to}),
    );
  }

  @override
  Future<AdminAuditSummary> adminAuditSummary({String? date}) async {
    final decoded = await _raw(
      'GET',
      '/api/admin/audit/summary',
      query: _clean({'date': date}),
    );
    return AdminAuditSummary.fromJson(decoded['data']);
  }

  @override
  Future<AdminAuditEventPage> adminAuditEvents({
    String? date,
    String? category,
    String? search,
    String? outcome,
    int page = 1,
    int pageSize = 20,
  }) async {
    final decoded = await _raw(
      'GET',
      '/api/admin/audit/events',
      query: _clean({
        'date': date,
        'category': category,
        'search': search,
        'outcome': outcome,
        'page': '$page',
        'pageSize': '$pageSize',
      }),
    );
    final rows = [
      for (final row in jsonRows(decoded['data']))
        AdminAuditEventRow.fromJson(row),
    ];
    final pagination = decoded['pagination'];
    final pageMap = pagination is Map
        ? Map<String, dynamic>.from(pagination)
        : const <String, dynamic>{};
    return AdminAuditEventPage(
      items: rows,
      page: optionalInt(pageMap, const ['page']) ?? page,
      pageSize: optionalInt(pageMap, const ['pageSize']) ?? pageSize,
      totalRecords: optionalInt(pageMap, const ['totalRecords']) ?? rows.length,
      totalPages: optionalInt(pageMap, const ['totalPages']) ?? 1,
    );
  }

  @override
  Future<AdminAuditEventDetail> adminAuditEvent(String id) async {
    final decoded = await _raw('GET', '/api/admin/audit/events/$id');
    return AdminAuditEventDetail.fromJson(decoded['data']);
  }

  @override
  Future<AdminAuditVerifyResult> adminAuditVerify(String id) async {
    final decoded = await _raw('POST', '/api/admin/audit/events/$id/verify');
    return AdminAuditVerifyResult.fromJson(decoded['data']);
  }

  @override
  Future<String> adminAuditExportCsv({
    String? date,
    String? category,
    String? search,
  }) async {
    return _rawText(
      'GET',
      '/api/admin/audit/export.csv',
      query: _clean({
        'date': date,
        'category': category,
        'search': search,
      }),
    );
  }

  @override
  Future<CommunicationDashboardSummary> adminCommunicationSummary({
    String? date,
  }) async {
    final decoded = await _raw(
      'GET',
      '/api/admin/communication/summary',
      query: _clean({'date': date}),
    );
    return CommunicationDashboardSummary.fromJson(decoded['data']);
  }

  @override
  Future<CommunicationGatewayStatus> adminCommunicationGateway() async {
    final decoded = await _raw('GET', '/api/admin/communication/gateway');
    return CommunicationGatewayStatus.fromJson(decoded['data']);
  }

  @override
  Future<CommunicationGatewayStatus> adminCommunicationTestGateway() async {
    final decoded = await _raw('POST', '/api/admin/communication/gateway/test');
    return CommunicationGatewayStatus.fromJson(decoded['data']);
  }

  @override
  Future<List<CommunicationTemplate>> adminCommunicationTemplates() async {
    final decoded = await _raw('GET', '/api/admin/communication/templates');
    return [
      for (final row in jsonRows(decoded['data']))
        CommunicationTemplate.fromJson(row),
    ];
  }

  @override
  Future<CommunicationTemplate> adminCreateCommunicationTemplate({
    required String name,
    required String language,
    required String triggerType,
    required String content,
    String? templateCode,
  }) async {
    final decoded = await _raw(
      'POST',
      '/api/admin/communication/templates',
      body: {
        'name': name,
        'language': language,
        'triggerType': triggerType,
        'content': content,
        'templateCode': templateCode,
      },
    );
    return CommunicationTemplate.fromJson(decoded['data']);
  }

  @override
  Future<CommunicationTemplate> adminUpdateCommunicationTemplate(
    String id, {
    required String name,
    required String language,
    required String triggerType,
    required String content,
  }) async {
    final decoded = await _raw(
      'PUT',
      '/api/admin/communication/templates/$id',
      body: {
        'name': name,
        'language': language,
        'triggerType': triggerType,
        'content': content,
      },
    );
    return CommunicationTemplate.fromJson(decoded['data']);
  }

  @override
  Future<CommunicationTemplate> adminSetCommunicationTemplateActive(
    String id, {
    required bool isActive,
  }) async {
    final path = isActive
        ? '/api/admin/communication/templates/$id/activate'
        : '/api/admin/communication/templates/$id/deactivate';
    final decoded = await _raw('POST', path);
    return CommunicationTemplate.fromJson(decoded['data']);
  }

  @override
  Future<void> adminArchiveCommunicationTemplate(String id) async {
    await _raw('POST', '/api/admin/communication/templates/$id/archive');
  }

  @override
  Future<CommunicationPreview> adminCommunicationPreview({
    required String templateId,
    Map<String, String>? variables,
  }) async {
    final decoded = await _raw(
      'POST',
      '/api/admin/communication/preview',
      body: {
        'templateId': templateId,
        'variables': variables,
      },
    );
    return CommunicationPreview.fromJson(decoded['data']);
  }

  @override
  Future<List<CommunicationTrigger>> adminCommunicationTriggers() async {
    final decoded = await _raw('GET', '/api/admin/communication/triggers');
    return [
      for (final row in jsonRows(decoded['data']))
        CommunicationTrigger.fromJson(row),
    ];
  }

  @override
  Future<CommunicationMessagePage> adminCommunicationMessages({
    String? date,
    String? status,
    String? search,
    int page = 1,
    int pageSize = 20,
  }) async {
    final decoded = await _raw(
      'GET',
      '/api/admin/communication/messages',
      query: _clean({
        'date': date,
        'status': status,
        'search': search,
        'page': '$page',
        'pageSize': '$pageSize',
      }),
    );
    final rows = [
      for (final row in jsonRows(decoded['data']))
        CommunicationMessageRow.fromJson(row),
    ];
    final pagination = decoded['pagination'];
    final pageMap = pagination is Map
        ? Map<String, dynamic>.from(pagination)
        : const <String, dynamic>{};
    return CommunicationMessagePage(
      items: rows,
      page: optionalInt(pageMap, const ['page']) ?? page,
      pageSize: optionalInt(pageMap, const ['pageSize']) ?? pageSize,
      totalRecords: optionalInt(pageMap, const ['totalRecords']) ?? rows.length,
      totalPages: optionalInt(pageMap, const ['totalPages']) ?? 1,
    );
  }

  @override
  Future<CommunicationMessageDetail> adminCommunicationMessage(String id) async {
    final decoded = await _raw('GET', '/api/admin/communication/messages/$id');
    return CommunicationMessageDetail.fromJson(decoded['data']);
  }

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
    final decoded = await _raw(
      'POST',
      '/api/admin/communication/messages',
      body: {
        'customerId': customerId,
        'templateId': templateId,
        'destinationNumber': destinationNumber,
        'transactionReference': transactionReference,
        'variables': variables,
        'idempotencyKey': idempotencyKey,
        'riderUserId': riderUserId,
      },
    );
    return CommunicationMessageDetail.fromJson(decoded['data']);
  }

  @override
  Future<CommunicationMessageDetail> adminRetryCommunicationMessage(
    String id,
  ) async {
    final decoded = await _raw(
      'POST',
      '/api/admin/communication/messages/$id/retry',
    );
    return CommunicationMessageDetail.fromJson(decoded['data']);
  }

  @override
  Future<String> adminCommunicationMessagesExportCsv({
    String? date,
    String? status,
  }) async {
    return _rawText(
      'GET',
      '/api/admin/communication/messages/export.csv',
      query: _clean({'date': date, 'status': status}),
    );
  }

  Future<DispatchActionResult> _dispatchAction(
    String id,
    String action,
    Map<String, dynamic> body,
  ) async {
    final decoded = await _raw(
      'POST',
      '/api/dispatch/orders/$id/$action',
      body: body,
    );
    return DispatchActionResult.fromJson(
      decoded['data'],
      message: decoded['message'] as String?,
    );
  }

  @override
  Future<SsoStatus> ssoStatus() async {
    try {
      final data = await _optional('/api/auth/sso/status');
      final map = _asMap(data);
      if (map == null) {
        return const SsoStatus(
          available: false,
          message: 'Corporate single sign-on is not available on this server.',
        );
      }
      return SsoStatus.fromJson(map);
    } on ApiException catch (error) {
      return SsoStatus(available: false, message: error.message);
    } catch (_) {
      return const SsoStatus(
        available: false,
        message: 'Corporate single sign-on could not be reached.',
      );
    }
  }

  Map<String, dynamic>? _lastOverviewPayload;

  @override
  Future<OnboardingOverview?> onboardingOverview() async {
    final map = _asMap(await _optional('/api/onboarding/overview'));
    _lastOverviewPayload = map;
    if (map == null) return null;
    return OnboardingOverview.fromJson(map);
  }

  @override
  Future<List<OnboardingStep>?> onboardingSteps() async {
    final direct = await _stepList('/api/onboarding/steps');
    if (direct != null) return direct;
    final embedded = _lastOverviewPayload;
    if (embedded == null) return null;
    return stepsFromOverviewJson(embedded);
  }

  @override
  Future<OnboardingProgress?> onboardingProgress() async {
    final map =
        _asMap(await _optional('/api/onboarding/progress')) ??
        _lastOverviewPayload;
    if (map == null) return null;
    return OnboardingProgress.fromJson(map);
  }

  @override
  Future<OnboardingReadiness?> onboardingReadiness() async {
    final map = _asMap(await _optional('/api/onboarding/readiness'));
    if (map != null) return OnboardingReadiness.fromJson(map);
    final overview = _lastOverviewPayload;
    if (overview == null) return null;
    return OnboardingReadiness.fromJson(overview);
  }

  @override
  Future<OnboardingNextStep?> onboardingNextStep() async {
    final map = _asMap(await _optional('/api/onboarding/next-step'));
    if (map != null) return OnboardingNextStep.fromJson(map);
    final overview = _lastOverviewPayload;
    final next = _asMap(overview?['nextStep']);
    if (next == null) return null;
    return OnboardingNextStep.fromJson({'step': next});
  }

  @override
  Future<List<OnboardingActivity>?> onboardingActivity() async {
    final data = await _optional('/api/onboarding/activity');
    if (data == null) return null;
    final list = data is List
        ? data
        : (_asMap(data)?['items'] ?? _asMap(data)?['activity']);
    if (list is! List) return const [];
    return [
      for (final item in list)
        if (_asMap(item) case final row?) OnboardingActivity.fromJson(row),
    ].where((item) => item.message.isNotEmpty).toList();
  }

  Future<List<OnboardingStep>?> _stepList(String path) async {
    final data = await _optional(path);
    if (data == null) return null;
    final list = data is List
        ? data
        : (_asMap(data)?['steps'] ?? _asMap(data)?['items']);
    if (list is! List) return const [];
    return [
      for (final item in list)
        if (_asMap(item) case final row?) OnboardingStep.fromJson(row),
    ];
  }

  Future<Object?> _optional(String path) async {
    try {
      return await _send('GET', path);
    } on ApiException catch (error) {
      if (error.statusCode == 404 || error.statusCode == 501) return null;
      rethrow;
    }
  }

  Map<String, dynamic>? _asMap(Object? data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return null;
  }

  Future<Object?> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
    bool auth = true,
  }) async {
    return (await _raw(
      method,
      path,
      query: query,
      body: body,
      auth: auth,
    ))['data'];
  }

  Future<Map<String, dynamic>> _raw(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
    bool auth = true,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$path')
        .replace(queryParameters: query);
    Future<http.Response> call(String? token) {
      final headers = {
        'Content-Type': 'application/json',
        if (auth && token != null) 'Authorization': 'Bearer $token',
      };
      final encoded = body == null ? null : jsonEncode(body);
      return switch (method) {
        'POST' => _client.post(uri, headers: headers, body: encoded),
        'PUT' => _client.put(uri, headers: headers, body: encoded),
        'PATCH' => _client.patch(uri, headers: headers, body: encoded),
        _ => _client.get(uri, headers: headers),
      }.timeout(const Duration(seconds: 12));
    }

    var response = await call(auth ? _access : null);
    if (response.statusCode == 401 && auth && _refresh != null) {
      final refreshed = await _client.post(
        Uri.parse('${ApiConfig.baseUrl}/api/auth/refresh-token'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': _refresh}),
      );
      final refreshedBody = _decode(refreshed);
      if (refreshed.statusCode == 200 && refreshedBody['success'] == true) {
        final session = _session(refreshedBody['data'] as Map<String, dynamic>);
        await _store(session);
        response = await call(_access);
      }
    }

    final decoded = _decode(response);
    if (response.statusCode >= 400 || decoded['success'] != true) {
      final errors = decoded['errors'];
      final extra = errors is List
          ? errors
                .whereType<String>()
                .where((item) => item.isNotEmpty)
                .join(' ')
          : '';
      final message = decoded['message'] as String? ?? 'Request failed.';
      throw ApiException(
        extra.isEmpty ? message : extra,
        statusCode: response.statusCode,
      );
    }
    return decoded;
  }

  Future<String> _rawText(
    String method,
    String path, {
    Map<String, String>? query,
    bool auth = true,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$path')
        .replace(queryParameters: query);
    Future<http.Response> call(String? token) {
      final headers = {
        if (auth && token != null) 'Authorization': 'Bearer $token',
      };
      return switch (method) {
        _ => _client.get(uri, headers: headers),
      }.timeout(const Duration(seconds: 12));
    }

    var response = await call(auth ? _access : null);
    if (response.statusCode == 401 && auth && _refresh != null) {
      final refreshed = await _client.post(
        Uri.parse('${ApiConfig.baseUrl}/api/auth/refresh-token'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': _refresh}),
      );
      final refreshedBody = _decode(refreshed);
      if (refreshed.statusCode == 200 && refreshedBody['success'] == true) {
        final session = _session(refreshedBody['data'] as Map<String, dynamic>);
        await _store(session);
        response = await call(_access);
      }
    }

    if (response.statusCode >= 400) {
      final decoded = _decode(response);
      final errors = decoded['errors'];
      final extra = errors is List
          ? errors
                .whereType<String>()
                .where((item) => item.isNotEmpty)
                .join(' ')
          : '';
      final message = decoded['message'] as String? ?? 'Request failed.';
      throw ApiException(
        extra.isEmpty ? message : extra,
        statusCode: response.statusCode,
      );
    }

    final contentType = (response.headers['content-type'] ?? '').toLowerCase();
    final isCsv =
        contentType.contains('csv') || path.toLowerCase().endsWith('.csv');
    if (isCsv || !_isSuccessJsonEnvelope(response.body)) {
      return response.body;
    }

    final decoded = _decode(response);
    if (decoded['success'] == true && decoded['data'] is String) {
      return decoded['data'] as String;
    }
    return response.body;
  }

  bool _isSuccessJsonEnvelope(String body) {
    if (body.trim().isEmpty) return false;
    try {
      final decoded = jsonDecode(body);
      return decoded is Map && decoded['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Map<String, dynamic> _decode(http.Response response) {
    if (response.body.isEmpty) return {'success': response.statusCode < 400};
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) return decoded;
    return {'success': false, 'message': 'Unexpected response.'};
  }

  Future<void> _store(AuthSession session) async {
    _access = session.accessToken;
    _refresh = session.refreshToken;
    await _storage.write(key: 'routeledger.access', value: session.accessToken);
    await _storage.write(
      key: 'routeledger.refresh',
      value: session.refreshToken,
    );
  }

  AuthSession _session(Map<String, dynamic> data) {
    final user = data['user'] as Map<String, dynamic>;
    return AuthSession(
      accessToken: data['accessToken'] as String,
      refreshToken: data['refreshToken'] as String,
      fullName: user['fullName'] as String? ?? '',
      username: user['username'] as String? ?? '',
      riderCode: user['riderCode'] as String? ?? '',
      routeName: user['routeName'] as String? ?? '',
      vehicleName: user['vehicleName'] as String? ?? '',
      vehiclePlate: user['vehiclePlate'] as String? ?? '',
      fleetCode: user['fleetCode'] as String? ?? '',
      depotGate: user['depotGate'] as String? ?? '',
      depotName: user['depotName'] as String? ?? '',
      role: user['role'] as String? ?? 'Rider',
      customerCode: user['customerCode'] as String? ?? '',
      allowedScreens: [
        for (final row in (user['allowedScreens'] is List ? user['allowedScreens'] as List : const []))
          if (row is String) row,
      ],
    );
  }

  StopItem _stop(Map<String, dynamic> row) {
    return StopItem(
      id: row['id'] as String,
      customerId: row['customerId'] as String,
      sequence: row['sequence'] as int,
      customerName: row['customerName'] as String,
      customerCode: row['customerCode'] as String,
      address: row['address'] as String,
      phone: row['phone'] as String,
      status: row['status'] as String,
      scheduledTime: row['scheduledTime'] as String?,
      outstanding: row['outstanding'] as num? ?? 0,
      emptyBottles: row['emptyBottles'] as int? ?? 0,
      distanceMeters: row['distanceMeters'] as int?,
      actionLabel: row['actionLabel'] as String,
      receiptSaleId: row['receiptSaleId'] as String?,
      invoiceNumber: row['invoiceNumber'] as String?,
      latitude: row['latitude'] as num?,
      longitude: row['longitude'] as num?,
    );
  }

  CustomerDetail _customer(Map<String, dynamic> row) {
    return CustomerDetail(
      id: row['id'] as String,
      code: row['code'] as String,
      businessName: row['businessName'] as String,
      category: row['category'] as String? ?? '',
      status: row['status'] as String? ?? '',
      phone: row['phone'] as String? ?? '',
      additionalContact: row['additionalContact'] as String?,
      street: row['street'] as String? ?? '',
      area: row['area'] as String? ?? '',
      city: row['city'] as String? ?? '',
      latitude: row['latitude'] as num?,
      longitude: row['longitude'] as num?,
      routeName: row['routeName'] as String? ?? '',
      routeId: row['routeId'] as String? ?? '',
      outstanding: row['outstanding'] as num? ?? 0,
      lastDropAt: row['lastDropAt'] == null
          ? null
          : DateTime.parse(row['lastDropAt'] as String).toLocal(),
      openOrders: row['openOrders'] as int? ?? 0,
      bottlesIssued: row['bottlesIssued'] as int? ?? 0,
      bottlesReturned: row['bottlesReturned'] as int? ?? 0,
      bottlesHeld: row['bottlesHeld'] as int? ?? 0,
      bottleOwnership: row['bottleOwnership'] as String? ?? 'Rented',
      cnic: row['cnic'] as String?,
      contactName: row['contactName'] as String?,
      contactRole: row['contactRole'] as String?,
      creditDays: row['creditDays'] as int? ?? 0,
      lastPaymentLabel: row['lastPaymentLabel'] as String?,
      nextOrderProduct: row['nextOrderProduct'] as String?,
      nextOrderQuantity: row['nextOrderQuantity'] as int? ?? 0,
      nextOrderDate: row['nextOrderDate'] as String?,
    );
  }

  ProductItem _product(Map<String, dynamic> row) {
    return ProductItem(
      id: row['id'] as String,
      name: row['name'] as String,
      unitPrice: row['unitPrice'] as num,
      unitLabel: row['unitLabel'] as String? ?? '',
      vanStock: row['vanStock'] as int? ?? 0,
      depotExpected: row['depotExpected'] as int? ?? 0,
      isReturnable: row['isReturnable'] as bool? ?? false,
    );
  }

  SaleDraft _draft(Map<String, dynamic> row) {
    return SaleDraft(
      id: row['id'] as String,
      customerId: row['customerId'] as String,
      saleAmount: row['saleAmount'] as num,
      previousOutstanding: row['previousOutstanding'] as num,
      amountDue: row['amountDue'] as num,
      emptyBottlesReturned: row['emptyBottlesReturned'] as int? ?? 0,
      emptyBottlesRemaining: row['emptyBottlesRemaining'] as int? ?? 0,
      lines: (row['lines'] as List<dynamic>)
          .map((item) => _line(item as Map<String, dynamic>))
          .toList(),
      receiptNumber: row['receiptNumber'] as String? ?? '',
    );
  }

  SaleLineItem _line(Map<String, dynamic> row) {
    return SaleLineItem(
      productId: row['productId'] as String,
      name: row['name'] as String,
      quantity: row['quantity'] as int,
      unitPrice: row['unitPrice'] as num,
      lineTotal: row['lineTotal'] as num,
    );
  }

  ReceiptData _receipt(Map<String, dynamic> row) {
    return ReceiptData(
      id: row['id'] as String,
      kind: row['kind'] as String,
      receiptNumber: row['receiptNumber'] as String,
      issuedAt: DateTime.parse(row['issuedAt'] as String).toLocal(),
      riderName: row['riderName'] as String? ?? '',
      riderCode: row['riderCode'] as String? ?? '',
      customerName: row['customerName'] as String? ?? '',
      customerCode: row['customerCode'] as String? ?? '',
      lines: (row['lines'] as List<dynamic>? ?? [])
          .map((item) => _line(item as Map<String, dynamic>))
          .toList(),
      saleAmount: row['saleAmount'] as num? ?? 0,
      previousOutstanding: row['previousOutstanding'] as num? ?? 0,
      amountReceived: row['amountReceived'] as num? ?? 0,
      balanceAfter: row['balanceAfter'] as num? ?? 0,
      paymentMethod: row['paymentMethod'] as String? ?? '',
      signerName: row['signerName'] as String?,
      signerRole: row['signerRole'] as String?,
      customerAddress: row['customerAddress'] as String? ?? '',
      customerPhone: row['customerPhone'] as String? ?? '',
      depotName: row['depotName'] as String? ?? '',
      depotAddress: row['depotAddress'] as String? ?? '',
      emptyBottlesReturned: row['emptyBottlesReturned'] as int? ?? 0,
      emptyBottlesHeld: row['emptyBottlesHeld'] as int? ?? 0,
      signatureNote: row['signatureNote'] as String?,
      withholdingTax: (row['withholdingTax'] as num?)?.round() ?? 0,
      syncStatus: row['syncStatus'] as String? ?? '',
    );
  }

  ShiftData _shift(Map<String, dynamic> row) {
    return ShiftData(
      id: row['id'] as String?,
      status: row['status'] as String? ?? 'Closed',
      serviceDate: row['serviceDate'] as String? ?? '',
      openingOdometer: row['openingOdometer'] as int? ?? 0,
      fleetCode: row['fleetCode'] as String? ?? '',
      routeLabel: row['routeLabel'] as String? ?? '',
      depotLabel: row['depotLabel'] as String? ?? '',
      odometerVerified: row['odometerVerified'] as bool? ?? false,
      lines: (row['lines'] as List<dynamic>).map((item) {
        final line = item as Map<String, dynamic>;
        return ShiftLine(
          productId: line['productId'] as String,
          name: line['name'] as String,
          depotExpected: line['depotExpected'] as int? ?? 0,
          countedQuantity: line['countedQuantity'] as int? ?? 0,
          editable: line['editable'] as bool? ?? false,
        );
      }).toList(),
    );
  }

  SettingsData _settings(Map<String, dynamic> row) {
    return SettingsData(
      autoSync: row['autoSync'] as bool? ?? true,
      showOrdersTab: row['showOrdersTab'] as bool? ?? true,
      language: row['language'] as String? ?? 'English (US)',
      autoPrint: row['autoPrint'] as bool? ?? false,
      deleteOnLogout: row['deleteOnLogout'] as bool? ?? false,
      paperSize: row['paperSize'] as String? ?? '58mm',
      printerId: row['printerId'] as String?,
      printerName: row['printerName'] as String?,
    );
  }

  @override
  Future<TrackingSessionInfo> startTracking() async {
    final decoded = await _raw('POST', '/api/rider/tracking/start');
    return TrackingSessionInfo.fromJson(decoded['data']);
  }

  @override
  Future<TrackingSessionInfo> stopTracking({String? reason}) async {
    final decoded = await _raw(
      'POST',
      '/api/rider/tracking/stop',
      body: {'reason': ?reason},
    );
    return TrackingSessionInfo.fromJson(decoded['data']);
  }

  @override
  Future<void> uploadTrackingLocations({
    String? sessionId,
    required List<Map<String, dynamic>> points,
  }) async {
    await _raw(
      'POST',
      '/api/rider/tracking/location',
      body: {'sessionId': ?sessionId, 'points': points},
    );
  }

  @override
  Future<TrackingStatusInfo> trackingStatus() async {
    final decoded = await _raw('GET', '/api/rider/tracking/status');
    return TrackingStatusInfo.fromJson(decoded['data']);
  }

  @override
  Future<ActiveAssignmentInfo> activeAssignment() async {
    final decoded = await _raw('GET', '/api/rider/assignments/active');
    return ActiveAssignmentInfo.fromJson(decoded['data']);
  }

  @override
  Future<RouteComplianceStateInfo> routeComplianceCurrent() async {
    final decoded = await _raw('GET', '/api/rider/route-compliance/current');
    return RouteComplianceStateInfo.fromJson(decoded['data']);
  }

  @override
  Future<List<RouteAnomalyInfo>> riderRouteAnomalies() async {
    final decoded = await _raw('GET', '/api/rider/route-anomalies');
    final rows = decoded['data'] as List? ?? const [];
    return rows.map(RouteAnomalyInfo.fromJson).toList();
  }

  @override
  Future<RouteAnomalyInfo> submitAnomalyExplanation({
    required String anomalyId,
    required String reason,
    required String explanationText,
    String? supportingNote,
    bool isCorrection = false,
  }) async {
    final decoded = await _raw(
      'POST',
      '/api/rider/route-anomalies/$anomalyId/explanation',
      body: {
        'reason': reason,
        'explanationText': explanationText,
        'supportingNote': ?supportingNote,
        'isCorrection': isCorrection,
      },
    );
    return RouteAnomalyInfo.fromJson(decoded['data']);
  }

  @override
  Future<List<RiderNotificationInfo>> riderNotifications() async {
    final decoded = await _raw('GET', '/api/rider/notifications');
    final rows = decoded['data'] as List? ?? const [];
    return rows.map(RiderNotificationInfo.fromJson).toList();
  }

  @override
  Future<void> markRiderNotificationRead(String id) async {
    await _raw('POST', '/api/rider/notifications/$id/read');
  }

  @override
  Future<LiveTrackingOverview> liveTrackingOverview() async {
    final decoded = await _raw('GET', '/api/admin/live-tracking/overview');
    return LiveTrackingOverview.fromJson(decoded['data']);
  }

  @override
  Future<List<LiveRiderCard>> liveTrackingRiders() async {
    final decoded = await _raw('GET', '/api/admin/live-tracking/riders');
    final rows = decoded['data'] as List? ?? const [];
    return rows.map(LiveRiderCard.fromJson).toList();
  }

  @override
  Future<LiveRiderDetail> liveTrackingRider(String riderUserId) async {
    final decoded = await _raw(
      'GET',
      '/api/admin/live-tracking/riders/$riderUserId',
    );
    return LiveRiderDetail.fromJson(decoded['data']);
  }

  @override
  Future<List<RouteAnomalyInfo>> adminRouteAnomalies({
    String? status,
    String? riderUserId,
  }) async {
    final query = <String, String>{};
    if (status != null && status.isNotEmpty) query['status'] = status;
    if (riderUserId != null && riderUserId.isNotEmpty) {
      query['riderUserId'] = riderUserId;
    }
    final decoded = await _raw(
      'GET',
      '/api/admin/route-anomalies',
      query: query.isEmpty ? null : query,
    );
    final rows = decoded['data'] as List? ?? const [];
    return rows.map(RouteAnomalyInfo.fromJson).toList();
  }

  @override
  Future<RouteAnomalyInfo> adminRouteAnomaly(String id) async {
    final decoded = await _raw('GET', '/api/admin/route-anomalies/$id');
    return RouteAnomalyInfo.fromJson(decoded['data']);
  }

  @override
  Future<RouteAnomalyInfo> reviewRouteAnomaly({
    required String id,
    required String action,
    String? notes,
  }) async {
    final decoded = await _raw(
      'POST',
      '/api/admin/route-anomalies/$id/review',
      body: {'action': action, 'notes': ?notes},
    );
    return RouteAnomalyInfo.fromJson(decoded['data']);
  }

  @override
  Future<RouteAnomalyInfo> queryRouteAnomaly({
    required String id,
    required String message,
  }) async {
    final decoded = await _raw(
      'POST',
      '/api/admin/route-anomalies/$id/query',
      body: {'message': message},
    );
    return RouteAnomalyInfo.fromJson(decoded['data']);
  }

  @override
  Future<RouteAnomalyInfo> resolveRouteAnomaly({
    required String id,
    String? notes,
    bool markFalsePositive = false,
  }) async {
    final decoded = await _raw(
      'POST',
      '/api/admin/route-anomalies/$id/resolve',
      body: {'notes': ?notes, 'markFalsePositive': markFalsePositive},
    );
    return RouteAnomalyInfo.fromJson(decoded['data']);
  }
}
