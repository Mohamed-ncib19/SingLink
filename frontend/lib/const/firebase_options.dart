import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBVKzUnJiV2koBKwgl9IhfdDRP9GnQd46I',
    appId: '1:632639747392:web:76d603b084ba7a535876a5',
    messagingSenderId: '632639747392',
    projectId: 'signlink-5f735',
    authDomain: 'signlink-5f735.firebaseapp.com',
    storageBucket: 'signlink-5f735.firebasestorage.app',
    measurementId: 'G-0NR5BWCS1J',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBVKzUnJiV2koBKwgl9IhfdDRP9GnQd46I',
    appId: '1:632639747392:android:YOUR_ANDROID_APP_ID',
    messagingSenderId: '632639747392',
    projectId: 'signlink-5f735',
    storageBucket: 'signlink-5f735.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBVKzUnJiV2koBKwgl9IhfdDRP9GnQd46I',
    appId: '1:632639747392:ios:YOUR_IOS_APP_ID',
    messagingSenderId: '632639747392',
    projectId: 'signlink-5f735',
    storageBucket: 'signlink-5f735.firebasestorage.app',
    iosClientId: 'YOUR_IOS_CLIENT_ID',
    iosBundleId: 'com.example.frontend',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyBVKzUnJiV2koBKwgl9IhfdDRP9GnQd46I',
    appId: '1:632639747392:macos:YOUR_MACOS_APP_ID',
    messagingSenderId: '632639747392',
    projectId: 'signlink-5f735',
    storageBucket: 'signlink-5f735.firebasestorage.app',
    iosClientId: 'YOUR_IOS_CLIENT_ID',
    iosBundleId: 'com.example.frontend',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyBVKzUnJiV2koBKwgl9IhfdDRP9GnQd46I',
    appId: '1:632639747392:windows:YOUR_WINDOWS_APP_ID',
    messagingSenderId: '632639747392',
    projectId: 'signlink-5f735',
    storageBucket: 'signlink-5f735.firebasestorage.app',
  );
}
