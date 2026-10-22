import 'dart:async';
import 'dart:math' as math;

import 'package:bloc/bloc.dart';
import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:ai_trainer/core/camera/camera_frame.dart';
import 'package:ai_trainer/core/camera/frame_throttle.dart';
import 'package:ai_trainer/core/error/failure.dart';
import 'package:ai_trainer/core/utils/cv_math.dart';
import 'package:ai_trainer/features/pose_coaching/domain/engine/coaching_session.dart';
import 'package:ai_trainer/features/pose_coaching/domain/entities/posture_assessment.dart';
import 'package:ai_trainer/features/pose_coaching/domain/usecases/adjust_rep_count_usecase.dart';
import 'package:ai_trainer/features/pose_coaching/domain/usecases/change_arm_mode_usecase.dart';
import 'package:ai_trainer/features/pose_coaching/domain/usecases/end_set_usecase.dart';
import 'package:ai_trainer/features/pose_coaching/domain/usecases/process_pose_frame_usecase.dart';
import 'package:ai_trainer/features/pose_coaching/domain/usecases/reset_tracking_usecase.dart';
import 'package:ai_trainer/features/pose_coaching/domain/usecases/resume_set_usecase.dart';
import 'package:ai_trainer/features/pose_coaching/domain/usecases/session_params.dart';
import 'package:ai_trainer/features/pose_coaching/domain/usecases/start_coaching_session_usecase.dart';
import 'package:ai_trainer/features/pose_coaching/domain/usecases/start_next_set_usecase.dart';
import 'package:ai_trainer/features/pose_coaching/domain/usecases/toggle_lying_check_usecase.dart';

part 'trainer_event.dart';
part 'trainer_state.dart';

// the trainer screen: camera frames -> reps and form, plus sets, rest timer and
// the 3-2-1 countdown (the USER ends a set, no automatic set detection).
// The workout itself (CoachingSession) lives in the domain; the bloc only calls
// use cases and shows the PostureAssessment they return.
class TrainerBloc extends Bloc<TrainerEvent, TrainerState> {
  StartCoachingSessionUseCase startCoachingSession;
  ProcessPoseFrameUseCase processPoseFrame;
  AdjustRepCountUseCase adjustRepCount;
  EndSetUseCase endSet;
  ResumeSetUseCase resumeSet;
  StartNextSetUseCase startNextSet;
  ResetTrackingUseCase resetTracking;
  ChangeArmModeUseCase changeArmMode;
  ToggleLyingCheckUseCase toggleLyingCheck;

  static const maxExtensions = 2; // the rest can be extended only 2 times
  static const readySeconds = 3;
  static const minRestSeconds = 5.0;
  static const maxRestSeconds = 600.0; // 10 minutes

  CoachingSession? _session;
  final _throttle = FrameThrottle();
  Timer? _ticker;
  double ptime = 0;
  double _lastUi = 0;
  int _lastBeepSec = -1;

