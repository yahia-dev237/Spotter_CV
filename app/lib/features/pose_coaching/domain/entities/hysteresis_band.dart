import 'package:equatable/equatable.dart';

/// how a rep is measured and counted (exercises/{exerciseId}.repThresholds).
/// The joint angle goes from [upperDeg] (0 %, start) to [lowerDeg] (100 %, bottom)
/// and back; the other fields are per-exercise extras and are null when unused.
class HysteresisBand extends Equatable {
  final String primaryAngle; // knee, hip or elbow
  final double lowerDeg;
  final double upperDeg;
  // "per-frame ..." or "per-time ..." (null = per-time)
  final String? smoothing;
  // squat
  final DepthClasses? depthClasses;
  // deadlift
  final Map<String, AngleRange>? hipAngleVariants;
  final BottomReachedPct? bottomReachedBarPct;
  final double? squatInsteadOfDeadliftKneeAngleDeg;
  // bench
  final bool? usesStraighterArm;
  // biceps curl
  final double? maxSpeedDegPerSec;
  final double? maxSpeedWarnMultiplier;
  // not used by the CV engine yet (kept so the database round-trips unchanged):
  final BarPosition? barPosition; // deadlift depth from the bar (wrists) position
  final double? lockoutBarPct; // deadlift lockout check
  final AngleRange? facingCamera; // curl range when facing the camera
  final double? upperArmFromVerticalLimitDeg; // curl upper-arm cap
  final double? upperArmBarCapPct;
  final String? note;

  const HysteresisBand({
    required this.primaryAngle,
    required this.lowerDeg,
    required this.upperDeg,
    this.smoothing,
    this.depthClasses,
    this.hipAngleVariants,
    this.bottomReachedBarPct,
    this.squatInsteadOfDeadliftKneeAngleDeg,
    this.usesStraighterArm,
    this.maxSpeedDegPerSec,
    this.maxSpeedWarnMultiplier,
    this.barPosition,
    this.lockoutBarPct,
    this.facingCamera,
    this.upperArmFromVerticalLimitDeg,
    this.upperArmBarCapPct,
    this.note,
  });

  /// true = "0.7 old + 0.3 new" every frame (squat), false = the same per time at 15 fps
  bool get perFrameSmoothing => smoothing?.startsWith('per-frame') ?? false;

  @override
  List<Object?> get props => [
    primaryAngle,
    lowerDeg,
    upperDeg,
    smoothing,
    depthClasses,
    hipAngleVariants,
    bottomReachedBarPct,
    squatInsteadOfDeadliftKneeAngleDeg,
    usesStraighterArm,
    maxSpeedDegPerSec,
    maxSpeedWarnMultiplier,
    barPosition,
    lockoutBarPct,
    facingCamera,
    upperArmFromVerticalLimitDeg,
    upperArmBarCapPct,
    note,
  ];
}

/// a joint angle range: [topDeg] at the start, [bottomDeg] at the bottom of the rep
class AngleRange extends Equatable {
  final double topDeg;
  final double bottomDeg;
  final String? note;

  const AngleRange({required this.topDeg, required this.bottomDeg, this.note});

  @override
  List<Object?> get props => [topDeg, bottomDeg, note];
}

/// squat depth levels by the lowest knee angle of the rep
class DepthClasses extends Equatable {
  final DepthClass partial;
  final DepthClass deep;
  final DepthClass extraDeep;

  const DepthClasses({required this.partial, required this.deep, required this.extraDeep});

  @override
  List<Object?> get props => [partial, deep, extraDeep];
}

class DepthClass extends Equatable {
  final double maxKneeAngleDeg;
  // null = not set in the database
  final bool? countsAsRep;

  const DepthClass({required this.maxKneeAngleDeg, this.countsAsRep});

  @override
  List<Object?> get props => [maxKneeAngleDeg, countsAsRep];
}

/// deadlift: the depth (in %) that counts as the bottom, filmed from the side / the front
class BottomReachedPct extends Equatable {
  final double side;
  final double front;

  const BottomReachedPct({required this.side, required this.front});

  @override
  List<Object?> get props => [side, front];
}

/// deadlift bar position measured from the wrists, in shin lengths
class BarPosition extends Equatable {
  final Map<String, List<int>> landmarks; // wrists, knees, ankles
  final double topShinLengths;
  final double bottomShinLengths;
  final String? source;

  const BarPosition({
    required this.landmarks,
    required this.topShinLengths,
    required this.bottomShinLengths,
    this.source,
  });

  @override
  List<Object?> get props => [landmarks, topShinLengths, bottomShinLengths, source];
}
