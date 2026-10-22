import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:ai_trainer/core/usecases/usecase.dart';
import 'package:ai_trainer/features/pose_coaching/domain/entities/exercise_rule_set.dart';
import 'package:ai_trainer/features/pose_coaching/domain/usecases/get_exercise_rule_sets_usecase.dart';

part 'exercise_menu_state.dart';

// Main.py: choose your training (the exercises come from the database)
class ExerciseMenuCubit extends Cubit<ExerciseMenuState> {
  GetExerciseRuleSetsUseCase getExercises;

  ExerciseMenuCubit({required this.getExercises}) : super(ExerciseMenuLoading());

  Future<void> load() async {
    final res = await getExercises(NoParams());
    res.fold(
      (failure) => emit(ExerciseMenuError(message: failure.message)),
      // overhead press, barbell row...: no camera tracking, they can only be logged in a workout
      (exercises) => emit(ExerciseMenuLoaded(exercises: exercises.where((e) => e.hasCvEngine).toList())),
    );
  }
}
