/// FSRS-6, the Free Spaced Repetition Scheduler (open-spaced-repetition, MIT), written again here in plain Dart with
/// its published default parameters. A word's memory is three numbers: stability S (days until recall falls to 90 %),
/// difficulty D (1 easy … 10 hard) and, at any moment, retrievability R (the chance it is still recalled).
///
/// Verbarium uses only the long-term part: the first answer of a day moves the memory, later answers the same day are
/// practice (Engine.answer). Ratings: 1 again, 2 hard, 3 good, 4 easy.
library;

import 'dart:math';

class Fsrs {
  /// FSRS-6 default parameters w0 … w20
  static const w = [
    0.212, 1.2931, 2.3065, 8.2956, 6.4133, 0.8334, 3.0194, 0.001, 1.8722, 0.1666, 0.796, //
    1.4835, 0.0614, 0.2629, 1.6483, 0.6014, 1.8729, 0.5425, 0.0912, 0.0658, 0.1542,
  ];

  static const again = 1, hard = 2, good = 3, easy = 4;

  /// the retention aimed at: an interval ends when R reaches it
  static const retention = 0.9;
  static const maxS = 36500.0;

  static double get _decay => w[20];
  static double get _factor => pow(0.9, -1 / _decay) - 1;

  /// the chance of recall [days] after the last review, for stability [s]
  static double r(double days, double s) {
    if (s <= 0) return 0;
    return pow(1 + _factor * max(0.0, days) / s, -_decay).toDouble();
  }

  /// days until R falls to [target]
  static double interval(double s, {double target = retention}) => s / _factor * (pow(target, -1 / _decay) - 1);

  static double s0(int g) => w[g - 1];

  static double d0(int g) => (w[4] - exp(w[5] * (g - 1)) + 1).clamp(1.0, 10.0);

  static double nextD(double d, int g) {
    final delta = -w[6] * (g - 3);
    final damped = d + delta * (10 - d) / 9;
    return (w[7] * d0(easy) + (1 - w[7]) * damped).clamp(1.0, 10.0);
  }

  /// stability after a recall with rating [g] (2 … 4) at retrievability [rr]
  static double recall(double d, double s, double rr, int g) {
    final hardPenalty = g == hard ? w[15] : 1.0;
    final easyBonus = g == easy ? w[16] : 1.0;
    final inc = exp(w[8]) * (11 - d) * pow(s, -w[9]) * (exp(w[10] * (1 - rr)) - 1) * hardPenalty * easyBonus;
    return min(maxS, s * (inc + 1));
  }

  /// stability after a lapse: never more than before
  static double forget(double d, double s, double rr) {
    final sf = w[11] * pow(d, -w[12]) * (pow(s + 1, w[13]) - 1) * exp(w[14] * (1 - rr));
    return max(0.01, min(s, sf));
  }

  /// the next (stability, difficulty) after rating [g] [days] after the last review; [s] == 0 means a first rating
  static (double, double) next(double s, double d, double days, int g) {
    if (s <= 0) return (s0(g), d0(g));
    final rr = r(days, s);
    final nd = nextD(d, g);
    final ns = g == again ? forget(d, s, rr) : recall(d, s, rr, g);
    return (ns, nd);
  }
}
