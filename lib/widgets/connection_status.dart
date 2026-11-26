import 'package:controller/services/boat_connection.dart';
import 'package:flutter/material.dart';

class ConnectionStatus extends StatelessWidget {
  const ConnectionStatus({
    super.key,
    required this.status,
    required this.label,
    this.kind,
  });

  final LinkStatus status;
  final String label;
  final ConnectionKind? kind;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      LinkStatus.connected => const Color(0xFF3DDC97),
      LinkStatus.connecting => const Color(0xFFFFB020),
      LinkStatus.failed => const Color(0xFFEF5350),
      LinkStatus.disconnected => const Color(0xFF90A4AE),
    };
    final statusLabel = switch (status) {
      LinkStatus.connected => 'Connected',
      LinkStatus.connecting => 'Connecting',
      LinkStatus.failed => 'Failed',
      LinkStatus.disconnected => 'Disconnected',
    };
    final kindLabel = switch (kind) {
      ConnectionKind.wifi => 'Wi-Fi',
      ConnectionKind.bluetooth => 'Bluetooth',
      null => 'None',
    };

    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            '$kindLabel · $statusLabel · $label',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
}
