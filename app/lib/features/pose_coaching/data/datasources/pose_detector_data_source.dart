import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart' as mp;
import 'package:ai_trainer/core/error/exception.dart';
import 'package:ai_trainer/core/camera/input_image_converter.dart';
import 'package:ai_trainer/features/pose_coaching/domain/entities/body_landmark.dart';
import 'package:ai_trainer/core/camera/camera_frame.dart';

// Google ML Kit pose detection (BlazePose, 33 landmarks, on-device)
abstract class PoseDetectorDataSource {
  /// the landmarks of the first person in picture pixels, empty when nobody is seen
  Future<List<BodyLandmark>> detect(CameraFrame frame);
  Future<void> close();
}

class PoseDetectorDataSourceImpl implements PoseDetectorDataSource {
  InputImageConverter inputImageConverter;
  PoseDetectorDataSourceImpl({required this.inputImageConverter});

  // stream mode = mediapipe static_image_mode=False (tracks between frames),
  // the accurate model is the closest to mediapipe's default model_complexity=1
  final mp.PoseDetector pose = mp.PoseDetector(
    options: mp.PoseDetectorOptions(
      mode: mp.PoseDetectionMode.stream,
      model: mp.PoseDetectionModel.accurate,
    ),
  );

  @override
  Future<List<BodyLandmark>> detect(CameraFrame frame) async {
    final converted = inputImageConverter.convert(frame);
    if (converted == null) throw PoseException(code: 'unsupported-frame');
    final List<mp.Pose> poses;
    try {
      poses = await pose.processImage(converted.inputImage);
    } catch (_) {
      throw PoseException(code: 'pose-detection-failed');
    }
    if (poses.isEmpty) return const [];
    // back to pixels of the full size picture
    final s = converted.scale;
    final lms = poses.first.landmarks;
    final out = <BodyLandmark>[];
    for (final type in mp.PoseLandmarkType.values) {
      final l = lms[type];
      if (l == null) continue;
      out.add(BodyLandmark(id: type.index, x: l.x * s, y: l.y * s, z: l.z * s, likelihood: l.likelihood));
    }
    return out;
  }

  @override
  Future<void> close() => pose.close();
}
