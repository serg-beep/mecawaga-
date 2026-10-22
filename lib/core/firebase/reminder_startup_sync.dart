import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/auth_providers.dart';
import '../../features/auth/domain/utilisateur.dart';
import '../../features/proprietaire/data/notification_service.dart';
import '../../features/proprietaire/data/proprietaire_providers.dart';
import '../../features/proprietaire/domain/rappel.dart';

class ReminderStartupSync extends ConsumerStatefulWidget {
  const ReminderStartupSync({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<ReminderStartupSync> createState() =>
      _ReminderStartupSyncState();
}

class _ReminderStartupSyncState extends ConsumerState<ReminderStartupSync> {
  String? _lastUserId;

  @override
  Widget build(BuildContext context) {
    ref.listen(currentUserProvider, (previous, next) {
      final user = next.valueOrNull;
      if (user != null && user.id != _lastUserId) {
        _lastUserId = user.id;
        unawaited(_reschedule(user));
      }
    });
    return widget.child;
  }

  Future<void> _reschedule(Utilisateur user) async {
    if (Firebase.apps.isEmpty || user.role != RoleUtilisateur.proprietaire) {
      return;
    }
    try {
      final repository = ref.read(proprietaireRepositoryProvider);
      final motos = await repository.getMotos();
      final reminders = <({Rappel rappel, String motoNom})>[];
      for (final moto in motos) {
        final motoReminders = await repository.getRappels(moto.id);
        reminders.addAll(
          motoReminders.map((rappel) => (rappel: rappel, motoNom: moto.nom)),
        );
      }
      await NotificationService.instance.rescheduleAll(reminders);
    } on Exception catch (error, stackTrace) {
      debugPrint('Impossible de reprogrammer les rappels locaux : $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }
}
