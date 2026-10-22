import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/permissions/permission_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/validators/market_validators.dart';
import '../../../../core/widgets/app_primary_button.dart';
import '../../../../core/widgets/etat_messages.dart';
import '../../../../core/widgets/remote_or_local_image.dart';
import '../../../auth/data/auth_providers.dart';
import '../../../auth/domain/utilisateur.dart';
import '../../data/annonce_repository.dart';
import '../../data/marche_providers.dart';
import '../../domain/annonce.dart';
import '../../marche_constants.dart';

class AnnonceFormPage extends ConsumerStatefulWidget {
  const AnnonceFormPage({this.annonce, super.key});
  final Annonce? annonce;

  @override
  ConsumerState<AnnonceFormPage> createState() => _AnnonceFormPageState();
}

class _AnnonceFormPageState extends ConsumerState<AnnonceFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _price = TextEditingController();
  final _description = TextEditingController();
  final _location = TextEditingController();
  final _phone = TextEditingController();
  final _specificFields = <String, TextEditingController>{};
  final _photoPicker = ImagePicker();
  final List<String> _photos = [];
  Categorie _category = Categorie.motosOccasion;
  EtatProduit _condition = EtatProduit.bonEtat;
  bool _negotiable = false;
  bool _whatsapp = false;
  bool _loading = false;
  int _uploadedPhotoCount = 0;
  int _uploadPhotoTotal = 0;
  double _uploadProgress = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    final announcement = widget.annonce;
    final user = ref.read(authServiceProvider).utilisateurConnecte;
    _title.text = announcement?.titre ?? '';
    _price.text = announcement == null
        ? ''
        : _formattedPrice(announcement.prix);
    _description.text = announcement?.description ?? '';
    _location.text = announcement?.localisation ?? '';
    _phone.text = announcement?.telephone ?? _profilePhone(user);
    _photos.addAll(announcement?.photos ?? const []);
    _category = announcement?.categorie ?? Categorie.motosOccasion;
    _condition = announcement?.etat ?? EtatProduit.bonEtat;
    _negotiable = announcement?.negociable ?? false;
    _whatsapp = announcement?.telephoneWhatsApp ?? false;
    _syncSpecificControllers(_category, announcement?.champsSpecifiques ?? {});
  }

  String _profilePhone(Utilisateur? user) =>
      user == null || user.telephone.isEmpty ? '+226' : user.telephone;

  String _formattedPrice(int price) {
    final digits = price.toString();
    final output = StringBuffer();
    for (var index = 0; index < digits.length; index++) {
      if (index > 0 && (digits.length - index) % 3 == 0) output.write(' ');
      output.write(digits[index]);
    }
    return output.toString();
  }

  void _syncSpecificControllers(
    Categorie category,
    Map<String, String> values,
  ) {
    final required = champsParCategorie[category] ?? const [];
    for (final entry in _specificFields.entries) {
      if (!required.contains(entry.key)) entry.value.dispose();
    }
    _specificFields.removeWhere((key, _) => !required.contains(key));
    for (final label in required) {
      _specificFields.putIfAbsent(
        label,
        () => TextEditingController(text: values[label] ?? ''),
      );
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _price.dispose();
    _description.dispose();
    _location.dispose();
    _phone.dispose();
    for (final controller in _specificFields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  bool get _isValid {
    if (_loading ||
        _photos.isEmpty ||
        _photos.length > 5 ||
        validateMarketTitle(_title.text) != null ||
        validateMarketPrice(_price.text) != null ||
        validateMarketDescription(_description.text) != null ||
        validateMarketLocation(_location.text) != null ||
        validateBurkinaPhone(_phone.text) != null) {
      return false;
    }
    return _specificFields.values.every(
      (field) => field.text.trim().isNotEmpty,
    );
  }

  void _changed() {
    if (mounted) setState(() => _error = null);
  }

  Future<void> _selectPhotos() async {
    if (_photos.length >= 5) {
      afficherConfirmation(
        context,
        'Vous pouvez ajouter au maximum cinq photos.',
      );
      return;
    }
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Prendre une photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choisir dans la galerie'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
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
      final image = await _photoPicker.pickImage(
        source: source,
        imageQuality: 100,
      );
      if (image == null || !mounted) return;
      setState(() {
        _photos.add(image.path);
        _error = null;
      });
    } on PlatformException {
      if (mounted) {
        setState(() {
          _error =
              'La photo n’a pas pu être ouverte. Vérifiez l’autorisation de la caméra ou de la photothèque.';
        });
      }
    } on Exception {
      if (mounted) {
        setState(() {
          _error =
              'La photo n’a pas pu être ajoutée. Réessayez avec une autre image.';
        });
      }
    }
  }

  Future<void> _useCurrentLocation() async {
    if (!mounted) return;
    if (!await PermissionService.instance.request(
          context,
          MecaPermission.location,
        ) ||
        !mounted) {
      return;
    }
    try {
      final locationEnabled = await Geolocator.isLocationServiceEnabled();
      if (!mounted) return;
      if (!locationEnabled) {
        afficherConfirmation(
          context,
          'Activez la localisation de votre appareil puis réessayez.',
          erreur: true,
        );
        return;
      }
      final position = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      _location.text =
          '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
      setState(() {});
    } on Exception {
      if (mounted) {
        afficherConfirmation(
          context,
          'Votre position n’a pas pu être récupérée. Saisissez la ville ou le quartier.',
          erreur: true,
        );
      }
    }
  }

  Future<void> _save() async {
    if (_loading || !_formKey.currentState!.validate()) {
      setState(() {});
      return;
    }
    final user = ref.read(authServiceProvider).utilisateurConnecte;
    if (user == null) {
      setState(() => _error = 'Reconnectez-vous avant de publier une annonce.');
      return;
    }
    if (widget.annonce case final existing?
        when existing.vendeurId != user.id) {
      setState(() => _error = 'Seul le vendeur peut modifier cette annonce.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final old = widget.annonce;
    final price = int.parse(_price.text.replaceAll(RegExp(r'\D'), ''));
    final announcement = Annonce(
      id: old?.id ?? 'annonce-${DateTime.now().microsecondsSinceEpoch}',
      vendeurId: user.id,
      vendeurNom: user.role == RoleUtilisateur.mecanicien
          ? user.nomAtelier ?? user.nomComplet
          : user.nomComplet,
      vendeurEstMecanicien: user.role == RoleUtilisateur.mecanicien,
      titre: _title.text.trim(),
      categorie: _category,
      etat: _condition,
      prix: price,
      negociable: _negotiable,
      description: _description.text.trim(),
      photos: List.unmodifiable(_photos),
      localisation: _location.text.trim(),
      telephone: normalizeBurkinaPhone(_phone.text),
      telephoneWhatsApp: _whatsapp,
      champsSpecifiques: {
        for (final field in _specificFields.entries)
          field.key: field.value.text.trim(),
      },
      statut: old?.statut ?? StatutAnnonce.active,
      datePublication: old?.datePublication ?? DateTime.now(),
    );
    try {
      await ref
          .read(annonceRepositoryProvider)
          .saveAnnouncement(
            announcement,
            onUploadProgress: (completed, total, progress) {
              if (!mounted) return;
              setState(() {
                _uploadedPhotoCount = completed;
                _uploadPhotoTotal = total;
                _uploadProgress = progress;
              });
            },
          );
      ref
        ..invalidate(annoncesActivesProvider)
        ..invalidate(mesAnnoncesProvider(user.id))
        ..invalidate(annonceProvider(announcement.id));
      if (!mounted) return;
      afficherConfirmation(
        context,
        old == null
            ? 'Votre annonce a été publiée.'
            : 'Votre annonce a été modifiée.',
      );
      context.go('/market/mine');
    } on MarketRepositoryException catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = error.message;
        });
      }
    } on Exception {
      if (mounted) {
        setState(() {
          _loading = false;
          _error =
              'L’annonce n’a pas pu être enregistrée. Vérifiez votre connexion puis réessayez ; vos saisies sont conservées.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.annonce == null ? 'Publier une annonce' : 'Modifier l’annonce',
      ),
    ),
    body: Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.xl,
        ),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Photos',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Text('${_photos.length}/5'),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (_photos.isNotEmpty)
            SizedBox(
              height: 120,
              child: ReorderableListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _photos.length,
                onReorderItem: (oldIndex, newIndex) {
                  setState(() {
                    final photo = _photos.removeAt(oldIndex);
                    _photos.insert(newIndex, photo);
                  });
                },
                itemBuilder: (context, index) => Padding(
                  key: ValueKey('photo-${_photos[index]}-$index'),
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadii.field),
                        child: SizedBox(
                          width: 112,
                          height: 112,
                          child: _photoWidget(_photos[index]),
                        ),
                      ),
                      if (index == 0)
                        Positioned(
                          left: AppSpacing.xs,
                          bottom: AppSpacing.xs,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: AppSpacing.xs,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(
                                AppRadii.pill,
                              ),
                            ),
                            child: const Text(
                              'Couverture',
                              style: TextStyle(
                                color: AppColors.texte,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: IconButton.filledTonal(
                          tooltip: 'Supprimer la photo ${index + 1}',
                          onPressed: () =>
                              setState(() => _photos.removeAt(index)),
                          icon: const Icon(Icons.close),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          OutlinedButton.icon(
            onPressed: _photos.length >= 5 ? null : _selectPhotos,
            icon: const Icon(Icons.add_a_photo_outlined),
            label: const Text('Ajouter une photo'),
          ),
          if (_photos.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                'Ajoutez au moins une photo pour publier votre annonce.',
                style: TextStyle(color: AppColors.erreur),
              ),
            ),
          const SizedBox(height: AppSpacing.lg),
          TextFormField(
            controller: _title,
            maxLength: 80,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Titre',
              hintText: 'Ex. Yamaha 125 en très bon état',
            ),
            validator: validateMarketTitle,
            onChanged: (_) => _changed(),
          ),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<Categorie>(
            initialValue: _category,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Catégorie'),
            items: [
              for (final category in Categorie.values)
                DropdownMenuItem(
                  value: category,
                  child: Text(category.label, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                _category = value;
                _syncSpecificControllers(
                  value,
                  widget.annonce?.categorie == value
                      ? widget.annonce!.champsSpecifiques
                      : {},
                );
              });
            },
          ),
          for (final field in _specificFields.entries) ...[
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: field.value,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              keyboardType:
                  field.key == 'Année' ||
                      field.key == 'Kilométrage' ||
                      field.key == 'Cylindrée'
                  ? TextInputType.number
                  : TextInputType.text,
              decoration: InputDecoration(labelText: field.key),
              validator: (value) => (value?.trim().isEmpty ?? true)
                  ? 'Renseignez ${field.key.toLowerCase()}.'
                  : null,
              onChanged: (_) => _changed(),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Text(
            'État du produit',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              for (final state in EtatProduit.values)
                ChoiceChip(
                  label: Text(state.label),
                  selected: _condition == state,
                  onSelected: (_) => setState(() => _condition = state),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _price,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Prix',
              suffixText: 'FCFA',
              prefixIcon: Icon(Icons.payments_outlined),
            ),
            validator: validateMarketPrice,
            onChanged: (value) {
              final formatted = _formatPriceLive(value);
              if (formatted != value) {
                _price.value = TextEditingValue(
                  text: formatted,
                  selection: TextSelection.collapsed(offset: formatted.length),
                );
              }
              _changed();
            },
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _negotiable,
            title: const Text('Prix négociable'),
            onChanged: (value) => setState(() => _negotiable = value ?? false),
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _description,
            maxLength: 1000,
            minLines: 4,
            maxLines: 7,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Description',
              alignLabelWithHint: true,
            ),
            validator: validateMarketDescription,
            onChanged: (_) => _changed(),
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _location,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Ville ou quartier',
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
            validator: validateMarketLocation,
            onChanged: (_) => _changed(),
          ),
          OutlinedButton.icon(
            onPressed: _useCurrentLocation,
            icon: const Icon(Icons.my_location),
            label: const Text('Utiliser ma position'),
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'Téléphone',
              prefixIcon: Icon(Icons.phone_outlined),
              helperText: 'Indicatif du Burkina Faso : +226',
            ),
            validator: validateBurkinaPhone,
            onChanged: (_) => _changed(),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _whatsapp,
            title: const Text('Ce numéro est aussi sur WhatsApp'),
            onChanged: (value) => setState(() => _whatsapp = value ?? false),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              _error!,
              style: const TextStyle(color: AppColors.erreur, height: 1.4),
            ),
          ],
          if (_loading && _uploadPhotoTotal > 0) ...[
            Text(
              'Envoi des photos : $_uploadedPhotoCount sur $_uploadPhotoTotal',
              style: const TextStyle(color: AppColors.texte),
            ),
            const SizedBox(height: AppSpacing.xs),
            LinearProgressIndicator(value: _uploadProgress),
            const SizedBox(height: AppSpacing.md),
          ],
          const SizedBox(height: AppSpacing.lg),
          AppPrimaryButton(
            label: widget.annonce == null
                ? 'Publier l’annonce'
                : 'Enregistrer les modifications',
            onPressed: _isValid ? _save : null,
            isLoading: _loading,
          ),
        ],
      ),
    ),
  );

  String _formatPriceLive(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return '';
    final output = StringBuffer();
    for (var index = 0; index < digits.length; index++) {
      if (index > 0 && (digits.length - index) % 3 == 0) output.write(' ');
      output.write(digits[index]);
    }
    return output.toString();
  }

  Widget _photoWidget(String path) {
    if (path.startsWith('assets/')) {
      return Image.asset(
        path == photoRemplacementMarche ? path : photoRemplacementMarche,
        fit: BoxFit.cover,
        cacheWidth: 224,
        cacheHeight: 224,
      );
    }
    return RemoteOrLocalImage(
      source: path,
      fit: BoxFit.cover,
      cacheWidth: 224,
      cacheHeight: 224,
    );
  }
}
