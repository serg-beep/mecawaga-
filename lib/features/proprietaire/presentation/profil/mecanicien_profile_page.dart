import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/opening_hours.dart';
import '../../domain/mecanicien.dart';
import '../owner_widgets.dart';

class MecanicienProfilePage extends StatelessWidget {
  const MecanicienProfilePage({required this.mecanicien, super.key});
  final Mecanicien mecanicien;

  bool get _isOpen {
    return isOpenNow(mecanicien.horaires, DateTime.now());
  }

  String _hoursText(int day) {
    final hours = mecanicien.horaires[day];
    if (hours == null) return 'Fermé';
    return '${hours.ouverture} – ${hours.fermeture}';
  }

  Future<void> _openRoute() async {
    final uri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': '${mecanicien.latitude},${mecanicien.longitude}',
      'travelmode': 'driving',
    });
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('Impossible d’ouvrir l’application de cartes.');
    }
  }

  Future<void> _call() async {
    final uri = Uri(scheme: 'tel', path: mecanicien.telephone);
    if (!await launchUrl(uri)) {
      throw Exception('Impossible de lancer l’appel.');
    }
  }

  @override
  Widget build(BuildContext context) => OwnerPage(
    title: 'Profil du mécanicien',
    child: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          mecanicien.nomAtelier,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(
              Icons.circle,
              size: 12,
              color: _isOpen ? AppColors.bleu : AppColors.texteDoux,
            ),
            const SizedBox(width: 8),
            Text(
              _isOpen ? 'Ouvert maintenant' : 'Fermé',
              style: TextStyle(
                color: _isOpen ? AppColors.bleu : AppColors.texteDoux,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 190,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.card),
            child: FlutterMap(
              options: MapOptions(
                initialCenter: LatLng(
                  mecanicien.positionRenseignee ? mecanicien.latitude : 48.8566,
                  mecanicien.positionRenseignee ? mecanicien.longitude : 2.3522,
                ),
                initialZoom: 14,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.mecawaga.app',
                ),
                if (mecanicien.positionRenseignee)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: LatLng(
                          mecanicien.latitude,
                          mecanicien.longitude,
                        ),
                        width: 48,
                        height: 48,
                        child: Semantics(
                          label: 'Position de ${mecanicien.nomAtelier}',
                          child: const Icon(
                            Icons.location_on,
                            color: AppColors.orange,
                            size: 42,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        OwnerCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on_outlined, color: AppColors.bleu),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  mecanicien.precisionsAdresse,
                  style: const TextStyle(height: 1.5),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text('Spécialités', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: mecanicien.specialites
              .map((type) => Chip(label: Text(type.label)))
              .toList(),
        ),
        const SizedBox(height: 16),
        Text('Horaires', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        OwnerCard(
          child: Column(
            children: [
              for (var day = 1; day <= 7; day++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: Row(
                    children: [
                      Expanded(child: Text(_dayName(day))),
                      Text(
                        _hoursText(day),
                        style: const TextStyle(color: AppColors.texteDoux),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        FilledButton.icon(
          onPressed: () => _runAction(context, _openRoute),
          icon: const Icon(Icons.directions),
          label: const Text('Itinéraire'),
          style: FilledButton.styleFrom(minimumSize: const Size(48, 52)),
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          onPressed: () => _runAction(context, _call),
          icon: const Icon(Icons.call_outlined),
          label: const Text('Appeler'),
          style: OutlinedButton.styleFrom(minimumSize: const Size(48, 52)),
        ),
      ],
    ),
  );

  String _dayName(int day) => switch (day) {
    1 => 'Lundi',
    2 => 'Mardi',
    3 => 'Mercredi',
    4 => 'Jeudi',
    5 => 'Vendredi',
    6 => 'Samedi',
    _ => 'Dimanche',
  };

  Future<void> _runAction(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Cette action n’a pas pu être lancée. Vérifiez que l’application nécessaire est disponible.',
            ),
          ),
        );
      }
    }
  }
}
