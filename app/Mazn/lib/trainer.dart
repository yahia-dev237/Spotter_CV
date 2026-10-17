import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'camera_view.dart';
import 'cv.dart';
import 'pose_module.dart';

// Form-bar colours. If the colours in cv.dart (green, blue, magenta) are not
// Flutter `Color`s, change these four constants to your cv.dart colour type.
const formGood = Color(0xFF50C878); // emerald: form correct
const formWarn = Color(0xFFFFB300); // amber: needs correction
const formBad = Color(0xFFE53935); // red: clear fault
const formNA = Color(0xFF9E9E9E); // grey: cannot be assessed

/// shows live numbers (angle, %, gate state...) on the camera picture while testing.
/// Set to false when everything works.
const debugHud = true;

/// the settings that are different between AiTrainer.py, SquatTrainer.py,
/// DeadliftTrainer.py and BenchPressTrainer.py
///
/// [limits] overrides any form threshold by key (all optional, defaults live
/// where each key is read). Keys: elbowDrift 25, swing 12, shrug 0.12, twist 0.2,
/// torsoLean 60, deepAngle 95, kneeCave 0.15, stanceMin 0.6, stanceMax 2.0,
/// kneeMin, kneeMax, spineDrift 25, flareMax 85, flareMin 25, forearmTilt 25,
/// wristMin 145, barTilt 0.25, asym 25, frontalRatio 0.5, maxSpeed, countFaulty 0,
/// squatRatio (deadlift, side view: knee bend / hip hinge above this = squat,
/// default 1.2, sumo 1.8, romanian 0.9), squatKnee (deadlift: knee angle below
/// this = squat, default 75, sumo 55, romanian 100), squatLegDrop
/// (deadlift facing the camera: hip-to-ankle height lost, default 0.38, sumo 0.50,
/// romanian 0.25), frontDead 10 and frontGain 1.5 (deadlift facing the camera),
/// swingReject 20 and elbowDriftReject 30 (curl: degrees PAST the warning limit
/// before a rep is rejected), lyingTilt 40 and lyingRatio 0.6 (bench: how
/// horizontal the torso must be). Defaults are commonly cited coaching/biomechanics ranges, not
/// clinical limits: tune them to your users. Pose estimation is 2D and
/// approximate; it can help you notice form problems but it cannot guarantee
/// injury prevention.
class Exercise {
  const Exercise({
    required this.name,
    required this.right,
    this.left,
    required this.downAngle,
    required this.upAngle,
    this.perFrameSmoothing = false,
    this.variant = '',
    this.limits = const {},
  });

  final String name;
  final List<int> right; // the 3 landmark ids of the right side
  final List<int>? left; // null = only the right side (AiTrainer.py)
  final double downAngle; // angle at 100%
  final double upAngle; // angle at 0%
  // true = exactly like the python file: "0.7*old + 0.3*new" every frame
  // (felt better for the squat on the phone than the timed version)
  final bool perFrameSmoothing;
  // deadlift variation: '' / 'conventional', 'sumo' or 'romanian'
  final String variant;
  // threshold overrides (see above)
  final Map<String, double> limits;

  /// AiTrainer.py is the first version: one arm
  bool get oneSide => left == null;
}

const exercises = [
  // Right Arm (shoulder=12, elbow=14, wrist=16)
  // elbow >=160 (extended) -> <=45 (flexed)
  Exercise(name: 'Biceps Curl', right: [12, 14, 16], downAngle: 45, upAngle: 160,
      limits: {'maxSpeed': 400}),
  // Right Leg (hip=24, knee=26, ankle=28), Left Leg (hip=23, knee=25, ankle=27)
  // knee >=165 (standing) = 0% , <=95 (deep) = 100%
  Exercise(name: 'Squat', right: [24, 26, 28], left: [23, 25, 27], downAngle: 95, upAngle: 165,
      perFrameSmoothing: true),
  // Right Hip (shoulder=12, hip=24, knee=26), Left Hip (shoulder=11, hip=23, knee=25)
  // hip >=165 (standing tall) = 0% , <=100 (full hinge) = 100%
  Exercise(name: 'Deadlift', right: [12, 24, 26], left: [11, 23, 25], downAngle: 100, upAngle: 165),
  // Right Arm (shoulder=12, elbow=14, wrist=16), Left Arm (shoulder=11, elbow=13, wrist=15)
  // arms extended 145 = 0% , bar near the chest 92 = 100%
  Exercise(name: 'Bench Press', right: [12, 14, 16], left: [11, 13, 15], downAngle: 92, upAngle: 145),
];

// Deadlift variations (not in the menu list; add them to `exercises` if wanted).
// Starting values: sumo has a more upright torso, the Romanian deadlift needs a
// deeper hinge with nearly straight knees.
const deadliftSumo = Exercise(
    name: 'Sumo Deadlift', variant: 'sumo', right: [12, 24, 26], left: [11, 23, 25],
    downAngle: 145, upAngle: 158);
const deadliftRomanian = Exercise(
    name: 'Romanian Deadlift', variant: 'romanian', right: [12, 24, 26], left: [11, 23, 25],
    downAngle: 130, upAngle: 158);

/// result of the form checks for one frame
class _Eval {
  final scores = <double>[]; // one 0..1 score per alignment check
  final warns = <String>[]; // messages for checks that are out of tolerance
  final blocking = <String>[]; // clear faults: these reject the rep
  bool assessable = false; // false = not enough landmarks to judge form
  String? note; // small grey hint ("flare unchecked")

  /// [over] > 0 means outside tolerance; the score reaches 0 at [over] == [soft].
  /// A fault only blocks the rep when it is clearly outside tolerance (score < 0.5).
  void limit(double over, double soft, String msg, {bool block = false, double? blockAt}) {
    if (!over.isFinite) return;
    final s = over <= 0 ? 1.0 : (1 - over / soft).clamp(0.0, 1.0).toDouble();
    scores.add(s);
    if (over > 0) {
      warns.add(msg);
      // blockAt: reject the rep only when [over] reaches this (warn earlier, reject later)
      if (block && (blockAt != null ? over >= blockAt : s < 0.5)) blocking.add(msg);
    }
  }
}

class TrainerPage extends StatefulWidget {
  const TrainerPage({super.key, required this.exercise});
  final Exercise exercise;

