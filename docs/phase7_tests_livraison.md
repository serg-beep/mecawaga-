# Phase 7 - Tests et livraison

Etat au 12 octobre 2026 : Phase 7 en cours, socle technique avance. Les tests
unitaires, widgets et regles Firebase sont presents; la recette sur deux
telephones, App Check prod applique, distribution testeurs et publication Play
restent a executer par l'equipe qui possede les comptes et appareils.

## Commandes de test

- [ ] Analyse statique : `flutter analyze`
- [ ] Tests Flutter : `flutter test --coverage`
- [ ] Regles Firebase :
  `firebase emulators:exec --project demo-mecawaga --only auth,firestore,storage "node --test test/firebase/rules.test.mjs"`
- [ ] APK test :
  `flutter build apk --release --dart-define=MECAWAGA_ENV=prod`
- [ ] Bundle Play :
  `flutter build appbundle --release --dart-define=MECAWAGA_ENV=prod`

Couverture obtenue : a renseigner apres execution locale de
`flutter test --coverage` avec `genhtml coverage/lcov.info`.

## Couverture automatisee

- [x] Validateurs de base : nom, e-mail, mot de passe, kilometrage, annonce.
- [x] Jours restants d'un rappel.
- [x] Prix FCFA et dates en francais.
- [x] Normalisation des numeros Burkina Faso en `+226`.
- [x] Generation et validation du code d'acces `MOTO-XXXXXX`.
- [x] Logique "Ouvert maintenant".
- [x] Parcours widgets principaux : connexion demo, inscription mecanicien,
  ajout moto, navigation proprietaire, mecanicien, Marché, petit ecran 320 px
  et texte 130 %.
- [x] Depot Marché fake : pagination, recherche, tri, signalements.
- [x] Regles Firebase : proprietaire, mecanicien autorise, mecanicien non
  autorise, code expire, utilisateur non connecte, Storage, annonces, photos,
  suppression de compte.
- [ ] Tests widgets dedies encore a isoler : formulaire d'intervention,
  formulaire d'annonce invalide, etats vide/chargement/erreur par composant.
- [ ] Tests d'integration Flutter `integration_test` contre Emulator Suite sur
  appareils physiques ou emulateurs Android.

## Fiche de recette cochable

| Cas | Etapes | Resultat attendu | Resultat |
| --- | --- | --- | --- |
| Inscription proprietaire | Installer l'APK, creer un compte proprietaire, valider e-mail/mot de passe. | Accueil proprietaire affiche Mes motos, Historique, Rappels, Marché, Profil. | [ ] |
| Inscription mecanicien | Creer un compte mecanicien, completer nom d'atelier, specialites, horaires. | L'espace mecanicien s'ouvre et l'atelier peut etre trouve apres profil complet. | [ ] |
| Connexion | Se deconnecter puis se reconnecter avec e-mail ou telephone. | Connexion reussie et role conserve. | [ ] |
| Mot de passe oublie | Depuis connexion, demander une reinitialisation. | Message de confirmation affiche; e-mail Firebase recu. | [ ] |
| Ajout moto | Ajouter marque, modele, annee, immatriculation, kilometrage. | Moto visible dans la liste et l'Historique. | [ ] |
| Modification moto | Modifier un champ et le kilometrage. | Donnees mises a jour sans perte des anciennes interventions. | [ ] |
| Code d'acces | Generer un code depuis une moto. | Code `MOTO-XXXXXX` affiche, expiration visible. | [ ] |
| Saisie code mecanicien | Saisir le code sur le second telephone mecanicien. | Moto proposee puis ajoutee aux clients du mecanicien. | [ ] |
| Mauvais code | Saisir un code invalide ou inconnu. | Message d'erreur clair, aucun acces cree. | [ ] |
| Code expire | Saisir un code expire. | Acces refuse, demande de nouveau code. | [ ] |
| Retrait acces | Proprietaire retire le mecanicien autorise. | Moto disparait de la liste client mecanicien. | [ ] |
| Intervention avec photos | Mecanicien ajoute kilometrage, type, pieces, photos. | Intervention creee et photos visibles. | [ ] |
| Temps reel proprietaire | Garder l'Historique ouvert cote proprietaire pendant l'ajout. | Nouvelle intervention apparait sans relance de l'app. | [ ] |
| Immutabilite intervention | Tenter de modifier/supprimer l'intervention. | Action impossible hors suppression de compte. | [ ] |
| Rappel date | Creer un rappel date, fermer l'application. | Notification recue a l'heure prevue. | [ ] |
| Recherche mecanicien avec position | Autoriser la position, filtrer par type moto. | Resultats pertinents, distance/itineraire disponibles. | [ ] |
| Recherche sans position | Refuser la position. | Recherche utilisable, message de permission non bloquant. | [ ] |
| Itineraire et appel | Ouvrir un atelier puis tester itineraire et appel. | Apps cartes et telephone s'ouvrent. | [ ] |
| Publication Marché | Publier annonce avec photos, prix, categorie, telephone. | Annonce active visible dans le Marché. | [ ] |
| Recherche/filtres Marché | Chercher par titre, categorie, etat, tri prix. | Resultats filtres sans doublons. | [ ] |
| Contact annonce | Tester appel et WhatsApp. | Actions ouvrent telephone/WhatsApp avec le bon numero. | [ ] |
| Marquer vendue | Vendeur marque l'annonce comme vendue. | Elle disparait du Marché public et reste dans Mes annonces. | [ ] |
| Signalement | Autre compte signale l'annonce. | Signalement unique enregistre, compteur Firestore incremente. | [ ] |
| Suppression compte | Supprimer le compte apres mot de passe. | Donnees, annonces, acces et photos rattaches sont effaces. | [ ] |

