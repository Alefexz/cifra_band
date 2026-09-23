const { test, before, after } = require('node:test');
const { readFileSync } = require('node:fs');
const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const { doc, setDoc, getDoc, getDocs, collection, query, or, where, documentId, updateDoc, writeBatch, arrayUnion, arrayRemove, runTransaction } = require('firebase/firestore');
let env;
before(async () => {
  env = await initializeTestEnvironment({ projectId: 'demo-cifra-band', firestore: {
    rules: readFileSync('../../firestore.rules', 'utf8'), host: '127.0.0.1', port: 8080,
  }});
  await env.withSecurityRulesDisabled(async context => {
    const db = context.firestore();
    await setDoc(doc(db, 'setlists/owned'), { ownerId: 'owner', title: 'Culto', songIds: [], sharedWith: ['member', 'other', 'revoked'] });
    await setDoc(doc(db, 'setlists/legacy'), { ownerId: 'owner', title: 'Antiga', songIds: [] });
    await setDoc(doc(db, 'users/member'), { church_id: 'church', is_admin: false });
    await setDoc(doc(db, 'users/stranger'), { church_id: null, is_admin: false });
    await setDoc(doc(db, 'users/target'), { church_id: 'elsewhere', is_admin: false, friendCode: 'ABC123', friends: ['old'] });
    await setDoc(doc(db, 'users/target/private/push'), { fcmTokens: ['fake'] });
    await setDoc(doc(db, 'public_profiles/target'), { name: 'Teste', roles: [] });
    await setDoc(doc(db, 'schedules/scale'), { church_id: 'church', title: 'Culto', date: 1, team_uids: ['member'], suggested_songs: [] });
  });
});
after(async () => env?.cleanup());
test('rehearsal board is isolated by ministry and rejects anonymous access', async () => {
  for (const context of [env.unauthenticatedContext(), env.authenticatedContext('target'), env.authenticatedContext('stranger')]) {
    await assertFails(getDocs(collection(context.firestore(), 'schedules/scale/rehearsal_status')));
  }
  await assertSucceeds(getDocs(collection(env.authenticatedContext('member').firestore(), 'schedules/scale/rehearsal_status')));
  await env.withSecurityRulesDisabled(async context => {
    await setDoc(doc(context.firestore(), 'users/empty-church'), {church_id: '', is_admin: false});
    await setDoc(doc(context.firestore(), 'schedules/empty-church'), {church_id: ''});
  });
  await assertFails(getDoc(doc(env.authenticatedContext('empty-church').firestore(), 'schedules/empty-church')));
});
test('preparation writes validate identity, state, revision and payload limits', async () => {
  const db = env.authenticatedContext('member').firestore();
  const ref = doc(db, 'schedules/scale/rehearsal_status/member_preparation');
  const valid = {uid: 'member', songKey: 'preparation', title: 'Teste', artist: 'Equipe',
    rehearsed: false, preparation: 'needsHelp', arrangementRevision: 'a'.repeat(64), note: 'Ponte'};
  await assertSucceeds(setDoc(ref, valid));
  for (const patch of [{preparation: 'invalid'}, {rehearsed: true}, {arrangementRevision: 'fake'},
    {note: 'x'.repeat(1501)}, {note: {private: true}}, {extra: 'injected'}, {uid: 'target'}]) {
    await assertFails(updateDoc(ref, patch));
  }
  await assertSucceeds(updateDoc(ref, {preparation: 'ready', rehearsed: true}));
  await assertSucceeds(updateDoc(ref, {note: 'Nova observacao'}));
  const assert = require('node:assert/strict');
  assert.equal((await getDoc(ref)).data().preparation, 'ready');
  await assertFails(updateDoc(doc(env.authenticatedContext('target').firestore(), ref.path), {note: 'other ministry'}));
  await env.withSecurityRulesDisabled(context => setDoc(doc(context.firestore(), 'users/leader'), {church_id: 'church', is_admin: true}));
  await assertSucceeds(getDoc(doc(env.authenticatedContext('leader').firestore(), ref.path)));
  await assertFails(updateDoc(doc(env.authenticatedContext('leader').firestore(), ref.path), {note: 'cannot impersonate'}));
});
test('legacy preparation remains readable and can migrate without losing notes', async () => {
  const db = env.authenticatedContext('member').firestore();
  const ref = doc(db, 'schedules/scale/rehearsal_status/member_legacy-preparation');
  await assertSucceeds(setDoc(ref, {uid: 'member', songKey: 'legacy-preparation', rehearsed: false, note: 'Preservar'}));
  await assertSucceeds(updateDoc(ref, {preparation: 'studying', rehearsed: false, arrangementRevision: 'b'.repeat(64)}));
  const assert = require('node:assert/strict');
  assert.equal((await getDoc(ref)).data().note, 'Preservar');
  await env.withSecurityRulesDisabled(context => updateDoc(doc(context.firestore(), 'users/member'), {church_id: null}));
  try { await assertFails(getDoc(ref)); } finally {
    await env.withSecurityRulesDisabled(context => updateDoc(doc(context.firestore(), 'users/member'), {church_id: 'church'}));
  }
});
test('contact endpoint resolves legacy cross-ministry friends without opening private profiles', async () => {
  const assert = require('node:assert/strict');
  const express = require('../../functions/node_modules/express');
  const backendRequire = require('node:module').createRequire(require.resolve('../../functions/package.json'));
  const { initializeApp, deleteApp } = backendRequire('firebase-admin/app');
  const { getFirestore } = backendRequire('firebase-admin/firestore');
  const { mountMemberActions } = require('../../functions/lib/member-actions');
  assert.match(process.env.FIRESTORE_EMULATOR_HOST || '', /(?:127\.0\.0\.1|localhost):8080/);
  await env.withSecurityRulesDisabled(async context => {
    const db = context.firestore();
    await setDoc(doc(db, 'users/contact-owner'), { name: 'Owner', church_id: 'one', friends: ['contact-same', 'contact-cross'] });
    await setDoc(doc(db, 'users/contact-same'), { name: 'Same', church_id: 'one', email: 'private' });
    await setDoc(doc(db, 'users/contact-cross'), { name: 'Cross', church_id: 'two', email: 'private', fcmTokens: ['private'] });
    await setDoc(doc(db, 'setlists/contact-sharing'), { title: 'Sharing', ownerId: 'contact-owner', sharedWith: [], songIds: ['song'] });
    await setDoc(doc(db, 'setlists/contact-sharing/songs/song'), { title: 'Test', content: 'C G\nTest words', created_by: 'contact-owner' });
  });
  const adminApp = initializeApp({ projectId: 'demo-cifra-band' }, 'contact-test');
  const app = express();
  app.use(express.json());
  mountMemberActions(app, {
    authenticate: (req, res, next) => {
      if (req.headers.authorization !== 'Bearer local-owner') return res.sendStatus(401);
      req.firebaseUser = { uid: 'contact-owner' };
      next();
    },
    limit: (_req, _res, next) => next(),
    getAdmin: () => ({ firestore: () => getFirestore(adminApp) }),
  });
  const server = app.listen(0, '127.0.0.1');
  await new Promise(resolve => server.once('listening', resolve));
  try {
    const url = `http://127.0.0.1:${server.address().port}/members/contacts`;
    assert.equal((await fetch(url, { method: 'POST' })).status, 401);
    const response = await fetch(url, { method: 'POST', headers: { Authorization: 'Bearer local-owner', 'Content-Type': 'application/json' }, body: JSON.stringify({ uid: 'target', ids: ['target'] }) });
    assert.equal(response.status, 200);
    assert.deepEqual(await response.json(), { contacts: [{id: 'contact-same', name: 'Same'}, {id: 'contact-cross', name: 'Cross'}] });
    const owner = env.authenticatedContext('contact-owner').firestore();
    await assertFails(getDoc(doc(owner, 'users/contact-cross')));
    await assertSucceeds(updateDoc(doc(owner, 'setlists/contact-sharing'), {sharedWith: ['contact-same', 'contact-cross']}));
    for (const uid of ['contact-same', 'contact-cross']) {
      const db = env.authenticatedContext(uid).firestore();
      await assertSucceeds(getDoc(doc(db, 'setlists/contact-sharing')));
      await assertSucceeds(getDoc(doc(db, 'setlists/contact-sharing/songs/song')));
    }
    await assertSucceeds(updateDoc(doc(owner, 'setlists/contact-sharing'), {sharedWith: []}));
    await assertFails(getDoc(doc(env.authenticatedContext('contact-cross').firestore(), 'setlists/contact-sharing/songs/song')));
  } finally {
    server.closeAllConnections();
    await new Promise(resolve => server.close(resolve));
    await deleteApp(adminApp);
  }
});
test('reproduces old failure: reading nonexistent schedule before setlist save is denied', async () => {
  await assertFails(getDoc(doc(env.authenticatedContext('owner').firestore(), 'schedules/owned')));
});
for (const uid of ['owner', 'member']) {
  test(`${uid}: cifra picker transaction saves exact arrangement and deduplicates`, async () => {
    const db = env.authenticatedContext(uid).firestore();
    const ref = doc(db, `setlists/owned/songs/picker-${uid}`);
    async function add() {
      return runTransaction(db, async tx => {
        await tx.get(doc(db, 'setlists/owned'));
        const previous = await tx.get(ref);
        if (previous.exists()) return false;
        tx.set(ref, {title: 'Teste', artist: 'Teste', originalKey: 'D', key: 'D', shapeKey: 'C', capo: '2', content: 'C G\nLetra de teste', created_by: uid});
        tx.update(doc(db, 'setlists/owned'), {songIds: arrayUnion(ref.id), updatedAt: 2});
        return true;
      });
    }
    if (await add() !== true || await add() !== false) throw Error('Duplicate prevention failed');
    const saved = await assertSucceeds(getDoc(ref));
    if (saved.data().shapeKey !== 'C' || saved.data().key !== 'D') throw Error('Arrangement changed');
  });
  test(`${uid}: list with the exact app OR query`, async () => {
    const db = env.authenticatedContext(uid).firestore();
    const result = await assertSucceeds(getDocs(query(collection(db, 'setlists'), or(where('ownerId', '==', uid), where('sharedWith', 'array-contains', uid)))));
    if (!result.docs.some(d => d.id === 'owned')) throw Error('Setlist missing');
  });
  test(`${uid}: atomic song creation and setlist update`, async () => {
    const db = env.authenticatedContext(uid).firestore();
    const batch = writeBatch(db);
    batch.set(doc(db, `setlists/owned/songs/${uid}`), { title: 'Teste', content: 'C G\nLetra de teste', created_by: uid });
    batch.update(doc(db, 'setlists/owned'), { songIds: arrayUnion(uid), updatedAt: 1 });
    await assertSucceeds(batch.commit());
    await assertSucceeds(getDoc(doc(db, `setlists/owned/songs/${uid}`)));
    const loaded = await assertSucceeds(getDocs(query(collection(db, 'setlists/owned/songs'), where(documentId(), 'in', [uid]))));
    if (loaded.size !== 1 || loaded.docs[0].id !== uid) throw Error('Saved song missing from app query');
  });
}
test('legacy owner can still add a song without sharedWith field', async () => {
  await assertSucceeds(updateDoc(doc(env.authenticatedContext('owner').firestore(), 'setlists/legacy'), { songIds: arrayUnion('owner') }));
});
test('legacy owner saves and queries song batches across the app ten-ID boundary', async () => {
  const db = env.authenticatedContext('owner').firestore();
  const ids = Array.from({length: 11}, (_, i) => `chunk-${i}`);
  const batch = writeBatch(db);
  for (const id of ids) batch.set(doc(db, `setlists/legacy/songs/${id}`), {title: id, content: 'C G\nLetra', created_by: 'owner'});
  batch.update(doc(db, 'setlists/legacy'), {songIds: arrayUnion(...ids)});
  await assertSucceeds(batch.commit());
  for (let i = 0; i < ids.length; i += 10) {
    const chunk = ids.slice(i, i + 10);
    const loaded = await assertSucceeds(getDocs(query(collection(db, 'setlists/legacy/songs'), where(documentId(), 'in', chunk))));
    if (loaded.size !== chunk.length) throw Error('Song batch incomplete');
  }
});
test('song list queries deny strangers, signed-out users and unrelated setlists', async () => {
  for (const context of [env.authenticatedContext('stranger'), env.unauthenticatedContext()]) {
    const db = context.firestore();
    await assertFails(getDocs(query(collection(db, 'setlists/owned/songs'), where(documentId(), 'in', ['owner', 'member']))));
    await assertFails(getDocs(collection(db, 'setlists/owned/songs')));
  }
  await assertFails(getDocs(query(collection(env.authenticatedContext('member').firestore(), 'setlists/legacy/songs'), where(documentId(), 'in', ['chunk-0']))));
});
test('revoked collaborator can no longer query songs', async () => {
  const songQuery = query(collection(env.authenticatedContext('revoked').firestore(), 'setlists/owned/songs'), where(documentId(), 'in', ['owner']));
  await assertSucceeds(getDocs(songQuery));
  await assertSucceeds(updateDoc(doc(env.authenticatedContext('owner').firestore(), 'setlists/owned'), {sharedWith: arrayRemove('revoked')}));
  await assertFails(getDocs(songQuery));
});
test('songs without an accessible parent remain unreadable and cannot be created', async () => {
  const db = env.authenticatedContext('owner').firestore();
  await assertFails(getDocs(query(collection(db, 'setlists/missing/songs'), where(documentId(), 'in', ['orphan']))));
  await assertFails(setDoc(doc(db, 'setlists/missing/songs/orphan'), {title: 'Orfa', content: 'C G\nLetra', created_by: 'owner'}));
});
test('stranger cannot read or save and failed batch leaves no orphan song', async () => {
  const db = env.authenticatedContext('stranger').firestore();
  await assertFails(getDoc(doc(db, 'setlists/owned')));
  const batch = writeBatch(db);
  batch.set(doc(db, 'songs/orphan'), { title: 'Teste' });
  batch.update(doc(db, 'setlists/owned'), { songIds: arrayUnion('orphan') });
  await assertFails(batch.commit());
  await env.withSecurityRulesDisabled(async c => {
    if ((await getDoc(doc(c.firestore(), 'songs/orphan'))).exists()) throw Error('Orphan created');
  });
});
test('collaborator cannot steal, share, rename or remove existing songs', async () => {
  const ref = doc(env.authenticatedContext('member').firestore(), 'setlists/owned');
  for (const change of [{ ownerId: 'member' }, { sharedWith: ['member', 'stranger'] }, { title: 'Hack' }, { songIds: [] }]) {
    await assertFails(updateDoc(ref, change));
  }
});
test('collaborator can leave without removing anyone else', async () => {
  await assertSucceeds(updateDoc(doc(env.authenticatedContext('other').firestore(), 'setlists/owned'), { sharedWith: arrayRemove('other') }));
});
test('musician must use validated endpoint instead of replacing all suggestions', async () => {
  await assertFails(updateDoc(doc(env.authenticatedContext('member').firestore(), 'schedules/scale'), { suggested_songs: arrayUnion({ title: 'Teste', content: 'C G\nLetra', suggestedBy: 'member' }) }));
});
test('unauthenticated account cannot list setlists', async () => {
  await assertFails(getDocs(collection(env.unauthenticatedContext().firestore(), 'setlists')));
});

