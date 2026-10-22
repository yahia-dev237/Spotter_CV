import 'dart:math' as math;

import 'package:ai_trainer/features/pose_coaching/domain/engine/exercises/exercise_engine.dart';
import 'package:ai_trainer/features/pose_coaching/domain/engine/exercises/lower_body_checks.dart';
import 'package:ai_trainer/features/pose_coaching/domain/engine/form_evaluation.dart';
import 'package:ai_trainer/features/pose_coaching/domain/engine/pose_geometry.dart';
import 'package:ai_trainer/features/pose_coaching/domain/entities/form_level.dart';

/// DeadliftTrainer.py: hip hinge, checked from the side or facing the camera.
/// Not in the database yet (kept as before): the front-view measures (frontDead,
/// frontGain, handDead, handReach), squat detection by knee/hip ratio and leg drop,
/// and the sumo / romanian limits.
class DeadliftEngine extends ExerciseEngine {
  DeadliftEngine(super.ctx);

  // python: 10 frames at 15 fps; a real lift rarely pauses 0.67 s
  static const deadHoldSeconds = 0.25;

  bool squatLike = false; // knees bent to squat depth during this rep
  double minKnee = 999; // smallest knee angle seen during the current rep
  bool deadFront = false; // filmed facing the camera (frozen during a rep)
  double dbgFrontTorso = double.nan, dbgFrontHands = double.nan, legDropDbg = 0;
  double kneeFlexDbg = 0, hipFlexDbg = 0; // squat-check numbers

  bool get _rdl => active.variant == 'romanian';
  bool get _sumo => active.variant == 'sumo';

  /// python: shoulders, hips, knees and ankles must ALL be visible
  @override
  List<int>? get fullBodyLandmarks => const [11, 12, 23, 24, 25, 26, 27, 28];

  /// python: hidden > 1 s cancels the rep
  @override
  double get lostGrace => 1.0;

  @override
  String? get lostMessage => 'Show your full body';

  /// decide side view / front view only while idle (never mid-rep)
  @override
  void beforeAngles() {
    if (ctx.idle) deadFront = ctx.geo.frontal() == true;
  }

  /// Facing the camera the hip angle hardly changes in 2D, so use how much the torso
  /// got shorter vertically compared with standing: lean = acos(vert/standing).
  /// Returned as an equivalent hip angle (180 = upright) so the same up/down limits work.
  ///
  /// Two measures, the one showing MORE hinge wins:
  /// 1) torso: how much shorter shoulders-to-hips got. At a very deep hinge the shoulders
  ///    reach hip height or go below it, which counts as the deepest hinge.
  /// 2) hands: how far the wrists went down compared with standing, as a fraction of the leg
  ///    length. Facing the camera this is far more reliable than the torso length.
  /// Side on, the hip angle shows more hinge; facing the camera, these do. No view guessing needed.
  @override
  double? frontAngle() {
    final g = ctx.geo, base = ctx.baseline, idle = ctx.idle;
    final sh = g.mid(11, 12), hp = g.mid(23, 24);
    if (sh == null || hp == null) return null;
    const dead = 10.0, gain = 1.5;
    // dead zone (relaxed standing is never exactly upright) and gain (the camera
    // under-reads a forward lean): standing = 180, a real hinge reaches the limit
    double? torso;
    final vert = hp.dy - sh.dy; // shoulders are above the hips
    if (vert >= 1) {
      final stand = base.stand('frontVert', vert, idle);
      final lean = math.acos((vert / stand).clamp(0.0, 1.0).toDouble()) * 180 / math.pi;
      torso = 180 - math.max(0.0, lean - dead) * gain;
    } else if (base['frontVert'] != null) {
      // shoulders level with / below the hips: the torso points at the lens = deepest hinge
      torso = 180 - math.max(0.0, 90 - dead) * gain;
    }
    double? hands;
    final an = g.mid(27, 28), wr = g.mid(15, 16);
    if (an != null && wr != null) {
      final ext = an.dy - hp.dy;
      if (ext > 1) {
        final leg = base.stand('legExt', ext, idle);
        final drop = (wr.dy - hp.dy) / leg;
        final h0 = base.low('handDrop0', drop, idle); // hands hanging, standing
        const dz = 0.12, reach = 0.40;
        final p = ((drop - h0 - dz) / math.max(reach - dz, 0.05)).clamp(0.0, 1.0).toDouble();
        hands = 180 - 80 * p; // same scale as the hip angle: 100 = bottom
      }
    }
    dbgFrontTorso = torso ?? double.nan;
    dbgFrontHands = hands ?? double.nan;
    if (torso == null) return hands;
    if (hands == null) return torso;
    return math.min(torso, hands);
  }

