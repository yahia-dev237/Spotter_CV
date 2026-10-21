import 'package:flutter/material.dart';

import 'package:ai_trainer/core/theme/app_theme.dart';

// Spotter shared widgets: use these instead of the default Material widgets.

/// Level-2 card: tonal fill + 1px hairline, 16px radius, no shadow.
class SpotCard extends StatelessWidget {
  const SpotCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color = Sp.card,
    this.borderColor = Sp.line,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final Color borderColor;

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(Sp.rCard),
          border: Border.all(color: borderColor),
        ),
        child: child,
      );
}

/// Status chip: neutral dark fill, 6px colour dot, high-contrast label.
class SpotChip extends StatelessWidget {
  const SpotChip(this.text, {super.key, this.dot, this.textColor = Sp.white});
  final String text;
  final Color? dot;
  final Color textColor;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: Sp.card,
          borderRadius: BorderRadius.circular(Sp.rChip),
          border: Border.all(color: Sp.line),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (dot != null) ...[
            Container(width: 6, height: 6, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(text.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Sp.labelSm.copyWith(fontSize: 11, color: textColor)),
          ),
        ]),
      );
}

/// Metric card: small uppercase label, big tabular value, optional unit.
class SpotMetric extends StatelessWidget {
  const SpotMetric(this.label, this.value, {super.key, this.unit, this.valueColor = Sp.white});
  final String label;
  final String value;
  final String? unit;
  final Color valueColor;

  @override
  Widget build(BuildContext context) => SpotCard(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(label.toUpperCase(), style: Sp.labelSm.copyWith(color: Sp.muted)),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
              Text(value, style: Sp.headlineLg.copyWith(color: valueColor)),
              if (unit != null) ...[
                const SizedBox(width: 4),
                Text(unit!.toUpperCase(), style: Sp.labelSm.copyWith(color: Sp.muted)),
              ],
            ]),
          ),
        ]),
      );
}

enum SpotKind { primary, secondary, destructive, link }

/// Buttons: primary = solid mint, secondary = outlined, destructive = dark with red
/// border (never solid red), link = underlined text. 12px radius, 56px tall by default.
/// Inside a Row wrap it in Expanded.
class SpotButton extends StatelessWidget {
  const SpotButton(this.label,
      {super.key, this.onPressed, this.icon, this.kind = SpotKind.primary, this.height = 56});
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final SpotKind kind;
  final double height;

  @override
  Widget build(BuildContext context) {
    final child = Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
      if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
      Flexible(child: Text(label.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis)),
    ]);
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(Sp.rButton));
    switch (kind) {
      case SpotKind.primary:
        return FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(minimumSize: Size.fromHeight(height)),
          child: child,
        );
      case SpotKind.secondary:
        return OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(minimumSize: Size.fromHeight(height)),
          child: child,
        );
      case SpotKind.destructive:
        return OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            minimumSize: Size.fromHeight(height),
            backgroundColor: Sp.neutral,
            foregroundColor: Sp.fault,
            side: const BorderSide(color: Sp.fault),
            shape: shape,
          ),
          child: child,
        );
      case SpotKind.link:
        return TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            minimumSize: const Size(44, 44),
            foregroundColor: Sp.onSurface,
            textStyle: Sp.bodyMd.copyWith(decoration: TextDecoration.underline),
          ),
          child: Text(label),
        );
    }
  }
}

/// Dialog in the Spotter style; actions are stacked full width (gym-glove friendly).
class SpotDialog extends StatelessWidget {
  const SpotDialog({super.key, required this.title, required this.content, required this.actions});
  final String title;
  final Widget content;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => AlertDialog(
        backgroundColor: Sp.cardHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Sp.rCard), side: const BorderSide(color: Sp.line)),
        title: Text(title, style: Sp.headlineSm.copyWith(color: Sp.white)),
        content: DefaultTextStyle(style: Sp.bodyMd, child: content),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        actions: [
          SizedBox(
            width: double.infinity,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (var i = 0; i < actions.length; i++) ...[
                if (i > 0) const SizedBox(height: 8),
                actions[i],
              ],
            ]),
          ),
        ],
      );
}
