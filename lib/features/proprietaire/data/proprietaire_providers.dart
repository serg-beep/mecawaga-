import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/moto.dart';
import '../domain/rappel.dart';
import 'firebase_meca_repository.dart';
import 'proprietaire_repository.dart';

final proprietaireRepositoryProvider = Provider<ProprietaireRepository>(
  (ref) => Firebase.apps.isEmpty
      ? FakeProprietaireRepository()
      : FirebaseMecaRepository(),
);

final motosProvider = StreamProvider<List<Moto>>(
  (ref) => ref.watch(proprietaireRepositoryProvider).watchMotos(),
);

final selectedMotoProvider = StateProvider<String?>((ref) => null);

final selectedMotoObjectProvider = Provider<Moto?>((ref) {
  final motos = ref.watch(motosProvider).valueOrNull ?? const <Moto>[];
  final selectedId = ref.watch(selectedMotoProvider);
  if (motos.isEmpty) return null;
  return motos.firstWhere(
    (moto) => moto.id == selectedId,
    orElse: () => motos.first,
  );
});

final rappelsProvider = StreamProvider.family<List<Rappel>, String>(
  (ref, motoId) => ref.watch(proprietaireRepositoryProvider).watchRappels(motoId),
);
