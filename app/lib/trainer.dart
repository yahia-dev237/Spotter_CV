import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'camera_view.dart';
import 'cv.dart';
import 'pose_module.dart';

/// the settings that are different between AiTrainer.py, SquatTrainer.py,
/// DeadliftTrainer.py and BenchPressTrainer.py
class Exercise {
  const Exercise({
    required this.name,
    required this.right,
    this.left,
    required this.downAngle,
    required this.upAngle,
    this.perFrameSmoothing = false,
  });

  final String name;
  final List<int> right; // the 3 landmark ids of the right side
  final List<int>? left; // null = only the right side (AiTrainer.py)
  final double downAngle; // angle at 100%
  final double upAngle; // angle at 0%
  // true = exactly like the python file: "0.7*old + 0.3*new" every frame and no
  // visibility check (felt better for the squat on the phone than the timed version)
  final bool perFrameSmoothing;

  /// AiTrainer.py is the first version: one arm
  bool get oneSide => left == null;
}

const exercises = [
  // Right Arm (shoulder=12, elbow=14, wrist=16)
  Exercise(name: 'Biceps Curl', right: [12, 14, 16], downAngle: 94, upAngle: 130),
  // Right Leg (hip=24, knee=26, ankle=28), Left Leg (hip=23, knee=25, ankle=27)
  // standing 160 = 0% , half squat 120 or deeper = 100%
  Exercise(name: 'Squat', right: [24, 26, 28], left: [23, 25, 27], downAngle: 120, upAngle: 160,
      perFrameSmoothing: true),
  // Right Hip (shoulder=12, hip=24, knee=26), Left Hip (shoulder=11, hip=23, knee=25)
  // standing tall 160 = 0% , bar at knee height 137 or lower = 100%
  Exercise(name: 'Deadlift', right: [12, 24, 26], left: [11, 23, 25], downAngle: 137, upAngle: 160),
  // Right Arm (shoulder=12, elbow=14, wrist=16), Left Arm (shoulder=11, elbow=13, wrist=15)
  // arms extended 152 = 0% , bar on the chest 79 = 100%
  Exercise(name: 'Bench Press', right: [12, 14, 16], left: [11, 13, 15], downAngle: 79, upAngle: 152),
];

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

  Future<void> onFrame(Frame img) async {
    final e = widget.exercise;
    await detector.findPose(img);
    final lmList = detector.findPosition(img, draw: false);
    final w = img.width, h = img.height;
    // python text sizes were made for a 640x480 (AiTrainer) or 1280x720 picture
    final k = math.min(w, h) / (e.oneSide ? 480 : 720);
    final hud = img.hud;

    // only use a side when its 3 joints are really seen; a half visible body
    // (walking into the picture) gives guessed joints and fake reps
    final check = !e.perFrameSmoothing;
    final rightOk = lmList.isNotEmpty && (!check || detector.isVisible(e.right));
    final leftOk = lmList.isNotEmpty && e.left != null && (!check || detector.isVisible(e.left!));
    // start fresh when the person comes back (the python way keeps the old value)
    if (check && !rightOk && !leftOk) smoothAngle = null;

    if (rightOk || leftOk) {
      final angleR = rightOk ? _fold(detector.findAngle(img, e.right[0], e.right[1], e.right[2])) : 0.0;
      final angleL = leftOk ? _fold(detector.findAngle(img, e.left![0], e.left![1], e.left![2])) : 0.0;
      // both sides must bend: use the straighter one, so moving one side can't count a rep
      final angle = math.max(angleR, angleL);
      // smooth the angle so one jumpy frame can't change it much
      final double smoothed;
      if (e.perFrameSmoothing) {
        smoothAngle ??= angle;
        smoothed = smoothAngle = 0.7 * smoothAngle! + 0.3 * angle;
      } else {
        smoothed = _smooth(angle);
      }
      final per = interp(smoothed, e.downAngle, e.upAngle, 100, 0).clamp(0.0, 100.0);

      final barTop = h * 0.2;
      final barBottom = h * 0.9;
      final barX1 = w * 0.88;
      final barX2 = w * 0.96;
      final bar = interp(per, 0, 100, barBottom, barTop);

      // same rule for every exercise now (the biceps used AiTrainer.py's first
      // version: half a rep at 0% and at 100%, no time limit - that is what
      // counted ~10 reps while walking into the picture)
      // down: must reach 100%
      if (per >= 100 && dir == 0) dir = 1;
      // up: must come back to 0%, and at least 1 second since the last rep
      if (per <= 0 && dir == 1) {
        if (now() - lastRepTime > 1) {
          count += 1;
          lastRepTime = now();
        }
        dir = 0;
      }

      hud.rectangle(barX1, barTop, barX2, barBottom, green, 3 * k);
      hud.rectangle(barX1, bar, barX2, barBottom, green, filled);
      if (e.oneSide) {
        hud.putText('${per.toInt()}', w * 450 / 640, h * 70 / 480, 3 * k, blue, 3);
        hud.putText('${count.toInt()}', 10, h * 450 / 480, 3 * k, blue, 3);
      } else {
        hud.putText('${per.toInt()}%', barX1 - 40 * k, barTop - 20 * k, 2 * k, blue, 3);
        hud.putText('${count.toInt()}', 20, h - 40 * k, 4 * k, blue, 5);
      }
    }

    ctime = now();
    final fps = 1 / (ctime - ptime);
    ptime = ctime;
    hud.putText('${fps.toInt()}', 10, 70 * k, 2 * k, magenta, 3);
  }

  @override
  void dispose() {
    detector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      CameraView(title: widget.exercise.name, onFrame: onFrame);
}
