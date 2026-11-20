// Scorecard: KPI cards with value, change vs previous, trend and target.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/chart_theme.dart';
import '../core/chart_utils.dart';
import '../sparkline.dart';

/// How the change versus the previous value is written on a card.
enum KpiDeltaMode {
  /// `+12.5%`
  percent,

  /// `+1,250`
  absolute,

  /// `+1,250 (+12.5%)`
  both,
}

/// Percent change from [previous] to [value]; null when [previous] is zero.
double? kpiDeltaPercent(double value, double previous) => previous == 0 ? null : (value - previous) / previous.abs() * 100;

/// One KPI shown on a [ScorecardChart] card.
class KpiItem {
  const KpiItem(
    this.title,
    this.value, {
    this.previous,
    this.target,
    this.trend,
    this.prefix = '',
    this.suffix = '',
    this.higherIsBetter = true,
    this.subtitle,
    this.icon,
    this.color,
    this.format,
  });

  /// Name of the metric, e.g. `Revenue`.
  final String title;
  final double value;

  /// Value of the previous period; enables the delta chip.
  final double? previous;

  /// Goal; enables a progress bar ("85% of target").
  final double? target;

  /// Recent values for the sparkline.
  final List<double>? trend;

  /// Text before / after the number, e.g. `$` and `k`.
  final String prefix, suffix;

  /// false for metrics where lower is better (churn, cost, errors): a fall is
  /// then drawn green.
  final bool higherIsBetter;

  /// Small line under the delta, e.g. `vs last month`.
  final String? subtitle;
  final IconData? icon;

  /// Accent colour of the card (sparkline, progress, icon).
  final Color? color;

  /// Custom number format for this card.
  final String Function(double)? format;
}

/// Scorecard: a grid of KPI cards. Each card shows the metric name, a large
/// value, the change against the previous period as a coloured chip (green =
/// good, red = bad, taking [KpiItem.higherIsBetter] into account), an optional
/// sparkline trend and an optional progress bar towards a target.
///
/// Built from ordinary widgets, so it sizes itself to its content and wraps
/// to as many rows as needed.
class ScorecardChart extends StatelessWidget {
  const ScorecardChart({
    super.key,
    required this.kpis,
    this.columns = 2,
    this.spacing = 12,
    this.deltaMode = KpiDeltaMode.percent,
    this.goodColor = const Color(0xFF2E7D32),
    this.badColor = const Color(0xFFC62828),
    this.neutralColor = const Color(0xFF757575),
    this.cardRadius = 16,
    this.showSparkline = true,
    this.valueFormat,
    this.theme,
  });
  final List<KpiItem> kpis;

  /// Cards per row.
  final int columns;
  final double spacing;
  final KpiDeltaMode deltaMode;

  /// Colours of the delta chip.
  final Color goodColor, badColor, neutralColor;
  final double cardRadius;
  final bool showSparkline;

  /// Default number format (cards can override with `KpiItem.format`).
  final String Function(double)? valueFormat;
  final ChartTheme? theme;

  @override
  Widget build(BuildContext context) {
    final t = theme ?? ChartTheme.of(context);
    return LayoutBuilder(builder: (context, c) {
      // each card gets an equal share of the width
      final cardW = (c.maxWidth - spacing * (columns - 1)) / columns;
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: [for (var i = 0; i < kpis.length; i++) SizedBox(width: cardW, child: _card(kpis[i], i, t, cardW))],
      );
    });
  }

  Widget _card(KpiItem k, int index, ChartTheme t, double width) {
    final fmt = k.format ?? valueFormat ?? formatNumber;
    final accent = k.color ?? t.colorAt(index);

    // ---- change vs previous
    Widget? chip;
    if (k.previous != null) {
      final change = k.value - k.previous!;
      final pct = kpiDeltaPercent(k.value, k.previous!);
      final good = change == 0 ? null : (k.higherIsBetter ? change > 0 : change < 0);
      final color = good == null ? neutralColor : (good ? goodColor : badColor);
      final sign = change >= 0 ? '+' : '−';
      final absText = '$sign${fmt(change.abs())}';
      final pctText = pct == null ? '' : '$sign${pct.abs().toStringAsFixed(1)}%';
      final text = switch (deltaMode) {
        KpiDeltaMode.percent => pctText.isEmpty ? absText : pctText,
        KpiDeltaMode.absolute => absText,
        KpiDeltaMode.both => pctText.isEmpty ? absText : '$absText ($pctText)',
      };
      chip = Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: color.withAlpha(34), borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(change == 0 ? Icons.remove : (change > 0 ? Icons.arrow_upward : Icons.arrow_downward), size: 13, color: color),
          const SizedBox(width: 3),
          Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
        ]),
      );
    }

    // ---- progress towards the target
    Widget? progress;
    if (k.target != null && k.target! > 0) {
      final frac = k.value / k.target!;
      progress = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(value: frac.clamp(0.0, 1.0).toDouble(), minHeight: 6, color: accent, backgroundColor: t.gridColor),
        ),
        const SizedBox(height: 4),
        Text('${(frac * 100).round()}% of ${k.prefix}${fmt(k.target!)}${k.suffix}', style: t.labelStyle.copyWith(fontSize: 11)),
      ]);
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(cardRadius),
        border: Border.all(color: t.gridColor),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          if (k.icon != null) ...[Icon(k.icon, size: 16, color: accent), const SizedBox(width: 6)],
          Expanded(child: Text(k.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.labelStyle.copyWith(fontSize: 13, fontWeight: FontWeight.w600))),
        ]),
        const SizedBox(height: 6),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text('${k.prefix}${fmt(k.value)}${k.suffix}', style: TextStyle(color: t.textColor, fontSize: 28, fontWeight: FontWeight.w800)),
            ),
          ),
          if (showSparkline && k.trend != null && k.trend!.length > 1)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Sparkline(values: k.trend!, color: accent, width: math.max(40.0, width * .32), height: 34, theme: t),
            ),
        ]),
        if (chip != null) ...[
          const SizedBox(height: 8),
          Row(children: [
            chip,
            if (k.subtitle != null) Padding(padding: const EdgeInsets.only(left: 8), child: Text(k.subtitle!, style: t.labelStyle.copyWith(fontSize: 11))),
          ]),
        ] else if (k.subtitle != null) ...[
          const SizedBox(height: 6),
          Text(k.subtitle!, style: t.labelStyle.copyWith(fontSize: 11)),
        ],
        if (progress != null) ...[const SizedBox(height: 10), progress],
      ]),
    );
  }
}