  @override
  bool get asymmetryAllowed => !deadFront;

  /// knees never bend to squat depth (python squat_like), checked during the WHOLE rep
  @override
  void trackRep(double smoothed) {
    final g = ctx.geo, base = ctx.baseline, rep = ctx.rep;
    final ks = <double>[];
    for (final s in const [
      [24, 26, 28],
      [23, 25, 27]
    ]) {
      final a = g.p(s[0]), b = g.p(s[1]), c = g.p(s[2]);
      if (a == null || b == null || c == null) continue;
      final v = PoseGeometry.ang(a, b, c);
      if (v.isFinite) ks.add(v);
    }
    if (deadFront) {
      // facing the camera knee angles are useless (the knees bend toward the lens),
      // so a squat is detected by the hips dropping: hip-to-ankle height shrinks
      final an = g.mid(27, 28), hpm = g.mid(23, 24);
      if (an != null && hpm != null) {
        final ext = an.dy - hpm.dy;
        if (ext > 1) {
          final stand = base.stand('legExt', ext, rep.idle);
          final legDrop = _rdl ? 0.25 : (_sumo ? 0.50 : 0.38);
          legDropDbg = 1 - ext / stand;
          if (rep.attempt && legDropDbg > legDrop) squatLike = true;
        }
      }
    } else if (ks.isNotEmpty) {
      final knee = ks.reduce(math.max); // python: max of both knees
      // the lifter's own standing angles (follow while idle, frozen in a rep)
      final idleNow = rep.idle;
      final kneeStand = base.stand('kneeStand', knee, idleNow);
      final hipStand = base.stand('hipStand', smoothed, idleNow);
      if (rep.attempt) {
        minKnee = math.min(minKnee, knee);
        final kneeFlex = kneeStand - minKnee; // how much the knees bent
        final hipFlex = math.max(hipStand - rep.minAngle, 1.0); // how much the hips hinged
        kneeFlexDbg = kneeFlex;
        hipFlexDbg = hipFlex;
        // a deadlift is mostly HIP hinge (knees bend little); a squat is mostly KNEE
        // bend. So compare them instead of using one fixed knee angle.
        final ratio = _rdl ? 0.9 : (_sumo ? 1.8 : 1.2);
        if ((kneeFlex >= 45 && kneeFlex > ratio * hipFlex) || minKnee < _squatKnee) squatLike = true;
      }
    }
  }

  /// knee angle below this during the rep = it was a squat (repThresholds.squatInsteadOfDeadliftKneeAngleDeg)
  double get _squatKnee {
    if (_rdl) return 100;
    if (_sumo) return 55;
    return ctx.rules.band.squatInsteadOfDeadliftKneeAngleDeg ??
        ctx.rules.reject('squat_instead_of_deadlift') ??
        75;
  }