  TrainerBloc({
    required this.startCoachingSession,
    required this.processPoseFrame,
    required this.adjustRepCount,
    required this.endSet,
    required this.resumeSet,
    required this.startNextSet,
    required this.resetTracking,
    required this.changeArmMode,
    required this.toggleLyingCheck,
  }) : super(const TrainerState()) {
    on<TrainerStarted>((event, emit) async {
      final res = await startCoachingSession(ExerciseIdParams(exerciseId: event.exerciseId));
      if (isClosed) return;
      res.fold(
        (failure) => emit(state.copyWith(errorMessage: failure.message)),
        (session) {
          _session = session;
          _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) => add(TrainerTicked()));
          emit(state.copyWith(assessment: session.assessment(now()), panelVersion: state.panelVersion + 1));
        },
      );
    });

    on<TrainerFrameReceived>((event, emit) async {
      // rest screen / get-ready: nothing is counted, tracked or drawn
      if (_session == null || state.paused) return;
      await _throttle.run(event.frame, (frame) async {
        final session = _session!;
        if (state.paused) return;
        final res = await processPoseFrame(PoseParams(frame: frame, session: session));
        if (isClosed) return;
        res.fold((failure) => debugPrint('frame error: ${failure.message}'), (assessment) {
          final ctime = now();
          final dtFrame = ctime - ptime;
          final fps = dtFrame > 0 ? 1 / dtFrame : 0.0;
          ptime = ctime;
          // redraw the panel under the camera (about 12 times a second is enough)
          var panel = state.panelVersion;
          if (ctime - _lastUi > 0.08) {
            _lastUi = ctime;
            panel++;
          }
          emit(state.copyWith(
            assessment: assessment,
            imageWidth: frame.uprightWidth,
            imageHeight: frame.uprightHeight,
            isMirrored: frame.isFrontCamera,
            fps: fps,
            frameNumber: state.frameNumber + 1,
            panelVersion: panel,
          ));
        });
      }, isClosed: () => isClosed);
    });

    on<TrainerTicked>(_onTick);

    on<ArmModeChanged>((event, emit) async {
      final session = _session;
      if (session == null || state.assessment?.arms?.mode == event.armMode) return;
      final res = await changeArmMode(ArmModeParams(session: session, armMode: event.armMode));
      _emitAssessment(emit, res,
          (s) => s.copyWith(phase: WorkoutPhase.active, restFinished: false, extraUsed: 0));
    });

    on<LyingCheckToggled>((event, emit) async {
      final session = _session;
      if (session == null) return;
      _emitAssessment(emit, await toggleLyingCheck(SessionParams(session: session)), (s) => s);
    });

    on<RepAdjusted>((event, emit) async {
      final session = _session;
      if (session == null) return;
      _emitAssessment(emit, await adjustRepCount(AdjustRepParams(session: session, delta: event.delta)), (s) => s);
    });

    on<SetFinished>((event, emit) async {
      final session = _session;
      if (session == null || (state.assessment?.sets.setReps ?? 0) == 0) return;
      _emitAssessment(emit, await endSet(SessionParams(session: session)), _startRest);
    });

    on<RestStopped>((event, emit) async {
      final session = _session;
      if (session == null) return;
      final elapsed = (_nowMs() - state.restStartMs) / 1000.0;
      final res = await resumeSet(ResumeSetParams(session: session, restedSeconds: elapsed));
      _emitAssessment(emit, res, (s) => s.copyWith(phase: WorkoutPhase.active, restFinished: false));
    });

    on<NextSetStarted>((event, emit) async {
      final session = _session;
      if (session == null || !state.resting) return;
      final res = await startNextSet(SessionParams(session: session));
      _emitAssessment(emit, res, (s) => _startGetReady(s.copyWith(restFinished: false)));
    });

    on<RestExtended>((event, emit) {
      if (!state.resting) return;
      emit(_armRest(
        state.copyWith(extraUsed: state.extraUsed + 1, restFinished: false),
        (state.restSeconds * 1000).round(),
      ));
    });

    on<GetReadySkipped>((event, emit) => _endGetReady(emit));

    on<RestTimeChanged>((event, emit) async {
      final s = state.copyWith(restSeconds: event.seconds, panelVersion: state.panelVersion + 1);
      final session = _session;
      if (event.startRest && !s.paused && session != null && (s.assessment?.sets.setReps ?? 0) > 0) {
        emit(s);
        _emitAssessment(emit, await endSet(SessionParams(session: session)), _startRest);
      } else if (!event.startRest && s.resting) {
        // Save & restart: the countdown starts again with the new time at once
        emit(_armRest(s, (event.seconds * 1000).round()));
      } else {
        emit(s);
      }
    });
  }

  /// emits the assessment a set command returned, with [then] applied to the state
  void _emitAssessment(
    Emitter<TrainerState> emit,
    Either<Failure, PostureAssessment> res,
    TrainerState Function(TrainerState s) then,
  ) {
    if (isClosed) return;
    res.fold(
      (failure) => debugPrint('trainer error: ${failure.message}'),
      (assessment) => emit(then(state.copyWith(assessment: assessment, panelVersion: state.panelVersion + 1))),
    );
  }

  int _nowMs() => DateTime.now().millisecondsSinceEpoch;

  TrainerState _armRest(TrainerState s, int ms) {
    _lastBeepSec = -1;
    return s.copyWith(restEndMs: _nowMs() + ms, restTotalMs: math.max(ms, 1));
  }

  /// starts the rest screen (the set was ended by EndSetUseCase)
  TrainerState _startRest(TrainerState s) => _armRest(
    s.copyWith(
      phase: WorkoutPhase.resting,
      extraUsed: 0,
      restFinished: false,
      restStartMs: _nowMs(),
    ),
    (s.restSeconds * 1000).round(),
  );

  TrainerState _startGetReady(TrainerState s) {
    _lastBeepSec = -1;
    return s.copyWith(phase: WorkoutPhase.getReady, readyEndMs: _nowMs() + readySeconds * 1000);
  }

  /// the countdown is over: back to the camera with a fresh start posture
  Future<void> _endGetReady(Emitter<TrainerState> emit) async {
    final session = _session;
    if (session == null) return;
    final res = await resetTracking(SessionParams(session: session));
    _emitAssessment(emit, res, (s) => s.copyWith(phase: WorkoutPhase.active));
  }

  Future<void> _onTick(TrainerTicked event, Emitter<TrainerState> emit) async {
    if (state.phase == WorkoutPhase.active) return;
    final n = _nowMs();
    if (state.resting) {
      if (state.restFinished) return;
      final left = state.restEndMs - n;
      if (left <= 0) {
        // the rest timer ran out: alert, then "Next set" or "More time" (max 2 times)
        emit(state.copyWith(restFinished: true));
        return;
      }
      final sec = (left / 1000).ceil();
      var beeps = state.beeps;
      if (sec <= 3 && sec != _lastBeepSec) {
        _lastBeepSec = sec; // short beep for the last 3 seconds
        beeps++;
      }
      emit(state.copyWith(beeps: beeps, tick: state.tick + 1));
    } else {
      final left = state.readyEndMs - n;
      if (left <= 0) {
        await _endGetReady(emit);
        return;
      }
      final sec = (left / 1000).ceil();
      var beeps = state.beeps;
      if (sec != _lastBeepSec) {
        _lastBeepSec = sec;
        beeps++;
      }
      emit(state.copyWith(beeps: beeps, tick: state.tick + 1));
    }
  }

  @override
  Future<void> close() async {
    _ticker?.cancel();
    await processPoseFrame.dispose();
    return super.close();
  }
}
