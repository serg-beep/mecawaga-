import '../../../core/utils/access_code_utils.dart';
import '../../proprietaire/data/proprietaire_repository.dart';
import '../../proprietaire/domain/intervention.dart';
import '../../proprietaire/domain/mecanicien.dart';
import '../domain/moto_client.dart';

class CodeAccesMecanicienException implements Exception {
  const CodeAccesMecanicienException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract interface class MecanicienRepository {
  Future<ClientsMecanicien> getClients(Mecanicien mecanicien);
  Stream<ClientsMecanicien> watchClients(Mecanicien mecanicien);
  Future<MotoClient> findMotoWithCode(String code, Mecanicien mecanicien);
  Future<void> addClient(MotoClient client, Mecanicien mecanicien);
  Future<void> addIntervention(
    Intervention intervention,
    Mecanicien mecanicien,
  );
  Future<Mecanicien?> getWorkshopProfile(String mecanicienId);
  Future<void> saveWorkshopProfile(Mecanicien mecanicien);
  Future<HistoriqueMecanicien?> getHistorique(
    String motoId,
    Mecanicien mecanicien,
  );
  Stream<HistoriqueMecanicien?> watchHistorique(
    String motoId,
    Mecanicien mecanicien,
  );
}

class FakeMecanicienRepository implements MecanicienRepository {
  FakeMecanicienRepository(this._proprietaireRepository);

  final ProprietaireRepository _proprietaireRepository;
  final Set<String> _knownMotoIds = {};
  final Set<String> _pendingRevokedMotoIds = {};

  @override
  Future<ClientsMecanicien> getClients(Mecanicien mecanicien) async {
    final motos = await _proprietaireRepository.getMotos();
    final clients = <MotoClient>[];
    final currentIds = <String>{};

    for (final moto in motos) {
      final accesses = await _proprietaireRepository.getMechanicAccess(moto.id);
      if (!accesses.any((access) => access.mecanicien.id == mecanicien.id)) {
        continue;
      }
      currentIds.add(moto.id);
      final interventions = await _proprietaireRepository.getInterventions(
        moto.id,
      );
      clients.add(
        MotoClient(
          moto: moto,
          proprietaire: await _proprietaireRepository.getOwnerName(moto.id),
          derniereIntervention: interventions.isEmpty
              ? null
              : interventions.first.date,
        ),
      );
    }

    _pendingRevokedMotoIds.addAll(_knownMotoIds.difference(currentIds));
    _knownMotoIds
      ..clear()
      ..addAll(currentIds);

    final revoked = <MotoClient>[];
    for (final motoId in _pendingRevokedMotoIds) {
      final moto = await _proprietaireRepository.getMoto(motoId);
      if (moto != null) {
        revoked.add(
          MotoClient(
            moto: moto,
            proprietaire: await _proprietaireRepository.getOwnerName(motoId),
          ),
        );
      }
    }
    _pendingRevokedMotoIds.clear();
    clients.sort(
      (a, b) => a.moto.immatriculation.compareTo(b.moto.immatriculation),
    );
    return ClientsMecanicien(motos: clients, accesRetires: revoked);
  }

  @override
  Stream<ClientsMecanicien> watchClients(Mecanicien mecanicien) async* {
    yield await getClients(mecanicien);
  }

  @override
  Future<MotoClient> findMotoWithCode(
    String code,
    Mecanicien mecanicien,
  ) async {
    final accessCode = await _proprietaireRepository.findAccessCode(code);
    if (!isValidAccessCode(code)) {
      throw const CodeAccesMecanicienException(
        'Saisissez un code au format MOTO-XXXXXX, sans caractères ambigus.',
      );
    }
    if (accessCode == null) {
      throw const CodeAccesMecanicienException(
        'Ce code est introuvable. Vérifiez-le auprès du propriétaire.',
      );
    }
    if (accessCode.estExpire) {
      throw const CodeAccesMecanicienException(
        'Ce code a expiré, demandez-en un nouveau au propriétaire.',
      );
    }
    final moto = await _proprietaireRepository.getMoto(accessCode.motoId);
    if (moto == null) {
      throw const CodeAccesMecanicienException(
        'La moto associée à ce code n’est plus disponible.',
      );
    }
    final accesses = await _proprietaireRepository.getMechanicAccess(moto.id);
    if (accesses.any((access) => access.mecanicien.id == mecanicien.id)) {
      throw const CodeAccesMecanicienException(
        'Cette moto figure déjà dans votre liste de clients.',
      );
    }
    final interventions = await _proprietaireRepository.getInterventions(
      moto.id,
    );
    return MotoClient(
      moto: moto,
      proprietaire: await _proprietaireRepository.getOwnerName(moto.id),
      derniereIntervention: interventions.isEmpty
          ? null
          : interventions.first.date,
      codeAcces: code,
    );
  }

  @override
  Future<void> addClient(MotoClient client, Mecanicien mecanicien) async {
    final code = client.codeAcces == null
        ? null
        : await _proprietaireRepository.findAccessCode(client.codeAcces!);
    if (code == null || code.estExpire || code.motoId != client.moto.id) {
      throw const CodeAccesMecanicienException(
        'Ce code d’accès n’est plus valide. Demandez un code actif au propriétaire.',
      );
    }
    final accesses = await _proprietaireRepository.getMechanicAccess(
      client.moto.id,
    );
    if (accesses.any((access) => access.mecanicien.id == mecanicien.id)) {
      throw const CodeAccesMecanicienException(
        'Cette moto figure déjà dans votre liste de clients.',
      );
    }
    await _proprietaireRepository.authorizeMechanic(client.moto.id, mecanicien);
    _knownMotoIds.add(client.moto.id);
  }

  @override
  Future<void> addIntervention(
    Intervention intervention,
    Mecanicien mecanicien,
  ) async {
    final historique = await getHistorique(intervention.motoId, mecanicien);
    if (historique == null) {
      throw StateError('Le propriétaire a retiré votre accès à cette moto.');
    }
    await _proprietaireRepository.saveIntervention(intervention);
  }

  @override
  Future<Mecanicien?> getWorkshopProfile(String mecanicienId) =>
      _proprietaireRepository.getWorkshopProfile(mecanicienId);

  @override
  Future<void> saveWorkshopProfile(Mecanicien mecanicien) =>
      _proprietaireRepository.saveWorkshopProfile(mecanicien);

  @override
  Future<HistoriqueMecanicien?> getHistorique(
    String motoId,
    Mecanicien mecanicien,
  ) async {
    final accesses = await _proprietaireRepository.getMechanicAccess(motoId);
    if (!accesses.any((access) => access.mecanicien.id == mecanicien.id)) {
      return null;
    }
    final moto = await _proprietaireRepository.getMoto(motoId);
    if (moto == null) return null;
    final interventions = await _proprietaireRepository.getInterventions(
      motoId,
    );
    return HistoriqueMecanicien(
      client: MotoClient(
        moto: moto,
        proprietaire: await _proprietaireRepository.getOwnerName(motoId),
        derniereIntervention: interventions.isEmpty
            ? null
            : interventions.first.date,
      ),
      interventions: interventions,
    );
  }

  @override
  Stream<HistoriqueMecanicien?> watchHistorique(
    String motoId,
    Mecanicien mecanicien,
  ) async* {
    yield await getHistorique(motoId, mecanicien);
  }
}
