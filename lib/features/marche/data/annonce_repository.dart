import '../domain/annonce.dart';
import '../marche_constants.dart';

enum AnnonceSort { recent, priceAscending, priceDescending }

class AnnonceQuery {
  const AnnonceQuery({
    this.category,
    this.states = const {},
    this.minimumPrice = 0,
    this.maximumPrice = prixMaximumFiltre,
    this.city = '',
    this.titlePrefix = '',
    this.sort = AnnonceSort.recent,
  });

  final Categorie? category;
  final Set<EtatProduit> states;
  final double minimumPrice;
  final double maximumPrice;
  final String city;
  final String titlePrefix;
  final AnnonceSort sort;
}

class AnnoncePage {
  const AnnoncePage({
    required this.items,
    required this.cursor,
    required this.hasMore,
  });

  final List<Annonce> items;
  final Object? cursor;
  final bool hasMore;
}

typedef MarketUploadProgress =
    void Function(int completedPhotos, int totalPhotos, double progress);

abstract interface class AnnonceRepository {
  Future<List<Annonce>> getActiveAnnouncements();
  Future<List<Annonce>> getMyAnnouncements(String vendeurId);
  Future<AnnoncePage> getActiveAnnouncementPage({
    required AnnonceQuery query,
    Object? cursor,
    int pageSize = 20,
  });
  Future<Annonce?> getAnnouncement(String id);
  Future<void> saveAnnouncement(
    Annonce annonce, {
    MarketUploadProgress? onUploadProgress,
  });
  Future<void> deleteAnnouncement(String id);
  Future<void> updateStatus(String id, StatutAnnonce statut);
  Future<bool> reportAnnouncement(Signalement signalement);
}

class FakeAnnonceRepository implements AnnonceRepository {
  FakeAnnonceRepository({List<Annonce>? announcements})
    : _announcements = announcements ?? _seedAnnouncements();

  final List<Annonce> _announcements;
  final List<Signalement> _reports = [];

  List<Signalement> get reports => List.unmodifiable(_reports);

