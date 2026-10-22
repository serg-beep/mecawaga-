import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mecawaga/app.dart';
import 'package:mecawaga/core/router/app_router.dart';
import 'package:mecawaga/features/auth/data/auth_providers.dart';
import 'package:mecawaga/features/auth/data/auth_service.dart';
import 'package:mecawaga/features/auth/domain/utilisateur.dart';
import 'package:mecawaga/features/mecanicien/data/mecanicien_repository.dart';
import 'package:mecawaga/features/mecanicien/presentation/clients/clients_page.dart';
import 'package:mecawaga/features/mecanicien/presentation/atelier/atelier_page.dart';
import 'package:mecawaga/features/proprietaire/data/proprietaire_providers.dart';
import 'package:mecawaga/features/proprietaire/data/proprietaire_repository.dart';
import 'package:mecawaga/features/proprietaire/domain/mecanicien.dart';
import 'package:mecawaga/features/marche/presentation/liste/marche_page.dart';

void main() {
  setUpAll(() => initializeDateFormatting('fr_FR'));

  testWidgets('Démarrage, connexion de démonstration et accueil', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: MecawagaApp()));
    expect(find.text('MecaWaga'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Ravi de vous revoir'), findsOneWidget);

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'demo@mecawaga.fr',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'Moto2026');
    await tester.pump();

    await tester.ensureVisible(find.text('Se connecter'));
    await tester.tap(find.text('Se connecter'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();

    expect(find.text('Historique'), findsWidgets);
  });

  testWidgets('Les écrans principaux restent lisibles à 320 px et 130 %', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 780);
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(const ProviderScope(child: MecawagaApp()));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(find.text('Créer un compte'));
    await tester.tap(find.text('Créer un compte'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Quel est votre profil ?'), findsOneWidget);
    await tester.tap(find.text('Propriétaire'));
    await tester.pumpAndSettle();
    expect(find.text('Nom complet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Les onglets propriétaire tiennent à 320 px et 130 %', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 780);
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final auth = AuthService();
    await tester.runAsync(
      () =>
          auth.signIn(identifiant: 'demo@mecawaga.fr', motDePasse: 'Moto2026'),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authServiceProvider.overrideWithValue(auth)],
        child: const MecawagaApp(),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(tester.takeException(), isNull);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(MecawagaApp)),
    );
    final router = container.read(appRouterProvider);
    for (final tab in ['history', 'reminders', 'market', 'profile', 'moto']) {
      router.go('/owner?tab=$tab');
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);
      if (tab == 'market') {
        expect(find.text('Publier'), findsOneWidget);
        expect(find.text('Honda CB125F d’occasion'), findsOneWidget);
      }
    }
    tester.view.physicalSize = const Size(1024, 900);
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      tester.getSize(find.byType(NavigationBar)).width,
      lessThanOrEqualTo(600),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('L’espace mécanicien reste lisible à 320 px et 130 %', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 780);
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final auth = AuthService();
    await tester.runAsync(
      () => auth.signUp(
        utilisateur: const Utilisateur(
          nomComplet: 'Sam Martin',
          contact: 'sam@example.fr',
          telephone: '0612345678',
          role: RoleUtilisateur.mecanicien,
          nomAtelier: 'Atelier Sam',
        ),
        motDePasse: 'atelier123',
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authServiceProvider.overrideWithValue(auth)],
        child: const MecawagaApp(),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(tester.takeException(), isNull);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(MecawagaApp)),
    );
    final router = container.read(appRouterProvider);
    router.go('/mechanic/profile');
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
    router.go('/market');
    await tester.pumpAndSettle();
    expect(find.byType(MecanicienShellPage), findsOneWidget);
    expect(find.text('Marché'), findsWidgets);
    expect(find.byType(MarchePage), findsOneWidget);
    expect(find.text('Moteur Yamaha 150 cc'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Le propriétaire peut consulter ses motos et son historique', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: MecawagaApp()));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'demo@mecawaga.fr',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'Moto2026');
    await tester.pump();
    await tester.ensureVisible(find.text('Se connecter'));
    await tester.tap(find.text('Se connecter'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();

    expect(find.text('Yamaha MT-07'), findsWidgets);
    expect(find.text('AB-123-CD · 2022'), findsOneWidget);

    await tester.tap(find.text('Historique').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('2 interventions'), findsOneWidget);
    expect(find.text('Entretien courant'), findsWidgets);

    await tester.tap(find.text('Entretien courant').last);
    await tester.pumpAndSettle();
    expect(find.text('Détail de l’intervention'), findsOneWidget);
    expect(find.text('Atelier du Centre'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back).first);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Partager l’historique'));
    await tester.pumpAndSettle();
    expect(find.text('Générer un code d’accès'), findsOneWidget);
    expect(find.text('Mécaniciens autorisés'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rappels').first);
    await tester.pumpAndSettle();
    expect(find.text('Vidange moteur'), findsOneWidget);

    await tester.tap(find.text('Profil').first);
    await tester.pumpAndSettle();
    expect(find.text('Alex Martin'), findsWidgets);
    expect(find.text('demo@mecawaga.fr'), findsOneWidget);
  });

  testWidgets('Le propriétaire peut ajouter une moto', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MecawagaApp()));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'demo@mecawaga.fr',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'Moto2026');
    await tester.pump();
    await tester.ensureVisible(find.text('Se connecter'));
    await tester.tap(find.text('Se connecter'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView).last, const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Ajouter une moto'));
    await tester.tap(find.text('Ajouter une moto'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Suzuki');
    await tester.enterText(fields.at(1), 'V-Strom');
    await tester.enterText(fields.at(2), 'JK-987-LM');
    await tester.enterText(fields.at(3), '2024');
    await tester.enterText(fields.at(4), '2500');
    await tester.pump();
    await tester.ensureVisible(find.text('Enregistrer'));
    await tester.tap(find.text('Enregistrer'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Suzuki V-Strom'), findsOneWidget);
  });

  testWidgets('Inscription mécanicien avec les champs requis', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MecawagaApp()));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Créer un compte'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mécanicien'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Sam Martin');
    await tester.enterText(fields.at(1), '0612345678');
    await tester.enterText(fields.at(2), 'sam@example.fr');
    await tester.enterText(fields.at(3), 'atelier123');
    await tester.enterText(fields.at(4), 'atelier123');
    await tester.enterText(fields.at(5), 'Garage Sam');
    await tester.ensureVisible(find.text('Scooter'));
    await tester.tap(find.text('Scooter'));
    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();

    await tester.ensureVisible(find.text('Créer mon compte'));
    await tester.tap(find.text('Créer mon compte'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();

    expect(find.text('Motos de mes clients'), findsOneWidget);
    expect(
      find.text('Complétez votre atelier pour apparaître dans les recherches'),
      findsOneWidget,
    );
    expect(find.text('Aucune moto pour le moment'), findsOneWidget);

    await tester.tap(find.text('Atelier').last);
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      1,
    );
    expect(find.text('Profil de l’atelier'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byType(FlutterMap),
      320,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(FlutterMap), const Offset(80, 30));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Précisions d’adresse'),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(
      find.byType(TextFormField).first,
      'À côté de la pharmacie, portail bleu',
    );
    await tester.scrollUntilVisible(
      find.byType(SwitchListTile).first,
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.byType(SwitchListTile).first);
    await tester.tap(find.byType(SwitchListTile).first);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Enregistrer mon atelier'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Enregistrer mon atelier'));
    await tester.pumpAndSettle();
    expect(
      find.text('Les informations de votre atelier ont été enregistrées.'),
      findsOneWidget,
    );
    await tester.tap(find.byIcon(Icons.people_outline));
    await tester.pumpAndSettle();
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      0,
    );
    expect(find.text('Motos de mes clients'), findsOneWidget);
    expect(
      find.text('Complétez votre atelier pour apparaître dans les recherches'),
      findsNothing,
    );
    expect(find.byType(AtelierPage), findsNothing);
    expect(find.byType(ClientsPage), findsOneWidget);

    final clientsList = find.descendant(
      of: find.byType(ClientsPage),
      matching: find.byType(ListView),
    );
    await tester.scrollUntilVisible(
      find.text('Saisir un code d’accès'),
      300,
      scrollable: find
          .descendant(
            of: find.byType(ClientsPage),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.drag(clientsList.first, const Offset(0, -180));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Saisir un code d’accès'));
    await tester.tap(find.text('Saisir un code d’accès'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'MOTO-684K2T');
    await tester.pump();
    await tester.tap(find.text('Vérifier le code'));
    await tester.pumpAndSettle();
    expect(find.text('Honda Forza 350'), findsOneWidget);
    expect(find.textContaining('Camille Laurent'), findsOneWidget);

    await tester.tap(find.text('Ajouter à mes clients'));
    await tester.pumpAndSettle();
    expect(find.text('Honda Forza 350'), findsOneWidget);

    await tester.tap(find.text('Honda Forza 350'));
    await tester.pumpAndSettle();
    expect(find.text('Historique de la moto'), findsOneWidget);
    expect(find.text('1 intervention'), findsOneWidget);
    await tester.tap(find.text('Entretien courant').last);
    await tester.pumpAndSettle();
    expect(find.text('Détail de l’intervention'), findsOneWidget);
    expect(find.text('Pièces utilisées'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ajouter une intervention'));
    await tester.pumpAndSettle();
    expect(find.text('Nouvelle intervention'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, '7000');
    await tester.tap(find.text('Entretien courant'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Enregistrer l’intervention'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Enregistrer l’intervention'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enregistrer l’intervention'));
    await tester.pumpAndSettle();
    expect(
      find.text('L’intervention a été ajoutée à l’historique.'),
      findsOneWidget,
    );
    expect(find.text('2 interventions'), findsOneWidget);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(MecawagaApp)),
    );
    final ownerHistory = await container
        .read(proprietaireRepositoryProvider)
        .getInterventions('moto-2');
    expect(ownerHistory.first.mecanicienNom, 'Garage Sam');
    expect(ownerHistory.first.kilometrage, 7000);

    await tester.tap(find.byIcon(Icons.arrow_back).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pumpAndSettle();
    expect(find.text('Aperçu de votre atelier'), findsOneWidget);
    await tester.tap(find.text('Modifier mon profil'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Samuel Martin');
    await tester.ensureVisible(find.text('Enregistrer'));
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(find.text('Modifier mon profil'), findsOneWidget);
    expect(find.text('Samuel Martin'), findsOneWidget);
    await tester.ensureVisible(find.text('Voir l’aperçu public'));
    await tester.tap(find.text('Voir l’aperçu public'));
    await tester.pumpAndSettle();
    expect(find.text('Profil du mécanicien'), findsOneWidget);
    expect(find.text('Garage Sam'), findsOneWidget);
  });

  test(
    'Le dépôt mécanicien respecte le retrait d’accès du propriétaire',
    () async {
      final proprietaireRepository = FakeProprietaireRepository();
      final mecanicienRepository = FakeMecanicienRepository(
        proprietaireRepository,
      );
      const mecanicien = Mecanicien(
        id: 'mec-1',
        nomAtelier: 'Atelier de test',
        telephone: '',
        specialites: [],
        latitude: 0,
        longitude: 0,
        precisionsAdresse: '',
        horaires: {},
      );

      final initial = await mecanicienRepository.getClients(mecanicien);
      expect(initial.motos.map((client) => client.moto.id), ['moto-1']);

      final candidate = await mecanicienRepository.findMotoWithCode(
        'MOTO-684K2T',
        mecanicien,
      );
      await mecanicienRepository.addClient(candidate, mecanicien);
      await expectLater(
        mecanicienRepository.findMotoWithCode('MOTO-684K2T', mecanicien),
        throwsA(isA<CodeAccesMecanicienException>()),
      );

      await proprietaireRepository.revokeMechanicAccess(
        'moto-1',
        mecanicien.id,
      );
      final afterRevocation = await mecanicienRepository.getClients(mecanicien);
      expect(afterRevocation.motos.map((client) => client.moto.id), ['moto-2']);
      expect(afterRevocation.accesRetires.map((client) => client.moto.id), [
        'moto-1',
      ]);
    },
  );
}
