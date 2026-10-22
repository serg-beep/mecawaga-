enum TypeMoto {
  moto125('Moto 125 cc'),
  scooter('Scooter'),
  sport('Moto sport'),
  trail('Trail');

  const TypeMoto(this.label);
  final String label;
}

class Moto {
  const Moto({
    required this.id,
    required this.marque,
    required this.modele,
    required this.type,
    required this.immatriculation,
    required this.annee,
    required this.kilometrage,
    this.photo,
  });

  final String id;
  final String marque;
  final String modele;
  final TypeMoto type;
  final String immatriculation;
  final int annee;
  final int kilometrage;
  final String? photo;

  String get nom => '$marque $modele';

  Moto copyWith({
    String? id,
    String? marque,
    String? modele,
    TypeMoto? type,
    String? immatriculation,
    int? annee,
    int? kilometrage,
    String? photo,
    bool clearPhoto = false,
  }) => Moto(
    id: id ?? this.id,
    marque: marque ?? this.marque,
    modele: modele ?? this.modele,
    type: type ?? this.type,
    immatriculation: immatriculation ?? this.immatriculation,
    annee: annee ?? this.annee,
    kilometrage: kilometrage ?? this.kilometrage,
    photo: clearPhoto ? null : photo ?? this.photo,
  );
}
