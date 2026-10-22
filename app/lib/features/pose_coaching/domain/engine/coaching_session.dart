import 'dart:math' as math;

import 'package:ai_trainer/core/utils/cv_math.dart';
import 'package:ai_trainer/features/pose_coaching/domain/engine/angle_filter.dart';
import 'package:ai_trainer/features/pose_coaching/domain/engine/coaching_context.dart';
import 'package:ai_trainer/features/pose_coaching/domain/engine/exercises/bench_engine.dart';
import 'package:ai_trainer/features/pose_coaching/domain/engine/exercises/curl_engine.dart';
import 'package:ai_trainer/features/pose_coaching/domain/engine/exercises/exercise_engine.dart';
import 'package:ai_trainer/features/pose_coaching/domain/engine/exercises/exercise_engine_factory.dart';
import 'package:ai_trainer/features/pose_coaching/domain/engine/exercises/squat_engine.dart';
import 'package:ai_trainer/features/pose_coaching/domain/engine/form_evaluation.dart';
import 'package:ai_trainer/features/pose_coaching/domain/engine/form_scorer.dart';
import 'package:ai_trainer/features/pose_coaching/domain/engine/pose_geometry.dart';
import 'package:ai_trainer/features/pose_coaching/domain/engine/rule_book.dart';
import 'package:ai_trainer/features/pose_coaching/domain/engine/set_tracker.dart';
import 'package:ai_trainer/features/pose_coaching/domain/engine/tracking_config.dart';
import 'package:ai_trainer/features/pose_coaching/domain/engine/warning_tracker.dart';
import 'package:ai_trainer/features/pose_coaching/domain/entities/coaching_feedback.dart';
import 'package:ai_trainer/features/pose_coaching/domain/entities/exercise_rule_set.dart';
import 'package:ai_trainer/features/pose_coaching/domain/entities/form_level.dart';
import 'package:ai_trainer/features/pose_coaching/domain/entities/joint_angle.dart';
import 'package:ai_trainer/features/pose_coaching/domain/entities/pose_frame.dart';
import 'package:ai_trainer/features/pose_coaching/domain/entities/posture_assessment.dart';

/// One workout of one exercise: the rep loop of the python trainers, the same for
/// every exercise. What differs per exercise is asked from the [ExerciseEngine];
/// all thresholds come from the database ([ExerciseRuleSet]). Pure Dart (no Flutter,
/// no ML Kit). Created by StartCoachingSessionUseCase, driven by the use cases.
class CoachingSession {
  CoachingSession._(this.ruleSet, this.ctx) : engine = createExerciseEngine(ctx);

  /// null = the camera cannot track this exercise (no repThresholds / no engine)
  static CoachingSession? create(ExerciseRuleSet ruleSet) {
    final config = TrackingConfig.fromRuleSet(ruleSet);
    if (config == null) return null;
    return CoachingSession._(ruleSet, CoachingContext(config: config, rules: RuleBook(ruleSet)));
  }

  final ExerciseRuleSet ruleSet;
  final CoachingContext ctx;
  final ExerciseEngine engine;
  final warnings = WarningTracker();
  final scorer = FormScorer();
  final sets = SetTracker();

  // timing (seconds)
  static const minRepSeconds = 0.6; // a real rep is never faster than this
  static const maxRepSeconds = 20.0; // stale half-rep: forget it
  static const attemptPer = 30.0; // % reached before a return counts as "incomplete"
  // rep smoothness score calibration (not in the database yet)
  static const smoothBase = 1.5, smoothSpan = 2.0;

  // what the last frame showed (drawn on the camera picture)
  PoseFrame _pose = PoseFrame.empty(DateTime.fromMillisecondsSinceEpoch(0));
  bool _tracking = false;
  final _jointAngles = <JointAngle>[];
  final _debugLines = <String>[];

  // ===================== one camera frame =====================

