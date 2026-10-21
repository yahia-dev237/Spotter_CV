import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:ai_trainer/features/pose_coaching/presentation/screens/training_menu_screen.dart';
import 'package:ai_trainer/injection_container.dart';

/// Main.py: choose your training
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }
  await init();
  runApp(const AiTrainerApp());
}

class AiTrainerApp extends StatelessWidget {
  const AiTrainerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Spotter',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.green, useMaterial3: true),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.green,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: const TrainingMenuScreen(),
    );
  }
}
