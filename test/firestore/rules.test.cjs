const { test, before, after } = require('node:test');
const { readFileSync } = require('node:fs');
const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const { doc, setDoc, getDoc, getDocs, collection, query, or, where, documentId, updateDoc, writeBatch, arrayUnion, arrayRemove } = require('firebase/firestore');
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
