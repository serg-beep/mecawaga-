import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart' as dev;
import '../../firebase_options_prod.dart' as prod;

enum FirebaseEnvironment {
  dev,
  prod;

  static FirebaseEnvironment fromDartDefine() {
    const value = String.fromEnvironment('MECAWAGA_ENV', defaultValue: 'dev');
    return value == 'prod' ? FirebaseEnvironment.prod : FirebaseEnvironment.dev;
  }
}

class MecaWagaFirebase {
  const MecaWagaFirebase._();

  static FirebaseEnvironment get environment =>
      FirebaseEnvironment.fromDartDefine();

  static FirebaseOptions get options => switch (environment) {
    FirebaseEnvironment.dev => dev.DefaultFirebaseOptions.currentPlatform,
    FirebaseEnvironment.prod => prod.DefaultFirebaseOptions.currentPlatform,
  };

  static bool get isDevelopment => environment == FirebaseEnvironment.dev;
  static bool get isProduction => environment == FirebaseEnvironment.prod;

  static Future<void> initialize() async {
    if (kReleaseMode) {
      if (!isProduction) {
        throw StateError(
          'La version publiée doit être compilée avec MECAWAGA_ENV=prod.',
        );
      }
    }
    if (isProduction &&
        (options.projectId != 'mecawaga-prod' ||
            options.apiKey.startsWith('PROD_') ||
            options.appId.startsWith('PROD_'))) {
      throw StateError(
        'Configurez les options Firebase de production avant la publication.',
      );
    }
    if (isDevelopment &&
        (options.apiKey.startsWith('DEV_') ||
            options.appId.startsWith('DEV_') ||
            options.messagingSenderId.startsWith('DEV_'))) {
      throw StateError(
        'Configurez les options Firebase de developpement avant de lancer l app.',
      );
    }
    try {
      await Firebase.initializeApp(options: options);
    } on FirebaseException catch (e) {
      if (e.code != 'duplicate-app') rethrow;
    }

    await FirebaseAppCheck.instance.activate(
      providerAndroid: isDevelopment
          ? const AndroidDebugProvider()
          : const AndroidPlayIntegrityProvider(),
      providerApple: isDevelopment
          ? const AppleDebugProvider()
          : const AppleDeviceCheckProvider(),
    );
    if (kDebugMode) {
      debugPrint('Firebase initialise: ${environment.name}');
    }
  }
}
