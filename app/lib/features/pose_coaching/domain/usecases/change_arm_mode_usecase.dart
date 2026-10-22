import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:ai_trainer/core/error/failure.dart';
import 'package:ai_trainer/core/usecases/usecase.dart';
import 'package:ai_trainer/core/utils/cv_math.dart';
import 'package:ai_trainer/features/pose_coaching/domain/engine/coaching_session.dart';
import 'package:ai_trainer/features/pose_coaching/domain/entities/posture_assessment.dart';

class ArmModeParams extends Equatable {
  final CoachingSession session;
  // 0 right, 1 left, 2 both, 3 alternate starting right, 4 alternate starting left
  final int armMode;

  const ArmModeParams({required this.session, required this.armMode});

  @override
  List<Object?> get props => [session, armMode];
}

// biceps curl arm menu: counting starts again from 0 with the new arm(s)
class ChangeArmModeUseCase implements UseCase<PostureAssessment, ArmModeParams> {
  @override
  Future<Either<Failure, PostureAssessment>> call(ArmModeParams params) async {
    params.session.setArmMode(params.armMode);
    return Right(params.session.assessment(now()));
  }
}
