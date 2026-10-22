import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/auth_providers.dart';

final firestoreOfflineProvider = StreamProvider<bool>((ref) {
  if (Firebase.apps.isEmpty) return Stream.value(false);
  final user = ref.watch(currentUserProvider).valueOrNull;
  final uid = user?.id ?? FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value(false);
  return FirebaseFirestore.instance
      .collection('utilisateurs')
      .doc(uid)
      .snapshots(includeMetadataChanges: true)
      .map((snapshot) => snapshot.metadata.isFromCache);
});
