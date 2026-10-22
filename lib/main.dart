import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_performance/firebase_performance.dart';

import 'app.dart';
import 'core/firebase/firebase_environment.dart';
import 'core/firebase/reminder_startup_sync.dart';
import 'features/proprietaire/data/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MecaWagaFirebase.initialize();
  final startupTrace = FirebasePerformance.instance.newTrace('app_startup');
  await startupTrace.start();
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };
  await initializeDateFormatting('fr_FR');
  tzdata.initializeTimeZones();
  await NotificationService.instance.initialize();
  await startupTrace.stop();
  runApp(const ProviderScope(child: ReminderStartupSync(child: MecawagaApp())));
}
