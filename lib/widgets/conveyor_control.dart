import 'package:controller/models/boat_command.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ConveyorControl extends StatelessWidget {
  const ConveyorControl({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.axis = Axis.horizontal,
  });

  final ConveyorDirection value;
  final ValueChanged<ConveyorDirection> onChanged;
  final bool enabled;
  final Axis axis;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: IgnorePointer(
        ignoring: !enabled,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'CONVEYOR',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    letterSpacing: 2.4,
                    color: Colors.white70,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: axis == Axis.vertical
                  ? Column(
                      children: [
                        _pad(ConveyorDirection.forward, 'FWD', Icons.keyboard_arrow_up_rounded, const Color(0xFF5B8DEF)),
                        const SizedBox(height: 8),
                        _pad(ConveyorDirection.stop, 'STOP', Icons.stop_rounded, const Color(0xFFE6EEF2)),
                        const SizedBox(height: 8),
                        _pad(ConveyorDirection.reverse, 'REV', Icons.keyboard_arrow_down_rounded, const Color(0xFFFFB020)),
                      ],
                    )
                  : Row(
                      children: [
                        _pad(ConveyorDirection.reverse, 'REV', Icons.fast_rewind_rounded, const Color(0xFFFFB020)),
                        const SizedBox(width: 8),
                        _pad(ConveyorDirection.stop, 'STOP', Icons.stop_rounded, const Color(0xFFE6EEF2)),
                        const SizedBox(width: 8),
                        _pad(ConveyorDirection.forward, 'FWD', Icons.fast_forward_rounded, const Color(0xFF5B8DEF)),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pad(
    ConveyorDirection direction,
    String label,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: _ConveyorButton(
        label: label,
        icon: icon,
        selected: value == direction,
        color: color,
        blink: direction != ConveyorDirection.stop,
        onPressed: () {
          HapticFeedback.selectionClick();
          onChanged(direction);
        },
      ),
    );
  }
}

class _ConveyorButton extends StatefulWidget {
  const _ConveyorButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.blink,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final bool blink;
  final VoidCallback onPressed;

  @override
  State<_ConveyorButton> createState() => _ConveyorButtonState();
}

class _ConveyorButtonState extends State<_ConveyorButton> with SingleTickerProviderStateMixin {
  late final AnimationController _blink;

  @override
  void initState() {
    super.initState();
    _blink = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
    _syncBlink();
  }

  @override
  void didUpdateWidget(covariant _ConveyorButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncBlink();
  }

  void _syncBlink() {
    final active = widget.selected && widget.blink;
    if (active && !_blink.isAnimating) {
      _blink.repeat(reverse: true);
    } else if (!active && (_blink.isAnimating || _blink.value != 0)) {
      _blink.stop();
      _blink.value = 0;
    }
  }

  @override
  void dispose() {
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) => widget.onPressed(),
      child: AnimatedBuilder(
        animation: _blink,
        builder: (context, child) {
          final pulse = widget.selected && widget.blink ? _blink.value : 0.0;
          final shown = Color.lerp(widget.color, Colors.white, 0.15 + pulse * 0.55)!;
          final faceTop = Color.lerp(shown, Colors.white, 0.12)!;
          final faceBottom = Color.lerp(shown, Colors.black, 0.18)!;
          final ink = shown.computeLuminance() > 0.6 ? const Color(0xFF061422) : Colors.white;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 80),
            margin: EdgeInsets.only(top: widget.selected ? 1 : 0),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [faceTop, shown, faceBottom],
              ),
              border: Border(
                top: BorderSide(color: faceTop.withValues(alpha: 0.9)),
                bottom: BorderSide(color: faceBottom),
              ),
              boxShadow: [
                BoxShadow(
                  color: shown.withValues(alpha: widget.selected && widget.blink ? 0.45 : 0.2),
                  offset: Offset(0, widget.selected ? 1 : 2),
                  blurRadius: widget.selected && widget.blink ? 8 : 3,
                ),
              ],
            ),
            child: IconTheme(
              data: IconThemeData(color: ink, size: 22),
              child: DefaultTextStyle(
                style: TextStyle(
                  color: ink,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
                child: child!,
              ),
            ),
          );
        },
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 22),
              const SizedBox(height: 2),
              Text(
                widget.label,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
