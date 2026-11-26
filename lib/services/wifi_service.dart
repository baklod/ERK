import 'dart:async';

import 'package:controller/models/boat_command.dart';
import 'package:controller/services/boat_connection.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class WifiService implements BoatConnection {
  WifiService({
    this.host = '192.168.4.1',
    this.port = 81,
    this.path = '/',
  });

  String host;
  int port;
  String path;
  String? name;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _inboundSub;
  final _statusController = StreamController<LinkStatus>.broadcast();
  final _inboundController = StreamController<String>.broadcast();
  LinkStatus _status = LinkStatus.disconnected;
  String? _error;

  @override
  ConnectionKind get kind => ConnectionKind.wifi;

  @override
  String get label => name ?? '$host:$port';

  @override
  LinkStatus get status => _status;

  @override
  String? get lastError => _error;

  @override
  Stream<LinkStatus> get statusStream => _statusController.stream;

  @override
  Stream<String> get inbound => _inboundController.stream;

  Uri get uri {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri(
      scheme: 'ws',
      host: host.trim(),
      port: port,
      path: normalizedPath,
    );
  }

  void configure({
    required String host,
    required int port,
    String path = '/',
    String? name,
  }) {
    this.host = host;
    this.port = port;
    this.path = path;
    this.name = name;
  }

  @override
  Future<void> connect() async {
    await disconnect();
    _error = null;
    _setStatus(LinkStatus.connecting);

    try {
      final channel = WebSocketChannel.connect(uri);
      _channel = channel;
      await channel.ready.timeout(const Duration(seconds: 8));
      _inboundSub = channel.stream.listen(
        (message) => _inboundController.add(message.toString()),
        onDone: () {
          if (_status == LinkStatus.connected) {
            _setStatus(LinkStatus.disconnected);
          }
        },
        onError: (Object error) {
          _error = error.toString();
          _setStatus(LinkStatus.failed);
        },
        cancelOnError: false,
      );
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
    await _inboundSub?.cancel();
    _inboundSub = null;
    try {
      await _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    if (_status != LinkStatus.disconnected) {
      _setStatus(LinkStatus.disconnected);
    }
  }

  @override
  Future<void> sendCommand(BoatCommand command) async {
    final channel = _channel;
    if (channel == null || _status != LinkStatus.connected) {
      throw StateError('Wi-Fi is not connected');
    }
    channel.sink.add(command.toWire());
  }

  void _setStatus(LinkStatus next) {
    _status = next;
    if (!_statusController.isClosed) {
      _statusController.add(next);
    }
  }
}
