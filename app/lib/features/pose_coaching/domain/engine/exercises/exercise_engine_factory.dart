import 'package:ai_trainer/features/pose_coaching/domain/engine/coaching_context.dart';
import 'package:ai_trainer/features/pose_coaching/domain/engine/exercises/bench_engine.dart';
import 'package:ai_trainer/features/pose_coaching/domain/engine/exercises/curl_engine.dart';
import 'package:ai_trainer/features/pose_coaching/domain/engine/exercises/deadlift_engine.dart';
import 'package:ai_trainer/features/pose_coaching/domain/engine/exercises/exercise_engine.dart';
import 'package:ai_trainer/features/pose_coaching/domain/engine/exercises/squat_engine.dart';
import 'package:ai_trainer/features/pose_coaching/domain/entities/exercise_kind.dart';

/// the engine of each exercise; a new tracked exercise = a new ExerciseKind + engine here
ExerciseEngine createExerciseEngine(CoachingContext ctx) => switch (ctx.config.kind) {
  ExerciseKind.bicepsCurl => CurlEngine(ctx),
  ExerciseKind.squat => SquatEngine(ctx),
  ExerciseKind.deadlift => DeadliftEngine(ctx),
  ExerciseKind.benchPress => BenchEngine(ctx),
};
