import 'package:dartz/dartz.dart';
import 'package:ai_trainer/core/error/failure.dart';
import 'package:ai_trainer/core/usecases/usecase.dart';
import 'package:ai_trainer/features/pose_coaching/domain/entities/exercise_rule_set.dart';
import 'package:ai_trainer/features/pose_coaching/domain/repositories/i_exercise_rule_repository.dart';

// every exercise of the database (the camera menu shows the ones with hasCvEngine)
class GetExerciseRuleSetsUseCase implements UseCase<List<ExerciseRuleSet>, NoParams> {
  IExerciseRuleRepository exerciseRuleRepository;
  GetExerciseRuleSetsUseCase({required this.exerciseRuleRepository});

  @override
  Future<Either<Failure, List<ExerciseRuleSet>>> call(NoParams params) =>
      exerciseRuleRepository.getRuleSets();
}
