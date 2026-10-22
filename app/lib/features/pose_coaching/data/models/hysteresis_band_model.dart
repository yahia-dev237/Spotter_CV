import 'package:ai_trainer/features/pose_coaching/data/models/json_reading.dart';
import 'package:ai_trainer/features/pose_coaching/domain/entities/hysteresis_band.dart';

// exercises/{exerciseId}.repThresholds
class HysteresisBandModel extends HysteresisBand {
  const HysteresisBandModel({
    required super.primaryAngle,
    required super.lowerDeg,
    required super.upperDeg,
    super.smoothing,
    super.depthClasses,
    super.hipAngleVariants,
    super.bottomReachedBarPct,
    super.squatInsteadOfDeadliftKneeAngleDeg,
    super.usesStraighterArm,
    super.maxSpeedDegPerSec,
    super.maxSpeedWarnMultiplier,
    super.barPosition,
    super.lockoutBarPct,
    super.facingCamera,
    super.upperArmFromVerticalLimitDeg,
    super.upperArmBarCapPct,
    super.note,
  });

  factory HysteresisBandModel.fromJson(Map<String, dynamic> json) {
    final depth = json['depthClasses'] as Map<String, dynamic>?;
    final variants = json['hipAngleVariants'] as Map<String, dynamic>?;
    final bottom = json['bottomReachedBarPct'] as Map<String, dynamic>?;
    final bar = json['barPosition'] as Map<String, dynamic>?;
    final facing = json['facingCamera'] as Map<String, dynamic>?;
    return HysteresisBandModel(
      primaryAngle: json['primaryAngle'] as String,
      lowerDeg: readDouble(json['lowerDeg']),
      upperDeg: readDouble(json['upperDeg']),
      smoothing: json['smoothing'] as String?,
      depthClasses: depth == null
          ? null
          : DepthClasses(
              partial: _depthClass(depth['partial']),
              deep: _depthClass(depth['deep']),
              extraDeep: _depthClass(depth['extraDeep']),
            ),
      hipAngleVariants: variants?.map((k, v) => MapEntry(k, _angleRange(v as Map<String, dynamic>))),
      bottomReachedBarPct: bottom == null
          ? null
          : BottomReachedPct(side: readDouble(bottom['side']), front: readDouble(bottom['front'])),
      squatInsteadOfDeadliftKneeAngleDeg: readDoubleOrNull(json['squatInsteadOfDeadliftKneeAngleDeg']),
      usesStraighterArm: json['usesStraighterArm'] as bool?,
      maxSpeedDegPerSec: readDoubleOrNull(json['maxSpeedDegPerSec']),
      maxSpeedWarnMultiplier: readDoubleOrNull(json['maxSpeedWarnMultiplier']),
      barPosition: bar == null
          ? null
          : BarPosition(
              landmarks: (bar['landmarks'] as Map<String, dynamic>)
                  .map((k, v) => MapEntry(k, readIntListOrNull(v) ?? const <int>[])),
              topShinLengths: readDouble(bar['topShinLengths']),
              bottomShinLengths: readDouble(bar['bottomShinLengths']),
              source: bar['source'] as String?,
            ),
      lockoutBarPct: readDoubleOrNull(json['lockoutBarPct']),
      facingCamera: facing == null ? null : _angleRange(facing),
      upperArmFromVerticalLimitDeg: readDoubleOrNull(json['upperArmFromVerticalLimitDeg']),
      upperArmBarCapPct: readDoubleOrNull(json['upperArmBarCapPct']),
      note: json['note'] as String?,
    );
  }

  factory HysteresisBandModel.fromEntity(HysteresisBand b) => HysteresisBandModel(
    primaryAngle: b.primaryAngle,
    lowerDeg: b.lowerDeg,
    upperDeg: b.upperDeg,
    smoothing: b.smoothing,
    depthClasses: b.depthClasses,
    hipAngleVariants: b.hipAngleVariants,
    bottomReachedBarPct: b.bottomReachedBarPct,
    squatInsteadOfDeadliftKneeAngleDeg: b.squatInsteadOfDeadliftKneeAngleDeg,
    usesStraighterArm: b.usesStraighterArm,
    maxSpeedDegPerSec: b.maxSpeedDegPerSec,
    maxSpeedWarnMultiplier: b.maxSpeedWarnMultiplier,
    barPosition: b.barPosition,
    lockoutBarPct: b.lockoutBarPct,
    facingCamera: b.facingCamera,
    upperArmFromVerticalLimitDeg: b.upperArmFromVerticalLimitDeg,
    upperArmBarCapPct: b.upperArmBarCapPct,
    note: b.note,
  );

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'primaryAngle': primaryAngle,
      'lowerDeg': lowerDeg,
      'upperDeg': upperDeg,
    };
    putIfNotNull(json, 'smoothing', smoothing);
    final depth = depthClasses;
    if (depth != null) {
      json['depthClasses'] = {
        'partial': _depthClassJson(depth.partial),
        'deep': _depthClassJson(depth.deep),
        'extraDeep': _depthClassJson(depth.extraDeep),
      };
    }
    putIfNotNull(json, 'hipAngleVariants', hipAngleVariants?.map((k, v) => MapEntry(k, _angleRangeJson(v))));
    final bar = barPosition;
    if (bar != null) {
      final barJson = <String, dynamic>{
        'landmarks': bar.landmarks,
        'topShinLengths': bar.topShinLengths,
        'bottomShinLengths': bar.bottomShinLengths,
      };
      putIfNotNull(barJson, 'source', bar.source);
      json['barPosition'] = barJson;
    }
    final bottom = bottomReachedBarPct;
    if (bottom != null) json['bottomReachedBarPct'] = {'side': bottom.side, 'front': bottom.front};
    putIfNotNull(json, 'lockoutBarPct', lockoutBarPct);
    putIfNotNull(json, 'squatInsteadOfDeadliftKneeAngleDeg', squatInsteadOfDeadliftKneeAngleDeg);
    putIfNotNull(json, 'usesStraighterArm', usesStraighterArm);
    final facing = facingCamera;
    if (facing != null) json['facingCamera'] = _angleRangeJson(facing);
    putIfNotNull(json, 'upperArmFromVerticalLimitDeg', upperArmFromVerticalLimitDeg);
    putIfNotNull(json, 'upperArmBarCapPct', upperArmBarCapPct);
    putIfNotNull(json, 'maxSpeedDegPerSec', maxSpeedDegPerSec);
    putIfNotNull(json, 'maxSpeedWarnMultiplier', maxSpeedWarnMultiplier);
    putIfNotNull(json, 'note', note);
    return json;
  }

  static DepthClass _depthClass(Object? v) {
    final json = v as Map<String, dynamic>;
    return DepthClass(
      maxKneeAngleDeg: readDouble(json['maxKneeAngleDeg']),
      countsAsRep: json['countsAsRep'] as bool?,
    );
  }

  static Map<String, dynamic> _depthClassJson(DepthClass d) {
    final json = <String, dynamic>{'maxKneeAngleDeg': d.maxKneeAngleDeg};
    putIfNotNull(json, 'countsAsRep', d.countsAsRep);
    return json;
  }

  static AngleRange _angleRange(Map<String, dynamic> json) => AngleRange(
    topDeg: readDouble(json['topDeg']),
    bottomDeg: readDouble(json['bottomDeg']),
    note: json['note'] as String?,
  );

  static Map<String, dynamic> _angleRangeJson(AngleRange r) {
    final json = <String, dynamic>{'topDeg': r.topDeg, 'bottomDeg': r.bottomDeg};
    putIfNotNull(json, 'note', r.note);
    return json;
  }
}
