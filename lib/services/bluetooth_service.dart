import 'dart:async';

import 'package:controller/models/boat_command.dart';
import 'package:controller/orientation_lock.dart';
import 'package:controller/services/boat_connection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as ble;
import 'package:permission_handler/permission_handler.dart';

/// Nordic UART Service (common on ESP32 BLE bridges).
final _nusService = ble.Guid('6E400001-B5A3-F393-E0A9-E50E24DCCA9E');
final _nusRx = ble.Guid('6E400002-B5A3-F393-E0A9-E50E24DCCA9E');
final _nusTx = ble.Guid('6E400003-B5A3-F393-E0A9-E50E24DCCA9E');

class BoatScanDevice {
  const BoatScanDevice({
    required this.id,
    required this.name,
    required this.rssi,
    required this.device,
  });

  final String id;
  final String name;
  final int rssi;
  final ble.BluetoothDevice device;
}

class BluetoothService implements BoatConnection {
  ble.BluetoothDevice? _device;
  ble.BluetoothCharacteristic? _writeChar;
  StreamSubscription<ble.BluetoothConnectionState>? _connectionSub;
  StreamSubscription<List<ble.ScanResult>>? _scanSub;
  final _statusController = StreamController<LinkStatus>.broadcast();
  final _inboundController = StreamController<String>.broadcast();
  final _scanController = StreamController<List<BoatScanDevice>>.broadcast();

  LinkStatus _status = LinkStatus.disconnected;
  String? _error;
  String _label = 'Bluetooth';

  @override
  ConnectionKind get kind => ConnectionKind.bluetooth;

  @override
  String get label => _label;

  @override
  LinkStatus get status => _status;

  @override
  String? get lastError => _error;

  @override
  Stream<LinkStatus> get statusStream => _statusController.stream;

  @override
  Stream<String> get inbound => _inboundController.stream;

  Stream<List<BoatScanDevice>> get scanResults => _scanController.stream;

  Stream<bool> get scanning => ble.FlutterBluePlus.isScanning;

  bool get isScanning => ble.FlutterBluePlus.isScanningNow;

  Future<void> select(BoatScanDevice target) async {
    _device = target.device;
    _label = target.name;
  }

