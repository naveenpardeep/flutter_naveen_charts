import 'dart:math';
import 'package:flutter_naveen_charts/chartify.dart';
import 'package:flutter/material.dart';

void main() => runApp(const GalleryApp());

class GalleryApp extends StatefulWidget {
  const GalleryApp({super.key});
  @override
  State<GalleryApp> createState() => _GalleryAppState();
}

class _GalleryAppState extends State<GalleryApp> {
  ThemeMode _mode = ThemeMode.light;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'flutter_naveen_charts gallery',
      debugShowCheckedModeBanner: false,
      themeMode: _mode,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      darkTheme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: Colors.indigo,
          brightness: Brightness.dark),
      home: GalleryPage(
        onToggleTheme: () => setState(() => _mode =
            _mode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light),
      ),
    );
  }
}

const months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec'
];
const sales = <double>[12, 18, 15, 22, 30, 28, 35, 33, 40, 38, 45, 52];
const costs = <double>[10, 12, 14, 16, 18, 20, 22, 24, 26, 28, 30, 32];

class GalleryPage extends StatelessWidget {
  const GalleryPage({super.key, required this.onToggleTheme});
  final VoidCallback onToggleTheme;

  @override
  Widget build(BuildContext context) {
    final rnd = Random(42);

    // Candles: a random walk.
    var price = 100.0;
    final candles = List.generate(30, (i) {
      final o = price;
      final c = o + (rnd.nextDouble() - .5) * 8;
      price = c;
      return Candle(
        label: 'D${i + 1}',
        open: o,
        close: c,
        high: max(o, c) + rnd.nextDouble() * 3,
        low: min(o, c) - rnd.nextDouble() * 3,
      );
    });

    final normal = List.generate(
        300,
        (_) =>
            50 +
            (rnd.nextDouble() + rnd.nextDouble() + rnd.nextDouble() - 1.5) *
                30);

    return Scaffold(
      appBar: AppBar(title: const Text('flutter_naveen_charts'), actions: [
        IconButton(
            icon: const Icon(Icons.brightness_6), onPressed: onToggleTheme),
      ]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        _Section(
          'Line chart (curved, dashed, stepped)',
          LineChart(xLabels: months, series: [
            LineSeries.fromValues(name: 'Sales', values: sales),
            LineSeries.fromValues(
                name: 'Costs', values: costs, dashed: true, showMarkers: false),
            LineSeries.fromValues(
                name: 'Target',
                values: List.filled(12, 36),
                stepped: true,
                curved: false,
                showMarkers: false),
          ]),
        ),
        _Section(
          'Area chart',
          AreaChart(xLabels: months, series: [
            AreaSeries.fromValues(name: 'Sales', values: sales),
            AreaSeries.fromValues(name: 'Costs', values: costs),
          ]),
        ),
        _Section(
          'Grouped bar chart',
          BarChart(xLabels: months.sublist(0, 6), series: [
            BarSeries.fromValues(name: 'Sales', values: sales.sublist(0, 6)),
            BarSeries.fromValues(name: 'Costs', values: costs.sublist(0, 6)),
          ]),
        ),
        _Section(
          'Stacked bar chart (with negatives)',
          BarChart(stacked: true, xLabels: const [
            'Q1',
            'Q2',
            'Q3',
            'Q4'
          ], series: [
            BarSeries.fromValues(
                name: 'Product A', values: const [30, 40, 35, 50]),
            BarSeries.fromValues(
                name: 'Product B', values: const [20, 25, 30, 28]),
            BarSeries.fromValues(
                name: 'Returns', values: const [-8, -5, -10, -6]),
          ]),
        ),
        _Section(
          'Combo chart (bars + line)',
          CartesianChart(xLabels: months.sublist(0, 8), series: [
            BarSeries.fromValues(name: 'Revenue', values: sales.sublist(0, 8)),
            LineSeries.fromValues(
                name: 'Margin', values: const [5, 7, 6, 9, 12, 11, 15, 14]),
          ]),
        ),
        _Section(
          'Scatter chart',
          ScatterChart(series: [
            ScatterSeries(name: 'Group A', points: [
              for (var i = 0; i < 40; i++)
                DataPoint(rnd.nextDouble() * 10, rnd.nextDouble() * 10)
            ]),
            ScatterSeries(name: 'Group B', points: [
              for (var i = 0; i < 40; i++)
                DataPoint(4 + rnd.nextDouble() * 10, 3 + rnd.nextDouble() * 10)
            ]),
          ]),
        ),
        _Section(
          'Bubble chart',
          BubbleChart(series: [
            ScatterSeries(name: 'Countries', points: [
              for (var i = 0; i < 12; i++)
                DataPoint(rnd.nextDouble() * 100, rnd.nextDouble() * 100,
                    size: 10 + rnd.nextDouble() * 90),
            ]),
          ]),
        ),
        _Section('Histogram', Histogram(values: normal, bins: 12)),
        _Section(
          'Pie chart',
          PieChart(slices: const [
            PieSlice('Mobile', 45),
            PieSlice('Desktop', 30),
            PieSlice('Tablet', 15),
            PieSlice('Other', 10),
          ]),
        ),
        _Section(
          'Donut chart',
          DonutChart(centerText: '1,240', slices: const [
            PieSlice('Done', 62),
            PieSlice('In progress', 25),
            PieSlice('Todo', 13),
          ]),
        ),
        _Section(
          'Radar chart',
          RadarChart(
            axes: const [
              'Speed',
              'Power',
              'Defense',
              'Magic',
              'Stamina',
              'Luck'
            ],
            series: const [
              RadarSeries(name: 'Knight', values: [6, 8, 9, 2, 7, 4]),
              RadarSeries(name: 'Mage', values: [5, 3, 3, 10, 4, 7]),
            ],
          ),
        ),
        _Section(
          'Gauge chart',
          Row(children: [
            Expanded(
                child: GaugeChart(
                    value: 72,
                    unit: '%',
                    label: 'CPU load',
                    segments: const [
                  GaugeSegment(50, Color(0xFF43A047)),
                  GaugeSegment(80, Color(0xFFFB8C00)),
                  GaugeSegment(100, Color(0xFFE53935)),
                ])),
            const SizedBox(width: 8),
            const Expanded(
                child: GaugeChart(value: 3.8, max: 5, label: 'Rating')),
          ]),
        ),
        _Section('Candlestick chart', CandlestickChart(candles: candles)),
        _Section(
          'Heatmap',
          HeatmapChart(
            rowLabels: const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
            colLabels: const ['6a', '9a', '12p', '3p', '6p', '9p'],
            values: [
              for (var r = 0; r < 7; r++)
                [
                  for (var c = 0; c < 6; c++)
                    (rnd.nextDouble() * 100).roundToDouble()
                ]
            ],
          ),
        ),
        _Section(
          'Funnel chart',
          const FunnelChart(stages: [
            FunnelStage('Visitors', 10000),
            FunnelStage('Sign-ups', 4200),
            FunnelStage('Trials', 1800),
            FunnelStage('Paid', 650),
          ]),
        ),
        _Section(
          'Sparklines',
          Wrap(spacing: 16, runSpacing: 12, children: [
            Sparkline(values: sales),
            Sparkline(values: costs, color: Colors.orange),
            Sparkline(
                values: sales.reversed.toList(),
                color: Colors.redAccent,
                fill: false),
          ]),
        ),
      ]),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title, this.child);
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            child,
          ]),
        ),
      );
}
