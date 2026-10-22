import 'dart:math' as math;

import 'package:ai_trainer/features/pose_coaching/domain/engine/exercises/exercise_engine.dart';
import 'package:ai_trainer/features/pose_coaching/domain/engine/form_evaluation.dart';
import 'package:ai_trainer/features/pose_coaching/domain/engine/pose_geometry.dart';
import 'package:ai_trainer/features/pose_coaching/domain/engine/tracking_config.dart';
import 'package:ai_trainer/features/pose_coaching/domain/entities/form_level.dart';
import 'package:ai_trainer/features/pose_coaching/domain/entities/posture_assessment.dart';

/// AiTrainer.py: biceps curl, one arm, both arms or alternating
class CurlEngine extends ExerciseEngine {
  CurlEngine(super.ctx);

  // 0 = right arm, 1 = left arm, 2 = both arms together,
  // 3 = alternate starting with the right arm, 4 = alternate starting with the left arm
  int armMode = 0;
  bool get altMode => armMode >= 3;

  // ---- alternate mode: only the arm that is "next" can count a rep ----
  bool altRightNext = true;
  int repsR = 0, repsL = 0; // counted reps per arm

  // ---- filmed facing the camera (decided while idle, frozen during a rep) ----
  bool curlFront = false;
  double dbgCurlFront = double.nan; // angle estimated from the wrist height (debug)

  ArmStatus get armStatus => ArmStatus(
    mode: armMode,
    alternate: altMode,
    rightNext: altRightNext,
    repsRight: repsR,
    repsLeft: repsL,
  );

  /// the arm(s) the user picked; everything else stays as configured
  @override
  TrackingConfig get active {
    // alternate: only the arm that is next is tracked (one-arm logic), then it swaps
    final useLeft = armMode >= 3 ? !altRightNext : armMode == 1;
    return ctx.config.copyWith(
      right: useLeft ? TrackingConfig.leftElbow : TrackingConfig.rightElbow,
      left: armMode == 2 ? TrackingConfig.leftElbow : null,
      clearLeft: armMode != 2,
    );
  }

  /// curl arm choice. Returns false when nothing changed.
  bool setArmMode(int m) {
    if (m == armMode) return false;
    armMode = m;
    altRightNext = m != 4; // 3 = right first, 4 = left first
    return true;
  }

  @override
  double get maxSpeed => ctx.rules.band.maxSpeedDegPerSec ?? 400;

  @override
  double get tooFastSpeed =>
      ctx.rules.warn('too_fast', (ctx.rules.band.maxSpeedWarnMultiplier ?? 1.3) * maxSpeed);

  @override
  void beforeAngles() {
    // side on (or unknown) = false = everything works exactly as before
    if (ctx.idle) curlFront = ctx.geo.frontal() == true;
  }

  /// Facing the camera the 2D angle drops too early (quarter reps counted), so a rep
  /// needs the wrist-height angle to show the flexion too: the STRAIGHTER of the two is used
  @override
  double adjustAngle(List<int> chain, double angle) {
    if (!curlFront) return angle;
    final f = _frontAngle(chain, ctx.idle);
    if (f == null || !f.isFinite) return angle;
    dbgCurlFront = f;
    return angle.isFinite ? math.max(angle, f) : f;
  }

  /// Facing the camera the forearm moves toward the lens, so the 2D elbow angle drops
  /// far too early (a quarter curl already looked like a full one). Better: the height of the
  /// wrist above/below the elbow compared with the arm hanging. cos(flexion) = height / hanging
  /// height, so 0 deg flexion = hanging and about 150 = wrist up at the shoulder.
  /// Returned as an equivalent elbow angle (180 = straight).
  double? _frontAngle(List<int> arm, bool idle) {
    final g = ctx.geo;
    final el = g.p(arm[1]), wr = g.p(arm[2]);
    if (el == null || wr == null || !g.vis([arm[1], arm[2]])) return null;
    final drop = wr.dy - el.dy; // wrist below the elbow = positive
    final full = ctx.baseline.stand('fa${arm[0]}', drop, idle);
    if (full < 1) return null;
    final c = (drop / full).clamp(-1.0, 1.0).toDouble();
    return 180 - math.acos(c) * 180 / math.pi;
  }