  Future<bool> ensurePermissions() async {
    if (kIsWeb) return true;
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final statuses = await <Permission>[
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
          Permission.locationWhenInUse,
        ].request();
        await lockLandscape();
        final scan = statuses[Permission.bluetoothScan];
        final connect = statuses[Permission.bluetoothConnect];
        if (scan != null && connect != null) {
          return scan.isGranted && connect.isGranted;
        }
        return statuses.values.any((status) => status.isGranted);
      }
      if (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS) {
        final status = await Permission.bluetooth.request();
        return status.isGranted || status.isLimited;
      }
    } catch (_) {
      // Desktop / Windows may not implement these permissions.
    }
    return true;
  }

  Future<void> startScan({
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final allowed = await ensurePermissions();
    if (!allowed) {
      throw StateError('Bluetooth permission was denied');
    }
    if (!await ble.FlutterBluePlus.isSupported) {
      throw StateError('Bluetooth is not supported on this device');
    }

    final adapter = await ble.FlutterBluePlus.adapterState.first;
    if (adapter != ble.BluetoothAdapterState.on) {
      if (defaultTargetPlatform == TargetPlatform.android) {
        await ble.FlutterBluePlus.turnOn();
        await lockLandscape();
      } else {
        throw StateError('Turn Bluetooth on and try again');
      }
    }

    await stopScan();
    _scanSub = ble.FlutterBluePlus.onScanResults.listen(
      (results) {
        final devices = results
            .map(
              (result) => BoatScanDevice(
                id: result.device.remoteId.str,
                name: _deviceName(result),
                rssi: result.rssi,
                device: result.device,
              ),
            )
            .toList()
          ..sort((a, b) => b.rssi.compareTo(a.rssi));
        if (!_scanController.isClosed) {
          _scanController.add(devices);
        }
      },
      onError: (Object error) {
        _error = error.toString();
      },
    );
    ble.FlutterBluePlus.cancelWhenScanComplete(_scanSub!);

    await ble.FlutterBluePlus.startScan(
      timeout: timeout,
      androidUsesFineLocation: true,
    );
  }

  Future<void> stopScan() async {
    if (ble.FlutterBluePlus.isScanningNow) {
      await ble.FlutterBluePlus.stopScan();
    }
    await _scanSub?.cancel();
    _scanSub = null;
  }

  @override
  Future<void> connect() async {
    final device = _device;
    if (device == null) {
      throw StateError('Select a Bluetooth device first');
    }

    await stopScan();
    await disconnect();
    _error = null;
    _setStatus(LinkStatus.connecting);
    _label = device.platformName.isEmpty ? device.remoteId.str : device.platformName;

    _connectionSub = device.connectionState.listen((state) {
      if (state == ble.BluetoothConnectionState.disconnected &&
          _status == LinkStatus.connected) {
        _writeChar = null;
        _setStatus(LinkStatus.disconnected);
      }
    });
    device.cancelWhenDisconnected(_connectionSub!, delayed: true, next: true);

    try {
      await device.connect(
        license: ble.License.nonprofit,
        timeout: const Duration(seconds: 20),
      );
      final services = await device.discoverServices();
      _writeChar = _pickWriteCharacteristic(services);
      if (_writeChar == null) {
        throw StateError('No writable BLE characteristic found');
      }

      final notify = _pickNotifyCharacteristic(services);
      if (notify != null) {
        final sub = notify.onValueReceived.listen((value) {
          _inboundController.add(String.fromCharCodes(value));
        });
        device.cancelWhenDisconnected(sub);
        await notify.setNotifyValue(true);
      }

      _setStatus(LinkStatus.connected);
    } catch (error) {
      _error = error.toString();
      _setStatus(LinkStatus.failed);
      await disconnect();
      rethrow;
    }
  }

  @override
  Future<void> disconnect() async {
    await _connectionSub?.cancel();
    _connectionSub = null;
    _writeChar = null;
    final device = _device;
    if (device != null && device.isConnected) {
      try {
        await device.disconnect();
      } catch (_) {}
    }
    if (_status != LinkStatus.disconnected) {
      _setStatus(LinkStatus.disconnected);
    }
  }

  @override
  Future<void> sendCommand(BoatCommand command) async {
    final characteristic = _writeChar;
    if (characteristic == null || _status != LinkStatus.connected) {
      throw StateError('Bluetooth is not connected');
    }
    final withoutResponse = characteristic.properties.writeWithoutResponse;
    await characteristic.write(
      command.toBytes(),
      withoutResponse: withoutResponse,
    );
  }

  ble.BluetoothCharacteristic? _pickWriteCharacteristic(
    List<ble.BluetoothService> services,
  ) {
    ble.BluetoothCharacteristic? fallback;
    for (final service in services) {
      for (final characteristic in service.characteristics) {
        if (characteristic.characteristicUuid == _nusRx ||
            (service.uuid == _nusService &&
                (characteristic.properties.writeWithoutResponse ||
                    characteristic.properties.write))) {
          return characteristic;
        }
        final props = characteristic.properties;
        if (fallback == null && (props.writeWithoutResponse || props.write)) {
          fallback = characteristic;
        }
      }
    }
    return fallback;
  }

  ble.BluetoothCharacteristic? _pickNotifyCharacteristic(
    List<ble.BluetoothService> services,
  ) {
    for (final service in services) {
      for (final characteristic in service.characteristics) {
        if (characteristic.characteristicUuid == _nusTx) {
          return characteristic;
        }
      }
    }
    for (final service in services) {
      for (final characteristic in service.characteristics) {
        if (characteristic.properties.notify || characteristic.properties.indicate) {
          return characteristic;
        }
      }
    }
    return null;
  }

  String _deviceName(ble.ScanResult result) {
    final advertised = result.advertisementData.advName.trim();
    if (advertised.isNotEmpty) return advertised;
    final platform = result.device.platformName.trim();
    if (platform.isNotEmpty) return platform;
    return 'Unknown · ${result.device.remoteId.str}';
  }

  void _setStatus(LinkStatus next) {
    _status = next;
    if (!_statusController.isClosed) {
      _statusController.add(next);
    }
  }
}
