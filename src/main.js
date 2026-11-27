// NextGen Life — entry: renderer, camera, day/night, UI, game loop, save, online.
import * as THREE from 'three';
import { OrbitControls } from 'three/examples/jsm/controls/OrbitControls.js';
import { EffectComposer } from 'three/examples/jsm/postprocessing/EffectComposer.js';
import { RenderPass } from 'three/examples/jsm/postprocessing/RenderPass.js';
import { UnrealBloomPass } from 'three/examples/jsm/postprocessing/UnrealBloomPass.js';
import { OutputPass } from 'three/examples/jsm/postprocessing/OutputPass.js';
import { NEEDS, NEED_KEYS, SKILLS, TRAITS, VIBES, SAVE_KEY, STARTING_MONEY, ONLINE_MINUTES_PER_SEC } from './config.js';
import { World, CATALOG, buildFurniture, toWorld, toTile } from './world.js';
import { Sim, buildAvatar, updateSim, animate, resolveSocial, SOCIALS, randomLook, randomTraits, NPC_NAMES, HAIR, SKIN, clamp } from './sim.js';
import { Net } from './net.js';

// ---------- Renderer ----------
const canvas = document.getElementById('c');
const renderer = new THREE.WebGLRenderer({ canvas, antialias: true, preserveDrawingBuffer: true });
renderer.setPixelRatio(Math.min(devicePixelRatio, 2));
renderer.shadowMap.enabled = true; renderer.shadowMap.type = THREE.PCFSoftShadowMap;
renderer.toneMapping = THREE.ACESFilmicToneMapping; renderer.toneMappingExposure = 1.05;
const scene = new THREE.Scene(); scene.fog = new THREE.Fog('#9cc8ff', 45, 120);
const camera = new THREE.PerspectiveCamera(45, 1, 0.1, 400); camera.position.set(-10, 18, 2);
const controls = new OrbitControls(camera, canvas);
controls.mouseButtons = { LEFT: null, MIDDLE: THREE.MOUSE.PAN, RIGHT: THREE.MOUSE.ROTATE };
controls.touches = { ONE: THREE.TOUCH.ROTATE, TWO: THREE.TOUCH.DOLLY_PAN };
controls.enableDamping = true; controls.maxPolarAngle = 1.3; controls.minDistance = 4; controls.maxDistance = 60; controls.screenSpacePanning = false;
const hemi = new THREE.HemisphereLight('#cfe6ff', '#4b5d3a', 0.9); scene.add(hemi);
const sun = new THREE.DirectionalLight('#fff3dd', 2.4); sun.castShadow = true; sun.shadow.mapSize.set(2048, 2048);
Object.assign(sun.shadow.camera, { left: -40, right: 40, top: 40, bottom: -40, far: 150 }); sun.shadow.bias = -0.0004; sun.shadow.normalBias = 0.03; scene.add(sun, sun.target);
const composer = new EffectComposer(renderer); composer.addPass(new RenderPass(scene, camera));
const bloom = new UnrealBloomPass(new THREE.Vector2(1, 1), 0.35, 0.6, 0.85); composer.addPass(bloom); composer.addPass(new OutputPass());
let quality = 'high';
function resize() { const w = innerWidth, h = innerHeight; renderer.setSize(w, h, false); composer.setSize(w, h); camera.aspect = w / h; camera.updateProjectionMatrix(); }
addEventListener('resize', resize); resize();

// ---------- State ----------
const world = new World(scene); world.generate();
const net = new Net({});
const G = { mode: 'title', sims: [], me: null, minutes: 8 * 60, speed: 1, feed: [], online: false, myLot: null, startedAt: 0, goals: [], day: 0, build: null, cut: true, photo: false, follow: true };
const $ui = document.getElementById('ui'), $labels = document.getElementById('labels');
const h = (html) => { const d = document.createElement('div'); d.innerHTML = html.trim(); return d.firstChild; };
const esc = (s) => String(s).replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
let toastT; function toast(t) { document.querySelector('.toast')?.remove(); const el = h(`<div class="toast panel">${t}</div>`); $ui.append(el); clearTimeout(toastT); toastT = setTimeout(() => el.remove(), 2800); }
function post(text, share = true) { G.feed.unshift({ name: G.me?.name || '', text, at: Date.now() }); G.feed = G.feed.slice(0, 60); if (share && G.online) net.send({ t: 'post', text }); renderSide(); }

