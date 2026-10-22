enum RoleUtilisateur { proprietaire, mecanicien }

extension RoleUtilisateurLabel on RoleUtilisateur {
  String get label => switch (this) {
    RoleUtilisateur.proprietaire => 'Propriétaire',
    RoleUtilisateur.mecanicien => 'Mécanicien',
  };

  String get routeSegment => switch (this) {
    RoleUtilisateur.proprietaire => 'proprietaire',
    RoleUtilisateur.mecanicien => 'mecanicien',
  };

  static RoleUtilisateur fromRoute(String? value) => value == 'mecanicien'
      ? RoleUtilisateur.mecanicien
      : RoleUtilisateur.proprietaire;
}

extension RoleUtilisateurFirestore on RoleUtilisateur {
  String get firestoreValue => switch (this) {
    RoleUtilisateur.proprietaire => 'proprietaire',
    RoleUtilisateur.mecanicien => 'mecanicien',
  };

  static RoleUtilisateur fromValue(String? value) => value == 'mecanicien'
      ? RoleUtilisateur.mecanicien
      : RoleUtilisateur.proprietaire;
}

class Utilisateur {
  const Utilisateur({
    this.id = '',
    required this.nomComplet,
    required this.contact,
    this.telephone = '',
    required this.role,
    this.nomAtelier,
    this.typesMoto = const [],
  });

  final String id;
  final String nomComplet;
  final String contact;
  final String telephone;
  final RoleUtilisateur role;
  final String? nomAtelier;
  final List<String> typesMoto;

  Utilisateur copyWith({
    String? id,
    String? nomComplet,
    String? contact,
    String? telephone,
    RoleUtilisateur? role,
    String? nomAtelier,
    List<String>? typesMoto,
  }) => Utilisateur(
    id: id ?? this.id,
    nomComplet: nomComplet ?? this.nomComplet,
    contact: contact ?? this.contact,
    telephone: telephone ?? this.telephone,
    role: role ?? this.role,
    nomAtelier: nomAtelier ?? this.nomAtelier,
    typesMoto: typesMoto ?? this.typesMoto,
  );
}