  /// count reps, check form, update the score. [t] = time.time()
  void update(PoseFrame pose, double t) {
    _pose = pose;
    final g = ctx.geo = PoseGeometry(pose);
    final rep = ctx.rep, filter = ctx.filter;
    final e = engine.active;
    _jointAngles.clear();
    _debugLines.clear();
    final dbg = _debugLines;

    // Every exercise checks that its joints are really seen (the deadlift: the full
    // body), and a short dropout (lostGrace) is ridden out instead of resetting the rep.
    final full = engine.fullBodyLandmarks;
    final fullBody = full == null || (pose.hasPerson && g.vis(full));
    final rightOk = pose.hasPerson && fullBody && g.vis(e.right);
    final leftOk = pose.hasPerson && fullBody && e.left != null && g.vis(e.left!);
    ctx.gateMsg = null;
    _tracking = rightOk || leftOk;
    if (!_tracking) {
      rep.bottomSince = null; // python: hold = 0 when joints are hidden
      rep.curPer = 0;
      if (t - rep.lastSeenTime > engine.lostGrace) resetTracking();
      // set after the reset, because resetTracking clears gateMsg
      ctx.gateMsg = engine.lostMessage;
      dbg.add('joints not seen: R $rightOk L $leftOk lm ${pose.landmarks.length}');
      return;
    }
    rep.lastSeenTime = t;

    engine.beforeAngles();
    var aR = rightOk ? AngleFilter.fold(_findAngle(g, e.right)) : 0.0;
    var aL = leftOk ? AngleFilter.fold(_findAngle(g, e.left!)) : 0.0;
    if (rightOk) aR = engine.adjustAngle(e.right, aR);
    if (leftOk) aL = engine.adjustAngle(e.left!, aL);
    // both sides must bend: use the straighter one, so moving one side can't count a rep
    final sideRaw = !aR.isFinite ? aL : (!aL.isFinite ? aR : math.max(aR, aL));
    // a second measure (deadlift facing the camera): the one showing MORE depth is used
    final frontRaw = engine.frontAngle();
    final raw = (frontRaw != null && sideRaw.isFinite) ? math.min(sideRaw, frontRaw) : (frontRaw ?? sideRaw);
    final angle = filter.clean(raw, e.upAngle);
    final asym = (engine.asymmetryAllowed && rightOk && leftOk && aR.isFinite && aL.isFinite)
        ? (aR - aL).abs()
        : null;
    final smoothed = filter.smooth(angle, t, perFrame: e.perFrameSmoothing);
    final per = interp(smoothed, e.downAngle, e.upAngle, 100, 0).clamp(0.0, 100.0).toDouble();
    rep.curPer = per;
    filter.updateSpeed(smoothed, t);

    final gateOk = engine.gate(t);
    engine.trackRep(smoothed);

    // form checks for this frame
    final ev = _evaluate(per, g.frontal(), asym);
    warnings.update(ev, t);

    // rep state machine (the bloc stops sending frames while the rest timer runs)
    if (!rep.attempt && per > 15 && gateOk && !rep.needRest) {
      rep.start(t, smoothed); // left the top
      engine.onRepStart();
    }
    if (rep.attempt) {
      rep.peakPer = math.max(rep.peakPer, per);
      rep.minAngle = math.min(rep.minAngle, smoothed);
      for (final m in warnings.shown) {
        if (warnings.severeNow(m, t)) rep.repFaults.add(m); // only faults that lasted count
      }
      final speed = filter.speed;
      if (rep.repSpeedInit) rep.repSpeedVar += (speed - rep.lastRepSpeed).abs();
      rep.repSpeedInit = true;
      rep.lastRepSpeed = speed;
      rep.repSpeedPeak = math.max(rep.repSpeedPeak, speed);
      if (scorer.formReady) {
        rep.repFormSum += scorer.formScore;
        rep.repFormN++;
      }
      if (t - rep.repStartTime > maxRepSeconds) {
        rep.attempt = false;
        rep.dir = 0;
      }
    }
    // down: must reach the bottom and stay there
    final reachPer = engine.bottomPercent;
    if (per >= reachPer && gateOk) {
      rep.bottomSince ??= t;
      if (rep.dir == 0 && rep.attempt && t - rep.bottomSince! >= engine.holdSeconds) {
        rep.dir = 1;
      }
    } else {
      rep.bottomSince = null;
    }
    // up: must come back to 0%, and at least 1 second since the last rep
    if (per <= 0) {
      rep.needRest = false; // (alternate curl: _finishRep below may set it again for the next arm)
      if (rep.dir == 1) {
        _finishRep(e, t);
      } else if (rep.attempt && rep.peakPer >= attemptPer) {
        _incompleteRep(e, t); // went part way down and came back
      }
      rep.dir = 0;
      rep.attempt = false;
      rep.bottomSince = null;
    }
    scorer.update(ev, t,
        speed: filter.speed,
        maxSpeed: engine.maxSpeed,
        lastRom: rep.lastRom,
        lastConsistency: rep.lastConsistency);

    dbg.add('angle ${smoothed.round()}  need ${e.downAngle.round()}..${e.upAngle.round()}  '
        'min ${rep.minAngle == 999 ? '-' : rep.minAngle.round()}');
    dbg.add('per ${per.round()}  dir ${rep.dir}  attempt ${rep.attempt ? 1 : 0}  hold ${rep.bottomSince == null ? 0 : 1}');
    engine.addDebug(
        dbg,
        FrameDebug(
            sideRaw: sideRaw, frontRaw: frontRaw, reachPer: reachPer, gateOk: gateOk, rightOk: rightOk, leftOk: leftOk));
  }

