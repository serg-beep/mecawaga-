import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/etat_chargement.dart';
import '../../../../core/widgets/list_item_entrance.dart';
import '../../../../core/widgets/etat_messages.dart';
import '../../../auth/data/auth_providers.dart';
import '../../data/mecanicien_providers.dart';
import '../../domain/moto_client.dart';
import '../profil/profil_mecanicien_page.dart';
import '../atelier/atelier_page.dart';
import '../../../proprietaire/presentation/owner_widgets.dart';
import '../../../marche/presentation/liste/marche_page.dart';

class MecanicienShellPage extends ConsumerStatefulWidget {
  const MecanicienShellPage({this.initialTab = 0, super.key});

  final int initialTab;

  @override
  ConsumerState<MecanicienShellPage> createState() =>
      _MecanicienShellPageState();
}

class _MecanicienShellPageState extends ConsumerState<MecanicienShellPage> {
  late int _selectedTab = widget.initialTab;

  @override
  void didUpdateWidget(covariant MecanicienShellPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab != widget.initialTab) {
      _selectedTab = widget.initialTab.clamp(0, 3);
    }
  }

  @override
  Widget build(BuildContext context) {
    final titles = ['Clients', 'Mon atelier', 'Marché', 'Profil'];
    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_selectedTab]),
        actions: [
          if (_selectedTab == 2)
            IconButton(
              tooltip: 'Mes annonces',
              onPressed: () => context.push('/market/mine'),
              icon: const Icon(Icons.sell_outlined),
            ),
          IconButton(
            tooltip: 'Se déconnecter',
            onPressed: () async {
              final confirmed = await confirmerActionIrreversible(
                context,
                titre: 'Se déconnecter ?',
                message:
                    'Vous devrez saisir vos identifiants pour accéder de nouveau à votre compte.',
                confirmation: 'Se déconnecter',
              );
              if (!confirmed || !context.mounted) return;
              ref.read(authServiceProvider).signOut();
              context.go('/login');
            },
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: switch (_selectedTab) {
          0 => const ClientsPage(),
          1 => const AtelierTabPage(),
          2 => const MarchePage(),
          _ => const ProfilMecanicienPage(),
        },
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedTab,
        onDestinationSelected: (index) => setState(() => _selectedTab = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Clients',
          ),
          NavigationDestination(
            icon: Icon(Icons.home_repair_service_outlined),
            selectedIcon: Icon(Icons.home_repair_service),
            label: 'Atelier',
          ),
          NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront),
            label: 'Marché',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}

class ClientsPage extends ConsumerStatefulWidget {
  const ClientsPage({super.key});

  @override
  ConsumerState<ClientsPage> createState() => _ClientsPageState();
}

