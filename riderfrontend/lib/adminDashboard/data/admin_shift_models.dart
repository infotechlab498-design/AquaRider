class ShiftDayRecord {
  const ShiftDayRecord({
    required this.serviceDate,
    required this.riders,
    required this.selected,
    required this.odometer,
  });

  final String serviceDate;
  final List<ShiftRiderDay> riders;
  final ShiftRiderDay? selected;
  final List<OdometerDay> odometer;

  factory ShiftDayRecord.fromJson(Map<String, dynamic> json) {
    final selected = json['selected'];
    return ShiftDayRecord(
      serviceDate: '${json['serviceDate'] ?? ''}',
      riders: [
        for (final row in _rows(json['riders'])) ShiftRiderDay.fromJson(row),
      ],
      selected: selected is Map
          ? ShiftRiderDay.fromJson(Map<String, dynamic>.from(selected))
          : null,
      odometer: [
        for (final row in _rows(json['odometer'])) OdometerDay.fromJson(row),
      ],
    );
  }
}

class ShiftRiderDay {
  const ShiftRiderDay({
    required this.riderId,
    required this.riderName,
    required this.riderCode,
    required this.routeName,
    required this.vehicleName,
    required this.plate,
    required this.fleetCode,
    required this.depotName,
    required this.status,
    required this.startedAt,
    required this.endedAt,
    required this.openingOdometer,
    required this.closingOdometer,
    required this.openingPhotoStored,
    required this.closingPhotoStored,
    required this.openingInspectionStored,
    required this.closingInspectionStored,
    required this.openingOdometerPhoto,
    required this.closingOdometerPhoto,
    required this.openingInspectionPhoto,
    required this.closingInspectionPhoto,
    required this.loadedUnits,
    required this.expectedUnits,
    required this.toDeliverUnits,
    required this.orderCount,
    required this.loaded,
    required this.toDeliver,
  });

  final String riderId;
  final String riderName;
  final String riderCode;
  final String routeName;
  final String vehicleName;
  final String plate;
  final String fleetCode;
  final String depotName;
  final String status;
  final String? startedAt;
  final String? endedAt;
  final int? openingOdometer;
  final int? closingOdometer;
  final bool openingPhotoStored;
  final bool closingPhotoStored;
  final bool openingInspectionStored;
  final bool closingInspectionStored;
  final String? openingOdometerPhoto;
  final String? closingOdometerPhoto;
  final String? openingInspectionPhoto;
  final String? closingInspectionPhoto;
  final int loadedUnits;
  final int expectedUnits;
  final int toDeliverUnits;
  final int orderCount;
  final List<LoadedBottle> loaded;
  final List<DeliverBottle> toDeliver;

  String get statusLabel => switch (status) {
    'Open' => 'Day started',
    'Closed' => 'Day closed',
    _ => 'Not started',
  };

  factory ShiftRiderDay.fromJson(Map<String, dynamic> json) {
    return ShiftRiderDay(
      riderId: '${json['riderId'] ?? ''}',
      riderName: '${json['riderName'] ?? ''}',
      riderCode: '${json['riderCode'] ?? ''}',
      routeName: '${json['routeName'] ?? ''}',
      vehicleName: '${json['vehicleName'] ?? ''}',
      plate: '${json['plate'] ?? ''}',
      fleetCode: '${json['fleetCode'] ?? ''}',
      depotName: '${json['depotName'] ?? ''}',
      status: '${json['status'] ?? 'NotStarted'}',
      startedAt: _text(json['startedAt']),
      endedAt: _text(json['endedAt']),
      openingOdometer: _intOrNull(json['openingOdometer']),
      closingOdometer: _intOrNull(json['closingOdometer']),
      openingPhotoStored: json['openingPhotoStored'] == true,
      closingPhotoStored: json['closingPhotoStored'] == true,
      openingInspectionStored: json['openingInspectionStored'] == true,
      closingInspectionStored: json['closingInspectionStored'] == true,
      openingOdometerPhoto: _text(json['openingOdometerPhoto']),
      closingOdometerPhoto: _text(json['closingOdometerPhoto']),
      openingInspectionPhoto: _text(json['openingInspectionPhoto']),
      closingInspectionPhoto: _text(json['closingInspectionPhoto']),
      loadedUnits: _int(json['loadedUnits']),
      expectedUnits: _int(json['expectedUnits']),
      toDeliverUnits: _int(json['toDeliverUnits']),
      orderCount: _int(json['orderCount']),
      loaded: [
        for (final row in _rows(json['loaded'])) LoadedBottle.fromJson(row),
      ],
      toDeliver: [
        for (final row in _rows(json['toDeliver'])) DeliverBottle.fromJson(row),
      ],
    );
  }
}

class LoadedBottle {
  const LoadedBottle({
    required this.productName,
    required this.unitLabel,
    required this.depotExpected,
    required this.loaded,
    required this.closing,
  });

  final String productName;
  final String unitLabel;
  final int depotExpected;
  final int loaded;
  final int? closing;

  String get loadStatus {
    if (loaded == depotExpected) return 'Matches depot';
    if (loaded < depotExpected) return 'Short by ${depotExpected - loaded}';
    return 'Over by ${loaded - depotExpected}';
  }

  factory LoadedBottle.fromJson(Map<String, dynamic> json) {
    return LoadedBottle(
      productName: '${json['productName'] ?? ''}',
      unitLabel: '${json['unitLabel'] ?? ''}',
      depotExpected: _int(json['depotExpected']),
      loaded: _int(json['loaded']),
      closing: _intOrNull(json['closing']),
    );
  }
}

class DeliverBottle {
  const DeliverBottle({
    required this.productName,
    required this.unitLabel,
    required this.quantity,
  });

  final String productName;
  final String unitLabel;
  final int quantity;

  factory DeliverBottle.fromJson(Map<String, dynamic> json) {
    return DeliverBottle(
      productName: '${json['productName'] ?? ''}',
      unitLabel: '${json['unitLabel'] ?? ''}',
      quantity: _int(json['quantity']),
    );
  }
}

class OdometerDay {
  const OdometerDay({
    required this.serviceDate,
    required this.status,
    required this.openingOdometer,
    required this.closingOdometer,
    required this.distanceKm,
  });

  final String serviceDate;
  final String status;
  final int openingOdometer;
  final int? closingOdometer;
  final int? distanceKm;

  factory OdometerDay.fromJson(Map<String, dynamic> json) {
    return OdometerDay(
      serviceDate: '${json['serviceDate'] ?? ''}',
      status: '${json['status'] ?? ''}',
      openingOdometer: _int(json['openingOdometer']),
      closingOdometer: _intOrNull(json['closingOdometer']),
      distanceKm: _intOrNull(json['distanceKm']),
    );
  }
}

List<Map<String, dynamic>> _rows(Object? value) {
  if (value is! List) return const [];
  return [
    for (final row in value)
      if (row is Map) Map<String, dynamic>.from(row),
  ];
}

int _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse('$value') ?? 0;
}

int? _intOrNull(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse('$value');
}

String? _text(Object? value) {
  if (value == null) return null;
  final text = '$value'.trim();
  return text.isEmpty ? null : text;
}