  double _findAngle(PoseGeometry g, List<int> joints) {
    final angle = g.findAngle(joints);
    _jointAngles.add(JointAngle(joints: joints, angle: angle));
    return angle;
  }

  FormEvaluation _evaluate(double per, bool? front, double? asym) {
    final ev = engine.evaluate(per, front);
    // one side doing more work than the other (needs both sides and a frontal view)
    if (ev.assessable && asym != null && front == true) {
      ev.limit(per >= 40 ? asym - ctx.rules.warn('asymmetry', 25) : -1, 20, 'Uneven sides');
    }
    if (ctx.filter.speed > engine.tooFastSpeed) ev.warns.add('Slow down - control it');
    return ev;
  }

  void _finishRep(TrackingConfig e, double t) {
    final rep = ctx.rep;
    final dur = t - rep.repStartTime;
    if (dur < minRepSeconds || t - rep.lastRepTime <= 1) return; // jitter (same 1 s rule as before)
    final rejected = engine.rejectRep();
    if (rejected != null) {
      rep.showResult(rejected.label, rejected.level, rejected.detail ?? '', t);
      return;
    }
    rep.lastRepTime = t;
    final faults = rep.repFaults.toList();
    final outcome = engine.classifyRep(faults);
    rep.showResult(
        outcome.label,
        outcome.level,
        faults.isNotEmpty ? faults.first : (outcome.label == 'Partial' ? 'Go deeper for full depth' : ''),
        t);
    if (outcome.counted) sets.count += 1;
    // range of motion of this rep
    final target = engine.romTargetAngle;
    rep.lastRom = ((e.upAngle - rep.minAngle) / (e.upAngle - target)).clamp(0.0, 1.0).toDouble();
    // consistency: how close this rep's duration is to the recent ones
    rep.repDurations.add(dur);
    if (rep.repDurations.length > 6) rep.repDurations.removeAt(0);
    if (rep.repDurations.length >= 3) {
      final prev = rep.repDurations.sublist(0, rep.repDurations.length - 1);
      final mean = prev.reduce((a, b) => a + b) / prev.length;
      rep.lastConsistency = (1 - ((dur - mean).abs() / mean - 0.35) / 0.65).clamp(0.0, 1.0).toDouble();
    }
    // smoothness of this rep: how much the speed jumped up and down. A clean rep is
    // one speed hill going down and one coming up (total change about 4 x peak speed).
    // Jerky reps change speed more often.
    if (rep.repSpeedPeak > 1) {
      final ratio = rep.repSpeedVar / (4 * rep.repSpeedPeak);
      rep.dbgSmoothRatio = ratio;
      rep.lastSmooth = (100 * (1 - (ratio - smoothBase) / smoothSpan)).clamp(0.0, 100.0).toDouble();
    }
    // set, fatigue, per-exercise counters (squat depths, curl arms and the alternate swap)
    if (outcome.counted) {
      sets.addRep(t, dur,
          rom: rep.lastRom ?? 1.0, form: rep.repFormN > 0 ? rep.repFormSum / rep.repFormN : scorer.formScore);
      engine.onCounted(outcome);
    }
  }

  void _incompleteRep(TrackingConfig e, double t) {
    final rep = ctx.rep;
    final outcome = engine.incompleteRep();
    rep.showResult(outcome.label, outcome.level, outcome.detail ?? '', t);
    rep.lastRom = ((e.upAngle - rep.minAngle) / (e.upAngle - e.downAngle)).clamp(0.0, 1.0).toDouble();
  }

  // ===================== commands =====================

  /// the person left or is hidden for a while: forget the half-finished rep
  /// (before, a rep started, the person walked out, came back and it was counted)
  void resetTracking() {
    ctx.rep.reset();
    ctx.filter.resetHistory();
    ctx.baseline.clear();
    warnings.clear();
    scorer.formReady = false;
    engine.resetTracking();
    ctx.gateMsg = null;
  }

  /// counting, sets and fatigue start again from the beginning
  void resetSession() {
    sets.reset();
    ctx.rep.lastRepTime = 0;
    ctx.rep.needRest = false;
    ctx.rep.lastSmooth = null;
    engine.resetSession();
  }

  /// biceps curl arm choice. Returns false when nothing changed.
  bool setArmMode(int mode) {
    final curl = engine;
    if (curl is! CurlEngine || !curl.setArmMode(mode)) return false;
    resetTracking(); // a half-finished rep of the other arm must not count
    resetSession(); // counting starts again from 0
    ctx.rep.repLabel = '';
    return true;
  }

