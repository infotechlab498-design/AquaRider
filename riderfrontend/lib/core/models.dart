import 'format.dart';

class RiderProfile {
  const RiderProfile({
    required this.fullName,
    required this.shortName,
    required this.id,
    required this.phone,
    required this.routeName,
    required this.loadedBottles,
  });

  final String fullName;
  final String shortName;
  final String id;
  final String phone;
  final String routeName;
  final int loadedBottles;
}

const kRider = RiderProfile(
  fullName: 'Ahmed Raza',
  shortName: 'Ahmed',
  id: '402',
  phone: kRegisteredPhone,
  routeName: 'Route 04: Clifton / Defence',
  loadedBottles: 84,
);

class Customer {
  const Customer({
    required this.id,
    required this.name,
    required this.area,
    required this.address,
    required this.phone,
    this.balance = 0,
    this.scheduledToday = false,
  });

  final String id;
  final String name;
  final String area;
  final String address;
  final String phone;
  final int balance;
  final bool scheduledToday;
}

const kCustomers = <Customer>[
  Customer(
    id: 'c1',
    name: 'Ahmed Raza',
    area: 'Bahria Town Phase 4',
    address: 'House 142-B, Bahria Town Phase 4',
    phone: '0300-5551234',
    scheduledToday: true,
  ),
  Customer(
    id: 'c2',
    name: 'Sara Malik',
    area: 'Satellite Town',
    address: 'House 18, Satellite Town',
    phone: '0321-4567890',
    balance: 450,
    scheduledToday: true,
  ),
  Customer(
    id: 'c3',
    name: 'Bilal Ahmed',
    area: 'Commercial Market',
    address: 'Shop 5, Commercial Market',
    phone: '0333-4445566',
    scheduledToday: true,
  ),
  Customer(
    id: 'c4',
    name: 'Noor Office',
    area: 'Saddar',
    address: 'Noor Office, Saddar',
    phone: '0301-9988776',
    balance: 1200,
    scheduledToday: true,
  ),
  Customer(
    id: 'c5',
    name: 'Hina Qureshi',
    area: 'Gulberg',
    address: 'Street 12, Gulberg',
    phone: '0345-1122334',
    balance: 300,
  ),
  Customer(
    id: 'c6',
    name: 'Usman Traders',
    area: 'Blue Area',
    address: 'Shop 9, Blue Area',
    phone: '0311-6677889',
  ),
];

class DeliveryDraft {
  Customer? customer;
  int fullBottles = 0;
  int emptyBottles = 0;
  PaymentMethod method = PaymentMethod.cash;
  int? amount;
  bool amountTouched = false;
  PaymentProvider provider = PaymentProvider.jazzCash;
  String reference = '';
  String? proofPath;

  int get bill => fullBottles * kBottlePrice;

  bool get hasQuantity => fullBottles > 0 || emptyBottles > 0;

  bool get awaitingVerification =>
      method == PaymentMethod.online && proofPath != null;

  bool get amountValid {
    if (method == PaymentMethod.unpaid) return true;
    if (bill == 0) return amount == null || amount! >= 0;
    return amount != null && amount! > 0;
  }

  int get settledAmount {
    if (method == PaymentMethod.unpaid) return 0;
    return amount ?? 0;
  }

  int get unpaidPortion {
    if (method == PaymentMethod.unpaid) return bill;
    final received = amount ?? 0;
    return received < bill ? bill - received : 0;
  }
}

class DeliveryEntry {
  const DeliveryEntry({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.area,
    required this.address,
    required this.phone,
    required this.fullBottles,
    required this.emptyBottles,
    required this.method,
    required this.amount,
    required this.billAmount,
    required this.previousBalance,
    required this.savedAt,
    this.provider,
    this.reference,
    this.proofPath,
    this.synced = false,
  });

  final String id;
  final String customerId;
  final String customerName;
  final String area;
  final String address;
  final String phone;
  final int fullBottles;
  final int emptyBottles;
  final PaymentMethod method;
  final int amount;
  final int billAmount;
  final int previousBalance;
  final PaymentProvider? provider;
  final String? reference;
  final String? proofPath;
  final DateTime savedAt;
  final bool synced;

  bool get awaitingVerification =>
      method == PaymentMethod.online && proofPath != null;

  String get statusLabel {
    if (method == PaymentMethod.unpaid) return 'Unpaid';
    if (awaitingVerification) return 'Awaiting Verification';
    return 'Saved';
  }

  int get unpaidPortion {
    if (method == PaymentMethod.unpaid) return billAmount;
    return amount < billAmount ? billAmount - amount : 0;
  }

  DeliveryEntry copyWith({bool? synced}) {
    return DeliveryEntry(
      id: id,
      customerId: customerId,
      customerName: customerName,
      area: area,
      address: address,
      phone: phone,
      fullBottles: fullBottles,
      emptyBottles: emptyBottles,
      method: method,
      amount: amount,
      billAmount: billAmount,
      previousBalance: previousBalance,
      provider: provider,
      reference: reference,
      proofPath: proofPath,
      savedAt: savedAt,
      synced: synced ?? this.synced,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'customerId': customerId,
    'customerName': customerName,
    'area': area,
    'address': address,
    'phone': phone,
    'fullBottles': fullBottles,
    'emptyBottles': emptyBottles,
    'method': method.name,
    'amount': amount,
    'billAmount': billAmount,
    'previousBalance': previousBalance,
    'provider': provider?.name,
    'reference': reference,
    'proofPath': proofPath,
    'savedAt': savedAt.toIso8601String(),
    'synced': synced,
  };

  factory DeliveryEntry.fromJson(Map<String, dynamic> json) {
    return DeliveryEntry(
      id: json['id'] as String,
      customerId: json['customerId'] as String,
      customerName: json['customerName'] as String,
      area: json['area'] as String,
      address: json['address'] as String,
      phone: json['phone'] as String,
      fullBottles: json['fullBottles'] as int,
      emptyBottles: json['emptyBottles'] as int,
      method: PaymentMethod.values.byName(json['method'] as String),
      amount: json['amount'] as int,
      billAmount: json['billAmount'] as int,
      previousBalance: json['previousBalance'] as int,
      provider: json['provider'] == null
          ? null
          : PaymentProvider.values.byName(json['provider'] as String),
      reference: json['reference'] as String?,
      proofPath: json['proofPath'] as String?,
      savedAt: DateTime.parse(json['savedAt'] as String),
      synced: json['synced'] as bool? ?? false,
    );
  }
}
