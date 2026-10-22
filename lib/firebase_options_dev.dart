// Remplacer ce fichier avec:
// flutterfire configure --project=mecawaga-dev --platforms=android,ios \
//   --out=lib/firebase_options_dev.dart
//
// Les valeurs ci-dessous sont des marqueurs pour garder la structure du projet
// en place avant la configuration FlutterFire reelle.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        throw UnsupportedError(
          'Firebase dev est configure uniquement pour Android et iOS.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'DEV_ANDROID_API_KEY',
    appId: 'DEV_ANDROID_APP_ID',
    messagingSenderId: 'DEV_MESSAGING_SENDER_ID',
    projectId: 'mecawaga-dev',
    storageBucket: 'mecawaga-dev.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'DEV_IOS_API_KEY',
    appId: 'DEV_IOS_APP_ID',
    messagingSenderId: 'DEV_MESSAGING_SENDER_ID',
    projectId: 'mecawaga-dev',
    storageBucket: 'mecawaga-dev.firebasestorage.app',
    iosBundleId: 'com.example.mecawaga',
  );
}
