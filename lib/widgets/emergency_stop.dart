import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class EmergencyStop extends StatelessWidget {
  const EmergencyStop({
    super.key,
    required this.active,
    required this.onTriggered,
    required this.onReset,
    this.diameter = 148,
    this.showHint = true,
  });

  final bool active;
  final VoidCallback onTriggered;
  final VoidCallback onReset;
  final double diameter;
  final bool showHint;

  @override
  Widget build(BuildContext context) {
    final button = GestureDetector(
      onTap: () {
        HapticFeedback.heavyImpact();
        if (active) {
          onReset();
        } else {
          onTriggered();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: diameter,
        height: showHint ? diameter : double.infinity,
        margin: EdgeInsets.only(top: active ? 1 : 0),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: active
                ? const [Color(0xFFC62828), Color(0xFF8E1C1C)]
                : const [Color(0xFFE57373), Color(0xFFC62828)],
          ),
          border: Border(
            top: BorderSide(color: active ? const Color(0xFFEF9A9A) : const Color(0xFFFFCDD2)),
            bottom: const BorderSide(color: Color(0xFF7F1D1D)),
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0x44000000),
              offset: Offset(0, active ? 1 : 2),
              blurRadius: 3,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              active ? Icons.lock_reset : Icons.crisis_alert,
              color: Colors.white,
              size: diameter * 0.3,
            ),
            const SizedBox(height: 4),
            Text(
              active ? 'RESET' : 'E-STOP',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                fontSize: diameter < 120 ? 13 : 16,
              ),
            ),
          ],
        ),
      ),
    );

    if (!showHint) return button;

    return Column(
      children: [
        button,
        const SizedBox(height: 10),
        Text(
          active ? 'Motors locked — tap to reset' : 'Tap to cut power',
          style: TextStyle(
            color: active ? const Color(0xFFFF8A80) : Colors.white54,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
