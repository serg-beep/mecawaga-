import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/etat_chargement.dart';
import '../../../core/widgets/list_item_entrance.dart';
import 'package:intl/intl.dart';

import '../../marche/presentation/liste/marche_page.dart';
import '../../../core/theme/app_theme.dart';
import '../data/proprietaire_providers.dart';
import '../domain/moto.dart';
import 'historique/historique_page.dart';
import 'profil/profil_proprietaire_page.dart';
import 'rappels/rappels_page.dart';
import 'owner_widgets.dart';

class OwnerShellPage extends ConsumerWidget {
  const OwnerShellPage({super.key, this.initialTab = 0});
  final int initialTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final motosAsync = ref.watch(motosProvider);
    final moto = ref.watch(selectedMotoObjectProvider);
    final tab = initialTab.clamp(0, 4);
    final pages = [
      _MotoHomePage(motosAsync: motosAsync, moto: moto),
      const HistoriquePage(),
      const RappelsPage(),
      const MarchePage(),
      const ProfilProprietairePage(),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(const [
          'Ma moto',
          'Historique',
          'Rappels',
          'Marché',
          'Profil',
        ][tab]),
        actions: [
          if (tab == 3)
            IconButton(
              tooltip: 'Mes annonces',
              onPressed: () => context.push('/market/mine'),
              icon: const Icon(Icons.sell_outlined),
            )
          else if (tab == 0)
            IconButton(
              tooltip: 'Trouver un mécanicien',
              onPressed: () => context.push('/owner/mechanics'),
              icon: const Icon(Icons.search),
            ),
        ],
      ),
      body: SafeArea(
        child: IndexedStack(index: tab, children: pages),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (index) => context.go(
          '/owner?tab=${const ['moto', 'history', 'reminders', 'market', 'profile'][index]}',
        ),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.two_wheeler_outlined),
            selectedIcon: Icon(Icons.two_wheeler),
            label: 'Ma moto',
          ),
          NavigationDestination(icon: Icon(Icons.history), label: 'Historique'),
          NavigationDestination(
            icon: Icon(Icons.notifications_outlined),
            selectedIcon: Icon(Icons.notifications),
            label: 'Rappels',
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

class _MotoHomePage extends ConsumerWidget {
  const _MotoHomePage({required this.motosAsync, required this.moto});
  final AsyncValue<List<Moto>> motosAsync;
  final Moto? moto;

  @override
  Widget build(BuildContext context, WidgetRef ref) => motosAsync.when(
    loading: () => const EtatChargement(),
    error: (error, stack) => StateMessage(
      icon: Icons.cloud_off_outlined,
      title: 'Vos motos sont indisponibles',
      message: 'Réessayez pour charger la liste de vos motos.',
      action: FilledButton(
        onPressed: () => ref.invalidate(motosProvider),
        child: const Text('Réessayer'),
      ),
    ),
    data: (motos) => motos.isEmpty
        ? StateMessage(
            icon: Icons.two_wheeler_outlined,
            title: 'Ajoutez votre première moto',
            message:
                'Centralisez son kilométrage, ses entretiens et ses rappels.',
            action: FilledButton.icon(
              onPressed: () => context.push('/owner/moto/form'),
              icon: const Icon(Icons.add),
              label: const Text('Ajouter une moto'),
            ),
          )
        : _motoList(context, ref, motos, moto),
  );

  Widget _motoList(
    BuildContext context,
    WidgetRef ref,
    List<Moto> motos,
    Moto? selectedMoto,
  ) {
    final showSelector = motos.length > 1;
    final motoStart = showSelector ? 2 : 1;
    final addSpacerIndex = motoStart + motos.length;
    final addButtonIndex = addSpacerIndex + 1;
    final mechanicsSpacerIndex = addButtonIndex + 1;
    final mechanicsButtonIndex = mechanicsSpacerIndex + 1;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      itemCount: mechanicsButtonIndex + 1,
      itemBuilder: (context, index) {
        if (showSelector && index == 0) {
          return MotoSelector(
            motos: motos,
            selected: selectedMoto ?? motos.first,
            onChanged: (value) =>
                ref.read(selectedMotoProvider.notifier).state = value.id,
          );
        }
        if (index == (showSelector ? 1 : 0)) {
          return const SizedBox(height: AppSpacing.sm);
        }
        if (index >= motoStart && index < addSpacerIndex) {
          final bike = motos[index - motoStart];
          return ListItemEntrance(
            key: ValueKey('bike-${bike.id}'),
            child: _BikeCard(bike: bike),
          );
        }
        if (index == addSpacerIndex) return const SizedBox(height: 8);
        if (index == addButtonIndex) {
          return OutlinedButton.icon(
            onPressed: () => context.push('/owner/moto/form'),
            icon: const Icon(Icons.add),
            label: const Text('Ajouter une moto'),
            style: OutlinedButton.styleFrom(minimumSize: const Size(48, 52)),
          );
        }
        if (index == mechanicsSpacerIndex) {
          return const SizedBox(height: 20);
        }
        return FilledButton.icon(
          onPressed: () => context.push('/owner/mechanics'),
          icon: const Icon(Icons.search),
          label: const Text('Trouver un mécanicien'),
          style: FilledButton.styleFrom(minimumSize: const Size(48, 52)),
        );
      },
    );
  }
}

