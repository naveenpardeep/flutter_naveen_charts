import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/chart_theme.dart';
import '../core/chart_utils.dart';
import '../core/legend.dart';
import '../core/plot_frame.dart';

class ParliamentParty {
  const ParliamentParty(this.label, this.seats, {this.color});
  final String label;
  final int seats;
  final Color? color;
}

class ParliamentSeat {
  const ParliamentSeat(this.row, this.angle);

  /// 0 = innermost arc.
  final int row;

  /// Radians: pi = far left, 0 = far right.
  final double angle;
}

/// Radius (0..1) of a seat row.
double parliamentRowRadius(int row, int rows) => .35 + .65 * (row + 1) / rows;

/// Distributes [total] seats over [rows] concentric arcs and orders them
/// left to right so that parties form wedges.
List<ParliamentSeat> parliamentSeats(int total, int rows) {
  if (total <= 0) return [];
  final r = math.max(1, rows);
  final radii = [for (var k = 0; k < r; k++) parliamentRowRadius(k, r)];
  final sumR = radii.fold<double>(0, (a, b) => a + b);
  final counts = [for (final x in radii) (total * x / sumR).round()];
  var diff = total - counts.fold<int>(0, (a, b) => a + b);
  var i = 0;
  while (diff != 0) {
    final idx = r - 1 - (i % r);
    if (diff > 0) {
      counts[idx]++;
      diff--;
    } else if (counts[idx] > 0) {
      counts[idx]--;
      diff++;
    }
    i++;
  }
  final seats = <ParliamentSeat>[];
  for (var k = 0; k < r; k++) {
    final n = counts[k];
    for (var s = 0; s < n; s++) {
      seats.add(ParliamentSeat(k, n == 1 ? math.pi / 2 : math.pi - s * math.pi / (n - 1)));
    }
  }
  seats.sort((a, b) {
    final c = b.angle.compareTo(a.angle);
    return c != 0 ? c : a.row.compareTo(b.row);
  });
  return seats;
}

/// Parliament (hemicycle) chart: one dot per seat, grouped by party.
class ParliamentChart extends StatelessWidget {
  const ParliamentChart({
    super.key,
    required this.parties,
    this.rows,
    this.showMajorityLine = true,
    this.centerText,
    this.showLegend = true,
    this.aspectRatio = 1.9,
    this.theme,
    this.animationDuration = const Duration(milliseconds: 1000),
  });
  final List<ParliamentParty> parties;

  /// Number of arcs; null chooses one from the seat count.
  final int? rows;
  final bool showMajorityLine;

  /// Text in the middle (defaults to the total number of seats).
  final String? centerText;
  final bool showLegend;
  final double aspectRatio;
  final ChartTheme? theme;
  final Duration animationDuration;

  @override
  Widget build(BuildContext context) {
    final t = theme ?? ChartTheme.of(context);
    return chartShell(
      theme: t,
      aspectRatio: aspectRatio,
      duration: animationDuration,
      legend: showLegend ? [for (var i = 0; i < parties.length; i++) LegendItem('${parties[i].label} (${parties[i].seats})', parties[i].color ?? t.colorAt(i))] : null,
      builder: (p, ptr) => _ParliamentPainter(this, t, p, ptr),
    );
  }
}

class _ParliamentPainter extends CustomPainter {
  _ParliamentPainter(this.w, this.theme, this.progress, this.pointer);
  final ParliamentChart w;
  final ChartTheme theme;
  final double progress;
  final Offset? pointer;

  @override
  void paint(Canvas canvas, Size size) {
    final total = w.parties.fold<int>(0, (a, p) => a + math.max(0, p.seats));
    if (total <= 0) return;
    final rows = w.rows ?? math.max(2, math.sqrt(total / 6).round());
    final seats = parliamentSeats(total, rows);
    final owner = <int>[];
    for (var i = 0; i < w.parties.length; i++) {
      for (var s = 0; s < w.parties[i].seats; s++) {
        owner.add(i);
      }
    }
    final c = Offset(size.width / 2, size.height * .9);
    final R = math.min(size.width / 2 - 10, size.height * .84);
    if (R <= 20) return;
    Offset pos(ParliamentSeat s) {
      final rad = R * parliamentRowRadius(s.row, rows);
      return c + Offset(math.cos(s.angle) * rad, -math.sin(s.angle) * rad);
    }

    final rowGap = R * .65 / rows;
    final perRow = List<int>.filled(rows, 0);
    for (final s in seats) {
      perRow[s.row]++;
    }
    var minArc = double.infinity;
    for (var k = 0; k < rows; k++) {
      if (perRow[k] > 1) minArc = math.min(minArc, math.pi * R * parliamentRowRadius(k, rows) / (perRow[k] - 1));
    }
    final dot = math.min(rowGap, minArc.isFinite ? minArc : rowGap) * .42;

    int? hover;
    final ptr = pointer;
    if (ptr != null && progress >= 1) {
      var best = dot + 4;
      for (var i = 0; i < seats.length; i++) {
        final d = (pos(seats[i]) - ptr).distance;
        if (d < best) {
          best = d;
          hover = i;
        }
      }
    }
    final hoverParty = hover == null ? null : owner[hover];
    for (var i = 0; i < seats.length; i++) {
      final t = (progress * seats.length - i).clamp(0.0, 1.0).toDouble();
      if (t <= 0) continue;
      final party = w.parties[owner[i]];
      var color = party.color ?? theme.colorAt(owner[i]);
      if (hoverParty != null && hoverParty != owner[i]) color = color.faded(.28);
      canvas.drawCircle(pos(seats[i]), dot * t, Paint()..color = color);
    }
    if (w.showMajorityLine) {
      final need = total ~/ 2 + 1;
      canvas.drawPath(
          dashPath(Path()
            ..moveTo(c.dx, c.dy - R * .3)
            ..lineTo(c.dx, c.dy - R * 1.04)),
          Paint()
            ..color = theme.axisColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2);
      paintText(canvas, 'Majority: $need', Offset(c.dx, c.dy - R * 1.06), theme.labelStyle, align: Alignment.bottomCenter);
    }
    paintText(canvas, w.centerText ?? '$total', c + const Offset(0, -6),
        TextStyle(color: theme.textColor, fontSize: math.min(34.0, R * .22), fontWeight: FontWeight.bold), align: Alignment.bottomCenter);
    paintText(canvas, 'seats', c + const Offset(0, -4), theme.labelStyle, align: Alignment.topCenter);
    if (hover != null && ptr != null) {
      final p = w.parties[owner[hover]];
      paintTooltip(canvas, size, ptr, theme, title: p.label, rows: [
        TooltipRow('${p.seats} seats (${(p.seats / total * 100).toStringAsFixed(1)}%)', color: p.color ?? theme.colorAt(owner[hover])),
      ]);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