// ---------- Sky / day-night ----------
const skyDay = new THREE.Color('#9cc8ff'), skyDusk = new THREE.Color('#ff9a76'), skyNight = new THREE.Color('#0c1030'), tmp = new THREE.Color();
const lampLights = []; for (let k = 0; k < 3; k++) { const l = new THREE.PointLight('#ffcf88', 0, 9, 1.6); scene.add(l); lampLights.push(l); }
function updateSky() {
  const hr = (G.minutes / 60) % 24, ang = ((hr - 6) / 24) * Math.PI * 2, el = Math.sin(ang);
  sun.position.set(Math.cos(ang) * 50, Math.max(el, 0.05) * 60 + 5, 20); sun.target.position.set(0, 0, 0);
  const day = clamp(el * 3 + 0.3, 0, 1), dusk = clamp(1 - Math.abs(el) * 4, 0, 1);
  tmp.copy(skyNight).lerp(skyDay, day).lerp(skyDusk, dusk * 0.6); scene.background = tmp.clone(); scene.fog.color.copy(tmp);
  sun.intensity = 2.6 * day; sun.color.set(dusk > 0.4 ? '#ffb27a' : '#fff3dd'); hemi.intensity = 0.25 + day * 0.75;
  const night = 1 - day; bloom.strength = 0.3 + night * 0.6;
  for (const o of world.objects.values()) if (o.type === 'lamp' || o.type === 'booth') o.mesh.traverse((m) => m.material?.emissive && m.material.emissiveIntensity > 0.5 && (m.material.emissiveIntensity = 0.6 + night * 2.5));
  // nearest lamps to the camera get real lights
  const lamps = [...world.objects.values()].filter((o) => o.type === 'lamp').sort((a, b) => a.mesh.position.distanceTo(controls.target) - b.mesh.position.distanceTo(controls.target));
  lampLights.forEach((l, k) => { const o = lamps[k]; l.intensity = o ? night * 6 : 0; if (o) l.position.copy(o.mesh.position).setY(1.6); });
}

// ---------- Wall cutaway ----------
const v1 = new THREE.Vector3();
function updateWalls() {
  for (const w of world.walls) {
    v1.subVectors(w.position, w.userData.lotCenter).setY(0).normalize();
    const camDir = new THREE.Vector3().subVectors(camera.position, w.userData.lotCenter).setY(0).normalize();
    const low = G.cut && v1.dot(camDir) > 0.35, s = low ? 0.12 : 1;
    w.scale.y += (s - w.scale.y) * 0.2; w.position.y = (2.7 * w.scale.y) / 2;
  }
}

// ---------- Sims ----------
function addSim(sim, i, j) { sim.setTile(i, j); scene.add(sim.mesh); G.sims.push(sim); sim.tagEl = h(`<div class="tag"><span class="b"></span><span class="n"></span></div>`); $labels.append(sim.tagEl); return sim; }
function removeSim(sim) { scene.remove(sim.mesh); sim.tagEl.remove(); G.sims = G.sims.filter((s) => s !== sim); }
const pv = new THREE.Vector3();
function updateTags() {
  for (const s of G.sims) {
    pv.copy(s.mesh.position).setY(2.15 * (s.look.height || 1)).project(camera);
    const vis = pv.z < 1 && Math.abs(pv.x) < 1.1 && Math.abs(pv.y) < 1.1 && s.mesh.position.distanceTo(camera.position) < 45 && !G.photo;
    s.tagEl.style.display = vis ? '' : 'none'; if (!vis) continue;
    s.tagEl.style.left = (pv.x * 0.5 + 0.5) * innerWidth + 'px'; s.tagEl.style.top = (-pv.y * 0.5 + 0.5) * innerHeight + 'px';
    const b = s.chat && s.chatT > performance.now() ? `💬 ${esc(s.chat)}` : s.bubble || VIBES[s.vibe].emoji;
    s.tagEl.querySelector('.b').innerHTML = b; s.tagEl.querySelector('.b').style.fontSize = s.chatT > performance.now() ? '13px' : '20px';
    s.tagEl.querySelector('.n').textContent = s.name + (s.remote ? ' 🌐' : s === G.me ? ' ⭐' : '');
  }
}

// ---------- Events from the sim layer ----------
function handleEvents(evts) {
  for (const e of evts) {
    if (e.type === 'social') {
      if (e.b.remote) { const ok = Math.random() < 0.8; const rel = e.a.relWith(e.b.id); applySocialDelta(rel, e.sid, ok, e.b.name); e.a.needs.social = clamp(e.a.needs.social + 14, 0, 100); net.send({ t: 'social', to: e.b.id, sid: e.sid, ok }); toast(`${SOCIALS.find((s) => s.id === e.sid).icon} ${e.a.name} → ${e.b.name}: ${ok ? 'it landed!' : 'awkward…'}`); goalTick('social'); continue; }
      const r = resolveSocial(e.a, e.b, e.sid); if (!r) continue;
      e.b.bubble = ''; e.b.heading = Math.atan2(e.a.pos.x - e.b.pos.x, e.a.pos.z - e.b.pos.z);
      if (e.a === G.me || e.b === G.me) { toast(`${r.social.icon} ${e.a.name} → ${e.b.name}: ${r.ok ? 'it landed!' : 'awkward…'}`); goalTick('social'); if (r.friend > 30 && !e.a.relWith(e.b.id).postedFriend) { e.a.relWith(e.b.id).postedFriend = true; post(`${e.a.name} and ${e.b.name} are now friends 🤝`); goalTick('friend'); } if (r.partner) post(`${e.a.name} 💞 ${e.b.name} — it's official!`); if (r.social.post && r.ok) post(`${e.a.name} took a selfie with ${e.b.name} 🤳`); }
      e.a.bubble = r.social.icon;
    }
    if (e.type === 'earn' && e.sim === G.me) { toast(`+$${e.amount} from ${e.act.label}`); goalTick('earn', e.amount); }
    if (e.type === 'post' && e.sim === G.me) post(e.text);
    if (e.type === 'contagion' && (e.a === G.me || e.b === G.me)) toast(`${VIBES[e.a.vibe].emoji} ${e.a.name}'s ${VIBES[e.a.vibe].label} vibe spread to ${e.b.name}`);
  }
}
function applySocialDelta(rel, sid, ok, name) { const s = SOCIALS.find((x) => x.id === sid); if (!s) return; const k = s.angry ? 1 : ok ? 1 : -0.6; rel.friend = clamp(rel.friend + s.f * k, -100, 100); rel.romance = clamp(rel.romance + s.r * k, 0, 100); rel.name = name; if (ok && s.partner) rel.partner = true; }

