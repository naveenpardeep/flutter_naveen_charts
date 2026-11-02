import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'core/chart_canvas.dart';
import 'core/chart_theme.dart';
import 'core/chart_utils.dart';

class FunnelStage {
  const FunnelStage(this.label, this.value, {this.color});
  final String label;
  final double value;
  final Color? color;
}

/// Funnel chart; stage widths are proportional to their values.
class FunnelChart extends StatelessWidget {
  const FunnelChart({
    super.key,
    required this.stages,
    this.aspectRatio = 1.5,
    this.theme,
    this.animationDuration = const Duration(milliseconds: 900),
  });
  final List<FunnelStage> stages;
  final double aspectRatio;
  final ChartTheme? theme;
  final Duration animationDuration;

  @override
  Widget build(BuildContext context) {
    final t = theme ?? ChartTheme.of(context);
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: ChartCanvas(
        duration: animationDuration,
        interactive: false,
        builder: (p, _) => _FunnelPainter(stages, t, p),
      ),
    );
  }
}

class _FunnelPainter extends CustomPainter {
  _FunnelPainter(this.stages, this.theme, this.progress);
  final List<FunnelStage> stages;
  final ChartTheme theme;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final n = stages.length;
    if (n == 0) return;
    final maxV = stages.map((s) => s.value).reduce(math.max);
    if (maxV <= 0) return;
    const gap = 4.0;
    final h = (size.height - gap * (n - 1)) / n;
    final cx = size.width / 2;
    for (var i = 0; i < n; i++) {
      final s = stages[i];
      final topW = size.width * (s.value / maxV) * progress;
      final nextW = i < n - 1
          ? size.width * (stages[i + 1].value / maxV) * progress
          : topW * 0.75;
      final y = i * (h + gap);
      final path = Path()
        ..moveTo(cx - topW / 2, y)
        ..lineTo(cx + topW / 2, y)
        ..lineTo(cx + nextW / 2, y + h)
        ..lineTo(cx - nextW / 2, y + h)
        ..close();
      canvas.drawPath(path, Paint()..color = s.color ?? theme.colorAt(i));
      if (progress > .99) {
        final pct = (s.value / stages.first.value * 100).round();
        paintText(
            canvas,
            '${s.label} · ${formatNumber(s.value)} ($pct%)',
            Offset(cx, y + h / 2),
            const TextStyle(
                color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
            maxWidth: math.max(0.0, math.min(topW, nextW) - 8));
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
