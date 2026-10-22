import 'dart:math';

import '../domain/code_acces.dart';
import '../domain/intervention.dart';
import '../domain/mecanicien.dart';
import '../domain/moto.dart';
import '../domain/rappel.dart';

abstract interface class ProprietaireRepository {
  Future<List<Moto>> getMotos();
  Stream<List<Moto>> watchMotos();
  Future<Moto?> getMoto(String motoId);
  Future<CodeAcces?> findAccessCode(String code);
  Future<String> getOwnerName(String motoId);
  Future<void> authorizeMechanic(String motoId, Mecanicien mecanicien);
  Future<void> saveIntervention(Intervention intervention);
  Future<void> saveMoto(Moto moto, {required bool isNew});
  Future<List<Intervention>> getInterventions(String motoId);
  Stream<List<Intervention>> watchInterventions(String motoId);
  Future<List<Rappel>> getRappels(String motoId);
  Stream<List<Rappel>> watchRappels(String motoId);
  Future<void> saveRappel(Rappel rappel);
  Future<void> deleteRappel(String rappelId);
  Future<CodeAcces> createAccessCode(String motoId);
  Future<CodeAcces?> getAccessCode(String motoId);
  Future<List<AccesMecanicien>> getMechanicAccess(String motoId);
  Future<void> revokeMechanicAccess(String motoId, String mecanicienId);
  Future<List<Mecanicien>> getMechanics();
  Future<List<Mecanicien>> searchMechanics({
    required double latitude,
    required double longitude,
    required double radiusKm,
    TypeMoto? speciality,
  });
  Future<Mecanicien?> getWorkshopProfile(String mecanicienId);
  Future<void> saveWorkshopProfile(Mecanicien mecanicien);
}

class FakeProprietaireRepository implements ProprietaireRepository {
  FakeProprietaireRepository()
    : _motos = [
        Moto(
          id: 'moto-1',
          marque: 'Yamaha',
          modele: 'MT-07',
          type: TypeMoto.sport,
          immatriculation: 'AB-123-CD',
          annee: 2022,
          kilometrage: 12450,
        ),
        Moto(
          id: 'moto-2',
          marque: 'Honda',
          modele: 'Forza 350',
          type: TypeMoto.scooter,
          immatriculation: 'EF-456-GH',
          annee: 2023,
          kilometrage: 6840,
        ),
      ],
      _mechanics = _fakeMechanics();

  final List<Moto> _motos;
  final List<Mecanicien> _mechanics;
  final Map<String, Mecanicien> _workshopProfiles = {};
  final Map<String, List<Rappel>> _rappels = {
    'moto-1': [
      Rappel(
        id: 'rappel-1',
        motoId: 'moto-1',
        titre: 'Vidange moteur',
        date: DateTime.now().add(const Duration(days: 12)),
        remarque: 'Huile 10W-40',
      ),
      Rappel(
        id: 'rappel-2',
        motoId: 'moto-1',
        titre: 'Contrôle des pneus',
        date: DateTime.now().add(const Duration(days: 36)),
      ),
    ],
  };
  final List<Intervention> _interventions = [
    Intervention(
      id: 'int-1',
      motoId: 'moto-1',
      date: DateTime(2026, 9, 12),
      kilometrage: 12000,
      type: TypeIntervention.entretien,
      pieces: ['Huile moteur', 'Filtre à huile'],
      remarque: 'Révision périodique et contrôle général.',
      mecanicienNom: 'Atelier du Centre',
      mecanicienId: 'mec-1',
    ),
    Intervention(
      id: 'int-2',
      motoId: 'moto-1',
      date: DateTime(2026, 6, 3),
      kilometrage: 9500,
      type: TypeIntervention.changementPiece,
      pieces: ['Plaquettes de frein avant'],
      remarque: 'Remplacement des plaquettes.',
      mecanicienNom: 'Garage des Deux Roues',
      mecanicienId: 'mec-2',
    ),
    Intervention(
      id: 'int-3',
      motoId: 'moto-2',
      date: DateTime(2026, 8, 21),
      kilometrage: 6200,
      type: TypeIntervention.entretien,
      pieces: ['Huile moteur', 'Filtre à air'],
      remarque: 'Entretien périodique du scooter.',
      mecanicienNom: 'Atelier du Centre',
      mecanicienId: 'mec-1',
    ),
  ];
  final Map<String, CodeAcces> _codes = {
    'moto-2': CodeAcces(
      motoId: 'moto-2',
      code: 'MOTO-684K2T',
      expiration: DateTime.now().add(const Duration(hours: 24)),
    ),
  };
  final Map<String, List<AccesMecanicien>> _access = {
    'moto-1': [
      AccesMecanicien(
        motoId: 'moto-1',
        mecanicien: _fakeMechanics()[0],
        dateAutorisation: DateTime.now().subtract(const Duration(days: 4)),
      ),
    ],
  };

