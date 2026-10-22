import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../../core/firebase/photo_storage_service.dart';
import '../domain/annonce.dart';
import 'annonce_repository.dart';

class FirebaseAnnonceRepository implements AnnonceRepository {
  FirebaseAnnonceRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    required this.photoStorageService,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final PhotoStorageService photoStorageService;

  CollectionReference<Map<String, dynamic>> get _announcements =>
      _firestore.collection('annonces');

  String get _uid {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw const MarketRepositoryException(
        'Reconnectez-vous pour accéder au Marché.',
      );
    }
    return uid;
  }

  @override
  Future<List<Annonce>> getActiveAnnouncements() async {
    final snapshot = await _announcements
        .where('statut', isEqualTo: StatutAnnonce.active.name)
        .orderBy('datePublication', descending: true)
        .limit(100)
        .get();
    return snapshot.docs.map(_fromDocument).toList();
  }

  @override
  Future<AnnoncePage> getActiveAnnouncementPage({
    required AnnonceQuery query,
    Object? cursor,
    int pageSize = 20,
  }) async {
    try {
      Query<Map<String, dynamic>> request = _announcements.where(
        'statut',
        isEqualTo: StatutAnnonce.active.name,
      );
      if (query.category != null) {
        request = request.where('categorie', isEqualTo: query.category!.name);
      }
      if (query.states.isNotEmpty) {
        final states = query.states.map((state) => state.name).toList();
        request = states.length == 1
            ? request.where('etat', isEqualTo: states.single)
            : request.where('etat', whereIn: states);
      }
      final cityPrefix = _searchable(query.city.trim());
      final titlePrefix = _searchable(query.titlePrefix.trim());
      if (titlePrefix.isNotEmpty) {
        request = request.where('titrePrefixes', arrayContains: titlePrefix);
      }

      final sortField = switch (query.sort) {
        AnnonceSort.recent => 'datePublication',
        AnnonceSort.priceAscending || AnnonceSort.priceDescending => 'prix',
      };
      final descending =
          query.sort == AnnonceSort.priceDescending ||
          query.sort == AnnonceSort.recent;
      request = request.orderBy(sortField, descending: descending);

      if (cursor is DocumentSnapshot<Map<String, dynamic>>) {
        request = request.startAfterDocument(cursor);
      }
      final snapshot = await request.limit(pageSize + 1).get();
      final hasMore = snapshot.docs.length > pageSize;
      final documents = hasMore
          ? snapshot.docs.take(pageSize).toList()
          : snapshot.docs;
      final filtered = documents.map(_fromDocument).where((annonce) {
        return annonce.prix >= query.minimumPrice &&
            annonce.prix <= query.maximumPrice &&
            (cityPrefix.isEmpty ||
                _searchable(annonce.localisation).contains(cityPrefix));
      }).toList();
      return AnnoncePage(
        items: filtered,
        cursor: documents.isEmpty ? cursor : documents.last,
        hasMore: hasMore,
      );
    } on FirebaseException catch (error) {
      throw MarketRepositoryException(_messageFor(error));
    }
  }

  @override
  Future<List<Annonce>> getMyAnnouncements(String vendeurId) async {
    if (vendeurId != _uid) {
      throw const MarketRepositoryException(
        'Vous ne pouvez consulter que vos propres annonces.',
      );
    }
    try {
      final snapshot = await _announcements
          .where('vendeurId', isEqualTo: vendeurId)
          .orderBy('datePublication', descending: true)
          .get();
      return snapshot.docs.map(_fromDocument).toList();
    } on FirebaseException catch (error) {
      throw MarketRepositoryException(_messageFor(error));
    }
  }

  @override
  Future<Annonce?> getAnnouncement(String id) async {
    try {
      final snapshot = await _announcements.doc(id).get();
      return snapshot.exists ? _fromDocument(snapshot) : null;
    } on FirebaseException catch (error) {
      throw MarketRepositoryException(_messageFor(error));
    }
  }

  @override
  Future<void> saveAnnouncement(
    Annonce annonce, {
    MarketUploadProgress? onUploadProgress,
  }) async {
    if (annonce.vendeurId != _uid) {
      throw const MarketRepositoryException(
        'Seul le vendeur peut publier ou modifier cette annonce.',
      );
    }
    if (annonce.photos.isEmpty || annonce.photos.length > 5) {
      throw const MarketRepositoryException(
        'Ajoutez entre une et cinq photos pour publier cette annonce.',
      );
    }

    final ref = _announcements.doc(annonce.id);
    final existing = await ref.get();
    if (existing.exists && existing.data()?['vendeurId'] != _uid) {
      throw const MarketRepositoryException(
        'Seul le vendeur peut modifier cette annonce.',
      );
    }

    final uploaded = <String>[];
    final resolvedPhotos = <String>[];
    var saved = false;
    try {
      for (var index = 0; index < annonce.photos.length; index++) {
        final source = annonce.photos[index];
        if (source.startsWith('https://')) {
          resolvedPhotos.add(source);
          continue;
        }
        if (source.startsWith('assets/')) {
          throw const MarketRepositoryException(
            'Choisissez une photo depuis votre appareil pour publier.',
          );
        }
        final url = await photoStorageService.uploadPhoto(
          file: File(source),
          destinationPath:
              'annonces/${annonce.id}/photo_${DateTime.now().microsecondsSinceEpoch}_$index.jpg',
          onProgress: (progress) =>
              onUploadProgress?.call(index, annonce.photos.length, progress),
          customMetadata: {'vendeurId': _uid},
        );
        uploaded.add(url);
        resolvedPhotos.add(url);
        onUploadProgress?.call(index + 1, annonce.photos.length, 1);
      }
      final oldPhotos = (existing.data()?['photos'] as List<dynamic>? ?? [])
          .whereType<String>()
          .toSet();
      await ref.set({
        'vendeurId': _uid,
        'vendeurNom': annonce.vendeurNom.trim(),
        'vendeurEstMecanicien': annonce.vendeurEstMecanicien,
        'titre': annonce.titre.trim(),
        'titreRecherche': _searchable(annonce.titre),
        'titrePrefixes': _titlePrefixes(annonce.titre),
        'categorie': annonce.categorie.name,
        'etat': annonce.etat.name,
        'prix': annonce.prix,
        'negociable': annonce.negociable,
        'description': annonce.description.trim(),
        'photos': resolvedPhotos,
        'localisation': annonce.localisation.trim(),
        'localisationRecherche': _searchable(annonce.localisation),
        'telephone': annonce.telephone,
        'whatsapp': annonce.telephoneWhatsApp,
        'champsSpecifiques': annonce.champsSpecifiques,
        'statut': annonce.statut.name,
        'nbSignalements':
            (existing.data()?['nbSignalements'] as num?)?.toInt() ?? 0,
        if (!existing.exists)
          'datePublication': FieldValue.serverTimestamp()
        else
          'datePublication':
              existing.data()?['datePublication'] ??
              Timestamp.fromDate(annonce.datePublication),
      }, SetOptions(merge: existing.exists));
      saved = true;
      final removedPhotos = oldPhotos.difference(resolvedPhotos.toSet());
      for (final photo in removedPhotos) {
        try {
          await photoStorageService.deletePhoto(photo);
        } on Exception catch (error) {
          debugPrint(
            'Annonce enregistrée, mais une ancienne photo n’a pas pu être '
            'nettoyée : $error',
          );
        }
      }
    } on Exception catch (error) {
      if (!saved) {
        for (final photo in uploaded) {
          try {
            await photoStorageService.deletePhoto(photo);
          } on Exception catch (cleanupError) {
            debugPrint(
              'Échec du nettoyage Storage après échec de publication : '
              '$cleanupError',
            );
          }
        }
      }
      if (error is MarketRepositoryException) rethrow;
      if (error is FirebaseException) {
        throw MarketRepositoryException(_messageFor(error));
      }
      rethrow;
    }
  }

  @override
  Future<void> deleteAnnouncement(String id) async {
    final ref = _announcements.doc(id);
    try {
      final snapshot = await ref.get();
      if (!snapshot.exists) return;
      if (snapshot.data()?['vendeurId'] != _uid) {
        throw const MarketRepositoryException(
          'Seul le vendeur peut supprimer cette annonce.',
        );
      }
      final photos = (snapshot.data()?['photos'] as List<dynamic>? ?? [])
          .whereType<String>();
      for (final photo in photos) {
        await photoStorageService.deletePhoto(photo);
      }
      await ref.delete();
    } on FirebaseException catch (error) {
      throw MarketRepositoryException(_messageFor(error));
    }
  }

  @override
  Future<void> updateStatus(String id, StatutAnnonce statut) async {
    try {
      final ref = _announcements.doc(id);
      final snapshot = await ref.get();
      if (!snapshot.exists || snapshot.data()?['vendeurId'] != _uid) {
        throw const MarketRepositoryException(
          'Cette annonce est introuvable ou ne vous appartient pas.',
        );
      }
      await ref.update({'statut': statut.name});
    } on FirebaseException catch (error) {
      throw MarketRepositoryException(_messageFor(error));
    }
  }

  @override
  Future<bool> reportAnnouncement(Signalement signalement) async {
    if (signalement.auteurId != _uid) {
      throw const MarketRepositoryException(
        'Reconnectez-vous pour signaler cette annonce.',
      );
    }
    final announcementRef = _announcements.doc(signalement.annonceId);
    final reportId = '${signalement.annonceId}_$_uid';
    final reportRef = _firestore.collection('signalements').doc(reportId);
    final userReportRef = _firestore
        .collection('utilisateurs')
        .doc(_uid)
        .collection('signalementsMarche')
        .doc(signalement.annonceId);
    try {
      if ((await userReportRef.get()).exists) {
        throw const MarketRepositoryException(
          'Vous avez déjà signalé cette annonce.',
        );
      }
      return await _firestore.runTransaction((transaction) async {
        final announcement = await transaction.get(announcementRef);
        if (!announcement.exists) {
          throw const MarketRepositoryException(
            'Cette annonce n’est plus disponible.',
          );
        }
        if (announcement.data()?['vendeurId'] == _uid) {
          throw const MarketRepositoryException(
            'Vous ne pouvez pas signaler votre propre annonce.',
          );
        }
        final count =
            (announcement.data()?['nbSignalements'] as num?)?.toInt() ?? 0;
        transaction.set(reportRef, {
          'annonceId': signalement.annonceId,
          'auteurId': _uid,
          'motif': signalement.motif,
          'date': FieldValue.serverTimestamp(),
        });
        transaction.set(userReportRef, {'annonceId': signalement.annonceId});
        transaction.update(announcementRef, {'nbSignalements': count + 1});
        return false;
      });
    } on FirebaseException catch (error) {
      throw MarketRepositoryException(_messageFor(error));
    }
  }

  Annonce _fromDocument(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data()!;
    return Annonce(
      id: snapshot.id,
      vendeurId: data['vendeurId'] as String? ?? '',
      vendeurNom: data['vendeurNom'] as String? ?? 'Vendeur MecaWaga',
      vendeurEstMecanicien: data['vendeurEstMecanicien'] as bool? ?? false,
      titre: data['titre'] as String? ?? '',
      categorie: Categorie.values.byName(
        data['categorie'] as String? ?? Categorie.autres.name,
      ),
      etat: EtatProduit.values.byName(
        data['etat'] as String? ?? EtatProduit.bonEtat.name,
      ),
      prix: (data['prix'] as num? ?? 0).toInt(),
      negociable: data['negociable'] as bool? ?? false,
      description: data['description'] as String? ?? '',
      photos: (data['photos'] as List<dynamic>? ?? [])
          .whereType<String>()
          .toList(),
      localisation: data['localisation'] as String? ?? '',
      telephone: data['telephone'] as String? ?? '',
      telephoneWhatsApp: data['whatsapp'] as bool? ?? false,
      champsSpecifiques: Map<String, String>.from(
        data['champsSpecifiques'] as Map? ?? const {},
      ),
      statut: StatutAnnonce.values.byName(
        data['statut'] as String? ?? StatutAnnonce.active.name,
      ),
      datePublication: _date(data['datePublication']),
    );
  }

  DateTime _date(Object? value) => switch (value) {
    Timestamp timestamp => timestamp.toDate(),
    DateTime date => date,
    _ => DateTime.now(),
  };

  String _searchable(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp('[àáâãäå]'), 'a')
      .replaceAll(RegExp('[èéêë]'), 'e')
      .replaceAll(RegExp('[ìíîï]'), 'i')
      .replaceAll(RegExp('[òóôõö]'), 'o')
      .replaceAll(RegExp('[ùúûü]'), 'u')
      .replaceAll('ç', 'c');

  List<String> _titlePrefixes(String value) {
    final runes = _searchable(value).runes.toList();
    return [
      for (var length = 1; length <= runes.length; length++)
        String.fromCharCodes(runes.take(length)),
    ];
  }

  String _messageFor(FirebaseException error) => switch (error.code) {
    'permission-denied' ||
    'unauthorized' => 'Cette action n’est pas autorisée pour votre compte.',
    'unavailable' || 'network-request-failed' =>
      'Connexion indisponible. Vérifiez votre réseau puis réessayez.',
    'failed-precondition' =>
      'La recherche nécessite un index Firestore. Contactez l’équipe technique.',
    _ => 'Le Marché est momentanément indisponible. Réessayez.',
  };
}
