import 'package:flutter_test/flutter_test.dart';
import 'package:mecawaga/features/marche/data/annonce_repository.dart';
import 'package:mecawaga/features/marche/domain/annonce.dart';

void main() {
  group('FakeAnnonceRepository', () {
    test('fournit au moins douze annonces actives au démarrage', () async {
      final repository = FakeAnnonceRepository();

      final announcements = await repository.getActiveAnnouncements();

      expect(announcements.length, greaterThanOrEqualTo(12));
      expect(
        announcements.every(
          (announcement) => announcement.statut == StatutAnnonce.active,
        ),
        isTrue,
      );
    });

    test('recherche par préfixe, filtre et pagine les annonces', () async {
      final repository = FakeAnnonceRepository();

      final first = await repository.getActiveAnnouncementPage(
        query: const AnnonceQuery(
          category: Categorie.accessoires,
          titlePrefix: 'Rétro',
          sort: AnnonceSort.priceAscending,
        ),
        pageSize: 1,
      );

      expect(first.items, hasLength(1));
      expect(first.items.single.titre, 'Rétroviseurs universels');
      expect(first.hasMore, isFalse);
    });

    test('trie les pages par prix croissant sans répéter les annonces', () async {
      final repository = FakeAnnonceRepository();
      const query = AnnonceQuery(
        category: Categorie.accessoires,
        sort: AnnonceSort.priceAscending,
      );

      final first = await repository.getActiveAnnouncementPage(
        query: query,
        pageSize: 1,
      );
      final second = await repository.getActiveAnnouncementPage(
        query: query,
        cursor: first.cursor,
        pageSize: 1,
      );

      expect(first.items.single.prix, 9000);
      expect(second.items.single.prix, 52000);
      expect(first.items.single.id, isNot(second.items.single.id));
    });

    test('masque une annonce après trois signalements distincts', () async {
      final repository = FakeAnnonceRepository();
      const announcementId = 'annonce-1';

      for (var index = 1; index <= 3; index++) {
        final hidden = await repository.reportAnnouncement(
          Signalement(
            annonceId: announcementId,
            auteurId: 'utilisateur-$index',
            motif: 'Informations fausses',
            date: DateTime(2025, 1, index),
          ),
        );
        expect(hidden, index == 3);
      }

      expect(
        await repository.getAnnouncement(announcementId),
        isA<Annonce>().having(
          (announcement) => announcement.statut,
          'statut',
          StatutAnnonce.masquee,
        ),
      );
      expect(
        (await repository.getActiveAnnouncements()).any(
          (announcement) => announcement.id == announcementId,
        ),
        isFalse,
      );
    });

    test('refuse plusieurs signalements du même auteur', () async {
      final repository = FakeAnnonceRepository();
      final report = Signalement(
        annonceId: 'annonce-1',
        auteurId: 'utilisateur-1',
        motif: 'Annonce frauduleuse',
        date: DateTime(2025),
      );

      await repository.reportAnnouncement(report);

      await expectLater(
        repository.reportAnnouncement(report),
        throwsA(isA<MarketRepositoryException>()),
      );
    });
  });
}
