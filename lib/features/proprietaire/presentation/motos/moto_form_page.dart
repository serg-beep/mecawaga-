import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/permissions/permission_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/firebase/photo_storage_service.dart';
import '../../../../core/validators/app_validators.dart';
import '../../../../core/widgets/app_primary_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/remote_or_local_image.dart';
import '../../data/proprietaire_providers.dart';
import '../../domain/moto.dart';
import '../owner_widgets.dart';

class MotoFormPage extends ConsumerStatefulWidget {
  const MotoFormPage({this.moto, super.key});
  final Moto? moto;

  @override
  ConsumerState<MotoFormPage> createState() => _MotoFormPageState();
}

class _MotoFormPageState extends ConsumerState<MotoFormPage> {
  final _key = GlobalKey<FormState>();
  late final TextEditingController _marque;
  late final TextEditingController _modele;
  late final TextEditingController _plaque;
  late final TextEditingController _annee;
  late final TextEditingController _km;
  final _picker = ImagePicker();
  TypeMoto _type = TypeMoto.moto125;
  String? _photo;
  bool _loading = false;
  String? _error;
  double? _uploadProgress;
  String? _pendingMotoId;

  bool get _isValid =>
      validateName(_marque.text) == null &&
      validateName(_modele.text) == null &&
      validateImmatriculation(_plaque.text) == null &&
      validateAnnee(_annee.text, minimum: 1950) == null &&
      validateKilometrage(_km.text, maximum: 999999) == null;

  @override
  void initState() {
    super.initState();
    final moto = widget.moto;
    _marque = TextEditingController(text: moto?.marque);
    _modele = TextEditingController(text: moto?.modele);
    _plaque = TextEditingController(text: moto?.immatriculation);
    _annee = TextEditingController(text: moto?.annee.toString());
    _km = TextEditingController(text: moto?.kilometrage.toString());
    _type = moto?.type ?? TypeMoto.moto125;
    _photo = moto?.photo;
  }

  @override
  void dispose() {
    _marque.dispose();
    _modele.dispose();
    _plaque.dispose();
    _annee.dispose();
    _km.dispose();
    super.dispose();
  }

  Future<void> _selectPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choisir dans la galerie'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Prendre une photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (source == null) return;
    if (source == ImageSource.camera) {
      if (!await PermissionService.instance.request(
            context,
            MecaPermission.camera,
          ) ||
          !mounted) {
        return;
      }
    }
    try {
      final image = await _picker.pickImage(source: source, imageQuality: 85);
      if (image != null && mounted) setState(() => _photo = image.path);
    } on Exception catch (error) {
      debugPrint('Erreur image_picker: $error');
      if (mounted) {
        setState(() => _error = 'Impossible d’ajouter la photo : $error');
      }
    }
  }

  Future<void> _save() async {
    if (_loading || !_key.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final motoId =
          widget.moto?.id ??
          (_pendingMotoId ??= DateTime.now().microsecondsSinceEpoch.toString());
      final isNew = widget.moto == null;
      final repository = ref.read(proprietaireRepositoryProvider);
      var photoUrl = widget.moto?.photo;
      final moto = Moto(
        id: motoId,
        marque: _marque.text.trim(),
        modele: _modele.text.trim(),
        type: _type,
        immatriculation: _plaque.text.trim().toUpperCase(),
        annee: int.parse(_annee.text),
        kilometrage: int.parse(_km.text),
        photo: photoUrl,
      );
      await repository.saveMoto(moto, isNew: isNew);

      if (_photo != null &&
          !_photo!.startsWith('http://') &&
          !_photo!.startsWith('https://')) {
        try {
          photoUrl = await ref.read(photoStorageServiceProvider).uploadPhoto(
              file: File(_photo!),
              destinationPath: 'motos/$motoId/photo.jpg',
              onProgress: (progress) {
                if (mounted) setState(() => _uploadProgress = progress);
              },
            );
          await repository.saveMoto(
            moto.copyWith(photo: photoUrl),
            isNew: false,
          );
        } on PhotoStorageException catch (error, stack) {
          debugPrint('PhotoStorageException: ${error.message}\n$stack');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Moto enregistrée. ${error.message}')),
            );
            context.pop();
          }
          return;
        }
      }
      ref.invalidate(motosProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.moto == null
                  ? 'Moto enregistrée.'
                  : 'Moto mise à jour.',
            ),
          ),
        );
        context.pop();
      }
    } on FirebaseException catch (error, stack) {
      debugPrint(
        'FirebaseException plugin=${error.plugin} code=${error.code} '
        'message=${error.message}\n$stack',
      );
      if (mounted) {
        setState(() {
          _uploadProgress = null;
          _error = switch (error.code) {
            'permission-denied' =>
              'Accès refusé par Firestore. Vérifiez que vous êtes connecté et que les règles autorisent l’écriture.',
            'unavailable' =>
              'Serveur injoignable. Vérifiez votre connexion.',
            'not-found' =>
              'La base Firestore n’existe pas encore. Créez-la dans la console Firebase.',
            _ => 'Erreur Firebase (${error.code}).',
          };
        });
      }
    } on TimeoutException catch (error, stack) {
      debugPrint('TimeoutException: $error\n$stack');
      if (mounted) {
        setState(() {
          _uploadProgress = null;
          _error = error.message ??
              'Enregistrement en attente. La moto sera envoyée au retour de la connexion.';
        });
      }
    } catch (error, stack) {
      debugPrint('Erreur enregistrement moto: $error\n$stack');
      if (mounted) {
        setState(() {
          _uploadProgress = null;
          _error = error is PhotoStorageException
              ? '${error.message}'
              : error is StateError
              ? '${error.message}'
              : 'La moto n’a pas pu être enregistrée. Réessayez.';
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => OwnerPage(
    title: widget.moto == null ? 'Ajouter une moto' : 'Modifier la moto',
    child: Form(
      key: _key,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          AppTextField(
            controller: _marque,
            label: 'Marque',
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            validator: validateName,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: _modele,
            label: 'Modèle',
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            validator: validateName,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<TypeMoto>(
            initialValue: _type,
            decoration: const InputDecoration(labelText: 'Type de moto'),
            items: TypeMoto.values
                .map(
                  (type) =>
                      DropdownMenuItem(value: type, child: Text(type.label)),
                )
                .toList(),
            onChanged: (value) => setState(() => _type = value ?? _type),
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: _plaque,
            label: 'Immatriculation',
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.next,
            validator: validateImmatriculation,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: _annee,
            label: 'Année',
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            validator: (value) => validateAnnee(value, minimum: 1950),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: _km,
            label: 'Kilométrage',
            hint: 'Ex. 12450',
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            validator: (value) =>
                validateKilometrage(value, minimum: 0, maximum: 999999),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _selectPhoto,
            icon: const Icon(Icons.add_a_photo_outlined),
            label: Text(
              _photo == null ? 'Ajouter une photo' : 'Changer la photo',
            ),
            style: OutlinedButton.styleFrom(minimumSize: const Size(48, 50)),
          ),
          if (_photo != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.field),
              child: RemoteOrLocalImage(
                source: _photo!,
                height: 190,
                fit: BoxFit.cover,
                cacheWidth: 760,
                cacheHeight: 380,
              ),
            ),
          ],
          if (_uploadProgress case final progress?)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: LinearProgressIndicator(value: progress),
            ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppColors.erreur)),
          ],
          const SizedBox(height: 20),
          AppPrimaryButton(
            label: 'Enregistrer',
            onPressed: _isValid ? _save : null,
            isLoading: _loading,
          ),
        ],
      ),
    ),
  );
}
