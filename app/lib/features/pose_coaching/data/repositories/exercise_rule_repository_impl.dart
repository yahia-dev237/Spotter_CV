import 'package:dartz/dartz.dart';
import 'package:ai_trainer/core/error/exception.dart';
import 'package:ai_trainer/core/error/exception_handler.dart';
import 'package:ai_trainer/core/error/failure.dart';
import 'package:ai_trainer/features/pose_coaching/data/datasources/exercise_local_data_source.dart';
import 'package:ai_trainer/features/pose_coaching/data/datasources/exercise_remote_data_source.dart';
import 'package:ai_trainer/features/pose_coaching/data/models/exercise_rule_set_model.dart';
import 'package:ai_trainer/features/pose_coaching/domain/entities/exercise_rule_set.dart';
import 'package:ai_trainer/features/pose_coaching/domain/repositories/i_exercise_rule_repository.dart';

// The remote database when it is connected, otherwise (or when it fails) the
// exercise file bundled with the app.
class ExerciseRuleRepositoryImpl implements IExerciseRuleRepository {
  // null until the remote database is connected (see ExerciseRemoteDataSource)
  ExerciseRemoteDataSource? exerciseRemoteDataSource;
  ExerciseLocalDataSource exerciseLocalDataSource;

  ExerciseRuleRepositoryImpl({
    this.exerciseRemoteDataSource,
    required this.exerciseLocalDataSource,
  });

  @override
  Future<Either<Failure, List<ExerciseRuleSet>>> getRuleSets() async {
    final remote = exerciseRemoteDataSource;
    if (remote != null) {
      try {
        return Right(await remote.getRuleSets());
      } on ServerException {
        // offline or not reachable: use the bundled exercises
      }
    }
    try {
      return Right(await exerciseLocalDataSource.getRuleSets());
    } on CacheException catch (e) {
      return Left(CacheFailure(message: ExceptionHandler.exerciseExceptionHandler(e.code)));
    }
  }

  @override
  Future<Either<Failure, ExerciseRuleSet>> getRuleSet(String exerciseId) async {
    final remote = exerciseRemoteDataSource;
    if (remote != null) {
      try {
        return Right(await remote.getRuleSet(exerciseId));
      } on ServerException {
        // offline or not reachable: use the bundled exercises
      }
    }
    try {
      final all = await exerciseLocalDataSource.getRuleSets();
      final ExerciseRuleSetModel? found =
          all.where((e) => e.exerciseId == exerciseId).firstOrNull;
      if (found == null) {
        return Left(CacheFailure(message: ExceptionHandler.exerciseExceptionHandler('exercise-not-found')));
      }
      return Right(found);
    } on CacheException catch (e) {
      return Left(CacheFailure(message: ExceptionHandler.exerciseExceptionHandler(e.code)));
    }
  }
}
