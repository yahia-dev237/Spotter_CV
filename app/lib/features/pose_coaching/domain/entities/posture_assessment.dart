import 'package:equatable/equatable.dart';
import 'package:ai_trainer/features/pose_coaching/domain/entities/coaching_feedback.dart';
import 'package:ai_trainer/features/pose_coaching/domain/entities/exercise_kind.dart';
import 'package:ai_trainer/features/pose_coaching/domain/entities/form_level.dart';
import 'package:ai_trainer/features/pose_coaching/domain/entities/joint_angle.dart';
import 'package:ai_trainer/features/pose_coaching/domain/entities/pose_frame.dart';

/// what ProcessPoseFrameUseCase (and the set commands) return: everything the
/// trainer screen shows, read from the coaching session at one moment
class PostureAssessment extends Equatable {
  final String exerciseId;
  final String exerciseName;
  final ExerciseKind kind;
  // true = only one side is tracked (the biceps curl), for the HUD text size
  final bool oneSide;

  final PoseFrame pose;
  // the exercise joints were seen in this frame
  final bool isTracking;
  // depth of the current rep, 0..100
  final double percent;
  final int reps;
  // findAngle lines of this frame
  final List<JointAngle> jointAngles;
  // live numbers for the debug HUD
  final List<String> debugLines;
  // squat: white ticks on the depth bar (partial and deep line), 0..100
  final List<double> depthTickPercents;

  final FormLevel formLevel;
  final bool formReady;
  final double formScore;
  final String formWord;
  final CoachingFeedback feedback;

  final SetProgress sets;
  final SquatDepthCounts? squatDepths; // squat only
  final ArmStatus? arms; // biceps curl only
  final bool? lyingCheck; // bench press only

  const PostureAssessment({
    required this.exerciseId,
    required this.exerciseName,
    required this.kind,
    required this.oneSide,
    required this.pose,
    required this.isTracking,
    required this.percent,
    required this.reps,
    required this.jointAngles,
    required this.debugLines,
    required this.depthTickPercents,
    required this.formLevel,
    required this.formReady,
    required this.formScore,
    required this.formWord,
    required this.feedback,
    required this.sets,
    this.squatDepths,
    this.arms,
    this.lyingCheck,
  });

  @override
  List<Object?> get props => [
    exerciseId,
    pose,
    isTracking,
    percent,
    reps,
    jointAngles,
    debugLines,
    formLevel,
    formReady,
    formScore,
    feedback,
    sets,
    squatDepths,
    arms,
    lyingCheck,
  ];
}

/// the set being done now and the last finished one
class SetProgress extends Equatable {
  final bool inSet; // lifting in the current set (starts at the first counted rep)
  final int setNumber;
  final int setReps;
  final double setStartTime; // seconds (time.time()) of the first rep
  final int lastSetReps;
  final double lastSetSeconds;
  final double? formAverage; // of the current / just finished set
  final double? fatigue; // 0..100, null until 3 reps are done
  final double? smoothness; // 0..100 of the last finished rep

  const SetProgress({
    required this.inSet,
    required this.setNumber,
    required this.setReps,
    required this.setStartTime,
    required this.lastSetReps,
    required this.lastSetSeconds,
    this.formAverage,
    this.fatigue,
    this.smoothness,
  });

  @override
  List<Object?> get props => [
    inSet,
    setNumber,
    setReps,
    setStartTime,
    lastSetReps,
    lastSetSeconds,
    formAverage,
    fatigue,
    smoothness,
  ];
}

/// squat: counted reps per depth level
class SquatDepthCounts extends Equatable {
  final int partial;
  final int deep;
  final int extraDeep;

  const SquatDepthCounts({required this.partial, required this.deep, required this.extraDeep});

  @override
  List<Object?> get props => [partial, deep, extraDeep];
}

/// biceps curl: which arm(s) and the reps of each arm
class ArmStatus extends Equatable {
  // 0 right, 1 left, 2 both, 3 alternate starting right, 4 alternate starting left
  final int mode;
  final bool alternate;
  final bool rightNext;
  final int repsRight;
  final int repsLeft;

  const ArmStatus({
    required this.mode,
    required this.alternate,
    required this.rightNext,
    required this.repsRight,
    required this.repsLeft,
  });

  @override
  List<Object?> get props => [mode, alternate, rightNext, repsRight, repsLeft];
}