class _ClientsPageState extends ConsumerState<ClientsPage> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _restoreWorkshopProfile();
      }
    });
  }

  Future<void> _restoreWorkshopProfile() async {
    final mecanicienId = ref.read(mecanicienIdProvider);
    try {
      final saved = await ref
          .read(mecanicienRepositoryProvider)
          .getWorkshopProfile(mecanicienId);
      if (!mounted) return;
      if (saved != null) {
        ref
                .read(mecanicienProfilOverrideProvider(mecanicienId).notifier)
                .state =
            saved;
      }
      ref.invalidate(mecanicienClientsProvider(mecanicienId));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Impossible de charger le profil atelier : $error'),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mecanicien = ref.watch(mecanicienProfilProvider);
    final workshopComplete = ref.watch(mecanicienProfilCompletProvider);
    final asyncClients = ref.watch(mecanicienClientsProvider(mecanicien.id));
    return asyncClients.when(
      loading: () => const EtatChargement(),
      error: (error, stack) => StateMessage(
        icon: Icons.cloud_off_outlined,
        title: 'Impossible de charger vos clients',
        message: 'Vérifiez votre connexion puis réessayez de charger la liste.',
        action: FilledButton(
          onPressed: () =>
              ref.invalidate(mecanicienClientsProvider(mecanicien.id)),
          child: const Text('Réessayer'),
        ),
      ),
      data: (snapshot) {
        final filtered = snapshot.motos.where((client) {
          final query = _query.trim().toLowerCase();
          return query.isEmpty ||
              client.moto.immatriculation.toLowerCase().contains(query) ||
              client.proprietaire.toLowerCase().contains(query);
        }).toList();
        final itemBuilders = <WidgetBuilder>[
          (_) => _WelcomeHeader(atelier: mecanicien.nomAtelier),
          (_) => const SizedBox(height: AppSpacing.lg),
        ];
        for (final client in snapshot.accesRetires) {
          itemBuilders.add((_) => _AccessRemovedNotice(client: client));
        }
        if (snapshot.accesRetires.isNotEmpty) {
          itemBuilders.add((_) => const SizedBox(height: 12));
        }
        if (!workshopComplete) {
          itemBuilders.add(
            (context) => InkWell(
              borderRadius: BorderRadius.circular(AppRadii.field),
              onTap: () => context.go('/mechanic/workshop'),
              child: Container(
                constraints: const BoxConstraints(minHeight: 64),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.orangePale,
                  border: Border.all(
                    color: AppColors.orange.withValues(alpha: 0.55),
                  ),
                  borderRadius: BorderRadius.circular(AppRadii.field),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: AppColors.bleuFonce),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Complétez votre atelier pour apparaître dans les recherches',
                        style: TextStyle(
                          color: AppColors.texte,
                          fontWeight: FontWeight.w700,
                          height: 1.4,
                        ),
                      ),
                    ),
                    Icon(Icons.chevron_right, color: AppColors.texte),
                  ],
                ),
              ),
            ),
          );
        }
        itemBuilders
          ..add((_) => const SizedBox(height: AppSpacing.xxl))
          ..add(
            (context) => Text(
              'Motos de mes clients',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          )
          ..add((_) => const SizedBox(height: 12))
          ..add(
            (_) => TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                labelText: 'Rechercher une moto ou un propriétaire',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Effacer la recherche',
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                        icon: const Icon(Icons.close),
                      ),
              ),
            ),
          )
          ..add((_) => const SizedBox(height: 12));
        if (snapshot.motos.isEmpty) {
          itemBuilders.add(
            (_) => const StateMessage(
              icon: Icons.two_wheeler_outlined,
              title: 'Aucune moto pour le moment',
              message:
                  'Demandez au propriétaire le code d’accès de sa moto pour l’ajouter à vos clients.',
            ),
          );
        } else if (filtered.isEmpty) {
          itemBuilders.add(
            (_) => const StateMessage(
              icon: Icons.search_off,
              title: 'Aucun résultat',
              message:
                  'Essayez une autre immatriculation ou le nom du propriétaire.',
            ),
          );
        } else {
          for (final client in filtered) {
            itemBuilders.add(
              (_) => ListItemEntrance(
                key: ValueKey('client-${client.moto.id}'),
                child: _ClientMotoCard(client: client),
              ),
            );
          }
        }
        itemBuilders
          ..add((_) => const SizedBox(height: 16))
          ..add(
            (context) => SizedBox(
              height: 54,
              child: FilledButton.icon(
                onPressed: () => context.push('/mechanic/code'),
                icon: const Icon(Icons.key_rounded),
                label: const Text('Saisir un code d’accès'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.orange,
                  foregroundColor: AppColors.texte,
                ),
              ),
            ),
          );
        return RefreshIndicator(
          onRefresh: () async =>
              ref.invalidate(mecanicienClientsProvider(mecanicien.id)),
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 112),
            itemCount: itemBuilders.length,
            itemBuilder: (context, index) => itemBuilders[index](context),
          ),
        );
      },
    );
  }
}

class _WelcomeHeader extends StatelessWidget {
  const _WelcomeHeader({required this.atelier});

  final String atelier;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: AppColors.bleu.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadii.field),
        ),
        child: const Icon(
          Icons.handyman_outlined,
          color: AppColors.bleu,
          size: 28,
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              atelier,
              style: Theme.of(context).textTheme.titleLarge,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            const Text(
              'Bienvenue dans votre espace mécanicien',
              style: TextStyle(color: AppColors.texteDoux),
            ),
          ],
        ),
      ),
    ],
  );
}

class _AccessRemovedNotice extends StatelessWidget {
  const _AccessRemovedNotice({required this.client});

  final MotoClient client;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(AppSpacing.lg),
    decoration: BoxDecoration(
      color: AppColors.orangePale,
      borderRadius: BorderRadius.circular(AppRadii.field),
      border: Border.all(color: AppColors.orange.withValues(alpha: 0.55)),
    ),
    child: Text(
      'Le propriétaire a retiré votre accès à cette moto (${client.moto.nom}).',
      style: const TextStyle(
        color: AppColors.texte,
        fontWeight: FontWeight.w700,
        height: 1.4,
      ),
    ),
  );
}

class _ClientMotoCard extends StatelessWidget {
  const _ClientMotoCard({required this.client});

  final MotoClient client;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: OwnerCard(
      onTap: () => context.push('/mechanic/moto/${client.moto.id}/history'),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.bleu.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.two_wheeler, color: AppColors.bleu),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  client.moto.nom,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontSize: 17),
                ),
                Text(
                  client.moto.immatriculation,
                  style: const TextStyle(
                    color: AppColors.texteDoux,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Propriétaire : ${client.proprietaire}',
                  style: const TextStyle(color: AppColors.texteDoux),
                ),
                Text(
                  client.derniereIntervention == null
                      ? 'Aucune intervention enregistrée'
                      : 'Dernière intervention : ${DateFormat('d MMM yyyy', 'fr_FR').format(client.derniereIntervention!)}',
                  style: const TextStyle(
                    color: AppColors.texteDoux,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
    ),
  );
}

class AtelierTabPage extends StatelessWidget {
  const AtelierTabPage({super.key});

  @override
  Widget build(BuildContext context) => const AtelierPage();
}
