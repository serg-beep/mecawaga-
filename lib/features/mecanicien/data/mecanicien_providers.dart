import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/auth_providers.dart';
import '../../proprietaire/data/firebase_meca_repository.dart';
import '../../proprietaire/data/proprietaire_providers.dart';
import '../../proprietaire/domain/intervention.dart';
import '../../proprietaire/domain/mecanicien.dart';
import '../../proprietaire/domain/moto.dart';
import '../domain/moto_client.dart';
import 'mecanicien_repository.dart';

final mecanicienRepositoryProvider = Provider<MecanicienRepository>(
  (ref) {
    if (Firebase.apps.isNotEmpty) return FirebaseMecaRepository();
    return FakeMecanicienRepository(
      ref.watch(proprietaireRepositoryProvider),
    );
  },
);

final mecanicienIdProvider = Provider<String>((ref) {
  final utilisateur = ref.watch(authServiceProvider).utilisateurConnecte;
  if (utilisateur?.id.isNotEmpty == true) return utilisateur!.id;
  final contactId = utilisateur?.contact.trim().toLowerCase();
  return contactId?.isNotEmpty == true ? contactId! : 'session';
});

final mecanicienProfilOverrideProvider =
    StateProvider.family<Mecanicien?, String>((ref, mecanicienId) => null);

final mecanicienProfilProvider = Provider<Mecanicien>((ref) {
  final utilisateur = ref.watch(authServiceProvider).utilisateurConnecte;
  final mecanicienId = ref.watch(mecanicienIdProvider);
  final override = ref.watch(mecanicienProfilOverrideProvider(mecanicienId));
  if (override != null) return override;
  final profile = Mecanicien(
    id: mecanicienId,
    nomAtelier: utilisateur?.nomAtelier?.trim().isNotEmpty == true
        ? utilisateur!.nomAtelier!
        : 'Atelier MecaWaga',
    telephone: utilisateur?.telephone ?? '',
    specialites: TypeMoto.values
        .where((type) => utilisateur?.typesMoto.contains(type.label) ?? false)
        .toList(),
    latitude: 0,
    longitude: 0,
    precisionsAdresse: '',
    horaires: const {},
  );
  return profile;
});

final mecanicienProfilCompletProvider = Provider<bool>((ref) {
  final profile = ref.watch(mecanicienProfilProvider);
  return profile.nomAtelier.trim().isNotEmpty &&
      profile.nomAtelier != 'Atelier MecaWaga' &&
      profile.telephone.trim().isNotEmpty &&
      profile.specialites.isNotEmpty &&
      profile.positionRenseignee &&
      profile.precisionsAdresse.trim().isNotEmpty &&
      profile.horaires.isNotEmpty;
});

final mecanicienClientsProvider =
    StreamProvider.family<ClientsMecanicien, String>((ref, mecanicienId) {
      final mecanicien = ref.watch(mecanicienProfilProvider);
      if (mecanicien.id != mecanicienId) {
        throw StateError('Le profil mécanicien demandé est indisponible.');
      }
      return ref.watch(mecanicienRepositoryProvider).watchClients(mecanicien);
    });

final mecanicienHistoriqueProvider =
    StreamProvider.family<HistoriqueMecanicien?, String>((ref, motoId) {
      return ref
          .watch(mecanicienRepositoryProvider)
          .watchHistorique(motoId, ref.watch(mecanicienProfilProvider));
    });

final mecanicienInterventionProvider =
    StreamProvider.family<
      ({bool accesActif, Intervention? intervention}),
      ({String motoId, String interventionId})
    >((ref, request) {
      return ref
          .watch(mecanicienRepositoryProvider)
          .watchHistorique(
            request.motoId,
            ref.watch(mecanicienProfilProvider),
          )
          .map((historique) {
            final matches =
                historique?.interventions
                    .where((item) => item.id == request.interventionId)
                    .toList() ??
                const [];
            return (
              accesActif: historique != null,
              intervention: matches.isEmpty ? null : matches.first,
            );
          });
    });
