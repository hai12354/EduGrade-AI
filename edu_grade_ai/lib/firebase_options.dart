import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android: return android;
      case TargetPlatform.iOS: return ios;
      default:
        throw UnsupportedError('Nền tảng này không được hỗ trợ.');
    }
  }

  // Đây là mã chuẩn lấy từ ảnh image_e75c44.png của bạn
  static const String _sharedApiKey = 'AIzaSyBYrGGRmQzPFmx416QIXy8sTMNGSMja8qE';

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: _sharedApiKey,
    appId: '1:794720308594:web:39742b3467ce277276a1eb',
    messagingSenderId: '794720308594',
    projectId: 'edugrade-ai-4a07f',
    authDomain: 'edugrade-ai-4a07f.firebaseapp.com',
    storageBucket: 'edugrade-ai-4a07f.firebasestorage.app',
    measurementId: 'G-LDBEBTPZV9',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: _sharedApiKey,
    appId: '1:794720308594:android:26a3782b794720308594',
    messagingSenderId: '794720308594',
    projectId: 'edugrade-ai-4a07f',
    storageBucket: 'edugrade-ai-4a07f.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: _sharedApiKey,
    appId: '1:794720308594:ios:07966bc0e77f16da76a1eb',
    messagingSenderId: '794720308594',
    projectId: 'edugrade-ai-4a07f',
    storageBucket: 'edugrade-ai-4a07f.firebasestorage.app',
    iosBundleId: 'com.example.edu.grade.ai',
  );
}