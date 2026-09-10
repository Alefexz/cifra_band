const { test, before, after, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const admin = require('../../functions/node_modules/firebase-admin');
const { createUpdatePushWorker, isEligible, deviceId, parseRegistration } = require('../../functions/lib/update-push');
let app, db, clock, calls, version, facade, failToken;
const logger = { log() {}, error() {} };
before(() => {
    if (!process.env.FIRESTORE_EMULATOR_HOST) throw Error('Emulator required');
    app = admin.initializeApp({ projectId: 'demo-cifra-band' }, 'update-push-tests');
    db = app.firestore();
});
after(async () => app?.delete());
beforeEach(async () => {
    for (const name of ['app_devices', 'system_jobs']) {
        const docs = await db.collection(name).get();
        const batch = db.batch(); docs.forEach(doc => batch.delete(doc.ref)); await batch.commit();
    }
    clock = 1000000000; calls = []; failToken = null;
    version = { latestVersion: '1.5.4', latestBuild: 22, apkUrl: 'https://example.com/app.apk' };
    const firestore = () => db; firestore.FieldPath = admin.firestore.FieldPath;
    facade = { firestore, messaging: () => ({ sendEachForMulticast: async payload => {
        calls.push(payload);
        const responses = payload.tokens.map(token => token === failToken ?
            { success:false, error:{ code:token === 'invalid' ? 'messaging/registration-token-not-registered' : 'messaging/server-unavailable' }} : { success:true });
        return { responses, successCount:responses.filter(r=>r.success).length, failureCount:responses.filter(r=>!r.success).length };
    } }) };
});
const worker = () => createUpdatePushWorker({ getAdmin:()=>facade, getVersion:()=>version, now:()=>clock, logger });
const seed = (id, data={}) => db.collection('app_devices').doc(id).set({token:id,build:21,platform:'android',enabled:true,...data});
test('only registered older Android devices qualify', () => {
    assert.equal(isEligible({token:'x',build:21,platform:'android'},version),true);
    for (const changes of [{build:22},{build:23},{build:undefined},{platform:'ios'},{enabled:false},{lastNotifiedBuild:22}]) {
        assert.equal(isEligible({token:'x',build:21,platform:'android',...changes},version),false);
    }
    assert.equal(parseRegistration({token:'x',build:21,platform:'android'}),null);
    assert.equal(deviceId('secret-token').includes('secret-token'),false);
});
test('sends to outdated device only and persists deduplication across restarts', async () => {
    await seed('old'); await seed('current',{build:22}); await seed('unknown',{build:null});
    await worker().runPage();
    assert.deepEqual(calls[0].tokens,['old']);
    assert.equal(calls[0].data.type,'app_update_available');
    assert.ok(calls[0].notification.title);
    clock += 16*60*1000;
    await worker().runPage();
    assert.equal(calls.length,1);
    version.latestBuild=23;
    await worker().runPage();
    assert.deepEqual(calls[1].tokens.sort(),['current','old']);
});
test('concurrent waking requests share a persistent lease', async () => {
    await seed('old');
    await Promise.all([worker().runPage(),worker().runPage()]);
    assert.equal(calls.length,1);
});
test('registration of the new installed build prevents future sends', async () => {
    await seed('old');
    await db.collection('app_devices').doc('old').update({build:22});
    await worker().runPage();
    assert.equal(calls.length,0);
});
test('invalid tokens are disabled', async () => {
    failToken='invalid'; await seed('invalid'); await worker().runPage();
    assert.equal((await db.collection('app_devices').doc('invalid').get()).data().enabled,false);
});
test('temporary failures are retried without repeating successful deliveries', async () => {
    failToken='retry'; await seed('retry'); await seed('success');
    await worker().runPage(); clock += 16*60*1000; failToken=null;
    await worker().runPage();
    assert.deepEqual(calls[1].tokens,['retry']);
});
test('pagination reaches all devices without a 100-token truncation', async () => {
    const batch=db.batch();
    for(let i=0;i<101;i++) batch.set(db.collection('app_devices').doc(`device-${i}`),{token:`t${i}`,build:21,platform:'android'});
    await batch.commit();
    assert.equal(await worker().runPage(),true);
    assert.equal(await worker().runPage(),false);
    assert.equal(calls.flatMap(c=>c.tokens).length,101);
});
