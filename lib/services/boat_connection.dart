import 'package:controller/models/boat_command.dart';

enum ConnectionKind { wifi, bluetooth }

enum LinkStatus { disconnected, connecting, connected, failed }

abstract class BoatConnection {
  ConnectionKind get kind;

  String get label;

  LinkStatus get status;

  String? get lastError;

  Stream<LinkStatus> get statusStream;

  Stream<String> get inbound;

  Future<void> connect();

  Future<void> disconnect();

  Future<void> sendCommand(BoatCommand command);
}
