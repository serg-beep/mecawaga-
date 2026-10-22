import assert from 'node:assert/strict';
import test from 'node:test';

const projectId = process.env.GCLOUD_PROJECT ?? 'demo-mecawaga';
const firestoreHost = process.env.FIRESTORE_EMULATOR_HOST ?? '127.0.0.1:8080';
const firestoreUrl =
  `http://${firestoreHost}/v1/projects/${projectId}/databases/(default)/documents`;
const authUrl =
  `http://${process.env.FIREBASE_AUTH_EMULATOR_HOST ?? '127.0.0.1:9099'}` +
  '/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake-api-key';
const storageUrl =
  `http://${process.env.FIREBASE_STORAGE_EMULATOR_HOST ?? '127.0.0.1:9199'}`;
const bucket = `${projectId}.appspot.com`;

function encodeValue(value) {
  if (value === null) return { nullValue: null };
  if (typeof value === 'boolean') return { booleanValue: value };
  if (typeof value === 'number') {
    return Number.isInteger(value)
      ? { integerValue: String(value) }
      : { doubleValue: value };
  }
  if (value instanceof Date) return { timestampValue: value.toISOString() };
  if (Array.isArray(value)) {
    return { arrayValue: { values: value.map(encodeValue) } };
  }
  if (typeof value === 'object') {
    return { mapValue: { fields: encodeFields(value) } };
  }
  return { stringValue: value };
}

function encodeFields(data) {
  return Object.fromEntries(
    Object.entries(data).map(([key, value]) => [key, encodeValue(value)]),
  );
}

async function request(url, { token, ...options } = {}) {
  const headers = new Headers(options.headers);
  if (token) headers.set('Authorization', 'Bearer ' + token);
  if (options.body && !(options.body instanceof Uint8Array)) {
    headers.set('Content-Type', 'application/json');
    options.body = JSON.stringify(options.body);
  }
  return fetch(url, { ...options, headers });
}

function documentUrl(path) {
  return `${firestoreUrl}/${path}`;
}

async function writeDocument(path, data, token, create = false) {
  const query = new URLSearchParams();
  if (create) {
    query.set('currentDocument.exists', 'false');
  } else {
    for (const field of Object.keys(data)) {
      query.append('updateMask.fieldPaths', field);
    }
  }
  return request(
    `${documentUrl(path)}?${query}`,
    {
      method: 'PATCH',
      token,
      body: { fields: encodeFields(data) },
    },
  );
}

async function writeDocumentWithServerTimestamp(
  path,
  data,
  token,
  timestampFields,
  create = false,
) {
  const fields = { ...data };
  for (const field of timestampFields) delete fields[field];
  const name = `projects/${projectId}/databases/(default)/documents/${path}`;
  const write = {
    update: { name, fields: encodeFields(fields) },
    updateTransforms: timestampFields.map((fieldPath) => ({
      fieldPath,
      setToServerValue: 'REQUEST_TIME',
    })),
  };
  if (create) write.currentDocument = { exists: false };
  return request(`${firestoreUrl}:commit`, {
    method: 'POST',
    token,
    body: { writes: [write] },
  });
}

async function submitMarketReport({
  announcementId,
  reporter,
  reason = 'Informations fausses',
}) {
  const reportId = `${announcementId}_${reporter.uid}`;
  const reportName =
    `projects/${projectId}/databases/(default)/documents/signalements/${reportId}`;
  const userReportName =
    `projects/${projectId}/databases/(default)/documents/` +
    `utilisateurs/${reporter.uid}/signalementsMarche/${announcementId}`;
  const announcementName =
    `projects/${projectId}/databases/(default)/documents/annonces/${announcementId}`;
  return request(`${firestoreUrl}:commit`, {
    method: 'POST',
    token: reporter.token,
    body: {
      writes: [
        {
          update: {
            name: announcementName,
            fields: encodeFields({ nbSignalements: 1 }),
          },
          updateMask: { fieldPaths: ['nbSignalements'] },
        },
        {
          update: {
            name: reportName,
            fields: encodeFields({
              annonceId: announcementId,
              auteurId: reporter.uid,
              motif: reason,
            }),
          },
          updateTransforms: [
            { fieldPath: 'date', setToServerValue: 'REQUEST_TIME' },
          ],
          currentDocument: { exists: false },
        },
        {
          update: {
            name: userReportName,
            fields: encodeFields({ annonceId: announcementId }),
          },
          currentDocument: { exists: false },
        },
      ],
    },
  });
}

