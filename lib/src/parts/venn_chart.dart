import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/chart_theme.dart';
import '../core/chart_utils.dart';
import '../core/plot_frame.dart';

class VennSet {
  const VennSet(this.label, this.size, {this.color});
  final String label;

  /// Total size of the set (including the parts it shares with other sets).
  final double size;
  final Color? color;
}

/// Size of the overlap of the sets at [sets] (indexes into `VennChart.sets`).
/// Give every pair; for three sets also give the triple overlap.
class VennOverlap {
  const VennOverlap(this.sets, this.size);
  final List<int> sets;
  final double size;
}

/// Area of the lens where two circles of radii [r1], [r2] with centres [d] apart overlap.
double lensArea(double r1, double r2, double d) {
  if (d >= r1 + r2) return 0;
  if (d <= (r1 - r2).abs()) return math.pi * math.min(r1, r2) * math.min(r1, r2);
  final a = r1 * r1 * math.acos((d * d + r1 * r1 - r2 * r2) / (2 * d * r1));
  final b = r2 * r2 * math.acos((d * d + r2 * r2 - r1 * r1) / (2 * d * r2));
  final c = .5 * math.sqrt((-d + r1 + r2) * (d + r1 - r2) * (d - r1 + r2) * (d + r1 + r2));
  return a + b - c;
}

/// Centre distance that makes two circles overlap by [area].
double vennDistance(double r1, double r2, double area) {
  if (area <= 0) return r1 + r2;
  if (area >= math.pi * math.min(r1, r2) * math.min(r1, r2)) return (r1 - r2).abs();
  var lo = (r1 - r2).abs(), hi = r1 + r2;
  for (var i = 0; i < 60; i++) {
    final mid = (lo + hi) / 2;
    if (lensArea(r1, r2, mid) > area) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  return (lo + hi) / 2;
}

/// Venn / Euler diagram for two or three sets. Circle areas follow the set
/// sizes and, for two sets, the overlap area is exact; three sets use pairwise
/// overlaps as a close approximation. Hover a region for its size.
class VennChart extends StatelessWidget {
  const VennChart({
    super.key,
    required this.sets,
    required this.overlaps,
    this.fillOpacity = 0.35,
    this.showSetLabels = true,
    this.showRegionValues = true,
    this.valueFormat,
    this.aspectRatio = 1.4,
    this.theme,
    this.animationDuration = const Duration(milliseconds: 900),
  }) : assert(sets.length >= 1 && sets.length <= 3, 'VennChart supports 1 to 3 sets');
  final List<VennSet> sets;
  final List<VennOverlap> overlaps;
  final double fillOpacity;
  final bool showSetLabels;
  final bool showRegionValues;
  final String Function(double)? valueFormat;
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
        builder: (p, ptr) => _VennPainter(this, t, p, ptr));
  }
}

class _VennPainter extends CustomPainter {
  _VennPainter(this.w, this.theme, this.progress, this.pointer);
  final VennChart w;
  final ChartTheme theme;
  final double progress;
  final Offset? pointer;

  double _ov(List<int> idx) {
    final key = [...idx]..sort();
    for (final o in w.overlaps) {
      final k = [...o.sets]..sort();
      if (k.length == key.length && List.generate(k.length, (i) => k[i] == key[i]).every((b) => b)) return o.size;
    }
    return 0;
  }

