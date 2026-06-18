// Generated from google-services.json (project: fluttercourse-87a9d)
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) throw UnsupportedError('Web not supported');
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError('Unsupported platform: $defaultTargetPlatform');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey:            'AIzaSyBzA5HY006rP5jj5b7WQRL-yQk7IORg5XA',
    appId:             '1:510460102100:android:8b67f45321a9de058a4241',
    messagingSenderId: '510460102100',
    projectId:         'fluttercourse-87a9d',
    storageBucket:     'fluttercourse-87a9d.firebasestorage.app',
  );

  // Add iOS config if you add an iOS app in Firebase Console
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey:            'AIzaSyBzA5HY006rP5jj5b7WQRL-yQk7IORg5XA',
    appId:             '1:510460102100:ios:REPLACE_WITH_IOS_APP_ID',
    messagingSenderId: '510460102100',
    projectId:         'fluttercourse-87a9d',
    storageBucket:     'fluttercourse-87a9d.firebasestorage.app',
    iosBundleId:       'com.example.teacherBooking',
  );
}
