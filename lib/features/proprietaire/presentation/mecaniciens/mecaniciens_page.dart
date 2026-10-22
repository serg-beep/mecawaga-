import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/permissions/permission_service.dart';
import '../../../../core/widgets/etat_chargement.dart';
import '../../../../core/widgets/list_item_entrance.dart';
import '../../data/proprietaire_providers.dart';
import '../../domain/mecanicien.dart';
import '../../domain/moto.dart';
import '../owner_widgets.dart';

class MecaniciensPage extends ConsumerStatefulWidget {
  const MecaniciensPage({super.key});

  @override
  ConsumerState<MecaniciensPage> createState() => _MecaniciensPageState();
}

class _MecaniciensPageState extends ConsumerState<MecaniciensPage> {
  TypeMoto? _filter;
  bool _mapMode = false;
  bool _loading = true;
  bool _permissionDenied = false;
  double _radiusKm = 10;
  String? _error;
  Position? _position;
  List<Mecanicien> _mechanics = [];

  @override
  void initState() {
    super.initState();
    _loadMechanics();
  }

  Future<void> _loadMechanics() async {
    try {
      final repository = ref.read(proprietaireRepositoryProvider);
      _mechanics = _position == null
          ? await repository.getMechanics()
          : await repository.searchMechanics(
              latitude: _position!.latitude,
              longitude: _position!.longitude,
              radiusKm: _radiusKm,
              speciality: _filter,
            );
      final type = ref.read(selectedMotoObjectProvider)?.type;
      if (mounted) {
        setState(() {
          _filter ??= type;
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error =
              'La liste des mécaniciens ne peut pas être chargée. Réessayez.';
          _loading = false;
        });
      }
    }
  }