  /// Size of the region that belongs to exactly the sets in [m].
  double _region(Set<int> m) {
    final n = w.sets.length;
    double s(int i) => w.sets[i].size;
    if (n == 1) return s(0);
    if (n == 2) {
      final ab = _ov([0, 1]);
      if (m.length == 2) return ab;
      return s(m.first) - ab;
    }
    final ab = _ov([0, 1]), ac = _ov([0, 2]), bc = _ov([1, 2]), abc = _ov([0, 1, 2]);
    if (m.length == 3) return abc;
    if (m.length == 1) {
      switch (m.first) {
        case 0:
          return s(0) - ab - ac + abc;
        case 1:
          return s(1) - ab - bc + abc;
        default:
          return s(2) - ac - bc + abc;
      }
    }
    if (m.containsAll([0, 1])) return ab - abc;
    if (m.containsAll([0, 2])) return ac - abc;
    return bc - abc;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final n = w.sets.length;
    final fmt = w.valueFormat ?? formatNumber;
    final r = [for (final s in w.sets) math.sqrt(math.max(s.size, 1e-9) / math.pi)];
    final cs = <Offset>[const Offset(0, 0)];
    if (n >= 2) {
      final dab = vennDistance(r[0], r[1], _ov([0, 1]));
      cs.add(Offset(dab, 0));
      if (n == 3) {
        final dac = vennDistance(r[0], r[2], _ov([0, 2])), dbc = vennDistance(r[1], r[2], _ov([1, 2]));
        final x = dab == 0 ? 0.0 : (dac * dac - dbc * dbc + dab * dab) / (2 * dab);
        cs.add(Offset(x, math.sqrt(math.max(0.0, dac * dac - x * x))));
      }
    }
    var minX = double.infinity, maxX = -double.infinity, minY = double.infinity, maxY = -double.infinity;
    for (var i = 0; i < n; i++) {
      minX = math.min(minX, cs[i].dx - r[i]);
      maxX = math.max(maxX, cs[i].dx + r[i]);
      minY = math.min(minY, cs[i].dy - r[i]);
      maxY = math.max(maxY, cs[i].dy + r[i]);
    }
    final pad = w.showSetLabels ? 26.0 : 10.0;
    final box = Rect.fromLTRB(pad, pad, size.width - pad, size.height - pad);
    final sc = math.min(box.width / (maxX - minX), box.height / (maxY - minY));
    final ox = box.center.dx - (minX + maxX) / 2 * sc, oy = box.center.dy - (minY + maxY) / 2 * sc;
    Offset pos(Offset u) => Offset(ox + u.dx * sc, oy + u.dy * sc);
    final centers = [for (final c in cs) pos(c)];
    final radii = [for (final x in r) x * sc * progress];
    Color color(int i) => w.sets[i].color ?? theme.colorAt(i);

    Set<int> member(Offset p) => {for (var i = 0; i < n; i++) if ((p - centers[i]).distance <= radii[i]) i};
    final ptr = pointer;
    Set<int>? hov;
    if (ptr != null && progress >= 1) {
      final m = member(ptr);
      if (m.isNotEmpty) hov = m;
    }

    for (var i = 0; i < n; i++) {
      canvas.drawCircle(centers[i], radii[i], Paint()..color = color(i).faded(w.fillOpacity));
    }
    if (hov != null) {
      Path? region;
      for (final i in hov) {
        final cp = Path()..addOval(Rect.fromCircle(center: centers[i], radius: radii[i]));
        region = region == null ? cp : Path.combine(PathOperation.intersect, region, cp);
      }
      for (var i = 0; i < n; i++) {
        if (hov.contains(i)) continue;
        region = Path.combine(PathOperation.difference, region!, Path()..addOval(Rect.fromCircle(center: centers[i], radius: radii[i])));
      }
      canvas.drawPath(region!, Paint()..color = theme.textColor.faded(.22));
    }
    for (var i = 0; i < n; i++) {
      canvas.drawCircle(centers[i], radii[i], Paint()
        ..color = color(i)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2);
    }

    final g = Offset(centers.fold<double>(0, (a, c) => a + c.dx) / n, centers.fold<double>(0, (a, c) => a + c.dy) / n);
    Offset away(Offset from, Offset to) {
      final d = to - from;
      return d.distance < 1e-6 ? Offset.zero : d / d.distance;
    }

    if (progress > .99) {
      if (w.showSetLabels) {
        for (var i = 0; i < n; i++) {
          final dir = n == 1 ? const Offset(0, -1) : away(g, centers[i]);
          paintText(canvas, w.sets[i].label, centers[i] + dir * (radii[i] + 6),
              theme.labelStyle.copyWith(color: theme.textColor, fontWeight: FontWeight.w700),
              align: Alignment(-dir.dx, -dir.dy));
        }
      }
      if (w.showRegionValues) {
        final st = TextStyle(color: theme.textColor, fontSize: 12, fontWeight: FontWeight.w600);
        for (var i = 0; i < n; i++) {
          final dir = away(g, centers[i]);
          final p = n == 1 ? centers[i] : centers[i] + dir * (radii[i] * (n == 2 ? .5 : .55));
          paintText(canvas, fmt(_region({i})), p, st);
        }
        if (n >= 2) {
          for (var i = 0; i < n; i++) {
            for (var j = i + 1; j < n; j++) {
              final d = (centers[j] - centers[i]).distance;
              final u = (centers[j] - centers[i]) / d;
              var mid = centers[i] + u * ((d - radii[j] + radii[i]) / 2);
              if (n == 3) {
                final k = 3 - i - j;
                mid = mid + away(centers[k], mid) * radii[k] * .22;
              }
              paintText(canvas, fmt(_region({i, j})), mid, st);
            }
          }
        }
        if (n == 3) paintText(canvas, fmt(_region({0, 1, 2})), g, st);
      }
    }
    if (hov != null && ptr != null) {
      final names = [for (final i in hov.toList()..sort()) w.sets[i].label];
      final v = _region(hov);
      var union = 0.0;
      if (n == 1) {
        union = w.sets[0].size;
      } else {
        for (var mask = 1; mask < (1 << n); mask++) {
          union += math.max(0.0, _region({for (var b = 0; b < n; b++) if (mask & (1 << b) != 0) b}));
        }
      }
      paintTooltip(canvas, size, ptr, theme, title: hov.length == 1 ? '${names.first} only' : names.join(' ∩ '), rows: [
        TooltipRow(fmt(v), color: color(hov.first)),
        if (union > 0) TooltipRow('${(v / union * 100).toStringAsFixed(1)}% of all'),
      ]);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
