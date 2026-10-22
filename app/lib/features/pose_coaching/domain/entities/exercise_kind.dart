/// the exercises the CV engine can track (exercises/{exerciseId}.exerciseId)
enum ExerciseKind {
  bicepsCurl('biceps_curl'),
  squat('squat'),
  deadlift('deadlift'),
  benchPress('bench_press');

  const ExerciseKind(this.exerciseId);
  final String exerciseId;

  /// null = the camera has no engine for this exercise
  static ExerciseKind? fromId(String exerciseId) {
    for (final k in ExerciseKind.values) {
      if (k.exerciseId == exerciseId) return k;
    }
    return null;
  }
}
