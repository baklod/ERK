import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BoatJoystick extends StatefulWidget {
  const BoatJoystick({
    super.key,
    required this.onChanged,
    this.enabled = true,
    this.size = 260,
  });

  final void Function(double throttle, double steering) onChanged;
  final bool enabled;
  final double size;

  @override
  State<BoatJoystick> createState() => _BoatJoystickState();
}

class _BoatJoystickState extends State<BoatJoystick> {
  Offset _offset = Offset.zero;

  static const _deadzone = 0.08;

  void _update(Offset local, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = _travel(size);
    var delta = local - center;
    if (delta.distance > radius) {
      delta = Offset.fromDirection(delta.direction, radius);
    }
    setState(() => _offset = delta);

    var steering = delta.dx / radius;
    var throttle = -delta.dy / radius;
    if (steering.abs() < _deadzone) steering = 0;
    if (throttle.abs() < _deadzone) throttle = 0;
    widget.onChanged(throttle.clamp(-1.0, 1.0), steering.clamp(-1.0, 1.0));
  }

  void _reset() {
    setState(() => _offset = Offset.zero);
    widget.onChanged(0, 0);
  }

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: widget.enabled ? 1 : 0.35,
      child: IgnorePointer(
        ignoring: !widget.enabled,
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = Size(constraints.maxWidth, constraints.maxHeight);
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (details) {
                  HapticFeedback.selectionClick();
                  _update(details.localPosition, size);
                },
                onPanUpdate: (details) => _update(details.localPosition, size),
                onPanEnd: (_) => _reset(),
                onPanCancel: _reset,
                child: CustomPaint(
                  painter: _JoystickPainter(offset: _offset),
                  child: const SizedBox.expand(),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

double _travel(Size size) => size.shortestSide * 0.26;

class _JoystickPainter extends CustomPainter {
  _JoystickPainter({required this.offset});

  final Offset offset;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outer = size.shortestSide / 2 - 2;
    final knob = (size.shortestSide * 0.13).clamp(22.0, 36.0);
    final stick = center + offset;

    _drawBase(canvas, center, outer);
    _drawGuide(canvas, center, outer - 34);
    _drawBoot(canvas, center, stick, knob);
    _drawKnob(canvas, stick, knob);
  }

  void _drawGuide(Canvas canvas, Offset center, double radius) {
    const style = TextStyle(
      color: Color(0xFFD5E0E6),
      fontSize: 11,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.8,
    );
    _drawMark(canvas, 'FWD', center + Offset(0, -radius), style);
    _drawMark(canvas, 'REV', center + Offset(0, radius), style);
    _drawMark(canvas, 'L', center + Offset(-radius, 0), style);
    _drawMark(canvas, 'R', center + Offset(radius, 0), style);
  }

  void _drawMark(Canvas canvas, String text, Offset at, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, at - Offset(painter.width / 2, painter.height / 2));
  }

  void _drawBase(Canvas canvas, Offset center, double outer) {
    final ring = Rect.fromCircle(center: center, radius: outer);
    canvas.drawCircle(
      center + const Offset(0, 8),
      outer * 0.9,
      Paint()
        ..color = const Color(0x88000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
    canvas.drawCircle(
      center,
      outer,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFC5D0D6), Color(0xFF5E6C74), Color(0xFF243038), Color(0xFF8C9AA2)],
          stops: [0, 0.35, 0.72, 1],
        ).createShader(ring),
    );
    canvas.drawCircle(center, outer - 8, Paint()..color = const Color(0xFF070B0E));
    canvas.drawCircle(
      center,
      outer - 14,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFF24323A), Color(0xFF10181C), Color(0xFF05080A)],
          stops: [0.2, 0.72, 1],
        ).createShader(Rect.fromCircle(center: center, radius: outer - 14)),
    );
    canvas.drawCircle(
      center,
      outer - 16,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x55000000), Color(0x00000000), Color(0x66FFFFFF)],
        ).createShader(ring),
    );

    final tick = Paint()
      ..color = const Color(0xFF5C727C)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (final angle in const [0.0, 1.5708, 3.1416, 4.7124]) {
      canvas.drawLine(
        center + Offset.fromDirection(angle, outer - 28),
        center + Offset.fromDirection(angle, outer - 18),
        tick,
      );
    }
  }

  void _drawBoot(Canvas canvas, Offset center, Offset stick, double knob) {
    final lean = stick - center;
    for (var fold = 4; fold >= 0; fold--) {
      final t = fold / 4;
      final at = center + lean * (0.18 + (1 - t) * 0.28);
      final width = knob * (1.55 - t * 0.45);
      final height = knob * (0.62 - t * 0.12);
      canvas.drawOval(
        Rect.fromCenter(center: at + const Offset(0, 2), width: width, height: height),
        Paint()..color = const Color(0xFF050505),
      );
      canvas.drawOval(
        Rect.fromCenter(center: at, width: width, height: height),
        Paint()..color = fold.isEven ? const Color(0xFF1A1A1A) : const Color(0xFF2C2C2C),
      );
      canvas.drawArc(
        Rect.fromCenter(center: at + Offset(0, -height * 0.12), width: width * 0.82, height: height * 0.45),
        3.4,
        2.6,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = const Color(0xFF4A4A4A),
      );
    }

    final span = Rect.fromCenter(
      center: center + lean / 2,
      width: lean.dx.abs().clamp(12.0, double.infinity),
      height: lean.dy.abs().clamp(12.0, double.infinity),
    );
    canvas.drawLine(
      center,
      stick,
      Paint()
        ..strokeWidth = knob * 0.34
        ..strokeCap = StrokeCap.round
        ..shader = const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFF101010), Color(0xFF8A8A8A), Color(0xFF161616)],
        ).createShader(span),
    );
  }

  void _drawKnob(Canvas canvas, Offset stick, double knob) {
    canvas.drawOval(
      Rect.fromCenter(
        center: stick + Offset(knob * 0.12, knob * 0.85),
        width: knob * 1.5,
        height: knob * 0.48,
      ),
      Paint()
        ..color = const Color(0x66000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    final face = Rect.fromCircle(center: stick, radius: knob);
    canvas.drawCircle(
      stick,
      knob,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.35, -0.4),
          colors: [Color(0xFF8E98A2), Color(0xFF3A424A), Color(0xFF15191C)],
          stops: [0, 0.55, 1],
        ).createShader(face),
    );

    const notches = 8;
    for (var i = 0; i < notches; i++) {
      final angle = i * 6.28318 / notches;
      final slot = stick + Offset.fromDirection(angle, knob * 0.62);
      canvas.save();
      canvas.translate(slot.dx, slot.dy);
      canvas.rotate(angle);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: knob * 0.16, height: knob * 0.3),
          Radius.circular(knob * 0.08),
        ),
        Paint()..color = const Color(0xFF0C0F12),
      );
      canvas.restore();
    }

    canvas.drawCircle(
      stick,
      knob * 0.46,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.3, -0.35),
          colors: [Color(0xFFD5DCE2), Color(0xFF6A737C), Color(0xFF2A3138)],
          stops: [0, 0.45, 1],
        ).createShader(Rect.fromCircle(center: stick, radius: knob * 0.46)),
    );
    canvas.drawCircle(stick, knob * 0.16, Paint()..color = const Color(0xFF1A1F24));
    canvas.drawCircle(
      stick + Offset(-knob * 0.05, -knob * 0.05),
      knob * 0.05,
      Paint()..color = const Color(0x99FFFFFF),
    );
  }

  @override
  bool shouldRepaint(covariant _JoystickPainter oldDelegate) {
    return oldDelegate.offset != offset;
  }
}
