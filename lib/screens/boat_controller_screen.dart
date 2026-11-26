import 'dart:math' as math;

import 'package:controller/screens/connection_screen.dart';
import 'package:controller/services/connection_manager.dart';
import 'package:controller/widgets/boat_joystick.dart';
import 'package:controller/widgets/connection_status.dart';
import 'package:controller/widgets/conveyor_control.dart';
import 'package:controller/widgets/emergency_stop.dart';
import 'package:flutter/material.dart';

class BoatControllerScreen extends StatefulWidget {
  const BoatControllerScreen({super.key});

  @override
  State<BoatControllerScreen> createState() => _BoatControllerScreenState();
}

class _BoatControllerScreenState extends State<BoatControllerScreen> {
  final _manager = ConnectionManager.instance;
  bool _wasConnected = false;

  @override
  void initState() {
    super.initState();
    _wasConnected = _manager.isConnected;
    _manager.addListener(_onManager);
  }

  @override
  void dispose() {
    _manager.removeListener(_onManager);
    super.dispose();
  }

  void _onManager() {
    if (!mounted) return;
    if (_wasConnected && !_manager.isConnected) {
      final message = _manager.lastError != null
          ? 'Disconnected: ${_manager.lastError}'
          : 'Disconnected from the boat';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
    _wasConnected = _manager.isConnected;
  }

  Future<void> _disconnect() async {
    await _manager.disconnect();
  }

  Future<void> _openConnection() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ConnectionScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _manager,
      builder: (context, _) {
        final command = _manager.command;
        final live = !command.emergencyStop && _manager.isConnected;
        return Scaffold(
          backgroundColor: const Color(0xFF060E1A),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0E1C36),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF1E3A5F)),
                  ),
                  child: Row(
                    children: [
                      const Text(
                        'ERK',
                        style: TextStyle(
                          fontFamily: 'Orbitron',
                          color: Color(0xFF5B8DEF),
                          fontWeight: FontWeight.w700,
                          fontSize: 26,
                          letterSpacing: 1.4,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Eco Wave',
                        style: TextStyle(
                          fontFamily: 'Orbitron',
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 26,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ConnectionStatus(
                          status: _manager.status,
                          label: _manager.label,
                          kind: _manager.kind,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _manager.isConnected ? _disconnect : _openConnection,
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF3DDC97),
                          visualDensity: VisualDensity.compact,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: const Size(0, 32),
                        ),
                        icon: Icon(
                          _manager.isConnected ? Icons.link_off : Icons.link,
                          size: 18,
                        ),
                        label: Text(_manager.isConnected ? 'Disconnect' : 'Connect'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 4,
                        child: _Panel(
                          child: Row(
                            children: [
                              EmergencyStop(
                                active: command.emergencyStop,
                                diameter: 96,
                                showHint: false,
                                onTriggered: _manager.triggerEmergencyStop,
                                onReset: _manager.resetEmergencyStop,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ConveyorControl(
                                  value: command.conveyor,
                                  enabled: live,
                                  axis: Axis.vertical,
                                  onChanged: _manager.setConveyor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 5,
                        child: _Panel(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final size = math
                                  .min(constraints.maxWidth - 24, constraints.maxHeight - 36)
                                  .clamp(140.0, 280.0);
                              return Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  BoatJoystick(
                                    enabled: live,
                                    size: size,
                                    onChanged: (throttle, steering) {
                                      _manager.setDrive(
                                        throttle: throttle,
                                        steering: steering,
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'THR ${command.throttle.toStringAsFixed(2)}    STR ${command.steering.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontFeatures: [FontFeature.tabularFigures()],
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            ),
          ),
        );
      },
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF0C1830),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E3A5F)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: child,
      ),
    );
  }
}