  @override
  FormEvaluation evaluate(double per, bool? front) {
    final ev = FormEvaluation();
    final g = ctx.geo, base = ctx.baseline, rules = ctx.rules, idle = ctx.idle;
    final e = active;
    // limits from the database (percent rules are stored as 12 = 12 %)
    final elbowDrift = rules.warn('elbow_drift', 25);
    final elbowDriftReject = rules.rejectMargin('elbow_drift') ?? 30;
    final swing = rules.warn('body_swing', 12);
    final swingReject = rules.rejectMargin('body_swing') ?? 20;
    final shrug = rules.warn('shoulder_shrug', 12) / 100;
    final twist = rules.warn('torso_twist', 20) / 100;
    final armShorten = rules.warn('elbow_forward', 25) / 100;
    // one arm or both arms (see armMode): every active arm is checked
    for (final arm in [e.right, if (e.left != null) e.left!]) {
      final isRight = arm[0] == 12;
      final hipId = isRight ? 24 : 23, otherShId = isRight ? 11 : 12;
      final s = g.p(arm[0]), el = g.p(arm[1]), hip = g.p(hipId);
      if (s == null || el == null || hip == null || !g.vis([arm[0], arm[1], hipId])) {
        continue; // hip hidden: swing cannot be judged for this arm
      }
      final torso = (s - hip).distance;
      if (torso < 1) continue;
      // 1) upper arm should stay near the torso; elbow swinging forward = shoulder is helping
      ev.limit(PoseGeometry.ang(hip, s, el) - elbowDrift, 30, 'Elbow drifting forward',
          block: rules.rejects('elbow_drift', true), blockAt: elbowDriftReject);
      // 2) body swing: torso lean compared with the user's own start posture
      final lean = PoseGeometry.fromVertical(hip, s);
      // side on, the far hip is partly hidden and wobbles, so this only REJECTS a rep
      // when the body really moves (swing + swingReject degrees from the start posture)
      ev.limit((lean - base.follow('lean$hipId', lean, idle)).abs() - swing, 20, 'Swinging - stay still',
          block: rules.rejects('body_swing', true), blockAt: swingReject);
      // 3) shoulder shrug: torso length (hip to shoulder) changes
      ev.limit(((torso / base.follow('torso$hipId', torso, idle)) - 1).abs() - shrug, 0.12,
          curlFront ? 'Leaning - keep still' : 'Shoulders shrugging');
      // 4) torso twist: shoulder width changes a lot
      final s2 = g.p(otherShId);
      if (s2 != null && g.vis([otherShId])) {
        final sw = (s - s2).distance;
        ev.limit(((sw / base.follow('sw$hipId', sw, idle)) - 1).abs() - twist, 0.2, 'Torso twisting');
      }
      // 5) ONLY when facing the camera (curlFront): an elbow moving forward points at the
      // lens, so check 1 cannot see it. The upper arm then looks SHORTER than at the start.
      // Warn only (never rejects), and it does nothing at all when filmed from the side.
      if (curlFront) {
        final ua = (s - el).distance;
        final ba = base.follow('ua$hipId', ua, idle);
        if (ba > 1) {
          ev.limit(1 - ua / ba - armShorten, 0.25, 'Elbow drifting forward');
        }
      }
      ev.assessable = true;
    }
    return ev;
  }

  /// which arm did the counted rep
  void _trackArm() {
    if (armMode == 0) {
      repsR++;
    } else if (armMode == 1) {
      repsL++;
    } else if (armMode == 2) {
      repsR++;
      repsL++;
    } else if (altRightNext) {
      repsR++;
    } else {
      repsL++;
    }
  }

  /// alternate mode: the other arm is next. Its angle history starts fresh and it
  /// must be at the bottom before a rep can begin (so a half-raised arm does not count).
  void _swapAlternateArm() {
    altRightNext = !altRightNext;
    ctx.filter.resetHistory();
    ctx.rep.needRest = true;
  }

  @override
  void onCounted(RepOutcome outcome) {
    _trackArm();
    if (altMode) _swapAlternateArm();
  }

  @override
  void onRepAdjusted(int d) {
    if (d > 0) {
      _trackArm();
      return;
    }
    if (armMode == 0) repsR = math.max(0, repsR - 1);
    if (armMode == 1) repsL = math.max(0, repsL - 1);
    if (armMode == 2) {
      repsR = math.max(0, repsR - 1);
      repsL = math.max(0, repsL - 1);
    }
  }

  @override
  RepOutcome incompleteRep() =>
      const RepOutcome('Incomplete rep', FormLevel.warn, detail: 'Curl through full range', counted: false);

  @override
  void addDebug(List<String> dbg, FrameDebug d) {
    dbg.add('view ${curlFront ? 'FRONT' : 'side'}  smooth ratio ${ctx.rep.dbgSmoothRatio.toStringAsFixed(2)}'
        '${curlFront ? '  wrist-angle ${dbgCurlFront.isFinite ? dbgCurlFront.round() : '-'}' : ''}'
        '${altMode ? '  next ${altRightNext ? 'R' : 'L'}' : ''}');
  }

  @override
  void resetSession() {
    repsR = 0;
    repsL = 0;
  }
}