// ---------- Daily goals ----------
const GOAL_POOL = [
  { id: 'social', text: 'Have 4 social interactions', n: 4 }, { id: 'earn', text: 'Earn $300', n: 300 }, { id: 'friend', text: 'Make a new friend', n: 1 },
  { id: 'skill', text: 'Gain a skill level', n: 1 }, { id: 'build', text: 'Place 2 new items at home', n: 2 }, { id: 'fun', text: 'Get Fun above 90', n: 1 },
];
function newGoals() { G.goals = GOAL_POOL.slice().sort(() => Math.random() - 0.5).slice(0, 3).map((g) => ({ ...g, p: 0, done: false })); }
function goalTick(id, amt = 1) { for (const g of G.goals) if (g.id === id && !g.done) { g.p += amt; if (g.p >= g.n) { g.done = true; G.me.money += 250; toast(`🏆 Goal complete: ${g.text} (+$250)`); post(`${G.me.name} smashed a daily goal: ${g.text} 🏆`, true); } } renderSide(); }

// ---------- Title + Character Creator ----------
function titleScreen() {
  const saved = loadSave();
  const el = h(`<div class="title"><div class="card panel" style="padding:28px">
    <h1>NextGen Life</h1><div style="opacity:.8">Build a life. Share a neighborhood. Spread the vibe.</div>
    ${saved ? `<button class="on" id="cont">▶ Continue as ${esc(saved.me.name)}</button>` : ''}
    <button ${saved ? '' : 'class="on"'} id="new">✨ Create a New Sim</button>
    <div class="lbl">Tip: online play connects to the shared neighborhood server when it's running.</div></div></div>`);
  $ui.append(el);
  el.querySelector('#new').onclick = () => { el.remove(); creator(); };
  el.querySelector('#cont')?.addEventListener('click', () => { el.remove(); startGame(saved.me, 'solo', saved); });
}

function creator() {
  const look = randomLook(), d = { name: NPC_NAMES[Math.floor(Math.random() * NPC_NAMES.length)].split(' ')[0] + ' ' + ['Vega', 'Stone', 'Rivers', 'Lux'][Math.floor(Math.random() * 4)], look, traits: randomTraits() };
  // preview avatar standing in the plaza
  let preview; const refresh = () => { if (preview) scene.remove(preview); preview = buildAvatar(d.look); preview.position.set(0, 0, 4); preview.rotation.y = 0.4; scene.add(preview); };
  refresh(); controls.target.set(0, 1, 4); camera.position.set(1.2, 2, 8.5);
  const sw = (key, list) => `<div class="row">${list.map((c) => `<button data-k="${key}" data-v="${c}" style="width:26px;height:26px;padding:0;background:${c}"></button>`).join('')}<input type="color" data-k="${key}" value="${d.look[key]}"></div>`;
  const el = h(`<div class="panel" style="position:fixed;left:16px;top:16px;bottom:16px;width:min(360px,92vw);overflow:auto;display:grid;gap:10px;align-content:start">
    <h2 style="margin:0">Create Your Sim</h2>
    <div class="lbl">Name</div><input id="nm" value="${esc(d.name)}" maxlength="24">
    <div class="lbl">Skin</div>${sw('skin', SKIN)}
    <div class="lbl">Hair style</div><div class="row">${HAIR.map((x) => `<button data-hs="${x}">${x}</button>`).join('')}</div>
    <div class="lbl">Hair colour</div>${sw('hair', ['#1d1a17', '#5a3a22', '#c8a26b', '#e6e1d6', '#d0452c', '#7c4dff', '#ff6fb1', '#35c3ff'])}
    <div class="lbl">Top</div>${sw('top', ['#ff6b6b', '#4ecdc4', '#ffe66d', '#7c6cff', '#2d3142', '#f7fff7', '#ff9f1c'])}
    <div class="lbl">Bottom</div>${sw('bottom', ['#22223b', '#4a4e69', '#1b998b', '#8d6346', '#e0e0e0'])}
    <div class="lbl">Height</div><input type="range" min="0.85" max="1.15" step="0.01" id="ht" value="${d.look.height}">
    <div class="lbl">Build</div><input type="range" min="0.85" max="1.25" step="0.01" id="bd" value="${d.look.build}">
    <div class="lbl">Traits (pick 3)</div><div class="row" id="tr"></div>
    <div class="row"><button id="rnd">🎲 Randomize</button></div>
    <button class="on" id="solo">🏡 Play Solo</button><button id="onl">🌐 Join Online Neighborhood</button><div id="err" class="lbl"></div></div>`);
  $ui.append(el);
  const drawTraits = () => { el.querySelector('#tr').innerHTML = Object.entries(TRAITS).map(([k, t]) => `<button title="${t.desc}" data-t="${k}" class="${d.traits.includes(k) ? 'on' : ''}">${t.icon} ${t.label}</button>`).join(''); };
  drawTraits();
  el.onclick = (e) => {
    const b = e.target.closest('button'); if (!b) return;
    if (b.dataset.k) { d.look[b.dataset.k] = b.dataset.v; refresh(); }
    if (b.dataset.hs) { d.look.hairStyle = b.dataset.hs; refresh(); }
    if (b.dataset.t) { const t = b.dataset.t; d.traits = d.traits.includes(t) ? d.traits.filter((x) => x !== t) : [...d.traits, t].slice(-3); drawTraits(); }
    if (b.id === 'rnd') { Object.assign(d.look, randomLook()); d.traits = randomTraits(); drawTraits(); refresh(); }
    if (b.id === 'solo' || b.id === 'onl') { d.name = el.querySelector('#nm').value.trim() || 'Sim'; scene.remove(preview); el.remove(); startGame(d, b.id === 'onl' ? 'online' : 'solo'); }
  };
  el.oninput = (e) => { if (e.target.type === 'color') d.look[e.target.dataset.k] = e.target.value; if (e.target.id === 'ht') d.look.height = +e.target.value; if (e.target.id === 'bd') d.look.build = +e.target.value; refresh(); };
}

