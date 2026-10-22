import 'package:ai_trainer/features/pose_coaching/domain/entities/localized_cue.dart';

class LocalizedCueModel extends LocalizedCue {
  const LocalizedCueModel({required super.ar, required super.en});

  factory LocalizedCueModel.fromJson(Map<String, dynamic> json) =>
      LocalizedCueModel(ar: json['ar'] as String? ?? '', en: json['en'] as String? ?? '');

  factory LocalizedCueModel.fromEntity(LocalizedCue cue) => LocalizedCueModel(ar: cue.ar, en: cue.en);

  Map<String, dynamic> toJson() => {'ar': ar, 'en': en};
}
