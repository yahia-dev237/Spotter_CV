import 'package:ai_trainer/features/pose_coaching/domain/engine/coaching_context.dart';
import 'package:ai_trainer/features/pose_coaching/domain/engine/form_evaluation.dart';
import 'package:ai_trainer/features/pose_coaching/domain/engine/tracking_config.dart';
import 'package:ai_trainer/features/pose_coaching/domain/entities/exercise_kind.dart';
import 'package:ai_trainer/features/pose_coaching/domain/entities/form_level.dart';

/// how a finished (or rejected) rep is reported
class RepOutcome {
  const RepOutcome(this.label, this.level, {this.detail, this.counted = true, this.depth});
  final String label;
  final FormLevel level;
  final String? detail; // null = the first fault, or nothing
  final bool counted;
  final int? depth; // squat: 0 partial, 1 deep, 2 extra deep
}

/// values only the debug HUD needs
class FrameDebug {
  const FrameDebug({
    required this.sideRaw,
    required this.frontRaw,
    required this.reachPer,
    required this.gateOk,
    required this.rightOk,
    required this.leftOk,
  });
  final double sideRaw;
  final double? frontRaw;
  final double reachPer;
  final bool gateOk;
  final bool rightOk;
  final bool leftOk;
}

/// The parts of the trainer that are different for each exercise (AiTrainer.py,
/// SquatTrainer.py, DeadliftTrainer.py, BenchPressTrainer.py). The CoachingSession
/// runs the same rep loop for every exercise and asks the engine at each step.
/// Thresholds come from the database through [CoachingContext.rules].
abstract class ExerciseEngine {
  ExerciseEngine(this.ctx);

  final CoachingContext ctx;

  ExerciseKind get kind => ctx.config.kind;

  /// the joints measured now (the curl arm menu can change them)
  TrackingConfig get active => ctx.config;

  // ---- seeing the person ----

  /// landmarks that must ALL be visible before anything is tracked (null = only the joints)
  List<int>? get fullBodyLandmarks => null;

  /// short landmark dropouts are ridden out for this long (seconds)
  double get lostGrace => 0.4;

  /// what the feedback card says while the joints are not seen
  String? get lostMessage => null;

  // ---- measuring the angle ----

  /// called before the angles of each frame (decide side / front view while idle)
  void beforeAngles() {}

  /// correct one side's 2D angle (the curl facing the camera)
  double adjustAngle(List<int> chain, double angle) => angle;

  /// a second depth measure facing the camera (deadlift); the lower angle is used
  double? frontAngle() => null;

  /// false = left/right difference is not judged this frame
  bool get asymmetryAllowed => true;

  // ---- during the rep ----

  /// false = the position is wrong and no rep may start or reach the bottom (bench: lying down)
  bool gate(double t) => true;

  /// extra checks during the whole rep (deadlift: did it turn into a squat?)
  void trackRep(double smoothed) {}

  /// form checks of this frame
  FormEvaluation evaluate(double per, bool? front);

  /// deg/s that is still a controlled rep (form score tempo)
  double get maxSpeed => 300;

  /// above this speed "Slow down - control it" is shown
  double get tooFastSpeed => 1.3 * maxSpeed;

  void onRepStart() {}

  /// the depth (%) that counts as the bottom
  double get bottomPercent => 100;

  /// how long the bottom must be held (seconds)
  double get holdSeconds => 0.10;

  // ---- the end of the rep ----

  /// not counted at all, e.g. a squat during the deadlift (null = normal rep)
  RepOutcome? rejectRep() => null;

  /// true = form faults only warn, the rep is still counted (only the position checks decide)
  bool get softFaults => false;

  RepOutcome classifyRep(List<String> faults) {
    final soft = softFaults;
    if (faults.isEmpty) return const RepOutcome('Good rep', FormLevel.good);
    return soft
        ? const RepOutcome('Counted - check form', FormLevel.warn)
        : const RepOutcome('Rejected', FormLevel.bad, counted: false);
  }

  /// the angle a full range of motion reaches (squat: full depth, not the counting line)
  double get romTargetAngle => active.downAngle;

  /// a counted rep: per-exercise counters (squat depths, curl arms)
  void onCounted(RepOutcome outcome) {}

  /// the rep went part way down and came back
  RepOutcome incompleteRep();

  /// +1 / -1 buttons (curl: the reps of each arm)
  void onRepAdjusted(int d) {}

  // ---- HUD ----

  void addDebug(List<String> dbg, FrameDebug d) {}

  /// squat: knee angles of the white ticks on the depth bar
  List<double> get depthTickAngles => const [];

  // ---- reset ----

  /// the person was lost: forget this exercise's state of the half-finished rep
  void resetTracking() {}

  /// counting starts again from 0
  void resetSession() {}
}
