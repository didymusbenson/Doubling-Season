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
import { inflateSync } from 'node:zlib';

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
let transitionFrames = null;
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
    expanded: node.properties?.find(property => property.name === 'expanded')?.value?.value,
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
  await click('Game controls', { startsWith: true, role: 'button' });
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
function decodeScreenshotPng(bytes) {
  assert(bytes.subarray(0, 8).equals(Buffer.from([137, 80, 78, 71, 13, 10, 26, 10])), 'Screenshot is not PNG.');
  let width, height, channels;
  const compressed = [];
  for (let offset = 8; offset + 12 <= bytes.length;) {
    const length = bytes.readUInt32BE(offset);
    assert(offset + length + 12 <= bytes.length, 'Truncated screenshot PNG.');
    const type = bytes.toString('ascii', offset + 4, offset + 8);
    const data = bytes.subarray(offset + 8, offset + 8 + length);
    if (type === 'IHDR') {
      width = data.readUInt32BE(0); height = data.readUInt32BE(4);
      assert(data[8] === 8 && [2, 6].includes(data[9]) && data[10] === 0 && data[11] === 0 && data[12] === 0,
        'Expected non-interlaced 8-bit RGB/RGBA Chrome screenshot.');
      channels = data[9] === 6 ? 4 : 3;
    } else if (type === 'IDAT') compressed.push(data);
    offset += length + 12;
    if (type === 'IEND') break;
  }
  assert(width > 0 && height > 0 && width <= 10000 && height <= 10000 && channels, 'Invalid screenshot dimensions.');
  const stride = width * channels;
  const raw = inflateSync(Buffer.concat(compressed));
  assert.equal(raw.length, (stride + 1) * height, 'Unexpected screenshot scanline size.');
  const pixels = Buffer.alloc(stride * height);
  const paeth = (a, b, c) => {
    const p = a + b - c, pa = Math.abs(p - a), pb = Math.abs(p - b), pc = Math.abs(p - c);
    return pa <= pb && pa <= pc ? a : pb <= pc ? b : c;
  };
  for (let y = 0; y < height; y++) {
    const filter = raw[y * (stride + 1)];
    assert(filter <= 4, 'Unknown screenshot PNG filter.');
    for (let x = 0; x < stride; x++) {
      const left = x >= channels ? pixels[y * stride + x - channels] : 0;
      const above = y > 0 ? pixels[(y - 1) * stride + x] : 0;
      const corner = y > 0 && x >= channels ? pixels[(y - 1) * stride + x - channels] : 0;
      const prediction = [0, left, above, Math.floor((left + above) / 2), paeth(left, above, corner)][filter];
      pixels[y * stride + x] = (raw[y * (stride + 1) + x + 1] + prediction) & 255;
    }
  }
  return { width, height, channels, pixels };
}
function paintedLabelPixels(png, rect) {
  let interior = 0, text = 0, icon = 0;
  const stacked = rect.height >= 80;
  for (let y = Math.max(0, Math.ceil(rect.y + 8)); y < Math.min(png.height, rect.y + rect.height - 8); y++) {
    for (let x = Math.max(0, Math.ceil(rect.x + 8)); x < Math.min(png.width, rect.x + rect.width - 8); x++) {
      const i = (y * png.width + x) * png.channels;
      const [r, g, b] = png.pixels.subarray(i, i + 3);
      const a = png.channels === 4 ? png.pixels[i + 3] : 255;
      // The dark-theme menu has green labels/icons and neutral surfaces and
      // borders. Exclude the outer stroke and transparent RGBA pixels. Tall
      // tiles place the label below their icon; narrow-layout rows place it to
      // the right. Require paint in both regions, not just the icon's pixels.
      if (a > 150 && g > 100 && g - r > 12 && g - b > 5) {
        interior++;
        if (stacked ? y > rect.y + rect.height / 2 + 2 : x > rect.x + rect.width / 2 + 2) text++;
        if (stacked ? y < rect.y + rect.height / 2 - 2 : x < rect.x + rect.width / 2 - 2) icon++;
      }
    }
  }
  return { interior, text, icon, layout: stacked ? 'stacked-tile' : 'inline-row' };
}
async function verifyMenuPixels(bytes, players, viewport, file) {
  const png = decodeScreenshotPng(bytes);
  assert.equal(png.width, viewport.width, 'Screenshot scale changed relative to semantic bounds.');
  const labels = [];
  const tree = await semantics();
  assert(!tree.some(node => node.role === 'button' && node.name === 'Reset / reload'),
    'Empty-seat controls remained actionable beside the open drawer.');
  for (const label of ['Dice', 'History', 'New game', 'Archives', 'Board wipes', 'Settings']) {
    assert.equal(tree.filter(node => node.role === 'button' && node.name === label).length, 1,
      `The open drawer exposes a duplicate ${label} action.`);
    const target = await findInDrawer(label, { role: 'button' });
    const pixels = paintedLabelPixels(png, target.rect);
    assert(pixels.interior > 40 && pixels.text > 12 && pixels.icon > 12,
      `Rendered ${label} label/icon is missing at ${players} seats, ${viewport.width}×${viewport.height}: ${JSON.stringify(pixels)}`);
    labels.push({ label, rect: target.rect, ...pixels });
  }
  evidence.drawerMenuPixels ||= [];
  evidence.drawerMenuPixels.push({ players, viewport, file, labels });
  await verifyGameComposition('menu', { centered: true });
}
async function verifyCutoutSurface(bytes, stage, { horizontal = false } = {}) {
  const png = decodeScreenshotPng(bytes);
  const drawer = await identifierRect('game-drawer-workspace');
  assert(drawer, 'Cutout pixel check requires the open drawer.');
  const menu = await find('Game controls Expanded', { startsWith: true, role: 'button' });
  const y = menu.rect.y + menu.rect.height / 2;
  const sample = (x, y) => {
    const channels = [[], [], []];
    for (let dy = -1; dy <= 1; dy++) for (let dx = -1; dx <= 1; dx++) {
      const index = (Math.round(y + dy) * png.width + Math.round(x + dx)) * png.channels;
      for (let channel = 0; channel < 3; channel++) channels[channel].push(png.pixels[index + channel]);
    }
    return channels.map(values => values.sort((a, b) => a - b)[4]);
  };
  // The opposite wall's exposed semicircle must use the same actual surface
  // as its adjacent empty gutter. Both points avoid strokes, icons and text.
  const notchPoint = horizontal ? { x: 30, y: drawer.y - 12 } : { x: drawer.x - 12, y };
  const surfacePoint = horizontal ? { x: 90, y: drawer.y + 8 } : { x: drawer.x + 8, y: y - 60 };
  const notch = sample(notchPoint.x, notchPoint.y), surface = sample(surfacePoint.x, surfacePoint.y);
  assert(notch.every((value, index) => Math.abs(value - surface[index]) <= 3),
    `${stage}: wall cutout does not match the current theme surface: ${notch} versus ${surface}.`);
  evidence.cutoutPixels ||= [];
  evidence.cutoutPixels.push({ stage, viewport: { ...evidence.viewport }, notchPoint, surfacePoint, notch, surface });
}
async function captureDrawerTransition(name, action) {
  const frames = [];
  transitionFrames = frames;
  await cdp.send('Page.startScreencast', { format: 'png', everyNthFrame: 1 });
  try {
    await action();
    if (name.endsWith('-closing')) {
      const deadline = Date.now() + 700;
      let closingTree;
      while (Date.now() < deadline) {
        const tree = await semantics();
        if (tree.some(node => node.name === 'Roll dice' && node.disabled)) {
          closingTree = tree;
          break;
        }
        await sleep(10);
      }
      assert(closingTree, 'Did not observe the closing drawer with its edge action disabled.');
      assert(!closingTree.some(node => node.role === 'button' &&
        ['Dice', 'History', 'New game', 'Archives', 'Board wipes', 'Settings', 'Close workspace'].includes(node.name)),
      'Invisible drawer workflow controls remained in the live accessibility tree while closing.');
      assert.equal(await identifierRect('game-drawer-workspace'), null,
        'Closing drawer retained its actionable semantic content.');
      const file = `${name}-live-semantics.json`;
      await writeFile(join(output, file), JSON.stringify(closingTree, null, 2));
      evidence.drawerClosingSemantics ||= [];
      evidence.drawerClosingSemantics.push({ name, file, controls: closingTree.map(({ name, role, disabled }) => ({ name, role, disabled })) });
    }
    await sleep(650);
  } finally {
    await cdp.send('Page.stopScreencast');
    transitionFrames = null;
  }
  const records = [];
  for (const [index, frame] of frames.entries()) {
    const file = `${name}-${String(index).padStart(2, '0')}.png`;
    await writeFile(join(output, file), Buffer.from(frame.data, 'base64'));
    records.push({ file, metadata: frame.metadata });
  }
  assert(records.length >= 2, `No intermediate animation frames captured for ${name}.`);
  evidence.drawerTransitions ||= [];
  evidence.drawerTransitions.push({ name, frames: records });
  return capture(`${name}-settled`);
}
async function assertNoTooltipSemantics(before, label) {
  const after = await semantics();
  assert(!after.some(node => node.role === 'tooltip'), `${label} exposed a tooltip role.`);
  const beforeLabels = new Map();
  for (const node of before) beforeLabels.set(node.name, (beforeLabels.get(node.name) ?? 0) + 1);
  const afterLabels = new Map();
  for (const node of after) afterLabels.set(node.name, (afterLabels.get(node.name) ?? 0) + 1);
  for (const [name, count] of afterLabels) {
    assert(count <= (beforeLabels.get(name) ?? 0), `${label} added hover/hold text: ${name}`);
  }
  assert.equal(await cdp.evaluate(`document.querySelectorAll(${JSON.stringify('[role="tooltip"], [title]:not([title=""])')}).length`), 0,
    `${label} exposed a browser tooltip target.`);
}
async function inspectNoTooltip(name, options = {}) {
  await ensureDrawerCollapsed();
  const node = await find(name, options);
  const before = await semantics();
  const x = node.rect.x + node.rect.width / 2, y = node.rect.y + node.rect.height / 2;
  await cdp.send('Input.dispatchMouseEvent', { type: 'mouseMoved', x, y });
  await sleep(1600);
  await assertNoTooltipSemantics(before, `${name} hover`);
  await capture('21-menu-hover-no-tooltip');
  await cdp.send('Emulation.setTouchEmulationEnabled', { enabled: true, maxTouchPoints: 1 });
  await cdp.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ x, y, id: 0, radiusX: 1, radiusY: 1, force: 1 }] });
  await sleep(1200);
  await assertNoTooltipSemantics(before, `${name} long press`);
  await capture('21-menu-long-press-no-tooltip');
  await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
  await cdp.send('Emulation.setTouchEmulationEnabled', { enabled: false });
  await sleep(650);
  // Menu has no functional hold; a retained ordinary tap on release is fine.
  // Use Menu state because the opening workspace can still be excluded from
  // semantics after a delayed tap is recognized on a busy browser runner.
  await ensureDrawerCollapsed();
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
  const bytes = Buffer.from(shot.data, 'base64');
  await writeFile(join(output, `${name}.png`), bytes);
  await writeFile(join(output, `${name}.semantics.json`), JSON.stringify(await semantics(), null, 2));
  log('captured rendered UI and semantic evidence', { name });
  return bytes;
}
async function verifyGameComposition(name, { centered = true, list = false } = {}) {
  const drawer = await identifierRect('game-drawer-workspace');
  const body = await identifierRect('game-drawer-body-viewport');
  const page = await identifierRect('game-drawer-page-viewport');
  const group = await identifierRect('game-drawer-attached-group');
  const header = await identifierRect('game-drawer-header');
  assert(drawer && body && page && group && header,
    `${name}: missing attached navigation geometry.`);
  assert(Math.abs(header.y + header.height - body.y) < 2,
    `${name}: navigation is detached from the body viewport.`);
  assert(Math.abs(group.y + group.height / 2 - (page.y + page.height / 2)) < 2,
    `${name}: header and body are not centered as one group.`);
  const overflowing = group.height >= page.height - 2;
  if (overflowing) assert(Math.abs(header.y - page.y) < 2,
    `${name}: overflowing page navigation is not pinned to the available top.`);
  for (const label of ['Close workspace', ...((await semantics()).some(node => node.name === 'Back' && node.role === 'button') ? ['Back'] : [])]) {
    const control = await findInDrawer(label, { role: 'button' });
    assert(control.rect.y >= header.y - 1 && control.rect.y + control.rect.height <= header.y + header.height + 1,
      `${name}: ${label} is outside its attached header.`);
    assert((await hitTarget(control)).sameAction, `${name}: ${label} is obstructed.`);
  }
  const navigation = { page, group, header, overflowing };
  if (list) {
    assert(body, `${name}: missing list viewport.`);
    const rows = await cdp.evaluate(`Array.from(document.querySelectorAll('[flt-semantics-identifier^="game-drawer-list-row-"]')).map(element => {
      const rect = element.getBoundingClientRect();
      return { id: element.getAttribute('flt-semantics-identifier'), x: rect.x, y: rect.y, width: rect.width, height: rect.height };
    })`);
    const visible = rows.filter(row => row.height > 0 && row.width > 0 && row.y < body.y + body.height && row.y + row.height > body.y);
    assert(visible.length > 0, `${name}: populated list has no visible rows.`);
    for (const row of visible) {
      assert(Math.abs(row.x + row.width / 2 - (body.x + body.width / 2)) < 2,
        `${name}: ${row.id} is not centered in the list viewport.`);
      assert(row.x >= drawer.x + 31 && row.x + row.width <= drawer.x + drawer.width - 31,
        `${name}: ${row.id} enters a wall/handle gutter.`);
    }
    const result = { name, viewport: { ...evidence.viewport }, drawer, body, navigation, list: true, rows: visible };
    evidence.gameComposition ||= [];
    evidence.gameComposition.push(result);
    return result;
  }
  const content = await identifierRect('game-drawer-body-content');
  assert(body && content && content.width > 0 && content.height > 0,
    `${name}: missing rendered natural-size drawer content.`);
  const horizontalOffset = content.x + content.width / 2 - (body.x + body.width / 2);
  assert(Math.abs(horizontalOffset) < 2, `${name}: drawer content is not horizontally centered (${horizontalOffset}px).`);
  assert(content.x >= drawer.x + 31 && content.x + content.width <= drawer.x + drawer.width - 31,
    `${name}: content enters a wall cutout or Menu handle gutter.`);
  const fits = !overflowing;
  const headerGap = content.y - (header.y + header.height);
  // Long routes may retain an ordinary scroll position. Short routes fit in
  // full and must keep their content immediately under the navigation row.
  if (fits) assert(Math.abs(headerGap - 8) < 2,
    `${name}: short content is detached from navigation (${headerGap}px).`);
  const result = { name, viewport: { ...evidence.viewport }, drawer, body, content, navigation, centered, fits, horizontalOffset, headerGap };
  evidence.gameComposition ||= [];
  evidence.gameComposition.push(result);
  return result;
}
async function captureGameView(name, composition = {}) {
  // Review the same real route in both tablet sizes. Resizing only the
  // disposable browser viewport preserves the current workflow and draft.
  const original = { ...evidence.viewport };
  for (const viewport of [{ width: 1133, height: 744 }, { width: 744, height: 1133 }]) {
    evidence.viewport = { ...viewport, deviceScaleFactor: 1 };
    await cdp.send('Emulation.setDeviceMetricsOverride', { ...evidence.viewport, mobile: false });
    await sleep(250);
    await findInDrawer('Close workspace', { role: 'button' });
    const drawer = await identifierRect('game-drawer-workspace');
    assert(drawer && drawer.width >= 220 && drawer.height >= 300, `${name}: unusable drawer viewport.`);
    await verifyGameComposition(name, composition);
    const file = `${name}-${viewport.width}x${viewport.height}`;
    await capture(file);
    evidence.gameViews ||= [];
    evidence.gameViews.push({ name, file: `${file}.png`, viewport, drawer });
  }
  evidence.viewport = original;
  await cdp.send('Emulation.setDeviceMetricsOverride', { ...original, mobile: false });
  await sleep(250);
}
async function verifyLifeOverlayGeometry(stage, names, counterOwners = []) {
  const tree = await semantics();
  const union = rects => {
    const x = Math.min(...rects.map(rect => rect.x));
    const y = Math.min(...rects.map(rect => rect.y));
    return { x, y, width: Math.max(...rects.map(rect => rect.x + rect.width)) - x,
      height: Math.max(...rects.map(rect => rect.y + rect.height)) - y };
  };
  const results = [];
  for (const name of names) {
    const minus = await find(`${name}, decrease life by one`, { startsWith: true, role: 'button' });
    const plus = await find(`${name}, increase life by one`, { startsWith: true, role: 'button' });
    const ledger = await find(`${name}, commander damage `, { startsWith: true, role: 'button' });
    const counters = tree.filter(node => node.role === 'button' && node.name.startsWith(`${name}, player counters`));
    assert.equal(counters.length, counterOwners.includes(name) ? 1 : 0,
      `${name}: unexpected counter area in ${stage}.`);
    const counterRect = counters.length ? await bounds(counters[0]) : null;
    if (counters.length) assert(counterRect, `${name}: active counter summary is not visible.`);
    const chip = union([minus.rect, plus.rect]);
    const group = union([ledger.rect, ...(counterRect ? [counterRect] : [])]);
    // The local horizontal axis follows the two halves, including the 90/270
    // degree seats. No injected seat state or assumptions about DOM order.
    const axis = Math.abs(plus.rect.x - minus.rect.x) > Math.abs(plus.rect.y - minus.rect.y) ? 'x' : 'y';
    const size = axis === 'x' ? 'width' : 'height';
    const offset = group[axis] + group[size] / 2 - (chip[axis] + chip[size] / 2);
    assert(Math.abs(offset) <= 2, `${name}: ${stage} damage/counter group is not centered (${offset}px).`);
    assert(group[axis] >= chip[axis] - 1 && group[axis] + group[size] <= chip[axis] + chip[size] + 1,
      `${name}: ${stage} damage/counter group overflows the life chip.`);
    assert((await hitTarget(ledger)).sameAction, `${name}: centered ledger center activates another control.`);
    results.push({ name, axis, chip, ledger: ledger.rect, counters: counterRect, group, offset });
  }
  evidence.lifeOverlayGeometry ||= [];
  evidence.lifeOverlayGeometry.push({ stage, viewport: { ...evidence.viewport }, players: results });
}
function stepperValue(node) {
  const value = Number(node.value ?? node.name.match(/ (-?\d+)$/)?.[1]);
  assert(Number.isInteger(value), `Missing numeric stepper value: ${node.name}`);
  return value;
}
async function verifyInlineCounterChips(stage) {
  const tree = await semantics();
  assert(!tree.some(node => /^(Add counter|Close counter choices|Enable (energy|poison|experience|radiation|counter))$/.test(node.name)),
    'Player counters retained the separate enable/management flow.');
  const group = await identifierRect('player-counter-chips');
  const statuses = await identifierRect('player-status-chips');
  assert(group && statuses, 'Inline counter/status geometry is missing.');
  const chips = [];
  for (const type of ['energy', 'poison', 'experience', 'radiation']) {
    const increase = await find(`Increase ${type}`, { startsWith: true, role: 'button' });
    const decrease = await find(`Decrease ${type}`, { startsWith: true, role: 'button', includeDisabled: true });
    const rect = await identifierRect(`player-counter-${type}`);
    assert(rect && increase.rect.width >= 43.9 && increase.rect.height >= 43.9 &&
      decrease.rect.width >= 43.9 && decrease.rect.height >= 43.9,
    `${type}: inline chip does not expose full-sized stepper halves.`);
    const value = stepperValue(increase);
    assert((await hitTarget(increase)).sameAction, `${type}: inline increase half is obstructed.`);
    if (value === 0) assert(decrease.disabled, `${type}: zero decrement lacks its disabled state.`);
    else assert((await hitTarget(decrease)).sameAction, `${type}: inline decrease half is obstructed.`);
    chips.push({ type, rect, value });
  }
  const left = await find('Decrease energy', { startsWith: true, role: 'button', includeDisabled: true });
  const right = await find('Increase energy', { startsWith: true, role: 'button' });
  const dx = right.rect.x + right.rect.width / 2 - left.rect.x - left.rect.width / 2;
  const dy = right.rect.y + right.rect.height / 2 - left.rect.y - left.rect.height / 2;
  const length = Math.hypot(dx, dy), down = { x: -dy / length, y: dx / length };
  const below = (group.x + group.width / 2 - statuses.x - statuses.width / 2) * down.x +
    (group.y + group.height / 2 - statuses.y - statuses.height / 2) * down.y;
  assert(below > 0, `${stage}: counter chips are not below the statuses in player-local orientation.`);
  evidence.inlineCounters ||= [];
  evidence.inlineCounters.push({ stage, viewport: { ...evidence.viewport }, group, statuses, below, chips });
  return chips;
}
async function exerciseCommanderName(recipient, owner, source, { hold = false } = {}) {
  const increaseLabel = `Increase ${source} damage from ${owner}; lose one life`;
  const decreaseLabel = `Decrease ${source} damage from ${owner}; restore one life`;
  const increase = await find(increaseLabel, { startsWith: true, role: 'button' });
  const decrease = await find(decreaseLabel, { startsWith: true, role: 'button', includeDisabled: true });
  const center = rect => ({ x: rect.x + rect.width / 2, y: rect.y + rect.height / 2 });
  const a = center(decrease.rect), b = center(increase.rect);
  const length = Math.hypot(b.x - a.x, b.y - a.y);
  const across = { x: (b.x - a.x) / length, y: (b.y - a.y) / length };
  const down = { x: -across.y, y: across.x };
  const height = Math.abs(down.x) > .5 ? increase.rect.width : increase.rect.height;
  const middle = { x: (a.x + b.x) / 2, y: (a.y + b.y) / 2 };
  // The actual text RenderBox is checked by widget tests. In the release
  // browser its pointer-transparent excluded overlay has no DOM node. Derive
  // the centered name line from the rendered full-half geometry and the
  // production 5px top inset + 12px/1.1 line height; +/-2px straddles the
  // center within even the short "qa" label, rather than tapping its margin.
  const nameCenter = { x: middle.x + down.x * (-height / 2 + 11),
    y: middle.y + down.y * (-height / 2 + 11) };
  const points = { increase: { x: nameCenter.x + across.x * 2, y: nameCenter.y + across.y * 2 },
    decrease: { x: nameCenter.x - across.x * 2, y: nameCenter.y - across.y * 2 } };
  const snapshot = async () => (await semantics()).filter(node => node.role === 'button' &&
    /^Increase .+ damage from .+; lose one life /.test(node.name)).map(node => node.name).sort();
  const beforeAll = await snapshot(), before = stepperValue(increase);
  const lifeHeader = (await semantics()).find(node => node.name.startsWith(`${recipient} · `) && /\d+ life/.test(node.name))?.name;
  assert(lifeHeader, 'Missing recipient life header before commander name input.');
  async function press(label, point, holdMs = 40) {
    const node = await find(label, { startsWith: true, role: 'button' });
    const hit = await hitTarget({ ...node, rect: { x: point.x - .5, y: point.y - .5, width: 1, height: 1 } });
    assert(hit.sameAction, `${recipient}/${owner}/${source}: rendered name strip belongs to another hit target.`);
    await cdp.send('Input.dispatchMouseEvent', { type: 'mouseMoved', ...point });
    await cdp.send('Input.dispatchMouseEvent', { type: 'mousePressed', ...point, button: 'left', buttons: 1, clickCount: 1 });
    await sleep(holdMs);
    const held = holdMs > 500 ? stepperValue(await find(increaseLabel, { startsWith: true, role: 'button' })) : null;
    await cdp.send('Input.dispatchMouseEvent', { type: 'mouseReleased', ...point, button: 'left', buttons: 0, clickCount: 1 });
    await sleep(180);
    return held;
  }
  const held = await press(increaseLabel, points.increase, hold ? 1200 : 40);
  const changed = await until('commander name input changes damage', async () => {
    const value = stepperValue(await find(increaseLabel, { startsWith: true, role: 'button' }));
    return value > before ? value : false;
  });
  if (hold) {
    assert(held > before, 'Commander name hold did not change damage while still pressed.');
    // The AX snapshot is asynchronous while repetition is still active; one
    // accepted tick can land between that read and dispatching mouseReleased.
    // Check stability after release instead of comparing those racing reads.
    await sleep(180);
    assert.equal(stepperValue(await find(increaseLabel, { startsWith: true, role: 'button' })), changed,
      'Commander name hold kept changing after release.');
  }
  else assert.equal(changed, before + 1, 'Commander name tap changed damage by more than one.');
  for (let value = changed; value > before; value--) await press(decreaseLabel, points.decrease);
  await until('commander name decrement restores the original value', async () =>
    stepperValue(await find(increaseLabel, { startsWith: true, role: 'button' })) === before);
  await find(lifeHeader);
  assert.deepEqual(await snapshot(), beforeAll, 'Commander name input changed another source or failed to restore its source.');
  evidence.commanderNameInputs ||= [];
  evidence.commanderNameInputs.push({ recipient, owner, source, viewport: { ...evidence.viewport },
    coordinateMethod: 'rendered-half-derived-name-line; exact Text bounds covered by widget tests',
    increase: increase.rect, decrease: decrease.rect, points, before, changed, held, lifeHeader, restored: true });
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
  cdp.on('Page.screencastFrame', frame => {
    if (transitionFrames && transitionFrames.length < 40) transitionFrames.push(frame);
    void cdp.send('Page.screencastFrameAck', { sessionId: frame.sessionId }).catch(() => {});
  });
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

  const probeSeats = process.env.DRAWER_SMOKE_SEATS;
  assert(!probeSeats || ['2', '3', '4'].includes(probeSeats), 'DRAWER_SMOKE_SEATS must be 2, 3, or 4.');
  if (probeSeats) {
    // Fast diagnosis uses the same real input/pixel/hit checks, in a fresh
    // profile. CI leaves this unset and always runs the complete suite below.
    evidence.scope = 'drawer-probe-only';
    await click('Game controls', { startsWith: true, role: 'button' });
    await clickInDrawer('New game', { role: 'button' });
    await clickInDrawer(`${probeSeats} players`);
    await scrollDrawerTo('Complete reset', { role: 'button' });
    await clickInDrawer('Complete reset', { role: 'button' });
    await scrollDrawerTo('Archive & complete reset', { role: 'button' });
    await clickInDrawer('Archive & complete reset', { role: 'button' });
    await drawerClosed();
    for (const viewport of [{ width: 1133, height: 744 }, { width: 744, height: 1133 }]) {
      evidence.viewport = { ...viewport, deviceScaleFactor: 1 };
      await cdp.send('Emulation.setDeviceMetricsOverride', { ...evidence.viewport, mobile: false });
      await sleep(250);
      const name = `probe-${probeSeats}p-${viewport.width}x${viewport.height}`;
      const png = await captureDrawerTransition(`${name}-opening`, () =>
        click('Game controls', { startsWith: true, role: 'button', after: 0 }));
      await verifyMenuPixels(png, Number(probeSeats), viewport, `${name}-opening-settled.png`);
      await clickInDrawer('History', { role: 'button' });
      await findInDrawer('Back', { role: 'button' });
      await capture(`${name}-history`);
      await clickInDrawer('Back', { role: 'button' });
      await click('Close game drawer', { role: 'button' });
      await drawerClosed();
      await click('Game controls', { startsWith: true, role: 'button' });
      await findInDrawer('History', { role: 'button' });
      await captureDrawerTransition(`${name}-closing`, () =>
        click('Game controls', { startsWith: true, role: 'button', after: 0 }));
      await drawerClosed();
    }
    assert.equal(evidence.exceptions.length, 0, 'Unhandled browser runtime exceptions occurred.');
    log(`PASS focused ${probeSeats}-seat drawer probe; complete release coverage not run in this mode`);
    evidence.status = 'passed';
  } else {
  evidence.scope = 'full-release-smoke';
  await click('Game controls Collapsed', { startsWith: true, role: 'button' });
  await clickInDrawer('History', { role: 'button' });
  await findInDrawer('This game has no actions yet.');
  await captureGameView('00-drawer-history-empty');
  await clickInDrawer('Close workspace', { role: 'button' });

  // The web semantics label must not extend the Day/Night hit target into
  // another seat's life half. Exercise the actual centers with semantics on;
  // do not substitute alternate points when a center belongs to another action.
  for (const viewport of [{ width: 744, height: 1133 }, { width: 1133, height: 744 }]) {
    Object.assign(evidence.viewport, viewport);
    await cdp.send('Emulation.setDeviceMetricsOverride', { ...evidence.viewport, mobile: false });
    await sleep(350);
    await find('Day/Night: neither. Tap to change; hold to clear', { role: 'button' });
    const dayNightBefore = await dayNightState();
    for (const name of ['Player 1', 'Player 2', 'Player 3', 'Player 4']) {
      await click(`${name}, decrease life by one 40`, { role: 'button' });
      await find(`${name}, increase life by one 39`, { role: 'button' });
      assert.equal(await dayNightState(), dayNightBefore, 'Life-minus center activated Day/Night.');
      await click(`${name}, increase life by one 39`, { role: 'button' });
      await find(`${name}, decrease life by one 40`, { role: 'button' });
      assert.equal(await dayNightState(), dayNightBefore, 'Life-plus center activated Day/Night.');
    }
    await verifyLifeOverlayGeometry('no-counters', ['Player 1', 'Player 2', 'Player 3', 'Player 4']);
    await capture(`01-life-centers-${viewport.width}x${viewport.height}`);
  }
  log('PASS semantics-enabled life centers for all four seats in portrait and landscape without Day/Night activation');

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
  assert(!(await semantics()).some(node => /Correct .*damage|Set damage total|Correct life|Undo latest action/.test(node.name)),
    'Combined popup exposes a removed correction or standalone Undo route.');
  await click('Close workspace');
  await click('Game controls', { startsWith: true, role: 'button' });
  await click('History', { role: 'button' });
  await click('Undo latest:', { startsWith: true, role: 'button' });
  await click('Close workspace');
  await click('qa, commander damage ', { startsWith: true, role: 'button' });
  await find('qa · 40 life', { contains: true });
  await capture('03e-partner-history-undo-restores-damage-and-life');
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
  log('PASS focused partner setup, separate damage, guarded Off, History-only undo and persisted deactivation');


  await click('Day/Night: neither.', { startsWith: true });
  await find('Day/Night: day.', { startsWith: true });
  await click('Day/Night: day.', { startsWith: true });
  await find('Day/Night: night.', { startsWith: true });
  await capture('04-direct-day-night');
  await diagnoseHold('mouse');
  await diagnoseHold('touch');
  await click('Roll dice', { startsWith: true, role: 'button' });
  await find('D6 quantity: 1');
  await captureGameView('05a-dice-selector-outlines');
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
  await captureGameView('05-direct-dice-results');
  await click('Back', { role: 'button' });
  await find('D6 quantity: 1');
  await click('Increase d4', { startsWith: true, role: 'button' });
  await click('Increase d4', { startsWith: true, role: 'button' });
  await click('Increase d20', { startsWith: true, role: 'button' });
  await find('D4 quantity: 2');
  await captureGameView('05b-dice-mixed-selection');
  await click('Roll 4 dice', { role: 'button' });
  await find('Roll again', { role: 'button' });
  await verifyDiceResults({ 4: 2, 6: 1, 20: 1 });
  await captureGameView('05c-dice-mixed-results');
  await clickInDrawer('Back', { role: 'button' });
  for (let index = 0; index < 19; index++) await clickInDrawer('Increase d6', { startsWith: true, role: 'button' });
  await clickInDrawer('Roll 23 dice', { role: 'button' });
  await captureGameView('05c-dice-dense-results');
  await scrollDrawerTo('Roll again', { role: 'button' });
  await verifyDiceResults({ 4: 2, 6: 20, 20: 1 });
  await capture('05c-dice-dense-results-bottom');
  await clickInDrawer('Back', { role: 'button' });
  for (let index = 0; index < 19; index++) await clickInDrawer('Decrease d6', { startsWith: true, role: 'button' });
  await clickInDrawer('Roll 4 dice', { role: 'button' });
  await verifyDiceResults({ 4: 2, 6: 1, 20: 1 });
  await click('Roll again', { role: 'button' });
  await verifyDiceResults({ 4: 2, 6: 1, 20: 1 });
  await click('Back', { role: 'button' });
  await find('D4 quantity: 2');
  await find('D20 quantity: 1');
  for (const sides of [4, 4, 6, 20]) await click(`Decrease d${sides}`, { startsWith: true, role: 'button' });
  await find('D6 quantity: 0');
  await clickInDrawer('Roll dice', { role: 'button' });
  await find('Select at least one die.', { contains: true });
  await verifyDiceResults({});
  await captureGameView('05d-dice-empty-selection');
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

  // Exercise the relocated statuses and immediate-life route in the real
  // release build, without injecting state or relying on widget-only fixtures.
  assert(!(await semantics()).some(node => node.name.startsWith('qa, player counters')),
    'Zero player counters reserve a life-summary action.');
  await click('qa, commander damage ', { startsWith: true, role: 'button' });
  const zeroCounters = await verifyInlineCounterChips('all-supported-counters-at-zero');
  assert(zeroCounters.every(counter => counter.value === 0), 'A fresh counter editor did not start at zero.');
  assert((await find('Decrease energy', { startsWith: true, role: 'button', includeDisabled: true })).disabled,
    'Zero-clamped energy decrement is not disabled.');
  assert.equal(stepperValue(await find('Increase energy', { startsWith: true, role: 'button' })), 0,
    'Zero-clamped energy decreased below zero.');
  await capture('17a-all-zero-inline-counter-chips');
  await click('Close workspace');
  await find('qa, player details', { role: 'button' });
  assert(!(await semantics()).some(node => node.name.startsWith('qa, player counters')),
    'Opening the zero-counter editor created an empty summary.');
  await click('qa, commander damage ', { startsWith: true, role: 'button' });
  await click('Increase energy', { startsWith: true, role: 'button' });
  await click('Close workspace');
  await find('qa, player counters', { startsWith: true, role: 'button' });
  await click('qa, player counters', { startsWith: true, role: 'button' });
  await click('Decrease energy', { startsWith: true, role: 'button' });
  await click('Close workspace');
  await find('qa, player details', { role: 'button' });
  assert(!(await semantics()).some(node => node.name.startsWith('qa, player counters')),
    'A counter restored to zero retained a summary strip.');
  await click('qa, commander damage ', { startsWith: true, role: 'button' });
  for (const status of ['Monarch', 'City’s blessing', 'Initiative']) {
    await click(`${status}, Off`, { contains: true, role: 'switch' });
    await find(`${status}, On`, { contains: true, role: 'switch' });
  }
  await click('Increase energy', { startsWith: true, role: 'button' });
  await click('Increase energy', { startsWith: true, role: 'button' });
  // Keep the two consecutive inputs. This editor displays committed state;
  // fixed click pacing is not a durable-save barrier on a slower CI runner.
  // A lost input still fails the bounded wait rather than accepting one.
  await until('both consecutive energy taps commit to two', async () =>
    stepperValue(await find('Increase energy', { startsWith: true, role: 'button' })) === 2);
  const activeCounters = await verifyInlineCounterChips('energy-two-other-supported-counters-zero');
  assert.deepEqual(activeCounters.map(({ type, value }) => [type, value]),
    [['energy', 2], ['poison', 0], ['experience', 0], ['radiation', 0]]);
  await capture('17-visual-counters-and-three-statuses');
  await click('Close workspace');
  await capture('18-statuses-on-life-chip');
  await click('qa, decrease life by one', { contains: true, role: 'button' });
  for (let index = 0; index < 3; index++) {
    await click('qa, increase life by one', { contains: true, role: 'button' });
  }
  async function expectLife(name, total) {
    await until(`${name} life ${total}`, async () => (await semantics()).some(node =>
      node.name.includes(`${name}, increase life by one`) &&
      new RegExp(`(^|[^0-9])${total}([^0-9]|$)`).test(`${node.name} ${node.value ?? ''}`)));
  }
  await expectLife('qa', 42);
  // The life chip projects accepted taps before storage. This sequence reaches
  // 42 only on its final command; the Commander header reads canonical life,
  // making it a durable UI barrier before reload rather than an arbitrary wait.
  await click('qa, commander damage ', { startsWith: true, role: 'button' });
  await find('qa · 42 life', { startsWith: true });
  await click('Close workspace');
  await cdp.send('Page.reload', { ignoreCache: true });
  await enableSemantics();
  await expectLife('qa', 42);
  await click('qa, player counters', { contains: true, role: 'button' });
  for (const status of ['Monarch', 'City’s blessing', 'Initiative']) {
    await find(`${status}, On`, { contains: true, role: 'switch' });
  }
  await click('Close workspace');
  log('PASS relocated status controls and ordinary life taps persist across reload');

  // Review owner/partner grids from every real seat in both orientations.
  for (const name of ['qa', 'Player 2', 'Player 3', 'Player 4']) {
    await click(`${name}, player details`);
    await click('Has partner');
    await selected('Has partner');
    await click('Search token art', { role: 'button' });
    await click('Search token art. Current value:', { startsWith: true, role: 'button' });
    for (const letter of 'scute') await click(letter, { role: 'button' });
    await click('Done');
    await click('Scute Swarm', { startsWith: true });
    await click('DSC', { startsWith: true, role: 'button' });
    await find('Preview — not saved', { contains: true });
    await click('Use artwork', { role: 'button' });
    await find('Remove life artwork', { role: 'button' });
    await click('Close workspace');
  }
  await sleep(750); // Decode the chosen life backgrounds before the visual matrix.
  for (const viewport of [
    { width: 1133, height: 744, deviceScaleFactor: 1 },
    { width: 744, height: 1133, deviceScaleFactor: 1 },
  ]) {
    evidence.viewport = viewport;
    await cdp.send('Emulation.setDeviceMetricsOverride', { ...viewport, mobile: false });
    await sleep(250);
    await verifyLifeOverlayGeometry('partners-art-active-counter', ['qa', 'Player 2', 'Player 3', 'Player 4'], ['qa']);
    await capture(`19-board-${viewport.width}x${viewport.height}`);
    for (const [index, name] of ['qa', 'Player 2', 'Player 3', 'Player 4'].entries()) {
      await click(`${name}, commander damage `, { startsWith: true, role: 'button' });
      for (const owner of ['qa', 'Player 2', 'Player 3', 'Player 4']) {
        for (const source of ['Commander #1', 'Partner #2']) {
          const target = await find(`Increase ${source} damage from ${owner}; lose one life`, { startsWith: true, role: 'button' });
          assert(target.rect.width >= 43.9 && target.rect.height >= 43.9,
            `Commander target too small: ${name}/${owner}/${source}`);
        }
      }
      await verifyInlineCounterChips(`seat-${index + 1}-${viewport.width}x${viewport.height}`);
      for (const source of ['Commander #1', 'Partner #2']) {
        await exerciseCommanderName(name, 'qa', source, {
          hold: index === 0 && viewport.width === 1133 && source === 'Partner #2',
        });
      }
      await capture(`20-commander-seat${index + 1}-${viewport.width}x${viewport.height}`);
      await click('Close workspace');
    }
  }
  log('PASS all four seat-facing art-backed owner/partner grids in portrait and landscape');

  // These actions affect only this process's temporary Chrome profile. The
  // archive created by New game restores the populated test table after every
  // two-/three-seat check; no app-state injection or user device is involved.
  evidence.viewport = { width: 1133, height: 744, deviceScaleFactor: 1 };
  await cdp.send('Emulation.setDeviceMetricsOverride', { ...evidence.viewport, mobile: false });
  await sleep(250);
  await inspectNoTooltip('Game controls', { startsWith: true, role: 'button' });

  async function tableSnapshot() {
    return (await semantics()).filter(node =>
      node.role === 'button' &&
      /, (?:increase life by one|decrease life by one|Scute Swarm,)/.test(node.name))
      .map(({ role, name, value }) => ({ role, name, value }))
      .sort((a, b) => a.name.localeCompare(b.name));
  }
  async function twoPlayerTokenBaseline(viewport, file) {
    const rows = [];
    for (const owner of ['qa', 'Player 2']) {
      const controls = [];
      for (const node of (await semantics()).filter(node => node.role === 'button' && node.name.startsWith(`${owner}, Scute Swarm,`))) {
        const rect = await bounds(node);
        if (rect) controls.push({ name: node.name, rect });
      }
      assert(controls.length >= 8, `${owner}: populated two-player token fixture is missing its real controls.`);
      const name = controls.find(node => node.name.startsWith(`${owner}, Scute Swarm, Name`));
      const upper = name.rect.y + name.rect.height / 2 < viewport.height / 2;
      const nearest = upper ? Math.max(...controls.map(node => node.rect.y + node.rect.height)) : Math.min(...controls.map(node => node.rect.y));
      const seamInset = Math.abs(nearest - viewport.height / 2);
      assert(seamInset < 18, `${owner}: the first token row still reserves a blank seam strip (${seamInset}px).`);
      rows.push({ owner, upper, controls, seamInset });
    }
    return { png: decodeScreenshotPng(await capture(file)), rows };
  }
  async function verifyTwoPlayerTokenRows(before, bytes, drawer, viewport) {
    const after = decodeScreenshotPng(bytes);
    const dismissals = [];
    for (const node of (await semantics()).filter(node => node.role === 'button' && node.name === 'Close game drawer')) {
      const rect = await bounds(node);
      if (rect) dismissals.push(rect);
    }
    assert.equal(dismissals.length, 2, 'Two-player drawer must expose one full token dismissal region per seat.');
    const results = [];
    for (const row of before.rows) {
      const region = dismissals.find(rect => row.upper ? rect.y < drawer.y : rect.y >= drawer.y + drawer.height - 1);
      const width = (viewport.width - 1) * .6;
      assert(region && Math.abs(region.width - width) < 2,
        `${row.owner}: the open drawer clips or resizes its token-lane width.`);
      assert(Math.abs(region.x - (row.upper ? viewport.width - width : 0)) < 2,
        `${row.owner}: the open drawer moved its token lane sideways.`);
      const shift = row.upper ? drawer.y - viewport.height / 2 : drawer.y + drawer.height - viewport.height / 2;
      const controlTop = Math.min(...row.controls.map(node => node.rect.y));
      const controlBottom = Math.max(...row.controls.map(node => node.rect.y + node.rect.height));
      // Corner Add/Summary controls intentionally remain over the outer edge
      // of the lane. Compare the first-row paint before that 48px overlay
      // region; its location changes as the viewport becomes shallower.
      const startY = Math.max(controlTop, region.y + (row.upper ? 48 : 0) - shift) + 2;
      const endY = Math.min(controlBottom, region.y + region.height - (row.upper ? 0 : 48) - shift) - 2;
      assert(endY - startY >= 50, `${row.owner}: opening leaves no useful visible first-token row.`);
      // Compare the actual painted row across its complete width, translated
      // only vertically. A +/-1 raster alignment tolerance handles fractional
      // layout coordinates; cropping the horizontal token strip cannot pass.
      const differences = [];
      for (const delta of [-1, 0, 1]) {
        let total = 0, samples = 0;
        const edge = { left: { total: 0, samples: 0 }, right: { total: 0, samples: 0 } };
        for (let y = Math.ceil(startY); y < endY; y += 3) for (let x = Math.ceil(region.x + 2); x < region.x + region.width - 2; x += 3) {
          const targetY = Math.round(y + shift) + delta;
          if (targetY < region.y + 1 || targetY >= region.y + region.height - 1) continue;
          const a = (y * before.png.width + x) * before.png.channels;
          const b = (targetY * after.width + x) * after.channels;
          const band = x < region.x + 18 ? edge.left : x > region.x + region.width - 18 ? edge.right : null;
          for (let channel = 0; channel < 3; channel++) {
            const difference = Math.abs(before.png.pixels[a + channel] - after.pixels[b + channel]);
            total += difference;
            if (band) { band.total += difference; band.samples++; }
          }
          samples += 3;
        }
        differences.push({ delta, samples, mean: total / samples,
          leftEdgeMean: edge.left.total / edge.left.samples, rightEdgeMean: edge.right.total / edge.right.samples });
      }
      const best = differences.reduce((a, b) => a.mean < b.mean ? a : b);
      assert(best.samples > 1000 && best.mean < 15,
        `${row.owner}: first-token pixels changed or clipped horizontally when the drawer opened (${JSON.stringify(differences)}).`);
      assert(best.leftEdgeMean < 15 && best.rightEdgeMean < 15,
        `${row.owner}: a token edge clipped despite the wider row matching (${JSON.stringify(best)}).`);
      results.push({ owner: row.owner, upper: row.upper, region, shift, seamInset: row.seamInset, differences, best });
    }
    evidence.twoPlayerTokenRows ||= [];
    evidence.twoPlayerTokenRows.push({ viewport, drawer, rows: results });
  }
  async function inspectDrawer(count, viewport) {
    evidence.viewport = { ...viewport, deviceScaleFactor: 1 };
    await cdp.send('Emulation.setDeviceMetricsOverride', { ...evidence.viewport, mobile: false });
    await sleep(300);
    await ensureDrawerCollapsed();
    const prefix = `22-drawer-${count}p-${viewport.width}x${viewport.height}`;
    await verifyLifeOverlayGeometry(`${count}-seat-drawer-before`, ['qa', 'Player 2', 'Player 3', 'Player 4'].slice(0, count), count === 4 ? ['qa'] : []);
    const before = await tableSnapshot();
    const closedMenu = await find('Game controls Collapsed', { startsWith: true, role: 'button' });
    await cdp.send('Input.dispatchMouseEvent', { type: 'mouseMoved',
      x: closedMenu.rect.x + closedMenu.rect.width / 2, y: closedMenu.rect.y + closedMenu.rect.height / 2 });
    const tokenRows = count === 2 ? await twoPlayerTokenBaseline(viewport, `${prefix}-populated-token-rows-before`) : null;
    const menuPng = await captureDrawerTransition(`${prefix}-opening`, () =>
      click('Game controls Collapsed', { startsWith: true, role: 'button', after: 0 }));
    const drawer = await identifierRect('game-drawer-workspace');
    const openMenu = await find('Game controls', { startsWith: true, role: 'button' });
    assert(drawer && drawer.width >= 220 && drawer.height >= 300, 'Drawer workflow has no usable viewport.');
    assert(Math.abs(openMenu.rect.width - closedMenu.rect.width) < .1 &&
      Math.abs(openMenu.rect.height - closedMenu.rect.height) < .1,
    'Menu button changed size or was sliced during drawer opening.');
    if (count === 2) {
      assert(drawer.width >= viewport.width - 2 && drawer.x <= 1,
        'The two-player drawer does not span the complete table width.');
      assert(openMenu.rect.y - closedMenu.rect.y > 20, 'Two-player Menu did not travel down with its wall.');
      assert(Math.abs(openMenu.rect.y + openMenu.rect.height / 2 - (drawer.y + drawer.height)) < 1,
        'The whole two-player Menu is not centered on the lower drawer wall.');
      assert(Math.abs(openMenu.rect.x + openMenu.rect.width / 2 - (viewport.width - 30)) < 1,
        'Two-player Menu left its lower-right wall position.');
    } else {
      assert(openMenu.rect.x - closedMenu.rect.x > 20, 'Menu did not travel right with the drawer edge.');
      assert(Math.abs(openMenu.rect.x + openMenu.rect.width / 2 - (drawer.x + drawer.width)) < 1,
        'The whole Menu is not centered on the right drawer wall.');
    }
    assert((await hitTarget(openMenu)).sameAction, 'The whole open Menu center is not actionable.');
    evidence.drawerGeometry ||= [];
    evidence.drawerGeometry.push({ players: count, viewport, drawer, menuClosed: closedMenu.rect, menuOpen: openMenu.rect });
    await verifyMenuPixels(menuPng, count, viewport, `${prefix}-opening-settled.png`);
    await verifyCutoutSurface(menuPng, `${count}-seat-dark`, { horizontal: count === 2 });
    if (tokenRows) await verifyTwoPlayerTokenRows(tokenRows, menuPng, drawer, viewport);
    await clickInDrawer('History', { role: 'button' });
    await findInDrawer('Back', { role: 'button' });
    await capture(`${prefix}-history`);
    await clickInDrawer('Back', { role: 'button' });
    await findInDrawer('Archives', { role: 'button' });
    await click('Close game drawer', { role: 'button' });
    await drawerClosed();
    assert.deepEqual(await tableSnapshot(), before, 'Token-space dismissal changed life or token state.');
    await capture(`${prefix}-dismissed-by-token-area`);
    // The edge Menu must work for another complete cycle without losing its
    // shape, its hit target, or the table's already-open token editor state.
    await click('Game controls', { startsWith: true, role: 'button' });
    await findInDrawer('Dice', { role: 'button' });
    await captureDrawerTransition(`${prefix}-closing`, () =>
      click('Game controls', { startsWith: true, role: 'button', after: 0 }));
    await drawerClosed();
    assert.deepEqual(await tableSnapshot(), before, 'Menu close changed life or token state.');
  }
  for (const viewport of [{ width: 1133, height: 744 }, { width: 744, height: 1133 }]) {
    await inspectDrawer(4, viewport);
  }

  evidence.viewport = { width: 1133, height: 744, deviceScaleFactor: 1 };
  await cdp.send('Emulation.setDeviceMetricsOverride', { ...evidence.viewport, mobile: false });
  await click('Game controls', { startsWith: true, role: 'button' });
  for (const [page, content] of [
    ['Archives', 'No archived games yet.'],
    ['Settings', 'Appearance theme'],
    ['New game', 'Starting life. Current value:'],
  ]) {
    await clickInDrawer(page, { role: 'button' });
    await findInDrawer(content, { startsWith: true });
    await captureGameView(`23-drawer-${page.toLowerCase().replaceAll(' ', '-')}`, { centered: page !== 'Settings' });
    if (page === 'New game') {
      await clickInDrawer('Starting life. Current value:', { startsWith: true, role: 'button' });
      await captureGameView('23-drawer-starting-life-keyboard');
      await clickInDrawer('Done', { role: 'button' });
      for (const action of ['Reset with current configuration', 'Complete reset']) {
        await scrollDrawerTo(action, { role: 'button' });
        await clickInDrawer(action, { role: 'button' });
        await captureGameView(`23-drawer-${action === 'Complete reset' ? 'complete-reset' : 'keep-board'}-confirmation`);
        await clickInDrawer('Cancel', { role: 'button' });
      }
    }
    if (page === 'Settings') {
      for (const [action, file] of [['Use bundled catalog', 'catalog'], ['Reset saved seat appearance', 'appearance']]) {
        await scrollDrawerTo(action, { role: 'button' });
        await clickInDrawer(action, { role: 'button' });
        await captureGameView(`23-drawer-${file}-confirmation`);
        await clickInDrawer('Cancel', { role: 'button' });
      }
      await scrollDrawerTo('Support this app', { role: 'button' });
      await clickInDrawer('Support this app', { role: 'button' });
      await findInDrawer('Always free to play');
      await captureGameView('23-drawer-support');
      await clickInDrawer('Back', { role: 'button' });
    }
    await clickInDrawer('Back', { role: 'button' });
    await findInDrawer('Board wipes', { role: 'button' });
  }
  await clickInDrawer('Board wipes', { role: 'button' });
  await captureGameView('23-drawer-wipe-chooser');
  await clickInDrawer('qa, Wipe creatures', { role: 'button' });
  await captureGameView('23-drawer-player-wipe-confirmation');
  await clickInDrawer('Cancel', { role: 'button' });
  await clickInDrawer('Everyone, Wipe creatures', { role: 'button' });
  await findInDrawer('Wipe all creatures for everyone?', { contains: true });
  await captureGameView('23-drawer-wipe-confirmation');
  await clickInDrawer('Wipe all creatures', { role: 'button' });
  await findInDrawer('Back', { role: 'button' });
  await clickInDrawer('Close workspace', { role: 'button' });
  await drawerClosed();
  assert(!(await semantics()).some(node => node.name.startsWith('qa, Scute Swarm, Name')), 'In-drawer wipe did not remove the creature.');
  await click('Game controls', { startsWith: true, role: 'button' });
  await clickInDrawer('History', { role: 'button' });
  await clickInDrawer('Undo latest:', { startsWith: true, role: 'button' });
  await captureGameView('23-drawer-history-restores-wipe', { list: true });
  await clickInDrawer('Close workspace', { role: 'button' });
  await drawerClosed();
  await find('qa, Scute Swarm, Name', { startsWith: true, role: 'button' });
  await expectLife('qa', 42);

  async function resetPlayers(count) {
    await click('Game controls', { startsWith: true, role: 'button' });
    await clickInDrawer('New game', { role: 'button' });
    await clickInDrawer(`${count} players`);
    await captureGameView(`24-drawer-new-game-${count}-players`);
    await scrollDrawerTo('Complete reset', { role: 'button' });
    await clickInDrawer('Complete reset', { role: 'button' });
    await scrollDrawerTo('Archive & complete reset', { role: 'button' });
    await clickInDrawer('Archive & complete reset', { role: 'button' });
    await drawerClosed();
    await expectLife('qa', 40);
    const names = (await semantics()).filter(node => node.role === 'button' && /, player details$/.test(node.name));
    assert.equal(names.length, count, `New game did not create the requested ${count}-seat layout.`);
  }
  async function restoreFourSeatArchive(fromCount) {
    await click('Game controls', { startsWith: true, role: 'button' });
    await clickInDrawer('Archives', { role: 'button' });
    await captureGameView(`24-drawer-populated-archives-from-${fromCount}`, { list: true });
    await clickInDrawer('4 players ·', { contains: true, role: 'button' });
    await scrollDrawerTo('Save current & restore', { role: 'button' });
    await captureGameView(`24-drawer-restore-archive-confirmation-from-${fromCount}`);
    await clickInDrawer('Save current & restore', { role: 'button' });
    await drawerClosed();
    await expectLife('qa', 42);
    await find('Player 4, player details');
    await find('qa, Scute Swarm, Name', { startsWith: true, role: 'button' });
  }
  for (const count of [2, 3]) {
    await resetPlayers(count);
    if (count === 2) {
      for (const name of ['qa', 'Player 2']) {
        await click(`${name}, add token`);
        await click('Search tokens, abilities, type, or P/T. Current value:', { contains: true, role: 'button' });
        await click('Select all');
        for (const letter of 'scute') await click(letter, { role: 'button' });
        await click('Done');
        await click('Scute Swarm', { startsWith: true });
        await click('Create tokens');
        await find(`${name}, Scute Swarm, Name`, { startsWith: true, role: 'button' });
      }
      await sleep(500);
      await click('qa, Scute Swarm, Name', { startsWith: true, role: 'button' });
      await find('qa, Scute Swarm, Choose artwork', { contains: true, role: 'button' });
      const originalName = await find('qa, Scute Swarm, Name', { startsWith: true, role: 'button' });
      const originalCopy = await find('qa, Scute Swarm, Copy one fresh token', { role: 'button' });
      // One wide expanded card can fit the closed two-seat lane. Create real
      // additional stacks so this probe has overflow instead of mistaking an
      // intentionally unscrollable short list for a product failure.
      for (let copy = 0; copy < 2; copy++) {
        await click('qa, Scute Swarm, Copy one fresh token', { role: 'button', backend: originalCopy.backend });
      }
      const rowBeforeScroll = await find('qa, Scute Swarm, Name', { startsWith: true, role: 'button', backend: originalName.backend });
      const wheel = { x: evidence.viewport.width * .3, y: evidence.viewport.height * .78 };
      await cdp.send('Input.dispatchMouseEvent', { type: 'mouseWheel', ...wheel, deltaX: 0, deltaY: 350 });
      await sleep(250);
      const rowAfterScroll = await find('qa, Scute Swarm, Name', {
        startsWith: true, role: 'button', backend: originalName.backend, timeout: 250,
      }).catch(() => null);
      assert(!rowAfterScroll || Math.abs(rowAfterScroll.rect.y - rowBeforeScroll.rect.y) > 20,
        'The two-player expanded token lane did not scroll through its real content.');
      await capture('22-two-player-expanded-token-scrolled');
      await cdp.send('Input.dispatchMouseEvent', { type: 'mouseWheel', ...wheel, deltaX: 0, deltaY: -1600 });
      await until('two-player first token row returns to its seam', async () => {
        // Lazy lists can recreate an offscreen DOM node. Find the first row at
        // its original seam coordinate, never a same-named later copy whose
        // partially clipped bounds happen to sort before the original.
        for (const node of (await semantics()).filter(node => node.role === 'button' && node.name.startsWith('qa, Scute Swarm, Name'))) {
          const rect = await bounds(node);
          if (rect && Math.abs(rect.x - rowBeforeScroll.rect.x) < 2 && Math.abs(rect.y - rowBeforeScroll.rect.y) < 2) return true;
        }
        return false;
      });
      evidence.twoPlayerTokenScroll = { originalNameBackend: originalName.backend, originalCopyBackend: originalCopy.backend,
        before: rowBeforeScroll.rect, after: rowAfterScroll?.rect ?? null, restored: true };
    }
    for (const viewport of [{ width: 1133, height: 744 }, { width: 744, height: 1133 }]) {
      await inspectDrawer(count, viewport);
    }
    await restoreFourSeatArchive(count);
  }
  await capture('24-restored-four-seat-table');
  log('PASS real drawer transitions, whole moving Menu, consumed token-space dismissal, repeated navigation, in-drawer wipe/History undo/new game/archive restore and 2/3/4-seat portrait/landscape');

  await click('Game controls Collapsed', { startsWith: true, role: 'button' });
  for (const theme of ['Light', 'Dark']) {
    await clickInDrawer('Settings', { role: 'button' });
    const body = await identifierRect('game-drawer-body-viewport');
    await cdp.send('Input.dispatchMouseEvent', { type: 'mouseWheel',
      x: body.x + body.width / 2, y: body.y + body.height / 2, deltaX: 0, deltaY: -2400 });
    await sleep(250);
    await clickInDrawer(theme);
    await selected(theme);
    await clickInDrawer('Back', { role: 'button' });
    for (const viewport of [{ width: 1133, height: 744 }, { width: 744, height: 1133 }]) {
      evidence.viewport = { ...viewport, deviceScaleFactor: 1 };
      await cdp.send('Emulation.setDeviceMetricsOverride', { ...evidence.viewport, mobile: false });
      await sleep(350);
      const name = `25-theme-${theme.toLowerCase()}-${viewport.width}x${viewport.height}`;
      const bytes = await capture(name);
      await verifyCutoutSurface(bytes, theme.toLowerCase());
      await verifyMenuPixels(bytes, 4, viewport, `${name}.png`);
    }
  }
  await clickInDrawer('Close workspace', { role: 'button' });
  log('PASS dark/light cutout surface pixels and attached Menu navigation in portrait and landscape');

  // With semantics enabled, Flutter3.41.2 buffers tappable pointerdown200ms
  // before the framework's500ms recognizer; durable publication adds latency.
  // Keep the750ms observation, but assert actual recognized clear + no trailing
  // change after release, not a brittle wall-clock threshold. Physical timing
  // remains a separate acceptance gate.
  assert(evidence.holds.every(hold => hold.clearObservedWhileHeld && hold.afterRelease === 'neither'), 'Observed mouse/touch hold did not clear and remain Neither; inspect hold snapshots, DOM event timeline and chronological history.');
  assert.equal(evidence.exceptions.length, 0, 'Unhandled browser runtime exceptions occurred; inspect evidence.json.');
  evidence.status = 'passed';
  }
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