// ---------- Start game ----------
async function startGame(d, mode, saved) {
  const me = new Sim({ name: d.name, look: d.look, traits: d.traits, id: d.id }); me.money = d.money ?? STARTING_MONEY; me.autonomy = false;
  if (d.needs) Object.assign(me.needs, d.needs); if (d.skills) me.skills = d.skills; if (d.rel) me.rel = d.rel; me.followers = d.followers || 0;
  G.me = me;
  if (mode === 'online') {
    try {
      const token = localStorage.getItem('ngl-token') || Math.random().toString(36).slice(2); localStorage.setItem('ngl-token', token);
      const w = await net.connect({ token, name: me.name, look: me.look, traits: me.traits });
      G.online = true; G.startedAt = w.start; G.feed = w.feed.reverse(); G.selfNetId = w.id;
      for (const l of w.lots) { const lot = world.lots.find((x) => x.id === l.id); lot.owner = l.owner; if (l.owner) { world.buildHouse(lot, '#e8eef6', false); for (const o of l.objects) world.addObject({ ...o, lot: lot.id }); } }
      G.myLot = world.lots.find((l) => l.id === w.lot) || null;
      if (G.myLot && w.lots.find((l) => l.id === w.lot).objects.length === 0) { const before = new Set(world.objects.keys()); furnish(G.myLot); net.send({ t: 'build', op: 'sync', lot: G.myLot.id, objects: [...world.objects.values()].filter((o) => !before.has(o.id)).map(ser) }); }
      for (const p of w.players) addRemote(p);
      Object.assign(net.h, netHandlers);
      toast(`🌐 Joined Neighborhood #${w.room}${G.myLot ? '' : ' (all lots taken — you are visiting)'}`);
    } catch (e) { toast('Online server not reachable — starting solo. See README to host one free.'); mode = 'solo'; }
  }
  if (mode === 'solo') {
    G.myLot = world.lots[0];
    if (saved?.objects) { world.buildHouse(G.myLot, '#f1e6d8', false); for (const o of saved.objects) world.addObject(o); } else world.buildHouse(G.myLot);
    G.minutes = saved?.minutes ?? 8 * 60;
    // NPC townies with their own homes
    for (let k = 1; k <= 4; k++) { const lot = world.lots[k]; world.buildHouse(lot, ['#ffe3e3', '#e3f1ff', '#e9ffe3', '#fff3d6'][k - 1]); lot.owner = NPC_NAMES[k]; }
  }
  // townies (local in both modes)
  const nNpc = mode === 'solo' ? 6 : 3;
  for (let k = 0; k < nNpc; k++) { const npc = new Sim({ name: NPC_NAMES[(k + 3) % NPC_NAMES.length], look: randomLook(), traits: randomTraits(), id: 'npc' + k }); npc.money = 500; npc.homeLot = k < 4 && mode === 'solo' ? world.lots[k + 1].id : null; const sp = spawnTile(k < 4 && mode === 'solo' ? world.lots[k + 1] : null); addSim(npc, ...sp); const sr = saved?.npcs?.[npc.id]; if (sr) { Object.assign(npc.needs, sr.needs); npc.rel = sr.rel; } }
  const sp = G.myLot ? [G.myLot.house.door[0], G.myLot.house.door[1] + 1] : [30, 28];
  addSim(me, ...sp); if (saved?.me?.pos) me.setTile(...saved.me.pos);
  G.goals = saved?.goals || []; if (!G.goals.length) newGoals(); G.day = Math.floor(G.minutes / 1440);
  G.mode = 'live'; buildHUD(); controls.target.copy(me.pos); camera.position.set(me.pos.x - 10, 14, me.pos.z + 10);
  if (!saved) post(`${me.name} moved into the neighborhood 🏡`);
}
function spawnTile(lot) { for (let t = 0; t < 200; t++) { const i = lot ? lot.x + Math.floor(Math.random() * lot.w) : 25 + Math.floor(Math.random() * 14), j = lot ? lot.z + Math.floor(Math.random() * lot.d) : 25 + Math.floor(Math.random() * 14); if (!world.isBlocked(i, j)) return [i, j]; } return [26, 26]; }
function furnish(lot) { world.buildHouse(lot, '#e8eef6', true); }
const ser = (o) => ({ id: o.id, type: o.type, i: o.i, j: o.j, rot: o.rot, color: o.color || '', lot: o.lot });

