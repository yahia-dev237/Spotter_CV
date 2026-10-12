import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'face_detection_module.dart';
import 'pose_page.dart';
import 'trainer.dart';

/// Main.py: choose your training
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
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
      darkTheme: ThemeData(colorSchemeSeed: Colors.green, brightness: Brightness.dark, useMaterial3: true),
      home: const MenuPage(),
    );
  }
}

class MenuPage extends StatelessWidget {
  const MenuPage({super.key});

  void _open(BuildContext context, Widget page) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Spotter')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Choose your training:', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          for (var i = 0; i < exercises.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                onPressed: () => _open(context, TrainerPage(exercise: exercises[i])),
                child: Text('${i + 1} - ${exercises[i].name}', style: const TextStyle(fontSize: 18)),
              ),
            ),
          const SizedBox(height: 24),
          Text('Learning demos', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => _open(context, const PosePage()),
            child: const Text('Pose Estimation (PoseModule)'),
          ),
          OutlinedButton(
            onPressed: () => _open(context, const FaceDetectionPage()),
            child: const Text('Face Detection (FaceDetectionModule)'),
          ),
        ],
      ),
    );
  }
}
