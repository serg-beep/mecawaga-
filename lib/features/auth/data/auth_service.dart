import 'dart:async';

import '../domain/auth_repository.dart';
import '../domain/utilisateur.dart';

class AuthService extends AuthRepository {
  final Map<String, _Compte> _comptes = {};
  final StreamController<Utilisateur?> _authStateController =
      StreamController<Utilisateur?>.broadcast();
  Utilisateur? _utilisateurConnecte;
  int _nextUserId = 0;

  @override
  Utilisateur? get utilisateurConnecte => _utilisateurConnecte;

  @override
  Stream<Utilisateur?> authStateChanges() async* {
    yield _utilisateurConnecte;
    yield* _authStateController.stream;
  }

  @override
  Future<Utilisateur> signIn({
    required String identifiant,
    required String motDePasse,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 700));
    final compte = _comptes[_normalizeIdentifier(identifiant)];

    if (compte != null && compte.motDePasse == motDePasse) {
      _setUtilisateur(compte.utilisateur);
      return compte.utilisateur;
    }

    if (identifiant.trim().toLowerCase() == 'demo@mecawaga.fr' &&
        motDePasse == 'Moto2026') {
      final demo = const Utilisateur(
        id: 'demo-owner',
        nomComplet: 'Alex Martin',
        contact: 'demo@mecawaga.fr',
        telephone: '',
        role: RoleUtilisateur.proprietaire,
      );
      _setUtilisateur(demo);
      return demo;
    }

    throw const AuthException('Identifiants incorrects.');
  }

  @override
  Future<Utilisateur> signUp({
    required Utilisateur utilisateur,
    required String motDePasse,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 700));
    final emailKey = _normalizeIdentifier(utilisateur.contact);
    final phoneKey = _normalizeIdentifier(utilisateur.telephone);

    if (_comptes.containsKey(emailKey) ||
        (phoneKey.isNotEmpty && _comptes.containsKey(phoneKey)) ||
        emailKey == 'demo@mecawaga.fr') {
      throw const AuthException('Cette adresse e-mail est déjà utilisée.');
    }

    final savedUtilisateur = utilisateur.copyWith(
      id: utilisateur.id.isEmpty
          ? 'user-${DateTime.now().microsecondsSinceEpoch}-${_nextUserId++}'
          : utilisateur.id,
    );
    final compte = _Compte(
      utilisateur: savedUtilisateur,
      motDePasse: motDePasse,
    );
    _comptes[emailKey] = compte;
    if (phoneKey.isNotEmpty) _comptes[phoneKey] = compte;
    _setUtilisateur(savedUtilisateur);
    return savedUtilisateur;
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    await Future<void>.delayed(const Duration(milliseconds: 700));
  }

  @override
  Future<void> signOut() async {
    _setUtilisateur(null);
  }

  @override
  Future<void> deleteAccount({String? password}) async {
    final connected = _utilisateurConnecte;
    if (connected == null) return;
    _comptes.removeWhere((_, account) => account.utilisateur.id == connected.id);
    _setUtilisateur(null);
  }

  @override
  Future<void> updateProfile(Utilisateur utilisateur) async {
    final connected = _utilisateurConnecte;
    if (connected != null) {
      final oldAccount = _comptes.values
          .where((account) => identical(account.utilisateur, connected))
          .firstOrNull;
      if (oldAccount != null) {
        final updatedAccount = _Compte(
          utilisateur: utilisateur,
          motDePasse: oldAccount.motDePasse,
        );
        for (final key in _comptes.keys.toList()) {
          if (identical(_comptes[key], oldAccount)) {
            _comptes[key] = updatedAccount;
          }
        }
        _comptes[_normalizeIdentifier(utilisateur.contact)] = updatedAccount;
        final phoneKey = _normalizeIdentifier(utilisateur.telephone);
        if (phoneKey.isNotEmpty) _comptes[phoneKey] = updatedAccount;
      }
    }
    _setUtilisateur(utilisateur);
  }

  void _setUtilisateur(Utilisateur? utilisateur) {
    _utilisateurConnecte = utilisateur;
    _authStateController.add(utilisateur);
    notifyListeners();
  }

  String _normalizeIdentifier(String value) {
    final trimmed = value.trim();
    return trimmed.contains('@')
        ? trimmed.toLowerCase()
        : trimmed.replaceAll(RegExp(r'\D'), '');
  }

  @override
  void dispose() {
    unawaited(_authStateController.close());
    super.dispose();
  }
}

class _Compte {
  const _Compte({required this.utilisateur, required this.motDePasse});

  final Utilisateur utilisateur;
  final String motDePasse;
}
