import 'dart:typed_data';

import 'package:equatable/equatable.dart';

// one picture from the camera stream ("cap.read()")
class CameraFrame extends Equatable {
  final Uint8List bytes;
  final int width;
  final int height;
  final int bytesPerRow;
  final int rotationDegrees;
  final int format; // raw camera image format
  final bool isFrontCamera;
  final DateTime capturedAt;

  const CameraFrame({
    required this.bytes,
    required this.width,
    required this.height,
    required this.bytesPerRow,
    required this.rotationDegrees,
    required this.format,
    required this.isFrontCamera,
    required this.capturedAt,
  });

  bool get isSideways => rotationDegrees == 90 || rotationDegrees == 270;

  // size of the picture after turning it upright (what the user sees)
  double get uprightWidth => (isSideways ? height : width).toDouble();
  double get uprightHeight => (isSideways ? width : height).toDouble();

  @override
  List<Object?> get props => [
    width,
    height,
    rotationDegrees,
    isFrontCamera,
    capturedAt,
  ];
}
