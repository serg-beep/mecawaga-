import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';

import '../domain/annonce.dart';
import 'annonce_repository.dart';
import '../../../core/firebase/photo_storage_service.dart';
import 'firebase_annonce_repository.dart';

final annonceRepositoryProvider = Provider<AnnonceRepository>(
  (ref) => Firebase.apps.isEmpty
      ? FakeAnnonceRepository()
      : FirebaseAnnonceRepository(
          photoStorageService: ref.watch(photoStorageServiceProvider),
        ),
);

final annoncesActivesProvider = FutureProvider<List<Annonce>>(
  (ref) => ref.watch(annonceRepositoryProvider).getActiveAnnouncements(),
);

final mesAnnoncesProvider = FutureProvider.family<List<Annonce>, String>(
  (ref, vendeurId) =>
      ref.watch(annonceRepositoryProvider).getMyAnnouncements(vendeurId),
);

final annonceProvider = FutureProvider.family<Annonce?, String>(
  (ref, id) => ref.watch(annonceRepositoryProvider).getAnnouncement(id),
);
