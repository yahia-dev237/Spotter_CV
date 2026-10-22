import 'package:ai_trainer/features/pose_coaching/domain/entities/exercise_kind.dart';
import 'package:ai_trainer/features/pose_coaching/domain/entities/exercise_rule_set.dart';

/// which joints are measured and the angle range of one rep, taken from
/// [ExerciseRuleSet.repThresholds] (primaryAngle, lowerDeg, upperDeg, smoothing)
class TrackingConfig {
  const TrackingConfig({
    required this.kind,
    required this.right,
    this.left,
    required this.downAngle,
    required this.upAngle,
    this.perFrameSmoothing = false,
    this.variant = 'conventional',
  });

  final ExerciseKind kind;
  final List<int> right; // the 3 landmark ids of the right side
  final List<int>? left; // null = only the right side (AiTrainer.py)
  final double downAngle; // angle at 100%
  final double upAngle; // angle at 0%
  // true = exactly like the python file: "0.7*old + 0.3*new" every frame
  // (felt better for the squat on the phone than the timed version)
  final bool perFrameSmoothing;
  // deadlift variation: 'conventional', 'sumo' or 'romanian'
  final String variant;

  /// AiTrainer.py is the first version: one arm
  bool get oneSide => left == null;

  TrackingConfig copyWith({List<int>? right, List<int>? left, bool clearLeft = false}) => TrackingConfig(
    kind: kind,
    right: right ?? this.right,
    left: clearLeft ? null : (left ?? this.left),
    downAngle: downAngle,
    upAngle: upAngle,
    perFrameSmoothing: perFrameSmoothing,
    variant: variant,
  );

  // joint chains (landmark ids) of each primaryAngle
  static const rightElbow = [12, 14, 16], leftElbow = [11, 13, 15]; // shoulder, elbow, wrist
  static const rightKnee = [24, 26, 28], leftKnee = [23, 25, 27]; // hip, knee, ankle
  static const rightHip = [12, 24, 26], leftHip = [11, 23, 25]; // shoulder, hip, knee

  /// null = the camera cannot track this exercise (no repThresholds or no engine)
  static TrackingConfig? fromRuleSet(ExerciseRuleSet ruleSet, {String variant = 'conventional'}) {
    final band = ruleSet.repThresholds;
    final kind = ExerciseKind.fromId(ruleSet.exerciseId);
    if (band == null || kind == null) return null;
    final (List<int> right, List<int> left) = switch (band.primaryAngle) {
      'knee' => (rightKnee, leftKnee),
      'hip' => (rightHip, leftHip),
      _ => (rightElbow, leftElbow),
    };
    // a deadlift variation has its own hip angle range
    final range = band.hipAngleVariants?[variant];
    return TrackingConfig(
      kind: kind,
      right: right,
      // the biceps curl starts with one arm; the arm menu changes it
      left: kind == ExerciseKind.bicepsCurl ? null : left,
      downAngle: range?.bottomDeg ?? band.lowerDeg,
      upAngle: range?.topDeg ?? band.upperDeg,
      perFrameSmoothing: band.perFrameSmoothing,
      variant: variant,
    );
  }
}
