import 'package:ai_trainer/features/pose_coaching/data/models/exercise_rule_set_model.dart';

// The remote exercise database (Firestore collection
// ExerciseRuleSetModel.collection = 'exercises', one document per exerciseId,
// same shape as assets/data/exercises.json).
//
// Not implemented yet. To connect it, write ExerciseRemoteDataSourceImpl
// (FirebaseFirestore) that reads the collection with ExerciseRuleSetModel.fromJson
// and throws ServerException on errors, then register it in injection_container.dart:
// ExerciseRuleRepositoryImpl then uses it first and falls back to the bundled file.
// The exercise CRUD (create / update / delete with ExerciseRuleSetModel.toJson)
// will be added here too.
abstract class ExerciseRemoteDataSource {
  /// throws [ServerException]
  Future<List<ExerciseRuleSetModel>> getRuleSets();

  /// throws [ServerException]
  Future<ExerciseRuleSetModel> getRuleSet(String exerciseId);
}
