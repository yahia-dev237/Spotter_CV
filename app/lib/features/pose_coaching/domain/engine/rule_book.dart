import 'package:ai_trainer/features/pose_coaching/domain/entities/exercise_rule_set.dart';
import 'package:ai_trainer/features/pose_coaching/domain/entities/hysteresis_band.dart';

/// Reads the thresholds of one exercise from the database ([ExerciseRuleSet]).
/// Every value has a fallback, the number the trainer used before the database,
/// so a missing rule never breaks the coaching.
class RuleBook {
  RuleBook(this.ruleSet);

  final ExerciseRuleSet ruleSet;

  HysteresisBand get band => ruleSet.repThresholds!;

  /// warn past this value (rules[id].warnThreshold)
  double warn(String id, double fallback) => ruleSet.rule(id)?.warnLimit ?? fallback;

  /// reject the rep past this value (rules[id].rejectThreshold), null = warn only
  double? reject(String id) => ruleSet.rule(id)?.rejectThreshold;

  /// how far past the warning a rep is rejected (rejectThreshold - warnThreshold)
  double? rejectMargin(String id) {
    final r = ruleSet.rule(id);
    final reject = r?.rejectThreshold;
    if (r == null || reject == null) return null;
    return (reject - r.warnLimit).abs();
  }

  /// true = a clear fault rejects the rep (the rule has a rejectThreshold);
  /// [fallback] when the rule is not in the database
  bool rejects(String id, bool fallback) {
    final r = ruleSet.rule(id);
    return r == null ? fallback : r.rejectThreshold != null;
  }

  /// lower / upper end of a range rule (comparator "range")
  double warnMin(String id, double fallback) => ruleSet.rule(id)?.warnThresholdMin ?? fallback;
  double warnMax(String id, double fallback) => ruleSet.rule(id)?.warnThresholdMax ?? fallback;
}