  @override
  Future<List<Annonce>> getActiveAnnouncements() async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    return _announcements
        .where((item) => item.statut == StatutAnnonce.active)
        .toList()
      ..sort((a, b) => b.datePublication.compareTo(a.datePublication));
  }

  @override
  Future<AnnoncePage> getActiveAnnouncementPage({
    required AnnonceQuery query,
    Object? cursor,
    int pageSize = 20,
  }) async {
    final all = await getActiveAnnouncements();
    final filtered = all.where((item) {
      final title = _searchable(item.titre);
      final prefix = _searchable(query.titlePrefix.trim());
      return (query.category == null || item.categorie == query.category) &&
          (query.states.isEmpty || query.states.contains(item.etat)) &&
          item.prix >= query.minimumPrice &&
          item.prix <= query.maximumPrice &&
          (query.city.trim().isEmpty ||
              _searchable(item.localisation).contains(
                _searchable(query.city.trim()),
              )) &&
          (prefix.isEmpty || title.startsWith(prefix));
    }).toList();
    switch (query.sort) {
      case AnnonceSort.recent:
        filtered.sort(
          (a, b) => b.datePublication.compareTo(a.datePublication),
        );
      case AnnonceSort.priceAscending:
        filtered.sort((a, b) => a.prix.compareTo(b.prix));
      case AnnonceSort.priceDescending:
        filtered.sort((a, b) => b.prix.compareTo(a.prix));
    }
    final start = cursor is int ? cursor : 0;
    final end = (start + pageSize).clamp(0, filtered.length);
    return AnnoncePage(
      items: filtered.sublist(start, end),
      cursor: end,
      hasMore: end < filtered.length,
    );
  }

  @override
  Future<List<Annonce>> getMyAnnouncements(String vendeurId) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    return _announcements
        .where((item) => item.vendeurId == vendeurId)
        .toList()
      ..sort((a, b) => b.datePublication.compareTo(a.datePublication));
  }

  @override
  Future<Annonce?> getAnnouncement(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 80));
    for (final announcement in _announcements) {
      if (announcement.id == id) return announcement;
    }
    return null;
  }

  @override
  Future<void> saveAnnouncement(
    Annonce annonce, {
    MarketUploadProgress? onUploadProgress,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (annonce.photos.isEmpty || annonce.photos.length > 5) {
      throw const MarketRepositoryException(
        'Ajoutez entre une et cinq photos pour publier cette annonce.',
      );
    }

    final index = _announcements.indexWhere((item) => item.id == annonce.id);
    if (index < 0) {
      _announcements.insert(0, annonce);
    } else {
      _announcements[index] = annonce;
    }
  }

  @override
  Future<void> deleteAnnouncement(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    _announcements.removeWhere((item) => item.id == id);
  }

  @override
  Future<void> updateStatus(String id, StatutAnnonce statut) async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    final index = _announcements.indexWhere((item) => item.id == id);
    if (index < 0) {
      throw const MarketRepositoryException(
        'Cette annonce n’existe plus. Actualisez la liste.',
      );
    }
    _announcements[index] = _announcements[index].copyWith(statut: statut);
  }

  @override
  Future<bool> reportAnnouncement(Signalement signalement) async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    if (_reports.any(
      (report) =>
          report.annonceId == signalement.annonceId &&
          report.auteurId == signalement.auteurId,
    )) {
      throw const MarketRepositoryException(
        'Vous avez déjà signalé cette annonce.',
      );
    }
    _reports.add(signalement);
    final uniqueAuthors = _reports
        .where((report) => report.annonceId == signalement.annonceId)
        .map((report) => report.auteurId)
        .toSet();
    if (uniqueAuthors.length >= seuilSignalements) {
      await updateStatus(signalement.annonceId, StatutAnnonce.masquee);
      return true;
    }
    return false;
  }

  static List<Annonce> _seedAnnouncements() {
    final now = DateTime.now();
    const owners = [
      ('vendeur-1', 'Awa K.', false),
      ('vendeur-2', 'Garage Wendpanga', true),
      ('vendeur-3', 'Moussa O.', false),
      ('vendeur-4', 'Atelier du Faso', true),
    ];
    final items = <AnnonceSeed>[
      (
        'Honda CB125F d’occasion',
        Categorie.motosOccasion,
        EtatProduit.tresBonEtat,
        780000,
        'Ouagadougou',
        'Moto entretenue, papiers à jour et prête à rouler.',
        {'Marque': 'Honda', 'Modèle': 'CB125F', 'Année': '2021', 'Kilométrage': '18 500 km'},
      ),
      (
        'Moteur Yamaha 150 cc',
        Categorie.moteurs,
        EtatProduit.bonEtat,
        165000,
        'Bobo-Dioulasso',
        'Moteur complet testé, vendu avec son démarreur.',
        {'Cylindrée': '150 cc', 'Moto compatible': 'Yamaha YBR'},
      ),
      (
        'Kit chaîne renforcé',
        Categorie.piecesDetachees,
        EtatProduit.neuf,
        24000,
        'Koudougou',
        'Kit chaîne neuf, jamais monté. Pignon et couronne inclus.',
        {'Moto compatible': 'Honda CG 125'},
      ),
      (
        'Clé dynamométrique 1/2',
        Categorie.outilsEtCles,
        EtatProduit.tresBonEtat,
        38000,
        'Ouagadougou',
        'Outil vérifié, idéal pour les travaux moteur et roues.',
        {'Marque': 'Total', 'Lot ou pièce unique': 'Pièce unique'},
      ),
      (
        'Casque intégral homologué',
        Categorie.accessoires,
        EtatProduit.neuf,
        52000,
        'Ouahigouya',
        'Casque neuf avec visière transparente et housse.',
        {},
      ),
      (
        'Suzuki GN125 à vendre',
        Categorie.motosOccasion,
        EtatProduit.bonEtat,
        690000,
        'Kaya',
        'Bonne moto de ville, entretien récent, consommation raisonnable.',
        {'Marque': 'Suzuki', 'Modèle': 'GN125', 'Année': '2019', 'Kilométrage': '26 000 km'},
      ),
      (
        'Paire de pneus moto',
        Categorie.piecesDetachees,
        EtatProduit.tresBonEtat,
        46000,
        'Banfora',
        'Pneus peu roulés, encore beaucoup de gomme.',
        {'Moto compatible': 'Motos 125 cc'},
      ),
      (
        'Moteur complet Haojue',
        Categorie.moteurs,
        EtatProduit.aReparerOuPourPieces,
        85000,
        'Tenkodogo',
        'À réviser. Peut servir de base de réparation ou pour pièces.',
        {'Cylindrée': '125 cc', 'Moto compatible': 'Haojue HJ125'},
      ),
      (
        'Lot de clés plates',
        Categorie.outilsEtCles,
        EtatProduit.bonEtat,
        18000,
        'Ouagadougou',
        'Lot de 12 clés de différentes tailles, état de fonctionnement.',
        {'Marque': 'Facom', 'Lot ou pièce unique': 'Lot de 12 pièces'},
      ),
      (
        'Yamaha Crypton 110',
        Categorie.motosOccasion,
        EtatProduit.tresBonEtat,
        625000,
        'Dédougou',
        'Moto propre, vidange faite, pneus en bon état.',
        {'Marque': 'Yamaha', 'Modèle': 'Crypton 110', 'Année': '2022', 'Kilométrage': '12 400 km'},
      ),
      (
        'Rétroviseurs universels',
        Categorie.accessoires,
        EtatProduit.neuf,
        9000,
        'Fada N’Gourma',
        'Paire de rétroviseurs universels, fixation standard.',
        {},
      ),
      (
        'Compresseur d’atelier compact',
        Categorie.autres,
        EtatProduit.bonEtat,
        95000,
        'Ouagadougou',
        'Compresseur compact entretenu, pratique pour un petit atelier.',
        {},
      ),
    ];
    return [
      for (var index = 0; index < items.length; index++)
        Annonce(
          id: 'annonce-${index + 1}',
          vendeurId: owners[index % owners.length].$1,
          vendeurNom: owners[index % owners.length].$2,
          vendeurEstMecanicien: owners[index % owners.length].$3,
          titre: items[index].$1,
          categorie: items[index].$2,
          etat: items[index].$3,
          prix: items[index].$4,
          negociable: index.isEven,
          description: items[index].$6,
          photos: const [photoRemplacementMarche],
          localisation: items[index].$5,
          telephone: '+22670123456',
          champsSpecifiques: items[index].$7,
          statut: StatutAnnonce.active,
          datePublication: now.subtract(Duration(days: index)),
          telephoneWhatsApp: true,
        ),
    ];
  }

  String _searchable(String value) => value
      .toLowerCase()
      .replaceAll(RegExp('[àáâãäå]'), 'a')
      .replaceAll(RegExp('[èéêë]'), 'e')
      .replaceAll(RegExp('[ìíîï]'), 'i')
      .replaceAll(RegExp('[òóôõö]'), 'o')
      .replaceAll(RegExp('[ùúûü]'), 'u')
      .replaceAll('ç', 'c');
}

typedef AnnonceSeed = (
  String,
  Categorie,
  EtatProduit,
  int,
  String,
  String,
  Map<String, String>,
);

class MarketRepositoryException implements Exception {
  const MarketRepositoryException(this.message);
  final String message;

  @override
  String toString() => message;
}

List<Annonce> seedMarketAnnouncements() =>
    FakeAnnonceRepository._seedAnnouncements();
