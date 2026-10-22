class ExceptionHandler {
  static String poseExceptionHandler(String code) {
    return switch (code) {
      'unsupported-frame' =>
        "This camera's picture format isn't supported on this device.",
      'pose-detection-failed' =>
        "Couldn't read your pose from the camera. Please try again.",
      'face-detection-failed' =>
        "Couldn't detect faces from the camera. Please try again.",
      'no-cv-engine' =>
        "Camera tracking isn't available for this exercise yet. You can still log it in a workout.",
      _ => 'Something went wrong with the camera tracking. Please try again.',
    };
  }

  static String exerciseExceptionHandler(String code) {
    return switch (code) {
      'exercise-not-found' => "We couldn't find that exercise.",
      'exercises-unreadable' => "The exercise list couldn't be loaded.",
      _ => 'Something went wrong while loading the exercises. Please try again.',
    };
  }
}
