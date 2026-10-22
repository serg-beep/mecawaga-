// Remplacer ce fichier avec:
// flutterfire configure --project=mecawaga-prod --platforms=android,ios \
//   --out=lib/firebase_options_prod.dart
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
          'Firebase prod est configure uniquement pour Android et iOS.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'PROD_ANDROID_API_KEY',
    appId: 'PROD_ANDROID_APP_ID',
    messagingSenderId: 'PROD_MESSAGING_SENDER_ID',
    projectId: 'mecawaga-prod',
    storageBucket: 'mecawaga-prod.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'PROD_IOS_API_KEY',
    appId: 'PROD_IOS_APP_ID',
    messagingSenderId: 'PROD_MESSAGING_SENDER_ID',
    projectId: 'mecawaga-prod',
    storageBucket: 'mecawaga-prod.firebasestorage.app',
    iosBundleId: 'com.example.mecawaga',
  );
}
