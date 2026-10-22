import '../../proprietaire/domain/intervention.dart';
import '../../proprietaire/domain/moto.dart';

class MotoClient {
  const MotoClient({
    required this.moto,
    required this.proprietaire,
    this.derniereIntervention,
    this.codeAcces,
  });

  final Moto moto;
  final String proprietaire;
  final DateTime? derniereIntervention;
  final String? codeAcces;
}

class ClientsMecanicien {
  const ClientsMecanicien({required this.motos, required this.accesRetires});

  final List<MotoClient> motos;
  final List<MotoClient> accesRetires;
}

class HistoriqueMecanicien {
  const HistoriqueMecanicien({
    required this.client,
    required this.interventions,
  });

  final MotoClient client;
  final List<Intervention> interventions;
}
