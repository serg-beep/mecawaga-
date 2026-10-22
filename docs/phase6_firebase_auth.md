# Phase 6 - Firebase et authentification

## Paquets ajoutes

- `firebase_core`
- `firebase_auth`
- `cloud_firestore`
- `firebase_storage`
- `firebase_app_check`

## Configuration FlutterFire

Deux fichiers d'options sont prevus :

- `lib/firebase_options_dev.dart` pour `mecawaga-dev`
- `lib/firebase_options_prod.dart` pour `mecawaga-prod`

Commandes a executer apres connexion au CLI Firebase :

```bash
flutterfire configure --project=mecawaga-dev --platforms=android,ios --out=lib/firebase_options_dev.dart
flutterfire configure --project=mecawaga-prod --platforms=android,ios --out=lib/firebase_options_prod.dart
```

L'environnement se choisit au lancement :

```bash
flutter run --dart-define=MECAWAGA_ENV=dev
flutter run --dart-define=MECAWAGA_ENV=prod
```

Sans `--dart-define`, l'application utilise `dev`.

## Etapes console Firebase

Pour `mecawaga-dev` et `mecawaga-prod` :

1. Activer Authentication > Sign-in method > Email/Password.
2. Creer Firestore Database.
3. Creer Cloud Storage.
4. Android : ajouter l'empreinte SHA-1 de la cle de debug et de la cle de release.
5. Activer App Check :
   - Android : Play Integrity.
   - iOS : DeviceCheck.
   - En developpement, enregistrer les jetons debug affiches par Firebase App Check.
6. Relancer `flutterfire configure` apres modification des applications Android/iOS.

## Donnees creees a l'inscription

`utilisateurs/{uid}` :

- `nom`
- `telephone`
- `email`
- `role` : `proprietaire` ou `mecanicien`
- `dateCreation`

`ateliers/{uid}` pour un mecanicien :

- `nomAtelier`
- `specialites`
- `profilComplet: false`
- `dateCreation`

Les documents sont ecrits avec un `WriteBatch`. Si l'ecriture Firestore echoue
apres creation du compte Auth, le compte Auth est supprime.

## Verification manuelle

1. Inscription proprietaire :
   - Lancer en dev : `flutter run --dart-define=MECAWAGA_ENV=dev`.
   - Creer un compte proprietaire avec e-mail et mot de passe.
   - Verifier la redirection vers l'accueil proprietaire.
   - Verifier `Authentication > Users`.
   - Verifier `Firestore > utilisateurs/{uid}` avec `role = proprietaire`.

2. Inscription mecanicien :
   - Creer un compte mecanicien avec nom d'atelier et specialites.
   - Verifier la redirection vers l'accueil mecanicien.
   - Verifier `utilisateurs/{uid}` avec `role = mecanicien`.
   - Verifier `ateliers/{uid}` avec `profilComplet = false`.

3. Connexion :
   - Se deconnecter.
   - Se reconnecter avec l'e-mail et le mot de passe.
   - Verifier la redirection vers l'accueil correspondant au role.

4. Deconnexion :
   - Utiliser le bouton de deconnexion.
   - Verifier le retour a l'ecran de connexion.
   - Fermer puis rouvrir l'app : l'utilisateur reste deconnecte.

5. Mot de passe oublie :
   - Ouvrir "Mot de passe oublie ?".
   - Saisir un e-mail existant.
   - Verifier l'ecran de confirmation.
   - Verifier la reception de l'e-mail de reinitialisation.

6. Mode avion :
   - Activer le mode avion.
   - Tenter une connexion.
   - Verifier le message : "Pas de connexion reseau. Verifiez votre connexion puis reessayez."
   - Desactiver le mode avion et verifier que la connexion fonctionne.

## Tests manuels passes

Non executes dans cet environnement : ils necessitent les deux projets Firebase
configures, les fichiers `firebase_options_*` generes par FlutterFire et un
appareil/emulateur Android ou iOS avec App Check configure.
