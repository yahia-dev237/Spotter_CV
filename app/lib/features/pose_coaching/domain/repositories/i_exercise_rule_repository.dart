import 'package:dartz/dartz.dart';
import 'package:ai_trainer/core/error/failure.dart';
import 'package:ai_trainer/features/pose_coaching/domain/entities/exercise_rule_set.dart';

// class diagram 2 Pose Coaching: IExerciseRuleRepository (exercises/{exerciseId})
abstract class IExerciseRuleRepository {
  Future<Either<Failure, ExerciseRuleSet>> getRuleSet(String exerciseId);

  /// every exercise of the database, including the ones without camera tracking
  Future<Either<Failure, List<ExerciseRuleSet>>> getRuleSets();
}