  static List<Mecanicien> _fakeMechanics() => const [
    Mecanicien(
      id: 'mec-1',
      nomAtelier: 'Atelier du Centre',
      telephone: '+33142345678',
      specialites: [TypeMoto.sport, TypeMoto.moto125],
      latitude: 48.8566,
      longitude: 2.3522,
      precisionsAdresse: '12 rue de la Moto, Paris',
      positionRenseignee: true,
      horaires: {
        1: CreneauJour(ouverture: '09:00', fermeture: '18:00'),
        2: CreneauJour(ouverture: '09:00', fermeture: '18:00'),
        3: CreneauJour(ouverture: '09:00', fermeture: '18:00'),
        4: CreneauJour(ouverture: '09:00', fermeture: '18:00'),
        5: CreneauJour(ouverture: '09:00', fermeture: '17:00'),
      },
    ),
    Mecanicien(
      id: 'mec-2',
      nomAtelier: 'Garage des Deux Roues',
      telephone: '+33143876543',
      specialites: [TypeMoto.scooter, TypeMoto.trail],
      latitude: 48.8666,
      longitude: 2.3322,
      precisionsAdresse: '8 avenue du Garage, Paris',
      positionRenseignee: true,
      horaires: {
        1: CreneauJour(ouverture: '08:30', fermeture: '17:30'),
        2: CreneauJour(ouverture: '08:30', fermeture: '17:30'),
        3: CreneauJour(ouverture: '08:30', fermeture: '17:30'),
        4: CreneauJour(ouverture: '08:30', fermeture: '17:30'),
        5: CreneauJour(ouverture: '08:30', fermeture: '17:30'),
      },
    ),
    Mecanicien(
      id: 'mec-3',
      nomAtelier: 'Moto Service 125',
      telephone: '+33144990011',
      specialites: [TypeMoto.moto125, TypeMoto.scooter],
      latitude: 48.8466,
      longitude: 2.3722,
      precisionsAdresse: '27 boulevard des Ateliers, Paris',
      positionRenseignee: true,
      horaires: {
        1: CreneauJour(ouverture: '09:00', fermeture: '19:00'),
        2: CreneauJour(ouverture: '09:00', fermeture: '19:00'),
        3: CreneauJour(ouverture: '09:00', fermeture: '19:00'),
        4: CreneauJour(ouverture: '09:00', fermeture: '19:00'),
        5: CreneauJour(ouverture: '09:00', fermeture: '17:00'),
      },
    ),
  ];

  @override
  Future<List<Moto>> getMotos() async => List.unmodifiable(_motos);

  @override
  Stream<List<Moto>> watchMotos() async* {
    yield await getMotos();
  }

  @override
  Future<Moto?> getMoto(String motoId) async {
    for (final moto in _motos) {
      if (moto.id == motoId) return moto;
    }
    return null;
  }

  @override
  Future<CodeAcces?> findAccessCode(String code) async {
    for (final accessCode in _codes.values) {
      if (accessCode.code == code) return accessCode;
    }
    return null;
  }

  @override
  Future<String> getOwnerName(String motoId) async => switch (motoId) {
    'moto-1' => 'Sophie Bernard',
    'moto-2' => 'Camille Laurent',
    _ => 'Propriétaire MecaWaga',
  };

  @override
  Future<void> authorizeMechanic(String motoId, Mecanicien mecanicien) async {
    final accesses = _access.putIfAbsent(motoId, () => []);
    if (accesses.any((access) => access.mecanicien.id == mecanicien.id)) {
      return;
    }
    accesses.add(
      AccesMecanicien(
        motoId: motoId,
        mecanicien: mecanicien,
        dateAutorisation: DateTime.now(),
      ),
    );
  }

