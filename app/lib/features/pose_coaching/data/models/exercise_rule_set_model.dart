import 'package:ai_trainer/features/pose_coaching/data/models/hysteresis_band_model.dart';
import 'package:ai_trainer/features/pose_coaching/data/models/json_reading.dart';
import 'package:ai_trainer/features/pose_coaching/data/models/localized_cue_model.dart';
import 'package:ai_trainer/features/pose_coaching/data/models/risk_rule_model.dart';
import 'package:ai_trainer/features/pose_coaching/domain/entities/exercise_rule_set.dart';

// Firestore: exercises/{exerciseId} (same shape as assets/data/exercises.json).
// toJson() writes the document back, for the exercise CRUD.
class ExerciseRuleSetModel extends ExerciseRuleSet {
  static const collection = 'exercises';

  const ExerciseRuleSetModel({
    required super.exerciseId,
    required super.nameAr,
    required super.nameEn,
    required super.requiredLandmarks,
    required super.repThresholds,
    required super.riskRules,
    required super.cues,
  });

  factory ExerciseRuleSetModel.fromJson(Map<String, dynamic> json) {
    final band = json['repThresholds'] as Map<String, dynamic>?;
    return ExerciseRuleSetModel(
      exerciseId: json['exerciseId'] as String,
      nameAr: json['nameAr'] as String? ?? '',
      nameEn: json['nameEn'] as String? ?? '',
      requiredLandmarks: readIntListOrNull(json['requiredLandmarks']),
      repThresholds: band == null ? null : HysteresisBandModel.fromJson(band),
      riskRules: ((json['rules'] as List?) ?? const [])
          .map((r) => RiskRuleModel.fromJson(r as Map<String, dynamic>))
          .toList(),
      cues: ((json['cues'] as Map<String, dynamic>?) ?? const {})
          .map((k, v) => MapEntry(k, LocalizedCueModel.fromJson(v as Map<String, dynamic>))),
    );
  }

  factory ExerciseRuleSetModel.fromEntity(ExerciseRuleSet e) => ExerciseRuleSetModel(
    exerciseId: e.exerciseId,
    nameAr: e.nameAr,
    nameEn: e.nameEn,
    requiredLandmarks: e.requiredLandmarks,
    repThresholds: e.repThresholds,
    riskRules: e.riskRules,
    cues: e.cues,
  );

  Map<String, dynamic> toJson() {
    final band = repThresholds;
    return {
      'exerciseId': exerciseId,
      'nameAr': nameAr,
      'nameEn': nameEn,
      'requiredLandmarks': requiredLandmarks,
      'repThresholds': band == null ? null : HysteresisBandModel.fromEntity(band).toJson(),
      'rules': riskRules.map((r) => RiskRuleModel.fromEntity(r).toJson()).toList(),
      'cues': cues.map((k, v) => MapEntry(k, LocalizedCueModel.fromEntity(v).toJson())),
    };
  }
}