  @override
  State<TrainerPage> createState() => _TrainerPageState();
}

class _TrainerPageState extends State<TrainerPage> {
  final detector = PoseDetector();
  double ptime = 0;
  double ctime = 0;
  double count = 0;
  int dir = 0;
  double? smoothAngle;
  double lastSmoothTime = 0;
  double lastRepTime = 0;

  // timing (seconds)
  static const holdSeconds = 0.10; // must stay at 100% this long (1-frame spikes)
  static const minRepSeconds = 0.6; // a real rep is never faster than this
  static const maxRepSeconds = 20.0; // stale half-rep: forget it
  static const lostGrace = 0.4; // short landmark dropouts are ridden out
  static const maxJumpDeg = 70.0; // angle jump per frame that is a tracking glitch
  static const attemptPer = 30.0; // % reached before a return counts as "incomplete"
  static const warnDelay = 0.25; // a problem must last this long to be shown
  static const warnHold = 0.6; // and stays this long after it is gone
  static const formTau = 0.35; // form score smoothing time constant

  // ---- deadlift (same as the python file: 10 frames at 15 fps) ----
  static const deadHoldSeconds = 0.25; // python: 10 frames; a real lift rarely pauses 0.67 s
  static const deadLostGrace = 1.0; // python: hidden > 1 s cancels the rep
  bool squatLike = false; // knees bent to squat depth during this deadlift rep
  double minKnee = 999; // smallest knee angle seen during the current rep
  bool deadFront = false; // deadlift filmed facing the camera (frozen during a rep)
  double dbgTilt = 0, dbgRatio = -1; // bench lying-gate numbers, shown when it blocks
  String dbgSrc = '-'; // bench: which landmarks the lying check used
  double kneeFlexDbg = 0, hipFlexDbg = 0; // deadlift squat-check numbers

  // ---- bench: must really be lying down ----
  static const lyingSeconds = 0.3;
  double? lyingSince;
  double? notLyingSince;
  String? gateMsg; // red hint when the exercise position is wrong

  bool get _isDead => widget.exercise.name.contains('Deadlift');
  bool get _isBench => widget.exercise.name.contains('Bench');

  double lastSeenTime = 0;
  double repStartTime = 0;
  bool attempt = false; // left the top, rep not finished yet
  double peakPer = 0;
  double minAngle = 999;
  double? bottomSince;
  double? prevRaw;
  int jumpRejects = 0;
  double? prevSmooth;
  double lastSpeedTime = 0;
  double speed = 0; // smoothed angular speed, deg/s
  final base = <String, double>{}; // the user's own "start" posture
  final repFaults = <String>{};
  final warnFirst = <String, double>{};
  final warnLast = <String, double>{};
  final warnSevere = <String, double>{};
  final shown = <String>[]; // warnings that passed the debounce
  String? note;
  double formScore = 0;
  bool formReady = false; // false = "Form not assessable"
  double lastFormTime = 0;
  double lastAssessable = -99;
  int formState = 0; // 0 good, 1 warn, 2 bad (with hysteresis)
  double? lastRom;
  double? lastConsistency;
  final repDurations = <double>[];
  String repLabel = '';
  String repDetail = '';
  Color repColor = formGood;
  double repLabelTime = -99;

  // biceps curl only: 0 = right arm, 1 = left arm, 2 = both arms together
  int armMode = 0;
  bool get _isCurl => widget.exercise.name.contains('Curl');

  /// the exercise with the arm(s) the user picked; everything else stays as configured
  Exercise get _active {
    final e = widget.exercise;
    if (!_isCurl) return e;
    const rightArm = [12, 14, 16], leftArm = [11, 13, 15];
    return Exercise(
      name: e.name,
      right: armMode == 1 ? leftArm : rightArm,
      left: armMode == 2 ? leftArm : null,
      downAngle: e.downAngle,
      upAngle: e.upAngle,
      perFrameSmoothing: e.perFrameSmoothing,
      variant: e.variant,
      limits: e.limits,
    );
  }

  void _setArmMode(int m) {
    if (m == armMode) return;
    setState(() => armMode = m);
    _resetTracking(); // a half-finished rep of the other arm must not count
    repLabel = '';
  }

  // the python code ran at about 15 fps; "0.7*old + 0.3*new" every frame is made
  // to react the same in seconds at any fps (a 35 fps phone would otherwise react
  // more than twice as fast and let jumpy frames through)
  static const pythonFps = 15.0;

  // make the angle 0-180 no matter which way you face the camera
  double _fold(double angle) => angle > 180 ? 360 - angle : angle;

  double _smooth(double angle) {
    final t = now();
    final dt = (t - lastSmoothTime).clamp(0.0, 1.0);
    lastSmoothTime = t;
    if (smoothAngle == null) return smoothAngle = angle;
    final keep = math.pow(0.7, dt * pythonFps).toDouble();
    return smoothAngle = keep * smoothAngle! + (1 - keep) * angle;
  }

  // ===================== helpers =====================

  double _lim(Exercise e, String key, double fallback) => e.limits[key] ?? fallback;

  double _maxSpeed(Exercise e) => _lim(e, 'maxSpeed', e.name.contains('Curl') ? 400 : 300);

  /// ASSUMPTION: each landmark in lmList looks like [id, x, y]. If your pose_module
  /// returns something else, this is the only place to change.
  Offset? _p(List lm, int id) {
    for (final q in lm) {
      if (q[0] == id) return Offset((q[1] as num).toDouble(), (q[2] as num).toDouble());
    }
    return null;
  }

  /// middle of two landmarks, using only the visible ones
  Offset? _mid(List lm, int a, int b) {
    final pts = <Offset>[];
    for (final id in [a, b]) {
      final q = _p(lm, id);
      if (q != null && detector.isVisible([id])) pts.add(q);
    }
    if (pts.isEmpty) return null;
    return pts.length == 1 ? pts[0] : (pts[0] + pts[1]) / 2;
  }

  /// angle at [b] in degrees (0-180)
  double _ang(Offset a, Offset b, Offset c) {
    final v1 = a - b, v2 = c - b;
    final d = v1.distance * v2.distance;
    if (d < 1e-6) return double.nan;
    final c0 = ((v1.dx * v2.dx + v1.dy * v2.dy) / d).clamp(-1.0, 1.0).toDouble();
    return math.acos(c0) * 180 / math.pi;
  }

