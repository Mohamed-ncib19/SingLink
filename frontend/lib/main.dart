import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart' hide UserInfo;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:frontend/pages/auth_gate.dart';
import 'package:frontend/const/custom_theme.dart';
import 'package:frontend/const/firebase_options.dart';
import 'package:frontend/provider/theme_model.dart';
import 'package:frontend/provider/user_info.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await _initApp();
}

Future<void> _initApp() async {
  if (!kIsWeb) LoadDetectionModel();

  final prefs = await SharedPreferences.getInstance();
  var color = prefs.getString('ThemeColor');
  var isDark = prefs.getBool('isDark') ?? false;
  var fontSize = prefs.getDouble('fontSize') ?? 15;
  var userId =
      FirebaseAuth.instance.currentUser?.uid ?? prefs.getString("userId") ?? "";

  if (color == 'pink') {
    currentTheme = createThemeData(Colors.pink, isDark, fontSize);
  } else if (color == 'orange') {
    currentTheme = createThemeData(Colors.orange, isDark, fontSize);
  } else if (color == 'brown') {
    currentTheme = createThemeData(Colors.brown, isDark, fontSize);
  } else if (color == 'lightBlue') {
    currentTheme = createThemeData(Colors.lightBlue, isDark, fontSize);
  } else if (color == 'purple') {
    currentTheme = createThemeData(Colors.purple, isDark, fontSize);
  } else {
    currentTheme = createThemeData(defaultColor, isDark, fontSize);
  }

  runApp(
    MultiProvider(
      providers: [
        Provider(create: (context) => UserInfo(userId)),
        ChangeNotifierProvider(
            create: (context) => ThemeNotifier(currentTheme)),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeNotifier>().getTheme;
    return MaterialApp(
      title: 'SignLink',
      theme: theme,
      home: const AuthGate(),
    );
  }
}

void LoadDetectionModel() async {
  if (kIsWeb) return;
  try {
    await Tflite.loadModel(
        model: "assets/model.tflite", labels: "assets/labels.txt");
    print("Loaded model successfully");
    TestModel();
  } on Exception catch (e) {
    print("Failed to load model: " + e.toString());
  }
}

Uint8List imageToByteListFloat32(
    dynamic img, int inputSize, double mean, double std) {
  var convertedBytes = Float32List(1 * inputSize * inputSize * 3);
  var buffer = Float32List.view(convertedBytes.buffer);
  int pixelIndex = 0;
  for (var i = 0; i < inputSize; i++) {
    for (var j = 0; j < inputSize; j++) {
      var pixel = img.getPixel(j, i);
      buffer[pixelIndex++] = (pixel.r.toInt() - mean) / std;
      buffer[pixelIndex++] = (pixel.g.toInt() - mean) / std;
      buffer[pixelIndex++] = (pixel.b.toInt() - mean) / std;
    }
  }
  return convertedBytes.buffer.asUint8List();
}

void TestModel() async {
  print("Model testing not implemented on mobile init");
}

class Tflite {
  static Future<void> close() async {}
  static Future<void> loadModel(
      {required String model, required String labels}) async {}
  static Future<List<Map<String, dynamic>>> runModelOnBinary(
      {required Uint8List binary, int numResults = 29}) async {
    return [];
  }
}
