<p align="center">
  <img src="assets/app_icon.png" width="140" alt="Spotter logo">
</p>

<h1 align="center">Spotter</h1>

<p align="center">
  An AI workout trainer that watches you through the phone camera, measures your joint angles
  and counts your reps automatically. It works fully offline.
</p>

---

## What it does

Spotter uses **pose estimation** to find 33 body landmarks (shoulders, elbows, hips, knees, ankles, …)
in every camera frame. For each exercise it measures the angle of the joint that moves, turns it into a
**0–100 % progress bar** and counts a rep when you go all the way down and back up.

| Exercise | Joint measured | 0 % (start) | 100 % (bottom) |
|---|---|---|---|
| Biceps Curl | right elbow: shoulder → elbow → wrist | 130° | 94° |
| Squat | knees: hip → knee → ankle (both legs) | 160° | 120° |
| Deadlift | hips: shoulder → hip → knee (both sides) | 160° | 137° |
| Bench Press | elbows: shoulder → elbow → wrist (both arms) | 152° | 79° |

A rep is counted only when the bar reaches 100 % and then returns to 0 %, with at least 1 second
between reps. For two-sided exercises the straighter side is used, so moving one limb can't count a rep.
The angle is smoothed so one jumpy frame can't change the result.

On screen you see the skeleton, the measured angle, the progress bar, the rep counter and the FPS.
There are also two learning demos: **Pose Estimation** (all landmarks) and **Face Detection**.

**Tip:** for Squat and Deadlift stand at about 45° or sideways to the camera. The camera only sees in
2D, so a knee bending towards the camera looks straighter than it really is.

## Project structure

```
spotter/
├── app/       Flutter (Dart) Android app – the final product
├── python/    the original prototype in Python (OpenCV + MediaPipe)
└── assets/    logo
```

The project started as a Python prototype running on a laptop webcam and was then ported to Dart/Flutter
to run on Android phones.

The Flutter app follows **clean architecture**: each feature has a `domain` layer (entities, repository
interfaces, use cases, pure Dart), a `data` layer (ML Kit and the exercise catalogue behind those
interfaces) and a `presentation` layer (BLoC + screens + widgets). Dependencies are wired with `get_it`
in `injection_container.dart`.

```
app/lib/
├── main.dart
├── injection_container.dart
├── core/                      shared: camera frame + converter, errors, use case base, theme, widgets
└── features/
    ├── pose_coaching/         the 4 trainers, the menu and the Pose Estimation demo
    │   ├── domain/            entities (ExerciseRuleSet, PostureAssessment...), repository interfaces,
    │   │                      use cases, engine/ (CoachingSession + one engine per exercise)
    │   ├── data/              ML Kit pose detector, landmark smoother, exercise database (models,
    │   │                      bundled assets/data/exercises.json, remote data source interface)
    │   └── presentation/      TrainerBloc, PoseBloc, ExerciseMenuCubit, screens, widgets
    └── face_detection/        the Face Detection demo (same layers)
```

### Exercise database

Every exercise lives in one document of the exercise database (Firestore collection
`exercises/{exerciseId}`; the same data is bundled in `app/assets/data/exercises.json` so the app works
offline). It holds the rep thresholds, the form rules (warn / reject limits) and the coaching cues in
Arabic and English. The camera trainer reads all its limits from there, so changing a number in the
database changes the coaching without touching the code. Exercises without `repThresholds` (overhead
press, barbell row) have no camera tracking yet.

To connect the remote database, implement `ExerciseRemoteDataSource`
(`features/pose_coaching/data/datasources/exercise_remote_data_source.dart`) and register it in
`injection_container.dart`; `ExerciseRuleRepositoryImpl` then uses it and falls back to the bundled file.
`ExerciseRuleSetModel.toJson()` writes a document back for the exercise CRUD.

The Dart code mirrors the Python modules:

| Python | Dart (`app/lib`) |
|---|---|
| `Main.py` – choose the training | `features/pose_coaching/presentation/screens/training_menu_screen.dart` |
| `PoseModule.py` – `findPose`, `findPosition`, `findAngle` | `features/pose_coaching/data/` (ML Kit + smoothing) and `domain/engine/pose_geometry.dart` (same angle math) |
| `AiTrainer.py`, `SquatTrainer.py`, `DeadliftTrainer.py`, `BenchPressTrainer.py` | `features/pose_coaching/domain/engine/` – `CoachingSession` (shared rep loop) + `exercises/` (one engine per exercise); thresholds come from the exercise database |
| `FaceDetectionModule` | `features/face_detection/` |
| `cv2.VideoCapture` loop + `cv2.imshow` | `core/widgets/camera_view.dart` |
| `cv2.line/circle/rectangle/putText`, `np.interp` | `core/widgets/overlay_canvas.dart`, `core/utils/cv_math.dart` |

## Tech

- **Flutter / Dart**, Android
- **Google ML Kit Pose Detection** (BlazePose, 33 landmarks, *accurate* model) – the models are bundled
  inside the app, so it **works without internet**
- MediaPipe's landmark smoothing (One Euro filter) ported to Dart
- `camera` plugin, 720p preview; the detector gets a half-size copy of each frame for speed
- Python prototype: OpenCV, MediaPipe, NumPy

Performance: about 30–40 FPS on a phone (tested on an Infinix GT 30 Pro), about 18 FPS on the Android emulator.

## Run the app

Requirements: [Flutter](https://docs.flutter.dev/get-started/install) and the Android SDK.

```bash
cd app
flutter pub get
flutter run --release        # with a phone (USB debugging) or emulator connected
```

Build an APK to install on a phone:

```bash
flutter build apk --release --split-per-abi
# -> app/build/outputs/flutter-apk/app-arm64-v8a-release.apk
```

## Run the Python prototype

```bash
cd python
pip install -r requirements.txt
python Main.py               # choose 1-4, uses the laptop webcam
```
