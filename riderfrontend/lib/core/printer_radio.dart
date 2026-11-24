import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_bluetooth_serial_plus/flutter_bluetooth_serial_plus.dart';

class NearbyPrinter {
  const NearbyPrinter({
    required this.name,
    required this.address,
    required this.paired,
    this.rssi,
  });

  final String name;
  final String address;
  final bool paired;
  final int? rssi;

  String get signal {
    final value = rssi;
    if (value == null || value == 0) return 'Paired on this phone';
    if (value >= -60) return 'Strong signal';
    if (value >= -75) return 'Good signal';
    return 'Weak signal';
  }
}

/// Classic Bluetooth (SPP) link used by 58 mm and 80 mm ESC/POS receipt printers.
class PrinterRadio {
  static BluetoothConnection? _connection;
  static String? connectedName;
  static String? connectedAddress;

  static bool get isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static bool get isConnected => _connection?.isConnected == true;

  static Future<({bool permitted, bool enabled})> status() async {
    if (!isAndroid) return (permitted: false, enabled: false);
    final serial = FlutterBluetoothSerial.instance;
    final permitted = await serial.ensurePermissions();
    if (!permitted) return (permitted: false, enabled: false);
    final enabled = await serial.isEnabled ?? false;
    return (permitted: true, enabled: enabled);
  }

  static Future<bool> turnOn() async {
    if (!isAndroid) return false;
    final serial = FlutterBluetoothSerial.instance;
    final permitted = await serial.ensurePermissions();
    if (!permitted) return false;
    if (await serial.isEnabled ?? false) return true;
    return await serial.requestEnable() ?? false;
  }

  static Stream<BluetoothState> watchState() {
    if (!isAndroid) return const Stream<BluetoothState>.empty();
    return FlutterBluetoothSerial.instance.onStateChanged();
  }

  static Future<List<NearbyPrinter>> bonded() async {
    if (!isAndroid) return const [];
    try {
      final devices = await FlutterBluetoothSerial.instance.getBondedDevices();
      return devices.map(_fromDevice).toList();
    } catch (_) {
      return const [];
    }
  }

  static Stream<NearbyPrinter> discover() {
    if (!isAndroid) return const Stream<NearbyPrinter>.empty();
    return FlutterBluetoothSerial.instance.startDiscovery().map(
      (result) => _fromDevice(result.device, rssi: result.rssi),
    );
  }

  static Future<void> cancelDiscovery() {
    if (!isAndroid) return Future.value();
    return FlutterBluetoothSerial.instance.cancelDiscovery();
  }

  static Future<void> connect(NearbyPrinter printer) async {
    if (!isAndroid) {
      throw StateError('Receipt printers connect from the Android phone.');
    }
    await disconnect();
    final serial = FlutterBluetoothSerial.instance;
    final bond = await serial.getBondStateForAddress(printer.address);
    if (!bond.isBonded) {
      final paired = await serial.bondDeviceAtAddress(printer.address) ?? false;
      if (!paired) {
        throw StateError(
          'Pairing was cancelled. The printer PIN is usually 0000 or 1234.',
        );
      }
    }
    _connection = await BluetoothConnection.toAddress(printer.address)
        .timeout(const Duration(seconds: 15));
    connectedName = printer.name;
    connectedAddress = printer.address;
  }

  static Future<void> printText(String text) async {
    final connection = _connection;
    if (connection == null || !connection.isConnected) {
      throw StateError('Connect a printer in Printer Configuration first.');
    }
    final bytes = <int>[0x1B, 0x40];
    final safe = text.replaceAll(RegExp(r'[^\x00-\xFF]'), '?');
    bytes.addAll(latin1.encode(safe));
    bytes.addAll(const [0x0A, 0x0A, 0x0A]);
    connection.output.add(Uint8List.fromList(bytes));
    await connection.output.allSent;
  }

  static Future<void> disconnect() async {
    final connection = _connection;
    _connection = null;
    connectedName = null;
    connectedAddress = null;
    if (connection == null) return;
    try {
      await connection.close();
    } catch (_) {}
  }

  static NearbyPrinter _fromDevice(BluetoothDevice device, {int? rssi}) {
    final raw = device.name?.trim();
    return NearbyPrinter(
      name: raw == null || raw.isEmpty ? 'Unknown printer' : raw,
      address: device.address,
      paired: device.isBonded,
      rssi: rssi,
    );
  }
}
