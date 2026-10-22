import 'package:ai_trainer/features/pose_coaching/domain/engine/form_evaluation.dart';

/// a problem is only shown after it lasted [warnDelay] and is kept [warnHold]: no flicker
class WarningTracker {
  static const warnDelay = 0.25; // a problem must last this long to be shown
  static const warnHold = 0.6; // and stays this long after it is gone

  final _first = <String, double>{};
  final _last = <String, double>{};
  final _severe = <String, double>{};
  final shown = <String>[]; // warnings that passed the debounce
  String? note; // small grey hint of the last frame

  bool severeNow(String m, double t) => t - (_severe[m] ?? -99) <= warnHold;

  void update(FormEvaluation ev, double t) {
    for (final m in ev.warns) {
      _first.putIfAbsent(m, () => t);
      _last[m] = t;
    }
    for (final m in ev.blocking) {
      _severe[m] = t;
    }
    final drop = <String>[];
    _last.forEach((m, last) {
      if (t - last > warnHold) drop.add(m);
    });
    for (final m in drop) {
      _last.remove(m);
      _first.remove(m);
    }
    shown.clear();
    for (final m in _last.keys) {
      if (_last[m]! - _first[m]! >= warnDelay) shown.add(m);
    }
    note = ev.note;
  }

  void clear() {
    _first.clear();
    _last.clear();
    _severe.clear();
    shown.clear();
    note = null;
  }
}
