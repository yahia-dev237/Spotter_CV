import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'package:ai_trainer/core/theme/app_theme.dart';
import 'package:ai_trainer/core/utils/cv_math.dart';
import 'package:ai_trainer/core/widgets/camera_view.dart';
import 'package:ai_trainer/core/widgets/overlay_canvas.dart';
import 'package:ai_trainer/core/widgets/spot_widgets.dart';
import 'package:ai_trainer/features/pose_coaching/domain/entities/exercise_kind.dart';
import 'package:ai_trainer/features/pose_coaching/domain/entities/exercise_rule_set.dart';
import 'package:ai_trainer/features/pose_coaching/domain/entities/posture_assessment.dart';
import 'package:ai_trainer/features/pose_coaching/presentation/bloc/trainer_bloc/trainer_bloc.dart';
import 'package:ai_trainer/features/pose_coaching/presentation/widgets/form_colors.dart';
import 'package:ai_trainer/features/pose_coaching/presentation/widgets/rest_overlay.dart';
import 'package:ai_trainer/features/pose_coaching/presentation/widgets/rest_timer_dialog.dart';
import 'package:ai_trainer/features/pose_coaching/presentation/widgets/trainer_overlay.dart';
import 'package:ai_trainer/features/pose_coaching/presentation/widgets/trainer_panel.dart';
import 'package:ai_trainer/injection_container.dart';

/// AiTrainer.py / SquatTrainer.py / DeadliftTrainer.py / BenchPressTrainer.py
class TrainerScreen extends StatelessWidget {
  const TrainerScreen({super.key, required this.ruleSet});
  final ExerciseRuleSet ruleSet;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<TrainerBloc>()..add(TrainerStarted(exerciseId: ruleSet.exerciseId)),
      child: _TrainerView(ruleSet: ruleSet),
    );
  }
}

class _TrainerView extends StatefulWidget {
  const _TrainerView({required this.ruleSet});
  final ExerciseRuleSet ruleSet;

  @override
  State<_TrainerView> createState() => _TrainerViewState();
}

