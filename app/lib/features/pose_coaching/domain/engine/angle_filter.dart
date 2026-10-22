import 'dart:math' as math;

/// turns the raw joint angle of each frame into a clean, smoothed angle and its speed
class AngleFilter {
  static const maxJumpDeg = 70.0; // angle jump per frame that is a tracking glitch

  // the python code ran at about 15 fps; "0.7*old + 0.3*new" every frame is made
  // to react the same in seconds at any fps (a 35 fps phone would otherwise react
  // more than twice as fast and let jumpy frames through)
  static const pythonFps = 15.0;

  double? smoothAngle;
  double lastSmoothTime = 0;
  double? prevRaw;
  int jumpRejects = 0;
  double? prevSmooth;
  double lastSpeedTime = 0;
  double speed = 0; // smoothed angular speed, deg/s

  /// make the angle 0-180 no matter which way you face the camera
  static double fold(double angle) => angle > 180 ? 360 - angle : angle;

  /// bad numbers (NaN) and one-frame tracking glitches must not move the angle
  double clean(double a, double upAngle) {
    final pr = prevRaw;
    if (!a.isFinite) {
      a = pr ?? upAngle;
    } else if (pr != null && (a - pr).abs() > maxJumpDeg && jumpRejects < 2) {
      jumpRejects++;
      a = pr;
    } else {
      jumpRejects = 0;
    }
    prevRaw = a;
    return a;
  }

  /// smooth the angle so one jumpy frame can't change it much
  double smooth(double angle, double t, {required bool perFrame}) {
    if (perFrame) {
      smoothAngle ??= angle;
      return smoothAngle = 0.7 * smoothAngle! + 0.3 * angle;
    }
    final dt = (t - lastSmoothTime).clamp(0.0, 1.0);
    lastSmoothTime = t;
    if (smoothAngle == null) return smoothAngle = angle;
    final keep = math.pow(0.7, dt * pythonFps).toDouble();
    return smoothAngle = keep * smoothAngle! + (1 - keep) * angle;
  }

  /// angular speed (smoothed): too fast = jerky / momentum
  void updateSpeed(double smoothed, double t) {
    final dtS = (t - lastSpeedTime).clamp(0.001, 1.0).toDouble();
    speed = 0.8 * speed + 0.2 * ((smoothed - (prevSmooth ?? smoothed)).abs() / dtS);
    prevSmooth = smoothed;
    lastSpeedTime = t;
  }

  /// forget the angle history (person lost, or the other arm is next)
  void resetHistory() {
    smoothAngle = null;
    prevRaw = null;
    prevSmooth = null;
    jumpRejects = 0;
    speed = 0;
  }
}
