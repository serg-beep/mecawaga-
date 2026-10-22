import 'dart:io';
import 'dart:math' show max;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../../core/permissions/permission_service.dart';
import '../../../../core/firebase/photo_storage_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/etat_chargement.dart';
import '../../../../core/validators/app_validators.dart';
import '../../../../core/widgets/remote_or_local_image.dart';
import '../../../proprietaire/data/proprietaire_providers.dart';
import '../../../proprietaire/domain/intervention.dart';
import '../../../proprietaire/presentation/historique/historique_page.dart';
import '../../../proprietaire/presentation/owner_widgets.dart';
import '../../data/mecanicien_providers.dart';

class InterventionFormPage extends ConsumerStatefulWidget {
  const InterventionFormPage({required this.motoId, super.key});

  final String motoId;

  @override
  ConsumerState<InterventionFormPage> createState() =>
      _InterventionFormPageState();
}

class _InterventionFormPageState extends ConsumerState<InterventionFormPage> {
  static const _suggestions = [
    'Filtre à huile',
    'Bougie',
    'Plaquettes',
    'Chaîne',
    'Pneu',
  ];

  final _formKey = GlobalKey<FormState>();
  final _kilometrageController = TextEditingController();
  final _remarqueController = TextEditingController();
  final _picker = ImagePicker();
  final List<String> _pieces = [];
  final List<String> _photos = [];
  DateTime _date = DateUtils.dateOnly(DateTime.now());
  TypeIntervention? _type;
  bool _saving = false;
  double? _uploadProgress;

  @override
  void dispose() {
    _kilometrageController.dispose();
    _remarqueController.dispose();
    super.dispose();
  }

  int? get _kilometrage => int.tryParse(_kilometrageController.text.trim());