  Future<void> _requestPosition() async {
    final granted = await PermissionService.instance.request(
      context,
      MecaPermission.location,
    );
    if (!mounted) return;
    if (!granted) {
      setState(() {
        _permissionDenied = true;
        _position = null;
      });
      return;
    }
    try {
      final position = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _position = position;
        _permissionDenied = false;
      });
      await _loadMechanics();
    } catch (error) {
      if (mounted) {
        setState(
          () => _error =
              'La position est momentanément indisponible. La liste reste consultable sans distances.',
        );
      }
    }
  }

  List<Mecanicien> get _filtered {
    final result = _filter == null
        ? _mechanics
        : _mechanics
              .where((mechanic) => mechanic.specialites.contains(_filter))
              .toList();
    if (_position == null) return result;
    result.sort((a, b) => _distance(a).compareTo(_distance(b)));
    return result;
  }

  double _distance(Mecanicien mechanic) => Geolocator.distanceBetween(
    _position!.latitude,
    _position!.longitude,
    mechanic.latitude,
    mechanic.longitude,
  );

  Future<void> _changeFilter(TypeMoto? type) async {
    setState(() => _filter = type);
    if (_position != null) await _loadMechanics();
  }

  Future<void> _changeRadius(double? radius) async {
    if (radius == null) return;
    setState(() => _radiusKm = radius);
    if (_position != null) await _loadMechanics();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const EtatChargement(rows: 4);
    if (_error != null && _mechanics.isEmpty) {
      return StateMessage(
        icon: Icons.cloud_off_outlined,
        title: 'Recherche indisponible',
        message: _error!,
        action: FilledButton(
          onPressed: _loadMechanics,
          child: const Text('Réessayer'),
        ),
      );
    }
    final mechanics = _filtered;
    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              FilterChip(
                label: const Text('Tous'),
                selected: _filter == null,
                onSelected: (_) => _changeFilter(null),
              ),
              const SizedBox(width: 8),
              for (final type in TypeMoto.values) ...[
                FilterChip(
                  label: Text(type.label),
                  selected: _filter == type,
                  onSelected: (_) => _changeFilter(type),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              if (_position != null)
                SizedBox(
                  width: 112,
                  child: DropdownButtonFormField<double>(
                    initialValue: _radiusKm,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Rayon',
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(value: 5, child: Text('5 km')),
                      DropdownMenuItem(value: 10, child: Text('10 km')),
                      DropdownMenuItem(value: 25, child: Text('25 km')),
                    ],
                    onChanged: _changeRadius,
                  ),
                ),
              Expanded(
                child: Text(
                  _permissionDenied
                      ? 'Liste sans distances : autorisez la position pour les calculer.'
                      : _position == null
                      ? 'Les ateliers proches sont triés après autorisation de position.'
                      : 'Triés par distance',
                  style: const TextStyle(color: AppColors.texteDoux),
                ),
              ),
              IconButton(
                tooltip: 'Autoriser la position',
                onPressed: _requestPosition,
                icon: const Icon(Icons.my_location),
              ),
              IconButton(
                tooltip: _mapMode ? 'Afficher la liste' : 'Afficher la carte',
                onPressed: () => setState(() => _mapMode = !_mapMode),
                icon: Icon(_mapMode ? Icons.list : Icons.map_outlined),
              ),
            ],
          ),
        ),
        Expanded(
          child: Column(
            children: [
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(color: AppColors.erreur),
                        ),
                      ),
                      TextButton(
                        onPressed: _requestPosition,
                        child: const Text('Réessayer'),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: mechanics.isEmpty
                    ? const StateMessage(
                        icon: Icons.search_off,
                        title: 'Aucun atelier trouvé',
                        message:
                            'Essayez un autre type de moto ou choisissez « Tous».',
                      )
                    : _mapMode
                    ? _mechanicMap(mechanics)
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                        itemCount: mechanics.length,
                        itemBuilder: (context, index) {
                          final mechanic = mechanics[index];
                          return ListItemEntrance(
                            key: ValueKey('atelier-${mechanic.id}'),
                            child: _MechanicListTile(
                              mechanic: mechanic,
                              distance: _position == null
                                  ? null
                                  : _distance(mechanic),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _mechanicMap(List<Mecanicien> mechanics) {
    final center = _position == null
        ? LatLng(48.8566, 2.3522)
        : LatLng(_position!.latitude, _position!.longitude);
    return FlutterMap(
      options: MapOptions(initialCenter: center, initialZoom: 12),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.mecawaga.app',
        ),
        MarkerLayer(
          markers: [
            if (_position != null)
              Marker(
                point: center,
                width: 48,
                height: 48,
                child: Semantics(
                  label: 'Votre position',
                  child: Icon(
                    Icons.my_location,
                    color: AppColors.bleu,
                    size: 34,
                  ),
                ),
              ),
            for (final mechanic in mechanics)
              Marker(
                point: LatLng(mechanic.latitude, mechanic.longitude),
                width: 52,
                height: 52,
                child: Semantics(
                  button: true,
                  label: 'Afficher l’atelier ${mechanic.nomAtelier}',
                  child: GestureDetector(
                    onTap: () => context.push(
                      '/owner/mechanic/${mechanic.id}',
                      extra: mechanic,
                    ),
                    child: const Icon(
                      Icons.location_on,
                      color: AppColors.orange,
                      size: 42,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const RichAttributionWidget(
          attributions: [TextSourceAttribution('© OpenStreetMap contributors')],
        ),
      ],
    );
  }
}

class _MechanicListTile extends StatelessWidget {
  const _MechanicListTile({required this.mechanic, required this.distance});
  final Mecanicien mechanic;
  final double? distance;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: OwnerCard(
      onTap: () =>
          context.push('/owner/mechanic/${mechanic.id}', extra: mechanic),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: AppColors.bleuPale,
            child: Icon(Icons.build_outlined, color: AppColors.bleu),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mechanic.nomAtelier,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  mechanic.precisionsAdresse,
                  style: const TextStyle(color: AppColors.texteDoux),
                ),
                Text(
                  mechanic.specialites.map((type) => type.label).join(' · '),
                  style: const TextStyle(color: AppColors.bleu),
                ),
              ],
            ),
          ),
          if (distance != null)
            Text(
              '${(distance! / 1000).toStringAsFixed(1)} km',
              style: const TextStyle(color: AppColors.texteDoux),
            ),
        ],
      ),
    ),
  );
}