## Conditions difficiles

- [ ] Mode avion pendant une saisie : champs conserves, bandeau "Hors
  connexion", synchronisation au retour reseau.
- [ ] Connexion lente : photos avec progression, annulation possible, aucune
  annonce incomplete.
- [ ] Telephone 2 Go RAM : listes fluides; mesurer temps de demarrage et memoire
  avec Flutter DevTools.
- [ ] Rotation, texte systeme 130 %, mode sombre systeme, largeur 320 px,
  tablette.
- [ ] Permissions refusees puis accordees depuis reglages.

## Securite et confidentialite

- [x] Regles Firestore et Storage relues : refus par defaut present, ownership
  explicite, interventions immuables, annonces vendues non publiques, photos
  controlees par role.
- [x] Suppression de compte encadree par `deletionRequested` et testee dans les
  regles.
- [ ] Confirmer dans Firebase Console que App Check est applique sur
  `mecawaga-prod` pour Firestore et Storage.
- [ ] Executer un scan final secrets avant release :
  `rg -n "(AIza|PRIVATE KEY|client_secret|storePassword=|keyPassword=|BEGIN RSA|BEGIN PRIVATE)" . -g "!build/**" -g "!.dart_tool/**"`
- [ ] Verifier sur compte reel que les photos Storage sont effacees apres
  suppression du compte.

Faiblesses restantes a surveiller :

- Les tests de regles valident la suppression de compte, mais l'effacement
  complet depend encore du parcours client car il n'y a pas de Cloud Functions.
- Les signalements sont moderes manuellement; pas de masquage automatique cote
  serveur.
- App Check prod ne peut etre confirme que dans la console Firebase.

## Suivi apres lancement

- [x] Firebase Crashlytics ajoute et branche sur erreurs Flutter et erreurs
  fatales plateforme.
- [x] Firebase Performance ajoute avec trace `app_startup`.
- [x] Les erreurs importantes doivent rester sans donnees personnelles; ne pas
  journaliser nom, telephone, e-mail, position precise, photos ou contenu libre.
- [x] Ecran "A propos" ajoute avec version, contact et lien confidentialite.

## Livraison Android

