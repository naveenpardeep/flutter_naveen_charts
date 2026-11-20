import 'dart:math' as math;

List<double> sortedCopy(List<double> v) => [...v]..sort();

/// Linear-interpolated quantile of an already sorted list.
double quantile(List<double> s, double p) {
  if (s.isEmpty) return 0;
  final pos = (s.length - 1) * p;
  final lo = pos.floor(), hi = pos.ceil();
  return s[lo] + (s[hi] - s[lo]) * (pos - lo);
}

double mean(List<double> v) =>
    v.isEmpty ? 0 : v.fold<double>(0, (a, b) => a + b) / v.length;

double stdDev(List<double> v) {
  if (v.length < 2) return 0;
  final m = mean(v);
  return math.sqrt(v.fold<double>(0, (a, b) => a + (b - m) * (b - m)) / (v.length - 1));
}

/// Silverman's rule-of-thumb bandwidth for a sorted sample.
double silverman(List<double> sorted) {
  final n = sorted.length;
  if (n < 2) return 1;
  final sd = stdDev(sorted);
  final iqr = quantile(sorted, .75) - quantile(sorted, .25);
  final spread = iqr > 0 ? math.min(sd, iqr / 1.34) : sd;
  final h = 0.9 * spread * math.pow(n, -0.2);
  return (h.isFinite && h > 0) ? h : 1;
}

/// Gaussian kernel density estimate of [data] at every x in [grid].
List<double> kde(List<double> data, List<double> grid, double h) {
  if (data.isEmpty) return List<double>.filled(grid.length, 0);
  final norm = 1 / (data.length * h * math.sqrt(2 * math.pi));
  return [
    for (final x in grid)
      data.fold<double>(0, (a, v) {
            final z = (x - v) / h;
            return a + math.exp(-0.5 * z * z);
          }) *
          norm
  ];
}

/// Inverse of the standard normal CDF (Acklam's approximation).
double normInv(double p) {
  const a = [-3.969683028665376e+01, 2.209460984245205e+02, -2.759285104469687e+02, 1.383577518672690e+02, -3.066479806614716e+01, 2.506628277459239e+00];
  const b = [-5.447609879822406e+01, 1.615858368580409e+02, -1.556989798598866e+02, 6.680131188771972e+01, -1.328068155288572e+01];
  const c = [-7.784894002430293e-03, -3.223964580411365e-01, -2.400758277161838e+00, -2.549732539343734e+00, 4.374664141464968e+00, 2.938163982698783e+00];
  const d = [7.784695709041462e-03, 3.224671290700398e-01, 2.445134137142996e+00, 3.754408661907416e+00];
  const plow = 0.02425, phigh = 1 - plow;
  double tail(double q) =>
      (((((c[0] * q + c[1]) * q + c[2]) * q + c[3]) * q + c[4]) * q + c[5]) /
      ((((d[0] * q + d[1]) * q + d[2]) * q + d[3]) * q + 1);
  if (p <= 0) return -8;
  if (p >= 1) return 8;
  if (p < plow) return tail(math.sqrt(-2 * math.log(p)));
  if (p > phigh) return -tail(math.sqrt(-2 * math.log(1 - p)));
  final q = p - .5, r = q * q;
  return (((((a[0] * r + a[1]) * r + a[2]) * r + a[3]) * r + a[4]) * r + a[5]) * q /
      (((((b[0] * r + b[1]) * r + b[2]) * r + b[3]) * r + b[4]) * r + 1);
}
