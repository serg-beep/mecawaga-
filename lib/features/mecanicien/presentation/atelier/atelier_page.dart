import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/permissions/permission_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/etat_chargement.dart';
import '../../../../core/validators/app_validators.dart';
import '../../../proprietaire/domain/mecanicien.dart';
import '../../../proprietaire/domain/moto.dart';
import '../../../proprietaire/presentation/owner_widgets.dart';
import '../../data/mecanicien_providers.dart';

class AtelierPage extends ConsumerStatefulWidget {
  const AtelierPage({super.key});

  @override
  ConsumerState<AtelierPage> createState() => _AtelierPageState();
}

class _AtelierPageState extends ConsumerState<AtelierPage> {
  static const _defaultCenter = LatLng(48.8566, 2.3522);
  static const _days = [
    'Lundi',
    'Mardi',
    'Mercredi',
    'Jeudi',
    'Vendredi',
    'Samedi',
    'Dimanche',
  ];

  final _formKey = GlobalKey<FormState>();
  final _workshopController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _mapController = MapController();
  final Set<TypeMoto> _specialities = {};
  final Map<int, CreneauJour> _hours = {};
  LatLng _center = _defaultCenter;
  bool _positionSelected = false;
  bool _loading = true;
  bool _saving = false;
  String? _loadError;
  String? _locationError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadProfile());
  }

  @override
  void dispose() {
    _workshopController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final id = ref.read(mecanicienIdProvider);
    try {
      final saved = await ref
          .read(mecanicienRepositoryProvider)
          .getWorkshopProfile(id);
      if (!mounted) return;
      final Mecanicien profile;
      if (saved != null) {
        profile = saved;
      } else {
        profile = ref.read(mecanicienProfilProvider);
      }
      ref.read(mecanicienProfilOverrideProvider(id).notifier).state = profile;
      _workshopController.text = profile.nomAtelier;
      _phoneController.text = profile.telephone;
      _addressController.text = profile.precisionsAdresse;
      _specialities
        ..clear()
        ..addAll(profile.specialites);
      _hours
        ..clear()
        ..addAll(profile.horaires);
      if (profile.positionRenseignee) {
        _center = LatLng(profile.latitude, profile.longitude);
        _positionSelected = true;
      }
      setState(() => _loading = false);
    } on Exception catch (error) {
      if (mounted) {
        setState(() {
          _loadError = 'Impossible de charger votre atelier : $error';
          _loading = false;
        });
      }
    }
  }

  bool get _phoneValid => validatePhone(_phoneController.text) == null;

  bool get _formValid =>
      _workshopController.text.trim().length >= 2 &&
      _phoneValid &&
      _specialities.isNotEmpty &&
      _positionSelected &&
      _addressController.text.trim().isNotEmpty &&
      _hours.isNotEmpty &&
      _hours.values.every(_isValidSlot);

  int get _completedSections {
    final contactComplete =
        _workshopController.text.trim().length >= 2 && _phoneValid;
    final specialtiesComplete = _specialities.isNotEmpty;
    final locationComplete =
        _positionSelected && _addressController.text.trim().isNotEmpty;
    final hoursComplete = _hours.isNotEmpty;
    return [
      contactComplete,
      specialtiesComplete,
      locationComplete,
      hoursComplete,
    ].where((complete) => complete).length;
  }

  Future<void> _selectTime(int day, {required bool opening}) async {
    final slot =
        _hours[day] ??
        const CreneauJour(ouverture: '09:00', fermeture: '18:00');
    final initial = _parseTime(opening ? slot.ouverture : slot.fermeture);
    final selected = await showTimePicker(
      context: context,
      initialTime: initial,
      helpText: opening ? 'Heure d’ouverture' : 'Heure de fermeture',
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (selected == null) return;
    setState(() {
      _hours[day] = CreneauJour(
        ouverture: opening ? _formatTime(selected) : slot.ouverture,
        fermeture: opening ? slot.fermeture : _formatTime(selected),
      );
    });
  }

  TimeOfDay _parseTime(String value) {
    final parts = value.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  String _formatTime(TimeOfDay value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

  bool _isValidSlot(CreneauJour slot) {
    final opening = _parseTime(slot.ouverture);
    final closing = _parseTime(slot.fermeture);
    return closing.hour * 60 + closing.minute >
        opening.hour * 60 + opening.minute;
  }

  void _copyMondayToWeekdays() {
    final monday = _hours[1];
    setState(() {
      for (var day = 2; day <= 5; day++) {
        if (monday == null) {
          _hours.remove(day);
        } else {
          _hours[day] = monday;
        }
      }
    });
  }

  Future<void> _useCurrentLocation() async {
    if (!await PermissionService.instance.request(
          context,
          MecaPermission.location,
        ) ||
        !mounted) {
      setState(() {
        _locationError =
            'La position n’est pas autorisée. Vous pouvez toujours choisir le point en déplaçant la carte.';
      });
      return;
    }

    setState(() {
      _locationError = null;
      _loading = true;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw const _LocationProblem(
          'Activez la localisation de votre téléphone, ou déplacez la carte pour choisir votre adresse.',
        );
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (!mounted) return;
      final center = LatLng(position.latitude, position.longitude);
      setState(() {
        _center = center;
        _positionSelected = true;
      });
      _mapController.move(center, 16);
    } on _LocationProblem catch (error) {
      if (mounted) setState(() => _locationError = error.message);
    } on Exception catch (error) {
      if (mounted) {
        setState(() {
          _locationError =
              'Impossible de récupérer la position : $error. Déplacez la carte pour choisir le point.';
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || !_formValid || _saving) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    final id = ref.read(mecanicienIdProvider);
    final profile = ref
        .read(mecanicienProfilProvider)
        .copyWith(
          nomAtelier: _workshopController.text.trim(),
          telephone: _phoneController.text.trim(),
          specialites: _specialities.toList(),
          latitude: _center.latitude,
          longitude: _center.longitude,
          precisionsAdresse: _addressController.text.trim(),
          horaires: Map<int, CreneauJour>.unmodifiable(_hours),
          positionRenseignee: _positionSelected,
        );
    try {
      await ref.read(mecanicienRepositoryProvider).saveWorkshopProfile(profile);
      if (!mounted) return;
      ref.read(mecanicienProfilOverrideProvider(id).notifier).state = profile;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Les informations de votre atelier ont été enregistrées.',
          ),
        ),
      );
    } on Exception catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Impossible d’enregistrer votre atelier : $error'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const EtatChargement(rows: 4);
    if (_loadError != null) {
      return StateMessage(
        icon: Icons.cloud_off_outlined,
        title: 'Atelier indisponible',
        message: _loadError!,
        action: FilledButton(
          onPressed: () {
            setState(() {
              _loading = true;
              _loadError = null;
            });
            _loadProfile();
          },
          child: const Text('Réessayer'),
        ),
      );
    }

    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
        children: [
          OwnerCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Profil de l’atelier',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  '$_completedSections sur 4 sections complétées',
                  style: const TextStyle(
                    color: AppColors.bleuFonce,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadii.small),
                  child: LinearProgressIndicator(
                    value: _completedSections / 4,
                    minHeight: 8,
                    color: AppColors.bleu,
                    backgroundColor: AppColors.fond,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  _completionMessage,
                  style: const TextStyle(color: AppColors.texteDoux),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _sectionTitle(
            context,
            'Coordonnées',
            'Nom de l’atelier et téléphone',
          ),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            controller: _workshopController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Nom de l’atelier',
              prefixIcon: Icon(Icons.storefront_outlined),
            ),
            validator: validateName,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Téléphone de l’atelier',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
            validator: validatePhone,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 20),
          _sectionTitle(
            context,
            'Types de motos réparés',
            'Choisissez au moins une spécialité.',
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final type in TypeMoto.values)
                FilterChip(
                  label: Text(type.label),
                  selected: _specialities.contains(type),
                  onSelected: (selected) => setState(() {
                    if (selected) {
                      _specialities.add(type);
                    } else {
                      _specialities.remove(type);
                    }
                  }),
                ),
            ],
          ),
          if (_specialities.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'Choisissez au moins un type de moto.',
                style: TextStyle(color: AppColors.erreur),
              ),
            ),
          const SizedBox(height: 20),
          _sectionTitle(
            context,
            'Position précise',
            'Déplacez la carte pour placer le repère au centre de votre atelier.',
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 240,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.card),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _center,
                      initialZoom: _positionSelected ? 15 : 12,
                      onPositionChanged: (camera, hasGesture) {
                        if (hasGesture) {
                          setState(() {
                            _center = camera.center;
                            _positionSelected = true;
                          });
                        }
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.mecawaga.app',
                      ),
                    ],
                  ),
                  IgnorePointer(
                    child: Semantics(
                      label: 'Repère de position choisie au centre de la carte',
                      child: Icon(
                        Icons.location_pin,
                        size: 46,
                        color: AppColors.orange,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Material(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadii.field),
                      child: IconButton(
                        tooltip: 'Utiliser ma position actuelle',
                        onPressed: _loading ? null : _useCurrentLocation,
                        icon: const Icon(
                          Icons.my_location,
                          color: AppColors.bleu,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _positionSelected
                ? 'Position choisie : ${_center.latitude.toStringAsFixed(5)}, ${_center.longitude.toStringAsFixed(5)}'
                : 'Déplacez la carte ou utilisez votre position pour choisir un emplacement.',
            style: TextStyle(
              color: _positionSelected ? AppColors.texteDoux : AppColors.erreur,
            ),
          ),
          if (_locationError != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              _locationError!,
              style: const TextStyle(color: AppColors.erreur),
            ),
            if (_locationError!.contains('réglages'))
              TextButton(
                onPressed: Geolocator.openAppSettings,
                child: const Text('Ouvrir les réglages'),
              ),
          ],
          const SizedBox(height: 12),
          TextFormField(
            controller: _addressController,
            textCapitalization: TextCapitalization.sentences,
            maxLength: 160,
            decoration: const InputDecoration(
              labelText: 'Précisions d’adresse',
              hintText: 'À côté de la pharmacie, portail bleu',
              prefixIcon: Icon(Icons.place_outlined),
              alignLabelWithHint: true,
            ),
            validator: (value) => (value?.trim().isEmpty ?? true)
                ? 'Ajoutez un repère qui aidera les clients à trouver l’atelier.'
                : null,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 20),
          _sectionTitle(
            context,
            'Horaires',
            'Définissez les jours et les heures d’ouverture.',
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _copyMondayToWeekdays,
              icon: const Icon(Icons.copy_all_outlined),
              label: const Text('Copier du lundi vers les jours ouvrés'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
            ),
          ),
          const SizedBox(height: 8),
          for (var day = 1; day <= 7; day++) _dayRow(day),
          if (_hours.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'Indiquez au moins un jour d’ouverture.',
                style: TextStyle(color: AppColors.erreur),
              ),
            ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: 54,
            child: FilledButton(
              onPressed: _formValid && !_saving ? _save : null,
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Enregistrer mon atelier'),
            ),
          ),
        ],
      ),
    );
  }

  String get _completionMessage {
    if (_completedSections == 4) {
      return 'Votre atelier est visible dans les recherches.';
    }
    final missing = <String>[];
    if (_workshopController.text.trim().length < 2 || !_phoneValid) {
      missing.add('les coordonnées');
    }
    if (_specialities.isEmpty) missing.add('les spécialités');
    if (!_positionSelected || _addressController.text.trim().isEmpty) {
      missing.add('la position et l’adresse');
    }
    if (_hours.isEmpty) missing.add('les horaires');
    return 'Il manque ${missing.join(', ')}.';
  }

  Widget _sectionTitle(BuildContext context, String title, String subtitle) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: const TextStyle(color: AppColors.texteDoux, height: 1.4),
          ),
        ],
      );

  Widget _dayRow(int day) {
    final slot = _hours[day];
    final isOpen = slot != null;
    return Card(
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.field),
        side: const BorderSide(color: AppColors.bordure),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.xs,
          AppSpacing.md,
          AppSpacing.sm,
        ),
        child: Column(
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(_days[day - 1]),
              subtitle: Text(isOpen ? 'Ouvert' : 'Fermé'),
              value: isOpen,
              onChanged: (open) => setState(() {
                if (open) {
                  _hours[day] =
                      slot ??
                      const CreneauJour(ouverture: '09:00', fermeture: '18:00');
                } else {
                  _hours.remove(day);
                }
              }),
            ),
            if (isOpen)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _selectTime(day, opening: true),
                      child: Text('Ouverture ${slot.ouverture}'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _selectTime(day, opening: false),
                      child: Text('Fermeture ${slot.fermeture}'),
                    ),
                  ),
                ],
              ),
            if (slot != null && !_isValidSlot(slot))
              const Padding(
                padding: EdgeInsets.only(top: AppSpacing.xs),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'L’heure de fermeture doit être après l’ouverture.',
                    style: TextStyle(color: AppColors.erreur),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LocationProblem implements Exception {
  const _LocationProblem(this.message);

  final String message;
}
