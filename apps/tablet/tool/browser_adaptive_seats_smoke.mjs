#!/usr/bin/env node
/** Real release-UI smoke using runner-provided Chrome + Node built-ins only.
 * No app state injection, dependencies, external hosting, or persistent profile.
 * All app clicks use current accessibility names and CDP-resolved rendered bounds.
 * The sole DOM click activates Flutter's offscreen assistive-technology opt-in.
 * Usage: node tool/browser_adaptive_seats_smoke.mjs [build/web] [evidence-dir]
 * Serves the built index.html base href, including the canonical Pages path.
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
const output = resolve(process.argv[3] || join(app, 'build/adaptive-browser-smoke'));
let prefix;
const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));
const evidence = {
  started: new Date().toISOString(), status: 'running',
  source: { sha: process.env.GITHUB_SHA || 'local-uncommitted', ref: process.env.GITHUB_REF, run: process.env.GITHUB_RUN_ID },
  viewport: { width: 1133, height: 744, deviceScaleFactor: 1 },
  build, steps: [], console: [], exceptions: [], networkFailures: [], images: [],
};
let chrome, server, profile, cdp;
let chromeLog = '';
await mkdir(output, { recursive: true });
function buildPrefix(indexHtml) {
  const match = indexHtml.match(/<base\s+href=["']([^"']+)["']\s*\/?\s*>/i);
  assert(match, 'Built index.html has no base href.');
  assert(/^\/(?:[a-z0-9_-]+\/)*$/i.test(match[1]),
    'Build base href must be an absolute directory path, such as / or /Doubling-Season/tablet/.');
  return match[1];
}
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
    expanded: node.properties?.find(property => property.name === 'expanded')?.value?.value,
    selected: node.properties?.find(property => property.name === 'selected')?.value?.value,
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
  } catch {
    // Chrome's StaticText backend is a text node, for which getBoxModel is
    // unsupported. Read its painted parent only for text assertions; action
    // targets keep the strict DOM box/hit-target route above.
    if (node.role !== 'StaticText') return null;
    const { object } = await cdp.send('DOM.resolveNode', { backendNodeId: node.backend });
    try {
      const { result } = await cdp.send('Runtime.callFunctionOn', {
        objectId: object.objectId, returnByValue: true,
        functionDeclaration: `function() {
          const element = this.nodeType === Node.ELEMENT_NODE ? this : this.parentElement;
          if (!element) return null;
          const rect = element.getBoundingClientRect();
          return { x: rect.x, y: rect.y, width: rect.width, height: rect.height };
        }`,
      });
      const rect = result.value;
      return rect && rect.width > 0 && rect.height > 0 && rect.x < evidence.viewport.width &&
        rect.y < evidence.viewport.height && rect.x + rect.width > 0 && rect.y + rect.height > 0 ? rect : null;
    } finally { await cdp.send('Runtime.releaseObject', { objectId: object.objectId }); }
  }
}
function matches(node, name, startsWith, contains) { return contains ? node.name.includes(name) : startsWith ? node.name.startsWith(name) : node.name === name; }
async function insideIdentifier(node, identifier) {
  if (!node.backend) return false;
  const { object } = await cdp.send('DOM.resolveNode', { backendNodeId: node.backend });
  try {
    const { result } = await cdp.send('Runtime.callFunctionOn', {
      objectId: object.objectId, returnByValue: true,
      arguments: [{ value: identifier }],
      functionDeclaration: `function(identifier) {
        for (let element = this.nodeType === Node.ELEMENT_NODE ? this : this.parentElement;
             element; element = element.parentElement) {
          if (element.getAttribute('flt-semantics-identifier') === identifier) return true;
        }
        return false;
      }`,
    });
    return result.value;
  } finally { await cdp.send('Runtime.releaseObject', { objectId: object.objectId }); }
}
async function identifierRect(identifier) {
  return cdp.evaluate(`(() => {
    const element = document.querySelector('[flt-semantics-identifier="' + ${JSON.stringify(identifier)} + '"]');
    if (!element) return null;
    const rect = element.getBoundingClientRect();
    return { x: rect.x, y: rect.y, width: rect.width, height: rect.height };
  })()`);
}
async function find(name, { startsWith = false, contains = false, role, within, backend, includeDisabled = false, timeout = 30000 } = {}) {
  return until(`visible semantic control ${JSON.stringify(name)}`, async () => {
    const nodes = (await semantics()).filter(node => matches(node, name, startsWith, contains) &&
      (includeDisabled || !node.disabled) && (!role || node.role === role) &&
      (backend === undefined || node.backend === backend));
    const candidates = [];
    for (const node of nodes) {
      if (within && !await insideIdentifier(node, within)) continue;
      const rect = await bounds(node);
      if (rect) candidates.push({ ...node, rect });
    }
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
async function click(name, options = {}) {
  const closesDrawer = name === 'Close workspace' && !!await identifierRect('game-drawer-workspace');
  let node = await find(name, options);
  assert(!node.disabled, `Cannot click a disabled control: ${name}`);
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
  await sleep(options.after ?? 120);
  if (closesDrawer) await drawerClosed();
}
async function findInDrawer(name, options = {}) {
  return find(name, { ...options, within: 'game-drawer-workspace' });
}
async function clickInDrawer(name, options = {}) {
  return click(name, { ...options, within: 'game-drawer-workspace' });
}
async function drawerClosed() {
  await until('drawer finished closing', async () =>
    !await identifierRect('game-drawer-workspace') &&
    (await semantics()).some(node => node.name.startsWith('Game controls') &&
      /Collapsed/.test(`${node.name} ${node.value ?? ''}`)));
}
async function drawerMenuState() {
  const menu = (await semantics()).find(node => node.role === 'button' && node.name.startsWith('Game controls'));
  if (!menu) return null;
  if (menu.expanded === true) return 'expanded';
  if (menu.expanded === false) return 'collapsed';
  const label = `${menu.name} ${menu.value ?? ''}`;
  return /\bExpanded\b/.test(label) ? 'expanded' : /\bCollapsed\b/.test(label) ? 'collapsed' : null;
}
async function ensureDrawerCollapsed() {
  // Workspace semantics are intentionally absent during both opening and
  // closing. Their absence alone therefore cannot tell us to toggle Menu.
  const state = await until('Menu state settled enough to close safely', async () => {
    const current = await drawerMenuState();
    if (current === 'collapsed') return current;
    if (current === 'expanded' && await identifierRect('game-drawer-workspace')) return current;
    return null;
  });
  if (state === 'expanded') {
    log('normalizing an expanded drawer before the next opening check');
    await click('Game controls Expanded', { startsWith: true, role: 'button' });
  }
  // A real failure to close remains a failure; never keep toggling to recover.
  await drawerClosed();
}
async function scrollDrawerTo(name, options = {}) {
  for (let attempt = 0; attempt < 9; attempt++) {
    const found = await findInDrawer(name, { ...options, timeout: 250 }).catch(() => null);
    const rect = await identifierRect('game-drawer-workspace');
    assert(rect && rect.width > 0, 'Cannot scroll a closed drawer.');
    if (found) {
      const y = found.rect.y + found.rect.height / 2;
      if (y > rect.y + 40 && y < Math.min(rect.y + rect.height, evidence.viewport.height) - 10) return found;
    }
    await cdp.send('Input.dispatchMouseEvent', {
      type: 'mouseWheel', x: rect.x + rect.width / 2,
      y: rect.y + Math.min(rect.height - 60, rect.height * .7), deltaX: 0, deltaY: 280,
    });
    await sleep(180);
  }
  throw new Error(`Drawer control not reachable by scrolling: ${name}`);
}
async function selected(name) {
  return until(`selected ${name}`, async () => (await semantics()).some(node => node.name === name && ['true', true].includes(node.checked)));
}
async function capture(name) {
  const shot = await cdp.send('Page.captureScreenshot', { format: 'png', captureBeyondViewport: false });
  const bytes = Buffer.from(shot.data, 'base64');
  await writeFile(join(output, `${name}.png`), bytes);
  await writeFile(join(output, `${name}.semantics.json`), JSON.stringify(await semantics(), null, 2));
  log('captured rendered UI and semantic evidence', { name });
  return bytes;
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
  prefix = buildPrefix(await readFile(join(build, 'index.html'), 'utf8'));
  evidence.baseHref = prefix;
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
    if (chrome.exitCode !== null || chrome.signalCode !== null) throw new Error(`Chrome exited ${chrome.exitCode ?? chrome.signalCode}: ${chromeLog.slice(-2000)}`);
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

  evidence.scope = 'adaptive-five-six-seat-release-smoke';
  async function viewport(width, height) {
    evidence.viewport = { width, height, deviceScaleFactor: 1 };
    await cdp.send('Emulation.setDeviceMetricsOverride', { ...evidence.viewport, mobile: false });
    await sleep(500);
  }
  async function resetPlayers(count) {
    await click('Game controls', { startsWith: true, role: 'button' });
    await clickInDrawer('New game', { role: 'button' });
    await clickInDrawer(`${count} players`);
    await capture(`setup-${count}`);
    await scrollDrawerTo('Reset everything', { role: 'button' });
    await clickInDrawer('Reset everything', { role: 'button' });
    await scrollDrawerTo('Archive & reset everything', { role: 'button' });
    await clickInDrawer('Archive & reset everything', { role: 'button' });
    await drawerClosed();
    log('PASS created game through New game UI', { count });
  }
  async function tabState(name) {
    return (await semantics()).find(node => node.name === `${name}, Utilities view`)?.selected;
  }
  async function expectLife(name, total) {
    await until(`${name} life ${total}`, async () => (await semantics()).some(node =>
      node.name.includes(`${name}, increase life by one`) &&
      new RegExp(`(^|[^0-9])${total}([^0-9]|$)`).test(`${node.name} ${node.value ?? ''}`)));
  }
  for (const count of [5, 6]) {
    await viewport(1133, 744);
    await resetPlayers(count);
    const tabOwners = (await semantics()).filter(node => node.name.endsWith(', Utilities view')).map(node => node.name.split(',')[0]);
    assert.equal(tabOwners.length, count === 5 ? 3 : 6, 'Wrong adaptive seat count at landscape tablet size');
    assert(tabOwners.includes('Player 1') && tabOwners.includes('Player 5'));
    await capture(`${count}-landscape-tokens`);
    await click('Player 1, Utilities view');
    await until('Player 1 local selection', async () => await tabState('Player 1') === true);
    assert.equal(await tabState('Player 5'), false, 'Switching Player 1 changed Player 5');
    await find('Player 1, increase life by one', { startsWith: true, role: 'button' });
    await click('Player 1, increase life by one', { startsWith: true, role: 'button' });
    await expectLife('Player 1', 41);
    await capture(`${count}-landscape-player1-utilities`);
    await click('Player 5, Utilities view');
    await until('Player 5 local selection', async () => await tabState('Player 5') === true);
    await click('Player 5, player details');
    // New game preserves the retained seats' commander choices. The second
    // iteration may therefore already have Player 5's partner enabled.
    const partnerToggle = await find('Has partner', { role: 'switch' });
    if (!['true', true].includes(partnerToggle.checked)) await click('Has partner');
    await selected('Has partner');
    await click('Close workspace');
    await click('Player 1, commander damage ', { startsWith: true, role: 'button' });
    await click('Increase Partner #2 damage from Player 5; lose one life', { startsWith: true, role: 'button' });
    await find('Player 1 · 40 life', { contains: true });
    await capture(`${count}-partner-damage`);
    await click('Close workspace');
    await expectLife('Player 1', 40);
    for (const [width, height] of [[744,1133], [650,480], [1700,1000], [1133,744]]) {
      await viewport(width, height);
      await capture(`${count}-${width}x${height}`);
      await click('Game controls', { startsWith: true, role: 'button' });
      await clickInDrawer('History', { role: 'button' });
      await capture(`${count}-${width}x${height}-history`);
      await clickInDrawer('Close workspace', { role: 'button' });
      await drawerClosed();
      await click('Game controls', { startsWith: true, role: 'button' });
      await findInDrawer('History', { role: 'button' });
      await click('Close game drawer', { role: 'button' });
      await drawerClosed();
      if (width === 1700) {
        assert(!(await semantics()).some(n => n.name.endsWith(', Utilities view')), 'Wide layout still uses tabs');
      } else {
        assert.equal(await tabState('Player 1'), true, 'Resize/drawer lost local selection');
      }
    }
    await click('Player 1, Tokens view');
    await until('Player 1 token selection', async () => await tabState('Player 1') === false);
    assert.equal(await tabState('Player 5'), true, 'Player 5 selection changed');
    log('PASS local independent views, life, partners, resizing and drawer reopen', { count });
  }
  assert.equal(evidence.exceptions.length, 0, 'Unhandled release browser exception');
  assert(!evidence.console.some(entry => /RenderFlex overflowed|EXCEPTION CAUGHT/.test(entry.text)), 'Flutter reported a rendering exception');
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