class _TrainerViewState extends State<_TrainerView> with WidgetsBindingObserver {
  TrainerBloc get _bloc => context.read<TrainerBloc>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WakelockPlus.enable(); // the screen stays on during the whole workout
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    WakelockPlus.disable();
    super.dispose();
  }

  /// timers use the wall clock, so after a phone call / background trip they are still right
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _bloc.add(TrainerTicked());
  }

  void _beep() {
    SystemSound.play(SystemSoundType.click);
    HapticFeedback.selectionClick();
  }

  /// the rest is over: three long vibrations + system alert sound
  Future<void> _ringAlert() async {
    for (var i = 0; i < 3; i++) {
      SystemSound.play(SystemSoundType.alert);
      HapticFeedback.vibrate();
      await Future.delayed(const Duration(milliseconds: 450));
      if (!mounted) return;
    }
  }

  void _needARep() {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Do at least one counted rep first')));
  }

  /// Finish button: ends the set and opens the rest screen
  void _finishSet() {
    if ((_bloc.state.assessment?.sets.setReps ?? 0) == 0) {
      _needARep();
      return;
    }
    _bloc.add(SetFinished());
  }

  Future<void> _restSettings() async {
    final s = _bloc.state;
    final res = await showRestTimerDialog(context, restSeconds: s.restSeconds, resting: s.resting);
    if (!mounted || res == null) return;
    final now = _bloc.state;
    if (res.startRest && !now.paused && (now.assessment?.sets.setReps ?? 0) == 0) {
      _bloc.add(RestTimeChanged(seconds: res.seconds));
      _needARep();
      return;
    }
    _bloc.add(RestTimeChanged(seconds: res.seconds, startRest: res.startRest));
  }

  /// the rest timer ran out: alert, then "Next set" or "More time" (max 2 times)
  Future<void> _restDone(TrainerState state) async {
    _ringAlert();
    final setNumber = state.assessment!.sets.setNumber;
    final left = TrainerBloc.maxExtensions - state.extraUsed;
    final more = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (c) => PopScope(
        canPop: false,
        child: SpotDialog(
          title: 'Rest finished',
          content: Text(left > 0
              ? 'Ready for set ${setNumber + 1}? You can add more time ($left left).'
              : 'Ready for set ${setNumber + 1}? No more extra time.'),
          actions: [
            SpotButton('Next set ${setNumber + 1}',
                icon: Icons.play_arrow, onPressed: () => Navigator.pop(c, false)),
            if (left > 0)
              SpotButton('More time +${mmss(state.restSeconds)} · $left left',
                  icon: Icons.add, kind: SpotKind.secondary, onPressed: () => Navigator.pop(c, true)),
          ],
        ),
      ),
    );
    if (!mounted) return;
    _bloc.add(more == true ? RestExtended() : NextSetStarted());
  }

  /// back button: ask first, so a workout is not lost by accident
  Future<void> _onBack() async {
    final s = _bloc.state;
    final count = s.assessment?.reps ?? 0;
    if (count == 0 && !s.paused) {
      Navigator.of(context).pop();
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => SpotDialog(
        title: 'Leave the workout?',
        content: Text('Your $count reps are not saved and will be lost.'),
        actions: [
          SpotButton('Stay', onPressed: () => Navigator.pop(c, false)),
          SpotButton('Leave', kind: SpotKind.destructive, onPressed: () => Navigator.pop(c, true)),
        ],
      ),
    );
    if (ok == true && mounted) Navigator.of(context).pop();
  }

  /// icon with a small label under it (top bar)
  Widget _labeled(IconData icon, String label, String tip, VoidCallback onTap) => Tooltip(
        message: tip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(Sp.rChip),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Column(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(icon, size: 22, color: Sp.white),
                const SizedBox(height: 2),
                Text(label.toUpperCase(), style: Sp.labelSm.copyWith(fontSize: 9, color: Sp.muted)),
              ]),
            ),
          ),
        ),
      );

  /// app bar buttons; each one redraws itself when the bloc changes
  List<Widget> _actions() {
    Widget watch(Widget Function(PostureAssessment c) build) => BlocBuilder<TrainerBloc, TrainerState>(
          buildWhen: (a, b) => a.panelVersion != b.panelVersion || a.assessment != b.assessment,
          builder: (context, state) =>
              state.assessment == null ? const SizedBox.shrink() : build(state.assessment!),
        );
    return [
      _labeled(Icons.timer_outlined, 'Timer', 'Rest timer', _restSettings),
      if (widget.ruleSet.exerciseId == ExerciseKind.benchPress.exerciseId)
        watch((c) => IconButton(
              tooltip: c.lyingCheck ?? true ? 'Lying check ON (tap to turn off)' : 'Lying check OFF',
              icon: Icon(c.lyingCheck ?? true ? Icons.bed : Icons.bed_outlined),
              color: c.lyingCheck ?? true ? Sp.mint : Sp.outline,
              onPressed: () => _bloc.add(LyingCheckToggled()),
            )),
      if (widget.ruleSet.exerciseId == ExerciseKind.bicepsCurl.exerciseId)
        watch((c) => PopupMenuButton<int>(
          tooltip: 'Arms',
          initialValue: c.arms?.mode ?? 0,
          onSelected: (m) => _bloc.add(ArmModeChanged(armMode: m)),
          itemBuilder: (_) => const [
            PopupMenuItem(value: 0, child: Text('Right arm')),
            PopupMenuItem(value: 1, child: Text('Left arm')),
            PopupMenuItem(value: 2, child: Text('Both arms')),
            PopupMenuItem(value: 3, child: Text('Alternate: right, left, right...')),
            PopupMenuItem(value: 4, child: Text('Alternate: left, right, left...')),
          ],
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
            decoration: BoxDecoration(
              color: Sp.card,
              borderRadius: BorderRadius.circular(Sp.rChip),
              border: Border.all(color: Sp.line),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(armShort[c.arms?.mode ?? 0].toUpperCase(), style: Sp.labelMd.copyWith(color: Sp.white)),
              const Icon(Icons.arrow_drop_down, size: 20),
            ]),
          ),
        )),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<TrainerBloc, TrainerState>(
          listenWhen: (a, b) => a.beeps != b.beeps,
          listener: (_, _) => _beep(),
        ),
        BlocListener<TrainerBloc, TrainerState>(
          listenWhen: (a, b) => a.errorMessage == null && b.errorMessage != null,
          listener: (context, state) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.errorMessage!)));
            Navigator.of(context).pop();
          },
        ),
        BlocListener<TrainerBloc, TrainerState>(
          listenWhen: (a, b) => !a.restFinished && b.restFinished,
          listener: (_, state) => _restDone(state),
        ),
      ],
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) _onBack();
        },
        child: Material(
          color: Sp.canvas,
          child: Stack(children: [
            Positioned.fill(
              child: Column(children: [
                Expanded(
                  child: CameraView(
                    title: widget.ruleSet.nameEn,
                    onFrame: (frame) => _bloc.add(TrainerFrameReceived(frame: frame)),
                    actions: _actions(),
                    overlay: BlocBuilder<TrainerBloc, TrainerState>(
                      buildWhen: (a, b) => a.frameNumber != b.frameNumber || a.phase != b.phase,
                      builder: (context, state) => CustomPaint(painter: OverlayPainter(trainerOverlay(state))),
                    ),
                  ),
                ),
                TrainerPanel(onFinishSet: _finishSet),
              ]),
            ),
            // rest screen / 3-2-1 countdown on top of everything
            Positioned.fill(
              child: BlocBuilder<TrainerBloc, TrainerState>(
                buildWhen: (a, b) => a.phase != b.phase || a.tick != b.tick || a.extraUsed != b.extraUsed,
                builder: (context, state) => state.paused && state.assessment != null
                    ? RestOverlay(state: state, onEditTime: _restSettings)
                    : const SizedBox.shrink(),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
