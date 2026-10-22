import 'package:ai_trainer/features/pose_coaching/domain/engine/form_evaluation.dart';
import 'package:ai_trainer/features/pose_coaching/domain/engine/pose_geometry.dart';

/// stance width (ankles / shoulders) and knee cave: only meaningful facing the camera.
/// Shared by the squat and the deadlift.
void frontLegChecks(
  FormEvaluation ev,
  PoseGeometry g,
  double per, {
  required double stanceMin,
  required double stanceMax,
  required double caveLimit,
  required bool caveBlocks,
  double? caveBlockAt,
}) {
  final a1 = g.p(27), a2 = g.p(28), s1 = g.p(11), s2 = g.p(12);
  if (a1 != null && a2 != null && s1 != null && s2 != null && g.vis([27, 28])) {
    final sw = (s1 - s2).distance;
    if (sw > 1) {
      final ratio = (a1 - a2).distance / sw;
      ev.limit(stanceMin - ratio, 0.3, 'Stance too narrow');
      ev.limit(ratio - stanceMax, 0.5, 'Stance too wide');
    }
  }
  final cave = g.kneeCave();
  if (cave != null) {
    ev.limit(per >= 30 ? cave - caveLimit : -1, 0.2, 'Knees caving in',
        block: caveBlocks, blockAt: caveBlockAt);
  }
}
