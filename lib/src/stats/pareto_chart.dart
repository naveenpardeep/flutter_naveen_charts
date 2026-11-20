import 'package:flutter/material.dart';
import '../cartesian/cartesian_chart.dart';
import '../cartesian/models.dart';
import '../core/chart_theme.dart';

class ParetoItem {
  const ParetoItem(this.label, this.value);
  final String label;
  final double value;
}

/// Pareto chart: bars sorted high to low plus the cumulative-percent line on a
/// right-hand 0-100 % axis (the "80/20" view).
class ParetoChart extends StatelessWidget {
  const ParetoChart({
    super.key,
    required this.items,
    this.barColor,
    this.lineColor,
    this.valueAxisTitle,
    this.showValueLabels = false,
    this.aspectRatio = 1.6,
    this.theme,
    this.animationDuration = const Duration(milliseconds: 900),
  });
  final List<ParetoItem> items;
  final Color? barColor, lineColor;
  final String? valueAxisTitle;
  final bool showValueLabels;
  final double aspectRatio;
  final ChartTheme? theme;
  final Duration animationDuration;

  @override
  Widget build(BuildContext context) {
    final list = [...items]..sort((a, b) => b.value.compareTo(a.value));
    final total = list.fold<double>(0, (a, b) => a + b.value);
    var run = 0.0;
    final cum = [
      for (final i in list)
        () {
          run += i.value;
          return total == 0 ? 0.0 : run / total * 100;
        }()
    ];
    return CartesianChart(
      xLabels: [for (final i in list) i.label],
      aspectRatio: aspectRatio,
      theme: theme,
      animationDuration: animationDuration,
      options: CartesianOptions(
        yAxisTitle: valueAxisTitle,
        secondaryAxisTitle: 'Cumulative %',
        secondaryYMin: 0,
        secondaryYMax: 100,
        secondaryYFormat: (v) => '${v.round()}%',
        yMin: 0,
        yMax: total,
        showValueLabels: showValueLabels,
      ),
      series: [
        BarSeries.fromValues(name: 'Value', values: [for (final i in list) i.value], color: barColor),
        LineSeries.fromValues(
            name: 'Cumulative %',
            values: cum,
            secondaryAxis: true,
            curved: false,
            color: lineColor ?? const Color(0xFFE15759)),
      ],
    );
  }
}