- [x] Nom Android : `MecaWaga`.
- [x] Icone adaptative configuree avec `assets/images/logo.png`.
- [x] Signature release bloquee si `android/key.properties` ou keystore absents.
- [x] Identifiant `com.example.mecawaga` bloque en release.
- [ ] Choisir l'identifiant definitif et le declarer dans Firebase prod.
- [ ] Creer le keystore :
  `keytool -genkeypair -v -keystore android\app\upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload`
- [ ] Sauvegarder le keystore chiffre hors Git et hors machine unique.
- [ ] Copier `android/key.properties.example` vers `android/key.properties`,
  renseigner les secrets, ne jamais versionner ce fichier.
- [ ] Regenerer les icones : `dart run flutter_launcher_icons`.
- [ ] Activer R8/shrink release, verifier taille APK/AAB et assets images.
- [ ] Generer APK test, installer sur deux telephones reels.
- [ ] Generer AAB et tester en piste interne Google Play.
- [ ] Distribuer aux testeurs via Firebase App Distribution.

Exigences Google Play verifiees le 12 octobre 2026 : pour un compte personnel
cree apres le 13 novembre 2023, Google Play demande une closed test avec au
moins 12 testeurs opt-in pendant 14 jours continus avant demande d'acces
production. Sources officielles : Play Console Help
`https://support.google.com/googleplay/android-developer/answer/14151465`,
configuration tests
`https://support.google.com/googleplay/android-developer/answer/9845334`,
Firebase App Distribution
`https://firebase.google.com/docs/app-distribution`.

## Fiche Google Play

Description courte :

> Suivi d'entretien moto, rappels, ateliers et annonces au Burkina Faso.

Description longue :

> MecaWaga aide les proprietaires de motos a suivre leurs interventions,
> rappels et kilometrages, et permet aux mecaniciens autorises d'ajouter des
> interventions avec photos. L'application propose aussi un Marché d'annonces
> pour vendre ou rechercher motos, pieces, accessoires et services, avec contact
> direct par appel ou WhatsApp.

- [ ] Captures : accueil proprietaire, fiche moto, Historique, recherche
  mecanicien, annonce Marché, publication annonce.
- [ ] Categorie : Auto et vehicules, ou Outils selon positionnement Play final.
- [ ] Donnees collectees a declarer : nom, e-mail, telephone, position, photos,
  contenu d'annonces, donnees moto/interventions.
- [ ] Politique de confidentialite publique et validee juridiquement.
- [ ] Comptes de test reviewers Google Play fournis si connexion obligatoire.

## Tableau des defauts

| Ecran/module | Gravite | Defaut | Correction ou report |
| --- | --- | --- | --- |
| Code d'acces | Important | Validateur historique attendait `MOTO-1234` alors que les depots generent `MOTO-XXXXXX`. | Corrige dans `validateCodeAcces`, test ajoute. |
| Observabilite | Important | Crashlytics/Performance etaient declares mais non initialises. | Corrige dans `main.dart`. |
| Profil | Important | Absence d'ecran "A propos" avec version/contact. | Corrige avec route `/about`. |
| Recette appareils | Important | Parcours deux telephones non executes dans cet environnement. | A executer avant go. |
| App Check prod | Important | Mode applique non verifiable sans acces Firebase Console. | A confirmer avant go. |
| Integration Flutter | Mineur | Pas encore de suite `integration_test` Flutter dediee. | Reporter si la recette manuelle est validee; a ajouter en version suivante. |
| Moderation Marché | Mineur | Signalements sans workflow admin applicatif. | Moderation manuelle documentee, outil admin a prevoir. |

## Go ou no go

- [ ] Tous les tests automatises passent.
- [ ] Recette sur deux telephones reels terminee.
- [ ] Aucun defaut bloquant ou important ouvert.
- [ ] App Check prod applique.
- [ ] Firebase prod configure, regles et index deployes.
- [ ] Keystore sauvegarde hors Git.
- [ ] APK test installe et valide.
- [ ] AAB signe teste en piste interne.
- [ ] Firebase App Distribution realisee.
- [ ] Closed test Google Play terminee si compte personnel soumis a l'exigence.
- [ ] Politique de confidentialite validee et URL publique.

Decision :

- [ ] GO publication
- [ ] NO GO - motif :
