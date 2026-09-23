const assert = require('node:assert/strict');
const fs = require('node:fs');
const express = require('../functions/node_modules/express');
const {chromium} = require('playwright');
const {mountAccountDeletion} = require('../functions/lib/account-deletion');
(async()=>{
    process.env.FIREBASE_WEB_API_KEY='local-test-only';
    const app=express();app.use(express.json());let received;
    mountAccountDeletion(app,{authenticate:(_req,_res,next)=>next(),limit:(_req,_res,next)=>next(),service:{
        options:async()=>[],request:async(_user,body)=>{received=body;return{accepted:true};},
        status:async()=>({status:'complete'}),kick:()=>{},
    }});
    // Test-only authenticated identity; no production credentials or Firebase calls.
    const server=await new Promise(resolve=>{const server=app.listen(0,'127.0.0.1',()=>resolve(server));});
    const origin=`http://127.0.0.1:${server.address().port}`;
    const browser=await chromium.launch({channel:'msedge',headless:true});
    try {
        const page=await browser.newPage();const errors=[];
        page.on('pageerror',error=>errors.push(error.message));
        await page.route('https://identitytoolkit.googleapis.com/**',route=>route.fulfill({
            contentType:'application/json',body:JSON.stringify({idToken:'test-token'})}));
        // Avoid requiring a real token, but exercise all frontend interactions.
        await page.route('**/account/deletion/options',route=>route.fulfill({contentType:'application/json',body:JSON.stringify({ministries:[{
            id:'sample',name:'Ministerio de teste',members:[{uid:'successor',name:'Integrante de teste'}]}]})}));
        await page.route('**/account/deletion/request',route=>{
            received=route.request().postDataJSON();return route.fulfill({status:202,contentType:'application/json',body:'{"accepted":true}'});
        });
        fs.mkdirSync('build/play-readiness/screenshots',{recursive:true});
        for(const width of [360,1280]) {
            await page.setViewportSize({width,height:900});await page.goto(origin+'/account-deletion');
            assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),true);
            await page.screenshot({path:`build/play-readiness/screenshots/deletion-${width}.png`,fullPage:true});
        }
        await page.getByLabel('E-mail',{exact:true}).fill('synthetic@example.test');
        await page.getByLabel('Senha atual').fill('synthetic-test-password');
        await page.getByRole('button',{name:'Continuar',exact:true}).click();
        await page.getByLabel('Novo administrador: Ministerio de teste').selectOption('successor');
        await page.getByLabel('Entendo que esta acao e permanente.').check();
        await page.getByRole('button',{name:'Excluir minha conta',exact:true}).click();
        await page.waitForFunction(()=>document.getElementById('message').textContent.includes('Solicitacao aceita'));
        assert.deepEqual(received.successors,{sample:'successor'});assert.match(received.receipt,/^[a-f0-9]{64}$/);
        assert.equal(received.password,undefined);
        await page.getByRole('button',{name:'Consultar andamento'}).click();
        await page.waitForFunction(()=>document.getElementById('result').textContent.includes('concluida'));
        assert.deepEqual(errors,[]);console.log('PASS: responsive 360/1280, identity mock, successor, receipt and status; no production writes.');
    } finally {await browser.close();await new Promise(resolve=>server.close(resolve));}
})().catch(error=>{console.error(error);process.exitCode=1;});
