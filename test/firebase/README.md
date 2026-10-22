# Tests des Firebase Security Rules

Les tests utilisent le module `node:test` intégré à Node.js et les émulateurs
Firebase déclarés dans `firebase.json` (Auth, Firestore et Storage). Aucun
paquet npm additionnel n'est requis ; les émulateurs nécessitent Java.

Depuis la racine du projet, exécuter :

```sh
firebase emulators:exec --project demo-mecawaga --only auth,firestore,storage "node --test test/firebase/rules.test.mjs"
```

`demo-mecawaga` est un identifiant local réservé aux émulateurs, pas un projet
Firebase de production. Les tests couvrent les chemins
`codesAcces/{code}`, `acces/{motoId}_{mecanicienId}`,
`motos/{motoId}/interventions/{id}` et `motos/{motoId}/rappels/{id}`, avec les
champs `proprietaireId`, `expireLe`, `dateAutorisation` et `creeLe == request.time`.
Ils testent aussi les annonces du Marché, le compteur de signalements,
l'interdiction de signaler deux fois, le contrôle des annonces vendues, les
photos d'annonces et la suppression d'un compte. Les images
`motos/{motoId}/photo.jpg`, les ateliers, l'ownership, le refus par défaut, la
lecture Storage contrôlée, l'augmentation seule du kilométrage par mécanicien
autorisé, l'accès moto par code actif et la suppression des photos
d'intervention en cas d'échec de création Firestore sont également couverts.

Les règles ne peuvent pas vérifier qu'un client a réellement effectué une
lecture préalable. La création de `acces` valide donc à nouveau le code côté
serveur : code existant, moto et propriétaire correspondants, et expiration
future. Lire le code révèle l'identifiant de la moto ; les codes doivent être
longs, imprévisibles et non énumérables. Un `get` exact de moto est aussi
autorisé par `codeAccesActif` uniquement si le code existe, est actif et pointe
vers cette moto et son propriétaire. Cette exception n'autorise pas les
requêtes `list`. Storage autorise l'upload et le nettoyage des images
d'intervention à un propriétaire ou mécanicien autorisé même si le document
Firestore n'existe pas encore. Les photos du Marché sont lisibles par tout
utilisateur connecté et écrites par leur vendeur. Pour l'envoi initial, Storage
vérifie la métadonnée `vendeurId` égale à l'UID tant que le document d'annonce
n'existe pas; ensuite la règle vérifie le vendeur dans Firestore.

La suppression de compte pose d'abord `utilisateurs/{uid}.deletionRequested`.
Cette marque irréversible permet uniquement l'effacement des interventions et
accès rattachés au compte. L'immutabilité des interventions reste appliquée
hors de cette procédure. Un signalement ne peut être supprimé par son auteur
qu'au cours de cette procédure d'effacement.

Les index du Marché couvrent les combinaisons de statut, catégorie, état,
préfixe du titre et tri. `titreRecherche` contient le titre normalisé et
`titrePrefixes` stocke ses préfixes sans accents pour préserver le tri choisi
pendant la recherche. L'index des ateliers cible le champ imbriqué
`position.geohash` produit par GeoFirePoint, avec `profilComplet` et
`specialites`.