async function createUser(email, role) {
  const response = await request(authUrl, {
    method: 'POST',
    body: { email, password: 'MecaWaga-test-123!', returnSecureToken: true },
  });
  assert.equal(response.status, 200, await response.clone().text());
  const auth = await response.json();
  const profile = await writeDocumentWithServerTimestamp(
    `utilisateurs/${auth.localId}`,
    {
      nom: email,
      telephone: '+22670000000',
      email,
      role,
    },
    auth.idToken,
    ['dateCreation'],
    true,
  );
  assert.equal(profile.status, 200, await profile.text());
  return { uid: auth.localId, token: auth.idToken, role };
}

async function createMechanicProfileAndWorkshop(uid, token, email) {
  const createWithServerTimestamp = (path, data) => {
    const fields = { ...data };
    delete fields.dateCreation;
    return {
      update: {
        name: `projects/${projectId}/databases/(default)/documents/${path}`,
        fields: encodeFields(fields),
      },
      updateTransforms: [
        { fieldPath: 'dateCreation', setToServerValue: 'REQUEST_TIME' },
      ],
      currentDocument: { exists: false },
    };
  };

  return request(`${firestoreUrl}:commit`, {
    method: 'POST',
    token,
    body: {
      writes: [
        createWithServerTimestamp(`utilisateurs/${uid}`, {
          nom: email,
          telephone: '+22670000000',
          email,
          role: 'mecanicien',
        }),
        createWithServerTimestamp(`ateliers/${uid}`, {
          nomAtelier: 'Atelier de test',
          specialites: ['Moto 125 cc'],
          profilComplet: false,
        }),
      ],
    },
  });
}

function storageObjectUrl(path, upload = false) {
  const name = encodeURIComponent(path);
  return upload
    ? `${storageUrl}/v0/b/${bucket}/o?uploadType=media&name=${name}`
    : `${storageUrl}/v0/b/${bucket}/o/${name}?alt=media`;
}

async function uploadImage(path, token, size = 16) {
  return request(storageObjectUrl(path, true), {
    method: 'POST',
    token,
    headers: { 'Content-Type': 'image/jpeg' },
    body: new Uint8Array(size),
  });
}