test('private profiles, tokens and arrangements stay private across accounts', async () => {
  const db = env.authenticatedContext('stranger').firestore();
  for (const path of ['users/target', 'users/target/private/push', 'setlists/owned/songs/owner', 'songs/owner']) {
    await assertFails(getDoc(doc(db, path)));
  }
  await assertSucceeds(getDoc(doc(db, 'public_profiles/target')));
});
test('profile changes cannot join a church, grant admin or replace friends', async () => {
  const db = env.authenticatedContext('stranger').firestore();
  await assertFails(updateDoc(doc(db, 'users/stranger'), { church_id: 'church', is_admin: false }));
  await assertFails(updateDoc(doc(db, 'users/stranger'), { is_admin: true }));
  await assertFails(updateDoc(doc(db, 'users/target'), { friends: ['stranger'] }));
  await assertFails(updateDoc(doc(db, 'users/stranger'), { fcmTokens: ['fake'] }));
  await assertSucceeds(updateDoc(doc(db, 'users/stranger'), { name: 'Novo nome' }));
});
test('member cannot overwrite another attendance or rehearsal status', async () => {
  const db = env.authenticatedContext('member').firestore();
  await assertFails(updateDoc(doc(db, 'schedules/scale'), { team_assignments: [{uid: 'target', status: 'accepted'}] }));
  await assertFails(setDoc(doc(db, 'schedules/scale/rehearsal_status/target_song'), { uid: 'member', songKey: 'song', rehearsed: true }));
  await assertSucceeds(setDoc(doc(db, 'schedules/scale/rehearsal_status/member_song'), { uid: 'member', songKey: 'song', rehearsed: true }));
});
test('creating own ministry still works atomically, never claims someone elses', async () => {
  const db = env.authenticatedContext('stranger').firestore();
  const batch = writeBatch(db);
  batch.set(doc(db, 'ministries/new'), {name: 'Equipe', admin_id: 'stranger', invite_code: 'XYZ123'});
  batch.set(doc(db, 'ministry_invites/XYZ123'), {ministry_id: 'new', admin_id: 'stranger'});
  batch.update(doc(db, 'users/stranger'), {church_id: 'new', is_admin: true});
  await assertSucceeds(batch.commit());
  await assertFails(updateDoc(doc(env.authenticatedContext('member').firestore(), 'users/member'), {church_id: 'new', is_admin: true}));
});
