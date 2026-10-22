import 'package:equatable/equatable.dart';

/// one coaching message in Arabic and English (exercises/{exerciseId}.cues.{cueKey})
class LocalizedCue extends Equatable {
  final String ar;
  final String en;

  const LocalizedCue({required this.ar, required this.en});

  bool get isEmpty => ar.isEmpty && en.isEmpty;

  @override
  List<Object?> get props => [ar, en];
}
