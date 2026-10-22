import 'dart:math' as math;

import 'package:ai_trainer/features/pose_coaching/domain/engine/form_evaluation.dart';
import 'package:ai_trainer/features/pose_coaching/domain/engine/warning_tracker.dart';
import 'package:ai_trainer/features/pose_coaching/domain/entities/form_level.dart';

/// form score = alignment (60%) + range of motion of the last rep (25%) +
/// tempo/consistency (15%). Missing parts are left out, never faked.
class FormScorer {
  static const formTau = 0.35; // form score smoothing time constant

  double formScore = 0;
  bool formReady = false; // false = "Form not assessable"
  double lastFormTime = 0;
  double lastAssessable = -99;
  int formState = 0; // 0 good, 1 warn, 2 bad (with hysteresis)

  int _nextState(int s, double v) {
    const good = 80.0, bad = 55.0, hy = 5.0; // hysteresis: the colour doesn't flicker
    if (s == 0) return v < good - hy ? (v < bad ? 2 : 1) : 0;
    if (s == 1) return v >= good + hy ? 0 : (v < bad - hy ? 2 : 1);
    return v >= bad + hy ? (v >= good + hy ? 0 : 1) : 2;
  }

  void update(
    FormEvaluation ev,
    double t, {
    required double speed,
    required double maxSpeed,
    required double? lastRom,
    required double? lastConsistency,
  }) {
    if (!(ev.assessable && ev.scores.isNotEmpty)) {
      if (t - lastAssessable > 0.4) formReady = false;
      return;
    }
    lastAssessable = t;
    final mean = ev.scores.reduce((a, b) => a + b) / ev.scores.length;
    final align = 0.5 * mean + 0.5 * ev.scores.reduce(math.min); // worst check counts
    final ms = maxSpeed;
    final tempoNow = speed <= ms ? 1.0 : (1 - (speed - ms) / ms).clamp(0.0, 1.0).toDouble();
    var acc = 0.0, wsum = 0.0;
    void part(double? v, double wt) {
      if (v != null) {
        acc += v * wt;
        wsum += wt;
      }
    }

    part(align, 0.6);
    part(lastRom, 0.25);
    final lc = lastConsistency;
    part(lc == null ? tempoNow : (tempoNow + lc) / 2, 0.15);
    final target = 100 * acc / wsum;
    final dt = (t - lastFormTime).clamp(0.0, 1.0).toDouble();
    lastFormTime = t;
    formScore = formReady ? formScore + (target - formScore) * (1 - math.exp(-dt / formTau)) : target;
    if (!formReady) formState = 0;
    formReady = true;
    formState = _nextState(formState, formScore);
  }

  /// colour of the depth bar, the rep progress and the form ring
  FormLevel level(WarningTracker warnings, double t) {
    if (!formReady) return FormLevel.notAssessable;
    var st = formState;
    if (warnings.shown.isNotEmpty) st = math.max(st, 1); // never emerald while a warning is up
    if (warnings.shown.any((m) => warnings.severeNow(m, t))) st = 2;
    return st == 0 ? FormLevel.good : (st == 1 ? FormLevel.warn : FormLevel.bad);
  }

  String word(WarningTracker warnings) {
    if (!formReady) return 'NOT ASSESSABLE';
    if (formScore >= 90 && warnings.shown.isEmpty && formState == 0) return 'FLAWLESS';
    return const ['GOOD', 'ADJUST', 'FAULT'][formState.clamp(0, 2)];
  }
}
