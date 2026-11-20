import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'core/chart_canvas.dart';
import 'core/chart_theme.dart';
import 'core/chart_utils.dart';

class WordEntry {
  const WordEntry(this.text, this.weight, {this.color});
  final String text;

  /// Relative importance (drives the font size).
  final double weight;
  final Color? color;
}

class _Placed {
  _Placed(this.entry, this.tp, this.rect, this.rotated, this.color);
  final WordEntry entry;
  final TextPainter tp;
  final Rect rect;
  final bool rotated;
  final Color color;
}

/// Word cloud placed on an Archimedean spiral without overlaps.
class WordCloud extends StatefulWidget {
  const WordCloud({
    super.key,
    required this.words,
    this.minFontSize = 12,
    this.maxFontSize = 48,
    this.rotateProbability = 0.2,
    this.padding = 3,
    this.seed = 3,
    this.fontWeight = FontWeight.w600,
    this.aspectRatio = 1.6,
    this.theme,
    this.animationDuration = const Duration(milliseconds: 800),
  });
  final List<WordEntry> words;
  final double minFontSize;
  final double maxFontSize;

  /// Share of words drawn vertically (0 = all horizontal).
  final double rotateProbability;
  final double padding;
  final int seed;
  final FontWeight fontWeight;
  final double aspectRatio;
  final ChartTheme? theme;
  final Duration animationDuration;

  @override
  State<WordCloud> createState() => _WordCloudState();
}

class _WordCloudState extends State<WordCloud> {
  Size? _size;
  List<_Placed> _placed = const [];
  String _sig = '';

  String _signature() =>
      '${widget.seed}|${widget.minFontSize}|${widget.maxFontSize}|${widget.rotateProbability}|${widget.padding}|'
      '${[for (final e in widget.words) '${e.text}:${e.weight}'].join(',')}';

  List<_Placed> _layout(Size size, ChartTheme theme) {
    final words = [...widget.words]..sort((a, b) => b.weight.compareTo(a.weight));
    if (words.isEmpty) return [];
    final rnd = math.Random(widget.seed);
    final minW = words.last.weight, maxW = words.first.weight;
    final bounds = Offset.zero & size;
    final placed = <_Placed>[];
    for (var rank = 0; rank < words.length; rank++) {
      final e = words[rank];
      final f = maxW == minW ? .5 : math.sqrt((e.weight - minW) / (maxW - minW));
      var fs = widget.minFontSize + (widget.maxFontSize - widget.minFontSize) * f;
      final color = e.color ?? theme.colorAt(rank);
      final rotated = rnd.nextDouble() < widget.rotateProbability;
      for (var attempt = 0; attempt < 4; attempt++) {
        final tp = TextPainter(
            text: TextSpan(text: e.text, style: TextStyle(fontSize: fs, fontWeight: widget.fontWeight, color: color)),
            textDirection: TextDirection.ltr)
          ..layout();
        final bw = (rotated ? tp.height : tp.width) + widget.padding * 2;
        final bh = (rotated ? tp.width : tp.height) + widget.padding * 2;
        var done = false;
        for (var s = 0; s < 1800; s++) {
          final ang = s * 0.3;
          final rad = 1.6 * ang;
          final center = Offset(size.width / 2 + rad * math.cos(ang) * 1.5, size.height / 2 + rad * math.sin(ang));
          final rect = Rect.fromCenter(center: center, width: bw, height: bh);
          if (rect.left < bounds.left || rect.top < bounds.top || rect.right > bounds.right || rect.bottom > bounds.bottom) {
            if (rad > math.max(size.width, size.height)) break;
            continue;
          }
          if (placed.any((p) => p.rect.overlaps(rect))) continue;
          placed.add(_Placed(e, tp, rect, rotated, color));
          done = true;
          break;
        }
        if (done) break;
        fs *= .85;
      }
    }
    return placed;
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme ?? ChartTheme.of(context);
    return AspectRatio(
      aspectRatio: widget.aspectRatio,
      child: LayoutBuilder(builder: (context, c) {
        final size = Size(c.maxWidth, c.maxHeight);
        final sig = _signature();
        if (_size != size || _sig != sig) {
          _placed = _layout(size, t);
          _size = size;
          _sig = sig;
        }
        final placed = _placed;
        return ChartCanvas(
          duration: widget.animationDuration,
          builder: (p, ptr) => _WordPainter(placed, t, p, ptr),
        );
      }),
    );
  }
}

class _WordPainter extends CustomPainter {
  _WordPainter(this.placed, this.theme, this.progress, this.pointer);
  final List<_Placed> placed;
  final ChartTheme theme;
  final double progress;
  final Offset? pointer;

  @override
  void paint(Canvas canvas, Size size) {
    _Placed? hover;
    final ptr = pointer;
    if (ptr != null && progress >= 1) {
      for (final p in placed) {
        if (p.rect.contains(ptr)) hover = p;
      }
    }
    for (final p in placed) {
      final hot = identical(p, hover);
      canvas.save();
      canvas.translate(p.rect.center.dx, p.rect.center.dy);
      canvas.scale(progress);
      if (p.rotated) canvas.rotate(-math.pi / 2);
      if (hot) {
        final r = Rect.fromCenter(
            center: Offset.zero,
            width: p.tp.width + 8,
            height: p.tp.height + 4);
        canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(4)),
            Paint()..color = p.color.faded(.15));
      }
      p.tp.paint(canvas, Offset(-p.tp.width / 2, -p.tp.height / 2));
      canvas.restore();
    }
    if (hover != null && ptr != null) {
      paintTooltip(canvas, size, ptr, theme, title: hover.entry.text,
          rows: [TooltipRow('Weight: ${formatNumber(hover.entry.weight)}', color: hover.color)]);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
