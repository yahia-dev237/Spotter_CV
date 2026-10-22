/// how serious a fault is (exercises/{exerciseId}.rules[].severity: 1, 2 or 3)
enum RiskLevel {
  low(1),
  medium(2),
  high(3);

  const RiskLevel(this.severity);
  final int severity;

  static RiskLevel fromSeverity(int severity) => switch (severity) {
    >= 3 => RiskLevel.high,
    2 => RiskLevel.medium,
    _ => RiskLevel.low,
  };
}
