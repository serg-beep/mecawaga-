import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/foundation.dart';

import '../../../core/firebase/photo_storage_service.dart';
import '../domain/auth_repository.dart';
import '../domain/utilisateur.dart';

class FirebaseAuthRepository extends AuthRepository {
  FirebaseAuthRepository({
    firebase_auth.FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
  }) : _auth = firebaseAuth ?? firebase_auth.FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance {
    _subscription = _auth.authStateChanges().listen(_onFirebaseUserChanged);
    final currentUser = _auth.currentUser;
    if (currentUser != null) {
      unawaited(_loadUtilisateur(currentUser.uid));
    }
  }

  final firebase_auth.FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  late final StreamSubscription<firebase_auth.User?> _subscription;
  final StreamController<Utilisateur?> _authStateController =
      StreamController<Utilisateur?>.broadcast();
  Utilisateur? _utilisateurConnecte;

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
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: identifiant.trim().toLowerCase(),
        password: motDePasse,
      );
      final uid = credential.user?.uid;
      if (uid == null) {
        throw const AuthException('Connexion impossible. Réessayez.');
      }
      return _loadUtilisateur(uid);
    } on firebase_auth.FirebaseAuthException catch (error) {
      throw AuthException(_messageForAuthError(error));
    } on FirebaseException catch (error) {
      throw AuthException(_messageForFirebaseError(error));
    }
  }

  @override
  Future<Utilisateur> signUp({
    required Utilisateur utilisateur,
    required String motDePasse,
  }) async {
    firebase_auth.User? createdUser;
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: utilisateur.contact.trim().toLowerCase(),
        password: motDePasse,
      );
      createdUser = credential.user;
      final uid = createdUser?.uid;
      if (uid == null) {
        throw const AuthException('Inscription impossible. Réessayez.');
      }

      final savedUtilisateur = utilisateur.copyWith(
        id: uid,
        contact: utilisateur.contact.trim().toLowerCase(),
        telephone: utilisateur.telephone.trim(),
      );
      final batch = _firestore.batch();
      batch.set(_firestore.collection('utilisateurs').doc(uid), {
        'nom': savedUtilisateur.nomComplet,
        'telephone': savedUtilisateur.telephone,
        'email': savedUtilisateur.contact,
        'role': savedUtilisateur.role.firestoreValue,
        'dateCreation': FieldValue.serverTimestamp(),
      });
      if (savedUtilisateur.role == RoleUtilisateur.mecanicien) {
        batch.set(_firestore.collection('ateliers').doc(uid), {
          'nomAtelier': savedUtilisateur.nomAtelier ?? '',
          'specialites': savedUtilisateur.typesMoto,
          'profilComplet': false,
          'dateCreation': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
      await createdUser?.updateDisplayName(savedUtilisateur.nomComplet);
      _setUtilisateur(savedUtilisateur);
      return savedUtilisateur;
    } on AuthException {
      rethrow;
    } on firebase_auth.FirebaseAuthException catch (error) {
      if (createdUser != null) {
        await _deleteCreatedUser(createdUser);
      }
      throw AuthException(_messageForAuthError(error));
    } on FirebaseException catch (error) {
      if (createdUser != null) {
        await _deleteCreatedUser(createdUser);
      }
      if (error.code == 'permission-denied') {
        throw const AuthException(
          'La création du profil a été refusée par les règles Firestore. '
          'Vérifiez que les règles sont déployées puis réessayez.',
        );
      }
      throw AuthException(_messageForFirebaseError(error));
    } on Exception {
      if (createdUser != null) {
        await _deleteCreatedUser(createdUser);
      }
      throw const AuthException(
        'Le profil n’a pas pu être créé. Vérifiez votre connexion puis réessayez.',
      );
    }
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim().toLowerCase());
    } on firebase_auth.FirebaseAuthException catch (error) {
      throw AuthException(_messageForAuthError(error));
    } on FirebaseException catch (error) {
      throw AuthException(_messageForFirebaseError(error));
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<void> deleteAccount({String? password}) async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      final email = user.email;
      if (password == null ||
          password.isEmpty ||
          email == null ||
          email.isEmpty) {
        throw const AuthException(
          'Saisissez votre mot de passe pour confirmer la suppression du compte.',
        );
      }
      await user.reauthenticateWithCredential(
        firebase_auth.EmailAuthProvider.credential(
          email: email,
          password: password,
        ),
      );
      await _eraseUserData(user.uid);
      await user.delete();
    } on firebase_auth.FirebaseAuthException catch (error) {
      throw AuthException(_messageForAuthError(error));
    } on FirebaseException catch (error) {
      throw AuthException(_messageForFirebaseError(error));
    }
  }

  Future<void> _eraseUserData(String uid) async {
    final storage = FirebasePhotoStorageService();
    final userRef = _firestore.collection('utilisateurs').doc(uid);
    final userSnapshot = await userRef.get();
    if (!userSnapshot.exists) {
      throw const AuthException(
        'Le profil est introuvable. Contactez le support avant de supprimer le compte.',
      );
    }
    if (userSnapshot.data()?['deletionRequested'] != true) {
      await userRef.update({'deletionRequested': true});
    }

    final reports = await userRef.collection('signalementsMarche').get();
    for (final report in reports.docs) {
      await _firestore
          .collection('signalements')
          .doc('${report.id}_$uid')
          .delete();
    }
    await _deleteReferences(reports.docs.map((doc) => doc.reference));

    final listings = await _firestore
        .collection('annonces')
        .where('vendeurId', isEqualTo: uid)
        .get();
    for (final listing in listings.docs) {
      final photos = (listing.data()['photos'] as List<dynamic>? ?? [])
          .whereType<String>();
      for (final photo in photos) {
        await storage.deletePhoto(photo);
      }
      await listing.reference.delete();
    }

    final accessByOwner = await _firestore
        .collection('acces')
        .where('proprietaireId', isEqualTo: uid)
        .get();
    final accessByMechanic = await _firestore
        .collection('acces')
        .where('mecanicienId', isEqualTo: uid)
        .get();

    final mechanicInterventions = await _firestore
        .collectionGroup('interventions')
        .where('mecanicienId', isEqualTo: uid)
        .get();
    for (final intervention in mechanicInterventions.docs) {
      final photos = (intervention.data()['photos'] as List<dynamic>? ?? [])
          .whereType<String>();
      for (final photo in photos) {
        await storage.deletePhoto(photo);
      }
    }
    await _deleteReferences(
      mechanicInterventions.docs.map((doc) => doc.reference),
    );

    await _deleteReferences([
      ...accessByOwner.docs.map((doc) => doc.reference),
      ...accessByMechanic.docs.map((doc) => doc.reference),
    ]);

    final codes = await _firestore
        .collection('codesAcces')
        .where('proprietaireId', isEqualTo: uid)
        .get();
    await _deleteReferences(codes.docs.map((doc) => doc.reference));

    final motos = await _firestore
        .collection('motos')
        .where('proprietaireId', isEqualTo: uid)
        .get();
    for (final moto in motos.docs) {
      await storage.deletePhoto('motos/${moto.id}/photo.jpg');
      for (final collection in ['interventions', 'rappels']) {
        final children = await moto.reference.collection(collection).get();
        if (collection == 'interventions') {
          for (final child in children.docs) {
            final photos = (child.data()['photos'] as List<dynamic>? ?? [])
                .whereType<String>();
            for (final photo in photos) {
              await storage.deletePhoto(photo);
            }
          }
        }
        await _deleteReferences(children.docs.map((doc) => doc.reference));
      }
    }
    await _deleteReferences(motos.docs.map((doc) => doc.reference));

    final workshop = await _firestore.collection('ateliers').doc(uid).get();
    final workshopPhoto = workshop.data()?['photoUrl'] as String?;
    if (workshopPhoto != null && workshopPhoto.isNotEmpty) {
      await storage.deletePhoto(workshopPhoto);
    }
    if (workshop.exists) await workshop.reference.delete();
    await userRef.delete();
  }

  Future<void> _deleteReferences(
    Iterable<DocumentReference<Map<String, dynamic>>> references,
  ) async {
    final docs = references.toList();
    for (var start = 0; start < docs.length; start += 400) {
      final batch = _firestore.batch();
      for (final reference in docs.skip(start).take(400)) {
        batch.delete(reference);
      }
      await batch.commit();
    }
  }

  @override
  Future<void> updateProfile(Utilisateur utilisateur) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthException('Reconnectez-vous pour modifier votre profil.');
    }
    final normalizedEmail = utilisateur.contact.trim().toLowerCase();
    final updated = utilisateur.copyWith(
      id: user.uid,
      contact: normalizedEmail,
      telephone: utilisateur.telephone.trim(),
    );
    try {
      if (user.email != normalizedEmail) {
        await user.verifyBeforeUpdateEmail(normalizedEmail);
      }
      await user.updateDisplayName(updated.nomComplet);
      await _firestore.collection('utilisateurs').doc(user.uid).set({
        'nom': updated.nomComplet,
        'telephone': updated.telephone,
        'email': updated.contact,
        'role': updated.role.firestoreValue,
        'dateModification': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      _setUtilisateur(updated);
    } on firebase_auth.FirebaseAuthException catch (error) {
      throw AuthException(_messageForAuthError(error));
    } on FirebaseException catch (error) {
      throw AuthException(_messageForFirebaseError(error));
    }
  }

  Future<void> _onFirebaseUserChanged(firebase_auth.User? user) async {
    if (user == null) {
      _setUtilisateur(null);
      return;
    }
    try {
      await _loadUtilisateur(user.uid);
    } on AuthException {
      _setUtilisateur(null);
    }
  }

  Future<Utilisateur> _loadUtilisateur(String uid) async {
    try {
      final userDoc = await _firestore
          .collection('utilisateurs')
          .doc(uid)
          .get();
      if (!userDoc.exists) {
        throw const AuthException(
          'Profil introuvable. Contactez le support MecaWaga.',
        );
      }
      final data = userDoc.data() ?? <String, Object?>{};
      final role = RoleUtilisateurFirestore.fromValue(data['role'] as String?);
      String? nomAtelier;
      List<String> specialites = const [];
      if (role == RoleUtilisateur.mecanicien) {
        final atelierDoc = await _firestore
            .collection('ateliers')
            .doc(uid)
            .get();
        final atelier = atelierDoc.data() ?? <String, Object?>{};
        nomAtelier = atelier['nomAtelier'] as String?;
        specialites = (atelier['specialites'] as List<dynamic>? ?? const [])
            .whereType<String>()
            .toList();
      }
      final utilisateur = Utilisateur(
        id: uid,
        nomComplet: data['nom'] as String? ?? '',
        contact: data['email'] as String? ?? _auth.currentUser?.email ?? '',
        telephone: data['telephone'] as String? ?? '',
        role: role,
        nomAtelier: nomAtelier,
        typesMoto: specialites,
      );
      _setUtilisateur(utilisateur);
      return utilisateur;
    } on AuthException {
      rethrow;
    } on FirebaseException catch (error) {
      throw AuthException(_messageForFirebaseError(error));
    }
  }

  Future<void> _deleteCreatedUser(firebase_auth.User user) async {
    try {
      await user.delete();
    } on Exception {
      await _auth.signOut();
    }
  }

  void _setUtilisateur(Utilisateur? utilisateur) {
    _utilisateurConnecte = utilisateur;
    _authStateController.add(utilisateur);
    notifyListeners();
  }

  String _messageForFirebaseError(FirebaseException error) {
    if (error.code == 'unavailable' || error.code == 'network-request-failed') {
      return 'Pas de connexion réseau. Vérifiez votre connexion puis réessayez.';
    }
    if (error.code == 'permission-denied') {
      return 'Certaines données n’ont pas pu être supprimées. Votre demande '
          'est conservée; réessayez ou contactez le support.';
    }
    return 'Une erreur est survenue. Vérifiez votre connexion puis réessayez.';
  }

  String _messageForAuthError(firebase_auth.FirebaseAuthException error) {
    if (kDebugMode) {
      debugPrint(
        'FirebaseAuthException: ${error.code} - ${error.message ?? ''}',
      );
    }
    return switch (error.code) {
      'email-already-in-use' => 'Cette adresse e-mail est déjà utilisée.',
      'weak-password' => 'Le mot de passe est trop faible.',
      'invalid-email' => 'Adresse e-mail invalide.',
      'invalid-api-key' =>
        'Firebase n’est pas configuré pour cette application. '
            'Configurez les options Firebase de développement.',
      'operation-not-allowed' =>
        'La création de compte par e-mail est désactivée dans Firebase '
            'Authentication. Activez le fournisseur E-mail/Mot de passe.',
      'app-not-authorized' || 'invalid-cert-hash' =>
        'Cette application Android n est pas autorisee par Firebase. '
            'Verifiez le package Android et les empreintes SHA dans Firebase.',
      'configuration-not-found' =>
        'La configuration Firebase Authentication est introuvable pour ce '
            'projet. Verifiez que Firebase Auth est active.',
      'missing-client-identifier' =>
        'Firebase n arrive pas a identifier cette application. '
            'Verifiez google-services.json et la configuration Android.',
      'user-not-found' ||
      'wrong-password' ||
      'invalid-credential' => 'Identifiants incorrects.',
      'too-many-requests' =>
        'Trop de tentatives. Patientez quelques minutes puis réessayez.',
      'network-request-failed' =>
        'Pas de connexion réseau. Vérifiez votre connexion puis réessayez.',
      'requires-recent-login' =>
        'Reconnectez-vous avant de réaliser cette action.',
      _ => 'Une erreur est survenue. Vérifiez vos informations puis réessayez.',
    };
  }

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    unawaited(_authStateController.close());
    super.dispose();
  }
}
