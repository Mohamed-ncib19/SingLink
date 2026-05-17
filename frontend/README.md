# SignLink - Sign Language Translation App (Frontend)

SignLink is a Flutter app that uses the device camera to capture sign language gestures, sends them to a Python backend for recognition, and displays the translated text in real time.

---

## Project Structure

```
frontend/
├── lib/
│   ├── main.dart                         # App entry point
│   ├── const/
│   │   ├── custom_theme.dart             # Theme colors, dark/light mode
│   │   └── firebase_options.dart         # Firebase project config
│   ├── pages/
│   │   ├── auth_gate.dart                # Auth router (login check)
│   │   ├── start_page.dart               # Google Sign-In screen
│   │   ├── translation_page.dart         # Wrapper → MainNavigationPage
│   │   ├── main_navigation_page.dart     # Bottom nav bar (Home/History/Profile)
│   │   ├── camera_screen.dart            # Mobile camera + prediction
│   │   ├── camera_screen_web.dart        # Web camera + prediction
│   │   ├── history.dart                  # Past translations list
│   │   ├── profile_page.dart             # User profile + settings link
│   │   ├── settings.dart                 # Theme, color, font size, logout
│   │   └── app_sidebar.dart              # (Unused) old drawer navigation
│   ├── provider/
│   │   ├── theme_model.dart              # Theme state (dark/light, color, font)
│   │   └── user_info.dart                # Current user ID holder
│   └── services/
│       ├── history_service.dart          # Firestore CRUD for translations
│       ├── web_square_capture_stub.dart   # Stub (non-web)
│       └── web_square_capture_web.dart    # Canvas-based video capture (web)
├── assets/
│   ├── model.tflite                      # TFLite model
│   ├── labels.txt                        # Model labels
│   └── images/                           # Reference images for similarity
├── pubspec.yaml
└── test/
    └── widget_test.dart
```

---

## File-by-File Explanation with Code Snippets

### `lib/main.dart` — App Entry Point

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await _initApp();
}
```

**Logic:** `main()` is the Dart entry point. `WidgetsFlutterBinding.ensureInitialized()` must be called before any async work that needs the plugin system (like Firebase). Firebase is initialized with platform-specific options (web, Android, iOS, etc.) from `firebase_options.dart`. Then `_initApp()` runs the rest of the setup.

```dart
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
  } // ... other colors ...
  else {
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
```

**Logic:** `_initApp()` loads saved user preferences (theme color, dark mode toggle, font size) from `SharedPreferences` and uses them to build an initial `ThemeData` via `createThemeData()`. It also retrieves the user ID from Firebase Auth or local storage. It then wraps the app in `MultiProvider` to make `UserInfo` and `ThemeNotifier` available to all descendant widgets through `Provider.of<>()` or `context.watch<>()`. On mobile, it also attempts to load a local TFLite model (though the actual ML runs on the backend).

```dart
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
```

**Logic:** `MyApp` is the root widget. It uses `context.watch<ThemeNotifier>()` to **reactively listen** for theme changes. Whenever `ThemeNotifier` calls `notifyListeners()` (after dark/light toggle, color change, or font size change), `MyApp` rebuilds and passes the new theme to `MaterialApp`, instantly updating the entire app's appearance. The `home` is `AuthGate`, which determines whether to show the login screen or the main app.

```dart
class Tflite {
  static Future<void> close() async {}
  static Future<void> loadModel(
      {required String model, required String labels}) async {}
  static Future<List<Map<String, dynamic>>> runModelOnBinary(
      {required Uint8List binary, int numResults = 29}) async {
    return [];
  }
}
```

**Logic:** This is a stub class for the `tflite` package. The actual sign language prediction runs on the Python backend server, not on the device. This stub exists so the app can call `Tflite.loadModel()` on startup without crashing, but it does nothing.

---

### `lib/const/custom_theme.dart` — Theme Builder

```dart
Map<int, Color> primary = {
  50: const Color.fromRGBO(17, 138, 126, .1),
  // ... shades ...
  900: const Color.fromRGBO(17, 138, 126, 1),
};
final defaultColor = MaterialColor(0xFF118A7E, primary);

ThemeData createThemeData(MaterialColor color, bool isDark, double fontSize) {
  if (isDark) {
    return ThemeData(
      primarySwatch: color,
      brightness: Brightness.dark,
      // ...
    );
  } else {
    return ThemeData(
      primarySwatch: color,
      brightness: Brightness.light,
      appBarTheme: AppBarTheme(
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(color: Colors.white, fontSize: 20),
      ),
      // ...
    );
  }
}
```

**Logic:** Defines the app's default teal-green color (`0xFF118A7E`) with 10 shade variants for Material Design. `createThemeData()` generates a complete `ThemeData` object for either dark or light mode using the given primary color and font size. In light mode, it also configures the AppBar icon and title colors to be white. The `fontSize` parameter is applied to all text styles (`bodyLarge`, `bodyMedium`, `headlineLarge`, etc.) for consistent scaling.

---

### `lib/const/firebase_options.dart` — Firebase Config

```dart
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android: return android;
      case TargetPlatform.iOS: return ios;
      case TargetPlatform.macOS: return macos;
      case TargetPlatform.windows: return windows;
      // ...
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBVKzUnJiV2koBKwgl9IhfdDRP9GnQd46I',
    appId: '1:632639747392:web:76d603b084ba7a535876a5',
    projectId: 'signlink-5f735',
    // ...
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBVKzUnJiV2koBKwgl9IhfdDRP9GnQd46I',
    appId: '1:632639747392:android:YOUR_ANDROID_APP_ID',
    // ...
  );
  // ios, macos, windows...
}
```

**Logic:** Generated by the FlutterFire CLI. Provides platform-specific Firebase credentials. `currentPlatform` detects the running platform (web, Android, iOS, macOS, Windows) and returns the corresponding `FirebaseOptions` object. Some platform IDs (Android, iOS, macOS, Windows) contain placeholder values like `YOUR_ANDROID_APP_ID` that need to be replaced with actual values from the Firebase Console.

---

### Pages (`lib/pages/`)

#### `auth_gate.dart` — Login Router

```dart
class AuthGate extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;
        if (user == null) return const StartPage();

        final userInfo = Provider.of<UserInfo>(context, listen: false);
        if (userInfo.getUserId != user.uid) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            userInfo.setUserId(user.uid);
          });
        }

        return const TranslationPage();
      },
    );
  }
}
```

**Logic:** `AuthGate` is the root router. It uses `StreamBuilder` to subscribe to Firebase Auth's `authStateChanges()` stream, which fires whenever the user signs in or out. 

There are 3 cases:
- **Loading** (`ConnectionState.waiting`): Shows a centered spinner while Firebase checks the auth state.
- **Logged out** (`user == null`): Returns `StartPage` (Google Sign-In screen).
- **Logged in** (`user != null`): Syncs the Firebase UID into the `UserInfo` provider (using `addPostFrameCallback` to avoid calling `setState` during build), then returns `TranslationPage` (main app).

The `listen: false` on `Provider.of` prevents this widget from rebuilding when the provider changes — it just reads the value once.

---

#### `start_page.dart` — Google Sign-In Screen

```dart
class _StartPageState extends State<StartPage> {
  bool _loading = false;
  String? _errorMessage;

