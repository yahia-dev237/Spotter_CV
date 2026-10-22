import 'package:equatable/equatable.dart';
import 'package:ai_trainer/features/pose_coaching/domain/entities/hysteresis_band.dart';
import 'package:ai_trainer/features/pose_coaching/domain/entities/localized_cue.dart';
import 'package:ai_trainer/features/pose_coaching/domain/entities/risk_rule.dart';

/// one exercise of the database (Firestore exercises/{exerciseId}): how reps are
/// counted, which form rules are checked and what the coach says
class ExerciseRuleSet extends Equatable {
  final String exerciseId;
  final String nameAr;
  final String nameEn;
  // null = no camera tracking for this exercise
  final List<int>? requiredLandmarks;
  // null = no camera tracking for this exercise (it can still be logged in a workout)
  final HysteresisBand? repThresholds;
  final List<RiskRule> riskRules;
  final Map<String, LocalizedCue> cues;

  const ExerciseRuleSet({
    required this.exerciseId,
    required this.nameAr,
    required this.nameEn,
    required this.requiredLandmarks,
    required this.repThresholds,
    required this.riskRules,
    required this.cues,
  });

  /// true when the camera can count reps and check form for this exercise
  bool get hasCvEngine => repThresholds != null;

  RiskRule? rule(String id) {
    for (final r in riskRules) {
      if (r.id == id) return r;
    }
    return null;
  }

  @override
  List<Object?> get props => [
    exerciseId,
    nameAr,
    nameEn,
    requiredLandmarks,
    repThresholds,
    riskRules,
    cues,
  ];
}