  @override
  Future<void> saveIntervention(Intervention intervention) async {
    final index = _motos.indexWhere((moto) => moto.id == intervention.motoId);
    if (index < 0) {
      throw StateError('La moto liée à cette intervention est introuvable.');
    }
    _interventions.add(intervention);
    _interventions.sort((a, b) => b.date.compareTo(a.date));
    final moto = _motos[index];
    if (intervention.kilometrage > moto.kilometrage) {
      _motos[index] = moto.copyWith(kilometrage: intervention.kilometrage);
    }
  }

  @override
  Future<Mecanicien?> getWorkshopProfile(String mecanicienId) async =>
      _workshopProfiles[mecanicienId];

  @override
  Future<void> saveWorkshopProfile(Mecanicien mecanicien) async {
    _workshopProfiles[mecanicien.id] = mecanicien;
  }

  @override
  Future<void> saveMoto(Moto moto, {required bool isNew}) async {
    final index = _motos.indexWhere((item) => item.id == moto.id);
    if (index < 0) {
      _motos.add(moto);
    } else {
      _motos[index] = moto;
    }
  }

  @override
  Future<List<Intervention>> getInterventions(String motoId) async =>
      _interventions.where((item) => item.motoId == motoId).toList()
        ..sort((a, b) => b.date.compareTo(a.date));

  @override
  Stream<List<Intervention>> watchInterventions(String motoId) async* {
    yield await getInterventions(motoId);
  }

  @override
  Future<List<Rappel>> getRappels(String motoId) async =>
      (_rappels[motoId] ?? []).toList()
        ..sort((a, b) => a.date.compareTo(b.date));

  @override
  Stream<List<Rappel>> watchRappels(String motoId) async* {
    yield await getRappels(motoId);
  }

  @override
  Future<void> saveRappel(Rappel rappel) async {
    _rappels.putIfAbsent(rappel.motoId, () => []).add(rappel);
  }

  @override
  Future<void> deleteRappel(String rappelId) async {
    for (final list in _rappels.values) {
      list.removeWhere((item) => item.id == rappelId);
    }
  }

  @override
  Future<CodeAcces> createAccessCode(String motoId) async {
    const alphabet = codeAccesAlphabet;
    final code = CodeAcces(
      motoId: motoId,
      code:
          'MOTO-${List.generate(codeAccesLongueur, (_) => alphabet[Random.secure().nextInt(alphabet.length)]).join()}',
      expiration: DateTime.now().add(const Duration(hours: 24)),
    );
    _codes[motoId] = code;
    return code;
  }

  @override
  Future<CodeAcces?> getAccessCode(String motoId) async => _codes[motoId];

  @override
  Future<List<AccesMecanicien>> getMechanicAccess(String motoId) async =>
      List.unmodifiable(_access[motoId] ?? []);

  @override
  Future<void> revokeMechanicAccess(String motoId, String mecanicienId) async {
    _access[motoId]?.removeWhere(
      (access) => access.mecanicien.id == mecanicienId,
    );
  }

  @override
  Future<List<Mecanicien>> getMechanics() async =>
      List.unmodifiable(_mechanics);

  @override
  Future<List<Mecanicien>> searchMechanics({
    required double latitude,
    required double longitude,
    required double radiusKm,
    TypeMoto? speciality,
  }) async {
    final matching = _mechanics.where(
      (mechanic) =>
          (speciality == null || mechanic.specialites.contains(speciality)) &&
          _distanceKm(latitude, longitude, mechanic.latitude, mechanic.longitude) <=
              radiusKm,
    ).toList();
    matching.sort(
      (a, b) =>
          _distanceKm(latitude, longitude, a.latitude, a.longitude).compareTo(
            _distanceKm(latitude, longitude, b.latitude, b.longitude),
          ),
    );
    return List.unmodifiable(matching);
  }

  double _distanceKm(double latitude1, double longitude1, double latitude2,
      double longitude2) {
    const earthRadiusKm = 6371.0;
    final latitudeDelta = (latitude2 - latitude1) * pi / 180;
    final longitudeDelta = (longitude2 - longitude1) * pi / 180;
    final haversine = sin(latitudeDelta / 2) * sin(latitudeDelta / 2) +
        cos(latitude1 * pi / 180) *
            cos(latitude2 * pi / 180) *
            sin(longitudeDelta / 2) *
            sin(longitudeDelta / 2);
    return earthRadiusKm * 2 * atan2(sqrt(haversine), sqrt(1 - haversine));
  }
}
