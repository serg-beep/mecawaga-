import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/auth_repository.dart';
import '../domain/utilisateur.dart';
import 'auth_service.dart';
import 'firebase_auth_repository.dart';

final authServiceProvider = Provider<AuthRepository>((ref) {
  final repository = Firebase.apps.isEmpty
      ? AuthService()
      : FirebaseAuthRepository();
  ref.onDispose(repository.dispose);
  return repository;
});

final currentUserProvider = StreamProvider<Utilisateur?>((ref) {
  final repository = ref.watch(authServiceProvider);
  return repository.authStateChanges();
});

final currentRoleProvider = Provider<RoleUtilisateur?>((ref) {
  final asyncUser = ref.watch(currentUserProvider);
  return asyncUser.valueOrNull?.role ??
      ref.watch(authServiceProvider).utilisateurConnecte?.role;
});
