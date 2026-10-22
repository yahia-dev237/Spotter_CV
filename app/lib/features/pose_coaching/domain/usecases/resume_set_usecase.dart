import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:ai_trainer/core/error/failure.dart';
import 'package:ai_trainer/core/usecases/usecase.dart';
import 'package:ai_trainer/core/utils/cv_math.dart';
import 'package:ai_trainer/features/pose_coaching/domain/engine/coaching_session.dart';
import 'package:ai_trainer/features/pose_coaching/domain/entities/posture_assessment.dart';

class ResumeSetParams extends Equatable {
  final CoachingSession session;
  final double restedSeconds; // not counted in the set time

  const ResumeSetParams({required this.session, required this.restedSeconds});

  @override
  List<Object?> get props => [session, restedSeconds];
}

// Stop timer: back to the camera, still in the same set
class ResumeSetUseCase implements UseCase<PostureAssessment, ResumeSetParams> {
  @override
  Future<Either<Failure, PostureAssessment>> call(ResumeSetParams params) async {
    params.session.resumeSet(params.restedSeconds);
    return Right(params.session.assessment(now()));
  }
}
