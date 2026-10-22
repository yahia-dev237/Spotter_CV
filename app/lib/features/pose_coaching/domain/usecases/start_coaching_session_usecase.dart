import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:ai_trainer/core/error/exception_handler.dart';
import 'package:ai_trainer/core/error/failure.dart';
import 'package:ai_trainer/core/usecases/usecase.dart';
import 'package:ai_trainer/features/pose_coaching/domain/engine/coaching_session.dart';
import 'package:ai_trainer/features/pose_coaching/domain/repositories/i_exercise_rule_repository.dart';

class ExerciseIdParams extends Equatable {
  final String exerciseId;

  const ExerciseIdParams({required this.exerciseId});

  @override
  List<Object?> get props => [exerciseId];
}

// SetStarted: load the exercise's rules from the database and start counting
class StartCoachingSessionUseCase implements UseCase<CoachingSession, ExerciseIdParams> {
  IExerciseRuleRepository exerciseRuleRepository;
  StartCoachingSessionUseCase({required this.exerciseRuleRepository});

  @override
  Future<Either<Failure, CoachingSession>> call(ExerciseIdParams params) async {
    final res = await exerciseRuleRepository.getRuleSet(params.exerciseId);
    return res.flatMap((ruleSet) {
      final session = CoachingSession.create(ruleSet);
      if (session == null) {
        return Left(PoseFailure(message: ExceptionHandler.poseExceptionHandler('no-cv-engine')));
      }
      return Right(session);
    });
  }
}