// ---------- Online handlers ----------
const remotes = new Map();
function addRemote(p) { if (remotes.has(p.id)) return; const s = new Sim({ name: p.name, look: p.look || randomLook(), traits: p.traits, id: p.id, remote: true }); s.autonomy = false; addSim(s, 30, 28); if (p.state) { s.pos.set(p.state.x, 0, p.state.z); s.mesh.position.copy(s.pos); } remotes.set(p.id, s); }
const netHandlers = {
  join: (m) => { addRemote(m.p); toast(`👋 ${esc(m.p.name)} joined the neighborhood`); },
  leave: (m) => { const s = remotes.get(m.id); if (s) { removeSim(s); remotes.delete(m.id); } },
  state: (m) => { const s = remotes.get(m.id); if (!s) return; const moved = Math.hypot(m.s.x - s.pos.x, m.s.z - s.pos.z) > 0.02; s.pos.set(m.s.x, 0, m.s.z); s.heading = m.s.h; s.pose = m.s.pose; s.vibe = VIBES[m.s.vibe] ? m.s.vibe : 'neutral'; s.bubble = m.s.bubble; s.netMoving = moved; },
  chat: (m) => { const s = m.id === G.selfNetId ? G.me : remotes.get(m.id); if (s) { s.chat = m.text; s.chatT = performance.now() + 6000; } chatLog(`<b>${esc(m.name)}</b>: ${esc(m.text)}`); },
  social: (m) => { const s = remotes.get(m.from); if (!s) return; applySocialDelta(G.me.relWith(s.id), m.sid, m.ok, s.name); G.me.needs.social = clamp(G.me.needs.social + 12, 0, 100); const so = SOCIALS.find((x) => x.id === m.sid); toast(`${so?.icon} ${esc(s.name)} → you: ${so?.label}`); renderSide(); },
  post: (m) => { G.feed.unshift(m.p); renderSide(); },
  build: (m) => { if (m.op === 'add') world.addObject({ ...m.o, lot: m.lot }); else world.removeObject(m.id); },
  lot: (m) => { const lot = world.lots.find((l) => l.id === m.lot); if (!lot.owner) { lot.owner = m.owner; world.buildHouse(lot, '#e8eef6', false); } for (const o of [...world.objects.values()]) if (o.lot === m.lot) world.removeObject(o.id); for (const o of m.objects) world.addObject({ ...o, lot: m.lot }); },
  disconnect: () => { G.online = false; toast('Disconnected from server'); },
};
function chatLog(html) { const l = document.querySelector('.chat .log'); if (!l) return; l.insertAdjacentHTML('beforeend', `<div>${html}</div>`); l.scrollTop = 1e9; }

