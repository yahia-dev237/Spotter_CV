/// the user's own "start" posture, so body type and camera angle don't need
/// one fixed number. One value per key (e.g. 'lean24', 'legExt').
class PostureBaseline {
  final _base = <String, double>{};

  double? operator [](String key) => _base[key];

  void clear() => _base.clear();

  /// slowly follows while idle, frozen during a rep
  double follow(String key, double v, bool idle) {
    final b = _base[key];
    if (b == null) {
      _base[key] = v;
      return v;
    }
    if (idle) return _base[key] = 0.95 * b + 0.05 * v;
    return b;
  }

  /// like [follow], but only follows while idle AND near the upright value, so a slow
  /// start of the lift cannot drag the "standing" reference down with it
  double stand(String key, double v, bool idle) {
    final b = _base[key];
    if (b == null) {
      _base[key] = v;
      return v;
    }
    if (!idle) return b;
    if (v > b) return _base[key] = 0.8 * b + 0.2 * v;
    if (v > 0.9 * b) return _base[key] = 0.95 * b + 0.05 * v;
    return _base[key] = 0.9995 * b; // far below: slow drift, so one early spike can't stick
  }

  /// like [follow], but follows quickly DOWNWARD and very slowly upward while idle, for a
  /// value whose standing level is its minimum (hand height: lifting makes it bigger, so
  /// the start of a lift cannot drag the reference up with it)
  double low(String key, double v, bool idle) {
    final b = _base[key];
    if (b == null) {
      _base[key] = v;
      return v;
    }
    if (!idle) return b;
    return _base[key] = v < b ? 0.8 * b + 0.2 * v : 0.995 * b + 0.005 * v;
  }
}