  @override
  FormEvaluation evaluate(double per, bool? front) {
    final ev = FormEvaluation();
    final g = ctx.geo, rules = ctx.rules, idle = ctx.idle;
    final low = per >= 60; // lower part of the lift
    // spine proxy: ear-shoulder-hip compared with the lifter's own upright posture.
    // It cannot see the lumbar spine, so it only warns and never rejects a rep.
    var spineSeen = deadFront; // facing the camera: spine angle cannot be seen
    for (final s in deadFront
        ? const <List<int>>[]
        : const [
            [8, 12, 24],
            [7, 11, 23]
          ]) {
      if (!g.vis(s)) continue;
      final a = g.p(s[0]), b = g.p(s[1]), c = g.p(s[2]);
      if (a == null || b == null || c == null) continue;
      final ang = PoseGeometry.ang(a, b, c);
      if (!ang.isFinite) continue;
      ev.limit((ctx.baseline.follow('neck', ang, idle) - ang) - rules.warn('spine_neutral', 25), 15,
          'Keep spine neutral');
      spineSeen = true;
      break;
    }
    if (deadFront) {
      ev.note = 'Facing camera: back not checked (film from the side)';
    } else if (!spineSeen) {
      ev.note = 'Head/back not visible';
    }
    // knee bend at the bottom depends on the variation
    final kLo = _rdl ? 135.0 : (_sumo ? 70.0 : rules.warn('knee_bend_too_much_conventional', 85));
    final kHi = _rdl ? 178.0 : (_sumo ? 140.0 : rules.warn('knees_too_straight_conventional', 150));
    final ks = <double>[];
    for (final s in const [
      [24, 26, 28],
      [23, 25, 27]
    ]) {
      if (!g.vis(s)) continue;
      final a = g.p(s[0]), b = g.p(s[1]), c = g.p(s[2]);
      if (a == null || b == null || c == null) continue;
      final ang = PoseGeometry.ang(a, b, c);
      if (ang.isFinite) ks.add(ang);
    }
    if (ks.isNotEmpty && !deadFront) {
      final knee = ks.reduce((a, b) => a + b) / ks.length;
      ev.limit(low ? kLo - knee : -1, 25, 'Too much knee bend');
      ev.limit(low ? knee - kHi : -1, 25, 'Knees too straight');
    }
    // conventional stance is about hip width (narrower than the shoulders), so 0.4 not 0.6.
    // Knee cave is a squat fault: here it only warns and with a looser limit (toe-out feet
    // made it fire on normal reps and paint the bar red).
    if (front == true) {
      frontLegChecks(ev, g, per,
          stanceMin: _sumo ? 1.4 : rules.warnMin('stance_width_conventional', 0.4),
          stanceMax: _sumo ? 3.0 : rules.warnMax('stance_width_conventional', 1.6),
          caveLimit: rules.warn('knee_cave', 0.30),
          caveBlocks: rules.rejects('knee_cave', false),
          caveBlockAt: rules.rejectMargin('knee_cave'));
    }
    ev.assessable = ev.scores.isNotEmpty;
    return ev;
  }

  @override
  void onRepStart() {
    squatLike = false;
    minKnee = 999;
  }

  /// facing the camera the hinge is under-read, so the bottom is a little earlier
  /// (repThresholds.bottomReachedBarPct)
  @override
  double get bottomPercent {
    final reach = ctx.rules.band.bottomReachedBarPct;
    return deadFront ? (reach?.front ?? 85) : (reach?.side ?? 100);
  }

  /// side: 10 frames like python; front: short (a touch-and-go lift never paused 0.25 s)
  @override
  double get holdSeconds => deadFront ? 0.10 : deadHoldSeconds;

  /// knees bent to squat depth = it was a squat, do not count
  @override
  RepOutcome? rejectRep() => squatLike
      ? const RepOutcome('Squat - not a deadlift', FormLevel.bad, detail: 'Hinge at the hips', counted: false)
      : null;

  /// only the squat check decides; form faults warn
  @override
  bool get softFaults => true;

  @override
  RepOutcome incompleteRep() =>
      const RepOutcome('Incomplete rep', FormLevel.warn, detail: 'Hinge fully, then lock out', counted: false);

  @override
  void addDebug(List<String> dbg, FrameDebug d) {
    String n(double? v) => (v == null || !v.isFinite) ? '-' : v.round().toString();
    dbg.add('side ${n(d.sideRaw)}  front ${n(d.frontRaw)}  (lower one is used)');
    dbg.add('knee flex ${kneeFlexDbg.round()}  hip flex ${hipFlexDbg.round()}  '
        'squat ${squatLike ? 'YES' : 'no'}');
    dbg.add('view ${deadFront ? 'FRONT' : 'side'}  torso ${n(dbgFrontTorso)}  hands ${n(dbgFrontHands)}  '
        'bottom at per ${d.reachPer.round()}  leg drop ${legDropDbg.toStringAsFixed(2)}');
  }

  @override
  void resetTracking() {
    squatLike = false;
    minKnee = 999;
  }
}