  /// how far the line from->to is tilted away from vertical (0 = straight up/down)
  double _fromVertical(Offset from, Offset to) =>
      math.atan2((to.dx - from.dx).abs(), (to.dy - from.dy).abs()) * 180 / math.pi;

  /// the user's own start posture (slowly follows while idle, frozen during a rep),
  /// so body type and camera angle don't need one fixed number
  double _base(String key, double v, bool idle) {
    final b = base[key];
    if (b == null) {
      base[key] = v;
      return v;
    }
    if (idle) return base[key] = 0.95 * b + 0.05 * v;
    return b;
  }

  /// true = facing the camera (shoulders wide), false = side on, null = unknown
  bool? _frontal(List lm, Exercise e) {
    final a = _p(lm, 11), b = _p(lm, 12), c = _p(lm, 23), d = _p(lm, 24);
    if (a == null || b == null || c == null || d == null || !detector.isVisible([11, 12, 23, 24])) {
      return null;
    }
    final tl = ((a + b) / 2 - (c + d) / 2).distance;
    if (tl < 1) return null;
    return (a - b).distance / tl > _lim(e, 'frontalRatio', 0.5);
  }

  /// true = torso is horizontal (lying on a bench), false = upright, null = unknown.
  /// Side camera: torso tilt from vertical. Foot-end camera: the torso is
  /// foreshortened, so it is much shorter than the shoulder width.
  /// Works with ONE visible side (lying on a table, the far side is usually hidden).
  bool? _lying(List lm, Exercise e) {
    final sh = <Offset>[], hp = <Offset>[];
    for (final s in const [
      [11, 23],
      [12, 24]
    ]) {
      if (!detector.isVisible(s)) continue;
      final a = _p(lm, s[0]), b = _p(lm, s[1]);
      if (a != null && b != null) {
        sh.add(a);
        hp.add(b);
      }
    }
    if (sh.isEmpty) {
      // hips not detected (very common lying on a table): use the head-shoulder line.
      // Lying on its side it is nearly horizontal; standing it is nearly vertical.
      for (final s in const [
        [7, 11],
        [8, 12],
        [0, 11],
        [0, 12]
      ]) {
        if (!detector.isVisible(s)) continue;
        final head = _p(lm, s[0]), shoulder = _p(lm, s[1]);
        if (head == null || shoulder == null || (head - shoulder).distance < 1) continue;
        dbgSrc = 'head';
        dbgRatio = -1;
        dbgTilt = _fromVertical(shoulder, head);
        return dbgTilt >= _lim(e, 'lyingTilt', 40);
      }
      dbgSrc = 'none';
      return null;
    }
    dbgSrc = 'hips';
    final s = sh.length == 2 ? (sh[0] + sh[1]) / 2 : sh[0];
    final h = hp.length == 2 ? (hp[0] + hp[1]) / 2 : hp[0];
    final tl = (s - h).distance;
    if (tl < 1) return null;
    dbgTilt = _fromVertical(h, s);
    dbgRatio = -1;
    var lying = dbgTilt >= _lim(e, 'lyingTilt', 40);
    if (sh.length == 2) {
      // camera at the head or foot end: the torso is foreshortened
      dbgRatio = tl / math.max((sh[0] - sh[1]).distance, 1.0);
      lying = lying || dbgRatio < _lim(e, 'lyingRatio', 0.6);
    }
    return lying;
  }

  /// like _base, but only follows while idle AND near the upright value, so a slow
  /// start of the lift cannot drag the "standing" reference down with it
  double _standBase(String key, double v, bool idle) {
    final b = base[key];
    if (b == null) {
      base[key] = v;
      return v;
    }
    if (!idle) return b;
    if (v > b) return base[key] = 0.8 * b + 0.2 * v;
    if (v > 0.9 * b) return base[key] = 0.95 * b + 0.05 * v;
    return base[key] = 0.9995 * b; // far below: slow drift, so one early spike can't stick
  }

  /// Deadlift facing the camera: the hip angle hardly changes in 2D, so use how much
  /// the torso got shorter vertically compared with standing: lean = acos(vert/standing).
  /// Returned as an equivalent hip angle (180 = upright) so the same up/down limits work.
  double? _frontHinge(List lm, bool idle) {
    final sh = _mid(lm, 11, 12), hp = _mid(lm, 23, 24);
    if (sh == null || hp == null) return null;
    final vert = hp.dy - sh.dy; // shoulders are above the hips
    if (vert < 1) return null;
    final stand = _standBase('frontVert', vert, idle);
    final lean = math.acos((vert / stand).clamp(0.0, 1.0).toDouble()) * 180 / math.pi;
    // dead zone (relaxed standing is never exactly upright) and gain (the camera
    // under-reads a forward lean): standing = 180, a real hinge reaches the limit
    final flex = math.max(0.0, lean - _lim(widget.exercise, 'frontDead', 10)) * _lim(widget.exercise, 'frontGain', 1.5);
    return 180 - flex;
  }

  /// how far the worst knee is inside its toes (0 = over the toes), as a fraction
  /// of shin length. Uses the toe, so a deliberate toe-out stance is not punished.
  double? _kneeCave(List lm) {
    final h1 = _p(lm, 23), h2 = _p(lm, 24);
    if (h1 == null || h2 == null) return null;
    final mx = (h1.dx + h2.dx) / 2;
    double? worst;
    for (final s in const [
      [25, 27, 31],
      [26, 28, 32]
    ]) {
      if (!detector.isVisible([s[0], s[1]])) continue;
      final kn = _p(lm, s[0]), an = _p(lm, s[1]), toe = _p(lm, s[2]);
      if (kn == null || an == null) continue;
      final Offset ft = (toe != null && detector.isVisible([s[2]])) ? toe : an;
      final shin = (kn - an).distance;
      if (shin < 1) continue;
      final inward = ((mx - ft.dx).abs() - (mx - kn.dx).abs()) / shin;
      worst = worst == null ? inward : math.max(worst, inward);
    }
    return worst;
  }

