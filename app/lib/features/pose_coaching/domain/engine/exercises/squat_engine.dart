import 'package:ai_trainer/core/utils/cv_math.dart';
import 'package:ai_trainer/features/pose_coaching/domain/engine/exercises/exercise_engine.dart';
import 'package:ai_trainer/features/pose_coaching/domain/engine/exercises/lower_body_checks.dart';
import 'package:ai_trainer/features/pose_coaching/domain/engine/form_evaluation.dart';
import 'package:ai_trainer/features/pose_coaching/domain/engine/pose_geometry.dart';
import 'package:ai_trainer/features/pose_coaching/domain/entities/form_level.dart';
import 'package:ai_trainer/features/pose_coaching/domain/entities/posture_assessment.dart';

/// SquatTrainer.py: a rep counts from the partial depth; partial, deep and extra deep
/// are counted separately (repThresholds.depthClasses)
class SquatEngine extends ExerciseEngine {
  SquatEngine(super.ctx);

  int partialReps = 0, deepReps = 0, extraReps = 0;

  SquatDepthCounts get depthCounts =>
      SquatDepthCounts(partial: partialReps, deep: deepReps, extraDeep: extraReps);

  // knee angle that already counts as a PARTIAL rep / DEEP / EXTRA DEEP
  double get partialAngle => ctx.rules.band.depthClasses?.partial.maxKneeAngleDeg ?? 130;
  double get deepAngle => ctx.rules.band.depthClasses?.deep.maxKneeAngleDeg ?? 110;
  double get extraDeepAngle => ctx.rules.band.depthClasses?.extraDeep.maxKneeAngleDeg ?? 95;
  // false = partial reps are shown but not added to the total
  bool get countPartial => ctx.rules.band.depthClasses?.partial.countsAsRep ?? true;

  @override
  FormEvaluation evaluate(double per, bool? front) {
    final ev = FormEvaluation();
    final g = ctx.geo, rules = ctx.rules;
    final sh = g.mid(11, 12), hp = g.mid(23, 24);
    if (sh != null && hp != null) {
      // trunk lean varies a lot with leg/torso proportions, so the limit is generous
      ev.limit(PoseGeometry.fromVertical(hp, sh) - rules.warn('trunk_lean', 60), 20, 'Chest up - leaning far',
          block: rules.rejects('trunk_lean', true), blockAt: rules.rejectMargin('trunk_lean'));
    }
    if (front == true) {
      frontLegChecks(ev, g, per,
          stanceMin: rules.warn('stance_narrow', 0.6),
          stanceMax: rules.warn('stance_wide', 2.0),
          caveLimit: rules.warn('knee_cave', 0.15),
          caveBlocks: rules.rejects('knee_cave', true),
          caveBlockAt: rules.rejectMargin('knee_cave'));
    }
    ev.assessable = ev.scores.isNotEmpty;
    return ev;
  }

  /// a partial rep is already a rep, so the bottom is the partial depth
  /// (the bar still fills to 100% at extra deep)
  @override
  double get bottomPercent {
    final e = active;
    return interp(partialAngle, e.downAngle, e.upAngle, 100, 0).clamp(35.0, 100.0).toDouble();
  }

  /// range of motion is scored against full depth, not the partial counting line
  @override
  double get romTargetAngle => deepAngle;

  /// depth by the lowest knee angle: 0 partial, 1 deep, 2 extra deep
  @override
  RepOutcome classifyRep(List<String> faults) {
    final minAngle = ctx.rep.minAngle;
    var depth = 0;
    if (minAngle <= extraDeepAngle) {
      depth = 2;
    } else if (minAngle <= deepAngle) {
      depth = 1;
    }
    var counted = faults.isEmpty;
    if (depth == 0 && !countPartial) counted = false;
    if (faults.isNotEmpty) return RepOutcome('Incorrect', FormLevel.bad, counted: counted, depth: depth);
    if (depth == 2) return RepOutcome('Extra deep', FormLevel.good, counted: counted, depth: depth);
    if (depth == 1) return RepOutcome('Deep', FormLevel.good, counted: counted, depth: depth);
    return RepOutcome(counted ? 'Partial' : 'Partial - not counted', FormLevel.warn,
        counted: counted, depth: depth);
  }

  @override
  void onCounted(RepOutcome outcome) {
    if (outcome.depth == 0) {
      partialReps++;
    } else if (outcome.depth == 1) {
      deepReps++;
    } else {
      extraReps++;
    }
  }

  @override
  RepOutcome incompleteRep() =>
      const RepOutcome('Incorrect', FormLevel.bad, detail: 'Too shallow - not counted', counted: false);

  /// white ticks: lower = partial line, upper = deep line, top of the bar = extra deep
  @override
  List<double> get depthTickAngles => [partialAngle, deepAngle];

  @override
  void resetSession() {
    partialReps = 0;
    deepReps = 0;
    extraReps = 0;
  }
}
