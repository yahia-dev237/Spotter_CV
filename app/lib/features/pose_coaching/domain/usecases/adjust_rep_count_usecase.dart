import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:ai_trainer/core/error/failure.dart';
import 'package:ai_trainer/core/usecases/usecase.dart';
import 'package:ai_trainer/core/utils/cv_math.dart';
import 'package:ai_trainer/features/pose_coaching/domain/engine/coaching_session.dart';
import 'package:ai_trainer/features/pose_coaching/domain/entities/posture_assessment.dart';

class AdjustRepParams extends Equatable {
  final CoachingSession session;
  final int delta; // +1 or -1

  const AdjustRepParams({required this.session, required this.delta});

  @override
  List<Object?> get props => [session, delta];
}

// +1 / -1 buttons: fix a rep the camera missed or added
class AdjustRepCountUseCase implements UseCase<PostureAssessment, AdjustRepParams> {
  @override
  Future<Either<Failure, PostureAssessment>> call(AdjustRepParams params) async {
    params.session.adjustRep(params.delta, now());
    return Right(params.session.assessment(now()));
  }
}