  /// bench press: the bed button
  void toggleLyingCheck() {
    final bench = engine;
    if (bench is BenchEngine) bench.toggleLyingCheck();
  }

  /// +1 / -1 buttons: fix a rep the camera missed or added
  void adjustRep(int d, double t) {
    if (sets.adjust(d, t)) engine.onRepAdjusted(d);
  }

  /// Finish set: the set ends and the rest screen opens
  void endSet() {
    sets.endSet();
    ctx.rep.dir = 0;
    ctx.rep.attempt = false;
    ctx.rep.bottomSince = null;
  }

  /// Stop timer: back to the camera, still in the SAME set (the rest time is not counted in it)
  void resumeSet(double restedSeconds) {
    sets.resumeSet(restedSeconds);
    resetTracking(); // fresh start posture, no half-finished rep
  }

  void nextSet() => sets.nextSet();

  // ===================== what the screen shows =====================

  /// what the feedback card says right now (most important first)
  CoachingFeedback _feedback(double t) {
    final rep = ctx.rep;
    final g = ctx.gateMsg;
    if (g != null) {
      final sub = g == 'Show your full body'
          ? 'Step back until head to feet are in view'
          : (g == 'Show shoulder, elbow, wrist' ? 'Keep your arm in view of the camera' : null);
      return CoachingFeedback(FeedbackIcon.warning, FeedbackTone.alert, g, sub);
    }
    if (rep.repLabel.isNotEmpty && t - rep.repLabelTime < 4) {
      final ic = rep.repLevel == FormLevel.good
          ? FeedbackIcon.check
          : (rep.repLevel == FormLevel.warn ? FeedbackIcon.error : FeedbackIcon.cancel);
      final tone = switch (rep.repLevel) {
        FormLevel.good => FeedbackTone.good,
        FormLevel.warn => FeedbackTone.warn,
        _ => FeedbackTone.bad,
      };
      return CoachingFeedback(ic, tone, rep.repLabel, rep.repDetail.isEmpty ? null : rep.repDetail);
    }
    if (warnings.shown.isNotEmpty) {
      final m = warnings.shown.first;
      return CoachingFeedback(FeedbackIcon.warning, warnings.severeNow(m, t) ? FeedbackTone.bad : FeedbackTone.warn,
          m, warnings.shown.length > 1 ? warnings.shown[1] : null);
    }
    final n = warnings.note;
    if (scorer.formReady && n != null) return CoachingFeedback(FeedbackIcon.info, FeedbackTone.muted, n);
    if (scorer.formReady) {
      return scorer.formState == 0
          ? const CoachingFeedback(FeedbackIcon.check, FeedbackTone.good, 'Form looks good', 'Keep going')
          : const CoachingFeedback(FeedbackIcon.error, FeedbackTone.warn, 'Check your form');
    }
    return CoachingFeedback(FeedbackIcon.person, FeedbackTone.muted,
        sets.inSet ? 'Form not assessable' : 'Start lifting',
        sets.inSet ? 'Show more of your body' : 'Reps are counted automatically');
  }

  /// everything the trainer screen shows, at time [t]
  PostureAssessment assessment(double t) {
    final e = engine.active;
    final eng = engine;
    return PostureAssessment(
      exerciseId: ruleSet.exerciseId,
      exerciseName: ruleSet.nameEn,
      kind: ctx.config.kind,
      oneSide: ctx.config.oneSide,
      pose: _pose,
      isTracking: _tracking,
      percent: ctx.rep.curPer,
      reps: sets.count.toInt(),
      jointAngles: List.unmodifiable(_jointAngles),
      debugLines: List.unmodifiable(_debugLines),
      depthTickPercents: [
        for (final a in engine.depthTickAngles)
          interp(a, e.downAngle, e.upAngle, 100, 0).clamp(0.0, 100.0).toDouble(),
      ],
      formLevel: scorer.level(warnings, t),
      formReady: scorer.formReady,
      formScore: scorer.formScore,
      formWord: scorer.word(warnings),
      feedback: _feedback(t),
      sets: SetProgress(
        inSet: sets.inSet,
        setNumber: sets.setNumber,
        setReps: sets.setReps,
        setStartTime: sets.setStart,
        lastSetReps: sets.lastSetReps,
        lastSetSeconds: sets.lastSetSecs,
        formAverage: sets.formAverage,
        fatigue: sets.fatigue,
        smoothness: ctx.rep.lastSmooth,
      ),
      squatDepths: eng is SquatEngine ? eng.depthCounts : null,
      arms: eng is CurlEngine ? eng.armStatus : null,
      lyingCheck: eng is BenchEngine ? eng.lyingCheck : null,
    );
  }
}
