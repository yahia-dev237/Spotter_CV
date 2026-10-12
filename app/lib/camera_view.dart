import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import 'cv.dart';

/// the "while True: cap.read() ... cv2.imshow()" loop.
/// Opens the camera (cv2.VideoCapture(0)), gives every frame to [onFrame]
/// and shows the camera with everything drawn on the frame.
class CameraView extends StatefulWidget {
  const CameraView({super.key, required this.title, required this.onFrame});

  final String title;
  final Future<void> Function(Frame img) onFrame;

  @override
  State<CameraView> createState() => _CameraViewState();
}

class _CameraViewState extends State<CameraView> {
  static const _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  CameraController? _controller;
  late CameraDescription _camera;
  bool _ready = false;
  // frames sent to the detector and not answered yet; 2 was tested and gave the
  // same fps (ML Kit works on one frame at a time) but the skeleton lagged more
  static const _maxInFlight = 1;
  int _inFlight = 0;
  int _sent = 0, _shown = 0;
  CameraImage? _pending;
  Frame? _frame;
  String? _error;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _error = 'No camera found');
        return;
      }
      // the selfie camera, like a laptop webcam
      _camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      // ask the camera for a bigger picture (720p) - this is what is shown on screen;
      // the detector gets a half size copy (see _halfSize)
      final controller = CameraController(
        _camera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
      );
      _controller = controller;
      await controller.initialize();
      if (!mounted) return;
      await controller.startImageStream(_process);
      setState(() => _ready = true);
    } on CameraException catch (e) {
      if (mounted) setState(() => _error = e.description ?? e.code);
    }
  }

  void _process(CameraImage image) {
    if (!mounted) return;
    // while the detector is full keep only the newest frame, and start it the
    // moment a slot is free instead of waiting for the camera's next frame
    if (_inFlight >= _maxInFlight) {
      _pending = image;
      return;
    }
    _run(image);
  }

  void _run(CameraImage image) {
    final input = _toInputImage(image);
    if (input == null) return;
    _inFlight++;
    final id = ++_sent;

    final meta = input.metadata!;
    final sideways = meta.rotation == InputImageRotation.rotation90deg ||
        meta.rotation == InputImageRotation.rotation270deg;
    final w = (sideways ? image.height : image.width).toDouble();
    final h = (sideways ? image.width : image.height).toDouble();
    final img = Frame(input, w, h,
        mirror: _camera.lensDirection == CameraLensDirection.front,
        detectScale: image.width / meta.size.width);

    widget.onFrame(img).then((_) {
      // ML Kit answers in order, but never show an older frame over a newer one
      if (mounted && id > _shown) {
        _shown = id;
        setState(() => _frame = img);
      }
    }).catchError((Object e) {
      debugPrint('frame error: $e');
    }).whenComplete(() {
      _inFlight--;
      final next = _pending;
      _pending = null;
      if (next != null && mounted) _run(next);
    });
  }

  /// NV21 picture at half the width and height (every 2nd pixel), so less data
  /// has to be copied to ML Kit and converted. Same shape, so same angles.
  static (Uint8List, int, int) _halfSize(Uint8List src, int width, int height, int stride) {
    final w2 = (width ~/ 2) & ~1, h2 = (height ~/ 2) & ~1;
    final out = Uint8List(w2 * h2 * 3 ~/ 2);
    // Y plane
    var o = 0;
    for (var y = 0; y < h2; y++) {
      var s = 2 * y * stride;
      for (var x = 0; x < w2; x++, s += 2) {
        out[o++] = src[s];
      }
    }
    // interleaved V/U plane (one V,U pair for every 2x2 pixels)
    final vu = stride * height;
    for (var y = 0; y < h2 ~/ 2; y++) {
      var s = vu + 2 * y * stride;
      for (var x = 0; x < w2 ~/ 2; x++, s += 4) {
        out[o++] = src[s];
        out[o++] = src[s + 1];
      }
    }
    return (out, w2, h2);
  }

  InputImage? _toInputImage(CameraImage image) {
    final controller = _controller;
    if (controller == null) return null;
    final sensor = _camera.sensorOrientation;
    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensor);
    } else {
      var comp = _orientations[controller.value.deviceOrientation];
      if (comp == null) return null;
      comp = _camera.lensDirection == CameraLensDirection.front
          ? (sensor + comp) % 360
          : (sensor - comp + 360) % 360;
      rotation = InputImageRotationValue.fromRawValue(comp);
    }
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null ||
        (Platform.isAndroid && format != InputImageFormat.nv21) ||
        (Platform.isIOS && format != InputImageFormat.bgra8888)) {
      return null;
    }
    if (image.planes.length != 1) return null;
    final plane = image.planes.first;

    var bytes = plane.bytes;
    var width = image.width, height = image.height, bytesPerRow = plane.bytesPerRow;
    // only when the buffer really is a full NV21 picture (Y rows + V/U rows)
    if (Platform.isAndroid && bytes.length >= bytesPerRow * (height + height ~/ 2 - 1) + width) {
      (bytes, width, height) = _halfSize(bytes, width, height, bytesPerRow);
      bytesPerRow = width;
    }

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(width.toDouble(), height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: bytesPerRow,
      ),
    );
  }

  @override
  void dispose() {
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      if (controller.value.isStreamingImages) {
        controller.stopImageStream().whenComplete(controller.dispose);
      } else {
        controller.dispose();
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    Widget body;
    if (_error != null) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, style: const TextStyle(color: Colors.white), textAlign: TextAlign.center),
        ),
      );
    } else if (!_ready || controller == null) {
      body = const Center(child: CircularProgressIndicator());
    } else {
      body = Center(
        child: CameraPreview(
          controller,
          child: CustomPaint(painter: FramePainter(_frame)),
        ),
      );
    }
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: Text(widget.title)),
      body: body,
    );
  }
}
