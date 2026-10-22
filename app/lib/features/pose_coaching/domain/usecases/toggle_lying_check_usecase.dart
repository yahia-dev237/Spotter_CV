import 'package:dartz/dartz.dart';
import 'package:ai_trainer/core/error/failure.dart';
import 'package:ai_trainer/core/usecases/usecase.dart';
import 'package:ai_trainer/core/utils/cv_math.dart';
import 'package:ai_trainer/features/pose_coaching/domain/entities/posture_assessment.dart';
import 'package:ai_trainer/features/pose_coaching/domain/usecases/session_params.dart';

// bench press: the bed button turns the "must lie on the bench" check on / off
class ToggleLyingCheckUseCase implements UseCase<PostureAssessment, SessionParams> {
  @override
  Future<Either<Failure, PostureAssessment>> call(SessionParams params) async {
    params.session.toggleLyingCheck();
    return Right(params.session.assessment(now()));
  }
}
