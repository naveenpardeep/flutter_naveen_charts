import 'dart:math' as math;
import '../candlestick_chart.dart' show Candle;

const double _nan = double.nan;

/// Simple moving average; the first `p - 1` values are NaN.
List<double> sma(List<double> v, int p) {
  final out = List<double>.filled(v.length, _nan);
  if (p < 1) return out;
  var sum = 0.0;
  for (var i = 0; i < v.length; i++) {
    sum += v[i];
    if (i >= p) sum -= v[i - p];
    if (i >= p - 1) out[i] = sum / p;
  }
  return out;
}

/// Exponential moving average seeded with the SMA of the first valid window.
/// NaN values at the start of [v] are skipped.
List<double> ema(List<double> v, int p) {
  final out = List<double>.filled(v.length, _nan);
  final first = v.indexWhere((x) => !x.isNaN);
  if (first < 0 || p < 1 || v.length - first < p) return out;
  final k = 2 / (p + 1);
  var seed = 0.0;
  for (var i = first; i < first + p; i++) {
    seed += v[i];
  }
  var prev = seed / p;
  out[first + p - 1] = prev;
  for (var i = first + p; i < v.length; i++) {
    prev = v[i] * k + prev * (1 - k);
    out[i] = prev;
  }
  return out;
}

class Bollinger {
  const Bollinger(this.mid, this.upper, this.lower);
  final List<double> mid, upper, lower;
}

Bollinger bollinger(List<double> v, int p, double k) {
  final mid = sma(v, p);
  final up = List<double>.filled(v.length, _nan), lo = List<double>.filled(v.length, _nan);
  for (var i = p - 1; i < v.length; i++) {
    var s = 0.0;
    for (var j = i - p + 1; j <= i; j++) {
      s += (v[j] - mid[i]) * (v[j] - mid[i]);
    }
    final sd = math.sqrt(s / p);
    up[i] = mid[i] + k * sd;
    lo[i] = mid[i] - k * sd;
  }
  return Bollinger(mid, up, lo);
}

/// Wilder's relative strength index (0..100).
List<double> rsi(List<double> c, int p) {
  final out = List<double>.filled(c.length, _nan);
  if (c.length <= p || p < 1) return out;
  var gain = 0.0, loss = 0.0;
  for (var i = 1; i <= p; i++) {
    final d = c[i] - c[i - 1];
    if (d >= 0) {
      gain += d;
    } else {
      loss -= d;
    }
  }
  gain /= p;
  loss /= p;
  out[p] = loss == 0 ? 100 : 100 - 100 / (1 + gain / loss);
  for (var i = p + 1; i < c.length; i++) {
    final d = c[i] - c[i - 1];
    gain = (gain * (p - 1) + (d > 0 ? d : 0)) / p;
    loss = (loss * (p - 1) + (d < 0 ? -d : 0)) / p;
    out[i] = loss == 0 ? 100 : 100 - 100 / (1 + gain / loss);
  }
  return out;
}

class Macd {
  const Macd(this.line, this.signal, this.hist);
  final List<double> line, signal, hist;
}

Macd macd(List<double> c, int fast, int slow, int signal) {
  final f = ema(c, fast), s = ema(c, slow);
  final line = [for (var i = 0; i < c.length; i++) (f[i].isNaN || s[i].isNaN) ? _nan : f[i] - s[i]];
  final sig = ema(line, signal);
  final hist = [for (var i = 0; i < c.length; i++) (line[i].isNaN || sig[i].isNaN) ? _nan : line[i] - sig[i]];
  return Macd(line, sig, hist);
}

/// Heikin-Ashi smoothed candles.
List<Candle> heikinAshi(List<Candle> c) {
  final out = <Candle>[];
  for (var i = 0; i < c.length; i++) {
    final haClose = (c[i].open + c[i].high + c[i].low + c[i].close) / 4;
    final haOpen = i == 0 ? (c[i].open + c[i].close) / 2 : (out[i - 1].open + out[i - 1].close) / 2;
    out.add(Candle(
      label: c[i].label,
      open: haOpen,
      close: haClose,
      high: math.max(c[i].high, math.max(haOpen, haClose)),
      low: math.min(c[i].low, math.min(haOpen, haClose)),
      volume: c[i].volume,
    ));
  }
  return out;
}

/// Average true range (Wilder).
List<double> atr(List<Candle> c, int p) {
  final out = List<double>.filled(c.length, _nan);
  if (c.length <= p || p < 1) return out;
  double tr(int i) => i == 0
      ? c[i].high - c[i].low
      : math.max(c[i].high - c[i].low, math.max((c[i].high - c[i - 1].close).abs(), (c[i].low - c[i - 1].close).abs()));
  var a = 0.0;
  for (var i = 1; i <= p; i++) {
    a += tr(i);
  }
  a /= p;
  out[p] = a;
  for (var i = p + 1; i < c.length; i++) {
    a = (a * (p - 1) + tr(i)) / p;
    out[i] = a;
  }
  return out;
}
