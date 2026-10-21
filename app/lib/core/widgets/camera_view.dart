import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:ai_trainer/core/camera/camera_frame.dart';

/// the "while True: cap.read() ... cv2.imshow()" loop.
/// Opens the camera (cv2.VideoCapture(0)), gives every frame to [onFrame]
/// and shows the camera with [overlay] (what was drawn on the frame) on top.
/// The bloc that gets the frames decides which ones go to the detector.
class CameraView extends StatefulWidget {
  const CameraView({
    super.key,
    required this.title,
    required this.onFrame,
    required this.overlay,
    this.actions,
  });

  final String title;
  final void Function(CameraFrame frame) onFrame;
  final Widget overlay;
  // e.g. the arm selector of the biceps curl, shown in the app bar
  final List<Widget>? actions;

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
      // the detector gets a half size copy (see InputImageConverter)
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
    final frame = _toCameraFrame(image);
    if (frame != null) widget.onFrame(frame);
  }

  CameraFrame? _toCameraFrame(CameraImage image) {
    final controller = _controller;
    if (controller == null) return null;
    final sensor = _camera.sensorOrientation;
    int rotation;
    if (Platform.isIOS) {
      rotation = sensor;
    } else {
      final comp = _orientations[controller.value.deviceOrientation];
      if (comp == null) return null;
      rotation = _camera.lensDirection == CameraLensDirection.front
          ? (sensor + comp) % 360
          : (sensor - comp + 360) % 360;
    }
    if (image.planes.length != 1) return null;
    final plane = image.planes.first;
    return CameraFrame(
      bytes: plane.bytes,
      width: image.width,
      height: image.height,
      bytesPerRow: plane.bytesPerRow,
      rotationDegrees: rotation,
      format: image.format.raw as int,
      isFrontCamera: _camera.lensDirection == CameraLensDirection.front,
      capturedAt: DateTime.now(),
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
      body = Center(child: CameraPreview(controller, child: widget.overlay));
    }
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: Text(widget.title), actions: widget.actions),
      body: body,
    );
  }
}
