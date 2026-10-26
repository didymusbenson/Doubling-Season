#!/usr/bin/env node
/** Real release-UI smoke using runner-provided Chrome + Node built-ins only.
 * No app state injection, dependencies, external hosting, or persistent profile.
 * All app clicks use current accessibility names and CDP-resolved rendered bounds.
 * The sole DOM click activates Flutter's offscreen assistive-technology opt-in.
 */
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { createHash } from 'node:crypto';
import { createServer } from 'node:http';
import { access, mkdir, mkdtemp, readFile, rm, stat, writeFile } from 'node:fs/promises';
import { constants } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, extname, join, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';

const app = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const build = resolve(process.argv[2] || join(app, 'build/web'));
const output = resolve(process.argv[3] || join(app, 'build/browser-smoke'));
const prefix = '/Doubling-Season/tablet/';
const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));
const evidence = {
  started: new Date().toISOString(), status: 'running',
  source: { sha: process.env.GITHUB_SHA || 'local-uncommitted', ref: process.env.GITHUB_REF, run: process.env.GITHUB_RUN_ID },
  viewport: { width: 1133, height: 744, deviceScaleFactor: 1 },
  build, steps: [], console: [], exceptions: [], networkFailures: [], images: [],
};
let chrome, server, profile, cdp;
let chromeLog = '';
let expectedScuteArtwork, expectedScuteArtist;
await mkdir(output, { recursive: true });
function log(message, data = {}) {
  const entry = { at: new Date().toISOString(), message, ...data };
  evidence.steps.push(entry);
  console.log(JSON.stringify(entry));
}
async function until(description, action, timeout = 30000) {
  const end = Date.now() + timeout;
  let last;
  while (Date.now() < end) {
    try { const value = await action(); if (value) return value; } catch (error) { last = error; }
    await sleep(150);
  }
  throw new Error(`Timed out: ${description}${last ? `; last observation: ${last.message}` : ''}`);
}
class CDP {
  constructor(socket) {
    this.socket = socket; this.id = 0; this.pending = new Map(); this.listeners = new Map();
    socket.addEventListener('message', event => {
      const message = JSON.parse(event.data);
      if (message.id) {
        const request = this.pending.get(message.id);
        if (!request) return;
        clearTimeout(request.timer); this.pending.delete(message.id);
        if (message.error) request.reject(new Error(JSON.stringify(message.error)));
        else request.resolve(message.result);
      } else for (const listener of this.listeners.get(message.method) || []) listener(message.params);
    });
    socket.addEventListener('close', () => {
      for (const request of this.pending.values()) { clearTimeout(request.timer); request.reject(new Error('Chrome CDP connection closed')); }
      this.pending.clear();
    });
  }
  on(method, listener) { this.listeners.set(method, [...(this.listeners.get(method) || []), listener]); }
  send(method, params = {}) {
    const id = ++this.id;
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => { this.pending.delete(id); reject(new Error(`CDP timeout: ${method}`)); }, 15000);
      this.pending.set(id, { resolve, reject, timer });
      this.socket.send(JSON.stringify({ id, method, params }));
    });
  }
  async evaluate(expression) {
    const result = await this.send('Runtime.evaluate', { expression, returnByValue: true, awaitPromise: true });
    if (result.exceptionDetails) throw new Error(result.exceptionDetails.text);
    return result.result.value;
  }
}
async function semantics() {
  const { nodes } = await cdp.send('Accessibility.getFullAXTree');
  return nodes.filter(node => !node.ignored && node.name?.value).map(node => ({
    id: node.nodeId, backend: node.backendDOMNodeId, role: node.role?.value,
    name: node.name.value, value: node.value?.value,
    disabled: node.properties?.some(property => property.name === 'disabled' && property.value?.value === true),
    checked: node.properties?.find(property => property.name === 'checked')?.value?.value,
  }));
}
async function bounds(node) {
  if (!node.backend) return null;
  try {
    const { model } = await cdp.send('DOM.getBoxModel', { backendNodeId: node.backend });
    const points = model.border;
    const xs = points.filter((_, index) => index % 2 === 0), ys = points.filter((_, index) => index % 2 === 1);
    const rect = { x: Math.min(...xs), y: Math.min(...ys), width: Math.max(...xs) - Math.min(...xs), height: Math.max(...ys) - Math.min(...ys) };
    if (rect.width <= 0 || rect.height <= 0 || rect.x + rect.width <= 0 || rect.y + rect.height <= 0 || rect.x >= evidence.viewport.width || rect.y >= evidence.viewport.height) return null;
    return rect;
  } catch { return null; }
}
function matches(node, name, startsWith, contains) { return contains ? node.name.includes(name) : startsWith ? node.name.startsWith(name) : node.name === name; }
async function find(name, { startsWith = false, contains = false, role, timeout = 30000 } = {}) {
  return until(`visible semantic control ${JSON.stringify(name)}`, async () => {
    const nodes = (await semantics()).filter(node => matches(node, name, startsWith, contains) && !node.disabled && (!role || node.role === role));
    const candidates = [];
    for (const node of nodes) { const rect = await bounds(node); if (rect) candidates.push({ ...node, rect }); }
    // A full-table dismissal barrier can share the header button's name.
    // Prefer the smallest actionable visible target, never its giant ancestor.
    candidates.sort((a, b) => Number(b.role === 'button') - Number(a.role === 'button') ||
      a.rect.width * a.rect.height - b.rect.width * b.rect.height);
    if (candidates.length) return candidates[0];
    return null;
  }, timeout);
}
async function hitTarget(node) {
  const { object } = await cdp.send('DOM.resolveNode', { backendNodeId: node.backend });
  try {
    const { result } = await cdp.send('Runtime.callFunctionOn', {
      objectId: object.objectId, returnByValue: true,
      arguments: [{ value: node.rect.x + node.rect.width / 2 }, { value: node.rect.y + node.rect.height / 2 }],
      functionDeclaration: `function(x, y) {
        let hit = document.elementFromPoint(x, y);
        while (hit && hit.shadowRoot) { const inner = hit.shadowRoot.elementFromPoint(x, y); if (!inner || inner === hit) break; hit = inner; }
        const describe = element => {
          if (!element) return null;
          const style = getComputedStyle(element), rect = element.getBoundingClientRect();
          return { tag: element.tagName, id: element.id, role: element.getAttribute('role'),
            label: element.getAttribute('aria-label'), text: element.textContent?.slice(0, 140),
            zIndex: style.zIndex, pointerEvents: style.pointerEvents, transform: style.transform,
            rect: { x: rect.x, y: rect.y, width: rect.width, height: rect.height } };
        };
        const chain = element => { const result = []; for (let i = 0; element && i < 8; i++, element = element.parentElement) result.push(describe(element)); return result; };
        const actionSelector = '[role="button"],[role="switch"],[role="checkbox"],[role="textbox"],[flt-tappable]';
        const selectedAction = this.closest(actionSelector), hitAction = hit?.closest(actionSelector);
        return { tag: hit?.tagName, label: hit?.getAttribute('aria-label'), text: hit?.textContent?.slice(0, 220),
          sameAction: !!selectedAction && selectedAction === hitAction,
          selectedContainsHit: !!hit && (this === hit || this.contains(hit)), hitContainsSelected: !!hit && hit.contains(this),
          selectedChain: chain(this), hitChain: chain(hit), atPoint: document.elementsFromPoint(x, y).slice(0, 10).map(describe) };
      }`,
    });
    return result.value;
  } finally { await cdp.send('Runtime.releaseObject', { objectId: object.objectId }); }
}
async function installInputObservation() {
  await cdp.evaluate(`(() => {
    window.__tableSmokeInputEvents = [];
    for (const type of ['pointerdown', 'pointerup', 'pointercancel', 'mousedown', 'mouseup', 'click', 'touchstart', 'touchend', 'contextmenu']) {
      document.addEventListener(type, event => {
        const target = event.composedPath()[0];
        window.__tableSmokeInputEvents.push({ at: performance.now(), type, pointerType: event.pointerType,
          buttons: event.buttons, tag: target?.tagName, tappable: target?.hasAttribute?.('flt-tappable'),
          label: target?.getAttribute?.('aria-label'), text: target?.textContent?.slice(0, 220), x: event.clientX, y: event.clientY });
      }, true);
    }
    return true;
  })()`);
}
async function dayNightState() {
  const node = (await semantics()).find(node => node.role === 'button' && node.name.startsWith('Day/Night:'));
  return node?.name.match(/^Day\/Night: (\w+)/)?.[1] || 'missing';
}
async function restoreNight() {
  for (let index = 0; index < 3 && await dayNightState() !== 'night'; index++) {
    await click('Day/Night:', { startsWith: true, role: 'button' });
    await sleep(250);
  }
  assert.equal(await dayNightState(), 'night', 'Could not establish Night through ordinary taps.');
}
async function diagnoseHold(input) {
  await restoreNight();
  const node = await find('Day/Night: night.', { startsWith: true, role: 'button' });
  const x = node.rect.x + node.rect.width / 2, y = node.rect.y + node.rect.height / 2;
  const record = { input, before: await dayNightState(), rect: node.rect, hit: await hitTarget(node) };
  const eventOffset = await cdp.evaluate('window.__tableSmokeInputEvents.length');
  const started = Date.now();
  log('begin observed long press', record);
  if (input === 'mouse') {
    await cdp.send('Input.dispatchMouseEvent', { type: 'mouseMoved', x, y });
    await cdp.send('Input.dispatchMouseEvent', { type: 'mousePressed', x, y, button: 'left', buttons: 1, clickCount: 1 });
  } else {
    await cdp.send('Emulation.setTouchEmulationEnabled', { enabled: true, maxTouchPoints: 1 });
    await cdp.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ x, y, id: 0, radiusX: 1, radiusY: 1, force: 1 }] });
  }
  await sleep(750);
  record.pressedAt750ms = await dayNightState();
  record.firstObservationElapsedMs = Date.now() - started;
  await capture(`04-${input}-hold-750ms-still-pressed`);
  await sleep(350);
  record.pressedAtLeast1100ms = await dayNightState();
  record.secondObservationElapsedMs = Date.now() - started;
  await capture(`04-${input}-hold-1100ms-still-pressed`);
  record.clearObservedWhileHeld = await until('clear during held pointer (3s budget)',
    async () => await dayNightState() === 'neither', Math.max(1, 3000 - (Date.now() - started)))
    .catch(error => { record.heldClearFailure = error.message; return false; });
  record.clearObservationElapsedMs = Date.now() - started;
  if (record.clearObservedWhileHeld && record.pressedAtLeast1100ms !== 'neither') {
    await capture(`04-${input}-hold-recognized-still-pressed`);
  }
  if (input === 'mouse') {
    await cdp.send('Input.dispatchMouseEvent', { type: 'mouseReleased', x, y, button: 'left', buttons: 0, clickCount: 1 });
  } else {
    await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
    await cdp.send('Emulation.setTouchEmulationEnabled', { enabled: false });
  }
  await sleep(500);
  record.afterRelease = await dayNightState();
  record.events = await cdp.evaluate(`window.__tableSmokeInputEvents.slice(${eventOffset})`);
  evidence.holds ||= [];
  evidence.holds.push(record);
  log('observed hold outcome', record);
  await capture(`04-${input}-hold-after-release`);
  await click('Game controls');
  const hubChoices = ['Dice', 'History', 'New game', 'Archives', 'Board wipes', 'Settings'];
  for (const label of hubChoices) {
    await find(label, { role: 'button' });
    assert.equal((await semantics()).filter(node => node.role === 'button' && node.name === label).length, 1, `Hub repeats ${label}`);
  }
  await capture(`04-${input}-focused-table-hub`);
  await click('History', { role: 'button' });
  assert(!(await semantics()).some(node => node.role === 'button' && hubChoices.includes(node.name)), 'Focused history still has sibling navigation tabs.');
  await capture(`04-${input}-hold-chronological-history`);
  await click('Back', { role: 'button' });
  await find('Archives', { role: 'button' });
  await click('Close workspace');
}
async function click(name, options = {}) {
  let node = await find(name, options);
  let target = await hitTarget(node);
  if (!target.sameAction) {
    evidence.unmatchedTargets ||= [];
    evidence.unmatchedTargets.push({ name, at: new Date().toISOString(), node, target });
    await until(`current DOM hit target for ${JSON.stringify(name)}`, async () => {
      node = await find(name, options);
      target = await hitTarget(node);
      evidence.unmatchedTargets.push({ name, at: new Date().toISOString(), node, target });
      return target.sameAction;
    }, 3000);
  }
  const x = node.rect.x + node.rect.width / 2, y = node.rect.y + node.rect.height / 2;
  assert(x >= 0 && y >= 0 && x < evidence.viewport.width && y < evidence.viewport.height, `Control center is clipped: ${name}`);
  log(options.hold ? 'pointer hold from rendered semantic bounds' : 'pointer click from rendered semantic bounds', { name: node.name, role: node.role, rect: node.rect, hit: target });
  await cdp.send('Input.dispatchMouseEvent', { type: 'mouseMoved', x, y });
  await cdp.send('Input.dispatchMouseEvent', { type: 'mousePressed', x, y, button: 'left', buttons: 1, clickCount: 1 });
  await sleep(options.hold || 40);
  await cdp.send('Input.dispatchMouseEvent', { type: 'mouseReleased', x, y, button: 'left', buttons: 0, clickCount: 1 });
  await sleep(120);
}
async function typeSoftwareText(text) {
  let symbols = false;
  for (const character of text) {
    const letter = /^[a-z]$/i.test(character);
    if (letter === symbols) {
      await click(symbols ? 'ABC' : '123', { role: 'button' });
      symbols = !symbols;
    }
    if (letter && character !== character.toLowerCase()) await click('Shift', { role: 'button' });
    await click(character, { role: 'button' });
  }
}
async function selected(name) {
  return until(`selected ${name}`, async () => (await semantics()).some(node => node.name === name && ['true', true].includes(node.checked)));
}
async function capture(name) {
  const shot = await cdp.send('Page.captureScreenshot', { format: 'png', captureBeyondViewport: false });
  await writeFile(join(output, `${name}.png`), Buffer.from(shot.data, 'base64'));
  await writeFile(join(output, `${name}.semantics.json`), JSON.stringify(await semantics(), null, 2));
  log('captured rendered UI and semantic evidence', { name });
}
async function enableSemantics() {
  await until('Flutter accessibility bootstrap', async () => cdp.evaluate(`(() => {
    const all = [];
    function visit(root) { for (const element of root.querySelectorAll('*')) { all.push(element); if (element.shadowRoot) visit(element.shadowRoot); } }
    visit(document);
    const placeholder = all.find(element => element.tagName.toLowerCase() === 'flt-semantics-placeholder');
    if (placeholder) { placeholder.click(); return true; }
    return all.some(element => element.tagName.toLowerCase() === 'flt-semantics');
  })()`), 90000);
  log('enabled Flutter accessibility through its AT placeholder');
}
try {
  assert.equal(typeof WebSocket, 'function', `Installed Node ${process.version} lacks global WebSocket; runner needs a supported preinstalled Node runtime. No package installation attempted.`);
  const candidates = [process.env.CHROME_EXECUTABLE, '/usr/bin/google-chrome', '/usr/bin/google-chrome-stable', '/usr/bin/chromium', '/usr/bin/chromium-browser'].filter(Boolean);
  let binary;
  for (const candidate of candidates) { try { await access(candidate, constants.X_OK); binary = candidate; break; } catch {} }
  assert(binary, 'No runner-provided Chrome binary found. No browser installation attempted.');
  evidence.node = process.version; evidence.chromeBinary = binary;
  evidence.buildHashes = {};
  for (const file of ['index.html', 'flutter_bootstrap.js', 'main.dart.js']) {
    evidence.buildHashes[file] = createHash('sha256').update(await readFile(join(build, file))).digest('hex');
  }
  const tokens = JSON.parse(await readFile(join(build, 'assets/packages/doubling_season/assets/token_database.json'), 'utf8'));
  const scutePrinting = tokens.find(token => token.name === 'Scute Swarm')?.artwork?.[0];
  expectedScuteArtwork = scutePrinting?.url;
  expectedScuteArtist = scutePrinting?.artist;
  assert(expectedScuteArtwork, 'Bundled catalog lacks the expected Scute Swarm artwork fixture.');
  evidence.expectedArtwork = expectedScuteArtwork;
  evidence.expectedArtist = expectedScuteArtist;
  assert((await readFile(join(build, 'index.html'), 'utf8')).includes(`<base href="${prefix}">`), 'Build must use the existing tablet release base href.');
  const mime = { '.html': 'text/html', '.js': 'text/javascript', '.json': 'application/json', '.wasm': 'application/wasm', '.png': 'image/png', '.jpg': 'image/jpeg', '.ttf': 'font/ttf', '.otf': 'font/otf', '.woff2': 'font/woff2' };
  server = createServer(async (request, response) => {
    try {
      const pathname = decodeURIComponent(new URL(request.url, 'http://localhost').pathname);
      if (!pathname.startsWith(prefix)) { response.writeHead(404).end(); return; }
      const path = resolve(build, pathname.slice(prefix.length) || 'index.html');
      if (path !== build && !path.startsWith(build + sep)) { response.writeHead(403).end(); return; }
      if (!(await stat(path)).isFile()) { response.writeHead(404).end(); return; }
      response.writeHead(200, { 'content-type': mime[extname(path)] || 'application/octet-stream', 'cache-control': 'no-store' });
      response.end(await readFile(path));
    } catch { response.writeHead(404).end(); }
  });
  await new Promise((resolve, reject) => { server.once('error', reject); server.listen(0, '127.0.0.1', resolve); });
  const url = `http://127.0.0.1:${server.address().port}${prefix}`;
  evidence.url = url;
  profile = await mkdtemp(join(tmpdir(), 'tripling-table-ci-chrome-'));
  chrome = spawn(binary, ['--headless=new', '--remote-debugging-port=0', `--user-data-dir=${profile}`, '--no-first-run', '--no-default-browser-check', '--disable-dev-shm-usage', 'about:blank'], { stdio: ['ignore', 'pipe', 'pipe'] });
  chrome.stdout.on('data', data => { chromeLog += data; });
  chrome.stderr.on('data', data => { chromeLog += data; });
  chrome.on('error', error => { chromeLog += error.stack; });
  const port = await until('Chrome DevToolsActivePort', async () => {
    if (chrome.exitCode !== null) throw new Error(`Chrome exited ${chrome.exitCode}: ${chromeLog.slice(-2000)}`);
    return (await readFile(join(profile, 'DevToolsActivePort'), 'utf8')).split('\n')[0];
  }, 30000);
  const targets = await (await fetch(`http://127.0.0.1:${port}/json/list`)).json();
  const target = targets.find(target => target.type === 'page');
  assert(target?.webSocketDebuggerUrl, 'Chrome did not expose an initial page target.');
  const socket = new WebSocket(target.webSocketDebuggerUrl);
  await new Promise((resolve, reject) => { socket.addEventListener('open', resolve, { once: true }); socket.addEventListener('error', reject, { once: true }); });
  cdp = new CDP(socket);
  cdp.on('Runtime.consoleAPICalled', event => evidence.console.push({ type: event.type, text: event.args.map(arg => arg.value ?? arg.description).join(' ') }));
  cdp.on('Runtime.exceptionThrown', event => evidence.exceptions.push(event.exceptionDetails));
  cdp.on('Network.loadingFailed', event => evidence.networkFailures.push(event));
  cdp.on('Network.responseReceived', event => { if (event.response.mimeType.startsWith('image/')) evidence.images.push({ requestId: event.requestId, url: event.response.url, status: event.response.status, mime: event.response.mimeType }); });
  cdp.on('Network.loadingFinished', event => { const image = evidence.images.find(image => image.requestId === event.requestId); if (image) { image.finished = true; image.encodedBytes = event.encodedDataLength; } });
  await Promise.all(['Page.enable', 'Runtime.enable', 'Network.enable', 'Accessibility.enable'].map(method => cdp.send(method)));
  evidence.browser = await cdp.send('Browser.getVersion');
  await cdp.send('Emulation.setDeviceMetricsOverride', { ...evidence.viewport, mobile: false });
  await cdp.send('Page.navigate', { url });
  await enableSemantics();
  await find('Player 1, player details', { timeout: 90000 });
  await capture('01-initial-four-seat-table');

  await click('Player 1, player details');
  await click('Player name. Current value:', { startsWith: true });
  await click('Select all');
  await click('q', { role: 'button' });
  await find('Player name. Current value: q');
  await click('a', { role: 'button' });
  await find('Player name. Current value: qa');
  await capture('02-player-keyboard-qa');
  await click('Done');
  await click('Close workspace');
  await find('qa, player details');
  await cdp.send('Page.reload', { ignoreCache: true });
  await enableSemantics();
  await find('qa, player details', { timeout: 90000 });
  await installInputObservation();
  await capture('03-name-persisted-after-reload');
  log('PASS software q→a typing, Done, durable rename and reload');

  // Partner setup requires no naming, and its stable ledger is not erased by Off.
  await click('qa, player details');
  assert(!(await semantics()).some(node => node.name.includes('Commander name')), 'Player setup still requires commander naming.');
  await click('Has partner');
  await selected('Has partner');
  await find('Has partner', { role: 'switch' });
  await sleep(300); // Capture the committed switch after its visual transition.
  await capture('03b-player-partner-enabled');
  await click('Close workspace');
  await click('qa, commander damage ', { startsWith: true, role: 'button' });
  await click('Increase Partner #2 damage from qa; lose one life', { startsWith: true, role: 'button' });
  await find('qa · 39 life', { contains: true });
  await capture('03c-focused-partner-damage');
  await click('Close workspace');
  await click('qa, player details');
  await click('Has partner');
  await find('Set this partner’s damage to zero for everyone first.', { contains: true });
  await until('guarded partner remains enabled', async () => (await semantics()).some(node =>
    node.role === 'switch' && node.name.startsWith('Has partner') && ['true', true].includes(node.checked)));
  assert(!(await semantics()).some(node => node.name.includes('Bad state:')), 'Expected partner guard surfaced as a global application error.');
  await capture('03d-partner-off-guarded');
  await click('Close workspace');
  await click('qa, commander damage ', { startsWith: true, role: 'button' });
  await click('Correct Partner #2 damage from qa; life unchanged');
  await click('Set damage total. Current value:', { startsWith: true });
  await click('Select all');
  await click('0', { role: 'button' });
  await click('Done');
  await click('Correct ledger only');
  await find('qa · 39 life', { contains: true });
  await click('Back');
  await capture('03e-partner-corrected-without-life-change');
  await click('Close workspace');
  await click('qa, player details');
  await click('Has partner');
  await click('Close workspace');
  await cdp.send('Page.reload', { ignoreCache: true });
  await enableSemantics();
  await find('qa, player details', { timeout: 90000 });
  await click('qa, commander damage ', { startsWith: true, role: 'button' });
  assert(!(await semantics()).some(node => node.name.includes('Increase Partner #2 damage from qa')), 'Inactive partner remained visible after reload.');
  await capture('03f-partner-off-persisted');
  await click('Close workspace');
  await installInputObservation();
  log('PASS focused partner setup, separate damage, guarded Off, ledger-only correction and persisted deactivation');


  await click('Day/Night: neither.', { startsWith: true });
  await find('Day/Night: day.', { startsWith: true });
  await click('Day/Night: day.', { startsWith: true });
  await find('Day/Night: night.', { startsWith: true });
  await capture('04-direct-day-night');
  await diagnoseHold('mouse');
  await diagnoseHold('touch');
  await click('Roll dice', { startsWith: true, role: 'button' });
  await find('D6 quantity: 1');
  await capture('05a-dice-selector-outlines');
  await click('Roll 1 die', { role: 'button' });
  async function verifyDiceResults(expected) {
    const rows = new Map();
    for (const node of await semantics()) {
      const match = node.name.match(/^D(4|6|8|10|12|20) result (\d+): (\d+)$/);
      if (!match) continue;
      const [, sidesText, indexText, valueText] = match;
      const sides = Number(sidesText), index = Number(indexText), value = Number(valueText);
      assert(value >= 1 && value <= sides, `Out-of-range D${sides} result ${value}`);
      const key = `${sides}:${index}`;
      if (rows.has(key)) assert.equal(rows.get(key).value, value, 'Duplicate semantic result disagrees.');
      rows.set(key, { sides, index, value });
    }
    for (const [sides, count] of Object.entries(expected)) {
      assert.equal([...rows.values()].filter(row => row.sides === Number(sides)).length, count, `Wrong D${sides} count`);
    }
    assert.equal(rows.size, Object.values(expected).reduce((sum, count) => sum + count, 0), 'Unexpected extra result');
    const summary = await find('Total:', { startsWith: true });
    const total = Number(summary.name.match(/^Total:\s*(\d+)/)?.[1]);
    assert.equal(total, [...rows.values()].reduce((sum, row) => sum + row.value, 0), 'Dice total differs from individual values.');
  }
  await find('Roll again', { role: 'button' });
  await verifyDiceResults({ 6: 1 });
  await capture('05-direct-dice-results');
  await click('Back', { role: 'button' });
  await find('D6 quantity: 1');
  await click('Increase d4', { startsWith: true, role: 'button' });
  await click('Increase d4', { startsWith: true, role: 'button' });
  await click('Increase d20', { startsWith: true, role: 'button' });
  await find('D4 quantity: 2');
  await capture('05b-dice-mixed-selection');
  await click('Roll 4 dice', { role: 'button' });
  await find('Roll again', { role: 'button' });
  await verifyDiceResults({ 4: 2, 6: 1, 20: 1 });
  await capture('05c-dice-mixed-results');
  await click('Roll again', { role: 'button' });
  await verifyDiceResults({ 4: 2, 6: 1, 20: 1 });
  await click('Back', { role: 'button' });
  await find('D4 quantity: 2');
  await find('D20 quantity: 1');
  for (const sides of [4, 4, 6, 20]) await click(`Decrease d${sides}`, { startsWith: true, role: 'button' });
  await find('D6 quantity: 0');
  await click('Roll dice', { role: 'button' });
  await find('Select at least one die.', { contains: true });
  await verifyDiceResults({});
  await capture('05d-dice-empty-selection');
  await click('Close workspace');
  log('PASS direct Day/Night and outlined Dice selection, individual results, sums, reroll, Back preservation and empty selection; hold outcomes recorded separately');

  await click('qa, add token');
  await click('Search tokens, abilities, type, or P/T. Current value:', { contains: true, role: 'button' });
  for (const letter of 'scute') await click(letter, { role: 'button' });
  await click('Done');
  await click('Scute Swarm', { startsWith: true });
  await find('Create tokens');
  await until('real catalog artwork response', async () => evidence.images.some(image => image.status === 200 && image.finished && image.url === expectedScuteArtwork), 30000);
  const loadedArt = evidence.images.find(image => image.url === expectedScuteArtwork && image.finished);
  const imageBody = await cdp.send('Network.getResponseBody', { requestId: loadedArt.requestId });
  const imageBytes = Buffer.from(imageBody.body, imageBody.base64Encoded ? 'base64' : 'utf8');
  assert(imageBytes.length > 0, 'Catalog artwork response was empty.');
  loadedArt.bytes = imageBytes.length;
  loadedArt.sha256 = createHash('sha256').update(imageBytes).digest('hex');
  await sleep(750); // Allow the downloaded image's decode and paint before capture.
  await capture('06-scute-catalog-real-artwork');
  await click('Create tokens');
  await find('qa, player details');
  await capture('07-populated-token-table');
  log('PASS real catalog token creation with downloaded artwork evidence');

  await click('qa, Scute Swarm, Name', { startsWith: true, role: 'button' });
  await find('qa, Scute Swarm, Choose artwork', { contains: true, role: 'button' });
  await capture('08-expanded-token-full-art');
  await click('qa, Scute Swarm, Choose artwork', { contains: true, role: 'button' });
  await find('Artwork image URL. Current value:', { contains: true, role: 'button' });
  await capture('09-current-artwork-editor');
  await click('Artwork image URL. Current value:', { contains: true, role: 'button' });
  await typeSoftwareText(expectedScuteArtwork);
  await find(`Artwork image URL. Current value: ${expectedScuteArtwork}`, { contains: true, role: 'button' });
  await capture('10-artwork-url-keyboard-draft');
  await click('Done');
  await click('Preview image URL');
  await find('Preview — not saved', { contains: true });
  await find(expectedScuteArtist, { contains: true });
  await find('Use this artwork', { role: 'button' });
  await capture('11-known-printing-preview-not-saved');
  await click('Use this artwork', { role: 'button' });
  await find('Current artwork', { contains: true });
  assert(!(await semantics()).some(node => node.name.includes('Preview — not saved')), 'Apply left an unsaved preview visible.');
  await find(expectedScuteArtist, { contains: true });
  await capture('12-artwork-applied-with-credit');
  await click('Fadeout');
  await selected('Fadeout');
  await click('Close workspace');
  await capture('13-expanded-token-fadeout');
  await cdp.send('Page.reload', { ignoreCache: true });
  await enableSemantics();
  await find('qa, Scute Swarm, Name', { startsWith: true, role: 'button', timeout: 90000 });
  await capture('14-reloaded-collapsed-token-fadeout');
  await click('qa, Scute Swarm, Name', { startsWith: true, role: 'button' });
  await find('qa, Scute Swarm, Choose artwork', { contains: true, role: 'button' });
  await capture('15-reloaded-expanded-token-fadeout');
  await click('qa, Scute Swarm, Choose artwork', { contains: true, role: 'button' });
  await selected('Fadeout');
  await find('Current artwork', { contains: true });
  await find(expectedScuteArtist, { contains: true });
  await capture('16-reloaded-artwork-editor-credit-and-mode');
  await click('Close workspace');
  log('PASS real artwork editor URL typing, staged preview, Apply, credit and Fadeout persistence across reload');

  // With semantics enabled, Flutter3.41.2 buffers tappable pointerdown200ms
  // before the framework's500ms recognizer; durable publication adds latency.
  // Keep the750ms observation, but assert actual recognized clear + no trailing
  // change after release, not a brittle wall-clock threshold. Physical timing
  // remains a separate acceptance gate.
  assert(evidence.holds.every(hold => hold.clearObservedWhileHeld && hold.afterRelease === 'neither'), 'Observed mouse/touch hold did not clear and remain Neither; inspect hold snapshots, DOM event timeline and chronological history.');
  assert.equal(evidence.exceptions.length, 0, 'Unhandled browser runtime exceptions occurred; inspect evidence.json.');
  evidence.status = 'passed';
} catch (error) {
  evidence.status = 'failed'; evidence.failure = error.stack || String(error);
  console.error(evidence.failure);
  if (cdp) { try { await capture('failure'); } catch (captureError) { evidence.captureFailure = String(captureError); } }
  process.exitCode = 1;
} finally {
  evidence.finished = new Date().toISOString();
  await writeFile(join(output, 'evidence.json'), JSON.stringify(evidence, null, 2));
  await writeFile(join(output, 'chrome.log'), chromeLog);
  cdp?.socket.close();
  if (chrome && chrome.exitCode === null) {
    chrome.kill('SIGTERM');
    await Promise.race([new Promise(resolve => chrome.once('exit', resolve)), sleep(5000)]);
    if (chrome.exitCode === null) chrome.kill('SIGKILL');
  }
  if (server) await new Promise(resolve => server.close(resolve));
  if (profile) await rm(profile, { recursive: true, force: true, maxRetries: 5, retryDelay: 200 });
}