// ---------- HUD ----------
let $needs, $top, $queue, $side, sideTab = 'goals';
function buildHUD() {
  $top = h(`<div class="top panel"><button id="live" class="on">🧍 Live</button><button id="buildb">🛠️ Build</button><span class="clock"></span>
    ${G.online ? '' : `<button data-sp="0">⏸</button><button data-sp="1" class="on">▶</button><button data-sp="3">⏩</button><button data-sp="10">⏭</button>`}
    <span id="money" class="chip panel"></span><button id="cut" title="Toggle walls (C)">🧱</button><button id="photo" title="Photo mode (P)">📸</button><button id="q" title="Graphics quality">✨</button><button id="savebtn" title="Save">💾</button></div>`);
  $needs = h(`<div class="needs panel"></div>`); $queue = h(`<div class="queue"></div>`); $side = h(`<div class="side panel"></div>`);
  $ui.append($top, $needs, $queue, $side);
  if (G.online) { const c = h(`<div class="chat panel"><div class="log"></div><input placeholder="Say something… (Enter)" maxlength="160" style="width:100%"></div>`); $ui.append(c); const inp = c.querySelector('input'); inp.onkeydown = (e) => { e.stopPropagation(); if (e.key === 'Enter' && inp.value.trim()) { net.send({ t: 'chat', text: inp.value.trim() }); inp.value = ''; } }; }
  $top.onclick = (e) => {
    const b = e.target.closest('button'); if (!b) return;
    if (b.dataset.sp) { G.speed = +b.dataset.sp; $top.querySelectorAll('[data-sp]').forEach((x) => x.classList.toggle('on', x === b)); }
    if (b.id === 'live') setMode('live'); if (b.id === 'buildb') setMode('build');
    if (b.id === 'cut') { G.cut = !G.cut; b.classList.toggle('on', !G.cut); }
    if (b.id === 'photo') photoMode();
    if (b.id === 'q') { quality = quality === 'high' ? 'low' : 'high'; renderer.setPixelRatio(quality === 'high' ? Math.min(devicePixelRatio, 2) : 1); renderer.shadowMap.enabled = quality === 'high'; scene.traverse((m) => m.material && (m.material.needsUpdate = true)); resize(); toast(`Graphics: ${quality}`); }
    if (b.id === 'savebtn') { save(); toast('💾 Saved'); }
  };
  renderSide(); setInterval(renderHUD, 250);
}
function renderHUD() {
  const me = G.me, hr = Math.floor(G.minutes / 60) % 24, mn = Math.floor(G.minutes % 60), day = Math.floor(G.minutes / 1440) + 1;
  $top.querySelector('.clock').textContent = `Day ${day} · ${String(hr % 12 || 12)}:${String(mn).padStart(2, '0')} ${hr < 12 ? 'AM' : 'PM'}`;
  $top.querySelector('#money').textContent = `$${me.money.toLocaleString()} · ${me.followers} 👥`;
  const v = VIBES[me.vibe];
  $needs.innerHTML = `<div class="row" style="justify-content:space-between"><b>${esc(me.name)}</b><span class="chip" style="background:${v.color}33">${v.emoji} ${v.label}</span></div>
    <div class="lbl" style="margin:4px 0">Mood ${me.mood()} · ${me.traits.map((t) => TRAITS[t]?.icon).join(' ')}</div>
    ${NEED_KEYS.map((k) => `<div class="need"><span style="width:76px">${NEEDS[k].icon} ${NEEDS[k].label}</span><div class="bar"><i style="width:${me.needs[k]}%;background:${me.needs[k] < 25 ? '#ff5a4f' : NEEDS[k].color}"></i></div></div>`).join('')}
    <label class="lbl"><input type="checkbox" id="auto" ${me.autonomy ? 'checked' : ''}> Free will</label>`;
  $needs.querySelector('#auto').onchange = (e) => (me.autonomy = e.target.checked);
  const items = [me.current, ...me.queue].filter(Boolean);
  $queue.innerHTML = items.map((a, k) => `<button class="${k ? '' : 'on'}" data-k="${k}">${a.kind === 'object' ? a.act.label : a.kind === 'social' ? SOCIALS.find((s) => s.id === a.sid)?.icon + ' ' + a.target.name : '🚶 Walk'} ✕</button>`).join('');
  $queue.onclick = (e) => { const b = e.target.closest('button'); if (!b) return; const k = +b.dataset.k; if (k === 0) { if (me.current?.obj) me.current.obj.busy = null; me.current = null; me.path = null; me.pose = 'stand'; me.bubble = ''; } else me.queue.splice(k - 1, 1); };
  if (G.me.needs.fun > 90) goalTick('fun');
}
function renderSide() {
  if (!$side) return; const me = G.me;
  const tabs = `<div class="row" style="margin-bottom:8px">${['goals', 'people', 'skills', 'feed'].map((t) => `<button data-tab="${t}" class="${t === sideTab ? 'on' : ''}">${{ goals: '🏆', people: '❤️', skills: '📈', feed: '📰' }[t]}</button>`).join('')}</div>`;
  let body = '';
  if (sideTab === 'goals') body = `<div class="lbl">Daily goals</div>` + G.goals.map((g) => `<div class="need">${g.done ? '✅' : '⬜'} ${g.text} <span class="lbl">${Math.min(g.p, g.n)}/${g.n}</span></div>`).join('');
  if (sideTab === 'people') body = `<div class="lbl">Relationships</div>` + (Object.values(me.rel).filter((r) => r.name).sort((a, b) => b.friend - a.friend).map((r) => `<div style="margin:6px 0"><b>${esc(r.name)}</b> ${r.partner ? '💞' : ''}<div class="need">🤝<div class="bar"><i style="width:${(r.friend + 100) / 2}%;background:${r.friend < 0 ? '#ff5a4f' : '#7ee08a'}"></i></div></div><div class="need">💗<div class="bar"><i style="width:${r.romance}%;background:#ff7eb6"></i></div></div></div>`).join('') || '<div class="lbl">Go meet someone! Click a sim.</div>');
  if (sideTab === 'skills') body = Object.entries(SKILLS).map(([k, s]) => `<div class="need"><span style="width:96px">${s.icon} ${s.label}</span><div class="bar"><i style="width:${(me.skills[k] || 0) * 10}%;background:#9d8cff"></i></div><span class="lbl">${Math.floor(me.skills[k] || 0)}</span></div>`).join('');
  if (sideTab === 'feed') body = `<div class="lbl">Neighborhood Feed</div><div class="feed">${G.feed.map((p) => `<div>${esc(p.text)}</div>`).join('') || '<div>Nothing yet…</div>'}</div>`;
  $side.innerHTML = tabs + body;
  $side.onclick = (e) => { const b = e.target.closest('[data-tab]'); if (b) { sideTab = b.dataset.tab; renderSide(); } };
}

