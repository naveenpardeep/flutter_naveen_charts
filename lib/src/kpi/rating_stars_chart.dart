// Rating stars: an average rating with partly filled stars and a distribution.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/chart_canvas.dart';
import '../core/chart_theme.dart';
import '../core/chart_utils.dart';

/// A five-pointed star centred on [c] with outer radius [r].
Path starPath(Offset c, double r, {double inner = .46}) {
  final p = Path();
  for (var i = 0; i < 10; i++) {
    final a = -math.pi / 2 + i * math.pi / 5; // alternate outer and inner points
    final o = c + Offset.fromDirection(a, i.isEven ? r : r * inner);
    if (i == 0) {
      p.moveTo(o.dx, o.dy);
    } else {
      p.lineTo(o.dx, o.dy);
    }
  }
  return p..close();
}

/// Rating chart: the average [rating] as a big number with stars (the last one
/// partly filled, e.g. 4.3 fills 4 stars and 30 % of the fifth) and, when a
/// [distribution] is given, a bar per star level with its share of ratings -
/// the familiar app-store summary.
///
/// Hover a distribution bar for the exact count.
class RatingStarsChart extends StatelessWidget {
  const RatingStarsChart({
    super.key,
    required this.rating,
    this.maxStars = 5,
    this.ratingCount,
    this.distribution,
    this.starColor = const Color(0xFFFFB400),
    this.emptyColor,
    this.showDistribution = true,
    this.valueFormat,
    this.aspectRatio = 2.3,
    this.theme,
    this.animationDuration = const Duration(milliseconds: 900),
  });

  /// Average rating, 0 .. [maxStars].
  final double rating;
  final int maxStars;

  /// Total number of ratings, written under the stars.
  final int? ratingCount;

  /// Number of ratings per level, index 0 = 1 star ... last = [maxStars].
  final List<double>? distribution;
  final Color starColor;

  /// Colour of empty stars (default: theme grid colour).
  final Color? emptyColor;
  final bool showDistribution;
  final String Function(double)? valueFormat;
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
        builder: (p, ptr) => _StarsPainter(this, t, p, ptr),
      ),
    );
  }
}

class _StarsPainter extends CustomPainter {
  _StarsPainter(this.w, this.theme, this.progress, this.pointer);
  final RatingStarsChart w;
  final ChartTheme theme;
  final double progress;
  final Offset? pointer;

  @override
  void paint(Canvas canvas, Size size) {
    final n = w.maxStars;
    if (n < 1) return;
    final fmt = w.valueFormat ?? ((double v) => v.toStringAsFixed(1));
    final dist = w.distribution;
    final hasDist = w.showDistribution && dist != null && dist.isNotEmpty;
    final empty = w.emptyColor ?? theme.gridColor;

    // ---- 1. two columns: summary on the left, distribution on the right
    final left = Rect.fromLTWH(0, 0, hasDist ? size.width * .42 : size.width, size.height);
    final right = Rect.fromLTWH(left.right + 12, 4, size.width - left.right - 12, size.height - 8);

    // ---- 2. big number, stars (last one partly filled) and the count
    final big = math.min(left.height * .36, 56.0);
    final starR = math.min((left.width - 16) / n / 2, left.height * .11);
    final shown = w.rating * progress;
    final blockH = big * 1.1 + 8 + starR * 2 + (w.ratingCount != null ? 22 : 0);
    var y = left.center.dy - blockH / 2;
    paintText(canvas, fmt(shown), Offset(left.center.dx, y + big * .55), TextStyle(color: theme.textColor, fontSize: big, fontWeight: FontWeight.w800));
    y += big * 1.1 + 8;
    final rowW = starR * 2 * n;
    for (var i = 0; i < n; i++) {
      final c = Offset(left.center.dx - rowW / 2 + starR + i * starR * 2, y + starR);
      final fill = (shown - i).clamp(0.0, 1.0).toDouble();
      canvas.drawPath(starPath(c, starR * .95), Paint()..color = empty);
      if (fill > 0) {
        // clip to the filled share of the star's width
        canvas.save();
        canvas.clipRect(Rect.fromLTWH(c.dx - starR, c.dy - starR, starR * 2 * fill, starR * 2));
        canvas.drawPath(starPath(c, starR * .95), Paint()..color = w.starColor);
        canvas.restore();
      }
    }
    if (w.ratingCount != null) {
      paintText(canvas, '${formatNumber(w.ratingCount!.toDouble())} ratings', Offset(left.center.dx, y + starR * 2 + 14), theme.labelStyle);
    }

    // ---- 3. distribution: one bar per level, highest level on top
    if (hasDist) {
      final total = dist.fold<double>(0, (a, b) => a + b);
      final maxV = dist.reduce(math.max);
      final rowH = math.min(26.0, right.height / n);
      final y0 = right.center.dy - rowH * n / 2;
      int? hover;
      final ptr = pointer;
      for (var k = 0; k < n; k++) {
        final level = n - k; // 5, 4, ... 1
        final v = level - 1 < dist.length ? dist[level - 1] : 0.0;
        final cy = y0 + (k + .5) * rowH;
        if (ptr != null && progress >= 1 && ptr.dy >= cy - rowH / 2 && ptr.dy < cy + rowH / 2 && ptr.dx >= right.left - 12) hover = level;
        paintText(canvas, '$level', Offset(right.left + 6, cy), theme.labelStyle.copyWith(color: theme.textColor), align: Alignment.centerRight);
        canvas.drawPath(starPath(Offset(right.left + 16, cy), 6), Paint()..color = w.starColor);
        final trackL = right.left + 28, trackR = right.right - 40;
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTRB(trackL, cy - 4, trackR, cy + 4), const Radius.circular(4)), Paint()..color = empty);
        if (maxV > 0) {
          canvas.drawRRect(
              RRect.fromRectAndRadius(Rect.fromLTRB(trackL, cy - 4, trackL + (trackR - trackL) * v / maxV * progress, cy + 4), const Radius.circular(4)),
              Paint()..color = hover == level ? Color.lerp(w.starColor, Colors.white, .25)! : w.starColor);
        }
        paintText(canvas, total <= 0 ? '0%' : '${(v / total * 100).round()}%', Offset(right.right, cy), theme.labelStyle, align: Alignment.centerRight);
      }
      if (hover != null && ptr != null) {
        final v = hover - 1 < dist.length ? dist[hover - 1] : 0.0;
        paintTooltip(canvas, size, ptr, theme, title: '$hover star${hover == 1 ? '' : 's'}', rows: [
          TooltipRow('${formatNumber(v)} ratings', color: w.starColor),
          TooltipRow('${total <= 0 ? 0 : (v / total * 100).toStringAsFixed(1)}% of all'),
        ]);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