  Future<void> _selectDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateUtils.dateOnly(DateTime.now()),
      helpText: 'Choisir la date de l’intervention',
      cancelText: 'Annuler',
      confirmText: 'Choisir',
      locale: const Locale('fr', 'FR'),
    );
    if (selected != null) setState(() => _date = selected);
  }

  Future<void> _addPiece() async {
    final controller = TextEditingController();
    String? error;
    final piece = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Ajouter une pièce'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final suggestion in _suggestions)
                    ActionChip(
                      label: Text(suggestion),
                      onPressed: () => Navigator.pop(context, suggestion),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                maxLength: 60,
                decoration: InputDecoration(
                  labelText: 'Autre pièce',
                  errorText: error,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () {
                final value = controller.text.trim();
                if (value.isEmpty) {
                  setDialogState(
                    () => error = 'Saisissez le nom de la pièce à ajouter.',
                  );
                } else {
                  Navigator.pop(context, value);
                }
              },
              child: const Text('Ajouter'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (piece != null && !_pieces.contains(piece) && mounted) {
      setState(() => _pieces.add(piece));
    }
  }

  Future<void> _addPhoto() async {
    if (_photos.length >= 5) return;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                minTileHeight: 56,
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Prendre une photo'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                minTileHeight: 56,
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choisir dans la galerie'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );
    if (source == null || !mounted) return;
    final permission = source == ImageSource.camera
        ? MecaPermission.camera
        : MecaPermission.gallery;
    if (!await PermissionService.instance.request(context, permission) ||
        !mounted) {
      return;
    }
    try {
      final file = await _picker.pickImage(
        source: source,
        imageQuality: 82,
        maxWidth: 1800,
      );
      if (file != null && mounted) setState(() => _photos.add(file.path));
    } on Exception catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Impossible d’ajouter la photo : $error')),
        );
      }
    }
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate() || _type == null) return;
    final history = ref.read(mecanicienHistoriqueProvider(widget.motoId));
    final client = history.valueOrNull?.client;
    if (client == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'La moto ou son accès n’est plus disponible. Revenez à la liste des clients.',
          ),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    final profile = ref.read(mecanicienProfilProvider);
    final interventionId =
        'intervention-${DateTime.now().microsecondsSinceEpoch}';
    final uploadedPhotos = <String>[];
    final storage = ref.read(photoStorageServiceProvider);
    final intervention = Intervention(
      id: interventionId,
      motoId: widget.motoId,
      date: _date,
      kilometrage: _kilometrage!,
      type: _type!,
      pieces: List.unmodifiable(_pieces),
      remarque: _remarqueController.text.trim(),
      photos: const [],
      mecanicienId: profile.id,
      mecanicienNom: profile.nomAtelier,
    );
    try {
      final photoUrls = <String>[];
      for (var index = 0; index < _photos.length; index++) {
        final photo = _photos[index];
        if (photo.startsWith('https://') || photo.startsWith('http://')) {
          photoUrls.add(photo);
          continue;
        }
        final url = await storage.uploadPhoto(
          file: File(photo),
          destinationPath:
              'motos/${widget.motoId}/interventions/$interventionId/$index.jpg',
          onProgress: (progress) {
            if (mounted) {
              setState(
                () => _uploadProgress = (index + progress) / _photos.length,
              );
            }
          },
        );
        uploadedPhotos.add(url);
        photoUrls.add(url);
      }
      await ref
          .read(mecanicienRepositoryProvider)
          .addIntervention(
            Intervention(
              id: intervention.id,
              motoId: intervention.motoId,
              date: intervention.date,
              kilometrage: intervention.kilometrage,
              type: intervention.type,
              pieces: intervention.pieces,
              remarque: intervention.remarque,
              photos: List.unmodifiable(photoUrls),
              mecanicienId: intervention.mecanicienId,
              mecanicienNom: intervention.mecanicienNom,
            ),
            profile,
          );
      if (!mounted) return;
      ref.invalidate(mecanicienHistoriqueProvider(widget.motoId));
      ref.invalidate(mecanicienClientsProvider(profile.id));
      ref.invalidate(interventionsProvider(widget.motoId));
      ref.invalidate(motosProvider);
      context.pop(true);
    } on Exception catch (error) {
      for (final url in uploadedPhotos) {
        try {
          await storage.deletePhoto(url);
        } on Exception catch (cleanupError) {
          debugPrint('Nettoyage de la photo Storage impossible : $cleanupError');
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is PhotoStorageException
                  ? error.message
                  : 'Impossible d’enregistrer l’intervention : $error',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _uploadProgress = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(mecanicienHistoriqueProvider(widget.motoId));
    return OwnerPage(
      title: 'Nouvelle intervention',
      child: history.when(
        loading: () => const EtatChargement(rows: 3),
        error: (error, stack) => StateMessage(
          icon: Icons.cloud_off_outlined,
          title: 'Impossible de charger la moto',
          message: 'Vérifiez votre connexion puis réessayez.',
          action: FilledButton(
            onPressed: () =>
                ref.invalidate(mecanicienHistoriqueProvider(widget.motoId)),
            child: const Text('Réessayer'),
          ),
        ),
        data: (value) {
          if (value == null) {
            return const StateMessage(
              icon: Icons.lock_outline,
              title: 'Accès retiré',
              message:
                  'Le propriétaire a retiré votre accès à cette moto. Vous ne pouvez plus ajouter d’intervention.',
            );
          }
          final latestKnownKm = max(
            value.client.moto.kilometrage,
            value.interventions.fold<int>(
              0,
              (highest, item) => max(highest, item.kilometrage),
            ),
          );
          if (_kilometrageController.text.isEmpty) {
            _kilometrageController.text = latestKnownKm.toString();
          }
          return Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
              children: [
                OwnerCard(
                  child: Row(
                    children: [
                      const Icon(
                        Icons.two_wheeler_outlined,
                        size: 34,
                        color: AppColors.bleu,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              value.client.moto.nom,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            Text(
                              value.client.moto.immatriculation,
                              style: const TextStyle(
                                color: AppColors.texteDoux,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.lock_outline,
                        color: AppColors.texteDoux,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text('Date', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _selectDate,
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: Text(DateFormat('d MMMM yyyy', 'fr_FR').format(_date)),
                  style: OutlinedButton.styleFrom(
                    alignment: Alignment.centerLeft,
                    minimumSize: const Size(48, 52),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _kilometrageController,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Kilométrage actuel',
                    suffixText: 'km',
                    prefixIcon: Icon(Icons.speed_outlined),
                  ),
                  validator: validateKilometrage,
                ),
                if (_kilometrage != null && _kilometrage! < latestKnownKm)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.orangePale,
                        borderRadius: BorderRadius.circular(AppRadii.field),
                      ),
                      child: Text(
                        'Ce kilométrage est inférieur au dernier relevé connu ($latestKnownKm km). Vérifiez la saisie avant de continuer.',
                        style: const TextStyle(
                          color: AppColors.texte,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Type d’intervention',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                RadioGroup<TypeIntervention>(
                  groupValue: _type,
                  onChanged: (value) => setState(() => _type = value),
                  child: Column(
                    children: [
                      for (final type in TypeIntervention.values)
                        RadioListTile<TypeIntervention>(
                          contentPadding: EdgeInsets.zero,
                          title: Text(type.label),
                          value: type,
                        ),
                    ],
                  ),
                ),
                if (_type == null)
                  const Padding(
                    padding: EdgeInsets.only(left: 12),
                    child: Text(
                      'Choisissez le type d’intervention.',
                      style: TextStyle(color: AppColors.erreur),
                    ),
                  ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Pièces changées',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _addPiece,
                      icon: const Icon(Icons.add),
                      label: const Text('Ajouter une pièce'),
                    ),
                  ],
                ),
                if (_pieces.isEmpty)
                  const Text(
                    'Aucune pièce ajoutée.',
                    style: TextStyle(color: AppColors.texteDoux),
                  )
                else
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final piece in _pieces)
                        InputChip(
                          label: Text(piece),
                          onDeleted: () =>
                              setState(() => _pieces.remove(piece)),
                        ),
                    ],
                  ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _remarqueController,
                  maxLength: 500,
                  maxLines: 4,
                  minLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Remarque',
                    hintText: 'Précisions sur les travaux réalisés',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Photos des pièces ou des factures',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    Text('${_photos.length}/5'),
                  ],
                ),
                const SizedBox(height: 8),
                if (_photos.isNotEmpty)
                  SizedBox(
                    height: 92,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _photos.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(width: 8),
                      itemBuilder: (context, index) => Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(AppRadii.field),
                            child: RemoteOrLocalImage(
                              source: _photos[index],
                              width: 92,
                              height: 92,
                              fit: BoxFit.cover,
                              cacheWidth: 184,
                              cacheHeight: 184,
                            ),
                          ),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: IconButton.filledTonal(
                              tooltip: 'Supprimer la photo',
                              onPressed: () =>
                                  setState(() => _photos.removeAt(index)),
                              icon: const Icon(Icons.close),
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _photos.length < 5 ? _addPhoto : null,
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: Text(
                    _photos.length < 5
                        ? 'Ajouter une photo'
                        : 'Limite de 5 photos atteinte',
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 50),
                  ),
                ),
                if (_uploadProgress case final progress?) ...[
                  const SizedBox(height: AppSpacing.sm),
                  LinearProgressIndicator(value: progress),
                ],
                const SizedBox(height: AppSpacing.xxl),
                SizedBox(
                  height: 56,
                  child: FilledButton(
                    onPressed: _kilometrage != null && _type != null && !_saving
                        ? _save
                        : null,
                    child: _saving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Enregistrer l’intervention'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
