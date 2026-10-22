import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/proprietaire/domain/intervention.dart';
import '../../features/proprietaire/domain/mecanicien.dart';
import '../../features/proprietaire/domain/moto.dart';
import '../../features/proprietaire/presentation/access/code_access_page.dart';
import '../../features/proprietaire/presentation/historique/historique_page.dart';
import '../../features/proprietaire/presentation/historique/intervention_detail_page.dart';
import '../../features/proprietaire/presentation/mecaniciens/mecaniciens_page.dart';
import '../../features/proprietaire/presentation/motos/moto_form_page.dart';
import '../../features/proprietaire/presentation/motos/moto_list_page.dart';
import '../../features/proprietaire/presentation/owner_shell_page.dart';
import '../../features/proprietaire/presentation/owner_widgets.dart';
import '../../features/proprietaire/presentation/profil/mecanicien_profile_page.dart';
import '../../features/proprietaire/presentation/profil/profil_proprietaire_page.dart';
import '../../features/proprietaire/presentation/rappels/rappels_page.dart';
import '../../features/mecanicien/domain/moto_client.dart';
import '../../features/mecanicien/presentation/clients/clients_page.dart';
import '../../features/mecanicien/presentation/code_acces/code_access_page.dart'
    as mechanic_code;
import '../../features/mecanicien/presentation/historique/historique_page.dart';
import '../../features/mecanicien/presentation/historique/intervention_detail_page.dart';
import '../../features/mecanicien/presentation/interventions/intervention_form_page.dart';
import '../../features/auth/data/auth_providers.dart';
import '../../features/auth/domain/utilisateur.dart';
import '../../features/auth/presentation/about_page.dart';
import '../../features/auth/presentation/choix_role_page.dart';
import '../../features/auth/presentation/forgot_password_page.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/auth/presentation/legal_document_page.dart';
import '../../features/auth/presentation/register_page.dart';
import '../../features/auth/presentation/splash_page.dart';
import '../../features/marche/domain/annonce.dart';
import '../../features/marche/presentation/fiche/annonce_detail_page.dart';
import '../../features/marche/presentation/mes_annonces/mes_annonces_page.dart';
import '../../features/marche/presentation/publication/annonce_form_page.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authRepository = ref.watch(authServiceProvider);
  final router = GoRouter(
    initialLocation: '/splash',
    refreshListenable: authRepository,
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const SplashPage()),
      GoRoute(
        path: '/role',
        builder: (context, state) => const ChoixRolePage(),
      ),
      GoRoute(
        path: '/register/:role',
        builder: (context, state) => RegisterPage(
          role: RoleUtilisateurLabel.fromRoute(state.pathParameters['role']),
        ),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordPage(),
      ),
      GoRoute(
        path: '/legal/privacy',
        builder: (context, state) =>
            const LegalDocumentPage(document: LegalDocument.privacy),
      ),
      GoRoute(
        path: '/legal/terms',
        builder: (context, state) =>
            const LegalDocumentPage(document: LegalDocument.terms),
      ),
      GoRoute(path: '/about', builder: (context, state) => const AboutPage()),
      GoRoute(
        path: '/home/:role',
        builder: (context, state) {
          final role = RoleUtilisateurLabel.fromRoute(
            state.pathParameters['role'],
          );
          return role == RoleUtilisateur.proprietaire
              ? const OwnerShellPage()
              : const MecanicienShellPage();
        },
      ),
      GoRoute(
        path: '/mechanic',
        builder: (context, state) => MecanicienShellPage(
          initialTab: state.uri.queryParameters['tab'] == 'market' ? 2 : 0,
        ),
      ),
      GoRoute(
        path: '/mechanic/workshop',
        builder: (context, state) => const MecanicienShellPage(initialTab: 1),
      ),
      GoRoute(
        path: '/mechanic/profile',
        builder: (context, state) => const MecanicienShellPage(initialTab: 3),
      ),
      GoRoute(
        path: '/mechanic/market',
        builder: (context, state) => const MecanicienShellPage(initialTab: 2),
      ),
      GoRoute(
        path: '/mechanic/code',
        builder: (context, state) => const mechanic_code.CodeAccessPage(),
      ),
      GoRoute(
        path: '/mechanic/code/confirmation',
        builder: (context, state) => mechanic_code.CodeAccessConfirmationPage(
          client: state.extra! as MotoClient,
        ),
      ),
      GoRoute(
        path: '/mechanic/moto/:motoId/history',
        builder: (context, state) =>
            HistoriqueMecanicienPage(motoId: state.pathParameters['motoId']!),
      ),
      GoRoute(
        path: '/mechanic/moto/:motoId/intervention/:interventionId',
        builder: (context, state) => InterventionDetailMecanicienPage(
          motoId: state.pathParameters['motoId']!,
          interventionId: state.pathParameters['interventionId']!,
        ),
      ),
      GoRoute(
        path: '/mechanic/add-intervention/:motoId',
        builder: (context, state) =>
            InterventionFormPage(motoId: state.pathParameters['motoId']!),
      ),
      GoRoute(
        path: '/mechanic/profile/preview',
        builder: (context, state) =>
            MecanicienProfilePage(mecanicien: state.extra! as Mecanicien),
      ),
      GoRoute(
        path: '/owner',
        builder: (context, state) => OwnerShellPage(
          initialTab: switch (state.uri.queryParameters['tab']) {
            'history' => 1,
            'reminders' => 2,
            'market' => 3,
            'profile' => 4,
            _ => 0,
          },
        ),
      ),
      GoRoute(
        path: '/owner/moto/form',
        builder: (context, state) => MotoFormPage(moto: state.extra as Moto?),
      ),
      GoRoute(
        path: '/owner/motos',
        builder: (context, state) =>
            const OwnerPage(title: 'Mes motos', child: MotoListPage()),
      ),
      GoRoute(
        path: '/owner/intervention/:id',
        builder: (context, state) =>
            InterventionDetailPage(intervention: state.extra! as Intervention),
      ),
      GoRoute(
        path: '/owner/access/:motoId',
        builder: (context, state) =>
            CodeAccessPage(motoId: state.pathParameters['motoId']!),
      ),
      GoRoute(
        path: '/owner/mechanics',
        builder: (context, state) => const MecaniciensPage(),
      ),
      GoRoute(
        path: '/owner/mechanic/:id',
        builder: (context, state) =>
            MecanicienProfilePage(mecanicien: state.extra! as Mecanicien),
      ),
      GoRoute(
        path: '/owner/profile',
        builder: (context, state) => const ProfilProprietairePage(),
      ),
      GoRoute(
        path: '/owner/history',
        builder: (context, state) => const HistoriquePage(),
      ),
      GoRoute(
        path: '/owner/reminders',
        builder: (context, state) => const RappelsPage(),
      ),
      GoRoute(
        path: '/market',
        builder: (context, state) {
          final user = authRepository.utilisateurConnecte;
          return user?.role == RoleUtilisateur.mecanicien
              ? const MecanicienShellPage(initialTab: 2)
              : const OwnerShellPage(initialTab: 3);
        },
      ),
      GoRoute(
        path: '/market/mine',
        builder: (context, state) => const MesAnnoncesPage(),
      ),
      GoRoute(
        path: '/market/publish',
        builder: (context, state) => AnnonceFormPage(
          annonce: state.extra as Annonce?,
        ),
      ),
      GoRoute(
        path: '/market/annonce/:id',
        builder: (context, state) => AnnonceDetailPage(
          annonceId: state.pathParameters['id']!,
        ),
      ),
    ],
    errorBuilder: (context, state) => const LoginPage(),
    redirect: (context, state) {
      final location = state.matchedLocation;
      final user = authRepository.utilisateurConnecte;
      final isAuthRoute =
          location == '/splash' ||
          location == '/login' ||
          location == '/role' ||
          location == '/forgot-password' ||
          location.startsWith('/legal/') ||
          location.startsWith('/register/');

      if (user == null) {
        return isAuthRoute ? null : '/login';
      }

      final home = '/home/${user.role.routeSegment}';
      if (isAuthRoute) return home;
      if (location == '/home/proprietaire' &&
          user.role != RoleUtilisateur.proprietaire) {
        return home;
      }
      if (location == '/home/mecanicien' &&
          user.role != RoleUtilisateur.mecanicien) {
        return home;
      }
      if (location.startsWith('/owner') &&
          user.role != RoleUtilisateur.proprietaire) {
        return home;
      }
      if (location.startsWith('/mechanic') &&
          user.role != RoleUtilisateur.mecanicien) {
        return home;
      }
      return null;
    },
  );
  ref.onDispose(router.dispose);
  return router;
});