// ---------- Interaction menus ----------
const ray = new THREE.Raycaster(), mouse = new THREE.Vector2();
function pick(e) { mouse.set((e.clientX / innerWidth) * 2 - 1, -(e.clientY / innerHeight) * 2 + 1); ray.setFromCamera(mouse, camera); return ray.intersectObjects(scene.children, true).find((x) => x.object.visible && x.object.type === 'Mesh' && !(x.object.geometry.type === 'RingGeometry')); }
function groundTile(e) { mouse.set((e.clientX / innerWidth) * 2 - 1, -(e.clientY / innerHeight) * 2 + 1); ray.setFromCamera(mouse, camera); const p = new THREE.Vector3(); ray.ray.intersectPlane(new THREE.Plane(new THREE.Vector3(0, 1, 0), 0), p); return p ? [toTile(p.x), toTile(p.z)] : null; }
function menu(x, y, items) {
  document.querySelector('.menu')?.remove(); if (!items.length) return;
  const el = h(`<div class="menu panel" style="left:${x}px;top:${y}px">${items.map((it, k) => `<button data-k="${k}" ${it.disabled ? 'disabled style="opacity:.4"' : ''}>${it.label}</button>`).join('')}</div>`);
  $ui.append(el); el.onclick = (e) => { const b = e.target.closest('button'); if (b && !b.disabled) { items[+b.dataset.k].fn(); el.remove(); } };
}
let downAt = null;
canvas.addEventListener('pointerdown', (e) => { if (e.button === 0) downAt = [e.clientX, e.clientY]; });
canvas.addEventListener('pointerup', (e) => {
  if (e.button !== 0 || !downAt || Math.hypot(e.clientX - downAt[0], e.clientY - downAt[1]) > 6 || G.mode === 'title') return;
  document.querySelector('.menu')?.remove();
  if (G.mode === 'build') return buildClick(e);
  const hit = pick(e), me = G.me;
  const sim = hit?.object.userData.sim, obj = hit?.object.userData.obj;
  if (sim && sim !== me) {
    const rel = me.relWith(sim.id);
    return menu(e.clientX, e.clientY, SOCIALS.map((s) => ({ label: `${s.icon} ${s.label}`, disabled: !s.req(rel), fn: () => me.enqueue({ kind: 'social', target: sim, sid: s.id }) })));
  }
  if (obj && CATALOG[obj.type].acts.length) return menu(e.clientX, e.clientY, CATALOG[obj.type].acts.map((a) => ({ label: `${a.label}${a.pay ? ` 💵` : ''}`, fn: () => me.enqueue({ kind: 'object', obj, act: a }) })));
  const t = groundTile(e); if (t && !world.isBlocked(...t)) me.enqueue({ kind: 'goto', tile: t });
});

// ---------- Build mode ----------
let ghost = null, $cat = null;
function setMode(m) {
  G.mode = m; $top.querySelector('#live').classList.toggle('on', m === 'live'); $top.querySelector('#buildb').classList.toggle('on', m === 'build');
  $cat?.remove(); if (ghost) { scene.remove(ghost); ghost = null; } G.build = null;
  $needs.style.display = $queue.style.display = m === 'build' ? 'none' : '';
  if (m !== 'build') return;
  if (!G.myLot) { toast('You need a lot to build. (Online lots full — try another time!)'); return setMode('live'); }
  controls.target.set(toWorld(G.myLot.x + G.myLot.w / 2), 0, toWorld(G.myLot.z + G.myLot.d / 2));
  $cat = h(`<div class="catalog panel">${Object.entries(CATALOG).filter(([, d]) => !d.hidden).map(([k, d]) => `<button data-t="${k}">${d.name}<br><span class="lbl">$${d.price}</span></button>`).join('')}<button data-t="sell">🗑️ Sell</button><input type="color" id="col" title="Colour"><span class="lbl">R = rotate</span></div>`);
  $ui.append($cat);
  $cat.onclick = (e) => { const b = e.target.closest('button'); if (!b) return; $cat.querySelectorAll('button').forEach((x) => x.classList.toggle('on', x === b)); if (ghost) scene.remove(ghost); ghost = null; G.build = { type: b.dataset.t, rot: 0, color: null }; if (b.dataset.t !== 'sell') { ghost = buildFurniture(b.dataset.t); ghost.traverse((m) => m.material && (m.material = m.material.clone(), (m.material.transparent = true), (m.material.opacity = 0.6))); scene.add(ghost); } };
  $cat.querySelector('#col').oninput = (e) => { if (G.build) G.build.color = e.target.value; };
}
const onMyLot = (i, j) => { const l = G.myLot; return l && i >= l.x && j >= l.z && i < l.x + l.w && j < l.z + l.d; };
canvas.addEventListener('pointermove', (e) => {
  if (G.mode !== 'build' || !ghost || !G.build) return; const t = groundTile(e); if (!t) return;
  const o = { type: G.build.type, i: t[0], j: t[1], rot: G.build.rot }, [w, d] = world.footprint(o);
  ghost.position.set(toWorld(t[0]) + (w - 1) / 2, 0, toWorld(t[1]) + (d - 1) / 2); ghost.rotation.y = -G.build.rot * Math.PI / 2;
  const ok = onMyLot(t[0], t[1]) && onMyLot(t[0] + w - 1, t[1] + d - 1) && world.canPlace(o.type, ...t, o.rot);
  ghost.traverse((m) => m.material?.emissive && m.material.emissive.set(ok ? '#004400' : '#660000'));
});
function buildClick(e) {
  if (!G.build) return;
  if (G.build.type === 'sell') { const o = pick(e)?.object.userData.obj; if (o && o.lot === G.myLot.id) { world.removeObject(o.id); G.me.money += Math.round(CATALOG[o.type].price * 0.75); net.send({ t: 'build', op: 'remove', lot: o.lot, id: o.id }); toast(`Sold ${CATALOG[o.type].name}`); } return; }
  const t = groundTile(e); if (!t) return; const def = CATALOG[G.build.type], o = { type: G.build.type, i: t[0], j: t[1], rot: G.build.rot, color: G.build.color, lot: G.myLot.id }, [w, d] = world.footprint(o);
  if (!(onMyLot(t[0], t[1]) && onMyLot(t[0] + w - 1, t[1] + d - 1) && world.canPlace(o.type, ...t, o.rot))) return toast("Can't place there");
  if (G.me.money < def.price) return toast('Not enough money — try a freelance gig on the PC!');
  G.me.money -= def.price; world.addObject(o); net.send({ t: 'build', op: 'add', lot: o.lot, o: ser(o) }); goalTick('build');
}

