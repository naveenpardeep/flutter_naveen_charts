import 'package:flutter/material.dart';

typedef PainterBuilder = CustomPainter Function(
    double progress, Offset? pointer);

/// Hosts a chart painter: runs the intro animation and tracks the
/// hover / touch position, passing both to [builder] on every frame.
class ChartCanvas extends StatefulWidget {
  const ChartCanvas({
    super.key,
    required this.builder,
    this.duration = const Duration(milliseconds: 900),
    this.curve = Curves.easeOutCubic,
    this.interactive = true,
  });

  final PainterBuilder builder;
  final Duration duration;
  final Curve curve;
  final bool interactive;

  @override
  State<ChartCanvas> createState() => _ChartCanvasState();
}

class _ChartCanvasState extends State<ChartCanvas>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl =
      AnimationController(vsync: this, duration: widget.duration);
  Offset? _pointer;

  @override
  void initState() {
    super.initState();
    if (widget.duration == Duration.zero) {
      _ctrl.value = 1;
    } else {
      _ctrl.forward();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _set(Offset? o) => setState(() => _pointer = o);

  @override
  Widget build(BuildContext context) {
    final chart = RepaintBoundary(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => CustomPaint(
          size: Size.infinite,
          painter: widget.builder(widget.curve.transform(_ctrl.value),
              widget.interactive ? _pointer : null),
        ),
      ),
    );
    if (!widget.interactive) return chart;
    return MouseRegion(
      onHover: (e) => _set(e.localPosition),
      onExit: (_) => _set(null),
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (e) => _set(e.localPosition),
        onPointerMove: (e) => _set(e.localPosition),
        child: chart,
      ),
    );
  }
}
