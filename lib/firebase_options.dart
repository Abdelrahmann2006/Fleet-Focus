import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError('Unsupported platform: $defaultTargetPlatform');
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBWKCvAH2_hYbE5_jtQbK2OQg2eWdN_8po',
    appId: '1:80732158852:web:d15ddb687451798476fbd1',
    messagingSenderId: '80732158852',
    projectId: 'panopticon-afbec',
    storageBucket: 'panopticon-afbec.firebasestorage.app',
    databaseURL: 'https://panopticon-afbec-default-rtdb.firebaseio.com',
    authDomain: 'panopticon-afbec.firebaseapp.com',
  );

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
