// ════════════════════════════════════════════════════════════════════════
//  ملف firebase_options.dart يجب توليده عبر FlutterFire CLI
//  لا تملأ هذه القيم يدوياً — شغّل الأمر التالي في مجلد المشروع:
//
//  1) dart pub global activate flutterfire_cli
//  2) flutterfire configure --project=panopticon-afbec
//
//  ستُنشأ هذا الملف تلقائياً بعد إضافة google-services.json
//  إلى android/app/
// ════════════════════════════════════════════════════════════════════════

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

  // ══════════════════════════════════════════════
  //  استبدل هذه القيم بما يُولّده FlutterFire CLI
  // ══════════════════════════════════════════════
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBWKCvAH2_hYbE5_jtQbK2OQg2eWdN_8po',
    appId: '1:80732158852:android:d15ddb687451798476fbd1',
    messagingSenderId: '80732158852',
    projectId: 'panopticon-afbec',
    storageBucket: 'panopticon-afbec.firebasestorage.app',
    databaseURL: 'https://panopticon-afbec-default-rtdb.firebaseio.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBWKCvAH2_hYbE5_jtQbK2OQg2eWdN_8po',
    appId: '1:80732158852:ios:d15ddb687451798476fbd1',
    messagingSenderId: '80732158852',
    projectId: 'panopticon-afbec',
    storageBucket: 'panopticon-afbec.firebasestorage.app',
    iosClientId: '',
    iosBundleId: 'com.abdelrahman.panopticon',
  );
}
