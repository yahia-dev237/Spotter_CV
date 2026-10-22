import 'package:ai_trainer/features/pose_coaching/domain/entities/form_level.dart';

/// the rep that is being done now and the result of the last one
class RepProgress {
  int dir = 0; // 0 = going down, 1 = reached the bottom
  bool attempt = false; // left the top, rep not finished yet
  double peakPer = 0;
  double minAngle = 999;
  double? bottomSince;
  double repStartTime = 0;
  double lastRepTime = 0;
  double lastSeenTime = 0;
  bool needRest = false; // alternate curl: the new arm must be at the bottom before a rep can start
  final repFaults = <String>{};
  double curPer = 0; // depth of the current rep, 0..100

  // range of motion and tempo consistency of the last reps (for the form score)
  double? lastRom;
  double? lastConsistency;
  final repDurations = <double>[];

  // per-rep smoothness and average form
  double repSpeedPeak = 0, repSpeedVar = 0, lastRepSpeed = 0;
  bool repSpeedInit = false;
  double repFormSum = 0;
  int repFormN = 0;
  double? lastSmooth; // 0..100 of the last finished rep
  double dbgSmoothRatio = 0;

  // what the feedback card says about the last rep
  String repLabel = '';
  String repDetail = '';
  FormLevel repLevel = FormLevel.good;
  double repLabelTime = -99;

  bool get idle => dir == 0 && !attempt;

  /// left the top: a new rep starts
  void start(double t, double smoothed) {
    attempt = true;
    repStartTime = t;
    peakPer = 0;
    minAngle = smoothed;
    repFaults.clear();
    // smoothness / average form of this rep start from zero
    repSpeedPeak = 0;
    repSpeedVar = 0;
    repSpeedInit = false;
    repFormSum = 0;
    repFormN = 0;
  }

  /// forget the half-finished rep and the reps' history
  void reset() {
    dir = 0;
    attempt = false;
    bottomSince = null;
    repFaults.clear();
    lastRom = null;
    lastConsistency = null;
    repDurations.clear();
  }

  void showResult(String label, FormLevel level, String detail, double t) {
    repLabel = label;
    repLevel = level;
    repDetail = detail;
    repLabelTime = t;
  }
}
