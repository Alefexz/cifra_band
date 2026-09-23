const {test, before, after} = require('node:test');
const assert = require('node:assert/strict');
const {readFileSync} = require('node:fs');
const {randomBytes} = require('node:crypto');
const {initializeTestEnvironment, assertFails} = require('@firebase/rules-unit-testing');
const {doc, getDoc, setDoc, deleteDoc} = require('firebase/firestore');
const admin = require('../../functions/node_modules/firebase-admin');
const express = require('../../functions/node_modules/express');
const {createAccountDeletionService, mountAccountDeletion, receiptId} = require('../../functions/lib/account-deletion');
const {createAuthenticator} = require('../../functions/lib/firebase-auth');
for (const key of ['FIRESTORE_EMULATOR_HOST', 'FIREBASE_AUTH_EMULATOR_HOST']) {
    assert.match(process.env[key] || '', /^(127\.0\.0\.1|localhost):\d+$/, `Refusing to test outside local ${key}`);
}
let sdk, db, env, service, server, origin;
const uid = 'delete-subject'; const other = 'delete-survivor';
const receipt = randomBytes(32).toString('hex');
const user = {uid, auth_time: Math.floor(Date.now()/1000)};
let token, refreshToken;
before(async () => {
    sdk = admin.initializeApp({projectId:'demo-cifra-band'}, 'account-deletion-tests');
    db = sdk.firestore();
    const firestore = () => db;
    Object.assign(firestore, {FieldValue:admin.firestore.FieldValue, FieldPath:admin.firestore.FieldPath, Timestamp:admin.firestore.Timestamp});
    const facade = {firestore, auth: () => sdk.auth()};
    service = createAccountDeletionService({getAdmin:()=>facade, logger:{error:()=>{}}});
    env = await initializeTestEnvironment({projectId:'demo-cifra-band', firestore:{
        rules:readFileSync('../../firestore.rules','utf8'),host:'127.0.0.1',port:8080}});
    const app = express(); app.use(express.json());
    mountAccountDeletion(app,{service:{...service,kick:()=>{}}, authenticate:createAuthenticator(()=>facade),limit:(_req,_res,next)=>next()});
    server = await new Promise(resolve => {const server=app.listen(0,'127.0.0.1',()=>resolve(server));});
    origin=`http://127.0.0.1:${server.address().port}`;
    await sdk.auth().createUser({uid,email:'delete-subject@example.test',password:'Test-password-123!'});
    const auth = await (await fetch(`http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=fake`,{
        method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({email:'delete-subject@example.test',password:'Test-password-123!',returnSecureToken:true})})).json();
    token=auth.idToken;refreshToken=auth.refreshToken; assert.ok(token);
    const fixtures = {
        [`users/${uid}`]:{name:'Delete',church_id:'delete-ministry',is_admin:true},
        [`users/${uid}/private/push`]:{fcmTokens:['private-token']},
        [`users/${uid}/notes/private`]:{text:'private'},
        [`users/${other}`]:{name:'Keep',church_id:'delete-ministry',friends:[uid,'keep']},
        [`public_profiles/${uid}`]:{name:'Delete'},
        'ministries/delete-ministry':{name:'Shared ministry',admin_id:uid},
        'ministry_invites/DEL123':{ministry_id:'delete-ministry',admin_id:uid},
        'setlists/delete-owned':{ownerId:uid,songIds:['s']},
        'setlists/delete-owned/songs/s':{title:'Delete'},
        'setlists/delete-shared':{ownerId:other,sharedWith:[uid,'keep'],songIds:['mine','other']},
        'setlists/delete-shared/songs/mine':{created_by:uid},
        'setlists/delete-shared/songs/other':{created_by:other},
        'schedules/delete-schedule':{church_id:'delete-ministry',team_uids:[uid,other],team_assignments:[{uid},{uid:other}],
            suggested_songs:[{suggestedByUid:uid},{suggestedByUid:other,upvotes:[uid,other]}]},
        'schedules/delete-schedule/rehearsal_status/mine':{uid},
        'schedules/missing-parent/rehearsal_status/orphan':{uid},
        'ministries/delete-ministry/official_songs/mine':{created_by:uid},
        'ministries/delete-ministry/official_songs/mine/versions/v':{updated_by:uid},
        'ministries/delete-ministry/official_songs/other':{created_by:other,updated_by:uid},
        'ministries/delete-ministry/official_songs/other/versions/mine':{updated_by:uid},
        'ministries/missing-parent/official_songs/missing/versions/orphan':{updated_by:uid},
        'ministries/missing-parent/official_songs/orphan':{created_by:uid},
        'support_tickets/delete-own':{user:{uid},messages:[{uid,message:'private'}]},
        'support_tickets/delete-other':{user:{uid:other},messages:[{uid,message:'private'},{uid:other,message:'keep'}],admin_reply:{responder_uid:uid},handled_by:{uid}},
        'app_devices/delete-mine':{uid,token:'private'},'app_devices/delete-other':{uid:other,token:'keep'},
        'contact_codes/DELETE':{uid}, 'songs/delete-legacy':{created_by:uid},
        'setlists/missing-parent/songs/delete-orphan':{created_by:uid},
    };
    const batch=db.batch(); for(const [path,data] of Object.entries(fixtures)) batch.set(db.doc(path),data); await batch.commit();
});
after(async()=>{await new Promise(resolve=>server.close(resolve));await env.cleanup();await sdk.delete();});
const post=(path,body,bearer=token)=>fetch(origin+path,{method:'POST',headers:{'Content-Type':'application/json',...(bearer?{Authorization:`Bearer ${bearer}`}:{})},body:JSON.stringify(body)});
test('deletion requires authentication, recent login, confirmation and explicit valid successor',async()=>{
    assert.equal((await post('/account/deletion/request',{confirm:true,receipt},null)).status,401);
    await assert.rejects(service.request({...user,auth_time:1},{confirm:true,receipt}),{status:401});
    await assert.rejects(service.request(user,{confirm:false,receipt}),{status:400});
    await assert.rejects(service.request(user,{confirm:true,receipt}),{status:409});
    await assert.rejects(service.request(user,{confirm:true,receipt,successors:{'delete-ministry':'outsider'}}),{status:409});
    assert.equal((await db.doc(`account_deletion_blocks/${uid}`).get()).exists,false);
});
test('accepted request transfers ownership and immediately denies old sessions and resurrection',async()=>{
    const response=await post('/account/deletion/request',{confirm:true,receipt,uid:other,successors:{'delete-ministry':other}});
    assert.equal(response.status,202,await response.text());
    assert.equal((await db.doc('ministries/delete-ministry').get()).data().admin_id,other);
    assert.equal((await db.doc(`users/${other}`).get()).data().is_admin,true);
    assert.equal((await post('/account/deletion/options',{})).status,403);
    const context=env.authenticatedContext(uid).firestore();
    await assertFails(getDoc(doc(context,`users/${uid}`)));
    await assertFails(setDoc(doc(context,`users/${uid}`),{name:'resurrect'}));
    await assertFails(deleteDoc(doc(context,`account_deletion_blocks/${uid}`)));
    assert.equal((await service.request(user,{confirm:true,receipt})).accepted,true);
    await assert.rejects(service.request({uid:other,auth_time:user.auth_time},{confirm:true,receipt}),{status:409});
});
test('cleanup deletes account, nested/orphaned data and FCM while preserving unrelated work',async()=>{
    assert.equal(await service.run(receiptId(receipt)),true,JSON.stringify((await db.doc(`account_deletions/${receiptId(receipt)}`).get()).data()));
    for(const path of [`users/${uid}`,`users/${uid}/private/push`,`users/${uid}/notes/private`,`public_profiles/${uid}`,
        'setlists/delete-owned','setlists/delete-owned/songs/s','setlists/delete-shared/songs/mine',
        'schedules/delete-schedule/rehearsal_status/mine','schedules/missing-parent/rehearsal_status/orphan',
        'ministries/delete-ministry/official_songs/mine','ministries/delete-ministry/official_songs/mine/versions/v',
        'ministries/delete-ministry/official_songs/other/versions/mine','ministries/missing-parent/official_songs/missing/versions/orphan',
        'ministries/missing-parent/official_songs/orphan',
        'support_tickets/delete-own','app_devices/delete-mine','contact_codes/DELETE','songs/delete-legacy',
        'setlists/missing-parent/songs/delete-orphan']) assert.equal((await db.doc(path).get()).exists,false,path);
    assert.deepEqual((await db.doc(`users/${other}`).get()).data().friends,['keep']);
    const shared=(await db.doc('setlists/delete-shared').get()).data();assert.deepEqual(shared.sharedWith,['keep']);assert.deepEqual(shared.songIds,['other']);
    assert.equal((await db.doc('setlists/delete-shared/songs/other').get()).exists,true);
    const support=(await db.doc('support_tickets/delete-other').get()).data();assert.equal(support.admin_reply,undefined);assert.equal(support.handled_by,undefined);assert.equal(support.messages.length,1);
    assert.equal((await db.doc('app_devices/delete-other').get()).data().token,'keep');
    assert.deepEqual((await db.doc('schedules/delete-schedule').get()).data().team_uids,[other]);
    await assert.rejects(sdk.auth().getUser(uid),{code:'auth/user-not-found'});
    assert.equal((await post('/account/deletion/options',{})).status,401);
    const refresh=await fetch(`http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}/securetoken.googleapis.com/v1/token?key=fake`,{
        method:'POST',headers:{'Content-Type':'application/x-www-form-urlencoded'},body:new URLSearchParams({grant_type:'refresh_token',refresh_token:refreshToken})});
    assert.equal(refresh.ok,false);
    const status=await (await post('/account/deletion/status',{receipt},null)).json();assert.equal(status.status,'complete');assert.equal(status.uid,undefined);
    assert.equal((await db.doc(`account_deletions/${receiptId(receipt)}`).get()).data().uid,undefined);
    assert.equal(await service.run(receiptId(receipt)),false);
});
test('public page works without login, has CSP and does not expose identity via status',async()=>{
    const page=await fetch(origin+'/account-deletion');assert.equal(page.status,200);assert.match(page.headers.get('content-security-policy'),/frame-ancestors 'none'/);
    assert.match(await page.text(),/Excluir conta e dados/);
    assert.equal((await post('/account/deletion/status',{receipt:'bad'},null)).status,400);
    assert.equal((await post('/account/deletion/status',{receipt:'f'.repeat(64)},null)).status,404);
});
test('interrupted deletion resumes at persisted phase and handles multiple query pages',async()=>{
    const retryUid='delete-retry';const retryReceipt=randomBytes(32).toString('hex');
    await sdk.auth().createUser({uid:retryUid});
    const batch=db.batch();batch.set(db.doc(`users/${retryUid}`),{name:'Retry'});
    for(let i=0;i<103;i++) batch.set(db.doc(`app_devices/paged-${i.toString().padStart(3,'0')}`),{uid:retryUid});
    await batch.commit();await service.request({uid:retryUid,auth_time:user.auth_time},{confirm:true,receipt:retryReceipt});
    const original=sdk.auth().deleteUser.bind(sdk.auth()); let first=true;
    sdk.auth().deleteUser=async id=>{if(id===retryUid&&first){first=false;throw Object.assign(new Error('temporary'),{code:'test/unavailable'});}return original(id);};
    try {
        assert.equal(await service.run(receiptId(retryReceipt)),false);
        assert.equal((await service.status(retryReceipt)).status,'retry');
        assert.equal(await service.run(receiptId(retryReceipt)),true);
        assert.equal((await db.collection('app_devices').where('uid','==',retryUid).get()).empty,true);
    }finally{sdk.auth().deleteUser=original;}
});
