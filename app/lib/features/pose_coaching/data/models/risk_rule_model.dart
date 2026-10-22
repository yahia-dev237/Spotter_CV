import 'package:ai_trainer/features/pose_coaching/data/models/json_reading.dart';
import 'package:ai_trainer/features/pose_coaching/domain/entities/risk_level.dart';
import 'package:ai_trainer/features/pose_coaching/domain/entities/risk_rule.dart';

// exercises/{exerciseId}.rules[]
class RiskRuleModel extends RiskRule {
  const RiskRuleModel({
    required super.id,
    required super.fault,
    required super.metric,
    required super.comparator,
    super.warnThreshold,
    super.warnThresholdMin,
    super.warnThresholdMax,
    super.rejectThreshold,
    required super.threshold,
    required super.severity,
    super.activeWhen,
    required super.cueKey,
    super.adaptive,
    super.usesToe,
    super.overrideKey,
    super.note,
  });

  factory RiskRuleModel.fromJson(Map<String, dynamic> json) => RiskRuleModel(
    id: json['id'] as String,
    fault: json['fault'] as String,
    metric: json['metric'] as String,
    comparator: RuleComparator.fromName(json['comparator'] as String? ?? 'gt'),
    warnThreshold: readDoubleOrNull(json['warnThreshold']),
    warnThresholdMin: readDoubleOrNull(json['warnThresholdMin']),
    warnThresholdMax: readDoubleOrNull(json['warnThresholdMax']),
    rejectThreshold: readDoubleOrNull(json['rejectThreshold']),
    threshold: readDouble(json['threshold']),
    severity: RiskLevel.fromSeverity((json['severity'] as num? ?? 1).toInt()),
    activeWhen: json['activeWhen'] as String?,
    cueKey: json['cueKey'] as String? ?? json['fault'] as String,
    adaptive: json['adaptive'] as String?,
    usesToe: json['usesToe'] as bool?,
    overrideKey: json['overrideKey'] as String?,
    note: json['note'] as String?,
  );

  factory RiskRuleModel.fromEntity(RiskRule r) => RiskRuleModel(
    id: r.id,
    fault: r.fault,
    metric: r.metric,
    comparator: r.comparator,
    warnThreshold: r.warnThreshold,
    warnThresholdMin: r.warnThresholdMin,
    warnThresholdMax: r.warnThresholdMax,
    rejectThreshold: r.rejectThreshold,
    threshold: r.threshold,
    severity: r.severity,
    activeWhen: r.activeWhen,
    cueKey: r.cueKey,
    adaptive: r.adaptive,
    usesToe: r.usesToe,
    overrideKey: r.overrideKey,
    note: r.note,
  );

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'id': id,
      'fault': fault,
      'metric': metric,
      'comparator': comparator.name,
    };
    putIfNotNull(json, 'warnThreshold', warnThreshold);
    putIfNotNull(json, 'warnThresholdMin', warnThresholdMin);
    putIfNotNull(json, 'warnThresholdMax', warnThresholdMax);
    json['rejectThreshold'] = rejectThreshold;
    json['threshold'] = threshold;
    json['severity'] = severity.severity;
    putIfNotNull(json, 'activeWhen', activeWhen);
    putIfNotNull(json, 'adaptive', adaptive);
    putIfNotNull(json, 'usesToe', usesToe);
    putIfNotNull(json, 'overrideKey', overrideKey);
    json['cueKey'] = cueKey;
    putIfNotNull(json, 'note', note);
    return json;
  }
}
