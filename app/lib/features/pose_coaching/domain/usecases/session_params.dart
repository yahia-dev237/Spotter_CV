import 'package:equatable/equatable.dart';
import 'package:ai_trainer/features/pose_coaching/domain/engine/coaching_session.dart';

// Params of the set commands (EndSet, StartNextSet, ResetTracking, ToggleLyingCheck)
class SessionParams extends Equatable {
  final CoachingSession session;

  const SessionParams({required this.session});

  @override
  List<Object?> get props => [session];
}
