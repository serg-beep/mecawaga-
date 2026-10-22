import 'dart:io';
import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

typedef PhotoUploadProgress = void Function(double progress);

abstract interface class PhotoStorageService {
  Future<String> uploadPhoto({
    required File file,
    required String destinationPath,
    PhotoUploadProgress? onProgress,
    Map<String, String>? customMetadata,
  });

  Future<void> deletePhoto(String urlOrPath);
}

final photoStorageServiceProvider = Provider<PhotoStorageService>((ref) {
  if (Firebase.apps.isEmpty) return const LocalPhotoStorageService();
  return FirebasePhotoStorageService();
});

class FirebasePhotoStorageService implements PhotoStorageService {
  FirebasePhotoStorageService({FirebaseStorage? storage})
    : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;

  @override
  Future<String> uploadPhoto({
    required File file,
    required String destinationPath,
    PhotoUploadProgress? onProgress,
    Map<String, String>? customMetadata,
  }) async {
    if (!await file.exists()) {
      throw const PhotoStorageException(
        'Le fichier photo est introuvable. Choisissez-le de nouveau.',
      );
    }
    final tempFile = File(
      '${Directory.systemTemp.path}${Platform.pathSeparator}'
      'mecawaga-${DateTime.now().microsecondsSinceEpoch}.jpg',
    );
    Reference? destination;
    try {
      final compressed = await FlutterImageCompress.compressAndGetFile(
        file.path,
        tempFile.path,
        minWidth: 1600,
        minHeight: 1600,
        quality: 80,
        format: CompressFormat.jpeg,
      );
      if (compressed == null) {
        throw const PhotoStorageException(
          'La photo n’a pas pu être compressée. Choisissez une autre image.',
        );
      }
      final compressedFile = File(compressed.path);
      final size = await compressedFile.length();
      if (size >= 5 * 1024 * 1024) {
        throw const PhotoStorageException(
          'La photo compressée dépasse la taille maximale autorisée.',
        );
      }
      destination = _storage.ref().child(destinationPath);
      final task = destination.putFile(
        compressedFile,
        SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: customMetadata,
        ),
      );
      final progressSubscription = task.snapshotEvents.listen(
        (snapshot) {
          final total = snapshot.totalBytes;
          if (total > 0) {
            onProgress?.call(snapshot.bytesTransferred / total);
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          debugPrint('Événement de progression Storage interrompu : $error');
        },
      );
      try {
        await task;
      } finally {
        await progressSubscription.cancel();
      }
      return await destination.getDownloadURL();
    } on PhotoStorageException {
      rethrow;
    } on FirebaseException catch (error) {
      debugPrint(
        'FirebaseException plugin=${error.plugin} code=${error.code} '
        'message=${error.message}',
      );
      if (destination != null) {
        try {
          await destination.delete();
        } on FirebaseException catch (cleanupError) {
          debugPrint(
            'Échec du nettoyage Storage (${cleanupError.code}) après '
            'échec de téléversement (${error.code}).',
          );
        }
      }
      throw PhotoStorageException(_messageForStorageError(error));
    } on Exception catch (error, stack) {
      debugPrint('Erreur téléversement photo: $error\n$stack');
      if (destination != null) {
        try {
          await destination.delete();
        } on FirebaseException catch (cleanupError) {
          debugPrint(
            'Échec du nettoyage Storage après erreur locale : '
            '${cleanupError.code}.',
          );
        }
      }
      throw const PhotoStorageException(
        'La photo n’a pas pu être envoyée. Vérifiez votre connexion et réessayez.',
      );
    } finally {
      if (await tempFile.exists()) await tempFile.delete();
    }
  }

  @override
  Future<void> deletePhoto(String urlOrPath) async {
    final ref = urlOrPath.startsWith('https://')
        ? _storage.refFromURL(urlOrPath)
        : _storage.ref().child(urlOrPath);
    try {
      await ref.delete();
    } on FirebaseException catch (error) {
      if (error.code != 'object-not-found') rethrow;
    }
  }

  String _messageForStorageError(
    FirebaseException error,
  ) => switch (error.code) {
    'unauthorized' ||
    'permission-denied' => 'Vous n’êtes pas autorisé à envoyer cette photo.',
    'canceled' => 'L’envoi de la photo a été annulé.',
    'quota-exceeded' => 'Le stockage est momentanément indisponible.',
    'retry-limit-exceeded' || 'unknown' || 'unavailable' =>
      'La photo n’a pas pu être envoyée. Vérifiez votre connexion et réessayez.',
    _ => 'La photo n’a pas pu être envoyée. Réessayez.',
  };
}

class LocalPhotoStorageService implements PhotoStorageService {
  const LocalPhotoStorageService();

  @override
  Future<String> uploadPhoto({
    required File file,
    required String destinationPath,
    PhotoUploadProgress? onProgress,
    Map<String, String>? customMetadata,
  }) async => file.path;

  @override
  Future<void> deletePhoto(String urlOrPath) async {}
}

class PhotoStorageException implements Exception {
  const PhotoStorageException(this.message);

  final String message;

  @override
  String toString() => message;
}
