enum Categorie {
  motosOccasion('Motos d’occasion'),
  moteurs('Moteurs'),
  piecesDetachees('Pièces détachées'),
  outilsEtCles('Outils et clés'),
  accessoires('Accessoires'),
  autres('Autres');

  const Categorie(this.label);
  final String label;
}

enum EtatProduit {
  neuf('Neuf'),
  tresBonEtat('Très bon état'),
  bonEtat('Bon état'),
  aReparerOuPourPieces('À réparer / pour pièces');

  const EtatProduit(this.label);
  final String label;
}

enum StatutAnnonce { active, vendue, masquee }

class Annonce {
  const Annonce({
    required this.id,
    required this.vendeurId,
    required this.vendeurNom,
    required this.vendeurEstMecanicien,
    required this.titre,
    required this.categorie,
    required this.etat,
    required this.prix,
    required this.negociable,
    required this.description,
    required this.photos,
    required this.localisation,
    required this.telephone,
    required this.champsSpecifiques,
    required this.statut,
    required this.datePublication,
    this.telephoneWhatsApp = false,
  });

  final String id;
  final String vendeurId;
  final String vendeurNom;
  final bool vendeurEstMecanicien;
  final String titre;
  final Categorie categorie;
  final EtatProduit etat;
  final int prix;
  final bool negociable;
  final String description;
  final List<String> photos;
  final String localisation;
  final String telephone;
  final Map<String, String> champsSpecifiques;
  final StatutAnnonce statut;
  final DateTime datePublication;
  final bool telephoneWhatsApp;

  Annonce copyWith({
    String? id,
    String? vendeurId,
    String? vendeurNom,
    bool? vendeurEstMecanicien,
    String? titre,
    Categorie? categorie,
    EtatProduit? etat,
    int? prix,
    bool? negociable,
    String? description,
    List<String>? photos,
    String? localisation,
    String? telephone,
    Map<String, String>? champsSpecifiques,
    StatutAnnonce? statut,
    DateTime? datePublication,
    bool? telephoneWhatsApp,
  }) => Annonce(
    id: id ?? this.id,
    vendeurId: vendeurId ?? this.vendeurId,
    vendeurNom: vendeurNom ?? this.vendeurNom,
    vendeurEstMecanicien: vendeurEstMecanicien ?? this.vendeurEstMecanicien,
    titre: titre ?? this.titre,
    categorie: categorie ?? this.categorie,
    etat: etat ?? this.etat,
    prix: prix ?? this.prix,
    negociable: negociable ?? this.negociable,
    description: description ?? this.description,
    photos: photos ?? this.photos,
    localisation: localisation ?? this.localisation,
    telephone: telephone ?? this.telephone,
    champsSpecifiques: champsSpecifiques ?? this.champsSpecifiques,
    statut: statut ?? this.statut,
    datePublication: datePublication ?? this.datePublication,
    telephoneWhatsApp: telephoneWhatsApp ?? this.telephoneWhatsApp,
  );
}

class Signalement {
  const Signalement({
    required this.annonceId,
    required this.auteurId,
    required this.motif,
    required this.date,
  });

  final String annonceId;
  final String auteurId;
  final String motif;
  final DateTime date;
}
