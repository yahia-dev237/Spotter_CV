import 'package:ai_trainer/features/pose_coaching/domain/engine/angle_filter.dart';
import 'package:ai_trainer/features/pose_coaching/domain/engine/pose_geometry.dart';
import 'package:ai_trainer/features/pose_coaching/domain/engine/posture_baseline.dart';
import 'package:ai_trainer/features/pose_coaching/domain/engine/rep_progress.dart';
import 'package:ai_trainer/features/pose_coaching/domain/engine/rule_book.dart';
import 'package:ai_trainer/features/pose_coaching/domain/engine/tracking_config.dart';
import 'package:ai_trainer/features/pose_coaching/domain/entities/pose_frame.dart';

/// what the coaching session and the exercise engine share: the pose of the
/// current frame, the user's baseline posture, the angle filter and the rep in progress
class CoachingContext {
  CoachingContext({required this.config, required this.rules});

  final TrackingConfig config; // as in the database (the curl arm menu changes the active one)
  final RuleBook rules;
  final baseline = PostureBaseline();
  final filter = AngleFilter();
  final rep = RepProgress();
  PoseGeometry geo = PoseGeometry(PoseFrame.empty(DateTime.fromMillisecondsSinceEpoch(0)));
  String? gateMsg; // red hint when the exercise position is wrong

  bool get idle => rep.idle;
}
