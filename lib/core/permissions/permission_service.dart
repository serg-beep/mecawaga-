import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

enum MecaPermission { location, camera, gallery, notifications }

class PermissionService {
  PermissionService._();

  static final PermissionService instance = PermissionService._();

  Future<bool> request(BuildContext context, MecaPermission permission) async {
    // Android's system photo picker grants access to the selected image
    // without requiring the app to request broad photo-library permission.
    if (permission == MecaPermission.gallery &&
        defaultTargetPlatform == TargetPlatform.android) {
      return true;
    }

    final explanation = _explanation(permission);
    final continueRequest = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(explanation.$1),
        content: Text(explanation.$2),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Pas maintenant'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Continuer'),
          ),
        ],
      ),
    );
    if (continueRequest != true || !context.mounted) return false;

    var status = await _systemPermission(permission).status;
    if (!status.isGranted && !status.isLimited) {
      status = await _systemPermission(permission).request();
    }
    if (!context.mounted) return false;
    if (status.isGranted || status.isLimited) return true;

    if (status.isPermanentlyDenied || status.isRestricted) {
      return _offerSettings(context, permission);
    }
    return false;
  }

  Future<bool> _offerSettings(
    BuildContext context,
    MecaPermission permission,
  ) async {
    final openSettings = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Permission désactivée'),
        content: Text(
          'La permission ${_permissionName(permission)} est désactivée dans les réglages. Vous pouvez continuer à utiliser les autres fonctionnalités de MecaWaga.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Plus tard'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Ouvrir les réglages'),
          ),
        ],
      ),
    );
    if (openSettings != true || !context.mounted) return false;
    await openAppSettings();
    return false;
  }

  Permission _systemPermission(MecaPermission permission) =>
      switch (permission) {
        MecaPermission.location => Permission.locationWhenInUse,
        MecaPermission.camera => Permission.camera,
        MecaPermission.gallery => Permission.photos,
        MecaPermission.notifications => Permission.notification,
      };

  (String, String) _explanation(
    MecaPermission permission,
  ) => switch (permission) {
    MecaPermission.location => (
      'Utiliser votre position',
      'Votre position sert à calculer les distances et à centrer la carte des mécaniciens. La liste reste disponible sans cette permission.',
    ),
    MecaPermission.camera => (
      'Accéder à l’appareil photo',
      'La caméra sert uniquement à joindre une photo de la moto, des pièces ou d’une facture.',
    ),
    MecaPermission.gallery => (
      'Accéder aux photos',
      'La photothèque sert à sélectionner une image à joindre à la moto ou à une intervention.',
    ),
    MecaPermission.notifications => (
      'Activer les notifications',
      'Les notifications locales vous préviennent à la date prévue d’un rappel d’entretien.',
    ),
  };

  String _permissionName(MecaPermission permission) => switch (permission) {
    MecaPermission.location => 'localisation',
    MecaPermission.camera => 'caméra',
    MecaPermission.gallery => 'photothèque',
    MecaPermission.notifications => 'notifications',
  };
}
