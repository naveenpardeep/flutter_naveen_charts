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

    final control = [for (var i = 0; i < 120; i++) gauss(50, 8)];
    final treated = [for (var i = 0; i < 120; i++) gauss(58, 11)];
    final irisGroups = <int>[];
    final iris = List.generate(4, (_) => <double>[]);
    for (var g = 0; g < 3; g++) {
      for (var i = 0; i < 30; i++) {
        irisGroups.add(g);
        iris[0].add(gauss(5 + g * .8, .4));
        iris[1].add(gauss(3.4 - g * .25, .3));
        iris[2].add(gauss(1.5 + g * 2, .4 + .2 * g));
        iris[3].add(gauss(.3 + g * .8, .2));
      }
    }

    var fp = 100.0;
    final market = List.generate(160, (i) {
      final o = fp;
      final c = o * (1 + (rnd.nextDouble() - .48) * .03);
      fp = c;
      return Candle(
        label: 'D${i + 1}',
        open: o,
        close: c,
        high: max(o, c) * (1 + rnd.nextDouble() * .012),
        low: min(o, c) * (1 - rnd.nextDouble() * .012),
        volume: 800 + rnd.nextDouble() * 1200 + (c - o).abs() * 300,
      );
    });
    final closes = [for (final c in market) c.close];

    final upset = <String, Set<Object>>{
      for (final e in {'Web': .55, 'Mobile': .4, 'AI': .3, 'Data': .45}.entries)
        e.key: <Object>{
          for (var i = 0; i < 150; i++)
            if (rnd.nextDouble() < e.value) i
        },
    };

    // 16 nodes in 4 groups; dense inside groups plus a few bridges between them.
    final arcNodes = [
      for (var i = 0; i < 16; i++)
        NetworkNode('n$i', label: 'N$i', group: i ~/ 4)
    ];
    final arcEdges = [
      for (var i = 0; i < 16; i++)
        for (var j = i + 1; j < 16; j++)
          if ((i ~/ 4 == j ~/ 4 && (i + j) % 3 == 0) || (i * j) % 17 == 5)
            NetworkEdge('n$i', 'n$j', weight: 1 + ((i + j) % 4).toDouble()),
    ];

    // Time-chart sample data.
    final spiralValues = [
      for (var i = 0; i < 72; i++)
        20 + 14 * sin(i * 2 * pi / 12 - 1.2) + i * .35 + rnd.nextDouble() * 4
    ];
    final weekday = [
      for (var h = 0; h < 24; h++)
        6 +
            40 * exp(-pow(h - 8, 2) / 6) +
            46 * exp(-pow(h - 17.5, 2) / 7) +
            rnd.nextDouble() * 4
    ];
    final weekend = [
      for (var h = 0; h < 24; h++)
        4 + 34 * exp(-pow(h - 13, 2) / 24) + rnd.nextDouble() * 3
    ];
    final horizonWalks = [
      for (var s = 0; s < 6; s++)
        () {
          var v = 0.0;
          return [
            for (var i = 0; i < 120; i++) v += (rnd.nextDouble() - .5) * 4
          ];
        }()
    ];
    const raceNames = [
      'USA',
      'China',
      'India',
      'Japan',
      'Germany',
      'UK',
      'France',
      'Brazil'
    ];
    const raceBase = [15.0, 6.0, 1.7, 5.7, 3.4, 2.5, 2.6, 2.2];
    const raceGrowth = [.03, .09, .08, .005, .015, .02, .012, .03];

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
          'Chord diagram',
          const ChordChart(
            labels: ['Design', 'Dev', 'QA', 'Ops'],
            matrix: [
              [0, 14, 6, 2],
              [10, 0, 18, 9],
              [3, 12, 0, 5],
              [1, 8, 4, 0],
            ],
          ),
        ),
        _Section(
          'Network graph (drag the nodes)',
          NetworkGraph(
            directed: true,
            showLegend: true,
            groupNames: const ['Core', 'Web', 'Data'],
            nodes: [
              for (var i = 0; i < 14; i++)
                NetworkNode('n$i',
                    label: 'N$i', group: i % 3, size: 1 + (i % 4) * 1.5)
            ],
            edges: [
              for (var i = 1; i < 14; i++)
                NetworkEdge('n${(i - 1) ~/ 2}', 'n$i',
                    weight: 1 + (i % 3).toDouble()),
              for (var i = 0; i < 14; i += 3)
                NetworkEdge('n$i', 'n${(i + 5) % 14}'),
            ],
          ),
        ),
        _Section(
          'Word cloud',
          const WordCloud(words: [
            WordEntry('Flutter', 100),
            WordEntry('Dart', 82),
            WordEntry('Widget', 70),
            WordEntry('Chart', 66),
            WordEntry('Animation', 58),
            WordEntry('State', 52),
            WordEntry('Canvas', 48),
            WordEntry('Paint', 44),
            WordEntry('Theme', 40),
            WordEntry('Material', 38),
            WordEntry('Layout', 34),
            WordEntry('Gesture', 30),
            WordEntry('Sliver', 26),
            WordEntry('Isolate', 24),
            WordEntry('Stream', 22),
            WordEntry('Future', 20),
            WordEntry('Hot reload', 18),
            WordEntry('Package', 16),
            WordEntry('Render', 14),
            WordEntry('Build', 12),
          ]),
        ),
        _Section(
          'Violin plot',
          ViolinPlot(yAxisTitle: 'Score', data: [
            ViolinData('Control', [for (var i = 0; i < 150; i++) gauss(50, 8)]),
            ViolinData(
                'Treatment A', [for (var i = 0; i < 150; i++) gauss(58, 12)]),
            ViolinData('Treatment B', [
              for (var i = 0; i < 150; i++)
                i.isEven ? gauss(45, 5) : gauss(68, 5)
            ]),
          ]),
        ),
        _Section(
          'Streamgraph',
          StreamGraphChart(
            xLabels: [for (var i = 0; i < 24; i++) 'W${i + 1}'],
            series: [
              AreaSeries.fromValues(name: 'Rock', values: [
                for (var i = 0; i < 24; i++)
                  12 + 8 * sin(i / 3) + rnd.nextDouble() * 3
              ]),
              AreaSeries.fromValues(name: 'Pop', values: [
                for (var i = 0; i < 24; i++)
                  14 + 6 * cos(i / 4) + rnd.nextDouble() * 3
              ]),
              AreaSeries.fromValues(name: 'Jazz', values: [
                for (var i = 0; i < 24; i++)
                  6 + 4 * sin(i / 2 + 1) + rnd.nextDouble() * 2
              ]),
              AreaSeries.fromValues(name: 'Folk', values: [
                for (var i = 0; i < 24; i++)
                  9 + 5 * cos(i / 5 + 2) + rnd.nextDouble() * 2
              ]),
              AreaSeries.fromValues(name: 'Electro', values: [
                for (var i = 0; i < 24; i++) 4 + i * .4 + rnd.nextDouble() * 2
              ]),
            ],
          ),
        ),
        _Section(
          'Marimekko',
          const MarimekkoChart(
            segmentNames: ['Hardware', 'Software', 'Services'],
            columns: [
              MarimekkoColumn('NA', [40, 35, 25]),
              MarimekkoColumn('EU', [30, 40, 20]),
              MarimekkoColumn('APAC', [50, 20, 10]),
              MarimekkoColumn('LATAM', [10, 8, 6]),
            ],
          ),
        ),
        _Section(
          '3-D bar chart (drag to rotate, double-tap to reset)',
          const Bar3DChart(
            categories: ['Q1', 'Q2', 'Q3', 'Q4'],
            seriesNames: ['North', 'South', 'East'],
            values: [
              [30, 40, 35, 50],
              [20, 25, 30, 28],
              [15, 22, 18, 35],
            ],
          ),
        ),
        _Section(
          '3-D scatter',
          Scatter3DChart(
            groupNames: const ['Setosa', 'Versicolor', 'Virginica'],
            xTitle: 'Length',
            yTitle: 'Width',
            zTitle: 'Weight',
            points: [
              for (var g = 0; g < 3; g++)
                for (var i = 0; i < 25; i++)
                  Point3D(gauss(g * 4 + 3, 1.2), gauss(g * 3 + 2, 1),
                      gauss(g * 5 + 5, 1.5),
                      group: g, size: 1 + rnd.nextDouble() * 3),
            ],
          ),
        ),
        _Section(
          '3-D surface',
          Surface3DChart(values: [
            for (var z = 0; z < 25; z++)
              [for (var x = 0; x < 25; x++) ripple(x, z)]
          ]),
        ),
        _Section(
          '3-D pie',
          const Pie3DChart(slices: [
            PieSlice('Alpha', 35),
            PieSlice('Beta', 25),
            PieSlice('Gamma', 20),
            PieSlice('Delta', 12),
            PieSlice('Other', 8),
          ]),
        ),
        _Section(
          'Lollipop',
          LollipopChart(
              labels: months.sublist(0, 8),
              showValueLabels: true,
              series: [
                BarSeries.fromValues(name: 'Sales', values: sales.sublist(0, 8))
              ]),
        ),
        _Section(
          'Dumbbell (change between two values)',
          const DumbbellChart(
              startLabel: '2025',
              endLabel: '2026',
              sortByGap: true,
              items: [
                DumbbellItem('Design', 42, 71),
                DumbbellItem('Engineering', 55, 63),
                DumbbellItem('Support', 70, 58),
                DumbbellItem('Sales', 38, 66),
                DumbbellItem('Ops', 61, 64),
              ]),
        ),
        _Section(
          'Slope chart',
          const SlopeChart(leftTitle: '2024', rightTitle: '2026', items: [
            SlopeItem('Flutter', 34, 46),
            SlopeItem('React Native', 38, 35),
            SlopeItem('Kotlin MP', 8, 19),
            SlopeItem('Swift UI', 22, 24),
            SlopeItem('Xamarin', 12, 4),
          ]),
        ),
        _Section(
          'Bump chart (ranks over time)',
          const BumpChart(periods: [
            '2022',
            '2023',
            '2024',
            '2025',
            '2026'
          ], series: [
            BumpSeries('Alpha', [90, 85, 88, 70, 60]),
            BumpSeries('Beta', [70, 80, 86, 90, 92]),
            BumpSeries('Gamma', [60, 65, 70, 75, 80]),
            BumpSeries('Delta', [80, 78, 60, 62, 70]),
            BumpSeries('Epsilon', [50, 55, 52, 58, 64]),
          ]),
        ),
        _Section(
          'Error bars',
          const ErrorBarChart(labels: [
            'A',
            'B',
            'C',
            'D'
          ], series: [
            ErrorBarSeries(
                name: 'Control',
                values: [12, 15, 14, 18],
                errors: [2, 2.5, 1.8, 3]),
            ErrorBarSeries(
                name: 'Treatment',
                values: [16, 19, 21, 24],
                errorsLow: [2, 3, 2, 2.5],
                errorsHigh: [3, 2, 4, 3.5]),
          ]),
        ),
        _Section(
          'Range band (forecast with 50 % and 95 % bands)',
          RangeBandChart(xLabels: months, series: [
            RangeBandSeries(
              name: 'Forecast',
              mid: sales,
              low: [for (var i = 0; i < 12; i++) sales[i] - 6 - i * .6],
              high: [for (var i = 0; i < 12; i++) sales[i] + 6 + i * .6],
              low2: [for (var i = 0; i < 12; i++) sales[i] - 3 - i * .3],
              high2: [for (var i = 0; i < 12; i++) sales[i] + 3 + i * .3],
            ),
          ]),
        ),
        _Section(
          'Ridgeline',
          RidgelineChart(xTitle: 'Temperature (°C)', data: [
            for (var d = 0; d < 6; d++)
              RidgeData(const ['Jan', 'Mar', 'May', 'Jul', 'Sep', 'Nov'][d], [
                for (var i = 0; i < 120; i++)
                  gauss(2 + d * 4.5 - (d > 3 ? (d - 3) * 6 : 0), 3 + d * .3)
              ]),
          ]),
        ),
        _Section(
          'Density (KDE) with histogram and rug',
          DensityChart(
              showHistogram: true,
              showRug: true,
              xTitle: 'Score',
              series: [
                DensitySeries('Control', control),
                DensitySeries('Treated', treated),
              ]),
        ),
        _Section(
            'ECDF',
            EcdfChart(xTitle: 'Score', series: [
              EcdfSeries('Control', control),
              EcdfSeries('Treated', treated)
            ])),
        _Section('QQ plot (vs normal)',
            QQPlot(sample: [for (var i = 0; i < 120; i++) exp(gauss(0, .5))])),
        _Section(
          'Hexbin',
          HexbinChart(xTitle: 'x', yTitle: 'y', points: [
            for (var i = 0; i < 1500; i++)
              () {
                final x = gauss(0, 1);
                return Offset(x, gauss(0, 1) + x * .6);
              }()
          ]),
        ),
        _Section(
          'Contour',
          ContourChart(
              xMin: -3,
              xMax: 3,
              yMin: -3,
              yMax: 3,
              levels: 9,
              values: [
                for (var r = 0; r < 50; r++)
                  [
                    for (var c = 0; c < 50; c++)
                      bump(c / 49 * 6 - 3, r / 49 * 6 - 3)
                  ]
              ]),
        ),
        _Section(
          'Strip chart: beeswarm',
          StripChart(yAxisTitle: 'Score', groups: [
            StripGroup('Control', control.take(70).toList()),
            StripGroup('Treated', treated.take(70).toList()),
            StripGroup('Placebo', [for (var i = 0; i < 70; i++) gauss(52, 6)])
          ]),
        ),
        _Section(
          'Strip chart: jitter',
          StripChart(layout: StripLayout.jitter, showMean: true, groups: [
            StripGroup('Control', control.take(70).toList()),
            StripGroup('Treated', treated.take(70).toList())
          ]),
        ),
        _Section(
          'Pareto',
          const ParetoChart(valueAxisTitle: 'Defects', items: [
            ParetoItem('Scratches', 120),
            ParetoItem('Dents', 85),
            ParetoItem('Misprint', 40),
            ParetoItem('Cracks', 25),
            ParetoItem('Stains', 15),
            ParetoItem('Other', 10),
          ]),
        ),
        _Section(
          'Scatter matrix (hover to link points)',
          ScatterMatrixChart(
              names: const ['Sepal L', 'Sepal W', 'Petal L', 'Petal W'],
              columns: iris,
              groups: irisGroups,
              groupNames: const ['Setosa', 'Versicolor', 'Virginica']),
        ),
        _Section(
          'Parallel coordinates',
          ParallelCoordinatesChart(
              dimensions: const ['Sepal L', 'Sepal W', 'Petal L', 'Petal W'],
              rows: [
                for (var i = 0; i < irisGroups.length; i++)
                  [for (final c in iris) c[i]]
              ],
              groups: irisGroups,
              groupNames: const ['Setosa', 'Versicolor', 'Virginica']),
        ),
        _Section(
          'Finance chart: candles + SMA/EMA + volume + RSI + MACD (drag, pinch, wheel; double-tap resets)',
          FinanceChart(
            candles: market,
            visibleBars: 70,
            showVolume: true,
            overlays: const [FinanceOverlay.sma(20), FinanceOverlay.ema(50)],
            panels: const [FinancePanel.rsi(), FinancePanel.macd()],
            aspectRatio: 0.85,
          ),
        ),
        _Section(
          'Hollow candles + Bollinger bands',
          FinanceChart(
              candles: market,
              type: FinanceChartType.hollowCandlestick,
              visibleBars: 60,
              overlays: const [FinanceOverlay.bollinger()]),
        ),
        _Section(
            'OHLC bars',
            OhlcChart(
                candles: market.sublist(0, 70),
                overlays: const [FinanceOverlay.sma(10)])),
        _Section(
            'Heikin-Ashi', HeikinAshiChart(candles: market, showVolume: true)),
        _Section(
          'Area price chart on a log scale',
          FinanceChart(
              candles: market,
              type: FinanceChartType.area,
              logScale: true,
              zoomable: false),
        ),
        _Section('Renko', RenkoChart(prices: closes)),
        _Section('Kagi', KagiChart(prices: closes, reversalPercent: 3)),
        _Section('Point & figure', PointFigureChart(prices: closes)),
        _Section(
          'Depth chart (order book)',
          DepthChart(
            bids: [
              for (var i = 0; i < 40; i++)
                DepthLevel(99.9 - i * .1,
                    4 + rnd.nextDouble() * 40 + (i > 25 ? 60 : 0))
            ],
            asks: [
              for (var i = 0; i < 40; i++)
                DepthLevel(100.1 + i * .1,
                    4 + rnd.nextDouble() * 40 + (i > 28 ? 80 : 0))
            ],
          ),
        ),
        _Section(
          'Fan chart (forecast with 50 / 80 / 95 % bands)',
          FanChart.fromSigma(
            history: closes.sublist(closes.length - 40),
            median: [
              for (var i = 1; i <= 20; i++) closes.last * (1 + .002 * i)
            ],
            sigma: [
              for (var i = 1; i <= 20; i++)
                closes.last * .012 * sqrt(i.toDouble())
            ],
            yAxisTitle: 'Price',
          ),
        ),
        _Section(
          'Waffle (each cell = 1 %)',
          const WaffleChart(total: 100, slices: [
            PieSlice('Mobile', 48),
            PieSlice('Desktop', 33),
            PieSlice('Tablet', 12)
          ]),
        ),
        _Section(
          'Waffle: circles, filled by column',
          const WaffleChart(
              rows: 5,
              columns: 20,
              shape: WaffleShape.circle,
              byColumns: true,
              aspectRatio: 2.4,
              slices: [
                PieSlice('Done', 55),
                PieSlice('In review', 25),
                PieSlice('Todo', 20)
              ]),
        ),
        _Section(
          'Pictogram (1 icon = 10 people)',
          const PictogramChart(unitValue: 10, items: [
            PictogramItem('Seattle', 62),
            PictogramItem('Austin', 45, icon: Icons.directions_walk),
            PictogramItem('Boston', 28, icon: Icons.accessibility_new),
          ]),
        ),
        _Section('Circle packing', const CirclePackingChart(nodes: tree)),
        _Section('Icicle', const IcicleChart(nodes: tree)),
        _Section('Icicle (horizontal)',
            const IcicleChart(nodes: tree, horizontal: true, aspectRatio: 1.9)),
        _Section(
          'Nested pie',
          const NestedPieChart(ringNames: [
            '2024',
            '2026'
          ], rings: [
            [PieSlice('Food', 45), PieSlice('Tech', 35), PieSlice('Home', 20)],
            [
              PieSlice('Food', 30),
              PieSlice('Tech', 42),
              PieSlice('Home', 18),
              PieSlice('Travel', 10)
            ],
          ]),
        ),
        _Section(
          'Venn: two sets',
          VennChart(sets: [
            VennSet('Flutter devs', 80),
            VennSet('Dart backend', 45)
          ], overlaps: [
            VennOverlap([0, 1], 18)
          ]),
        ),
        _Section(
          'Venn: three sets',
          VennChart(
            sets: [
              VennSet('Design', 60),
              VennSet('Code', 75),
              VennSet('Data', 50)
            ],
            overlaps: [
              VennOverlap([0, 1], 20),
              VennOverlap([0, 2], 14),
              VennOverlap([1, 2], 18),
              VennOverlap([0, 1, 2], 8)
            ],
          ),
        ),
        _Section(
            'UpSet plot (hover a column)', UpSetChart.fromSets(sets: upset)),
        _Section(
          'Parliament',
          const ParliamentChart(parties: [
            ParliamentParty('Labour', 204, color: Color(0xFFE4003B)),
            ParliamentParty('Green', 40, color: Color(0xFF3FA535)),
            ParliamentParty('Liberal', 62, color: Color(0xFFFAA61A)),
            ParliamentParty('Centre', 28, color: Color(0xFF6D6E71)),
            ParliamentParty('Conservative', 16, color: Color(0xFF0087DC)),
          ]),
        ),
        _Section(
          'Arc diagram (ordered by group)',
          ArcDiagram(
              order: ArcNodeOrder.group, nodes: arcNodes, edges: arcEdges),
        ),
        _Section(
          'Alluvial diagram',
          const AlluvialChart(
            stageTitles: ['2023', '2024', '2025'],
            categories: [
              ['Free', 'Trial', 'Paid'],
              ['Free', 'Trial', 'Paid', 'Churned'],
              ['Free', 'Paid', 'Churned'],
            ],
            flows: [
              AlluvialFlow(0, 'Free', 'Free', 40),
              AlluvialFlow(0, 'Free', 'Trial', 15),
              AlluvialFlow(0, 'Trial', 'Paid', 20),
              AlluvialFlow(0, 'Trial', 'Churned', 5),
              AlluvialFlow(0, 'Paid', 'Paid', 30),
              AlluvialFlow(1, 'Free', 'Free', 35),
              AlluvialFlow(1, 'Free', 'Paid', 8),
              AlluvialFlow(1, 'Trial', 'Paid', 12),
              AlluvialFlow(1, 'Paid', 'Paid', 55),
              AlluvialFlow(1, 'Paid', 'Churned', 6),
              AlluvialFlow(1, 'Churned', 'Churned', 10),
            ],
          ),
        ),
        _Section(
          'Dependency wheel',
          const DependencyWheelChart(
            nodes: [
              NetworkNode('app', label: 'App'),
              NetworkNode('ui', label: 'UI kit', group: 1),
              NetworkNode('state', label: 'State', group: 1),
              NetworkNode('net', label: 'Network', group: 2),
              NetworkNode('db', label: 'Database', group: 2),
              NetworkNode('auth', label: 'Auth', group: 3),
              NetworkNode('log', label: 'Logging', group: 3),
            ],
            edges: [
              NetworkEdge('app', 'ui', weight: 6),
              NetworkEdge('app', 'state', weight: 5),
              NetworkEdge('app', 'auth', weight: 3),
              NetworkEdge('ui', 'state', weight: 4),
              NetworkEdge('state', 'net', weight: 5),
              NetworkEdge('state', 'db', weight: 3),
              NetworkEdge('auth', 'net', weight: 3),
              NetworkEdge('net', 'log', weight: 2),
              NetworkEdge('db', 'log', weight: 2),
              NetworkEdge('auth', 'log', weight: 1),
            ],
          ),
        ),
        _Section('Dendrogram: clustering heights (horizontal)',
            const DendrogramChart(root: cluster)),
        _Section(
            'Dendrogram (vertical, depth based)',
            const DendrogramChart(
                root: orgTree,
                orientation: DendrogramOrientation.vertical,
                aspectRatio: 1.3)),
        _Section('Radial tree',
            const RadialTreeChart(root: mindTree, showInternalLabels: true)),
        _Section('Org chart (tap a card to collapse)',
            const OrgChart(root: orgTree)),
        _Section('Mind map (tap a node to fold)',
            const MindMapChart(root: mindTree)),
        _Section(
          'Adjacency matrix (grouped)',
          AdjacencyMatrixChart(
              order: AdjacencyOrder.group, nodes: arcNodes, edges: arcEdges),
        ),
        _Section(
          'Adjacency matrix (directed, with values)',
          AdjacencyMatrixChart(
              directed: true,
              showValues: true,
              order: AdjacencyOrder.degree,
              nodes: arcNodes.take(10).toList(),
              edges: arcEdges),
        ),
        _Section(
          'Market heatmap (size = volume, colour = price change)',
          const MarketHeatmapChart(tiles: cryptoTiles),
        ),
        _Section(
          'Market heatmap: custom colours, legend, no title',
          MarketHeatmapChart(
            tiles: cryptoTiles,
            title: null,
            showLegend: true,
            maxMove: 4,
            outerRadius: 12,
            tileRadius: 4,
            gap: 3,
            upColors: const [
              Color(0xFF8ED1FC),
              Color(0xFF2196F3),
              Color(0xFF0D47A1)
            ],
            downColors: const [
              Color(0xFFFFCC80),
              Color(0xFFFB8C00),
              Color(0xFFBF360C)
            ],
            caption: 'Blue = up, orange = down.',
            onTileTap: (t) => ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${t.symbol}: ${t.changePercent}%'))),
          ),
        ),
        _Section(
          'Timeline (horizontal)',
          TimelineChart(events: [
            TimelineEvent(DateTime(2015, 5, 12), 'Sky announced',
                description: 'Dart conf'),
            TimelineEvent(DateTime(2017, 5, 17), 'Flutter beta',
                color: Colors.orange),
            TimelineEvent(DateTime(2018, 12, 4), 'Flutter 1.0',
                description: 'Stable'),
            TimelineEvent(DateTime(2019, 5, 7), 'Web preview',
                end: DateTime(2021, 3, 3), color: Colors.teal),
            TimelineEvent(DateTime(2021, 3, 3), 'Flutter 2',
                description: 'Web + null safety'),
            TimelineEvent(DateTime(2022, 5, 11), 'Flutter 3',
                description: 'Six platforms'),
            TimelineEvent(DateTime(2024, 5, 14), 'Dart 3.4',
                color: Colors.purple),
          ]),
        ),
        _Section(
          'Timeline (vertical)',
          TimelineChart(vertical: true, maxCardWidth: 170, events: [
            TimelineEvent(DateTime(2026, 1, 8), 'Kick-off',
                description: 'Team of 6'),
            TimelineEvent(DateTime(2026, 2, 20), 'Prototype',
                end: DateTime(2026, 4, 2)),
            TimelineEvent(DateTime(2026, 4, 28), 'Private beta',
                description: '200 users'),
            TimelineEvent(DateTime(2026, 6, 15), 'Public launch',
                color: Colors.green),
            TimelineEvent(DateTime(2026, 9, 1), 'v2 planning'),
          ]),
        ),
        _Section(
          'Swimlane (tasks and milestones)',
          SwimlaneChart(
              showToday: true,
              today: DateTime(2026, 3, 18),
              lanes: const [
                'Design',
                'Frontend',
                'Backend',
                'QA'
              ],
              items: [
                SwimlaneItem('Design', DateTime(2026, 1, 5),
                    end: DateTime(2026, 1, 30), label: 'Research'),
                SwimlaneItem('Design', DateTime(2026, 1, 20),
                    end: DateTime(2026, 2, 28), label: 'UI kit'),
                SwimlaneItem('Frontend', DateTime(2026, 2, 10),
                    end: DateTime(2026, 4, 15), label: 'App shell'),
                SwimlaneItem('Frontend', DateTime(2026, 3, 20),
                    end: DateTime(2026, 5, 10), label: 'Charts'),
                SwimlaneItem('Backend', DateTime(2026, 1, 25),
                    end: DateTime(2026, 3, 25), label: 'API'),
                SwimlaneItem('Backend', DateTime(2026, 4, 1),
                    label: 'DB freeze'),
                SwimlaneItem('QA', DateTime(2026, 4, 5),
                    end: DateTime(2026, 5, 20), label: 'Regression'),
                SwimlaneItem('QA', DateTime(2026, 5, 25), label: 'Release'),
              ]),
        ),
        _Section(
          'Spiral: 6 years of monthly values (one turn = 1 year)',
          SpiralChart(
            period: 12,
            values: spiralValues,
            phaseLabels: const [
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
            ],
            labels: [
              for (var i = 0; i < 72; i++)
                '${[
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
                ][i % 12]} ${2021 + i ~/ 12}'
            ],
          ),
        ),
        _Section(
            'Spiral: heat style',
            SpiralChart(
                period: 12, style: SpiralStyle.heat, values: spiralValues)),
        _Section(
          'Clock chart: 24 h traffic (bars)',
          ClockChart(
            centerText: '24 h',
            markerIndex: 14,
            labels: [for (var h = 0; h < 24; h++) '$h:00'],
            series: [
              ClockSeries('Weekday', weekday),
              ClockSeries('Weekend', weekend)
            ],
          ),
        ),
        _Section(
            'Clock chart: area style',
            ClockChart(style: ClockStyle.area, series: [
              ClockSeries('Weekday', weekday),
              ClockSeries('Weekend', weekend)
            ])),
        _Section(
          'Polar line (monthly temperature, 3 years)',
          PolarLineChart(
            labels: const [
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
            ],
            series: [
              PolarSeries('2024', [
                for (var m = 0; m < 12; m++)
                  12 + 11 * sin((m - 3) * pi / 6) + (m % 3)
              ]),
              PolarSeries('2025', [
                for (var m = 0; m < 12; m++)
                  13 + 11 * sin((m - 3) * pi / 6) - (m % 2)
              ]),
              PolarSeries('2026', [
                for (var m = 0; m < 12; m++)
                  14 + 11.5 * sin((m - 3) * pi / 6) + 1
              ]),
            ],
          ),
        ),
        _Section(
          'Horizon chart (6 series, 3 bands)',
          HorizonChart(
            xLabels: [for (var i = 0; i < 120; i++) 'D${i + 1}'],
            series: [
              for (var s = 0; s < 6; s++)
                HorizonSeries('Sensor ${s + 1}', horizonWalks[s])
            ],
          ),
        ),
        _Section(
          'Bar-chart race (press play, drag the slider)',
          BarChartRace(
            topN: 6,
            secondsPerFrame: .9,
            names: raceNames,
            frames: [
              for (var y = 0; y < 16; y++)
                BarRaceFrame('${2010 + y}', [
                  for (var i = 0; i < raceNames.length; i++)
                    raceBase[i] * pow(1 + raceGrowth[i], y)
                ]),
            ],
          ),
        ),
        _Section(
          'Thermometers (zones, target, dual scale)',
          Row(children: [
            Expanded(
              child: ThermometerChart(
                value: 36.6,
                min: 30,
                max: 42,
                unit: '°C',
                label: 'Body temperature',
                target: 37,
                zones: const [
                  ThermometerZone(35, Color(0xFF42A5F5)),
                  ThermometerZone(37.5, Color(0xFF43A047)),
                  ThermometerZone(42, Color(0xFFE53935))
                ],
                secondaryConvert: (c) => c * 9 / 5 + 32,
                secondaryFormat: (f) => '${f.round()}°F',
              ),
            ),
            const Expanded(
                child: ThermometerChart(
                    value: 72,
                    unit: '%',
                    label: 'Fundraising',
                    target: 85,
                    color: Colors.teal)),
            const Expanded(
                child: ThermometerChart(
                    value: 18,
                    min: -20,
                    max: 40,
                    unit: '°C',
                    label: 'Outside',
                    color: Colors.deepOrange)),
          ]),
        ),
        _Section(
          'Batteries',
          Column(children: [
            const BatteryChart(level: 85, label: 'Phone'),
            const BatteryChart(level: 45, segments: 5, label: 'Segmented'),
            const BatteryChart(level: 12, charging: true, label: 'Charging'),
            const SizedBox(height: 8),
            Wrap(spacing: 16, children: const [
              SizedBox(
                  width: 70,
                  child: BatteryChart(level: 90, vertical: true, label: 'A')),
              SizedBox(
                  width: 70,
                  child: BatteryChart(
                      level: 35, vertical: true, segments: 4, label: 'B')),
              SizedBox(
                  width: 70,
                  child: BatteryChart(
                      level: 8, vertical: true, charging: true, label: 'C')),
            ]),
          ]),
        ),
        _Section(
          'Scorecard (delta, trend, target)',
          ScorecardChart(kpis: [
            KpiItem('Revenue', 128400,
                previous: 114200,
                prefix: '\$',
                target: 150000,
                subtitle: 'vs last month',
                icon: Icons.attach_money,
                trend: const [90, 95, 99, 104, 101, 110, 114, 128]),
            KpiItem('Churn', 3.2,
                previous: 3.9,
                suffix: '%',
                higherIsBetter: false,
                subtitle: 'lower is better',
                icon: Icons.person_off,
                trend: const [4.4, 4.2, 4.1, 3.9, 3.7, 3.5, 3.3, 3.2]),
            KpiItem('Active users', 48210,
                previous: 45100,
                trend: const [30, 33, 38, 40, 42, 45, 46, 48],
                icon: Icons.groups),
            KpiItem('Support tickets', 312,
                previous: 280,
                higherIsBetter: false,
                icon: Icons.support_agent),
          ]),
        ),
        _Section(
          'Scorecard: absolute + percent change, one column',
          ScorecardChart(columns: 1, deltaMode: KpiDeltaMode.both, kpis: [
            KpiItem('Orders', 1840,
                previous: 1700, trend: const [1500, 1580, 1620, 1700, 1840])
          ]),
        ),
        _Section(
          'Diverging Likert (sorted by net agreement)',
          const DivergingLikertChart(
            sortByNet: true,
            levels: [
              'Strongly disagree',
              'Disagree',
              'Neutral',
              'Agree',
              'Strongly agree'
            ],
            questions: [
              LikertQuestion('I enjoy my work', [4, 9, 18, 42, 27]),
              LikertQuestion('Pay is fair', [18, 26, 22, 24, 10]),
              LikertQuestion('Management listens', [12, 22, 28, 26, 12]),
              LikertQuestion('I would recommend us', [3, 6, 14, 40, 37]),
            ],
          ),
        ),
        _Section(
          'Rating stars with distribution',
          const RatingStarsChart(
              rating: 4.3,
              ratingCount: 1284,
              distribution: [32, 58, 130, 410, 654]),
        ),
        _Section(
          'Progress rings (goal, overflow lap, segments)',
          Row(children: const [
            Expanded(
                child: ProgressRingChart(
                    value: 72, unit: '%', label: 'Sales', previous: 64)),
            Expanded(
                child: ProgressRingChart(
                    value: 132,
                    unit: '%',
                    label: 'Quota',
                    color: Color(0xFF3F9A4F))),
            Expanded(
                child: ProgressRingChart(
                    value: 7,
                    max: 10,
                    segments: 10,
                    label: 'Habits',
                    color: Color(0xFF7E57C2),
                    previous: 8,
                    higherIsBetter: true)),
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

/// Damped ripple used by the 3-D surface example.
double ripple(int x, int z) {
  final dx = (x - 12) / 3.0, dz = (z - 12) / 3.0;
  final r = sqrt(dx * dx + dz * dz);
  return r == 0 ? 1.0 : sin(r) / r;
}

/// Two overlapping Gaussian hills, used by the contour example.
double bump(double x, double y) =>
    exp(-((x - 1) * (x - 1) + (y - 1) * (y - 1))) +
    .7 * exp(-((x + 1) * (x + 1) + (y + 1.2) * (y + 1.2)) / 1.5);

/// Org structure used by the org chart and vertical dendrogram examples.
const orgTree = TreeNode('CEO', subtitle: 'Ada Lovelace', children: [
  TreeNode('CTO', subtitle: 'Linus', children: [
    TreeNode('Platform',
        subtitle: '12 engineers',
        children: [TreeNode('Infra'), TreeNode('SRE')]),
    TreeNode('Mobile', subtitle: '9 engineers'),
    TreeNode('Web', subtitle: '14 engineers'),
  ]),
  TreeNode('CFO',
      subtitle: 'Grace',
      children: [TreeNode('Accounting'), TreeNode('Treasury')]),
  TreeNode('COO', subtitle: 'Alan', children: [
    TreeNode('Support'),
    TreeNode('Logistics'),
    TreeNode('Procurement')
  ]),
]);

/// Hierarchical clustering with merge heights, for the dendrogram example.
const cluster = TreeNode('All', height: 10, children: [
  TreeNode('Mammals', height: 6, children: [
    TreeNode('Felines',
        height: 2,
        children: [TreeNode('Lion'), TreeNode('Tiger'), TreeNode('Cat')]),
    TreeNode('Canines',
        height: 3,
        children: [TreeNode('Wolf'), TreeNode('Dog'), TreeNode('Fox')]),
  ]),
  TreeNode('Birds', height: 5, children: [
    TreeNode('Raptors',
        height: 2.5, children: [TreeNode('Eagle'), TreeNode('Hawk')]),
    TreeNode('Songbirds',
        height: 3,
        children: [TreeNode('Robin'), TreeNode('Finch'), TreeNode('Wren')]),
  ]),
]);

/// Topic tree for the mind map and radial tree examples.
const mindTree = TreeNode('Flutter', children: [
  TreeNode('Widgets', children: [
    TreeNode('Stateless'),
    TreeNode('Stateful'),
    TreeNode('Inherited')
  ]),
  TreeNode('State',
      children: [TreeNode('Provider'), TreeNode('Riverpod'), TreeNode('Bloc')]),
  TreeNode('Animation',
      children: [TreeNode('Implicit'), TreeNode('Explicit'), TreeNode('Hero')]),
  TreeNode('Testing',
      children: [TreeNode('Unit'), TreeNode('Widget'), TreeNode('Golden')]),
  TreeNode('Tooling', children: [TreeNode('DevTools'), TreeNode('Hot reload')]),
  TreeNode('Packages', children: [TreeNode('pub.dev'), TreeNode('Plugins')]),
]);

/// Sample market data (volume in arbitrary units, change in percent).
const cryptoTiles = <MarketTile>[
  MarketTile('BTC', 100, -0.13),
  MarketTile('ETH', 55, -0.42),
  MarketTile('BNB', 14, 0.41),
  MarketTile('XRP', 17, -0.85),
  MarketTile('SOL', 15, -0.79),
  MarketTile('ZEC', 8, -2.16),
  MarketTile('HYPE', 7, -1.73),
  MarketTile('TRUMP', 6, -1.9),
  MarketTile('TRX', 4.5, 0.29),
  MarketTile('ENA', 4, -5.51),
  MarketTile('PEPE', 3.5, -0.15),
  MarketTile('XAUT', 3.4, -0.09),
  MarketTile('NEAR', 3.2, 0.38),
  MarketTile('UNI', 3.2, 0.54),
  MarketTile('DOGE', 3.2, -1.41),
  MarketTile('SUI', 2.8, -1.5),
  MarketTile('AVAX', 2.7, -1.47),
  MarketTile('WLD', 2.7, -2.52),
  MarketTile('ONE', 2.6, 1.2),
  MarketTile('PUMP', 2.4, -5.27),
  MarketTile('ME', 2.3, -2.75),
  MarketTile('AAVE', 2.2, -0.96),
  MarketTile('BCH', 2.2, -4.83),
  MarketTile('LTC', 2.1, -0.7),
  MarketTile('ADA', 2.0, -1.65),
  MarketTile('W', 2.0, -4.5),
  MarketTile('LINK', 1.9, -0.48),
  MarketTile('FET', 1.9, -2.04),
  MarketTile('ARB', 1.8, 2.52),
  MarketTile('XMR', 1.8, -1.94),
];