  /// stance width (ankles / shoulders) and knee cave: only meaningful facing the camera
  void _frontChecks(_Eval ev, List lm, Exercise e, double per, double sMin, double sMax) {
    final a1 = _p(lm, 27), a2 = _p(lm, 28), s1 = _p(lm, 11), s2 = _p(lm, 12);
    if (a1 != null && a2 != null && s1 != null && s2 != null && detector.isVisible([27, 28])) {
      final sw = (s1 - s2).distance;
      if (sw > 1) {
        final ratio = (a1 - a2).distance / sw;
        ev.limit(_lim(e, 'stanceMin', sMin) - ratio, 0.3, 'Stance too narrow');
        ev.limit(ratio - _lim(e, 'stanceMax', sMax), 0.5, 'Stance too wide');
      }
    }
    final cave = _kneeCave(lm);
    if (cave != null) {
      ev.limit(per >= 30 ? cave - _lim(e, 'kneeCave', 0.15) : -1, 0.2, 'Knees caving in', block: true);
    }
  }

  // ===================== per-exercise form checks =====================

  _Eval _curl(List lm, Exercise e, double per, bool idle) {
    final ev = _Eval();
    // one arm or both arms (see armMode): every active arm is checked
    for (final arm in [e.right, if (e.left != null) e.left!]) {
      final isRight = arm[0] == 12;
      final hipId = isRight ? 24 : 23, otherShId = isRight ? 11 : 12;
      final s = _p(lm, arm[0]), el = _p(lm, arm[1]), hip = _p(lm, hipId);
      if (s == null || el == null || hip == null || !detector.isVisible([arm[0], arm[1], hipId])) {
        continue; // hip hidden: swing cannot be judged for this arm
      }
      final torso = (s - hip).distance;
      if (torso < 1) continue;
      // 1) upper arm should stay near the torso; elbow swinging forward = shoulder is helping
      ev.limit(_ang(hip, s, el) - _lim(e, 'elbowDrift', 25), 30, 'Elbow drifting forward',
          block: true, blockAt: _lim(e, 'elbowDriftReject', 30));
      // 2) body swing: torso lean compared with the user's own start posture
      final lean = _fromVertical(hip, s);
      // side on, the far hip is partly hidden and wobbles, so this only REJECTS a rep
      // when the body really moves (swing + swingReject degrees from the start posture)
      ev.limit((lean - _base('lean$hipId', lean, idle)).abs() - _lim(e, 'swing', 12), 20,
          'Swinging - stay still',
          block: true, blockAt: _lim(e, 'swingReject', 20));
      // 3) shoulder shrug: torso length (hip to shoulder) changes
      ev.limit(((torso / _base('torso$hipId', torso, idle)) - 1).abs() - _lim(e, 'shrug', 0.12), 0.12,
          'Shoulders shrugging');
      // 4) torso twist: shoulder width changes a lot
      final s2 = _p(lm, otherShId);
      if (s2 != null && detector.isVisible([otherShId])) {
        final sw = (s - s2).distance;
        ev.limit(((sw / _base('sw$hipId', sw, idle)) - 1).abs() - _lim(e, 'twist', 0.2), 0.2,
            'Torso twisting');
      }
      ev.assessable = true;
    }
    return ev;
  }

  _Eval _squat(List lm, Exercise e, double per, bool? front) {
    final ev = _Eval();
    final sh = _mid(lm, 11, 12), hp = _mid(lm, 23, 24);
    if (sh != null && hp != null) {
      // trunk lean varies a lot with leg/torso proportions, so the limit is generous
      ev.limit(_fromVertical(hp, sh) - _lim(e, 'torsoLean', 60), 20, 'Chest up - leaning far', block: true);
    }
    if (front == true) _frontChecks(ev, lm, e, per, 0.6, 2.0);
    ev.assessable = ev.scores.isNotEmpty;
    return ev;
  }

