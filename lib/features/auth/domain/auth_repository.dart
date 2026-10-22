import 'package:flutter/foundation.dart';

import 'utilisateur.dart';

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract class AuthRepository extends ChangeNotifier {
  Utilisateur? get utilisateurConnecte;

  Stream<Utilisateur?> authStateChanges();

  Future<Utilisateur> signIn({
    required String identifiant,
    required String motDePasse,
  });

  Future<Utilisateur> signUp({
    required Utilisateur utilisateur,
    required String motDePasse,
  });

  Future<void> sendPasswordReset(String email);

  Future<void> signOut();

  Future<void> deleteAccount({String? password});

  Future<void> updateProfile(Utilisateur utilisateur);
}
