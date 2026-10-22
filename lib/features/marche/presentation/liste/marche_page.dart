import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/etat_chargement.dart';
import '../../../../core/widgets/etat_messages.dart';
import '../../data/marche_providers.dart';
import '../../data/annonce_repository.dart';
import '../../domain/annonce.dart';
import '../../marche_constants.dart';
import '../marche_widgets.dart';

enum TriAnnonces { recentes, prixCroissant, prixDecroissant }

class MarchePage extends ConsumerStatefulWidget {
  const MarchePage({super.key});

  @override
  ConsumerState<MarchePage> createState() => _MarchePageState();
}

class _MarchePageState extends ConsumerState<MarchePage> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  final List<Annonce> _items = [];
  Object? _cursor;
  Timer? _searchTimer;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _loadError;
  int _requestGeneration = 0;
  String _query = '';
  String _city = '';
  Categorie? _category;
  Set<EtatProduit> _states = {};
  RangeValues _priceRange = const RangeValues(0, prixMaximumFiltre);
  TriAnnonces _sort = TriAnnonces.recentes;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _searchTimer?.cancel();
    super.dispose();
  }

  AnnonceQuery get _activeQuery => AnnonceQuery(
    category: _category,
    states: _states,
    minimumPrice: _priceRange.start,
    maximumPrice: _priceRange.end,
    city: _city,
    titlePrefix: _query,
    sort: switch (_sort) {
      TriAnnonces.recentes => AnnonceSort.recent,
      TriAnnonces.prixCroissant => AnnonceSort.priceAscending,
      TriAnnonces.prixDecroissant => AnnonceSort.priceDescending,
    },
  );

  Future<void> _reload() async {
    if (!mounted) return;
    _requestGeneration++;
    setState(() {
      _items.clear();
      _cursor = null;
      _hasMore = true;
      _loading = true;
      _loadingMore = false;
      _loadError = null;
    });
    await _loadNextPage();
  }

  Future<void> _loadNextPage() async {
    if (!mounted || !_hasMore || _loadingMore) return;
    final generation = _requestGeneration;
    setState(() {
      _loadingMore = true;
      _loadError = null;
    });
    try {
      final results = <Annonce>[];
      var nextCursor = _cursor;
      var hasMore = _hasMore;
      do {
        final page = await ref
            .read(annonceRepositoryProvider)
            .getActiveAnnouncementPage(
              query: _activeQuery,
              cursor: nextCursor,
            );
        results.addAll(page.items);
        nextCursor = page.cursor;
        hasMore = page.hasMore;
      } while (hasMore && _items.length + results.length < 20);
      if (!mounted) return;
      if (generation != _requestGeneration) return;
      setState(() {
        _items.addAll(results);
        _cursor = nextCursor;
        _hasMore = hasMore;
        _loading = false;
        _loadingMore = false;
      });
    } on Exception catch (error) {
      if (!mounted) return;
      if (generation != _requestGeneration) return;
      setState(() {
        _loadError = error is MarketRepositoryException
            ? error.message
            : 'Impossible de charger les annonces. Vérifiez votre connexion puis réessayez.';
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  void _onScroll() {
    if (_scrollController.position.extentAfter < 500) {
      unawaited(_loadNextPage());
    }
  }

  Future<void> _openFilters() async {
    final cityController = TextEditingController(text: _city);
    final result = await showModalBottomSheet<_MarketFilters>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        var selectedStates = {..._states};
        var range = _priceRange;
        return StatefulBuilder(
          builder: (context, setSheetState) => SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Filtres',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    const Text(
                      'État du produit',
                      style: TextStyle(
                        color: AppColors.texte,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Wrap(
                      spacing: AppSpacing.sm,
                      children: [
                        for (final state in EtatProduit.values)
                          FilterChip(
                            label: Text(state.label),
                            selected: selectedStates.contains(state),
                            onSelected: (selected) => setSheetState(() {
                              if (selected) {
                                selectedStates.add(state);
                              } else {
                                selectedStates.remove(state);
                              }
                            }),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Prix : ${formatMarketPrice(range.start.round())} – ${formatMarketPrice(range.end.round())}',
                      style: const TextStyle(
                        color: AppColors.texte,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    RangeSlider(
                      values: range,
                      min: 0,
                      max: prixMaximumFiltre,
                      divisions: 100,
                      labels: RangeLabels(
                        formatMarketPrice(range.start.round()),
                        formatMarketPrice(range.end.round()),
                      ),
                      onChanged: (value) => setSheetState(() => range = value),
                    ),
                    TextField(
                      controller: cityController,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        labelText: 'Ville ou quartier',
                        prefixIcon: Icon(Icons.location_city_outlined),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    FilledButton(
                      onPressed: () => Navigator.pop(
                        context,
                        _MarketFilters(
                          states: selectedStates,
                          priceRange: range,
                          city: cityController.text.trim(),
                        ),
                      ),
                      child: const Text('Voir les résultats'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
    cityController.dispose();
    if (result == null || !mounted) return;
    setState(() {
      _states = result.states;
      _priceRange = result.priceRange;
      _city = result.city;
    });
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/market/publish'),
        backgroundColor: AppColors.orange,
        foregroundColor: AppColors.texte,
        icon: const Icon(Icons.add),
        label: const Text('Publier'),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() => _query = value);
                      _searchTimer?.cancel();
                      _searchTimer = Timer(
                        const Duration(milliseconds: 350),
                        _reload,
                      );
                    },
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Rechercher une annonce',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Effacer la recherche',
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _query = '');
                                unawaited(_reload());
                              },
                              icon: const Icon(Icons.close),
                            ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SizedBox(
                    height: 48,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: AppSpacing.sm),
                          child: ChoiceChip(
                            label: const Text('Tout'),
                            selected: _category == null,
                            onSelected: (_) {
                              setState(() => _category = null);
                              unawaited(_reload());
                            },
                          ),
                        ),
                        for (final category in Categorie.values)
                          Padding(
                            padding: const EdgeInsets.only(right: AppSpacing.sm),
                            child: ChoiceChip(
                              label: Text(category.label),
                              selected: _category == category,
                              onSelected: (_) {
                                setState(
                                  () => _category = _category == category
                                      ? null
                                      : category,
                                );
                                unawaited(_reload());
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: _openFilters,
                        icon: const Icon(Icons.tune),
                        label: const Text('Filtres'),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: DropdownButtonFormField<TriAnnonces>(
                          initialValue: _sort,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Trier',
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.sm,
                            ),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: TriAnnonces.recentes,
                              child: Text('Plus récentes'),
                            ),
                            DropdownMenuItem(
                              value: TriAnnonces.prixCroissant,
                              child: Text('Prix croissant'),
                            ),
                            DropdownMenuItem(
                              value: TriAnnonces.prixDecroissant,
                              child: Text('Prix décroissant'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _sort = value);
                              unawaited(_reload());
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading && _items.isEmpty
                  ? const EtatChargement(rows: 4, showHeader: false)
                  : _loadError != null && _items.isEmpty
                  ? EtatErreur(message: _loadError!, onRetry: _reload)
                  : _items.isEmpty
                  ? const EtatVide(
                      icone: Icons.search_off,
                      titre: 'Aucune annonce ne correspond',
                      aide: 'Essayez un autre filtre.',
                    )
                  : GridView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.sm,
                      AppSpacing.lg,
                      100,
                    ),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: AppSpacing.md,
                          mainAxisSpacing: AppSpacing.md,
                          childAspectRatio: 0.59,
                        ),
                    itemCount: _items.length + (_loadingMore || _loadError != null ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= _items.length) {
                        if (_loadError != null) {
                          return Center(
                            child: TextButton.icon(
                              onPressed: _loadNextPage,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Réessayer'),
                            ),
                          );
                        }
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }
                      final announcement = _items[index];
                      return AnnonceCard(
                        key: ValueKey(announcement.id),
                        annonce: announcement,
                        onTap: () async {
                          await context.push(
                            '/market/annonce/${announcement.id}',
                          );
                          if (mounted) await _reload();
                        },
                      );
                    },
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MarketFilters {
  const _MarketFilters({
    required this.states,
    required this.priceRange,
    required this.city,
  });

  final Set<EtatProduit> states;
  final RangeValues priceRange;
  final String city;
}
