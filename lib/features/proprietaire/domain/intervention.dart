enum TypeIntervention {
  entretien('Entretien courant'),
  reparation('Réparation'),
  changementPiece('Changement de pièce');

  const TypeIntervention(this.label);
  final String label;
}

class Intervention {
  const Intervention({
    required this.id,
    required this.motoId,
    required this.date,
    required this.kilometrage,
    required this.type,
    this.pieces = const [],
    this.remarque = '',
    this.photos = const [],
    this.mecanicienId = '',
    this.mecanicienNom = 'Atelier MecaWaga',
  });

  final String id;
  final String motoId;
  final DateTime date;
  final int kilometrage;
  final TypeIntervention type;
  final List<String> pieces;
  final String remarque;
  final List<String> photos;
  final String mecanicienId;
  final String mecanicienNom;
}
