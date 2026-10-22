import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:ai_trainer/core/theme/app_theme.dart';
import 'package:ai_trainer/core/utils/cv_math.dart';
import 'package:ai_trainer/core/widgets/spot_widgets.dart';
import 'package:ai_trainer/features/pose_coaching/presentation/bloc/trainer_bloc/trainer_bloc.dart';
import 'package:ai_trainer/features/pose_coaching/presentation/widgets/form_colors.dart';

/// the panel under the camera: status chips, feedback card, REPS DONE card with depth
/// progress, FORM SCORE ring, +/- rep buttons and the FINISH SET button
class TrainerPanel extends StatelessWidget {
  const TrainerPanel({super.key, required this.onFinishSet});

  final VoidCallback onFinishSet;

  Widget _squareBtn(IconData icon, String tip, VoidCallback onTap) => SizedBox(
        width: 56,
        height: 56,
        child: Tooltip(
          message: tip,
          child: OutlinedButton(
            onPressed: onTap,
            style: OutlinedButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(56, 56)),
            child: Icon(icon, size: 24),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          color: Sp.canvas,
          border: Border(top: BorderSide(color: Sp.line)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: BlocBuilder<TrainerBloc, TrainerState>(
              buildWhen: (a, b) => a.panelVersion != b.panelVersion || a.assessment != b.assessment,
              builder: (context, state) =>
                  state.assessment == null ? const SizedBox.shrink() : _panelBody(context, state),
            ),
          ),
        ),
      );

  Widget _panelBody(BuildContext context, TrainerState state) {
    final c = state.assessment!;
    final sets = c.sets;
    final t = now();
    final msg = c.feedback;
    final msgColor = feedbackColor(msg.tone);
    final fc = formLevelColor(c.formLevel);
    final fat = sets.fatigue, sm = sets.smoothness;
    final arms = c.arms, depths = c.squatDepths;
    final bloc = context.read<TrainerBloc>();

    final chips = <Widget>[
      if (sets.inSet)
        SpotChip('Set ${sets.setNumber} · ${sets.setReps} reps · ${mmss(t - sets.setStartTime)}', dot: Sp.mint)
      else
        SpotChip('Set ${sets.setNumber} · start lifting', dot: formNA),
      if (arms != null)
        SpotChip(
            arms.alternate
                ? 'Next ${arms.rightNext ? 'R' : 'L'} · R ${arms.repsRight} · L ${arms.repsLeft}'
                : armNames[arms.mode],
            dot: arms.alternate ? formWarn : Sp.mint),
      if (depths != null)
        SpotChip('Partial ${depths.partial} · Deep ${depths.deep} · Extra ${depths.extraDeep}', dot: Sp.mint),
      if (sm != null) SpotChip('Smooth ${sm.round()}', dot: Sp.mint),
      if (sets.inSet && fat != null) SpotChip('Fatigue ${fat.round()}% ${fatigueWord(fat)}', dot: fatigueColor(fat)),
    ];

    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // status chips
      SizedBox(
        height: 32,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: chips.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (_, i) => Center(child: chips[i]),
        ),
      ),
      const SizedBox(height: 8),
      // feedback card
      SizedBox(
        height: 64,
        child: SpotCard(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(color: Sp.cardHigh, shape: BoxShape.circle),
              child: Icon(feedbackIcon(msg.icon), color: msgColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(msg.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Sp.headlineSm.copyWith(fontSize: 16, color: Sp.white)),
                if (msg.sub != null)
                  Text(msg.sub!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Sp.bodySm.copyWith(color: Sp.muted)),
              ]),
            ),
          ]),
        ),
      ),
      const SizedBox(height: 8),
      // reps + form score
      SizedBox(
        height: 100,
        child: Row(children: [
          Expanded(
            flex: 5,
            child: SpotCard(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('REPS DONE', style: Sp.labelSm.copyWith(color: Sp.muted)),
                Text('${c.reps}', style: Sp.displayMetric.copyWith(fontSize: 44, height: 1, color: Sp.white)),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: (c.percent / 100).clamp(0.0, 1.0).toDouble(),
                    minHeight: 4,
                    color: fc,
                    backgroundColor: Sp.line,
                  ),
                ),
              ]),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 4,
            child: SpotCard(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                SizedBox(
                  width: 56,
                  height: 56,
                  child: Stack(alignment: Alignment.center, children: [
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        value: c.formReady ? (c.formScore / 100).clamp(0.0, 1.0).toDouble() : 0.0,
                        strokeWidth: 5,
                        color: fc,
                        backgroundColor: Sp.line,
                      ),
                    ),
                    Text(c.formReady ? '${c.formScore.round()}' : '--',
                        style: Sp.headlineSm.copyWith(color: Sp.white)),
                  ]),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('FORM SCORE', maxLines: 1, style: Sp.labelSm.copyWith(color: Sp.muted, fontSize: 9)),
                    const SizedBox(height: 2),
                    Text(c.formWord, maxLines: 2, style: Sp.labelMd.copyWith(color: fc)),
                  ]),
                ),
              ]),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 8),
      // fix a rep + finish the set
      Row(children: [
        _squareBtn(Icons.remove, 'Remove a rep', () => bloc.add(const RepAdjusted(delta: -1))),
        const SizedBox(width: 8),
        _squareBtn(Icons.add, 'Add a rep', () => bloc.add(const RepAdjusted(delta: 1))),
        const SizedBox(width: 8),
        Expanded(
          child: SpotButton(sets.setReps > 0 ? 'Finish set · ${sets.setReps} reps' : 'Finish set',
              icon: Icons.flag_outlined, onPressed: onFinishSet),
        ),
      ]),
    ]);
  }
}
