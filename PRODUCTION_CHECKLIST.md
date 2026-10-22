# Mise en production de MecaWaga

## Firebase et données

- [ ] Pour les essais en développement, remplacer les marqueurs de
  `lib/firebase_options_dev.dart` avec
  `flutterfire configure --project=mecawaga-dev --platforms=android,ios --out=lib/firebase_options_dev.dart`.
- [ ] Dans Firebase Console, activer le fournisseur E-mail/Mot de passe dans
  Authentication > Méthode de connexion.
- [ ] Remplacer les marqueurs de `lib/firebase_options_prod.dart` :
  `flutterfire configure --project=mecawaga-prod --platforms=android,ios --out=lib/firebase_options_prod.dart`.
- [ ] Choisir l’identifiant Android définitif et le déclarer dans Firebase.
  Dans PowerShell, le fournir à Gradle avec
  `$env:ORG_GRADLE_PROJECT_mecawagaApplicationId = '<identifiant définitif>'`.
  La valeur par défaut `com.example.mecawaga` est volontairement bloquée en
  release.
- [ ] Vérifier les applications Android/iOS, clés SHA, domaines Auth et bucket
  du projet `mecawaga-prod`.
- [ ] Déployer et vérifier les règles et index :
  `firebase deploy --project mecawaga-prod --only firestore,storage`.
- [ ] Activer App Check en mode appliqué dans Firebase Console pour Firestore
  et Storage; enregistrer Play Integrity et Device Check/App Attest.
- [ ] Configurer un budget et des alertes de facturation dans Google Cloud.
- [ ] Configurer et tester les sauvegardes Firestore planifiées et leur
  politique de rétention.
- [ ] Si des annonces existent avant cette version, remplir leurs champs
  `titreRecherche` et `titrePrefixes` avant d’activer la recherche par préfixe.
- [ ] Personnaliser en français les e-mails de réinitialisation du mot de passe
  dans Firebase Authentication.
- [ ] Faire valider le texte provisoire de la politique de confidentialité et
  des conditions par le responsable de l’application et un professionnel du
  droit avant de les publier.
- [ ] Vérifier la suppression de compte sur les deux rôles et dans Storage.

## Signalements du Marché

`nbSignalements` est incrémenté dans la même transaction que chaque
signalement valide. Les signalements sont uniques par annonce et auteur.
L’application ne masque pas automatiquement les annonces et n’utilise pas de
Cloud Function.

Pour masquer une annonce manuellement :

1. Dans Firebase Console, ouvrir Firestore Database puis la collection
   `annonces`.
2. Ouvrir le document concerné et vérifier `nbSignalements` et le contenu de
   l’annonce.
3. Modifier `statut` en `masquee` (valeur chaîne, sans accent).
4. Vérifier que l’annonce n’apparaît plus dans le Marché. Le vendeur peut
   toujours la consulter dans « Mes annonces ».

Les documents `signalements` ne sont pas lisibles depuis l’application. Leur
consultation et toute décision de modération doivent être faites par une
personne autorisée dans la console.

## Android

- [ ] Générer une clé d’envoi Play distincte de toute clé de développement et
  conserver une copie chiffrée hors du dépôt.
- [ ] Générer le keystore, par exemple avec
  `keytool -genkeypair -v -keystore android\app\upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload`.
- [ ] Copier `android/key.properties.example` vers `android/key.properties`,
  puis remplacer les valeurs d’exemple. Ne jamais versionner le fichier ni le
  keystore.
- [ ] Générer et vérifier l’icône de lancement configurée dans `pubspec.yaml` :
  `dart run flutter_launcher_icons`.
- [ ] Vérifier le nom « MecaWaga », l’identifiant d’application et la version.
- [ ] Compiler le bundle de production après configuration du Firebase prod :
  `flutter build appbundle --release --dart-define=MECAWAGA_ENV=prod`.
- [ ] Tester l’AAB signé sur une piste interne Google Play avant la publication.

## Parcours de recette sur deux téléphones

- [ ] Inscription propriétaire.
- [ ] Inscription mécanicien et profil d’atelier.
- [ ] Propriétaire : ajout d’une moto et génération d’un code d’accès.
- [ ] Mécanicien : saisie du code, consultation de la moto et confirmation.
- [ ] Mécanicien : ajout d’une intervention avec photo.
- [ ] Propriétaire : vérifier l’apparition de l’intervention dans l’Historique.
- [ ] Propriétaire : retirer l’accès du mécanicien et vérifier sa disparition
  côté mécanicien.
- [ ] Publication propriétaire d’une annonce avec photo, catégorie, prix et
  coordonnées.
- [ ] Publication mécanicien d’une annonce.
- [ ] Depuis le second compte, ouvrir une annonce et vérifier l’appel et
  WhatsApp sur l’appareil.
- [ ] Vérifier la modification, la vente, la remise en vente et la suppression
  avec nettoyage des photos.
- [ ] Signaler une annonce et vérifier `nbSignalements` dans Firebase Console.
- [ ] Vérifier les parcours hors connexion, reprise réseau et erreurs de
  permission.

La recette réelle sur deux appareils, l’activation App Check, les sauvegardes,
la facturation et le déploiement prod restent à cocher par l’équipe disposant
des comptes et appareils de production.
