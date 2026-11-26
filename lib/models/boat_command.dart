import 'dart:convert';

/// Wire protocol sent to the boat over Wi-Fi (JSON WebSocket) or BLE UART.
///
/// Newline-terminated JSON:
/// `{"t":0.00,"s":0.00,"c":0,"e":0}`
///
/// - [throttle] (`t`): -1.0 reverse … 1.0 forward
/// - [steering] (`s`): -1.0 left … 1.0 right
/// - [conveyor] (`c`): -1 reverse, 0 stop, 1 forward
/// - [emergencyStop] (`e`): 1 latches motors off until reset

enum ConveyorDirection {
  reverse(-1),
  stop(0),
  forward(1);

  const ConveyorDirection(this.value);
  final int value;

  static ConveyorDirection fromValue(int value) {
    return ConveyorDirection.values.firstWhere(
      (direction) => direction.value == value,
      orElse: () => ConveyorDirection.stop,
    );
  }
}

class BoatCommand {
  const BoatCommand({
    this.throttle = 0,
    this.steering = 0,
    this.conveyor = ConveyorDirection.stop,
    this.emergencyStop = false,
  });

  static const idle = BoatCommand();

  static const stopped = BoatCommand(emergencyStop: true);

  final double throttle;
  final double steering;
  final ConveyorDirection conveyor;
  final bool emergencyStop;

  BoatCommand copyWith({
    double? throttle,
    double? steering,
    ConveyorDirection? conveyor,
    bool? emergencyStop,
  }) {
    return BoatCommand(
      throttle: throttle ?? this.throttle,
      steering: steering ?? this.steering,
      conveyor: conveyor ?? this.conveyor,
      emergencyStop: emergencyStop ?? this.emergencyStop,
    );
  }

  BoatCommand clamped() {
    return BoatCommand(
      throttle: throttle.clamp(-1.0, 1.0),
      steering: steering.clamp(-1.0, 1.0),
      conveyor: conveyor,
      emergencyStop: emergencyStop,
    );
  }

  /// Compact JSON object matching the boat firmware parser.
  Map<String, Object> toJson() {
    final command = clamped();
    return {
      't': _round(command.throttle),
      's': _round(command.steering),
      'c': command.conveyor.value,
      'e': command.emergencyStop ? 1 : 0,
    };
  }

  String toWire() {
    final json = toJson();
    return '{"t":${json['t']},"s":${json['s']},"c":${json['c']},"e":${json['e']}}\n';
  }

  List<int> toBytes() => utf8.encode(toWire());

  static double _round(double value) => (value * 100).round() / 100;

  @override
  bool operator ==(Object other) {
    return other is BoatCommand &&
        other.throttle == throttle &&
        other.steering == steering &&
        other.conveyor == conveyor &&
        other.emergencyStop == emergencyStop;
  }

  @override
  int get hashCode => Object.hash(throttle, steering, conveyor, emergencyStop);
}