// ---------- Keys ----------
const keys = {};
addEventListener('keydown', (e) => {
  if (e.target.tagName === 'INPUT') return; keys[e.key.toLowerCase()] = true;
  if (e.key === 'r' && G.build) { G.build.rot = (G.build.rot + 1) % 4; canvas.dispatchEvent(new PointerEvent('pointermove', { clientX: lastMouse[0], clientY: lastMouse[1] })); }
  if (e.key === 'c') G.cut = !G.cut; if (e.key === 'p') photoMode(); if (e.key === 'b' && G.mode !== 'title') setMode(G.mode === 'build' ? 'live' : 'build');
  if (e.key === 'f') G.follow = !G.follow; if (e.key === 'Escape') { document.querySelector('.menu')?.remove(); if (G.mode === 'build') setMode('live'); }
  if (!G.online && '0123'.includes(e.key) && G.mode !== 'title') G.speed = [0, 1, 3, 10][+e.key];
});
addEventListener('keyup', (e) => (keys[e.key.toLowerCase()] = false));
let lastMouse = [0, 0]; addEventListener('pointermove', (e) => (lastMouse = [e.clientX, e.clientY]));
function photoMode() { G.photo = !G.photo; $ui.style.display = G.photo ? 'none' : ''; if (G.photo) { toast('📸 Photo mode — press P again to exit, S to save'); setTimeout(() => ($ui.style.display = 'none')); } }
addEventListener('keydown', (e) => { if (G.photo && e.key === 's') { const a = document.createElement('a'); a.download = 'nextgen-life.png'; a.href = canvas.toDataURL('image/png'); a.click(); } });

// ---------- Save ----------
function save() {
  if (G.online || !G.me) return; const me = G.me;
  const npcs = Object.fromEntries(G.sims.filter((s) => s.id.startsWith('npc')).map((s) => [s.id, { needs: s.needs, rel: s.rel }]));
  localStorage.setItem(SAVE_KEY, JSON.stringify({ me: { id: me.id, name: me.name, look: me.look, traits: me.traits, needs: me.needs, skills: me.skills, rel: me.rel, money: me.money, followers: me.followers, pos: me.tile() }, objects: [...world.objects.values()].filter((o) => o.lot === G.myLot.id).map(ser), minutes: G.minutes, goals: G.goals, npcs }));
}
function loadSave() { try { return JSON.parse(localStorage.getItem(SAVE_KEY)); } catch { return null; } }
setInterval(() => G.mode !== 'title' && save(), 30000); addEventListener('beforeunload', save);

// ---------- Main loop ----------
const clock = new THREE.Clock(); let netT = 0, skillSnap = 0;
function loop() {
  requestAnimationFrame(loop);
  const dt = Math.min(clock.getDelta(), 0.1);
  if (G.mode !== 'title' && G.me) {
    const sp = G.online ? ONLINE_MINUTES_PER_SEC : G.speed, gm = dt * sp, rdt = dt * (G.online ? 1 : Math.min(G.speed, 4));
    if (G.online) G.minutes = 8 * 60 + (Date.now() - G.startedAt) / 1000 * ONLINE_MINUTES_PER_SEC; else G.minutes += gm;
    const events = [];
    for (const s of G.sims) { if (s.remote) { animate(s, s.netMoving, dt); continue; } if (gm > 0) updateSim(s, gm, rdt, world, G.sims, events); }
    handleEvents(events);
    const day = Math.floor(G.minutes / 1440); if (day !== G.day) { G.day = day; newGoals(); renderSide(); toast('🌅 New day — new goals!'); }
    const lv = Object.values(G.me.skills).reduce((a, b) => a + Math.floor(b), 0); if (lv > skillSnap) { if (skillSnap) { goalTick('skill'); toast('📈 Skill level up!'); } skillSnap = lv; }
    if (G.online && (netT += dt) > 0.15) { netT = 0; const m = G.me; net.send({ t: 'state', x: +m.pos.x.toFixed(2), z: +m.pos.z.toFixed(2), h: +m.heading.toFixed(2), pose: m.pose, vibe: m.vibe, bubble: m.bubble }); }
    // camera: WASD pan + gentle follow
    const fwd = new THREE.Vector3().subVectors(controls.target, camera.position).setY(0).normalize(), right = new THREE.Vector3().crossVectors(fwd, camera.up), mv = new THREE.Vector3();
    if (keys.w || keys.arrowup) mv.add(fwd); if (keys.s && !G.photo || keys.arrowdown) mv.sub(fwd); if (keys.d || keys.arrowright) mv.add(right); if (keys.a || keys.arrowleft) mv.sub(right);
    if (mv.lengthSq()) { G.follow = false; mv.normalize().multiplyScalar(dt * 18); controls.target.add(mv); camera.position.add(mv); }
    else if (G.follow && G.mode === 'live') { const d = new THREE.Vector3().subVectors(G.me.mesh.position, controls.target).setY(0).multiplyScalar(Math.min(1, dt * 2)); controls.target.add(d); camera.position.add(d); }
    updateSky(); updateWalls(); updateTags();
  }
  controls.update();
  quality === 'high' ? composer.render() : renderer.render(scene, camera);
}
updateSky(); titleScreen(); loop();
window.__G = G; // debug handle
