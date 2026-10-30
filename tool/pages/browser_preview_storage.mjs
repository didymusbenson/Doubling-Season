// Isolated temporary Chrome profile only. Never touches a user's browser profile.
import assert from 'node:assert/strict';
import {spawn} from 'node:child_process';
import {createServer} from 'node:http';
import {access, mkdtemp, readFile, rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join, resolve, extname, sep} from 'node:path';
const root = resolve(process.argv[2]);
const prefix = '/Doubling-Season/preview/phone/';
const wait = ms => new Promise(r => setTimeout(r, ms));
async function until(fn) {
  for (let n = 0; n < 240; n++) { try { const r = await fn(); if (r) return r; } catch {} await wait(250); }
  throw new Error('Timed out waiting for preview browser state');
}
let chrome, socket, profile;
const server = createServer(async (req,res) => {
  const path = new URL(req.url,'http://local').pathname;
  if (path === '/seed') { res.end('<title>Storage fixture</title>'); return; }
  if (!path.startsWith(prefix)) { res.writeHead(404).end(); return; }
  const file = resolve(root, decodeURIComponent(path.slice(prefix.length)) || 'index.html');
  if (!file.startsWith(root+sep)) { res.writeHead(403).end(); return; }
  try {
    const types = {'.html':'text/html','.js':'application/javascript','.json':'application/json','.wasm':'application/wasm','.png':'image/png','.ttf':'font/ttf'};
    res.setHeader('Content-Type', types[extname(file)] || 'application/octet-stream');
    res.end(await readFile(file));
  } catch { res.writeHead(404).end(); }
});
try {
  await new Promise(r => server.listen(0,'127.0.0.1',r));
  const origin = `http://127.0.0.1:${server.address().port}`;
  let binary;
  for (const candidate of [process.env.CHROME_EXECUTABLE,'/usr/bin/google-chrome','/usr/bin/google-chrome-stable','/usr/bin/chromium'].filter(Boolean)) {
    try { await access(candidate); binary=candidate; break; } catch {}
  }
  assert(binary,'Chrome is required');
  profile = await mkdtemp(join(tmpdir(),'phone-preview-storage-'));
  chrome = spawn(binary,['--headless=new','--remote-debugging-port=0',`--user-data-dir=${profile}`,'--no-first-run','--no-default-browser-check','--disable-dev-shm-usage','about:blank']);
  chrome.stdout.resume(); chrome.stderr.resume();
  const port = await until(async () => (await readFile(join(profile,'DevToolsActivePort'),'utf8')).split('\n')[0]);
  const targets = await (await fetch(`http://127.0.0.1:${port}/json`)).json();
  socket = new WebSocket(targets.find(t=>t.type==='page').webSocketDebuggerUrl);
  await new Promise((r,j)=>{socket.addEventListener('open',r,{once:true});socket.addEventListener('error',j,{once:true});});
  let next=0; const pending=new Map();
  socket.addEventListener('message',event=>{const m=JSON.parse(event.data);if(m.id){const p=pending.get(m.id);pending.delete(m.id);if(p){clearTimeout(p.timer);m.error?p.reject(new Error(JSON.stringify(m.error))):p.resolve(m.result);}}});
  const send=(method,params={})=>new Promise((resolve,reject)=>{const id=++next;const timer=setTimeout(()=>{pending.delete(id);reject(new Error(method+' timed out'));},30000);pending.set(id,{resolve,reject,timer});socket.send(JSON.stringify({id,method,params}));});
  const evaluate=async expression=>{const r=await send('Runtime.evaluate',{expression,awaitPromise:true,returnByValue:true});assert(!r.exceptionDetails,JSON.stringify(r.exceptionDetails));return r.result.value;};
  await send('Page.enable'); await send('Runtime.enable');
  await send('Emulation.setDeviceMetricsOverride',{width:1133,height:744,deviceScaleFactor:1,mobile:false});
  await send('Page.navigate',{url:origin+'/seed'});
  await until(()=>evaluate("location.pathname === '/seed'"));
  const production=['tripling_season_tablet_aggregate_v1','tripling_season_tablet_aggregate_v1_previous','tripling_season_tablet_aggregate_v1_recovery','tripling_season_tablet_catalog_v1','tripling_table_media_v1'];
  await evaluate(`(async()=>{for(const name of ${JSON.stringify(production)}){await new Promise((resolve,reject)=>{const r=indexedDB.open(name,1);r.onupgradeneeded=()=>r.result.createObjectStore('sentinel');r.onerror=()=>reject(r.error);r.onsuccess=()=>{const db=r.result;const t=db.transaction('sentinel','readwrite');t.objectStore('sentinel').put(name,'preserve');t.oncomplete=()=>{db.close();resolve();};t.onerror=()=>reject(t.error);};});}localStorage.setItem('flutter.tablet_support_owned_v1','["production-sentinel"]');localStorage.setItem('flutter.tablet_support_heart_color','12345');return true;})()`);
  const snapshot=`(async()=>{const result={};for(const name of ${JSON.stringify(production)}){result[name]=await new Promise((resolve,reject)=>{const r=indexedDB.open(name);r.onerror=()=>reject(r.error);r.onsuccess=()=>{const db=r.result;const names=[...db.objectStoreNames];if(names.length!==1||names[0]!=='sentinel'){db.close();reject(new Error('Production database changed'));return;}const t=db.transaction('sentinel');const q=t.objectStore('sentinel').get('preserve');q.onsuccess=()=>{const v=q.result;db.close();resolve(v);};q.onerror=()=>reject(q.error);};});}result.prefs=[localStorage.getItem('flutter.tablet_support_owned_v1'),localStorage.getItem('flutter.tablet_support_heart_color')];return result;})()`;
  const before=await evaluate(snapshot);
  await send('Page.navigate',{url:origin+prefix});
  const ready=`(async()=>{const names=(await indexedDB.databases()).map(x=>x.name);return ['phone_preview_v1__tripling_season_tablet_aggregate_v1','phone_preview_v1__tripling_season_tablet_aggregate_v1_previous','phone_preview_v1__tripling_season_tablet_aggregate_v1_recovery','phone_preview_v1__tripling_season_tablet_catalog_v1'].every(n=>names.includes(n));})()`;
  await until(()=>evaluate(ready));
  await wait(1500);
  assert.deepEqual(await evaluate(snapshot),before,'Preview boot changed production storage');
  await send('Page.reload',{ignoreCache:true});
  await until(()=>evaluate(ready)); await wait(1500);
  assert.deepEqual(await evaluate(snapshot),before,'Preview reload changed production storage');
  const registrations=await evaluate("(async()=>('serviceWorker' in navigator ? (await navigator.serviceWorker.getRegistrations()).map(x=>x.scope) : []))()");
  assert.equal(registrations.length,0,'Fresh preview registered an offline worker');
  console.log(JSON.stringify({status:'passed',productionDatabasesPreserved:production,productionPreferencesPreserved:true,previewReloaded:true}));
} finally {
  socket?.close(); chrome?.kill('SIGTERM');
  await new Promise(r=>server.close(r));
  if(profile){await wait(500);await rm(profile,{recursive:true,force:true});}
}
