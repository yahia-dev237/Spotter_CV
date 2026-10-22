import 'package:dartz/dartz.dart';
import 'package:ai_trainer/core/error/failure.dart';
import 'package:ai_trainer/core/usecases/usecase.dart';
import 'package:ai_trainer/core/utils/cv_math.dart';
import 'package:ai_trainer/features/pose_coaching/domain/entities/posture_assessment.dart';
import 'package:ai_trainer/features/pose_coaching/domain/usecases/session_params.dart';

// Finish set: the set ends (reps, time, form and fatigue are kept for the rest screen).
// The set summary for the workout log (BuildSetSummaryUseCase) will start from here.
class EndSetUseCase implements UseCase<PostureAssessment, SessionParams> {
  @override
  Future<Either<Failure, PostureAssessment>> call(SessionParams params) async {
    params.session.endSet();
    return Right(params.session.assessment(now()));
  }
}
