import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:frontend/pages/camera_screen.dart';
import 'package:frontend/pages/camera_screen_web.dart';

class TranslationPage extends StatelessWidget {
  const TranslationPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return kIsWeb ? const CameraScreenWeb() : const CameraScreen();
  }
}
