const { test, before, after } = require('node:test');
const { readFileSync } = require('node:fs');
const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const { doc, setDoc, getDoc, getDocs, collection, query, or, where, updateDoc, writeBatch, arrayUnion, arrayRemove } = require('firebase/firestore');
let env;
before(async () => {
  env = await initializeTestEnvironment({ projectId: 'demo-cifra-band', firestore: {
    rules: readFileSync('../../firestore.rules', 'utf8'), host: '127.0.0.1', port: 8080,
  }});
  await env.withSecurityRulesDisabled(async context => {
    const db = context.firestore();
    await setDoc(doc(db, 'setlists/owned'), { ownerId: 'owner', title: 'Culto', songIds: [], sharedWith: ['member', 'other'] });
    await setDoc(doc(db, 'setlists/legacy'), { ownerId: 'owner', title: 'Antiga', songIds: [] });
    await setDoc(doc(db, 'users/member'), { church_id: 'church', is_admin: false });
    await setDoc(doc(db, 'schedules/scale'), { church_id: 'church', title: 'Culto', date: 1, team_uids: ['member'], suggested_songs: [] });
  });
});
after(async () => env?.cleanup());
test('reproduces old failure: reading nonexistent schedule before setlist save is denied', async () => {
  await assertFails(getDoc(doc(env.authenticatedContext('owner').firestore(), 'schedules/owned')));
});
for (const uid of ['owner', 'member']) {
  test(`${uid}: list with the exact app OR query`, async () => {
    const db = env.authenticatedContext(uid).firestore();
    const result = await assertSucceeds(getDocs(query(collection(db, 'setlists'), or(where('ownerId', '==', uid), where('sharedWith', 'array-contains', uid)))));
    if (!result.docs.some(d => d.id === 'owned')) throw Error('Setlist missing');
  });
  test(`${uid}: atomic song creation and setlist update`, async () => {
    const db = env.authenticatedContext(uid).firestore();
    const batch = writeBatch(db);
    batch.set(doc(db, `songs/${uid}`), { title: 'Teste', content: 'C G\nLetra de teste', created_by: uid });
    batch.update(doc(db, 'setlists/owned'), { songIds: arrayUnion(uid), updatedAt: 1 });
    await assertSucceeds(batch.commit());
    await assertSucceeds(getDoc(doc(db, `songs/${uid}`)));
  });
}
test('legacy owner can still add a song without sharedWith field', async () => {
  await assertSucceeds(updateDoc(doc(env.authenticatedContext('owner').firestore(), 'setlists/legacy'), { songIds: arrayUnion('owner') }));
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
test('musician can suggest to own schedule', async () => {
  await assertSucceeds(updateDoc(doc(env.authenticatedContext('member').firestore(), 'schedules/scale'), { suggested_songs: arrayUnion({ title: 'Teste', content: 'C G\nLetra', suggestedBy: 'member' }) }));
});
test('unauthenticated account cannot list setlists', async () => {
  await assertFails(getDocs(collection(env.unauthenticatedContext().firestore(), 'setlists')));
});
