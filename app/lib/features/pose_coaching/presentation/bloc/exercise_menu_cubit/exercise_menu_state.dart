part of 'exercise_menu_cubit.dart';

sealed class ExerciseMenuState extends Equatable {
  const ExerciseMenuState();

  @override
  List<Object> get props => [];
}

final class ExerciseMenuLoading extends ExerciseMenuState {}

final class ExerciseMenuLoaded extends ExerciseMenuState {
  final List<ExerciseRuleSet> exercises;

  const ExerciseMenuLoaded({required this.exercises});

  @override
  List<Object> get props => [exercises];
}

final class ExerciseMenuError extends ExerciseMenuState {
  final String message;

  const ExerciseMenuError({required this.message});

  @override
  List<Object> get props => [message];
}
