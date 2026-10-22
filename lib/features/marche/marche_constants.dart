import 'domain/annonce.dart';

const seuilSignalements = 3;
const prixMaximumFiltre = 10000000.0;
const photoRemplacementMarche = 'assets/images/logo.png';

const champsParCategorie = <Categorie, List<String>>{
  Categorie.motosOccasion: ['Marque', 'Modèle', 'Année', 'Kilométrage'],
  Categorie.moteurs: ['Cylindrée', 'Moto compatible'],
  Categorie.piecesDetachees: ['Moto compatible'],
  Categorie.outilsEtCles: ['Marque', 'Lot ou pièce unique'],
  Categorie.accessoires: [],
  Categorie.autres: [],
};

const motifsSignalement = [
  'Annonce frauduleuse',
  'Produit interdit',
  'Informations fausses',
  'Autre',
];
