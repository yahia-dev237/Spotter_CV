import 'dart:math' as math;

import 'package:ai_trainer/features/pose_coaching/domain/engine/exercises/exercise_engine.dart';
import 'package:ai_trainer/features/pose_coaching/domain/engine/form_evaluation.dart';
import 'package:ai_trainer/features/pose_coaching/domain/engine/pose_geometry.dart';
import 'package:ai_trainer/features/pose_coaching/domain/entities/form_level.dart';
import 'package:ai_trainer/features/pose_coaching/domain/entities/vec2.dart';

/// BenchPressTrainer.py: both arms; reps only count while lying on the bench
class BenchEngine extends ExerciseEngine {
  BenchEngine(super.ctx);

  static const lyingSeconds = 0.3;

  double? lyingSince;
  double? notLyingSince;
  bool lyingCheck = true; // false = never block the bench press (bed icon in the app bar)
  double dbgTilt = 0, dbgRatio = -1; // lying-gate numbers, shown when it blocks
  String dbgSrc = '-'; // which landmarks the lying check used
  bool _gateOk = true;

  @override
  String? get lostMessage => 'Show shoulder, elbow, wrist';

  /// bed button: the lying check on / off
  void toggleLyingCheck() {
    lyingCheck = !lyingCheck;
    lyingSince = null;
    notLyingSince = null;
  }

  /// true = torso is horizontal (lying on a bench), false = clearly upright, null = unknown.
  /// "false" is only returned when the hips are really seen AND the torso is vertical AND
  /// not foreshortened. When the hips are hidden (very common lying down) the answer is
  /// "unknown" and the bench press is NOT blocked, because a vertical head-shoulder line
  /// also looks vertical from the head/foot end of the bench.
  bool? _lying() {
    final g = ctx.geo;
    final tiltLim = ctx.rules.warn('lying_down_torso_tilt', 35);
    final ratioLim = ctx.rules.warn('lying_down_torso_ratio', 0.9);
    final sh = <Vec2>[], hp = <Vec2>[];
    for (final s in const [
      [11, 23],
      [12, 24]
    ]) {
      if (!g.vis(s)) continue;
      final a = g.p(s[0]), b = g.p(s[1]);
      if (a != null && b != null) {
        sh.add(a);
        hp.add(b);
      }
    }
    if (sh.isNotEmpty) {
      final s = sh.length == 2 ? (sh[0] + sh[1]) / 2 : sh[0];
      final h = hp.length == 2 ? (hp[0] + hp[1]) / 2 : hp[0];
      final tl = (s - h).distance;
      if (tl >= 1) {
        dbgSrc = 'hips';
        dbgTilt = PoseGeometry.fromVertical(h, s);
        dbgRatio = -1;
        if (dbgTilt >= tiltLim) return true; // side view: torso horizontal
        if (sh.length == 2) {
          // head/foot end: the torso is foreshortened compared with the shoulder width
          dbgRatio = tl / math.max((sh[0] - sh[1]).distance, 1.0);
          if (dbgRatio < ratioLim) return true;
        }
        return false; // hips seen, torso vertical and full length = really upright
      }
    }
    // hips hidden: the head line can PROVE lying (horizontal), but a vertical head line
    // proves nothing -> unknown, don't block
    for (final s in const [
      [7, 11],
      [8, 12],
      [0, 11],
      [0, 12]
    ]) {
      if (!g.vis(s)) continue;
      final head = g.p(s[0]), shoulder = g.p(s[1]);
      if (head == null || shoulder == null || (head - shoulder).distance < 1) continue;
      dbgSrc = 'head';
      dbgRatio = -1;
      dbgTilt = PoseGeometry.fromVertical(shoulder, head);
      return dbgTilt >= tiltLim ? true : null;
    }
    dbgSrc = 'none';
    return null;
  }

  /// only count while lying down (blocks shoulder press / curl)
  @override
  bool gate(double t) {
    _gateOk = true;
    if (!lyingCheck) return true;
    final rep = ctx.rep;
    final ly = _lying();
    if (ly == false) {
      // clearly upright: drop the lying state only after 2 s (4 s mid-rep)
      notLyingSince ??= t;
      if (t - notLyingSince! > (rep.attempt || rep.dir != 0 ? 4.0 : 2.0)) lyingSince = null;
    } else {
      // lying, or cannot tell (null): do not block
      lyingSince ??= t;
      notLyingSince = null;
    }
    _gateOk = lyingSince != null && t - lyingSince! >= lyingSeconds;
    if (!_gateOk) ctx.gateMsg = 'Lie on the bench';
    if (!_gateOk && (rep.attempt || rep.dir != 0)) {
      // stood up / left the bench mid-rep: forget it
      rep.attempt = false;
      rep.dir = 0;
      rep.bottomSince = null;
      rep.repFaults.clear();
    }
    return _gateOk;
  }

