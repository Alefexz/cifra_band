// Idempotent, additive migration. Original song documents are never deleted.
const fs = require('node:fs');
const path = require('node:path');
const { createHash } = require('node:crypto');
const { isDeepStrictEqual } = require('node:util');
const auth = require(path.join(process.env.APPDATA, 'npm/node_modules/firebase-tools/lib/auth.js'));
const project = 'cifra-band';
const root = `projects/${project}/databases/(default)/documents`;
const endpoint = `https://firestore.googleapis.com/v1/${root}`;
const apply = process.argv.includes('--apply');
const hash = data => createHash('sha256').update(JSON.stringify(data)).digest('hex');
let token;
async function request(url, body) {
  const response = await fetch(url, { method: body ? 'POST' : 'GET',
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: body ? JSON.stringify(body) : undefined });
  if (response.status === 404) return null;
  if (!response.ok) throw Error(`Migration HTTP ${response.status}: ${(await response.text()).slice(0, 300)}`);
  return response.json();
}
async function list(collection) {
  const docs = [];
  let cursor;
  do {
    const query = new URLSearchParams({ pageSize: '100', ...(cursor ? {pageToken: cursor} : {}) });
    const page = await request(`${endpoint}/${collection}?${query}`);
    docs.push(...(page.documents || []));
    cursor = page.nextPageToken;
  } while (cursor);
  return docs;
}
function strings(field) { return (field?.arrayValue?.values || []).map(v => v.stringValue).filter(Boolean); }
function encode(value) {
  if (typeof value === 'string') return {stringValue: value};
  if (typeof value === 'number') return {integerValue: String(value)};
  if (typeof value === 'boolean') return {booleanValue: value};
  if (Array.isArray(value)) return {arrayValue: {values: value.map(encode)}};
  return {nullValue: null};
}
async function createOrVerify(relative, fields) {
  const existing = await request(`${endpoint}/${relative}`);
  if (existing) {
    if (relative.includes('/songs/') && !isDeepStrictEqual(existing.fields, fields)) throw Error(`Existing song differs: ${relative}`);
    return;
  }
  if (apply) await request(`${endpoint}:commit`, {writes: [{update: {name: `${root}/${relative}`, fields}, currentDocument: {exists: false}}]});
}
(async () => {
  token = (await auth.getAccessToken(auth.getGlobalDefaultAccount().tokens.refresh_token, [])).access_token;
  const users = await list('users');
  const setlists = await list('setlists');
  const songs = await list('songs');
  const byId = new Map(songs.map(song => [song.name.split('/').at(-1), song]));
  const missing = [];
  let copies = 0, tokenCount = 0;
  for (const setlist of setlists) for (const id of strings(setlist.fields?.songIds)) {
    if (!byId.has(id)) {
      const nested = await request(`${endpoint}/setlists/${setlist.name.split('/').at(-1)}/songs/${id}`);
      if (!nested) missing.push(`${setlist.name.split('/').at(-1)}/${id}`);
    } else copies++;
  }
  if (missing.length) throw Error(`Missing referenced songs (${missing.length}); refusing migration.`);
  if (apply) {
    fs.mkdirSync(path.join(__dirname, '../build/migrations'), {recursive: true});
    fs.writeFileSync(path.join(__dirname, `../build/migrations/156-${Date.now()}.json`), JSON.stringify({project, users, setlists, songs}));
  }
  for (const setlist of setlists) for (const id of strings(setlist.fields?.songIds)) {
    const source = byId.get(id);
    if (source) await createOrVerify(`setlists/${setlist.name.split('/').at(-1)}/songs/${id}`, source.fields);
  }
  for (const user of users) {
    const uid = user.name.split('/').at(-1);
    const fields = user.fields || {};
    await createOrVerify(`public_profiles/${uid}`, {
      name: fields.name || encode('Musico'), roles: fields.roles || encode([]), friendCode: fields.friendCode || encode(null),
    });
    const tokens = [...strings(fields.fcmTokens), ...(fields.fcmToken?.stringValue ? [fields.fcmToken.stringValue] : [])];
    for (const value of new Set(tokens)) {
      tokenCount++;
      const device = createHash('sha256').update(value).digest('hex');
      await createOrVerify(`app_devices/${device}`, {
        token: encode(value), uid: encode(uid), platform: encode('android'), build: encode(1),
        enabled: encode(true), registeredAt: encode(Date.now()), migrated: encode(true),
      });
    }
    if (apply && (fields.fcmTokens || fields.fcmToken)) {
      const privateFields = { fcmTokens: encode(tokens) };
      await createOrVerify(`users/${uid}/private/push`, privateFields);
      await request(`${endpoint}:commit`, {writes: [{update: {name: user.name, fields: {}},
        updateMask: {fieldPaths: ['fcmTokens', 'fcmToken', 'fcmTokenUpdatedAt']}, currentDocument: {updateTime: user.updateTime}}]});
    }
  }
  console.log(JSON.stringify({project, mode: apply ? 'APPLIED' : 'PLAN ONLY', users: users.length, setlists: setlists.length, copiedSongReferences: copies, tokens: tokenCount, missing: missing.length}));
})().catch(error => { console.error(error.message); process.exitCode = 1; });
