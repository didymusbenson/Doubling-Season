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
async function find(name, { startsWith = false, contains = false, role, within, timeout = 30000 } = {}) {
  return until(`visible semantic control ${JSON.stringify(name)}`, async () => {
    const nodes = (await semantics()).filter(node => matches(node, name, startsWith, contains) && !node.disabled && (!role || node.role === role));
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
  let interior = 0, text = 0;
  for (let y = Math.max(0, Math.ceil(rect.y + 8)); y < Math.min(png.height, rect.y + rect.height - 8); y++) {
    for (let x = Math.max(0, Math.ceil(rect.x + 8)); x < Math.min(png.width, rect.x + rect.width - 8); x++) {
      const i = (y * png.width + x) * png.channels;
      const [r, g, b] = png.pixels.subarray(i, i + 3);
      const a = png.channels === 4 ? png.pixels[i + 3] : 255;
      // The dark-theme menu has green labels/icons and neutral surfaces and
      // borders. Exclude the outer stroke and transparent RGBA pixels. The
      // right-of-center sample excludes the leading icon as well.
      if (a > 150 && g > 100 && g - r > 12 && g - b > 5) {
        interior++;
        if (x > rect.x + rect.width / 2 + 2) text++;
      }
    }
  }
  return { interior, text };
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
    assert(pixels.interior > 40 && pixels.text > 12,
      `Rendered ${label} label/icon is missing at ${players} seats, ${viewport.width}×${viewport.height}: ${JSON.stringify(pixels)}`);
    labels.push({ label, rect: target.rect, ...pixels });
  }
  evidence.drawerMenuPixels ||= [];
  evidence.drawerMenuPixels.push({ players, viewport, file, labels });
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
  await clickInDrawer('Roll dice', { role: 'button' });
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

  // Exercise the relocated statuses and immediate-life route in the real
  // release build, without injecting state or relying on widget-only fixtures.
  await click('qa, commander damage ', { startsWith: true, role: 'button' });
  await find('Add counter', { role: 'button' });
  for (const status of ['Monarch', 'City’s blessing', 'Initiative']) {
    await click(`${status}, Off`, { contains: true, role: 'switch' });
    await find(`${status}, On`, { contains: true, role: 'switch' });
  }
  await click('Add counter', { role: 'button' });
  await click('Enable energy', { role: 'button' });
  await click('Increase energy', { startsWith: true, role: 'button' });
  await click('Increase energy', { startsWith: true, role: 'button' });
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
  async function inspectDrawer(count, viewport) {
    evidence.viewport = { ...viewport, deviceScaleFactor: 1 };
    await cdp.send('Emulation.setDeviceMetricsOverride', { ...evidence.viewport, mobile: false });
    await sleep(300);
    await ensureDrawerCollapsed();
    const prefix = `22-drawer-${count}p-${viewport.width}x${viewport.height}`;
    const before = await tableSnapshot();
    const closedMenu = await find('Game controls Collapsed', { startsWith: true, role: 'button' });
    const menuPng = await captureDrawerTransition(`${prefix}-opening`, () =>
      click('Game controls Collapsed', { startsWith: true, role: 'button', after: 0 }));
    const drawer = await identifierRect('game-drawer-workspace');
    const openMenu = await find('Game controls', { startsWith: true, role: 'button' });
    assert(drawer && drawer.width >= 220 && drawer.height >= 300, 'Drawer workflow has no usable viewport.');
    assert(Math.abs(openMenu.rect.width - closedMenu.rect.width) < .1 &&
      Math.abs(openMenu.rect.height - closedMenu.rect.height) < .1,
    'Menu button changed size or was sliced during drawer opening.');
    assert(Math.abs(openMenu.rect.x - closedMenu.rect.x) > 20, 'Menu did not travel with the drawer edge.');
    assert((await hitTarget(openMenu)).sameAction, 'The whole open Menu center is not actionable.');
    evidence.drawerGeometry ||= [];
    evidence.drawerGeometry.push({ players: count, viewport, drawer, menuClosed: closedMenu.rect, menuOpen: openMenu.rect });
    await verifyMenuPixels(menuPng, count, viewport, `${prefix}-opening-settled.png`);
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
    await capture(`23-drawer-${page.toLowerCase().replaceAll(' ', '-')}`);
    if (page === 'Settings') {
      await scrollDrawerTo('Support this app', { role: 'button' });
      await clickInDrawer('Support this app', { role: 'button' });
      await findInDrawer('Support Tripling Table', { contains: true });
      await capture('23-drawer-support');
      await clickInDrawer('Back', { role: 'button' });
    }
    await clickInDrawer('Back', { role: 'button' });
    await findInDrawer('Board wipes', { role: 'button' });
  }
  await clickInDrawer('Board wipes', { role: 'button' });
  await clickInDrawer('Wipe all creatures', { role: 'button' });
  await findInDrawer('Wipe all creatures for everyone?', { contains: true });
  await capture('23-drawer-wipe-confirmation');
  await clickInDrawer('Wipe all creatures', { role: 'button' });
  await findInDrawer('Back', { role: 'button' });
  await clickInDrawer('Close workspace', { role: 'button' });
  await drawerClosed();
  assert(!(await semantics()).some(node => node.name.startsWith('qa, Scute Swarm, Name')), 'In-drawer wipe did not remove the creature.');
  await click('Game controls', { startsWith: true, role: 'button' });
  await clickInDrawer('History', { role: 'button' });
  await clickInDrawer('Undo latest:', { startsWith: true, role: 'button' });
  await capture('23-drawer-history-restores-wipe');
  await clickInDrawer('Close workspace', { role: 'button' });
  await drawerClosed();
  await find('qa, Scute Swarm, Name', { startsWith: true, role: 'button' });
  await expectLife('qa', 42);

  async function resetPlayers(count) {
    await click('Game controls', { startsWith: true, role: 'button' });
    await clickInDrawer('New game', { role: 'button' });
    await clickInDrawer(`${count} players`);
    await scrollDrawerTo('Complete reset', { role: 'button' });
    await clickInDrawer('Complete reset', { role: 'button' });
    await scrollDrawerTo('Archive & complete reset', { role: 'button' });
    await clickInDrawer('Archive & complete reset', { role: 'button' });
    await drawerClosed();
    await expectLife('qa', 40);
    const names = (await semantics()).filter(node => node.role === 'button' && /, player details$/.test(node.name));
    assert.equal(names.length, count, `New game did not create the requested ${count}-seat layout.`);
  }
  async function restoreFourSeatArchive() {
    await click('Game controls', { startsWith: true, role: 'button' });
    await clickInDrawer('Archives', { role: 'button' });
    await clickInDrawer('4 players ·', { contains: true, role: 'button' });
    await scrollDrawerTo('Save current & restore', { role: 'button' });
    await capture('24-drawer-restore-archive-confirmation');
    await clickInDrawer('Save current & restore', { role: 'button' });
    await drawerClosed();
    await expectLife('qa', 42);
    await find('Player 4, player details');
    await find('qa, Scute Swarm, Name', { startsWith: true, role: 'button' });
  }
  for (const count of [2, 3]) {
    await resetPlayers(count);
    for (const viewport of [{ width: 1133, height: 744 }, { width: 744, height: 1133 }]) {
      await inspectDrawer(count, viewport);
    }
    await restoreFourSeatArchive();
  }
  await capture('24-restored-four-seat-table');
  log('PASS real drawer transitions, whole moving Menu, consumed token-space dismissal, repeated navigation, in-drawer wipe/History undo/new game/archive restore and 2/3/4-seat portrait/landscape');

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
