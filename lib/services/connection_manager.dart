import 'dart:async';

import 'package:controller/models/boat_command.dart';
import 'package:controller/services/bluetooth_service.dart';
import 'package:controller/services/boat_connection.dart';
import 'package:controller/services/wifi_service.dart';
import 'package:flutter/foundation.dart';

class ConnectionManager extends ChangeNotifier {
  ConnectionManager({
    WifiService? wifi,
    BluetoothService? bluetooth,
  })  : wifi = wifi ?? WifiService(),
        bluetooth = bluetooth ?? BluetoothService() {
    _wifiSub = this.wifi.statusStream.listen(_onStatus);
    _btSub = this.bluetooth.statusStream.listen(_onStatus);
  }

  static final ConnectionManager instance = ConnectionManager();

  final WifiService wifi;
  final BluetoothService bluetooth;

  BoatConnection? _active;
  BoatCommand _command = BoatCommand.idle;
  Timer? _heartbeat;
  StreamSubscription<LinkStatus>? _wifiSub;
  StreamSubscription<LinkStatus>? _btSub;
  StreamSubscription<LinkStatus>? _activeSub;
  StreamSubscription<String>? _inboundSub;
  DateTime? _ignoreBoatStopUntil;

  BoatConnection? get active => _active;

  BoatCommand get command => _command;

  LinkStatus get status => _active?.status ?? LinkStatus.disconnected;

  ConnectionKind? get kind => _active?.kind;

  String get label => _active?.label ?? 'Not connected';

  String? get lastError => _active?.lastError;

  bool get isConnected => status == LinkStatus.connected;

  bool get isBusy => status == LinkStatus.connecting;

  Future<void> connectWifi({
    required String host,
    required int port,
    String path = '/',
    String? name,
  }) async {
    await disconnect();
    wifi.configure(host: host, port: port, path: path, name: name);
    _active = wifi;
    _listenActive();
    notifyListeners();
    try {
      await wifi.connect();
      _startHeartbeat();
    } finally {
      notifyListeners();
    }
  }

  Future<void> connectBluetooth(BoatScanDevice device) async {
    await disconnect();
    await bluetooth.select(device);
    _active = bluetooth;
    _listenActive();
    notifyListeners();
    try {
      await bluetooth.connect();
      _startHeartbeat();
    } finally {
      notifyListeners();
    }
  }

  Future<void> disconnect() async {
    _heartbeat?.cancel();
    _heartbeat = null;
    _command = BoatCommand.idle;
    final current = _active;
    _active = null;
    await _activeSub?.cancel();
    await _inboundSub?.cancel();
    _activeSub = null;
    _inboundSub = null;
    if (current != null) {
      try {
        await current.disconnect();
      } catch (_) {}
    }
    notifyListeners();
  }

  void setDrive({required double throttle, required double steering}) {
    if (_command.emergencyStop) return;
    _command = _command.copyWith(
      throttle: throttle.clamp(-1.0, 1.0),
      steering: steering.clamp(-1.0, 1.0),
    );
    notifyListeners();
    unawaited(_sendNow());
  }

  void setConveyor(ConveyorDirection direction) {
    if (_command.emergencyStop) return;
    _command = _command.copyWith(conveyor: direction);
    notifyListeners();
    unawaited(_sendNow());
  }

  void triggerEmergencyStop() {
    _command = BoatCommand.stopped;
    notifyListeners();
    unawaited(_sendNow());
  }

  void resetEmergencyStop() {
    _ignoreBoatStopUntil = DateTime.now().add(const Duration(milliseconds: 500));
    _command = BoatCommand.idle;
    notifyListeners();
    unawaited(_sendPacket(BoatCommand.release));
  }

  void _onStatus(LinkStatus status) {
    if (status != LinkStatus.connected) {
      _heartbeat?.cancel();
      _heartbeat = null;
    }
    notifyListeners();
  }

  void _onBoatMessage(String message) {
    if (!message.contains('emergency_stop')) return;
    final ignoreUntil = _ignoreBoatStopUntil;
    if (ignoreUntil != null && DateTime.now().isBefore(ignoreUntil)) return;
    if (_command.emergencyStop) return;
    _command = BoatCommand.stopped;
    notifyListeners();
  }

  void _listenActive() {
    _activeSub?.cancel();
    _inboundSub?.cancel();
    final active = _active;
    _activeSub = active?.statusStream.listen(_onStatus);
    _inboundSub = active?.inbound.listen(_onBoatMessage);
  }

  void _startHeartbeat() {
    _heartbeat?.cancel();
    unawaited(_sendPacket(BoatCommand.statusQuery));
    _heartbeat = Timer.periodic(const Duration(milliseconds: 100), (_) {
      unawaited(_sendNow());
    });
  }

  Future<void> _sendNow() => _sendPacket(_command);

  Future<void> _sendPacket(BoatCommand command) async {
    final connection = _active;
    if (connection == null || connection.status != LinkStatus.connected) {
      return;
    }
    try {
      await connection.sendCommand(command);
    } catch (_) {}
  }

  @override
  void dispose() {
    _heartbeat?.cancel();
    _wifiSub?.cancel();
    _btSub?.cancel();
    _activeSub?.cancel();
    _inboundSub?.cancel();
    super.dispose();
  }
}