  _Eval _deadlift(List lm, Exercise e, double per, bool idle, bool? front) {
    final ev = _Eval();
    final rdl = e.variant == 'romanian', sumo = e.variant == 'sumo';
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
      if (!detector.isVisible(s)) continue;
      final a = _p(lm, s[0]), b = _p(lm, s[1]), c = _p(lm, s[2]);
      if (a == null || b == null || c == null) continue;
      final ang = _ang(a, b, c);
      if (!ang.isFinite) continue;
      ev.limit((_base('neck', ang, idle) - ang) - _lim(e, 'spineDrift', 25), 15, 'Keep spine neutral');
      spineSeen = true;
      break;
    }
    if (!spineSeen) ev.note = 'Head/back not visible';
    // knee bend at the bottom depends on the variation
    final kLo = _lim(e, 'kneeMin', rdl ? 135 : (sumo ? 70 : 85));
    final kHi = _lim(e, 'kneeMax', rdl ? 178 : (sumo ? 140 : 150));
    final ks = <double>[];
    for (final s in const [
      [24, 26, 28],
      [23, 25, 27]
    ]) {
      if (!detector.isVisible(s)) continue;
      final a = _p(lm, s[0]), b = _p(lm, s[1]), c = _p(lm, s[2]);
      if (a == null || b == null || c == null) continue;
      final ang = _ang(a, b, c);
      if (ang.isFinite) ks.add(ang);
    }
    if (ks.isNotEmpty && !deadFront) {
      final knee = ks.reduce((a, b) => a + b) / ks.length;
      ev.limit(low ? kLo - knee : -1, 25, 'Too much knee bend');
      ev.limit(low ? knee - kHi : -1, 25, 'Knees too straight');
    }
    if (front == true) _frontChecks(ev, lm, e, per, sumo ? 1.4 : 0.6, sumo ? 3.0 : 1.5);
    ev.assessable = ev.scores.isNotEmpty;
    return ev;
  }

  _Eval _bench(List lm, Exercise e, double per, bool idle, bool? front) {
    final ev = _Eval();
    final flares = <double>[], tilts = <double>[], bends = <double>[];
    final wrists = <Offset>[];
    var segs = 0.0;
    var sides = 0;
    for (final s in [e.right, if (e.left != null) e.left!]) {
      if (!detector.isVisible(s)) continue;
      final sh = _p(lm, s[0]), el = _p(lm, s[1]), wr = _p(lm, s[2]);
      if (sh == null || el == null || wr == null) continue;
      final isRight = s[0] == 12;
      final hipId = isRight ? 24 : 23, idxId = isRight ? 20 : 19;
      final hip = detector.isVisible([hipId]) ? _p(lm, hipId) : null;
      final idx = detector.isVisible([idxId]) ? _p(lm, idxId) : null;
      if (hip != null) flares.add(_ang(hip, sh, el)); // elbow-to-torso angle
      tilts.add(_fromVertical(el, wr)); // forearm vs vertical
      if (idx != null) bends.add(_ang(el, wr, idx)); // wrist straightness
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
    // so flare can only be judged from the head/foot end, and it only warns (before,
    // it rejected every rep filmed from the side).
    if (front == true && fl.isNotEmpty) {
      ev.limit(per >= 50 ? fl.reduce(math.max) - _lim(e, 'flareMax', 85) : -1, 20, 'Elbows flared wide');
      ev.limit(per >= 50 ? _lim(e, 'flareMin', 25) - fl.reduce(math.min) : -1, 15, 'Elbows tucked in');
    } else if (front != true) {
      ev.note = 'Flare needs head/foot view';
    } else {
      ev.note = 'Hips hidden - flare unchecked';
    }
    // forearm should be close to vertical near the chest (wrist stacked over elbow)
    if (tl.isNotEmpty) {
      ev.limit(per >= 70 ? tl.reduce(math.max) - _lim(e, 'forearmTilt', 25) : -1, 20, 'Stack wrist over elbow');
    }
    // wrist alignment: elbow-wrist-knuckle should be near straight
    if (bd.isNotEmpty) {
      ev.limit(per >= 30 ? _lim(e, 'wristMin', 145) - bd.reduce(math.min) : -1, 25, 'Wrist bent back');
    }
    // bar path (the wrists stand in for the bar): sideways drift from the start line
    final x = wrists.map((p) => p.dx).reduce((a, b) => a + b) / wrists.length;
    final seg = segs / (2 * sides);
    if (seg > 1) {
      ev.limit((x - _base('barX', x, idle)).abs() / seg - 0.5, 0.4, 'Bar path drifting');
    }
    // uneven bar (facing the camera): one wrist higher than the other
    final s1 = _p(lm, 11), s2 = _p(lm, 12);
    if (front == true && wrists.length == 2 && s1 != null && s2 != null) {
      final sw = (s1 - s2).distance;
      if (sw > 1) {
        ev.limit((wrists[0].dy - wrists[1].dy).abs() / sw - _lim(e, 'barTilt', 0.25), 0.25, 'Bar uneven');
      }
    }
    ev.assessable = true;
    return ev;
  }

  _Eval _evaluate(List lm, Exercise e, double per, bool idle, bool? front, double? asym) {
    final n = e.name;
    final ev = n.contains('Curl')
        ? _curl(lm, e, per, idle)
        : n.contains('Squat')
            ? _squat(lm, e, per, front)
            : n.contains('Deadlift')
                ? _deadlift(lm, e, per, idle, front)
                : n.contains('Bench')
                    ? _bench(lm, e, per, idle, front)
                    : _Eval();
    // one side doing more work than the other (needs both sides and a frontal view)
    if (ev.assessable && asym != null && front == true) {
      ev.limit(per >= 40 ? asym - _lim(e, 'asym', 25) : -1, 20, 'Uneven sides');
    }
    if (speed > 1.3 * _maxSpeed(e)) ev.warns.add('Slow down - control it');
    return ev;
  }

  // ===================== warnings, form score, rep result =====================

  bool _severeNow(String m, double t) => t - (warnSevere[m] ?? -99) <= warnHold;

  /// a problem is only shown after it lasted warnDelay and is kept warnHold: no flicker
  void _updateWarnings(_Eval ev, double t) {
    for (final m in ev.warns) {
      warnFirst.putIfAbsent(m, () => t);
      warnLast[m] = t;
    }
    for (final m in ev.blocking) {
      warnSevere[m] = t;
    }
    final drop = <String>[];
    warnLast.forEach((m, last) {
      if (t - last > warnHold) drop.add(m);
    });
    for (final m in drop) {
      warnLast.remove(m);
      warnFirst.remove(m);
    }
    shown.clear();
    for (final m in warnLast.keys) {
      if (warnLast[m]! - warnFirst[m]! >= warnDelay) shown.add(m);
    }
    note = ev.note;
  }

  int _nextState(int s, double v) {
    const good = 80.0, bad = 55.0, hy = 5.0; // hysteresis: the colour doesn't flicker
    if (s == 0) return v < good - hy ? (v < bad ? 2 : 1) : 0;
    if (s == 1) return v >= good + hy ? 0 : (v < bad - hy ? 2 : 1);
    return v >= bad + hy ? (v >= good + hy ? 0 : 1) : 2;
  }

  /// form score = alignment (60%) + range of motion of the last rep (25%) +
  /// tempo/consistency (15%). Missing parts are left out, never faked.
  void _updateForm(Exercise e, _Eval ev, double t) {
    if (!(ev.assessable && ev.scores.isNotEmpty)) {
      if (t - lastAssessable > 0.4) formReady = false;
      return;
    }
    lastAssessable = t;
    final mean = ev.scores.reduce((a, b) => a + b) / ev.scores.length;
    final align = 0.5 * mean + 0.5 * ev.scores.reduce(math.min); // worst check counts
    final ms = _maxSpeed(e);
    final tempoNow = speed <= ms ? 1.0 : (1 - (speed - ms) / ms).clamp(0.0, 1.0).toDouble();
    var acc = 0.0, wsum = 0.0;
    void part(double? v, double wt) {
      if (v != null) {
        acc += v * wt;
        wsum += wt;
      }
    }

    part(align, 0.6);
    part(lastRom, 0.25);
    final lc = lastConsistency;
    part(lc == null ? tempoNow : (tempoNow + lc) / 2, 0.15);
    final target = 100 * acc / wsum;
    final dt = (t - lastFormTime).clamp(0.0, 1.0).toDouble();
    lastFormTime = t;
    formScore = formReady ? formScore + (target - formScore) * (1 - math.exp(-dt / formTau)) : target;
    if (!formReady) formState = 0;
    formReady = true;
    formState = _nextState(formState, formScore);
  }

  Color _formColor(double t) {
    if (!formReady) return formNA;
    var st = formState;
    if (shown.isNotEmpty) st = math.max(st, 1); // never emerald while a warning is up
    if (shown.any((m) => _severeNow(m, t))) st = 2;
    return st == 0 ? formGood : (st == 1 ? formWarn : formBad);
  }

  void _finishRep(Exercise e, double t) {
    final dur = t - repStartTime;
    if (dur < minRepSeconds || t - lastRepTime <= 1) return; // jitter (same 1 s rule as before)
    // deadlift only: knees bent to squat depth = it was a squat, do not count
    if (_isDead && squatLike) {
      repLabel = 'Squat - not a deadlift';
      repColor = formBad;
      repDetail = 'Hinge at the hips';
      repLabelTime = t;
      return;
    }
    lastRepTime = t;
    final squat = e.name.contains('Squat');
    final faults = repFaults.toList();
    final soft = _isDead || _isBench; // only the squat / lying checks decide these
    final counted = faults.isEmpty || _lim(e, 'countFaulty', 0) > 0 || soft;
    if (squat) {
      if (faults.isNotEmpty) {
        repLabel = 'Incorrect';
        repColor = formBad;
      } else if (minAngle <= _lim(e, 'deepAngle', 95)) {
        repLabel = 'Deep';
        repColor = formGood;
      } else {
        repLabel = 'Partial';
        repColor = formWarn;
      }
    } else {
      repLabel = faults.isEmpty ? 'Good rep' : (soft ? 'Counted - check form' : 'Rejected');
      repColor = faults.isEmpty ? formGood : (soft ? formWarn : formBad);
    }
    repDetail = faults.isNotEmpty
        ? faults.first
        : (repLabel == 'Partial' ? 'Go deeper for full depth' : '');
    repLabelTime = t;
    if (counted) count += 1;
    // range of motion of this rep (squat is scored against full depth, not the 120 counting line)
    final target = squat ? _lim(e, 'deepAngle', 95) : e.downAngle;
    lastRom = ((e.upAngle - minAngle) / (e.upAngle - target)).clamp(0.0, 1.0).toDouble();
    // consistency: how close this rep's duration is to the recent ones
    repDurations.add(dur);
    if (repDurations.length > 6) repDurations.removeAt(0);
    if (repDurations.length >= 3) {
      final prev = repDurations.sublist(0, repDurations.length - 1);
      final mean = prev.reduce((a, b) => a + b) / prev.length;
      lastConsistency = (1 - ((dur - mean).abs() / mean - 0.35) / 0.65).clamp(0.0, 1.0).toDouble();
    }
  }

  void _incompleteRep(Exercise e, double t) {
    final squat = e.name.contains('Squat');
    final n = e.name;
    repLabel = squat ? 'Incorrect' : 'Incomplete rep';
    repColor = squat ? formBad : formWarn;
    repDetail = squat
        ? 'Too shallow - not counted'
        : n.contains('Curl')
            ? 'Curl through full range'
            : n.contains('Bench')
                ? 'Lower to chest, lock out'
                : n.contains('Deadlift')
                    ? 'Hinge fully, then lock out'
                    : '';
    repLabelTime = t;
    lastRom = ((e.upAngle - minAngle) / (e.upAngle - e.downAngle)).clamp(0.0, 1.0).toDouble();
  }

  /// the person left or is hidden for a while: forget the half-finished rep
  /// (before, a rep started, the person walked out, came back and it was counted)
  void _resetTracking() {
    dir = 0;
    attempt = false;
    bottomSince = null;
    smoothAngle = null;
    prevRaw = null;
    prevSmooth = null;
    jumpRejects = 0;
    speed = 0;
    base.clear();
    repFaults.clear();
    warnFirst.clear();
    warnLast.clear();
    warnSevere.clear();
    shown.clear();
    note = null;
    formReady = false;
    lastRom = null;
    lastConsistency = null;
    repDurations.clear();
    squatLike = false;
    minKnee = 999;
    lyingSince = null;
    notLyingSince = null;
    gateMsg = null;
  }

  /// bad numbers (NaN) and one-frame tracking glitches must not move the angle
  double _cleanAngle(double a, Exercise e) {
    final pr = prevRaw;
    if (!a.isFinite) {
      a = pr ?? e.upAngle;
    } else if (pr != null && (a - pr).abs() > maxJumpDeg && jumpRejects < 2) {
      jumpRejects++;
      a = pr;
    } else {
      jumpRejects = 0;
    }
    prevRaw = a;
    return a;
  }

  Future<void> onFrame(Frame img) async {
    final e = _active;
    final oneSide = widget.exercise.oneSide; // HUD layout does not change with the arm choice
    await detector.findPose(img);
    final lmList = detector.findPosition(img, draw: false);
    final w = img.width, h = img.height;
    // python text sizes were made for a 640x480 (AiTrainer) or 1280x720 picture
    final k = math.min(w, h) / (oneSide ? 480 : 720);
    final hud = img.hud;
    final t = now();

    // text that always fits: shrinks, then cuts, instead of running into the bar
    void put(String s, double x, double y, double scale, Color color, double maxW,
        {bool right = false}) {
      const cw = 18.0; // about one letter at scale 1
      var sc = scale;
      var txt = s;
      if (txt.length * cw * sc > maxW) sc = math.max(maxW / (txt.length * cw), 0.45 * k);
      final fit = (maxW / (cw * sc)).floor();
      if (txt.length > fit && fit > 2) txt = '${txt.substring(0, fit - 2)}..';
      hud.putText(txt, right ? x - txt.length * cw * sc : x, y, sc, color, 2);
    }

    // deadlift (python): shoulders, hips, knees and ankles must ALL be visible.
    // Every exercise checks that its joints are really seen, and a short dropout
    // (lostGrace) is ridden out instead of resetting the rep.
    final fullBody =
        !_isDead || (lmList.isNotEmpty && detector.isVisible([11, 12, 23, 24, 25, 26, 27, 28]));
    final rightOk = lmList.isNotEmpty && fullBody && detector.isVisible(e.right);
    final leftOk = lmList.isNotEmpty && fullBody && e.left != null && detector.isVisible(e.left!);
    gateMsg = null;
    if (rightOk || leftOk) {
      lastSeenTime = t;
    } else {
      bottomSince = null; // python: hold = 0 when joints are hidden
      if (t - lastSeenTime > (_isDead ? deadLostGrace : lostGrace)) _resetTracking();
      // set after the reset, because _resetTracking clears gateMsg
      if (_isDead) gateMsg = 'Show your full body';
      if (_isBench) gateMsg = 'Show shoulder, elbow, wrist';
    }

    final barTop = h * 0.2;
    final barBottom = h * 0.9;
    final barX1 = w * 0.88;
    final barX2 = w * 0.96;
    final dbg = <String>[];
    if (!(rightOk || leftOk)) {
      dbg.add('joints not seen: R $rightOk L $leftOk lm ${lmList.length}');
    }

    if (rightOk || leftOk) {
      final aR = rightOk ? _fold(detector.findAngle(img, e.right[0], e.right[1], e.right[2])) : 0.0;
      final aL = leftOk ? _fold(detector.findAngle(img, e.left![0], e.left![1], e.left![2])) : 0.0;
      // both sides must bend: use the straighter one, so moving one side can't count a rep
      // deadlift: decide side view / front view only while idle (never mid-rep)
      if (_isDead && dir == 0 && !attempt) deadFront = _frontal(lmList, e) == true;
      final sideRaw = !aR.isFinite ? aL : (!aL.isFinite ? aR : math.max(aR, aL));
      // deadlift: take whichever measure shows MORE hinge. Side on, the hip angle shows it;
      // facing the camera, the torso getting shorter shows it. No view guessing needed.
      final frontRaw = _isDead ? _frontHinge(lmList, dir == 0 && !attempt) : null;
      final raw = (frontRaw != null && sideRaw.isFinite) ? math.min(sideRaw, frontRaw) : (frontRaw ?? sideRaw);
      final angle = _cleanAngle(raw, e);
      final asym = (!(_isDead && deadFront) && rightOk && leftOk && aR.isFinite && aL.isFinite)
          ? (aR - aL).abs()
          : null;
      // smooth the angle so one jumpy frame can't change it much
      final double smoothed;
      if (e.perFrameSmoothing) {
        smoothAngle ??= angle;
        smoothed = smoothAngle = 0.7 * smoothAngle! + 0.3 * angle;
      } else {
        smoothed = _smooth(angle);
      }
      final per = interp(smoothed, e.downAngle, e.upAngle, 100, 0).clamp(0.0, 100.0).toDouble();

      // angular speed (smoothed): too fast = jerky / momentum
      final dtS = (t - lastSpeedTime).clamp(0.001, 1.0).toDouble();
      speed = 0.8 * speed + 0.2 * ((smoothed - (prevSmooth ?? smoothed)).abs() / dtS);
      prevSmooth = smoothed;
      lastSpeedTime = t;

      // ---- BENCH: only count while lying down (blocks shoulder press / curl) ----
      var gateOk = true;
      if (_isBench) {
        final ly = _lying(lmList, e);
        if (ly == false) {
          // clearly upright: only after 1 s of it is the lying state dropped
          notLyingSince ??= t;
          if (t - notLyingSince! > 1.0) lyingSince = null;
        } else {
          // lying, or cannot tell (null): do not block the rep
          lyingSince ??= t;
          notLyingSince = null;
        }
        gateOk = lyingSince != null && t - lyingSince! >= lyingSeconds;
        if (!gateOk) gateMsg = 'Lie on the bench';
        if (!gateOk && (attempt || dir != 0)) {
          // stood up / left the bench mid-rep: forget it
          attempt = false;
          dir = 0;
          bottomSince = null;
          repFaults.clear();
        }
      }

      // ---- DEADLIFT: knees never bend to squat depth (python squat_like) ----
      if (_isDead) {
        final ks = <double>[];
        for (final s in const [
          [24, 26, 28],
          [23, 25, 27]
        ]) {
          final a = _p(lmList, s[0]), b = _p(lmList, s[1]), c = _p(lmList, s[2]);
          if (a == null || b == null || c == null) continue;
          final v = _ang(a, b, c);
          if (v.isFinite) ks.add(v);
        }
        final rdl = e.variant == 'romanian', sumo = e.variant == 'sumo';
        if (deadFront) {
          // facing the camera knee angles are useless (the knees bend toward the lens),
          // so a squat is detected by the hips dropping: hip-to-ankle height shrinks
          final an = _mid(lmList, 27, 28), hpm = _mid(lmList, 23, 24);
          if (an != null && hpm != null) {
            final ext = an.dy - hpm.dy;
            if (ext > 1) {
              final stand = _standBase('legExt', ext, dir == 0 && !attempt);
              final legDrop = _lim(e, 'squatLegDrop', rdl ? 0.25 : (sumo ? 0.50 : 0.38));
              if (attempt && 1 - ext / stand > legDrop) squatLike = true;
            }
          }
        } else if (ks.isNotEmpty) {
          final knee = ks.reduce(math.max); // python: max of both knees
          // the lifter's own standing angles (follow while idle, frozen in a rep)
          final idleNow = dir == 0 && !attempt;
          final kneeStand = _standBase('kneeStand', knee, idleNow);
          final hipStand = _standBase('hipStand', smoothed, idleNow);
          if (attempt) {
            // checked during the WHOLE rep, not only after the bottom hold
            minKnee = math.min(minKnee, knee);
            final kneeFlex = kneeStand - minKnee; // how much the knees bent
            final hipFlex = math.max(hipStand - minAngle, 1.0); // how much the hips hinged
            kneeFlexDbg = kneeFlex;
            hipFlexDbg = hipFlex;
            // a deadlift is mostly HIP hinge (knees bend little); a squat is mostly KNEE
            // bend. So compare them instead of using one fixed knee angle.
            final ratio = _lim(e, 'squatRatio', rdl ? 0.9 : (sumo ? 1.8 : 1.2));
            final deepKnee = _lim(e, 'squatKnee', rdl ? 100 : (sumo ? 55 : 75));
            if ((kneeFlex >= 45 && kneeFlex > ratio * hipFlex) || minKnee < deepKnee) squatLike = true;
          }
        }
      }

      // form checks for this frame
      final idle = dir == 0 && !attempt;
      final ev = _evaluate(lmList, e, per, idle, _frontal(lmList, e), asym);
      _updateWarnings(ev, t);

      // rep state machine
      if (!attempt && per > 15 && gateOk) {
        attempt = true; // left the top
        repStartTime = t;
        peakPer = 0;
        minAngle = smoothed;
        repFaults.clear();
        squatLike = false;
        minKnee = 999;
      }
      if (attempt) {
        peakPer = math.max(peakPer, per);
        minAngle = math.min(minAngle, smoothed);
        for (final m in shown) {
          if (_severeNow(m, t)) repFaults.add(m); // only faults that lasted count
        }
        if (t - repStartTime > maxRepSeconds) {
          attempt = false;
          dir = 0;
        }
      }
      // down: must reach 100% and stay there (deadlift: 10 frames like python)
      final holdNeed = _isDead ? deadHoldSeconds : holdSeconds;
      if (per >= 100 && gateOk) {
        bottomSince ??= t;
        if (dir == 0 && attempt && t - bottomSince! >= holdNeed) {
          dir = 1; // squatLike is NOT reset here: it must survive until the rep ends
        }
      } else {
        bottomSince = null;
      }
      // up: must come back to 0%, and at least 1 second since the last rep
      if (per <= 0) {
        if (dir == 1) {
          _finishRep(e, t);
        } else if (attempt && peakPer >= attemptPer) {
          _incompleteRep(e, t); // went part way down and came back
        }
        dir = 0;
        attempt = false;
        bottomSince = null;
      }
      _updateForm(e, ev, t);

      dbg.add('angle ${smoothed.round()}  need ${e.downAngle.round()}..${e.upAngle.round()}  '
          'min ${minAngle == 999 ? '-' : minAngle.round()}');
      dbg.add('per ${per.round()}  dir $dir  attempt ${attempt ? 1 : 0}  hold ${bottomSince == null ? 0 : 1}');
      if (_isBench) {
        dbg.add('lying ${gateOk ? 'YES' : 'no'}  src $dbgSrc  tilt ${dbgTilt.round()}'
            '${dbgRatio >= 0 ? '  ratio ${dbgRatio.toStringAsFixed(1)}' : ''}');
        dbg.add('R arm $rightOk  L arm $leftOk');
      }
      if (_isDead) {
        String n(double? v) => (v == null || !v.isFinite) ? '-' : v.round().toString();
        dbg.add('side ${n(sideRaw)}  front ${n(frontRaw)}  (lower one is used)');
        dbg.add('knee flex ${kneeFlexDbg.round()}  hip flex ${hipFlexDbg.round()}  '
            'squat ${squatLike ? 'YES' : 'no'}');
      }

      final bar = interp(per, 0, 100, barBottom, barTop);
      final barColor = _formColor(t);

      hud.rectangle(barX1, barTop, barX2, barBottom, barColor, 3 * k);
      hud.rectangle(barX1, bar, barX2, barBottom, barColor, filled);
      if (oneSide) {
        hud.putText('${per.toInt()}', w * 450 / 640, h * 70 / 480, 3 * k, blue, 3);
        hud.putText('${count.toInt()}', 10, h * 450 / 480, 3 * k, blue, 3);
      } else {
        hud.putText('${per.toInt()}%', barX1 - 40 * k, barTop - 20 * k, 2 * k, blue, 3);
        hud.putText('${count.toInt()}', 20, h - 40 * k, 4 * k, blue, 5);
      }
    }

    // feedback column (left, under the fps text) - never reaches the bar
    final maxW = math.max(barX1 - 40 * k - 20, 120.0);
    var y = 120 * k;
    if (gateMsg != null) {
      put(gateMsg!, 10, y, 1.1 * k, formBad, maxW);
      y += 38 * k;
      if (_isBench && gateMsg == 'Lie on the bench') {
        // shows WHY it thinks you are not lying down, so the limits can be tuned
        final r = dbgRatio >= 0 ? '  ratio ${dbgRatio.toStringAsFixed(1)}' : '';
        put('tilt ${dbgTilt.round()} need ${_lim(e, 'lyingTilt', 40).round()}$r', 10, y, 0.7 * k, formNA,
            maxW);
        y += 30 * k;
      }
    }
    if (repLabel.isNotEmpty && t - repLabelTime < 4) {
      put(repLabel, 10, y, 1.3 * k, repColor, maxW);
      y += 38 * k;
      if (repDetail.isNotEmpty) {
        put(repDetail, 10, y, 0.9 * k, repColor, maxW);
        y += 32 * k;
      }
    }
    for (final m in shown.take(2)) {
      put(m, 10, y, 0.9 * k, _severeNow(m, t) ? formBad : formWarn, maxW);
      y += 32 * k;
    }
    if (shown.isEmpty && formReady && note != null) put(note!, 10, y, 0.8 * k, formNA, maxW);
    // form score under the bar, or an honest "not assessable"
    put(formReady ? 'Form ${formScore.round()}%' : 'Form not assessable', w - 12.0, h - 12 * k, 0.9 * k,
        _formColor(t), w * 0.55,
        right: true);

    if (debugHud) {
      var dy = h * 0.5;
      for (final s in dbg) {
        put(s, 10, dy, 0.6 * k, formNA, maxW);
        dy += 24 * k;
      }
    }

    ctime = now();
    final dtFrame = ctime - ptime;
    final fps = dtFrame > 0 ? 1 / dtFrame : 0.0;
    ptime = ctime;
    hud.putText('${fps.toInt()}', 10, 70 * k, 2 * k, magenta, 3);
  }

  @override
  void dispose() {
    detector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CameraView(
        title: widget.exercise.name,
        onFrame: onFrame,
        actions: _isCurl
            ? [
                PopupMenuButton<int>(
                  tooltip: 'Arms',
                  initialValue: armMode,
                  onSelected: _setArmMode,
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 0, child: Text('Right arm')),
                    PopupMenuItem(value: 1, child: Text('Left arm')),
                    PopupMenuItem(value: 2, child: Text('Both arms')),
                  ],
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(const ['Right arm', 'Left arm', 'Both arms'][armMode]),
                      const Icon(Icons.arrow_drop_down),
                    ]),
                  ),
                ),
              ]
            : null,
      );
}