  Future<void> _signInWithGoogle() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final userCredential = await _authenticateWithGoogle();
      final uid = userCredential.user?.uid;
      if (uid != null && mounted) {
        Provider.of<UserInfo>(context, listen: false).setUserId(uid);
      }

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const TranslationPage()),
      );
    } on FirebaseAuthException catch (e) {
      _showInlineError(e.message ?? 'Google sign-in failed.');
    } catch (e) {
      _showInlineError('Google sign-in failed: $e');
    }
  }
}
```

**Logic:** The sign-in flow sets `_loading = true` to show a spinner on the button, then calls `_authenticateWithGoogle()`. On success, it saves the user ID to the `UserInfo` provider and replaces the current route with `TranslationPage` using `pushReplacement` (no back button to return to login). On failure, it displays the error message inline below the button.

```dart
Future<UserCredential> _authenticateWithGoogle() async {
  if (kIsWeb && !GoogleSignIn.instance.supportsAuthenticate()) {
    return FirebaseAuth.instance.signInWithPopup(GoogleAuthProvider());
  }

  _googleSignInInitialization ??= GoogleSignIn.instance.initialize();
  await _googleSignInInitialization;

  final googleUser = await GoogleSignIn.instance.authenticate(
    scopeHint: const ['email'],
  );
  final googleAuth = googleUser.authentication;
  if (googleAuth.idToken == null) {
    throw FirebaseAuthException(
      code: 'missing-google-id-token',
      message: 'Google did not return an ID token for Firebase sign-in.',
    );
  }
  final credential = GoogleAuthProvider.credential(idToken: googleAuth.idToken);
  return FirebaseAuth.instance.signInWithCredential(credential);
}
```

**Logic:** Handles platform-specific Google authentication:
- **Web**: Uses `signInWithPopup()` with a `GoogleAuthProvider` when the standard `authenticate()` method is not supported.
- **Mobile**: Initializes `GoogleSignIn`, calls `authenticate()` to get the Google account, extracts the ID token, creates a Firebase credential from it, and signs in to Firebase with that credential. The `_googleSignInInitialization` is cached as a static variable so it only runs once.

```dart
@override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: Colors.black,
    body: SafeArea(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.sign_language, color: Colors.white, size: 92),
            const SizedBox(height: 20),
            const Text('SignLink', style: TextStyle(...)),
            const SizedBox(height: 8),
            const Text('Translate signs into live text', style: ...),
            const SizedBox(height: 44),
            ElevatedButton.icon(
              onPressed: _loading ? null : _signInWithGoogle,
              icon: _loading
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.login),
              label: Text(_loading ? 'Signing in...' : 'Sign in with Google'),
              style: ElevatedButton.styleFrom(...),
            ),
            if (_errorMessage != null) Text(_errorMessage!, style: ...),
          ],
        ),
      ),
    ),
  );
}
```

**Logic:** Builds the login UI on a black background. Shows the SignLink logo (a hand sign icon), the app name, a subtitle, and a Google sign-in button. When `_loading` is true, the button is disabled and shows a spinner. Error messages appear in red below the button if sign-in fails.

---

#### `translation_page.dart` — Simple Wrapper

```dart
class TranslationPage extends StatelessWidget {
  const TranslationPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const MainNavigationPage();
  }
}
```

**Logic:** A thin wrapper that returns `MainNavigationPage`. This exists so that `AuthGate` and `StartPage` can both navigate to `TranslationPage` without caring about the internal navigation structure. If the bottom nav structure changes, only this file needs updating.

---

#### `main_navigation_page.dart` — Bottom Navigation Bar

```dart
class _MainNavigationPageState extends State<MainNavigationPage> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    kIsWeb ? const CameraScreenWeb() : const CameraScreen(),
    const HistoryPage(),
    const _ProfileSection(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: Theme.of(context).primaryColor,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
```

**Logic:** The main shell after login. Uses `IndexedStack` to switch between 3 pages while preserving each page's state (so the camera doesn't re-initialize when switching tabs). `_currentIndex` tracks the selected tab. The `BottomNavigationBar` listens for taps and updates the index. The Home tab shows the camera (platform-appropriate version), History shows past translations, and Profile uses a special `_ProfileSection` widget.

```dart
class _ProfileSection extends StatefulWidget {
  const _ProfileSection({Key? key}) : super(key: key);

  @override
  _ProfileSectionState createState() => _ProfileSectionState();
}

class _ProfileSectionState extends State<_ProfileSection> {
  bool _showSettings = false;

  @override
  Widget build(BuildContext context) {
    if (_showSettings) {
      return MySettingsPage(
        onBack: () => setState(() => _showSettings = false),
      );
    }
    return ProfilePage(
      onGoToSettings: () => setState(() => _showSettings = true),
    );
  }
}
```

**Logic:** Manages sub-navigation within the Profile tab. When `_showSettings` is `false`, it shows `ProfilePage`. When the user taps "Settings" on the profile page, `_showSettings` becomes `true` and `MySettingsPage` is shown instead — the bottom navigation bar remains visible. The settings page receives an `onBack` callback to return to the profile page. This avoids pushing a separate route and keeps the bottom nav consistent.

---

#### `camera_screen.dart` — Mobile Camera + Prediction

```dart
class _CameraScreenState extends State<CameraScreen> {
  static const double _captureBoxSize = 200;
  static const double _minimumSkinRatio = 0.02;
  static const Duration _captureInterval = Duration(milliseconds: 250);
  static const Duration _repeatAcceptanceCooldown = Duration(milliseconds: 900);

  CameraController? _controller;
  bool _isInitialized = false;
  bool _recording = false;
  bool _isCameraOn = false;
  String output = "";
  String translation = "";
  String _finalTranslation = "";
  bool _loading = false;
  bool _isCapturing = false;
  final List<String> _phraseBuffer = [];
  // ...
}
```

**Logic:** State variables control every aspect of the camera screen:
- `_isCameraOn` starts `false` — camera is off by default.
- `_captureBoxSize` (200px) is the size of the centered square used for prediction.
- `_captureInterval` (250ms) controls how often frames are captured during recording.
- `_repeatAcceptanceCooldown` (900ms) prevents the same label from being appended too rapidly.
- `_phraseBuffer` accumulates detected letters/words.
- `_finalTranslation` stores the completed phrase after recording stops.

```dart
void _toggleCamera() {
  if (_isCameraOn) {
    _timer?.cancel();
    _controller?.dispose();
    if (mounted) {
      setState(() {
        _controller = null;
        _isInitialized = false;
        _isCameraOn = false;
        _recording = false;
      });
    }
  } else {
    _initCamera();
    if (mounted) {
      setState(() => _isCameraOn = true);
    }
  }
}
```

**Logic:** Toggles the camera on/off. When turning **off**, it cancels any active timer, disposes the `CameraController` (releasing the camera hardware), and resets all state. When turning **on**, it calls `_initCamera()` which requests permissions and initializes the camera controller.

```dart
Future<void> _initCamera() async {
  try {
    final hasPermissions = await _requestRequiredPermissions();
    if (!hasPermissions) return;

    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    _controller = CameraController(
      cameras.first,
      ResolutionPreset.medium,
      enableAudio: true,
    );

    await _controller!.initialize();
    if (mounted) setState(() => _isInitialized = true);
  } catch (e) {
    if (mounted) {
      setState(() {
        _permissionMessage =
            'Camera and microphone access are needed to translate signs while recording.';
      });
    }
  }
}
```

**Logic:** Initializes the camera in 3 steps:
1. Request camera + microphone permissions via `permission_handler`.
2. Get the list of available cameras and select the first (usually the front camera).
3. Create a `CameraController` with medium resolution and initialize it.

If permissions are denied or camera unavailable, `_permissionMessage` is set, triggering a permission-denied UI.

```dart
Future<void> _captureAndPredict() async {
  if (_controller == null || !_controller!.value.isInitialized) return;
  if (!_recording || _isCapturing) return;

  _isCapturing = true;
  setState(() => _loading = true);

  try {
    final XFile image = await _controller!.takePicture();
    final bytes = await image.readAsBytes();
    final croppedBytes = await _cropToCaptureBox(bytes);

    final hasForeground = _frameContainsForeground(croppedBytes);
    final response = await _sendToBackend(croppedBytes);

    if (response != null) {
      final predictedLabel = response['label'] ?? '';
      final conf = (response['confidence'] ?? 0.0).toDouble();
      final acceptedPrediction =
          (response['accepted'] ?? false) && predictedLabel != 'nothing';

      setState(() {
        confidenceScore = acceptedPrediction || hasForeground ? conf : 0.0;

        if (acceptedPrediction) {
          output = predictedLabel;
          boxColor = Colors.green;
          if (_shouldAppendPrediction(predictedLabel)) {
            _appendDetectedSign(predictedLabel);
            _lastAcceptedLabel = predictedLabel;
            _lastAcceptedAt = DateTime.now();
          }
        } else if (hasForeground && conf > 0.6) {
          output = '';
          boxColor = Colors.yellow;
        } else if (hasForeground) {
          output = '';
          boxColor = Colors.orange;
        } else {
          output = '';
          boxColor = Colors.red;
          _resetPredictionWindow();
        }
      });
    }
  } catch (e) {
    print("Capture error: $e");
  } finally {
    if (mounted) setState(() => _loading = false);
    _isCapturing = false;
  }
}
```

**Logic:** This is the core prediction loop, called every 250ms during recording:

1. **Capture**: Takes a photo with `takePicture()`, reads the bytes.
2. **Crop**: Centers and crops to a 200×200 square via `_cropToCaptureBox()`.
3. **Skin Detection**: Checks if a hand is present using `_frameContainsForeground()` (YCbCr color analysis).
4. **Backend Call**: Sends the cropped image to `http://10.0.2.2:5000/predict` as a multipart POST.

The response contains `{label, confidence, accepted}`. The state update handles 4 visual cases:
- **Green** `accepted == true` and label is not `'nothing'`: Shows the detected letter in the output box and appends it to the phrase buffer.
- **Yellow** hand detected and confidence > 60%: Hand detected but prediction uncertain.
- **Orange** hand detected but low confidence: Weak hand signal.
- **Red** no hand detected: Resets the prediction window.

`_isCapturing` prevents concurrent captures (a guard against timer overlap).

```dart
void _toggleRecording(String userId) {
  if (_recording) {
    _timer?.cancel();
    _finalTranslation = _phraseBuffer.join();
    if (userId.isNotEmpty && _finalTranslation.isNotEmpty) {
      _storeHistory(userId, _finalTranslation);
    }
    _speakTranslation();
    setState(() {
      _recording = false;
      _loading = false;
    });
  } else {
    _phraseBuffer.clear();
    _resetPredictionWindow();
    setState(() {
      _recording = true;
      translation = "";
      _finalTranslation = "";
      output = "";
      boxColor = Colors.red;
    });

    _captureAndPredict();
    _timer = Timer.periodic(_captureInterval, (timer) {
      _captureAndPredict();
    });
  }
}
```

**Logic:** Toggles recording on/off:
- **Start**: Clears the phrase buffer, resets state, sets `_recording = true`, immediately captures one frame, then starts a `Timer.periodic` that calls `_captureAndPredict()` every 250ms.
- **Stop**: Cancels the timer, joins the phrase buffer into `_finalTranslation`, saves to Firestore via `_storeHistory()`, and speaks the translation aloud with TTS via `_speakTranslation()`.

```dart
double _estimateSkinRatio(Uint8List imageBytes) {
  final decoded = img.decodeImage(imageBytes);
  if (decoded == null) return 0.0;

  final resized = img.copyResize(decoded, width: 24, height: 24,
      interpolation: img.Interpolation.average);

  var skinPixels = 0;
  final totalPixels = 24 * 24;

  for (var y = 0; y < 24; y++) {
    for (var x = 0; x < 24; x++) {
      final pixel = resized.getPixel(x, y);
      final r = pixel.r.toDouble();
      final g = pixel.g.toDouble();
      final b = pixel.b.toDouble();
      final luminance = 0.299 * r + 0.587 * g + 0.114 * b;
      final cb = 128 - 0.168736 * r - 0.331264 * g + 0.5 * b;
      final cr = 128 + 0.5 * r - 0.418688 * g - 0.081312 * b;

      final isSkin = cb >= 77 && cb <= 135 &&
          cr >= 133 && cr <= 180 &&
          luminance >= 30 && r > 40 && g > 20 && b > 10 &&
          r >= g * 0.9 && r >= b * 0.9;

      if (isSkin) skinPixels++;
    }
  }
  return skinPixels / totalPixels;
}
```

**Logic:** Detects skin (hand) presence using YCbCr color space. The image is first resized to 24×24 pixels for performance. Each pixel is converted from RGB to YCbCr using standard formulas. A pixel is classified as "skin" if its Cb, Cr, luminance, and RGB values fall within empirically-determined ranges. Returns the ratio of skin-colored pixels to total pixels. If this ratio exceeds `_minimumSkinRatio` (0.02), a hand is considered present.

```dart
Future<Uint8List> _cropToCaptureBox(Uint8List imageBytes) async {
  final codec = await ui.instantiateImageCodec(imageBytes);
  final frame = await codec.getNextFrame();
  final decoded = frame.image;

  final cropSize = math.min(decoded.width, decoded.height);
  final cropX = ((decoded.width - cropSize) / 2).roundToDouble();
  final cropY = ((decoded.height - cropSize) / 2).roundToDouble();

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawImageRect(
    decoded,
    Rect.fromLTWH(cropX, cropY, cropSize.toDouble(), cropSize.toDouble()),
    Rect.fromLTWH(0, 0, _captureBoxSize, _captureBoxSize),
    Paint(),
  );
  final cropped = await recorder.endRecording()
      .toImage(_captureBoxSize.toInt(), _captureBoxSize.toInt());
  final bytes = await cropped.toByteData(format: ui.ImageByteFormat.png);

  return bytes?.buffer.asUint8List() ?? imageBytes;
}
```

**Logic:** Crops the captured photo to a centered square. It decodes the image, calculates the largest centered square that fits within the photo, then uses `Canvas.drawImageRect()` to extract and resize that region to 200×200 pixels. This ensures the sign language gesture is centered and uniformly sized for the backend model.

```dart
void _appendDetectedSign(String label) {
  final normalizedLabel = label.trim();
  if (normalizedLabel.isEmpty || normalizedLabel == 'nothing') return;

  if (normalizedLabel == 'space') {
    _phraseBuffer.add(' ');
  } else if (normalizedLabel == 'del') {
    if (_phraseBuffer.isNotEmpty) _phraseBuffer.removeLast();
  } else if (normalizedLabel.length == 1) {
    _phraseBuffer.add(normalizedLabel);
  }

  translation = _phraseBuffer.join();
}
```

**Logic:** Processes a detected label:
- `'space'` → adds a space character to the buffer.
- `'del'` → removes the last character (backspace).
- Single letters (A-Z) → appends to the buffer.
- `'nothing'` or empty → ignored.
After mutation, `translation` is updated to the joined string of the buffer.

```dart
void _repeatPhrase() async {
  if (_finalTranslation.isEmpty) return;
  await _flutterTts.setLanguage("en-US");
  await _flutterTts.speak(_finalTranslation);
}
```

**Logic:** Repeats the last recorded phrase via TTS. This is triggered by a speaker icon button that appears next to the phrase after recording stops, allowing the user to hear the translation again.

**Build method — UI states:**

```dart
// Permission denied state
if (_permissionMessage != null) {
  return Scaffold(
    backgroundColor: Colors.black,
    body: Center(
      child: Column(children: [
        Icon(Icons.lock, color: Colors.white, size: 56),
        Text(_permissionMessage!, style: ...),
        ElevatedButton(onPressed: _openPermissionSettings, child: Text('Open settings')),
      ]),
    ),
  );
}
```

When permissions are denied, shows a lock icon, the permission message, and a button that opens system settings so the user can grant camera/mic access.

```dart
// Camera off state
if (!_isCameraOn) {
  return Scaffold(
    backgroundColor: Colors.black,
    body: Center(
      child: Column(children: [
        Icon(Icons.videocam_off, color: Colors.white54, size: 64),
        Text('Camera is off', style: ...),
        ElevatedButton.icon(
          onPressed: _toggleCamera,
          icon: Icon(Icons.videocam),
          label: Text('Turn Camera On'),
        ),
      ]),
    ),
  );
}
```

When the camera is off (default state), shows a camera-off icon, a "Camera is off" message, and a "Turn Camera On" button in the center. The camera only initializes when the user taps this button.

```dart
// Active camera state
return Scaffold(
  backgroundColor: Colors.black,
  body: Stack(
    children: [
      // Camera preview
      Container(
        foregroundDecoration: BoxDecoration(
          border: _recording ? Border.all(color: Colors.redAccent, width: 4) : null,
        ),
        child: Center(
          child: AspectRatio(
            aspectRatio: _controller!.value.aspectRatio,
            child: CameraPreview(_controller!),
          ),
        ),
      ),

      // Recording badge
      if (_recording)
        Positioned(top: 28, left: 16, child: SafeArea(
          child: Container(
            decoration: BoxDecoration(color: Colors.redAccent, borderRadius: ...),
            child: Row(children: [Icon(Icons.fiber_manual_record), Text('Recording')]),
          ),
        )),

      // Confidence score badge
      Positioned(top: 60, left: 0, right: 0, child: Center(
        child: Container(
          child: Text('${(confidenceScore * 100).toStringAsFixed(1)}%'),
        ),
      )),

      // Centered crop box
      Center(
        child: Container(
          width: _captureBoxSize, height: _captureBoxSize,
          decoration: BoxDecoration(
            border: Border.all(color: boxColor, width: 4),
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),

      // Detected sign + phrase display
      Positioned(left: 16, right: 16, bottom: 136, child: Center(
        child: Column(children: [
          // Current detected sign
          Container(child: Text(output.isEmpty ? 'Show sign' : output, ...)),
          SizedBox(height: 10),
          // Accumulated phrase with speaker icon
          Container(
            child: Row(children: [
              Expanded(child: Text(visiblePhrase, ...)),
              if (_finalTranslation.isNotEmpty)
                IconButton(
                  onPressed: _repeatPhrase,
                  icon: Icon(Icons.volume_up, color: Colors.white),
                  tooltip: 'Hear phrase again',
                ),
            ]),
          ),
        ]),
      )),

      // Camera toggle button (top-left)
      Positioned(top: 60, left: 16, child: SafeArea(
        child: IconButton(
          onPressed: _toggleCamera,
          icon: Icon(Icons.videocam_off, color: Colors.white, size: 28),
        ),
      )),

      // Record/Stop button
      Align(alignment: Alignment.bottomCenter,
        child: Container(
          height: 120,
          color: Colors.black87,
          child: ElevatedButton.icon(
            onPressed: () => _toggleRecording(userInfo.getUserId),
            icon: Icon(_recording ? Icons.stop : Icons.fiber_manual_record),
            label: Text(_recording ? 'Stop Recording' : 'Start Recording'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _recording ? Colors.red : Colors.green,
            ),
          ),
        ),
      ),
    ],
  ),
);
```

**Logic:** The active camera UI is built as a `Stack` with layers:
1. **Camera preview** fills the screen, with a red border overlay when recording.
2. **Recording badge** appears at top-left with a red dot + "Recording" text.
3. **Confidence score** centered at the top, colored to match the crop box.
4. **Crop box** centered on screen — color indicates state (green=match, yellow/orange=uncertain, red=no hand).
5. **Output display** shows the currently detected sign (large text) above the accumulated phrase (smaller blue container). After recording stops, a volume-up icon appears to replay the phrase.
6. **Camera toggle** button at top-left to turn camera off.
7. **Record/Stop button** at the bottom — green when idle, red during recording.

---

#### `camera_screen_web.dart` — Web Camera + Prediction

Key differences from mobile version:

```dart
import 'package:frontend/services/web_square_capture_stub.dart'
    if (dart.library.html) 'package:frontend/services/web_square_capture_web.dart';
```

**Logic:** Uses Dart's conditional imports. On web (where `dart:html` is available), it imports the real implementation. On other platforms, it imports a stub that returns `null`.

```dart
Future<void> _captureAndPredict() async {
  // ...
  final croppedBytes = await captureCenteredVideoSquare(_captureBoxSize);
  Uint8List imageBytes;
  if (croppedBytes == null) {
    final image = await _controller!.takePicture();
    final bytes = await image.readAsBytes();
    imageBytes = await _cropToCaptureBox(bytes);
  } else {
    imageBytes = croppedBytes;
  }
  // ...
}
```

**Logic:** On each capture tick, the web version first tries to capture directly from the browser's `<video>` element via `captureCenteredVideoSquare()` (which draws onto a canvas for better performance and lower latency). If that fails (returns null), it falls back to `takePicture()` + `_cropToCaptureBox()` like the mobile version.

```dart
Transform.scale(
  scaleX: -1,
  child: Container(
    child: Center(
      child: AspectRatio(
        aspectRatio: _controller!.value.aspectRatio,
        child: CameraPreview(_controller!),
      ),
    ),
  ),
),
```

**Logic:** The web version mirrors the camera preview horizontally (`scaleX: -1`) so the user sees a natural mirror image (like a selfie), making it easier to position their hands.

```dart
void _initTts() {
  _flutterTts = FlutterTts();
  _flutterTts!.setLanguage("en-US");
}
```

**Logic:** TTS is lazily initialized in its own method rather than inline, because on web the `FlutterTts` constructor may behave differently or need platform-specific setup.

The backend URL also differs — `http://127.0.0.1:5000/predict` instead of `http://10.0.2.2:5000/predict` (the Android emulator's host loopback address).

---

#### `history.dart` — Past Translations

```dart
class HistoryService {
  static CollectionReference<Map<String, dynamic>> _historyCollection(
      String userId) {
    return _firestore.collection('users').doc(userId).collection('history');
  }
}

class HistoryPage extends StatefulWidget {
  @override
  Widget build(BuildContext context) {
    final userInfo = Provider.of<UserInfo>(context);

    return Scaffold(
      appBar: AppBar(title: const Text("History")),
      body: StreamBuilder<List<HistoryEntry>>(
        stream: HistoryService.streamHistory(userInfo.getUserId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final entries = snapshot.data ?? [];
          if (entries.isEmpty) {
            return const Center(child: Text("No History"));
          }

          return ListView.builder(
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              return Dismissible(
                key: Key(entry.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  color: Colors.red,
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                onDismissed: (_) {
                  HistoryService.deleteEntry(userInfo.getUserId, entry.id);
                },
                child: ListTile(
                  title: Text(entry.phrase, style: const TextStyle(fontSize: 18)),
                  subtitle: entry.createdAt != null
                      ? Text('${entry.createdAt!.day}/${entry.createdAt!.month}/${entry.createdAt!.year} ...')
                      : null,
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () {
                      HistoryService.deleteEntry(userInfo.getUserId, entry.id);
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
```

**Logic:** Uses `StreamBuilder` to subscribe to a Firestore query that streams all history entries for the current user, ordered by creation time (newest first). While loading, shows a spinner. If empty, shows "No History". Each entry displays the phrase text and a formatted date. Entries can be deleted by either swiping left (`Dismissible`) or tapping the delete icon. Deletion calls `HistoryService.deleteEntry()` which removes the document from Firestore.

---

#### `profile_page.dart` — User Profile

```dart
class ProfilePage extends StatelessWidget {
  final VoidCallback? onGoToSettings;

  const ProfilePage({Key? key, this.onGoToSettings}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final userInfo = Provider.of<UserInfo>(context);
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        children: [
          const SizedBox(height: 32),
          Center(
            child: CircleAvatar(
              radius: 48,
              backgroundColor: Theme.of(context).primaryColor,
              child: Text(
                (user?.displayName ?? user?.email ?? 'U')[0].toUpperCase(),
                style: const TextStyle(fontSize: 40, color: Colors.white),
              ),
            ),
          ),
          Text(user?.displayName ?? 'User', style: ...),
          if (user?.email != null)
            Text(user!.email!, style: TextStyle(color: Colors.grey[600])),

          const Divider(),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('Settings'),
            trailing: const Icon(Icons.chevron_right),
            onTap: onGoToSettings,
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Log out'),
            onTap: () async {
              await FirebaseAuth.instance.signOut();
              try { await GoogleSignIn.instance.signOut(); } catch (_) {}
              userInfo.setUserId('');
              if (!context.mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const StartPage()),
                (route) => false,
              );
            },
          ),
        ],
      ),
    );
  }
}
```

**Logic:** Shows user info from FirebaseAuth:
- Avatar: First letter of display name or email in a colored circle.
- Name and email displayed below.
- **Settings** tile calls `onGoToSettings` callback (provided by `_ProfileSection` in `main_navigation_page.dart`) which switches the profile tab to the settings page.
- **Log out** signs out of Firebase and Google, clears the user ID, and removes all routes back to `StartPage` using `pushAndRemoveUntil`.

The `onGoToSettings` callback pattern avoids pushing a new route — the settings page appears within the same tab, keeping the bottom navigation bar visible.

---

#### `settings.dart` — App Settings

```dart
class MySettingsPage extends StatefulWidget {
  final VoidCallback? onBack;
  const MySettingsPage({Key? key, this.onBack}) : super(key: key);

  @override
  _MySettingsPageState createState() => _MySettingsPageState();
}

class _MySettingsPageState extends State<MySettingsPage> {
  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final userInfo = Provider.of<UserInfo>(context);

    return Scaffold(
      appBar: AppBar(
        leading: widget.onBack != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBack,
              )
            : null,
        title: const Text("Settings"),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          _buildSettingTile(
            icon: Icons.mode_night_outlined,
            title: "Dark/Light Mode",
            onTap: () => themeNotifier.changeThemeMode(),
          ),
          _buildSettingTile(
            icon: Icons.border_color_outlined,
            title: "Theme Color",
            onTap: () => chooseThemeColor(themeNotifier),
          ),
          _buildSettingTile(
            icon: Icons.format_size_sharp,
            title: "Text Size",
            onTap: () => _showFontSizePopUp(themeNotifier),
          ),
          const Divider(height: 32, indent: 16, endIndent: 16),
          _buildSettingTile(
            icon: userInfo.getUserId.isEmpty ? Icons.login : Icons.logout,
            title: userInfo.getUserId.isEmpty ? "Login" : "Log out",
            onTap: () async {
              // signs out and navigates to StartPage
            },
          ),
        ],
      ),
    );
  }
}
```

**Logic:** Displays settings options as `ListTile` widgets in a `ListView`:

1. **Dark/Light Mode** → `themeNotifier.changeThemeMode()`. Inside `ThemeNotifier`, this toggles `_isDark`, recreates `ThemeData` with `createThemeData(_color, _isDark, _fontSize)`, saves to `SharedPreferences`, and calls `notifyListeners()`.
2. **Theme Color** → Opens a dialog with 6 color circles. Each circle calls `themeNotifier.setThemeColor(color, colorName)` which updates the primary color, persists it, and notifies listeners.
3. **Text Size** → Opens a slider dialog (`FontSizePopUp`) with range 10–30. Sliding calls `themeNotifier.setFontSize(value)` on each change, which recreates the theme and notifies.
4. **Log out / Login** → Signs out and navigates to `StartPage`, or navigates to login if not authenticated.

The `onBack` callback from `_ProfileSection` enables a back arrow in the AppBar, allowing navigation back to the profile page without leaving the bottom nav.

**Theme Color Dialog:**
```dart
void chooseThemeColor(ThemeNotifier themeNotifier) {
  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text("Choose Theme Color"),
        content: Wrap(
          spacing: 20, runSpacing: 20,
          alignment: WrapAlignment.center,
          children: [
            colorCircle(themeNotifier, Colors.pink, 'pink'),
            colorCircle(themeNotifier, defaultColor, 'default'),
            colorCircle(themeNotifier, Colors.orange, 'orange'),
            colorCircle(themeNotifier, Colors.brown, 'brown'),
            colorCircle(themeNotifier, Colors.lightBlue, 'lightBlue'),
            colorCircle(themeNotifier, Colors.purple, 'purple'),
          ],
        ),
      );
    },
  );
}

Widget colorCircle(ThemeNotifier themeNotifier, MaterialColor color, String colorString) {
  return GestureDetector(
    onTap: () => themeNotifier.setThemeColor(color, colorString),
    child: Container(
      width: 56, height: 56,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.grey.shade300, width: 2),
      ),
    ),
  );
}
```

**Logic:** `chooseThemeColor()` shows an `AlertDialog` with 6 color circles wrapped in a `Wrap` layout. Each circle is a `GestureDetector` on a `Container` with circular decoration. Tapping a circle calls `themeNotifier.setThemeColor()` with the selected color, which updates the app's theme and persists the choice.

**Font Size Dialog:**
```dart
class _FontSizePopUpState extends State<FontSizePopUp> {
  late double _fontSize;

  @override
  void initState() {
    super.initState();
    _fontSize = widget.initialFontSize;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Font Size'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Slider(
            value: _fontSize, max: 30, min: 10, divisions: 20,
            label: _fontSize.round().toString(),
            onChanged: (double value) {
              setState(() {
                _fontSize = value;
                widget.themeNotifier.setFontSize(_fontSize);
              });
            },
          ),
          const SizedBox(height: 8),
          Text("SignLink", style: TextStyle(fontSize: _fontSize)),
        ],
      ),
    );
  }
}
```

**Logic:** Shows a dialog with a `Slider` (10–30, step 1) that adjusts font size in real time. As the user drags, `themeNotifier.setFontSize()` is called, which recreates the theme with the new size and calls `notifyListeners()`. A preview text ("SignLink") shows the current font size. The `late double _fontSize` is initialized from `widget.initialFontSize` (the current saved font size).

---

#### `app_sidebar.dart` — (Unused)

```dart
class AppSidebar extends StatelessWidget {
  const AppSidebar({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(children: [
        DrawerHeader(child: Text('SignLink', ...)),
        ListTile(leading: Icon(Icons.settings_outlined), title: Text('Settings'),
          onTap: () {
            Navigator.of(context).pop();
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MySettingsPage()),
            );
          },
        ),
        ListTile(leading: Icon(Icons.history), title: Text('History'),
          onTap: () {
            Navigator.of(context).pop();
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const HistoryPage()),
            );
          },
        ),
        Spacer(),
        ListTile(leading: Icon(Icons.logout), title: Text('Log out'), ...),
      ]),
    );
  }
}
```

**Logic:** This was the original drawer-based navigation (end drawer), accessible from a hamburger menu icon on the camera screen. It has been replaced by the bottom navigation bar. The file remains in the codebase but is no longer imported anywhere. It would navigate to Settings, History, or Log out by pushing new routes.

---

### Providers (`lib/provider/`)

#### `theme_model.dart` — ThemeNotifier

```dart
class ThemeNotifier extends ChangeNotifier {
  ThemeData _themeData;
  late bool _isDark;
  late String _colorName;
  late MaterialColor _color;
  late double _fontSize;

  ThemeData get getTheme => _themeData;

  ThemeNotifier(this._themeData) {
    getPreferences();
  }

  void getPreferences() async {
    SharedPreferences sharedPreferences = await SharedPreferences.getInstance();
    _isDark = sharedPreferences.getBool('isDark') ?? false;
    _colorName = sharedPreferences.getString('ThemeColor') ?? 'default';
    _fontSize = sharedPreferences.getDouble('fontSize') ?? 15;
    // Map colorName to MaterialColor...
  }

  void changeThemeMode() async {
    _isDark = !_isDark;
    _themeData = createThemeData(_color, _isDark, _fontSize);

    SharedPreferences sharedPreferences = await SharedPreferences.getInstance();
    sharedPreferences.setBool('isDark', _isDark);
    notifyListeners();
  }

  void setThemeColor(MaterialColor color, String colorName) async {
    _color = color;
    _colorName = colorName;
    _themeData = createThemeData(color, _isDark, _fontSize);

    SharedPreferences sharedPreferences = await SharedPreferences.getInstance();
    sharedPreferences.setString('ThemeColor', _colorName);
    notifyListeners();
  }

  setFontSize(double fontSize) async {
    _fontSize = fontSize;
    _themeData = createThemeData(_color, _isDark, _fontSize);

    SharedPreferences sharedPreferences = await SharedPreferences.getInstance();
    sharedPreferences.setDouble('fontSize', _fontSize);
    notifyListeners();
  }

  double getFontSize() => _fontSize;
}
```

**Logic:** `ThemeNotifier` is a `ChangeNotifier` that holds the complete app theme state:
- `changeThemeMode()` flips `_isDark` (dark/light), rebuilds `ThemeData` using `createThemeData()`, saves to `SharedPreferences`, and calls `notifyListeners()` so `MyApp` rebuilds with the new theme.
- `setThemeColor()` updates the primary `MaterialColor`, persists the color name, rebuilds `ThemeData`, and notifies.
- `setFontSize()` updates the font size, persists it, rebuilds `ThemeData`, and notifies.
- `getPreferences()` runs on construction to restore saved preferences from disk.

All three methods follow the same pattern: update internal state → persist to `SharedPreferences` → rebuild `ThemeData` → call `notifyListeners()`.

#### `user_info.dart` — UserInfo

```dart
class UserInfo {
  String _userId;

  UserInfo(this._userId);

  String get getUserId => _userId;

  void setUserId(String id) async {
    SharedPreferences sharedPreferences = await SharedPreferences.getInstance();
    sharedPreferences.setString("userId", id);
    _userId = id;
  }
}
```

**Logic:** A simple class that stores the current Firebase user ID and persists it to `SharedPreferences` whenever it changes. This allows the app to remember the user across app restarts (for cases where Firebase auth token might still be valid). The `getUserId` getter is used by camera screens, history, and profile to identify the user when saving/loading data from Firestore.

---

### Services (`lib/services/`)

#### `history_service.dart` — Firestore History

```dart
class HistoryEntry {
  const HistoryEntry({
    required this.id,
    required this.phrase,
    required this.createdAt,
  });

  final String id;
  final String phrase;
  final DateTime? createdAt;

  factory HistoryEntry.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final timestamp = data['createdAt'];
    return HistoryEntry(
      id: doc.id,
      phrase: (data['phrase'] ?? '').toString(),
      createdAt: timestamp is Timestamp ? timestamp.toDate() : null,
    );
  }
}

class HistoryService {
  HistoryService._();  // Prevent instantiation

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> _historyCollection(
      String userId) {
    return _firestore.collection('users').doc(userId).collection('history');
  }

  static Future<void> savePhrase(String userId, String phrase) async {
    final normalizedPhrase = phrase.trim();
    if (userId.isEmpty || normalizedPhrase.isEmpty) return;

    await _historyCollection(userId).add({
      'phrase': normalizedPhrase,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Stream<List<HistoryEntry>> streamHistory(String userId) {
    if (userId.isEmpty) return const Stream<List<HistoryEntry>>.empty();

    return _historyCollection(userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map(HistoryEntry.fromSnapshot)
            .where((entry) => entry.phrase.isNotEmpty)
            .toList());
  }

  static Future<void> deleteEntry(String userId, String entryId) async {
    if (userId.isEmpty || entryId.isEmpty) return;
    await _historyCollection(userId).doc(entryId).delete();
  }
}
```

**Logic:** Data layer for translation history stored in Firestore:

- `HistoryEntry` model: Maps a Firestore document to a Dart object with `id`, `phrase`, and `createdAt`. The `fromSnapshot` factory handles the Firestore `Timestamp` conversion.
- `savePhrase()`: Adds a new document to `users/{userId}/history` with the phrase text and a server timestamp. Uses `FieldValue.serverTimestamp()` so the timestamp is set by Firestore (not the client clock).
- `streamHistory()`: Returns a real-time `Stream` that emits a new list whenever the history collection changes. Results are ordered by `createdAt` descending (newest first). Empty phrases are filtered out.
- `deleteEntry()`: Deletes a specific history document by its document ID.

Data path: `users/{userId}/history/{auto-generated-document-id}`

#### `web_square_capture_web.dart` — Web Video Capture

```dart
import 'dart:html' as html;

Future<Uint8List?> captureCenteredVideoSquare(double outputSize) async {
  html.VideoElement? video;
  final videoElements = html.document.querySelectorAll('video');
  for (final element in videoElements) {
    if (element is html.VideoElement &&
        element.videoWidth > 0 && element.videoHeight > 0) {
      if (video == null ||
          element.videoWidth * element.videoHeight >
              video.videoWidth * video.videoHeight) {
        video = element;
      }
    }
  }

  if (video == null || video.videoWidth == 0 || video.videoHeight == 0) {
    return null;
  }

  final sourceSize = math.min(video.videoWidth, video.videoHeight);
  final sourceX = ((video.videoWidth - sourceSize) / 2).round();
  final sourceY = ((video.videoHeight - sourceSize) / 2).round();
  final canvasSize = outputSize.round();

  final canvas = html.CanvasElement(width: canvasSize, height: canvasSize);
  final context = canvas.context2D;

  context.drawImageScaledFromSource(
    video, sourceX, sourceY, sourceSize, sourceSize,
    0, 0, canvasSize, canvasSize,
  );

  final blob = await canvas.toBlob('image/png');
  final reader = html.FileReader();
  final completer = Completer<Uint8List?>();

  reader.onLoad.first.then((_) {
    final result = reader.result;
    if (result is ByteBuffer) {
      completer.complete(result.asUint8List());
    } else {
      completer.complete(null);
    }
  });
  reader.onError.first.then((_) => completer.complete(null));
  reader.readAsArrayBuffer(blob);

  return completer.future;
}
```

**Logic:** This function is only available on web (conditional import). It:

1. Finds the largest active `<video>` element on the page (the camera preview).
2. Calculates the largest centered square from the video dimensions.
3. Draws that square region onto an off-screen `<canvas>`, scaled to `outputSize`.
4. Converts the canvas to a PNG blob.
5. Reads the blob as an `ArrayBuffer` using `FileReader` (wrapped in a `Completer` for async/await compatibility).
6. Returns the bytes as `Uint8List`.

This approach is faster and more reliable than `takePicture()` on web because it avoids the photo capture pipeline and directly accesses the video stream.

#### `web_square_capture_stub.dart` — Web Fallback

```dart
import 'dart:typed_data';
Future<Uint8List?> captureCenteredVideoSquare(double outputSize) async => null;
```

**Logic:** Stub that always returns `null`. Imported on non-web platforms where `dart:html` is not available. The camera screen web code checks if this returns null and falls back to `takePicture()`.

---

### Test (`test/widget_test.dart`)

```dart
void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(MyApp());
    expect(find.text('0'), findsOneWidget);
    expect(find.text('1'), findsNothing);
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    expect(find.text('0'), findsNothing);
    expect(find.text('1'), findsOneWidget);
  });
}
```

**Logic:** This is the default Flutter template test and does not match the actual app. It tries to find a counter widget that doesn't exist in SignLink. **This test will fail.** It needs to be rewritten to test SignLink-specific functionality (e.g., verifying the app renders the auth gate or sign-in button).

---

### Dependencies (`pubspec.yaml`)

```yaml
dependencies:
  camera: ^0.11.0                        # Mobile camera controller
  tflite: ^1.1.2                          # TFLite model runner (stub)
  flutter_tts: ^4.2.0                     # Text-to-speech
  provider: ^6.1.2                        # State management
  shared_preferences: ^2.3.3              # Local key-value storage
  http: ^1.2.2                            # HTTP client for backend API
  image: ^4.3.0                           # Image processing (skin detection)
  firebase_core: ^3.8.0                   # Firebase initialization
  cloud_firestore: ^5.6.12                # Firestore database
  firebase_auth: ^5.7.0                   # Firebase Authentication
  google_sign_in: ^7.2.0                  # Google Sign-In
  permission_handler: ^12.0.1             # Runtime permissions
  html: ^0.15.5                           # Web DOM access (video capture)
```

---

## Data Flow

```
┌─────────────┐     ┌──────────────┐     ┌────────────────┐
│  StartPage   │────>│  AuthGate    │────>│ MainNavigation  │
│  (sign-in)   │     │  (auth gate) │     │    Page         │
└─────────────┘     └──────────────┘     └───────┬────────┘
                                                  │
                    ┌─────────────────────────────┼─────────────────────┐
                    │                             │                     │
                    ▼                             ▼                     ▼
            ┌───────────────┐            ┌──────────────┐     ┌──────────────┐
            │  Home (index 0)│            │ History (1)  │     │ Profile (2)  │
            │  CameraScreen  │            │  HistoryPage │     │ ProfilePage  │
            └───────┬───────┘            └──────────────┘     └──────┬───────┘
                    │                                                 │
        Start Recording                                               │
            │                                                  ┌──────┴──────┐
            ▼                                                  │             │
    ┌───────────────┐                                    Profile         Settings
    │ Timer.periodic │                                    Page           Page
    │  (250ms)       │                                    (default)      (onBack)
    └───────┬───────┘
            │
    ┌───────┴──────────────────┐
    │  1. takePicture()         │
    │  2. _cropToCaptureBox()   │
    │  3. _frameContainsForeground()
    │  4. POST /predict         │
    │  5. Parse response        │
    │  6. Update phrase buffer  │
    └───────────────────────────┘
            │
            ▼
    ┌───────────────┐
    │ Stop Recording │
    ├────────────────┤
    │ save to Firestore
    │ speak via TTS   │
    │ show speaker icon│
    └────────────────┘
```

---

## Backend API

The Flask backend (at `backend/main.py`) exposes:

| Method | Endpoint | Purpose |
|--------|----------|---------|
| POST | `/predict` | Accepts image → returns `{label, confidence, accepted, source}` |
| POST | `/history` | Save a phrase |
| GET | `/history` | Retrieve phrase history |
| POST | `/register` | Create account |
| POST | `/login` | Authenticate |
| POST | `/tts` | Text-to-speech audio |

Prediction uses a 3-stage cascade:
1. **Reference image similarity** — cosine similarity against pre-loaded reference images for each label.
2. **MediaPipe Hand Landmarker + keypoint classifier** — detects 21 hand landmarks, normalizes them, runs through a separate keypoint TFLite model.
3. **Standard TFLite model** — the main `model.tflite` (64×64 grayscale input, 29 classes: A–Z, del, nothing, space).

The first stage that produces a confident enough result wins, with later stages serving as fallbacks.

---

## Key Design Decisions

1. **Camera off by default** — saves battery and avoids unnecessary permission prompts. The user consciously enables the camera by tapping a button.

2. **Bottom navigation over drawer** — the 3 main tabs (Home, History, Profile) are always one tap away, more discoverable than a hidden drawer menu.

3. **Settings embedded in Profile tab** — uses `_ProfileSection` state management to swap between Profile and Settings within the same tab, keeping the bottom nav visible. No separate route navigation needed.

4. **Backend ML** — the heavy TFLite model runs on a Python server, not the device. This keeps the app lightweight and allows model updates without app store deployment.

5. **Provider over complex state management** — `ChangeNotifier` + `Provider` is sufficient for this app's needs. The theme state is the only globally reactive state; user info is passed via simple dependency injection.

6. **IndexedStack** — preserves each tab's widget state across tab switches. The camera doesn't re-initialize when switching from Home to History and back.

7. **Conditional imports for web** — the web camera screen uses Dart's `if (dart.library.html)` conditional import pattern to use `dart:html` for direct video canvas capture, with a stub fallback for mobile.

8. **YCbCr skin detection** — a lightweight client-side check runs before every backend call. If no hand is detected (low skin ratio), the prediction request is still sent but the UI provides immediate visual feedback (red/orange/yellow crop box).