test('Firestore et Storage appliquent le schéma MECawaga et ses permissions', async () => {
  const owner = await createUser('owner@example.test', 'proprietaire');
  const mechanic = await createUser('mechanic@example.test', 'mecanicien');
  const stranger = await createUser('stranger@example.test', 'mecanicien');
  const onboardingResponse = await request(authUrl, {
    method: 'POST',
    body: {
      email: 'new-mechanic@example.test',
      password: 'MecaWaga-test-123!',
      returnSecureToken: true,
    },
  });
  assert.equal(onboardingResponse.status, 200);
  const onboardingAuth = await onboardingResponse.json();
  assert.equal(
    (await createMechanicProfileAndWorkshop(
      onboardingAuth.localId,
      onboardingAuth.idToken,
      'new-mechanic@example.test',
    )).status,
    200,
    'un mécanicien peut créer son profil et son atelier dans le même lot',
  );
  const motoId = 'moto-1';
  const code = 'opaque-long-random-code-id';
  const moto = {
    proprietaireId: owner.uid,
    marque: 'Honda',
    modele: 'Wave',
    annee: 2024,
    kilometrage: 1200,
  };

  assert.equal(
    (await writeDocument(`motos/${motoId}`, moto, owner.token, true)).status,
    200,
  );
  assert.equal(
    (await request(documentUrl(`motos/${motoId}`))).status,
    403,
    'la lecture anonyme est refusée',
  );
  assert.equal(
    (await request(documentUrl(`motos/${motoId}`), { token: mechanic.token })).status,
    403,
    'la moto reste inaccessible avant création de l’accès',
  );
  assert.equal(
    (await writeDocument(`motos/${motoId}`, {
      ...moto,
      proprietaireId: stranger.uid,
    }, owner.token)).status,
    403,
    'un propriétaire ne peut pas transférer sa moto',
  );
  assert.equal(
    (await writeDocument(
      `utilisateurs/${owner.uid}`,
      { role: 'mecanicien' },
      owner.token,
    )).status,
    403,
    'le rôle utilisateur est immuable',
  );

  const future = new Date(Date.now() + 60 * 60 * 1000);
  assert.equal(
    (await writeDocument(`codesAcces/${code}`, {
      motoId,
      proprietaireId: owner.uid,
      expireLe: future,
    }, owner.token, true)).status,
    200,
  );
  assert.equal(
    (await request(documentUrl(`codesAcces/${code}`), {
      token: mechanic.token,
    })).status,
    200,
    'le mécanicien peut lire un code actif connu',
  );
  assert.equal(
    (await request(documentUrl(`codesAcces/${code}`))).status,
    403,
    'la lecture du code exige une authentification',
  );
  assert.equal(
    (await request(`${firestoreUrl}/codesAcces`, {
      token: mechanic.token,
    })).status,
    403,
    'un mécanicien ne peut pas rechercher/lister les codes',
  );
  assert.equal(
    (await writeDocument(`codesAcces/${code}-expired`, {
      motoId,
      proprietaireId: owner.uid,
      expireLe: new Date(Date.now() - 60 * 1000),
    }, owner.token, true)).status,
    403,
    'un propriétaire ne peut pas créer un code déjà expiré',
  );
  assert.equal(
    (await writeDocument(`motos/${motoId}`, {
      codeAccesActif: code,
    }, owner.token)).status,
    200,
  );
  assert.equal(
    (await request(documentUrl(`motos/${motoId}`), {
      token: mechanic.token,
    })).status,
    200,
    'un code actif pointe vers la moto exacte consultée avant de confirmer l’accès',
  );
  assert.equal(
    (await request(`${firestoreUrl}/motos`, {
      token: mechanic.token,
    })).status,
    403,
    'le code actif n’autorise pas la liste des motos',
  );

  const accessId = `${motoId}_${mechanic.uid}`;
  assert.equal(
    (await writeDocumentWithServerTimestamp(
      `acces/${accessId}`,
      {
        motoId,
        proprietaireId: owner.uid,
        mecanicienId: mechanic.uid,
        mecanicienNom: 'Atelier Test',
        nomAtelier: 'Atelier Test',
        proprietaireNom: 'Propriétaire Test',
        code,
      },
      mechanic.token,
      ['dateAutorisation'],
      true,
    )).status,
    200,
    'le code lu et non expiré permet de créer le document acces attendu',
  );
  assert.equal(
    (await request(documentUrl(`motos/${motoId}`), {
      token: mechanic.token,
    })).status,
    200,
    'l’accès root permet désormais de lire la moto',
  );
  assert.equal(
    (await writeDocument(`motos/${motoId}`, {
      kilometrage: 1300,
    }, mechanic.token)).status,
    200,
    'un mécanicien autorisé peut seulement augmenter le kilométrage',
  );
  assert.equal(
    (await writeDocument(`motos/${motoId}`, {
      kilometrage: 1250,
    }, mechanic.token)).status,
    403,
    'un mécanicien ne peut pas diminuer le kilométrage',
  );
  assert.equal(
    (await writeDocument(`motos/${motoId}`, {
      kilometrage: 1400,
      marque: 'Yamaha',
    }, mechanic.token)).status,
    403,
    'un mécanicien ne peut pas modifier la moto en même temps que son kilométrage',
  );
  assert.equal(
    (await writeDocument(`motos/${motoId}`, {
      kilometrage: 5000,
    }, stranger.token)).status,
    403,
    'un mécanicien sans accès ne peut pas modifier le kilométrage',
  );
  assert.equal(
    (await writeDocument(`acces/${motoId}_${stranger.uid}`, {
      motoId,
      proprietaireId: owner.uid,
      mecanicienId: stranger.uid,
      code,
    }, stranger.token, true)).status,
    403,
    'un code ne peut être accepté que pour le compte mécanicien connecté',
  );
  assert.equal(
    (await writeDocument(`acces/${motoId}_${mechanic.uid}`, {
      motoId,
      proprietaireId: stranger.uid,
      mecanicienId: mechanic.uid,
      code,
    }, mechanic.token)).status,
    403,
    'le champ proprietaireId doit correspondre au propriétaire du code et de la moto',
  );
  assert.equal(
    (await writeDocument(`codesAcces/${code}`, {
      expireLe: new Date(Date.now() - 60 * 1000),
    }, owner.token)).status,
    200,
  );
  assert.equal(
    (await request(documentUrl(`codesAcces/${code}`), {
      token: stranger.token,
    })).status,
    200,
    'tout mécanicien authentifié peut lire un code expiré et afficher son état',
  );
  assert.equal(
    (await writeDocumentWithServerTimestamp(
      `acces/${motoId}_${stranger.uid}`,
      {
        motoId,
        proprietaireId: owner.uid,
        mecanicienId: stranger.uid,
        code,
      },
      stranger.token,
      ['dateAutorisation'],
      true,
    )).status,
    403,
    'un code expiré ne permet pas de créer un nouvel accès',
  );

  const interventionPath = `motos/${motoId}/interventions/visit-1`;
  const intervention = {
    motoId,
    proprietaireId: owner.uid,
    mecanicienId: mechanic.uid,
    date: new Date(),
    kilometrage: 1200,
    type: 'entretien',
  };
  assert.equal(
    (await writeDocumentWithServerTimestamp(
      interventionPath,
      intervention,
      mechanic.token,
      ['creeLe'],
      true,
    )).status,
    200,
    'une intervention du mécanicien autorisé exige creeLe == request.time',
  );
  assert.equal(
    (await writeDocument(interventionPath, {
      remarque: 'Modification interdite',
    }, owner.token)).status,
    403,
    'une intervention ne peut pas être modifiée après sa création',
  );
  assert.equal(
    (await request(documentUrl(interventionPath), {
      method: 'DELETE',
      token: owner.token,
    })).status,
    403,
    'une intervention ne peut pas être supprimée après sa création',
  );
  assert.equal(
    (await writeDocument(`motos/${motoId}/interventions/wrong-time`, {
      ...intervention,
      creeLe: new Date(),
    }, mechanic.token, true)).status,
    403,
    'une intervention sans server timestamp request.time est refusée',
  );
  assert.equal(
    (await writeDocument('interventions/wrong-path', intervention, mechanic.token, true)).status,
    403,
    'les interventions ne sont pas stockées dans une collection racine',
  );
  assert.equal(
    (await writeDocument(`motos/${motoId}/interventions/outsider`, {
      motoId,
      proprietaireId: owner.uid,
      mecanicienId: stranger.uid,
      creeLe: new Date(),
    }, stranger.token, true)).status,
    403,
    'un mécanicien sans accès ne peut pas créer une intervention',
  );

  const rappel = {
    motoId,
    proprietaireId: owner.uid,
    titre: 'Vidange',
    date: future,
  };
  assert.equal(
    (await writeDocument(`motos/${motoId}/rappels/reminder-1`, rappel, mechanic.token, true)).status,
    403,
    'les rappels restent réservés au propriétaire',
  );
  assert.equal(
    (await writeDocument(`motos/${motoId}/rappels/reminder-1`, rappel, owner.token, true)).status,
    200,
  );
  assert.equal(
    (await writeDocument('rappels/wrong-path', rappel, owner.token, true)).status,
    403,
    'les rappels ne sont pas stockés dans une collection racine',
  );

  assert.equal(
    (await writeDocumentWithServerTimestamp(
      `ateliers/${mechanic.uid}`,
      {
        nomAtelier: 'Atelier test',
        specialites: ['moto125', 'scooter'],
        profilComplet: false,
        latitude: 12.3,
        longitude: -1.5,
        positionRenseignee: true,
        precisionsAdresse: 'Quartier Centre',
        geohash: '7vct',
        position: {
          geohash: '7vct',
          geopoint: { latitude: 12.3, longitude: -1.5 },
        },
      },
      mechanic.token,
      ['dateCreation'],
      true,
    )).status,
    200,
    'le profil atelier accepte les specialites et champs de position du modèle',
  );
  assert.equal(
    (await writeDocument('ateliers/fake', {
      nomAtelier: 'Faux atelier',
      specialites: [],
      profilComplet: false,
      dateCreation: new Date(),
    }, owner.token, true)).status,
    403,
    'seul un mécanicien peut créer son atelier',
  );

  const motoPhoto = `motos/${motoId}/photo.jpg`;
  assert.equal((await uploadImage(motoPhoto, owner.token)).status, 200);
  assert.equal(
    (await request(storageObjectUrl(motoPhoto), { token: stranger.token })).status,
    403,
    'la lecture des photos moto est contrôlée',
  );
  assert.equal(
    (await request(storageObjectUrl(motoPhoto), { token: mechanic.token })).status,
    200,
  );
  assert.equal(
    (await uploadImage(motoPhoto, owner.token, 5 * 1024 * 1024)).status,
    403,
    'les images de 5 Mio ou plus sont refusées',
  );
  assert.equal(
    (await uploadImage(`motos/${motoId}/photo.jpg`, stranger.token)).status,
    403,
  );
  assert.equal(
    (await request(storageObjectUrl(motoPhoto))).status,
    403,
    'les lectures Storage anonymes sont refusées',
  );

  const interventionPhoto =
    `motos/${motoId}/interventions/visit-1/photo.jpg`;
  const cleanupPhoto =
    `motos/${motoId}/interventions/failed-write/photo.jpg`;
  assert.equal(
    (await uploadImage(cleanupPhoto, mechanic.token)).status,
    200,
    'un mécanicien autorisé peut téléverser avant la création du document d’intervention',
  );
  assert.equal(
    (await request(storageObjectUrl(cleanupPhoto), {
      method: 'DELETE',
      token: mechanic.token,
    })).status,
    200,
    'le nettoyage Storage reste autorisé même si le document d’intervention est absent',
  );
  assert.equal(
    (await uploadImage(interventionPhoto, mechanic.token)).status,
    200,
    'le mécanicien auteur peut joindre une image à son intervention',
  );
  assert.equal(
    (await request(storageObjectUrl(interventionPhoto), {
      token: stranger.token,
    })).status,
    403,
    'les images d’intervention ne sont pas publiques',
  );
  assert.equal(
    (await request(storageObjectUrl(interventionPhoto), {
      token: owner.token,
    })).status,
    200,
    'le propriétaire peut lire les images de ses interventions',
  );

  assert.equal(
    (await request(documentUrl('collectionsInexistante/document'), {
      token: owner.token,
    })).status,
    403,
    'les collections non déclarées sont refusées par défaut',
  );

  const marketListingId = 'market-listing-1';
  const marketListing = {
    vendeurId: owner.uid,
    vendeurNom: 'Vendeur test',
    vendeurEstMecanicien: false,
    titre: 'Moto de test',
    titreRecherche: 'moto de test',
    titrePrefixes: ['m', 'mo', 'mot', 'moto', 'moto ', 'moto d', 'moto de test'],
    categorie: 'motosOccasion',
    etat: 'bonEtat',
    prix: 300000,
    negociable: false,
    description: 'Description de test suffisamment détaillée.',
    photos: ['https://example.test/image.jpg'],
    localisation: 'Ouagadougou',
    localisationRecherche: 'ouagadougou',
    telephone: '+22670000000',
    whatsapp: true,
    champsSpecifiques: {},
    statut: 'active',
    nbSignalements: 0,
  };
  assert.equal(
    (
      await writeDocumentWithServerTimestamp(
        `annonces/${marketListingId}`,
        marketListing,
        owner.token,
        ['datePublication'],
        true,
      )
    ).status,
    200,
    'un utilisateur peut créer une annonce active valide',
  );
  assert.equal(
    (await request(documentUrl(`annonces/${marketListingId}`), {
      token: mechanic.token,
    })).status,
    200,
    'un utilisateur connecté peut consulter une annonce active',
  );
  const marketPhotoPath = `annonces/${marketListingId}/photo.jpg`;
  assert.equal(
    (await uploadImage(marketPhotoPath, owner.token)).status,
    200,
    'le vendeur peut téléverser une photo de son annonce',
  );
  assert.equal(
    (await uploadImage(marketPhotoPath, stranger.token)).status,
    403,
    'un autre utilisateur ne peut pas remplacer la photo du vendeur',
  );
  assert.equal(
    (await request(storageObjectUrl(marketPhotoPath), {
      token: stranger.token,
    })).status,
    200,
    'tout utilisateur connecté peut consulter les photos du Marché',
  );
  assert.equal(
    (await request(storageObjectUrl(marketPhotoPath), {
      method: 'DELETE',
      token: stranger.token,
    })).status,
    403,
    'seul le vendeur peut supprimer une photo de son annonce',
  );
  assert.equal(
    (await writeDocument(`annonces/${marketListingId}`, {
      nbSignalements: 50,
    }, owner.token)).status,
    403,
    'le vendeur ne peut pas modifier le compteur de signalements',
  );
  assert.equal(
    (
      await submitMarketReport({
        announcementId: marketListingId,
        reporter: mechanic,
      })
    ).status,
    200,
    'un signalement et son compteur sont enregistrés atomiquement',
  );
  assert.equal(
    (await request(documentUrl(`signalements/${marketListingId}_${mechanic.uid}`), {
      token: mechanic.token,
    })).status,
    403,
    'les signalements ne sont pas lisibles par les utilisateurs',
  );
  assert.notEqual(
    (
      await submitMarketReport({
        announcementId: marketListingId,
        reporter: mechanic,
      })
    ).status,
    200,
    'un même utilisateur ne peut pas signaler deux fois la même annonce',
  );
  assert.equal(
    (await writeDocument(`annonces/${marketListingId}`, {
      statut: 'vendue',
    }, owner.token)).status,
    200,
    'le vendeur peut marquer son annonce vendue',
  );
  assert.equal(
    (await request(documentUrl(`annonces/${marketListingId}`), {
      token: stranger.token,
    })).status,
    403,
    'une annonce vendue n’est plus visible aux autres utilisateurs',
  );
  assert.equal(
    (await request(documentUrl(`annonces/${marketListingId}`), {
      token: owner.token,
    })).status,
    200,
    'le vendeur conserve l’accès à sa propre annonce vendue',
  );
  assert.equal(
    (await request(storageObjectUrl(marketPhotoPath), {
      method: 'DELETE',
      token: owner.token,
    })).status,
    200,
    'le vendeur peut nettoyer les photos de son annonce',
  );

  assert.equal(
    (await request(documentUrl(interventionPath), {
      method: 'DELETE',
      token: owner.token,
    })).status,
    403,
    'un propriétaire ne peut pas supprimer une intervention hors suppression de compte',
  );
  assert.equal(
    (await writeDocument(
      `utilisateurs/${owner.uid}`,
      { deletionRequested: true },
      owner.token,
    )).status,
    200,
    'le propriétaire peut démarrer la procédure de suppression de compte',
  );
  assert.equal(
    (await request(documentUrl(interventionPath), {
      method: 'DELETE',
      token: owner.token,
    })).status,
    200,
    'la suppression de compte permet d’effacer les interventions personnelles',
  );
});