class _BikeCard extends ConsumerWidget {
  const _BikeCard({required this.bike});
  final Moto bike;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: OwnerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.two_wheeler, color: AppColors.bleu, size: 34),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  bike.nom,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: 'Modifier la moto',
                onPressed: () => context.push('/owner/moto/form', extra: bike),
                icon: const Icon(Icons.edit_outlined),
              ),
            ],
          ),
          Text(
            '${bike.immatriculation} · ${bike.annee}',
            style: const TextStyle(color: AppColors.texteDoux),
          ),
          Consumer(
            builder: (context, ref, child) {
              final reminders = ref.watch(rappelsProvider(bike.id));
              final upcoming = reminders.valueOrNull
                  ?.where((item) => item.date.isAfter(DateTime.now()))
                  .toList();
              if (reminders.isLoading || upcoming == null || upcoming.isEmpty) {
                return const SizedBox.shrink();
              }
              upcoming.sort((a, b) => a.date.compareTo(b.date));
              final days = upcoming.first.date
                  .difference(DateTime.now())
                  .inDays;
              if (days > 30) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.orangePale,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    child: Text(
                      'Rappel dans $days jour${days == 1 ? '' : 's'} · ${DateFormat('d MMM', 'fr_FR').format(upcoming.first.date)}',
                      style: const TextStyle(
                        color: AppColors.texte,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          LayoutBuilder(
            builder: (context, constraints) {
              final historyButton = TextButton(
                onPressed: () {
                  ref.read(selectedMotoProvider.notifier).state = bike.id;
                  context.go('/owner?tab=history');
                },
                child: const Text('Voir l’historique'),
              );
              if (constraints.maxWidth < 320) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _AnimatedMileage(value: bike.kilometrage),
                    Align(
                      alignment: Alignment.centerRight,
                      child: historyButton,
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: _AnimatedMileage(value: bike.kilometrage)),
                  historyButton,
                ],
              );
            },
          ),
        ],
      ),
    ),
  );
}

class _AnimatedMileage extends StatelessWidget {
  const _AnimatedMileage({required this.value});
  final int value;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<int>(
    tween: IntTween(begin: 0, end: value),
    duration: AppTheme.animationDuration,
    builder: (context, current, child) => Text(
      '${NumberFormat.decimalPattern('fr_FR').format(current)} km',
      style: const TextStyle(fontWeight: FontWeight.w800),
    ),
  );
}
