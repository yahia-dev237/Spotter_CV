import 'package:equatable/equatable.dart';
import 'package:ai_trainer/features/pose_coaching/domain/entities/risk_level.dart';

/// how [RiskRule.metric] is compared with the thresholds
enum RuleComparator {
  gt, // fault when the metric is greater
  lt, // fault when the metric is smaller
  range; // fault outside warnThresholdMin..warnThresholdMax

  static RuleComparator fromName(String name) =>
      RuleComparator.values.firstWhere((c) => c.name == name, orElse: () => RuleComparator.gt);
}

/// one form check of an exercise (exercises/{exerciseId}.rules[])
class RiskRule extends Equatable {
  final String id;
  final String fault;
  final String metric;
  final RuleComparator comparator;
  // show a warning past this value
  final double? warnThreshold;
  // comparator == range
  final double? warnThresholdMin;
  final double? warnThresholdMax;
  // reject the rep past this value (null = warn only)
  final double? rejectThreshold;
  // the main limit; the same as warnThreshold when both exist
  final double threshold;
  final RiskLevel severity;
  // when the check runs, e.g. "facing_camera", "side_view_bar_ge_60"
  final String? activeWhen;
  // the message in [ExerciseRuleSet.cues]
  final String cueKey;
  // not used by the CV engine yet (kept so the database round-trips unchanged):
  final String? adaptive; // e.g. squat trunk lean limit that adapts to thigh/torso ratio
  final bool? usesToe;
  final String? overrideKey;
  final String? note;

  const RiskRule({
    required this.id,
    required this.fault,
    required this.metric,
    required this.comparator,
    this.warnThreshold,
    this.warnThresholdMin,
    this.warnThresholdMax,
    this.rejectThreshold,
    required this.threshold,
    required this.severity,
    this.activeWhen,
    required this.cueKey,
    this.adaptive,
    this.usesToe,
    this.overrideKey,
    this.note,
  });

  /// the warning limit: warnThreshold, or threshold when the rule has no warnThreshold
  double get warnLimit => warnThreshold ?? threshold;

  @override
  List<Object?> get props => [
    id,
    fault,
    metric,
    comparator,
    warnThreshold,
    warnThresholdMin,
    warnThresholdMax,
    rejectThreshold,
    threshold,
    severity,
    activeWhen,
    cueKey,
    adaptive,
    usesToe,
    overrideKey,
    note,
  ];
}
