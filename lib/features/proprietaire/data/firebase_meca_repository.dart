import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';

import '../domain/code_acces.dart';
import '../domain/intervention.dart';
import '../domain/mecanicien.dart';
import '../domain/moto.dart';
import '../domain/rappel.dart';
import '../../mecanicien/data/mecanicien_repository.dart';
import '../../mecanicien/domain/moto_client.dart';
import 'proprietaire_repository.dart';

class FirebaseMecaRepository
    implements ProprietaireRepository, MecanicienRepository {
  FirebaseMecaRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final Set<String> _previousClientMotoIds = {};
  final Set<String> _revokedMotoIds = {};

  String get _uid {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw StateError('Vous devez être connecté pour ajouter une moto.');
    }
    return uid;
  }

  CollectionReference<Map<String, dynamic>> get _motos =>
      _firestore.collection('motos');

  @override
  Future<List<Moto>> getMotos() async {
    final snapshot = await _motos
        .where('proprietaireId', isEqualTo: _uid)
        .get();
    return snapshot.docs.map(_motoFromDocument).toList()
      ..sort((a, b) => a.nom.compareTo(b.nom));
  }

  @override
  Stream<List<Moto>> watchMotos() => _motos
      .where('proprietaireId', isEqualTo: _uid)
      .snapshots(includeMetadataChanges: true)
      .map(
        (snapshot) =>
            snapshot.docs.map(_motoFromDocument).toList()
              ..sort((a, b) => a.nom.compareTo(b.nom)),
      );

  @override
  Future<Moto?> getMoto(String motoId) async {
    final snapshot = await _motos.doc(motoId).get();
    return snapshot.exists ? _motoFromDocument(snapshot) : null;
  }

  @override
  Future<CodeAcces?> findAccessCode(String code) async {
    final snapshot = await _firestore.collection('codesAcces').doc(code).get();
    if (!snapshot.exists) return null;
    final data = snapshot.data()!;
    return CodeAcces(
      motoId: data['motoId'] as String,
      code: snapshot.id,
      expiration: _date(data['expireLe']),
    );
  }

  @override
  Future<String> getOwnerName(String motoId) async {
    final moto = await _motos.doc(motoId).get();
    final ownerId = moto.data()?['proprietaireId'] as String?;
    if (ownerId == null) return 'Propriétaire MecaWaga';
    if (ownerId != _uid) {
      final access = await _firestore
          .collection('acces')
          .doc('${motoId}_$_uid')
          .get();
      return access.data()?['proprietaireNom'] as String? ??
          'Propriétaire MecaWaga';
    }
    final owner = await _firestore
        .collection('utilisateurs')
        .doc(ownerId)
        .get();
    return owner.data()?['nom'] as String? ?? 'Propriétaire MecaWaga';
  }

  @override
  Future<void> authorizeMechanic(String motoId, Mecanicien mecanicien) async {
    throw StateError(
      'Utilisez l’ajout par code d’accès pour autoriser un mécanicien.',
    );
  }

  @override
  Future<void> saveIntervention(Intervention intervention) async {
    final motoRef = _motos.doc(intervention.motoId);
    final interventionRef = motoRef
        .collection('interventions')
        .doc(intervention.id);
    await _firestore.runTransaction((transaction) async {
      final motoSnapshot = await transaction.get(motoRef);
      if (!motoSnapshot.exists) {
        throw StateError('La moto liée à cette intervention est introuvable.');
      }
      if (intervention.mecanicienId != _uid) {
        throw StateError(
          'Le mécanicien connecté ne correspond pas à l’auteur.',
        );
      }
      final currentKilometrage =
          (motoSnapshot.data()?['kilometrage'] as num?)?.toInt() ?? 0;
      transaction.set(interventionRef, {
        'motoId': intervention.motoId,
        'proprietaireId': motoSnapshot.data()?['proprietaireId'],
        'mecanicienId': _uid,
        'mecanicienNom': intervention.mecanicienNom,
        'date': Timestamp.fromDate(intervention.date),
        'kilometrage': intervention.kilometrage,
        'type': intervention.type.name,
        'pieces': intervention.pieces,
        'remarque': intervention.remarque,
        'photos': intervention.photos,
        'creeLe': FieldValue.serverTimestamp(),
      });
      if (intervention.kilometrage > currentKilometrage) {
        transaction.update(motoRef, {'kilometrage': intervention.kilometrage});
      }
    });
  }

  @override
  Future<Mecanicien?> getWorkshopProfile(String mecanicienId) async {
    final snapshot = await _firestore
        .collection('ateliers')
        .doc(mecanicienId)
        .get();
    return snapshot.exists
        ? _mechanicFromData(mecanicienId, snapshot.data()!)
        : null;
  }

  @override
  Future<void> saveWorkshopProfile(Mecanicien mecanicien) async {
    if (mecanicien.id != _uid) {
      throw StateError('Vous ne pouvez modifier que votre propre atelier.');
    }
    final point = GeoFirePoint(
      GeoPoint(mecanicien.latitude, mecanicien.longitude),
    );
    final complete =
        mecanicien.nomAtelier.trim().isNotEmpty &&
        mecanicien.telephone.trim().isNotEmpty &&
        mecanicien.specialites.isNotEmpty &&
        mecanicien.positionRenseignee &&
        mecanicien.precisionsAdresse.trim().isNotEmpty &&
        mecanicien.horaires.isNotEmpty;
    final workshopRef = _firestore.collection('ateliers').doc(_uid);
    await _firestore.runTransaction((transaction) async {
      final existing = await transaction.get(workshopRef);
      final data = <String, Object?>{
        'nomAtelier': mecanicien.nomAtelier.trim(),
        'telephone': mecanicien.telephone.trim(),
        'specialites': mecanicien.specialites
            .map((type) => type.label)
            .toList(),
        'position': point.data,
        'geohash': point.geohash,
        'precisions': mecanicien.precisionsAdresse.trim(),
        'horaires': {
          for (final entry in mecanicien.horaires.entries)
            '${entry.key}': {
              'ouverture': entry.value.ouverture,
              'fermeture': entry.value.fermeture,
            },
        },
        'profilComplet': complete,
      };
      if (!existing.exists) data['dateCreation'] = FieldValue.serverTimestamp();
      transaction.set(workshopRef, data, SetOptions(merge: true));
    });
  }

  @override
  Future<void> saveMoto(Moto moto, {required bool isNew}) async {
    final ref = _motos.doc(moto.id);
    final data = <String, Object?>{
      'proprietaireId': _uid,
      'marque': moto.marque.trim(),
      'modele': moto.modele.trim(),
      'type': moto.type.name,
      'immatriculation': moto.immatriculation.trim().toUpperCase(),
      'annee': moto.annee,
      'kilometrage': moto.kilometrage,
      'photoUrl': moto.photo,
    };
    if (isNew) {
      data['dateCreation'] = FieldValue.serverTimestamp();
      await ref.set(data).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw TimeoutException(
          'Enregistrement en attente. La moto sera envoyée au retour de la connexion.',
        ),
      );
    } else {
      await ref.update(data).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw TimeoutException(
          'Enregistrement en attente. La moto sera envoyée au retour de la connexion.',
        ),
      );
    }
  }

  @override
  Future<List<Intervention>> getInterventions(String motoId) async {
    final snapshot = await _motos
        .doc(motoId)
        .collection('interventions')
        .orderBy('date', descending: true)
        .get();
    return snapshot.docs.map(_interventionFromDocument).toList();
  }

  @override
  Stream<List<Intervention>> watchInterventions(String motoId) => _motos
      .doc(motoId)
      .collection('interventions')
      .orderBy('date', descending: true)
      .snapshots(includeMetadataChanges: true)
      .map((snapshot) => snapshot.docs.map(_interventionFromDocument).toList());

  @override
  Future<List<Rappel>> getRappels(String motoId) async {
    final snapshot = await _motos
        .doc(motoId)
        .collection('rappels')
        .orderBy('date')
        .get();
    return snapshot.docs.map(_reminderFromDocument).toList();
  }

  @override
  Stream<List<Rappel>> watchRappels(String motoId) => _motos
      .doc(motoId)
      .collection('rappels')
      .orderBy('date')
      .snapshots(includeMetadataChanges: true)
      .map((snapshot) => snapshot.docs.map(_reminderFromDocument).toList());

  @override
  Future<void> saveRappel(Rappel rappel) =>
      _motos.doc(rappel.motoId).collection('rappels').doc(rappel.id).set({
        'motoId': rappel.motoId,
        'proprietaireId': _uid,
        'titre': rappel.titre.trim(),
        'date': Timestamp.fromDate(rappel.date),
        'remarque': rappel.remarque,
        'notificationId': rappel.notificationId ?? notificationIdFor(rappel.id),
      });

  @override
  Future<void> deleteRappel(String rappelId) async {
    final userMotos = await _motos
        .where('proprietaireId', isEqualTo: _uid)
        .get();
    for (final moto in userMotos.docs) {
      final ref = moto.reference.collection('rappels').doc(rappelId);
      final reminder = await ref.get();
      if (reminder.exists) {
        await ref.delete();
        return;
      }
    }
  }

  @override
  Future<CodeAcces> createAccessCode(String motoId) async {
    final motoRef = _motos.doc(motoId);
    final codes = _firestore.collection('codesAcces');
    final rng = Random.secure();
    late String generatedCode;
    late DateTime expiration;
    await _firestore.runTransaction((transaction) async {
      final moto = await transaction.get(motoRef);
      if (!moto.exists || moto.data()?['proprietaireId'] != _uid) {
        throw StateError('Cette moto ne vous appartient pas.');
      }
      final ownerRef = _firestore.collection('utilisateurs').doc(_uid);
      final owner = await transaction.get(ownerRef);
      final ownerName = owner.data()?['nom'] as String? ?? '';
      String? code;
      for (var attempt = 0; attempt < 10; attempt++) {
        final suffix = List.generate(
          codeAccesLongueur,
          (_) => codeAccesAlphabet[rng.nextInt(codeAccesAlphabet.length)],
        ).join();
        final candidate = '$codeAccesPrefixe$suffix';
        final candidateRef = codes.doc(candidate);
        final existing = await transaction.get(candidateRef);
        if (!existing.exists) {
          code = candidate;
          break;
        }
      }
      if (code == null) {
        throw StateError('Impossible de générer un code unique. Réessayez.');
      }
      generatedCode = code;
      final previousCode = moto.data()?['codeAccesActif'] as String?;
      if (previousCode != null && previousCode.isNotEmpty) {
        transaction.delete(codes.doc(previousCode));
      }
      expiration = DateTime.now().add(const Duration(hours: 24));
      transaction.set(codes.doc(generatedCode), {
        'motoId': motoId,
        'proprietaireId': _uid,
        'proprietaireNom': ownerName,
        'expireLe': Timestamp.fromDate(expiration),
      });
      transaction.update(motoRef, {'codeAccesActif': generatedCode});
    });
    return CodeAcces(
      motoId: motoId,
      code: generatedCode,
      expiration: expiration,
    );
  }

  @override
  Future<CodeAcces?> getAccessCode(String motoId) async {
    final moto = await _motos.doc(motoId).get();
    if (moto.data()?['proprietaireId'] != _uid) {
      throw StateError('Vous ne pouvez consulter que vos propres codes.');
    }
    final code = moto.data()?['codeAccesActif'] as String?;
    return code == null ? null : findAccessCode(code);
  }

  @override
  Future<List<AccesMecanicien>> getMechanicAccess(String motoId) async {
    final snapshot = await _firestore
        .collection('acces')
        .where('motoId', isEqualTo: motoId)
        .where('proprietaireId', isEqualTo: _uid)
        .get();
    final result = <AccesMecanicien>[];
    for (final document in snapshot.docs) {
      final data = document.data();
      final mechanicId = data['mecanicienId'] as String;
      final mechanic =
          await getWorkshopProfile(mechanicId) ??
          Mecanicien(
            id: mechanicId,
            nomAtelier: data['nomAtelier'] as String? ?? 'Atelier MecaWaga',
            telephone: '',
            specialites: const [],
            latitude: 0,
            longitude: 0,
            precisionsAdresse: '',
            horaires: const {},
          );
      result.add(
        AccesMecanicien(
          motoId: motoId,
          mecanicien: mechanic,
          dateAutorisation: _date(data['dateAutorisation']),
        ),
      );
    }
    return result;
  }

  @override
  Future<void> revokeMechanicAccess(String motoId, String mecanicienId) async {
    await _firestore
        .collection('acces')
        .doc('${motoId}_$mecanicienId')
        .delete();
  }

  @override
  Future<List<Mecanicien>> getMechanics() async {
    final snapshot = await _firestore
        .collection('ateliers')
        .where('profilComplet', isEqualTo: true)
        .get();
    return snapshot.docs
        .map((doc) => _mechanicFromData(doc.id, doc.data()))
        .toList();
  }

  @override
  Future<List<Mecanicien>> searchMechanics({
    required double latitude,
    required double longitude,
    required double radiusKm,
    TypeMoto? speciality,
  }) async {
    final collection = GeoCollectionReference<Map<String, dynamic>>(
      _firestore.collection('ateliers'),
    );
    final center = GeoFirePoint(GeoPoint(latitude, longitude));
    final documents = await collection.fetchWithin(
      center: center,
      radiusInKm: radiusKm,
      field: 'position',
      geohashField: 'geohash',
      geopointFrom: (data) =>
          (data['position'] as Map<String, dynamic>)['geopoint'] as GeoPoint,
      strictMode: true,
      queryBuilder: (query) {
        final complete = query.where('profilComplet', isEqualTo: true);
        return speciality == null
            ? complete
            : complete.where('specialites', arrayContains: speciality.label);
      },
    );
    final results = documents
        .map(
          (doc) => _mechanicFromData(doc.id, doc.data() ?? <String, dynamic>{}),
        )
        .toList();
    results.sort(
      (a, b) => center
          .distanceBetweenInKm(geopoint: GeoPoint(a.latitude, a.longitude))
          .compareTo(
            center.distanceBetweenInKm(
              geopoint: GeoPoint(b.latitude, b.longitude),
            ),
          ),
    );
    return results;
  }

  @override
  Future<void> addClient(MotoClient client, Mecanicien mecanicien) async {
    final code = client.codeAcces;
    if (code == null) {
      throw const CodeAccesMecanicienException(
        'Ce code d’accès est introuvable. Demandez-en un nouveau au propriétaire.',
      );
    }
    final codeRef = _firestore.collection('codesAcces').doc(code);
    final motoRef = _motos.doc(client.moto.id);
    final accessRef = _firestore
        .collection('acces')
        .doc('${client.moto.id}_$_uid');
    await _firestore.runTransaction((transaction) async {
      final codeSnapshot = await transaction.get(codeRef);
      if (!codeSnapshot.exists) {
        throw const CodeAccesMecanicienException(
          'Ce code est introuvable. Vérifiez-le auprès du propriétaire.',
        );
      }
      final data = codeSnapshot.data()!;
      final expiration = _date(data['expireLe']);
      if (!expiration.isAfter(DateTime.now())) {
        throw const CodeAccesMecanicienException(
          'Ce code a expiré, demandez-en un nouveau au propriétaire.',
        );
      }
      if (data['motoId'] != client.moto.id) {
        throw const CodeAccesMecanicienException(
          'Ce code ne correspond pas à cette moto.',
        );
      }
      final accessSnapshot = await transaction.get(accessRef);
      if (accessSnapshot.exists) {
        throw const CodeAccesMecanicienException(
          'Cette moto figure déjà dans votre liste de clients.',
        );
      }
      final motoSnapshot = await transaction.get(motoRef);
      if (!motoSnapshot.exists ||
          motoSnapshot.data()?['proprietaireId'] != data['proprietaireId']) {
        throw const CodeAccesMecanicienException(
          'La moto associée à ce code n’est plus disponible.',
        );
      }
      transaction.set(accessRef, {
        'motoId': client.moto.id,
        'mecanicienId': _uid,
        'mecanicienNom': mecanicien.nomAtelier,
        'nomAtelier': mecanicien.nomAtelier,
        'proprietaireId': data['proprietaireId'],
        'proprietaireNom': data['proprietaireNom'] as String? ?? '',
        'code': code,
        'dateAutorisation': FieldValue.serverTimestamp(),
      });
    });
  }

  @override
  Future<MotoClient> findMotoWithCode(
    String code,
    Mecanicien mecanicien,
  ) async {
    if (!RegExp(
      r'^MOTO-[23456789ABCDEFGHJKMNPQRSTUVWXYZ]{6}$',
    ).hasMatch(code)) {
      throw const CodeAccesMecanicienException(
        'Saisissez un code au format MOTO-XXXXXX, sans caractères ambigus.',
      );
    }
    final codeSnapshot = await _firestore
        .collection('codesAcces')
        .doc(code)
        .get();
    if (!codeSnapshot.exists) {
      throw const CodeAccesMecanicienException(
        'Ce code est introuvable. Vérifiez-le auprès du propriétaire.',
      );
    }
    final codeData = codeSnapshot.data()!;
    if (!_date(codeData['expireLe']).isAfter(DateTime.now())) {
      throw const CodeAccesMecanicienException(
        'Ce code a expiré, demandez-en un nouveau au propriétaire.',
      );
    }
    final motoId = codeData['motoId'] as String;
    final access = await _firestore
        .collection('acces')
        .doc('${motoId}_$_uid')
        .get();
    if (access.exists) {
      throw const CodeAccesMecanicienException(
        'Cette moto figure déjà dans votre liste de clients.',
      );
    }
    final moto = await getMoto(motoId);
    if (moto == null) {
      throw const CodeAccesMecanicienException(
        'La moto associée à ce code n’est plus disponible.',
      );
    }
    return MotoClient(
      moto: moto,
      proprietaire:
          codeData['proprietaireNom'] as String? ?? 'Propriétaire MecaWaga',
      codeAcces: code,
    );
  }

  @override
  Future<ClientsMecanicien> getClients(Mecanicien mecanicien) async {
    final snapshot = await _firestore
        .collection('acces')
        .where('mecanicienId', isEqualTo: _uid)
        .get();
    final clients = <MotoClient>[];
    final currentIds = <String>{};
    for (final access in snapshot.docs) {
      final motoId = access.data()['motoId'] as String;
      final moto = await getMoto(motoId);
      if (moto == null) continue;
      currentIds.add(motoId);
      final interventions = await getInterventions(motoId);
      clients.add(
        MotoClient(
          moto: moto,
          proprietaire:
              access.data()['proprietaireNom'] as String? ??
              'Propriétaire MecaWaga',
          derniereIntervention: interventions.firstOrNull?.date,
        ),
      );
    }
    _revokedMotoIds.addAll(_previousClientMotoIds.difference(currentIds));
    _previousClientMotoIds
      ..clear()
      ..addAll(currentIds);
    final revoked = <MotoClient>[];
    for (final motoId in _revokedMotoIds) {
      // A removed access prevents reading the moto, so the notice is one-shot.
      revoked.add(
        MotoClient(
          moto: Moto(
            id: motoId,
            marque: 'Moto',
            modele: 'indisponible',
            type: TypeMoto.moto125,
            immatriculation: '',
            annee: 0,
            kilometrage: 0,
          ),
          proprietaire: 'Le propriétaire a retiré votre accès à cette moto',
        ),
      );
    }
    _revokedMotoIds.clear();
    clients.sort(
      (a, b) => a.moto.immatriculation.compareTo(b.moto.immatriculation),
    );
    return ClientsMecanicien(motos: clients, accesRetires: revoked);
  }

  @override
  Stream<ClientsMecanicien> watchClients(Mecanicien mecanicien) async* {
    await for (final snapshot
        in _firestore
            .collection('acces')
            .where('mecanicienId', isEqualTo: _uid)
            .snapshots(includeMetadataChanges: true)) {
      final clients = <MotoClient>[];
      final currentIds = <String>{};
      for (final access in snapshot.docs) {
        final motoId = access.data()['motoId'] as String;
        final moto = await getMoto(motoId);
        if (moto == null) continue;
        currentIds.add(motoId);
        final interventions = await getInterventions(motoId);
        clients.add(
          MotoClient(
            moto: moto,
            proprietaire:
                access.data()['proprietaireNom'] as String? ??
                'Propriétaire MecaWaga',
            derniereIntervention: interventions.firstOrNull?.date,
          ),
        );
      }
      _revokedMotoIds.addAll(_previousClientMotoIds.difference(currentIds));
      _previousClientMotoIds
        ..clear()
        ..addAll(currentIds);
      final revoked = [
        for (final motoId in _revokedMotoIds)
          MotoClient(
            moto: Moto(
              id: motoId,
              marque: 'Moto',
              modele: 'indisponible',
              type: TypeMoto.moto125,
              immatriculation: '',
              annee: 0,
              kilometrage: 0,
            ),
            proprietaire: 'Le propriétaire a retiré votre accès à cette moto',
          ),
      ];
      _revokedMotoIds.clear();
      clients.sort(
        (a, b) => a.moto.immatriculation.compareTo(b.moto.immatriculation),
      );
      yield ClientsMecanicien(motos: clients, accesRetires: revoked);
    }
  }

  @override
  Future<void> addIntervention(
    Intervention intervention,
    Mecanicien mecanicien,
  ) async {
    if (await getHistorique(intervention.motoId, mecanicien) == null) {
      throw StateError('Le propriétaire a retiré votre accès à cette moto.');
    }
    await saveIntervention(intervention);
  }

  @override
  Future<HistoriqueMecanicien?> getHistorique(
    String motoId,
    Mecanicien mecanicien,
  ) async {
    final access = await _firestore
        .collection('acces')
        .doc('${motoId}_$_uid')
        .get();
    if (!access.exists) return null;
    final moto = await getMoto(motoId);
    if (moto == null) return null;
    final interventions = await getInterventions(motoId);
    final accessData = access.data()!;
    return HistoriqueMecanicien(
      client: MotoClient(
        moto: moto,
        proprietaire:
            accessData['proprietaireNom'] as String? ?? 'Propriétaire MecaWaga',
        derniereIntervention: interventions.firstOrNull?.date,
      ),
      interventions: interventions,
    );
  }

  @override
  Stream<HistoriqueMecanicien?> watchHistorique(
    String motoId,
    Mecanicien mecanicien,
  ) async* {
    final accessRef = _firestore.collection('acces').doc('${motoId}_$_uid');
    yield* accessRef.snapshots().asyncExpand((access) {
      if (!access.exists) return Stream.value(null);
      return watchInterventions(motoId).asyncMap((interventions) async {
        final moto = await getMoto(motoId);
        if (moto == null) return null;
        return HistoriqueMecanicien(
          client: MotoClient(
            moto: moto,
            proprietaire:
                access.data()?['proprietaireNom'] as String? ??
                'Propriétaire MecaWaga',
            derniereIntervention: interventions.firstOrNull?.date,
          ),
          interventions: interventions,
        );
      });
    });
  }

  Moto _motoFromDocument(DocumentSnapshot<Map<String, dynamic>> document) {
    final data = document.data()!;
    return Moto(
      id: document.id,
      marque: data['marque'] as String? ?? '',
      modele: data['modele'] as String? ?? '',
      type: _motoType(data['type']),
      immatriculation: data['immatriculation'] as String? ?? '',
      annee: (data['annee'] as num?)?.toInt() ?? 0,
      kilometrage: (data['kilometrage'] as num?)?.toInt() ?? 0,
      photo: data['photoUrl'] as String?,
    );
  }

  Intervention _interventionFromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data()!;
    return Intervention(
      id: document.id,
      motoId: document.reference.parent.parent!.id,
      date: _date(data['date']),
      kilometrage: (data['kilometrage'] as num?)?.toInt() ?? 0,
      type: TypeIntervention.values.firstWhere(
        (value) => value.name == data['type'],
        orElse: () => TypeIntervention.entretien,
      ),
      pieces: (data['pieces'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(),
      remarque: data['remarque'] as String? ?? '',
      photos: (data['photos'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(),
      mecanicienId: data['mecanicienId'] as String? ?? '',
      mecanicienNom: data['mecanicienNom'] as String? ?? 'Atelier MecaWaga',
    );
  }

  Rappel _reminderFromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data()!;
    return Rappel(
      id: document.id,
      motoId: document.reference.parent.parent!.id,
      titre: data['titre'] as String? ?? '',
      date: _date(data['date']),
      remarque: data['remarque'] as String?,
      notificationId:
          (data['notificationId'] as num?)?.toInt() ??
          notificationIdFor(document.id),
    );
  }

  Mecanicien _mechanicFromData(String id, Map<String, dynamic> data) {
    final positionData = data['position'];
    final point = positionData is GeoPoint
        ? positionData
        : positionData is Map<String, dynamic>
        ? positionData['geopoint'] as GeoPoint?
        : null;
    final rawHours = data['horaires'] as Map<String, dynamic>? ?? const {};
    return Mecanicien(
      id: id,
      nomAtelier: data['nomAtelier'] as String? ?? '',
      telephone: data['telephone'] as String? ?? '',
      specialites: (data['specialites'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .map(_motoType)
          .toList(),
      latitude: point?.latitude ?? 0,
      longitude: point?.longitude ?? 0,
      precisionsAdresse: data['precisions'] as String? ?? '',
      positionRenseignee: point != null,
      horaires: {
        for (final entry in rawHours.entries)
          if (entry.value is Map<String, dynamic>)
            int.tryParse(entry.key) ?? -1: CreneauJour(
              ouverture:
                  (entry.value as Map<String, dynamic>)['ouverture']
                      as String? ??
                  '',
              fermeture:
                  (entry.value as Map<String, dynamic>)['fermeture']
                      as String? ??
                  '',
            ),
      }..remove(-1),
    );
  }

  TypeMoto _motoType(Object? value) => TypeMoto.values.firstWhere(
    (type) => type.name == value || type.label == value,
    orElse: () => TypeMoto.moto125,
  );

  DateTime _date(Object? value) => switch (value) {
    Timestamp timestamp => timestamp.toDate(),
    DateTime date => date,
    _ => DateTime.fromMillisecondsSinceEpoch(0),
  };
}
