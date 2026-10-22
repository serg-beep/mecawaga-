import 'moto.dart';

class CreneauJour {
  const CreneauJour({required this.ouverture, required this.fermeture});
  final String ouverture;
  final String fermeture;
}

class Mecanicien {
  const Mecanicien({
    required this.id,
    required this.nomAtelier,
    required this.telephone,
    required this.specialites,
    required this.latitude,
    required this.longitude,
    required this.precisionsAdresse,
    required this.horaires,
    this.positionRenseignee = false,
  });

  final String id;
  final String nomAtelier;
  final String telephone;
  final List<TypeMoto> specialites;
  final double latitude;
  final double longitude;
  final String precisionsAdresse;
  final Map<int, CreneauJour> horaires;
  final bool positionRenseignee;

  Mecanicien copyWith({
    String? nomAtelier,
    String? telephone,
    List<TypeMoto>? specialites,
    double? latitude,
    double? longitude,
    String? precisionsAdresse,
    Map<int, CreneauJour>? horaires,
    bool? positionRenseignee,
  }) => Mecanicien(
    id: id,
    nomAtelier: nomAtelier ?? this.nomAtelier,
    telephone: telephone ?? this.telephone,
    specialites: specialites ?? this.specialites,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    precisionsAdresse: precisionsAdresse ?? this.precisionsAdresse,
    horaires: horaires ?? this.horaires,
    positionRenseignee: positionRenseignee ?? this.positionRenseignee,
  );
}
