import 'package:chartify/chartify.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('NiceScale picks round bounds', () {
    final a = NiceScale.compute(0, 97);
    expect(a.max, 100);
    expect(a.step, 20);
    final b = NiceScale.compute(-5, 12);
    expect(b.min, -5);
    expect(b.max, 15);
  });

  test('formatNumber is compact', () {
    expect(formatNumber(1200000), '1.2M');
    expect(formatNumber(0.30000000000000004), '0.3');
    expect(formatNumber(42), '42');
  });

  testWidgets('every chart builds and animates without errors', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Column(children: [
            LineChart(xLabels: const ['a', 'b', 'c'], series: [
              LineSeries.fromValues(name: 's', values: const [1, 3, 2]),
            ]),
            AreaChart(series: [AreaSeries.fromValues(name: 's', values: const [1, 3, 2])]),
            BarChart(stacked: true, series: [
              BarSeries.fromValues(name: 'a', values: const [1, -2, 3]),
              BarSeries.fromValues(name: 'b', values: const [2, 1, 1]),
            ]),
            const ScatterChart(series: [
              ScatterSeries(name: 's', points: [DataPoint(1, 2, size: 3), DataPoint(2, 1, size: 6)]),
            ]),
            Histogram(values: const [1, 2, 2, 3, 3, 3, 4], bins: 4),
            const PieChart(slices: [PieSlice('a', 1), PieSlice('b', 2)]),
            const DonutChart(slices: [PieSlice('a', 1), PieSlice('b', 2)], centerText: '3'),
            const RadarChart(axes: ['a', 'b', 'c'], series: [RadarSeries(name: 's', values: [1, 2, 3])]),
            const GaugeChart(value: 40),
            const CandlestickChart(candles: [Candle(label: 'x', open: 1, high: 3, low: 0, close: 2)]),
            const HeatmapChart(values: [[1, 2], [3, 4]]),
            const FunnelChart(stages: [FunnelStage('a', 10), FunnelStage('b', 5)]),
            const Sparkline(values: [1, 3, 2, 5]),
          ]),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
