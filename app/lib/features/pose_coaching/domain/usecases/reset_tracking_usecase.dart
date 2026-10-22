import 'package:dartz/dartz.dart';
import 'package:ai_trainer/core/error/failure.dart';
import 'package:ai_trainer/core/usecases/usecase.dart';
import 'package:ai_trainer/core/utils/cv_math.dart';
import 'package:ai_trainer/features/pose_coaching/domain/entities/posture_assessment.dart';
import 'package:ai_trainer/features/pose_coaching/domain/usecases/session_params.dart';

// after the 3-2-1 countdown: fresh start posture, no half-finished rep
class ResetTrackingUseCase implements UseCase<PostureAssessment, SessionParams> {
  @override
  Future<Either<Failure, PostureAssessment>> call(SessionParams params) async {
    params.session.resetTracking();
    return Right(params.session.assessment(now()));
  }
}
