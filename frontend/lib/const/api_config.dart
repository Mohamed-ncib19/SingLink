import 'package:flutter/foundation.dart';

class ApiConfig {
  ApiConfig._();

  static String get baseUrl {
    if (kIsWeb) {
      return const String.fromEnvironment(
        'BACKEND_URL',
        defaultValue: 'http://127.0.0.1:5000',
      );
    }
    return const String.fromEnvironment(
      'BACKEND_URL',
      defaultValue: 'http://10.0.2.2:5000',
    );
  }

  static String get predictUrl => '$baseUrl/predict';
}
