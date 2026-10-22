import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:ai_trainer/features/pose_coaching/data/models/exercise_rule_set_model.dart';
import 'package:ai_trainer/features/pose_coaching/domain/engine/coaching_session.dart';
import 'package:ai_trainer/features/pose_coaching/domain/entities/body_landmark.dart';
import 'package:ai_trainer/features/pose_coaching/domain/entities/exercise_rule_set.dart';
import 'package:ai_trainer/features/pose_coaching/domain/entities/pose_frame.dart';

/// the exercise database bundled with the app
List<dynamic> readDatabaseJson() => jsonDecode(File('assets/data/exercises.json').readAsStringSync()) as List;

List<ExerciseRuleSet> loadDatabase() =>
    readDatabaseJson().map((e) => ExerciseRuleSetModel.fromJson(e as Map<String, dynamic>)).toList();

ExerciseRuleSet ruleSet(String id) => loadDatabase().firstWhere((e) => e.exerciseId == id);

/// a person filmed from the side with the right elbow bent to [elbowDeg]
PoseFrame sideCurl(double elbowDeg) {
  const shoulder = (300.0, 200.0), elbow = (300.0, 300.0), hip = (300.0, 400.0);
  final r = elbowDeg * math.pi / 180;
  // the forearm makes [elbowDeg] with the upper arm (which points up to the shoulder)
  final wrist = (elbow.$1 + 100 * math.sin(r), elbow.$2 - 100 * math.cos(r));
  final pts = <int, (double, double)>{
    11: (310, 200), 12: shoulder, 13: (310, 300), 14: elbow, 15: (310, 390), 16: wrist,
    23: (310, 400), 24: hip, 25: (310, 500), 26: (300, 500), 27: (310, 600), 28: (300, 600),
  };
  return PoseFrame(
    landmarks: [
      for (var id = 0; id < 33; id++)
        BodyLandmark(
          id: id,
          x: (pts[id] ?? (300.0, 150.0)).$1,
          y: (pts[id] ?? (300.0, 150.0)).$2,
          z: 0,
          likelihood: 0.99,
        ),
    ],
    timestamp: DateTime(2026),
  );
}

void main() {
  group('exercise database', () {
    test('every exercise parses, and only the tracked ones have a CV engine', () {
      final all = loadDatabase();
      expect(all.map((e) => e.exerciseId),
          ['squat', 'deadlift', 'bench_press', 'overhead_press', 'barbell_row', 'biceps_curl']);
      expect(all.where((e) => e.hasCvEngine).map((e) => e.exerciseId),
          ['squat', 'deadlift', 'bench_press', 'biceps_curl']);
      for (final e in all) {
        expect(CoachingSession.create(e) != null, e.hasCvEngine, reason: e.exerciseId);
      }
    });

    test('thresholds are read from the database', () {
      final curl = ruleSet('biceps_curl');
      expect(curl.repThresholds!.lowerDeg, 64);
      expect(curl.rule('elbow_drift')!.rejectThreshold, 55);
      final squat = ruleSet('squat');
      expect(squat.repThresholds!.perFrameSmoothing, isTrue);
      expect(squat.repThresholds!.depthClasses!.partial.countsAsRep, isTrue);
      expect(ruleSet('deadlift').repThresholds!.bottomReachedBarPct!.side, 90);
      expect(ruleSet('squat').cues['knee_valgus']!.en, isNotEmpty);
    });

    test('toJson writes back the same document (for the exercise CRUD)', () {
      for (final raw in readDatabaseJson()) {
        final json = raw as Map<String, dynamic>;
        final model = ExerciseRuleSetModel.fromJson(json);
        final again = ExerciseRuleSetModel.fromJson(model.toJson());
        expect(again, model, reason: json['exerciseId'] as String);
      }
    });
  });

  group('coaching session', () {
    late CoachingSession session;
    var t = 0.0;
    void hold(double deg, double secs) {
      for (var i = 0; i < secs * 30; i++) {
        session.update(sideCurl(deg), t += 1 / 30);
      }
    }

    void move(double from, double to, double secs) {
      final n = (secs * 30).round();
      for (var i = 1; i <= n; i++) {
        session.update(sideCurl(from + (to - from) * i / n), t += 1 / 30);
      }
    }

    setUp(() {
      session = CoachingSession.create(ruleSet('biceps_curl'))!;
      t = 0;
    });

    test('biceps curl: three full reps are counted and form a set', () {
      hold(170, 1);
      for (var rep = 0; rep < 3; rep++) {
        move(170, 40, 1);
        hold(40, 0.6); // the bottom must be held (holdSeconds) after the smoothing catches up
        move(40, 170, 1);
        hold(170, 1);
      }
      final a = session.assessment(t);
      expect(a.reps, 3);
      expect(a.sets.setReps, 3);
      expect(a.sets.inSet, isTrue);
      expect(a.feedback.title, 'Good rep');
      expect(a.sets.fatigue, isNotNull);
      expect(a.arms!.repsRight, 3);

      session.endSet();
      expect(session.assessment(t).sets.lastSetReps, 3);
      session.nextSet();
      final next = session.assessment(t);
      expect(next.sets.setNumber, 2);
      expect(next.sets.setReps, 0);
    });

    test('a half curl is reported as incomplete and not counted', () {
      hold(170, 1);
      move(170, 100, 1); // bottom is 64 degrees in the database: 100 is only part way
      move(100, 170, 2);
      hold(170, 1);
      final a = session.assessment(t);
      expect(a.reps, 0);
      expect(a.feedback.title, 'Incomplete rep');
    });

    test('+1 / -1 buttons change the reps and the arm count', () {
      session.adjustRep(1, 1);
      session.adjustRep(1, 2);
      session.adjustRep(-1, 3);
      final a = session.assessment(3);
      expect(a.reps, 1);
      expect(a.sets.setReps, 1);
      expect(a.arms!.repsRight, 1);
    });

    test('changing the arm starts counting again', () {
      session.adjustRep(1, 1);
      expect(session.setArmMode(2), isTrue);
      final a = session.assessment(2);
      expect(a.reps, 0);
      expect(a.arms!.mode, 2);
    });

    test('nobody in the picture: nothing is tracked', () {
      session.update(PoseFrame.empty(DateTime(2026)), 1);
      final a = session.assessment(1);
      expect(a.isTracking, isFalse);
      expect(a.reps, 0);
    });
  });
}