  @override
  FormEvaluation evaluate(double per, bool? front) {
    final ev = FormEvaluation();
    final g = ctx.geo, rules = ctx.rules, rep = ctx.rep, idle = ctx.idle;
    final e = active;
    final flares = <double>[], tilts = <double>[], bends = <double>[];
    final wrists = <Vec2>[];
    var segs = 0.0;
    var sides = 0;
    for (final s in [e.right, if (e.left != null) e.left!]) {
      if (!g.vis(s)) continue;
      final sh = g.p(s[0]), el = g.p(s[1]), wr = g.p(s[2]);
      if (sh == null || el == null || wr == null) continue;
      final isRight = s[0] == 12;
      final hipId = isRight ? 24 : 23, idxId = isRight ? 20 : 19;
      final hip = g.vis([hipId]) ? g.p(hipId) : null;
      final idx = g.vis([idxId]) ? g.p(idxId) : null;
      if (hip != null) flares.add(PoseGeometry.ang(hip, sh, el)); // elbow-to-torso angle
      tilts.add(PoseGeometry.fromVertical(el, wr)); // forearm vs vertical
      if (idx != null) bends.add(PoseGeometry.ang(el, wr, idx)); // wrist straightness
      wrists.add(wr);
      segs += (sh - el).distance + (el - wr).distance;
      sides++;
    }
    if (sides == 0) return ev;
    final fl = flares.where((v) => v.isFinite).toList();
    final tl = tilts.where((v) => v.isFinite).toList();
    final bd = bends.where((v) => v.isFinite).toList();
    // elbow flare: a range, not one universal angle (bottom half only)
    // From the SIDE the elbow-to-torso angle is about 90 degrees on every normal rep,
    // so flare can only be judged from the head/foot end, and it only warns.
    if (front == true && fl.isNotEmpty) {
      ev.limit(per >= 50 ? fl.reduce(math.max) - rules.warn('elbow_flare_wide', 75) : -1, 20,
          'Elbows flared wide');
      ev.limit(per >= 50 ? rules.warn('elbow_flare_tucked', 30) - fl.reduce(math.min) : -1, 15,
          'Elbows tucked in');
    } else if (front != true) {
      ev.note = 'Flare needs head/foot view';
    } else {
      ev.note = 'Hips hidden - flare unchecked';
    }
    // forearm should be close to vertical near the chest (wrist stacked over elbow)
    if (tl.isNotEmpty) {
      ev.limit(per >= 70 ? tl.reduce(math.max) - rules.warn('forearm_not_vertical', 25) : -1, 20,
          'Stack wrist over elbow');
    }
    // wrist alignment: elbow-wrist-knuckle should be near straight
    if (bd.isNotEmpty) {
      ev.limit(per >= 30 ? rules.warn('wrist_bent_back', 145) - bd.reduce(math.min) : -1, 25, 'Wrist bent back');
    }
    // bar path (the wrists stand in for the bar): sideways drift from the start line
    final x = wrists.map((p) => p.dx).reduce((a, b) => a + b) / wrists.length;
    final seg = segs / (2 * sides);
    if (seg > 1) {
      ev.limit((x - ctx.baseline.follow('barX', x, idle)).abs() / seg - rules.warn('bar_path_drift', 0.5), 0.4,
          'Bar path drifting');
    }
    // controlled lowering: dropping the bar fast (bouncing it off the chest) is a classic
    // chest / shoulder injury. dir == 0 && attempt = on the way down, before the bottom.
    if (rep.dir == 0 && rep.attempt) {
      ev.limit(ctx.filter.speed - rules.warn('lowering_too_fast', 160), 120, 'Lower slowly - control the bar');
    }
    // glutes must stay on the bench (side view): the shoulder-hip line keeps its start angle
    if (front != true && lyingSince != null) {
      for (final s in const [
        [11, 23],
        [12, 24]
      ]) {
        if (!g.vis(s)) continue;
        final a = g.p(s[0]), b = g.p(s[1]);
        if (a == null || b == null || (a - b).distance < 1) continue;
        final tilt = PoseGeometry.fromVertical(b, a);
        ev.limit((tilt - ctx.baseline.follow('benchTilt${s[0]}', tilt, idle)).abs() - rules.warn('glutes_lift', 12),
            15, 'Keep glutes on the bench');
        break;
      }
    }
    // uneven bar (facing the camera): one wrist higher than the other
    final s1 = g.p(11), s2 = g.p(12);
    if (front == true && wrists.length == 2 && s1 != null && s2 != null) {
      final sw = (s1 - s2).distance;
      if (sw > 1) {
        ev.limit((wrists[0].dy - wrists[1].dy).abs() / sw - rules.warn('uneven_bar', 0.25), 0.25, 'Bar uneven');
      }
    }
    ev.assessable = true;
    return ev;
  }

  /// only the lying check decides; form faults warn
  @override
  bool get softFaults => true;

  @override
  RepOutcome incompleteRep() =>
      const RepOutcome('Incomplete rep', FormLevel.warn, detail: 'Lower to chest, lock out', counted: false);

  @override
  void addDebug(List<String> dbg, FrameDebug d) {
    dbg.add('lying ${d.gateOk ? 'YES' : 'no'}  src $dbgSrc  tilt ${dbgTilt.round()} '
        'need ${ctx.rules.warn('lying_down_torso_tilt', 35).round()}'
        '${dbgRatio >= 0 ? '  ratio ${dbgRatio.toStringAsFixed(1)}' : ''}');
    dbg.add('R arm ${d.rightOk}  L arm ${d.leftOk}');
  }

  @override
  void resetTracking() {
    lyingSince = null;
    notLyingSince = null;
  }
}
