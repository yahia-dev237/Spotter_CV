import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:ai_trainer/core/camera/camera_frame.dart';
import 'package:ai_trainer/core/error/failure.dart';
import 'package:ai_trainer/core/usecases/usecase.dart';
import 'package:ai_trainer/core/utils/cv_math.dart';
import 'package:ai_trainer/features/pose_coaching/domain/engine/coaching_session.dart';
import 'package:ai_trainer/features/pose_coaching/domain/entities/posture_assessment.dart';
import 'package:ai_trainer/features/pose_coaching/domain/repositories/i_pose_estimator.dart';

class PoseParams extends Equatable {
  final CameraFrame frame;
  final CoachingSession session; // the workout this frame belongs to

  const PoseParams({required this.frame, required this.session});

  @override
  List<Object?> get props => [frame, session];
}

// class diagram 2 Pose Coaching: ProcessPoseFrameUseCase.
// One frame of the trainer loop: find the pose, then count reps and check form.
class ProcessPoseFrameUseCase implements UseCase<PostureAssessment, PoseParams> {
  IPoseEstimator poseEstimator;
  ProcessPoseFrameUseCase({required this.poseEstimator});

  @override
  Future<Either<Failure, PostureAssessment>> call(PoseParams params) async {
    final res = await poseEstimator.detect(params.frame);
    return res.map((pose) {
      final t = now();
      params.session.update(pose, t);
      return params.session.assessment(t);
    });
  }

  Future<void> dispose() => poseEstimator.close();
}
