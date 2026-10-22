import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:ai_trainer/core/error/exception.dart';
import 'package:ai_trainer/features/pose_coaching/data/models/exercise_rule_set_model.dart';

// the exercise database bundled with the app (assets/data/exercises.json), so the
// trainer works offline and before the remote database is connected
abstract class ExerciseLocalDataSource {
  /// throws [CacheException]
  Future<List<ExerciseRuleSetModel>> getRuleSets();
}

class ExerciseLocalDataSourceImpl implements ExerciseLocalDataSource {
  static const assetPath = 'assets/data/exercises.json';

  AssetBundle assetBundle;
  ExerciseLocalDataSourceImpl({required this.assetBundle});

  List<ExerciseRuleSetModel>? _cache;

  @override
  Future<List<ExerciseRuleSetModel>> getRuleSets() async {
    final cached = _cache;
    if (cached != null) return cached;
    try {
      final text = await assetBundle.loadString(assetPath);
      final list = (jsonDecode(text) as List)
          .map((e) => ExerciseRuleSetModel.fromJson(e as Map<String, dynamic>))
          .toList();
      return _cache = list;
    } catch (_) {
      throw CacheException(code: 'exercises-unreadable');
    }
  }
}
