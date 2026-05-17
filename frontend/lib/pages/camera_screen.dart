import 'dart:convert';
import 'dart:typed_data';
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:image/image.dart' as img;
import 'package:frontend/const/api_config.dart';
import 'package:frontend/provider/user_info.dart';
import 'package:frontend/services/history_service.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({Key? key}) : super(key: key);

  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  static const double _captureBoxSize = 200;
  static const int _signatureSize = 24;
  static const double _minimumSkinRatio = 0.02;
  static const Duration _captureInterval = Duration(milliseconds: 250);
  static const Duration _repeatAcceptanceCooldown = Duration(milliseconds: 900);

  CameraController? _controller;
  bool _isInitialized = false;
  final FlutterTts _flutterTts = FlutterTts();

  bool _recording = false;
  Timer? _timer;
  String output = "";
  String translation = "";
  String _finalTranslation = "";
  double confidenceScore = 0.0;
  Color boxColor = Colors.black;
  bool _loading = false;
  bool _isCapturing = false;
  bool _isCameraOn = false;
  String? _permissionMessage;
  final List<String> _phraseBuffer = [];
  String? _lastAcceptedLabel;
  DateTime? _lastAcceptedAt;

  @override
  void initState() {
    super.initState();
  }

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
      if (mounted) {
        setState(() => _isInitialized = true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _permissionMessage =
              'Camera and microphone access are needed to translate signs while recording.';
        });
      }
      print("Camera init error: $e");
    }
  }

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

  Future<bool> _requestRequiredPermissions() async {
    final statuses = await [
      Permission.camera,
      Permission.microphone,
    ].request();
    final cameraStatus = statuses[Permission.camera];
    final microphoneStatus = statuses[Permission.microphone];
    final denied = cameraStatus == null ||
        microphoneStatus == null ||
        cameraStatus.isDenied ||
        cameraStatus.isPermanentlyDenied ||
        cameraStatus.isRestricted ||
        microphoneStatus.isDenied ||
        microphoneStatus.isPermanentlyDenied ||
        microphoneStatus.isRestricted;

    if (denied && mounted) {
      setState(() {
        _permissionMessage =
            'SignLink needs camera access for signs and microphone access while recording. Enable both permissions in system settings.';
      });
    }

    return !denied;
  }

  Future<void> _openPermissionSettings() async {
    await openAppSettings();
  }

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
      if (mounted) {
        setState(() => _loading = false);
      }
      _isCapturing = false;
    }
  }

  double _estimateSkinRatio(Uint8List imageBytes) {
    final decoded = img.decodeImage(imageBytes);
    if (decoded == null) return 0.0;

    final resized = img.copyResize(
      decoded,
      width: _signatureSize,
      height: _signatureSize,
      interpolation: img.Interpolation.average,
    );

    var skinPixels = 0;
    final totalPixels = _signatureSize * _signatureSize;

    for (var y = 0; y < _signatureSize; y++) {
      for (var x = 0; x < _signatureSize; x++) {
        final pixel = resized.getPixel(x, y);
        final r = pixel.r.toDouble();
        final g = pixel.g.toDouble();
        final b = pixel.b.toDouble();
        final luminance = 0.299 * r + 0.587 * g + 0.114 * b;
        final cb = 128 - 0.168736 * r - 0.331264 * g + 0.5 * b;
        final cr = 128 + 0.5 * r - 0.418688 * g - 0.081312 * b;

        final isSkin = cb >= 77 &&
            cb <= 135 &&
            cr >= 133 &&
            cr <= 180 &&
            luminance >= 30 &&
            r > 40 &&
            g > 20 &&
            b > 10 &&
            r >= g * 0.9 &&
            r >= b * 0.9;

        if (isSkin) {
          skinPixels++;
        }
      }
    }

    return skinPixels / totalPixels;
  }

  bool _frameContainsForeground(Uint8List imageBytes) {
    return _estimateSkinRatio(imageBytes) >= _minimumSkinRatio;
  }

  void _resetPredictionWindow() {
    _lastAcceptedLabel = null;
    _lastAcceptedAt = null;
  }

  bool _shouldAppendPrediction(String label) {
    final lastAcceptedAt = _lastAcceptedAt;
    if (_lastAcceptedLabel != label || lastAcceptedAt == null) {
      return true;
    }

    return DateTime.now().difference(lastAcceptedAt) >=
        _repeatAcceptanceCooldown;
  }

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
    final cropped = await recorder
        .endRecording()
        .toImage(_captureBoxSize.toInt(), _captureBoxSize.toInt());
    final bytes = await cropped.toByteData(format: ui.ImageByteFormat.png);

    return bytes?.buffer.asUint8List() ?? imageBytes;
  }

  Future<Map<String, dynamic>?> _sendToBackend(Uint8List imageBytes) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse(ApiConfig.predictUrl),
      );
      request.files.add(http.MultipartFile.fromBytes(
        'image',
        imageBytes,
        filename: 'capture.png',
      ));

      var streamedResponse = await request.send().timeout(
            const Duration(seconds: 10),
          );
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      print("Backend error: $e");
    }
    return null;
  }

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

  void _storeHistory(String userId, String translation) async {
    try {
      await HistoryService.savePhrase(userId, translation);
    } catch (e) {
      print("Store history error: $e");
    }
  }

  void _speakTranslation() async {
    if (translation.isEmpty) return;
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.speak(translation);
  }

  void _repeatPhrase() async {
    if (_finalTranslation.isEmpty) return;
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.speak(_finalTranslation);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userInfo = Provider.of<UserInfo>(context);

    if (_permissionMessage != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock, color: Colors.white, size: 56),
                const SizedBox(height: 18),
                Text(
                  _permissionMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 17),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _openPermissionSettings,
                  child: const Text('Open settings'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (!_isCameraOn) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.videocam_off, color: Colors.white54, size: 64),
              const SizedBox(height: 20),
              const Text(
                'Camera is off',
                style: TextStyle(color: Colors.white54, fontSize: 22),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _toggleCamera,
                icon: const Icon(Icons.videocam),
                label: const Text('Turn Camera On'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (!_isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 16),
              Text('Initializing camera...',
                  style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
      );
    }

    final visiblePhrase = translation.isNotEmpty
        ? translation
        : _finalTranslation.isNotEmpty
            ? _finalTranslation
            : _recording
                ? 'Signing...'
                : 'Press Start Recording';

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Container(
            foregroundDecoration: BoxDecoration(
              border: _recording
                  ? Border.all(color: Colors.redAccent, width: 4)
                  : null,
            ),
            color: Colors.black,
            child: Center(
              child: AspectRatio(
                aspectRatio: _controller!.value.aspectRatio,
                child: CameraPreview(_controller!),
              ),
            ),
          ),
          if (_recording)
            Positioned(
              top: 28,
              left: 16,
              child: SafeArea(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.fiber_manual_record,
                          color: Colors.white, size: 14),
                      SizedBox(width: 8),
                      Text(
                        'Recording',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            top: 60,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${(confidenceScore * 100).toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: boxColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          Center(
            child: Container(
              width: _captureBoxSize,
              height: _captureBoxSize,
              decoration: BoxDecoration(
                border: Border.all(color: boxColor, width: 4),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 136,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Text(
                        output.isEmpty ? 'Show sign' : output,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.82),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Expanded(
                            child: Text(
                              visiblePhrase,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (_finalTranslation.isNotEmpty)
                            IconButton(
                              onPressed: _repeatPhrase,
                              icon: const Icon(Icons.volume_up,
                                  color: Colors.white),
                              tooltip: 'Hear phrase again',
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_loading)
            const Positioned(
              top: 16,
              left: 16,
              child: CircularProgressIndicator(color: Colors.white),
            ),
          Positioned(
            top: 60,
            left: 16,
            child: SafeArea(
              child: IconButton(
                onPressed: _toggleCamera,
                icon: const Icon(Icons.videocam_off, color: Colors.white, size: 28),
              ),
            ),
          ),
          
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              height: 120,
              color: Colors.black87,
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 24),
              child: ElevatedButton.icon(
                onPressed: () => _toggleRecording(userInfo.getUserId),
                icon: Icon(_recording ? Icons.stop : Icons.fiber_manual_record),
                label: Text(
                  _recording ? 'Stop Recording' : 'Start Recording',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _recording ? Colors.red : Colors.green,
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
