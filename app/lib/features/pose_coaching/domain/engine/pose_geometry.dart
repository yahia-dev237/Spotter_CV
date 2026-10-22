import 'dart:math' as math;

import 'package:ai_trainer/features/pose_coaching/domain/entities/pose_frame.dart';
import 'package:ai_trainer/features/pose_coaching/domain/entities/vec2.dart';

/// geometry on one detected pose: landmark points, angles and view checks
class PoseGeometry {
  PoseGeometry(this.pose);

  final PoseFrame pose;

  // shoulder width / torso length above this = facing the camera
  static const frontalRatio = 0.5;

  bool vis(List<int> ids) => pose.isVisible(ids);

  /// landmark [id] in whole pixels (like lmList = [id, cx, cy]), null when nobody is seen
  Vec2? p(int id) {
    if (!pose.hasPerson) return null;
    final q = pose.landmark(id);
    return Vec2(q.x.toInt().toDouble(), q.y.toInt().toDouble());
  }

  /// middle of two landmarks, using only the visible ones
  Vec2? mid(int a, int b) {
    final pts = <Vec2>[];
    for (final id in [a, b]) {
      final q = p(id);
      if (q != null && vis([id])) pts.add(q);
    }
    if (pts.isEmpty) return null;
    return pts.length == 1 ? pts[0] : (pts[0] + pts[1]) / 2;
  }

  /// angle at [b] in degrees (0-180)
  static double ang(Vec2 a, Vec2 b, Vec2 c) {
    final v1 = a - b, v2 = c - b;
    final d = v1.distance * v2.distance;
    if (d < 1e-6) return double.nan;
    final c0 = ((v1.dx * v2.dx + v1.dy * v2.dy) / d).clamp(-1.0, 1.0).toDouble();
    return math.acos(c0) * 180 / math.pi;
  }

  /// how far the line from->to is tilted away from vertical (0 = straight up/down)
  static double fromVertical(Vec2 from, Vec2 to) =>
      math.atan2((to.dx - from.dx).abs(), (to.dy - from.dy).abs()) * 180 / math.pi;

  /// PoseModule.findAngle: whole pixels like lmList, 0-360 degrees
  double findAngle(List<int> joints) {
    final p1 = pose.landmark(joints[0]), p2 = pose.landmark(joints[1]), p3 = pose.landmark(joints[2]);
    final x1 = p1.x.toInt(), y1 = p1.y.toInt();
    final x2 = p2.x.toInt(), y2 = p2.y.toInt();
    final x3 = p3.x.toInt(), y3 = p3.y.toInt();
    var angle = (math.atan2(y3 - y2, x3 - x2) - math.atan2(y1 - y2, x1 - x2)) * 180 / math.pi;
    if (angle < 0) angle += 360;
    return angle;
  }

  /// true = facing the camera (shoulders wide), false = side on, null = unknown
  bool? frontal() {
    final a = p(11), b = p(12), c = p(23), d = p(24);
    if (a == null || b == null || c == null || d == null || !vis([11, 12, 23, 24])) {
      return null;
    }
    final tl = ((a + b) / 2 - (c + d) / 2).distance;
    if (tl < 1) return null;
    return (a - b).distance / tl > frontalRatio;
  }

  /// how far the worst knee is inside its toes (0 = over the toes), as a fraction
  /// of shin length. Uses the toe, so a deliberate toe-out stance is not punished.
  double? kneeCave() {
    final h1 = p(23), h2 = p(24);
    if (h1 == null || h2 == null) return null;
    final mx = (h1.dx + h2.dx) / 2;
    double? worst;
    for (final s in const [
      [25, 27, 31],
      [26, 28, 32]
    ]) {
      if (!vis([s[0], s[1]])) continue;
      final kn = p(s[0]), an = p(s[1]), toe = p(s[2]);
      if (kn == null || an == null) continue;
      final Vec2 ft = (toe != null && vis([s[2]])) ? toe : an;
      final shin = (kn - an).distance;
      if (shin < 1) continue;
      final inward = ((mx - ft.dx).abs() - (mx - kn.dx).abs()) / shin;
      worst = worst == null ? inward : math.max(worst, inward);
    }
    return worst;
  }
}
