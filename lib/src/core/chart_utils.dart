import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'chart_theme.dart';

/// "Nice" axis bounds and tick steps (1, 2, 5 x 10^n).
class NiceScale {
  const NiceScale._(this.min, this.max, this.step);
  final double min;
  final double max;
  final double step;

  factory NiceScale.compute(double lo, double hi,
      {int maxTicks = 5, bool includeZero = false}) {
    if (includeZero) {
      lo = math.min(lo, 0);
      hi = math.max(hi, 0);
    }
    if (lo == hi) {
      if (lo == 0) {
        hi = 1;
      } else {
        final d = lo.abs() * 0.1;
        lo -= d;
        hi += d;
      }
    }
    final range = _nice(hi - lo, false);
    final step = _nice(range / (maxTicks - 1), true);
    return NiceScale._(
        (lo / step).floor() * step, (hi / step).ceil() * step, step);
  }

  List<double> get ticks {
    final n = ((max - min) / step).round();
    return List<double>.generate(n + 1, (i) => min + i * step);
  }

  static double _nice(double range, bool round) {
    final exp = (math.log(range) / math.ln10).floor();
    final f = range / math.pow(10, exp);
    double nf;
    if (round) {
      nf = f < 1.5 ? 1 : (f < 3 ? 2 : (f < 7 ? 5 : 10));
    } else {
      nf = f <= 1 ? 1 : (f <= 2 ? 2 : (f <= 5 ? 5 : 10));
    }
    return nf * math.pow(10, exp);
  }
}

String _strip(String s) =>
    s.contains('.') ? s.replaceFirst(RegExp(r'\.?0+$'), '') : s;

/// Compact number formatting: 1200000 -> 1.2M, 0.30000000004 -> 0.3.
String formatNumber(double v) {
  final a = v.abs();
  if (a >= 1e9) return '${_strip((v / 1e9).toStringAsFixed(1))}B';
  if (a >= 1e6) return '${_strip((v / 1e6).toStringAsFixed(1))}M';
  if (a >= 1e4) return '${_strip((v / 1e3).toStringAsFixed(1))}K';
  if (a >= 100) return v.toStringAsFixed(0);
  return _strip(v.toStringAsFixed(a < 1 ? 3 : 2));
}

Size measureText(String text, TextStyle style) {
  final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr)
    ..layout();
  return tp.size;
}

/// Paints [text] so that [align] describes which point of the text box
/// sits on [anchor] (e.g. Alignment.centerRight = text ends at anchor).
void paintText(Canvas canvas, String text, Offset anchor, TextStyle style,
    {Alignment align = Alignment.center, double maxWidth = double.infinity}) {
  final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…')
    ..layout(maxWidth: maxWidth);
  tp.paint(
      canvas,
      Offset(anchor.dx - tp.width * (align.x + 1) / 2,
          anchor.dy - tp.height * (align.y + 1) / 2));
}

Path dashPath(Path src, {double dash = 6, double gap = 4}) {
  final out = Path();
  for (final m in src.computeMetrics()) {
    double d = 0;
    while (d < m.length) {
      out.addPath(m.extractPath(d, math.min(d + dash, m.length)), Offset.zero);
      d += dash + gap;
    }
  }
  return out;
}

class TooltipRow {
  const TooltipRow(this.text, {this.color});
  final String text;
  final Color? color;
}

void paintTooltip(Canvas canvas, Size bounds, Offset anchor, ChartTheme theme,
    {String? title, required List<TooltipRow> rows}) {
  TextPainter mk(String t, TextStyle s) => TextPainter(
      text: TextSpan(text: t, style: s), textDirection: TextDirection.ltr)
    ..layout();
  final tTitle = title == null
      ? null
      : mk(title, theme.tooltipStyle.copyWith(fontWeight: FontWeight.bold));
  final tRows = [for (final r in rows) mk(r.text, theme.tooltipStyle)];
  const pad = 8.0, sw = 10.0, gap = 6.0, lineGap = 3.0;
  final hasSwatch = rows.any((r) => r.color != null);
  double w = tTitle?.width ?? 0;
  for (final t in tRows) {
    w = math.max(w, t.width + (hasSwatch ? sw + gap : 0));
  }
  double h = tTitle == null ? 0 : tTitle.height + lineGap;
  for (final t in tRows) {
    h += t.height + lineGap;
  }
  h -= lineGap;
  w += pad * 2;
  h += pad * 2;
  double x = anchor.dx + 14;
  if (x + w > bounds.width) x = anchor.dx - 14 - w;
  x = x.clamp(0.0, math.max(0.0, bounds.width - w)).toDouble();
  final y = (anchor.dy - h / 2)
      .clamp(0.0, math.max(0.0, bounds.height - h))
      .toDouble();
  final rr = RRect.fromRectAndRadius(
      Rect.fromLTWH(x, y, w, h), const Radius.circular(6));
  canvas.drawShadow(Path()..addRRect(rr), Colors.black, 3, true);
  canvas.drawRRect(rr, Paint()..color = theme.tooltipBackground);
  double cy = y + pad;
  if (tTitle != null) {
    tTitle.paint(canvas, Offset(x + pad, cy));
    cy += tTitle.height + lineGap;
  }
  for (var i = 0; i < tRows.length; i++) {
    final t = tRows[i];
    var tx = x + pad;
    final c = rows[i].color;
    if (c != null) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(tx, cy + (t.height - sw) / 2, sw, sw),
              const Radius.circular(2)),
          Paint()..color = c);
    }
    if (hasSwatch) tx += sw + gap;
    t.paint(canvas, Offset(tx, cy));
    cy += t.height + lineGap;
  }
}
