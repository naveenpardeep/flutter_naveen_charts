import 'dart:math';
import 'package:flutter_naveen_charts/flutter_naveen_charts.dart';
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
      title: 'Flutter Naveen Charts gallery',
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

const tree = [
  HierarchyNode('Electronics', children: [
    HierarchyNode('Phones', value: 120),
    HierarchyNode('Laptops', value: 90),
    HierarchyNode('Audio', value: 45),
  ]),
  HierarchyNode('Clothing', children: [
    HierarchyNode('Men', value: 70),
    HierarchyNode('Women', value: 95),
    HierarchyNode('Kids', value: 30),
  ]),
  HierarchyNode('Home', children: [
    HierarchyNode('Kitchen', value: 60),
    HierarchyNode('Garden', value: 40),
  ]),
  HierarchyNode('Toys', value: 50),
];

class GalleryPage extends StatelessWidget {
  const GalleryPage({super.key, required this.onToggleTheme});
  final VoidCallback onToggleTheme;

  @override
  Widget build(BuildContext context) {
    final rnd = Random(42);

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
    double gauss(double mean, double sd) =>
        mean +
        (rnd.nextDouble() + rnd.nextDouble() + rnd.nextDouble() - 1.5) *
            sd *
            1.6;
    final normal = List.generate(300, (_) => gauss(50, 18));
    final boxData = [
      for (final e in {
        'Alpha': 50.0,
        'Beta': 62.0,
        'Gamma': 41.0,
        'Delta': 70.0
      }.entries)
        BoxPlotStats.fromValues(
            e.key,
            [for (var i = 0; i < 60; i++) gauss(e.value, 10)]
              ..add(e.value + 45)),
    ];
    final signal = [
      for (var i = 0; i < 200; i++)
        DataPoint(i.toDouble(), sin(i / 12) * 10 + (rnd.nextDouble() - .5) * 4)
    ];
    final cal = <DateTime, double>{
      for (var i = 0; i < 180; i++)
        if (rnd.nextDouble() > .25)
          DateTime(2026, 10, 30 - i): (rnd.nextInt(10) + 1).toDouble()
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Flutter Naveen Charts'), actions: [
        IconButton(
            icon: const Icon(Icons.brightness_6), onPressed: onToggleTheme),
      ]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        _Section(
          'Line chart: axis titles + reference line',
          LineChart(
            xLabels: months,
            options: const CartesianOptions(
              xAxisTitle: 'Month',
              yAxisTitle: 'Sales (k)',
              dashedGrid: true,
              referenceLines: [ReferenceLine(36, label: 'Target')],
            ),
            series: [
              LineSeries.fromValues(name: 'Sales', values: sales),
              LineSeries.fromValues(
                  name: 'Costs',
                  values: costs,
                  dashed: true,
                  showMarkers: false),
              LineSeries.fromValues(
                  name: 'Plan',
                  values: List.filled(12, 30),
                  stepped: true,
                  curved: false,
                  showMarkers: false),
            ],
          ),
        ),
        _Section(
          'Zoom & pan: pinch, drag, mouse wheel, double-tap to reset',
          CartesianChart(
            options: const CartesianOptions(
                zoomable: true, gridMode: GridMode.both, showLegend: false),
            series: [
              LineSeries(
                  name: 'Signal',
                  points: signal,
                  showMarkers: false,
                  curved: false,
                  strokeWidth: 1.8)
            ],
          ),
        ),
        _Section(
          'Dual y-axes (bars + line on right axis)',
          CartesianChart(
            xLabels: months.sublist(0, 8),
            options: CartesianOptions(
              yAxisTitle: 'Revenue',
              secondaryAxisTitle: 'Conversion',
              secondaryYFormat: (v) => '${v.toStringAsFixed(0)}%',
              showValueLabels: true,
            ),
            series: [
              BarSeries.fromValues(
                  name: 'Revenue', values: sales.sublist(0, 8)),
              LineSeries.fromValues(
                  name: 'Conversion',
                  secondaryAxis: true,
                  values: const [2.1, 2.4, 2.2, 3.0, 3.6, 3.4, 4.1, 4.4]),
            ],
          ),
        ),
        _Section(
            'Area chart',
            AreaChart(xLabels: months, series: [
              AreaSeries.fromValues(name: 'Sales', values: sales),
              AreaSeries.fromValues(name: 'Costs', values: costs),
            ])),
        _Section(
          'Stacked area',
          StackedAreaChart(xLabels: months, series: [
            AreaSeries.fromValues(name: 'Web', values: sales),
            AreaSeries.fromValues(name: 'Mobile', values: costs),
            AreaSeries.fromValues(
                name: 'Retail',
                values: const [8, 9, 9, 10, 11, 12, 12, 13, 14, 15, 15, 16]),
          ]),
        ),
        _Section(
          '100% stacked area',
          StackedAreaChart(percent: true, xLabels: months, series: [
            AreaSeries.fromValues(name: 'Web', values: sales),
            AreaSeries.fromValues(name: 'Mobile', values: costs),
            AreaSeries.fromValues(
                name: 'Retail',
                values: const [8, 9, 9, 10, 11, 12, 12, 13, 14, 15, 15, 16]),
          ]),
        ),
        _Section(
          'Grouped bars with value labels',
          BarChart(
            xLabels: months.sublist(0, 6),
            options: const CartesianOptions(showValueLabels: true),
            series: [
              BarSeries.fromValues(name: 'Sales', values: sales.sublist(0, 6)),
              BarSeries.fromValues(name: 'Costs', values: costs.sublist(0, 6)),
            ],
          ),
        ),
        _Section(
          'Stacked bars (with negatives)',
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
          'Horizontal bars',
          HorizontalBarChart(
            categories: const ['Dart', 'Kotlin', 'Swift', 'Rust', 'Go'],
            series: [
              BarSeries.fromValues(
                  name: '2025', values: const [62, 70, 66, 48, 55]),
              BarSeries.fromValues(
                  name: '2026', values: const [78, 74, 69, 60, 58]),
            ],
          ),
        ),
        _Section(
          'Population pyramid',
          HorizontalBarChart.pyramid(
            categories: const [
              '75+',
              '60-74',
              '45-59',
              '30-44',
              '15-29',
              '0-14'
            ],
            leftName: 'Male',
            leftValues: const [4, 9, 14, 17, 15, 12],
            rightName: 'Female',
            rightValues: const [6, 11, 15, 17, 14, 11],
          ),
        ),
        _Section(
          'Combo: bars + scatter overlay',
          CartesianChart(xLabels: months.sublist(0, 6), series: [
            BarSeries.fromValues(name: 'Actual', values: sales.sublist(0, 6)),
            ScatterSeries(name: 'Forecast', markerSize: 7, points: [
              for (var i = 0; i < 6; i++)
                DataPoint(i.toDouble(), sales[i] + (rnd.nextDouble() - .5) * 8)
            ]),
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
        _Section('Box plot (with outliers and mean)',
            BoxPlotChart(data: boxData, yAxisTitle: 'Score')),
        _Section(
          'Pie chart',
          const PieChart(slices: [
            PieSlice('Mobile', 45),
            PieSlice('Desktop', 30),
            PieSlice('Tablet', 15),
            PieSlice('Other', 10),
          ]),
        ),
        _Section(
          'Donut chart',
          const DonutChart(centerText: '1,240', slices: [
            PieSlice('Done', 62),
            PieSlice('In progress', 25),
            PieSlice('Todo', 13),
          ]),
        ),
        _Section(
          'Semi-circle donut',
          const PieChart(
            donut: true,
            startAngle: pi,
            sweepAngle: pi,
            aspectRatio: 2,
            slices: [PieSlice('A', 40), PieSlice('B', 35), PieSlice('C', 25)],
          ),
        ),
        _Section(
          'Polar area (rose)',
          const PolarAreaChart(slices: [
            PieSlice('N', 12),
            PieSlice('NE', 8),
            PieSlice('E', 15),
            PieSlice('SE', 6),
            PieSlice('S', 10),
            PieSlice('SW', 18),
            PieSlice('W', 9),
            PieSlice('NW', 14),
          ]),
        ),
        _Section(
          'Radial bars',
          const RadialBarChart(centerText: '78%', items: [
            RadialBarItem('Move', 82),
            RadialBarItem('Exercise', 55),
            RadialBarItem('Stand', 91),
          ]),
        ),
        _Section('Sunburst', const SunburstChart(roots: tree)),
        _Section('Treemap', const TreemapChart(nodes: tree)),
        _Section(
          'Sankey',
          const SankeyChart(
            nodes: [
              SankeyNode('search', label: 'Search'),
              SankeyNode('social', label: 'Social'),
              SankeyNode('direct', label: 'Direct'),
              SankeyNode('landing', label: 'Landing'),
              SankeyNode('bounce', label: 'Bounce'),
              SankeyNode('signup', label: 'Sign-up'),
              SankeyNode('buy', label: 'Purchase'),
              SankeyNode('drop', label: 'Abandon'),
            ],
            links: [
              SankeyLink('search', 'landing', 40),
              SankeyLink('social', 'landing', 25),
              SankeyLink('direct', 'landing', 15),
              SankeyLink('landing', 'bounce', 30),
              SankeyLink('landing', 'signup', 50),
              SankeyLink('signup', 'buy', 20),
              SankeyLink('signup', 'drop', 30),
            ],
          ),
        ),
        _Section(
          'Waterfall',
          const WaterfallChart(steps: [
            WaterfallStep('Revenue', 500, isTotal: false),
            WaterfallStep('COGS', -180),
            WaterfallStep('Gross', 0, isTotal: true),
            WaterfallStep('Opex', -120),
            WaterfallStep('Tax', -45),
            WaterfallStep('Other', 25),
            WaterfallStep('Net', 0, isTotal: true),
          ]),
        ),
        _Section(
          'Radar chart',
          const RadarChart(
            axes: ['Speed', 'Power', 'Defense', 'Magic', 'Stamina', 'Luck'],
            series: [
              RadarSeries(name: 'Knight', values: [6, 8, 9, 2, 7, 4]),
              RadarSeries(name: 'Mage', values: [5, 3, 3, 10, 4, 7]),
            ],
          ),
        ),
        _Section(
          'Gauges',
          Row(children: const [
            Expanded(
                child: GaugeChart(
                    value: 72,
                    unit: '%',
                    label: 'CPU load',
                    segments: [
                  GaugeSegment(50, Color(0xFF43A047)),
                  GaugeSegment(80, Color(0xFFFB8C00)),
                  GaugeSegment(100, Color(0xFFE53935)),
                ])),
            SizedBox(width: 8),
            Expanded(child: GaugeChart(value: 3.8, max: 5, label: 'Rating')),
          ]),
        ),
        _Section(
          'Bullet chart',
          const BulletChart(items: [
            BulletItem('Revenue',
                value: 275, target: 250, ranges: [150, 225, 300]),
            BulletItem('Profit', value: 22, target: 27, ranges: [20, 25, 30]),
            BulletItem('Orders',
                value: 1650, target: 2000, ranges: [1000, 1500, 2500]),
          ]),
        ),
        _Section('Candlestick', CandlestickChart(candles: candles)),
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
        _Section('Calendar heatmap',
            CalendarHeatmap(data: cal, endDate: DateTime(2026, 10, 30))),
        _Section(
          'Gantt',
          GanttChart(today: DateTime(2026, 11, 10), tasks: [
            GanttTask('Research', DateTime(2026, 10, 19), DateTime(2026, 11, 2),
                progress: 1),
            GanttTask('Design', DateTime(2026, 10, 28), DateTime(2026, 11, 20),
                progress: .7),
            GanttTask('Build', DateTime(2026, 11, 9), DateTime(2026, 12, 18),
                progress: .3),
            GanttTask('Test', DateTime(2026, 12, 7), DateTime(2026, 12, 28)),
            GanttTask('Launch', DateTime(2026, 12, 28), DateTime(2027, 1, 4)),
          ]),
        ),
        _Section(
          'Funnel',
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
