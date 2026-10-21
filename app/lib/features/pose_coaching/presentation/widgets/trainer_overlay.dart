import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:ai_trainer/core/utils/cv_math.dart';
import 'package:ai_trainer/core/widgets/overlay_canvas.dart';
import 'package:ai_trainer/features/pose_coaching/presentation/bloc/trainer_bloc/trainer_bloc.dart';
import 'package:ai_trainer/features/pose_coaching/presentation/widgets/form_colors.dart';
import 'package:ai_trainer/features/pose_coaching/presentation/widgets/skeleton_drawing.dart';

/// what is drawn on the camera picture: skeleton, findAngle lines, the depth bar
/// and (debugHud) the live numbers and fps. All the other text lives in the panel.
OverlayFrame? trainerOverlay(TrainerState state) {
  final counter = state.counter, pose = state.pose;
  if (counter == null || pose == null || state.paused) return null;
  final img = OverlayFrame(state.imageWidth, state.imageHeight, mirror: state.isMirrored);
  drawLandmarks(img, pose);
  for (final a in counter.jointAngles) {
    drawAngle(img, pose, a);
  }

  final e = counter.active;
  final w = img.width, h = img.height;
  // python text sizes were made for a 640x480 (AiTrainer) or 1280x720 picture
  final k = math.min(w, h) / (counter.exercise.oneSide ? 480 : 720);
  final hud = img.hud;
  final t = now();

  // debug text that always fits: shrinks, then cuts, instead of running into the bar
  void put(String s, double x, double y, double scale, Color color, double maxW) {
    const cw = 18.0; // about one letter at scale 1
    var sc = scale;
    var txt = s;
    if (txt.length * cw * sc > maxW) sc = math.max(maxW / (txt.length * cw), 0.45 * k);
    final fit = (maxW / (cw * sc)).floor();
    if (txt.length > fit && fit > 2) txt = '${txt.substring(0, fit - 2)}..';
    hud.putText(txt, x, y, sc, color, 2);
  }

  final barTop = h * 0.2;
  final barBottom = h * 0.9;
  final barX1 = w * 0.88;
  final barX2 = w * 0.96;

  if (counter.tracking) {
    // depth bar drawn on the camera picture
    final bar = interp(counter.curPer, 0, 100, barBottom, barTop);
    final barColor = formLevelColor(counter.formLevel(t));

    hud.rectangle(barX1, barTop, barX2, barBottom, barColor, 3 * k);
    hud.rectangle(barX1, bar, barX2, barBottom, barColor, filled);
    if (counter.isSquat) {
      // white ticks: lower = partial line, upper = deep line, top of the bar = extra deep
      for (final a in counter.depthTickAngles) {
        final pp = interp(a, e.downAngle, e.upAngle, 100, 0).clamp(0.0, 100.0).toDouble();
        final yy = interp(pp, 0, 100, barBottom, barTop);
        hud.rectangle(barX1 - 8 * k, yy, barX2 + 8 * k, yy, Colors.white, 2);
      }
    }
  }

  if (debugHud) {
    final maxW = math.max(barX1 - 40 * k - 20, 120.0);
    var dy = h * 0.5;
    for (final s in counter.debugLines) {
      put(s, 10, dy, 0.6 * k, formNA, maxW);
      dy += 24 * k;
    }
    hud.putText('${state.fps.toInt()}', 10, 70 * k, 2 * k, magenta, 3);
  }
  return img;
}
