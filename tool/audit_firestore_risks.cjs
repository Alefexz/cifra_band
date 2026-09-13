// Characterization audit of current rules, strictly against the local emulator.
const { readFileSync } = require('node:fs');
const path = require('node:path');
const { initializeTestEnvironment } = require('../test/firestore/node_modules/@firebase/rules-unit-testing');
const { doc, setDoc, getDoc, updateDoc } = require('../test/firestore/node_modules/firebase/firestore');

(async () => {
  if (!process.env.FIRESTORE_EMULATOR_HOST?.startsWith('127.0.0.1:')) {
    throw Error('Local emulator required; this audit never runs on production.');
  }
  const env = await initializeTestEnvironment({ projectId: 'demo-cifra-band', firestore: {
    host: '127.0.0.1', port: 8080,
    rules: readFileSync(path.join(__dirname, '../firestore.rules'), 'utf8'),
  }});
  const results = [];
  try {
    await env.withSecurityRulesDisabled(async c => {
      const db = c.firestore();
      await setDoc(doc(db, 'users/audit-stranger'), { church_id: null, is_admin: false, email: 'dummy@example.invalid' });
      await setDoc(doc(db, 'users/audit-member'), { church_id: 'audit-church', is_admin: false });
      await setDoc(doc(db, 'users/audit-target'), { church_id: 'audit-church', is_admin: false, friendCode: 'DUMMY', fcmTokens: ['FAKE-TOKEN'], friends: ['audit-friend'] });
      await setDoc(doc(db, 'ministries/audit-church'), { name: 'Dummy ministry', admin_id: 'audit-admin' });
      await setDoc(doc(db, 'schedules/audit-scale'), { church_id: 'audit-church', title: 'Dummy', date: 1,
        team_uids: ['audit-member'], team_assignments: { other: { uid: 'audit-target', status: 'pending' } } });
    });
    async function check(name, action) {
      try { await action(); results.push({name, allowed: true}); }
      catch (e) { results.push({name, allowed: false, code: e.code}); }
    }
    const stranger = env.authenticatedContext('audit-stranger').firestore();
    const member = env.authenticatedContext('audit-member').firestore();
    await check('read other ministry profile with friendCode, including fake FCM token', () => getDoc(doc(stranger, 'users/audit-target')));
    await check('overwrite another users friends list', () => updateDoc(doc(stranger, 'users/audit-target'), { friends: ['audit-stranger'] }));
    await check('change self profile email independently of Auth email', () => updateDoc(doc(stranger, 'users/audit-stranger'), { email: 'audit-owner@example.invalid' }));
    await check('join known ministry ID without presenting invitation', () => updateDoc(doc(stranger, 'users/audit-stranger'), { church_id: 'audit-church', is_admin: false }));
    await check('edit another musicians attendance', () => updateDoc(doc(member, 'schedules/audit-scale'), { team_assignments: { other: { uid: 'audit-target', status: 'accepted' } } }));
    await check('unauthenticated profile read', () => getDoc(doc(env.unauthenticatedContext().firestore(), 'users/audit-target')));
    console.log(JSON.stringify({scope:'LOCAL EMULATOR ONLY', results}, null, 2));
  } finally { await env.cleanup(); }
})().catch(e => { console.error(e.message); process.exitCode = 1; });
