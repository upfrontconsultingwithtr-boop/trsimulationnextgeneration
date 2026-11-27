// Sims: avatar mesh, needs, vibes, autonomy (utility AI), social interactions, relationships.
import * as THREE from 'three';
import { NEEDS, NEED_KEYS, VIBES, WALK_SPEED, TRAITS, SKILLS } from './config.js';
import { CATALOG, toWorld, toTile } from './world.js';

const M = (c) => new THREE.MeshStandardMaterial({ color: c, roughness: 0.6 });
export const HAIR = ['buzz', 'bob', 'puff', 'long', 'spikes', 'bun'];
export const SKIN = ['#ffe0c7', '#f1c27d', '#d9a066', '#b37548', '#8d5524', '#5c3a1e'];

export function buildAvatar(look) {
  const g = new THREE.Group(), h = look.height || 1, b = look.build || 1;
  const limb = (r, len, col) => { const p = new THREE.Group(), m = new THREE.Mesh(new THREE.CapsuleGeometry(r, len, 4, 10), M(col)); m.position.y = -len / 2 - r; m.castShadow = true; p.add(m); return p; };
  const body = new THREE.Group(); g.add(body); body.scale.set(b, h, b);
  const torso = new THREE.Mesh(new THREE.CapsuleGeometry(0.2, 0.38, 6, 14), M(look.top)); torso.position.y = 1.08; torso.castShadow = true; body.add(torso);
  const hips = new THREE.Mesh(new THREE.CylinderGeometry(0.2, 0.21, 0.2, 14), M(look.bottom)); hips.position.y = 0.8; body.add(hips);
  const head = new THREE.Group(); head.position.y = 1.58; body.add(head);
  const skull = new THREE.Mesh(new THREE.SphereGeometry(0.23, 24, 18), M(look.skin)); skull.castShadow = true; head.add(skull);
  for (const s of [-1, 1]) { const e = new THREE.Mesh(new THREE.SphereGeometry(0.035, 10, 8), M('#1a1a2a')); e.position.set(s * 0.08, 0.03, 0.2); head.add(e); }
  const hm = M(look.hair), hs = look.hairStyle;
  const addH = (geo, x, y, z, sx = 1, sy = 1, sz = 1) => { const m = new THREE.Mesh(geo, hm); m.position.set(x, y, z); m.scale.set(sx, sy, sz); m.castShadow = true; head.add(m); };
  if (hs === 'buzz') addH(new THREE.SphereGeometry(0.24, 20, 12, 0, Math.PI * 2, 0, 1.3), 0, 0.01, -0.01);
  if (hs === 'bob') { addH(new THREE.SphereGeometry(0.26, 20, 14, 0, Math.PI * 2, 0, 1.9), 0, 0.02, -0.03); }
  if (hs === 'puff') addH(new THREE.IcosahedronGeometry(0.3, 2), 0, 0.14, -0.04, 1, 0.9, 1);
  if (hs === 'long') { addH(new THREE.SphereGeometry(0.26, 20, 14, 0, Math.PI * 2, 0, 1.6), 0, 0.02, -0.02); addH(new THREE.BoxGeometry(0.46, 0.5, 0.15), 0, -0.2, -0.16); }
  if (hs === 'spikes') for (let k = 0; k < 9; k++) addH(new THREE.ConeGeometry(0.06, 0.22, 6), Math.cos(k) * 0.12, 0.22, Math.sin(k) * 0.12 - 0.03);
  if (hs === 'bun') { addH(new THREE.SphereGeometry(0.245, 20, 12, 0, Math.PI * 2, 0, 1.4), 0, 0.01, -0.01); addH(new THREE.SphereGeometry(0.12, 12, 10), 0, 0.25, -0.12); }
  const armL = limb(0.07, 0.42, look.top), armR = limb(0.07, 0.42, look.top); armL.position.set(-0.29, 1.36, 0); armR.position.set(0.29, 1.36, 0);
  const legL = limb(0.085, 0.5, look.bottom), legR = limb(0.085, 0.5, look.bottom); legL.position.set(-0.1, 0.78, 0); legR.position.set(0.1, 0.78, 0);
  body.add(armL, armR, legL, legR);
  // vibe ring: soft glowing disc under the sim, coloured by current vibe
  const ring = new THREE.Mesh(new THREE.RingGeometry(0.35, 0.55, 32), new THREE.MeshBasicMaterial({ color: '#fff', transparent: true, opacity: 0.45, depthWrite: false }));
  ring.rotation.x = -Math.PI / 2; ring.position.y = 0.03; g.add(ring);
  g.userData.parts = { body, head, armL, armR, legL, legR, ring };
  return g;
}

let simCounter = 0;
export class Sim {
  constructor({ name, look, traits = [], id, remote = false }) {
    this.id = id || 's' + simCounter++ + Math.random().toString(36).slice(2, 6);
    this.name = name; this.look = look; this.traits = traits; this.remote = remote;
    this.needs = Object.fromEntries(NEED_KEYS.map((k) => [k, 70 + Math.random() * 25]));
    this.skills = {}; this.rel = {}; this.queue = []; this.current = null; this.path = null;
    this.vibe = 'neutral'; this.vibeTimer = 0; this.money = 0; this.followers = 0; this.autonomy = true;
    this.mesh = buildAvatar(look); this.mesh.traverse((m) => (m.userData.sim = this));
    this.pos = new THREE.Vector3(); this.heading = 0; this.anim = 0; this.pose = 'stand'; this.bubble = '';
  }
  setTile(i, j) { this.pos.set(toWorld(i), 0, toWorld(j)); this.mesh.position.copy(this.pos); }
  tile() { return [toTile(this.pos.x), toTile(this.pos.z)]; }
  has(t) { return this.traits.includes(t); }
  mood() { const avg = NEED_KEYS.reduce((a, k) => a + this.needs[k], 0) / NEED_KEYS.length; const low = Math.min(...NEED_KEYS.map((k) => this.needs[k])); return Math.round(avg * 0.6 + low * 0.4); }
  setVibe(v, mins = 180) { this.vibe = v; this.vibeTimer = mins; }
  relWith(id) { return (this.rel[id] ||= { friend: 0, romance: 0, name: '' }); }
  skillUp(k, amt) { this.skills[k] = Math.min(10, (this.skills[k] || 0) + amt); }
  enqueue(action) { if (this.queue.length < 5) this.queue.push(action); }
  cancel() { this.queue = []; this.current = null; this.path = null; this.pose = 'stand'; }
}

// Social interactions: base friendship/romance deltas, requirements, need effects.
export const SOCIALS = [
  { id: 'chat', label: 'Chat', icon: '💬', f: 6, r: 0, req: () => true },
  { id: 'joke', label: 'Tell a Joke', icon: '😂', f: 9, r: 0, req: () => true, fun: 10, risk: 0.25 },
  { id: 'compliment', label: 'Compliment', icon: '🌟', f: 8, r: 2, req: (rel) => rel.friend > 5 },
  { id: 'selfie', label: 'Take a Selfie', icon: '🤳', f: 7, r: 0, req: (rel) => rel.friend > 15, fun: 12, post: true },
  { id: 'hug', label: 'Hug', icon: '🤗', f: 12, r: 3, req: (rel) => rel.friend > 30 },
  { id: 'dance', label: 'Dance Together', icon: '💃', f: 10, r: 4, req: (rel) => rel.friend > 20, fun: 20 },
  { id: 'flirt', label: 'Flirt', icon: '😘', f: 2, r: 10, req: (rel) => rel.friend > 25, risk: 0.3, trait: 'romantic' },
  { id: 'kiss', label: 'Kiss', icon: '💋', f: 4, r: 15, req: (rel) => rel.romance > 40, risk: 0.15, trait: 'romantic' },
  { id: 'date', label: 'Ask to Be Partners', icon: '💞', f: 10, r: 25, req: (rel) => rel.romance > 70 && !rel.partner, risk: 0.2, partner: true },
  { id: 'argue', label: 'Argue', icon: '🗯️', f: -14, r: -6, req: () => true, angry: true },
];

// Resolve a social between a and b. Returns outcome for UI/network.
export function resolveSocial(a, b, sid, rand = Math.random()) {
  const s = SOCIALS.find((x) => x.id === sid); if (!s) return null;
  const ra = a.relWith(b.id), rb = b.relWith(a.id);
  let chance = 0.75 + (a.skills.charisma || 0) * 0.03 + (b.mood() - 50) / 200 - (s.risk || 0);
  if (a.has('outgoing')) chance += 0.08; if (s.trait && a.has(s.trait)) chance += 0.12;
  if (b.vibe === 'angry') chance -= 0.25; if (b.vibe === 'flirty' && s.r > 0) chance += 0.15;
  const ok = s.angry ? true : rand < chance, k = ok ? 1 : -0.6;
  for (const [r, other] of [[ra, b], [rb, a]]) { r.friend = clamp(r.friend + s.f * k, -100, 100); r.romance = clamp(r.romance + s.r * k, 0, 100); r.name = other.name; }
  if (ok && s.partner) ra.partner = rb.partner = true;
  for (const x of [a, b]) { x.needs.social = clamp(x.needs.social + (ok ? 14 : 4), 0, 100); if (s.fun) x.needs.fun = clamp(x.needs.fun + s.fun, 0, 100); }
  if (s.angry) { a.setVibe('angry', 90); b.setVibe(b.has('chill') ? 'neutral' : 'angry', b.has('chill') ? 10 : 120); }
  else if (ok && s.r >= 10) { a.setVibe('flirty'); b.setVibe('flirty'); }
  else if (ok) { a.setVibe('happy', 120); } else { a.setVibe('tense', 60); }
  a.skillUp('charisma', 0.08);
  return { ok, social: s, friend: ra.friend, romance: ra.romance, partner: ok && s.partner };
}
export const clamp = (v, a, b) => Math.max(a, Math.min(b, v));

// Utility AI: pick the best advertised action for a sim.
export function chooseAction(sim, world, sims) {
  let best = null, bestScore = 0;
  const [si, sj] = sim.tile();
  const urgency = (k) => { const v = sim.needs[k]; return Math.pow((100 - v) / 100, 2) * 3 + 0.05; };
  for (const o of world.objects.values()) {
    if ((o.busy && o.busy !== sim.id) || (sim.homeLot !== undefined && o.lot !== sim.homeLot && o.lot !== 'plaza')) continue;
    for (const act of CATALOG[o.type].acts) {
      let score = 0;
      for (const [k, v] of Object.entries(act.adv)) if (v > 0) score += urgency(k) * Math.min(v, 100 - sim.needs[k] + 10) / 30;
      if (act.trait && sim.has(act.trait)) score *= 1.5;
      if (act.pay && sim.mood() > 55) score += 0.12 * (sim.has('ambitious') ? 2 : 1);
      if (act.id === 'sleep' && sim.needs.energy > 45) score *= 0.1;
      if (act.cost && sim.money < act.cost) continue;
      const dist = Math.hypot(o.i - si, o.j - sj);
      score /= 1 + dist / 18;
      score *= 0.8 + Math.random() * 0.4;
      if (score > bestScore) { bestScore = score; best = { kind: 'object', obj: o, act }; }
    }
  }
  // socialising
  const socialU = urgency('social') * (sim.has('outgoing') ? 1.6 : 1);
  for (const other of sims) {
    if (other === sim || other.remote) continue;
    const dist = sim.pos.distanceTo(other.pos); if (dist > 22) continue;
    const s = socialU * 2.2 / (1 + dist / 10) * (0.8 + Math.random() * 0.4);
    if (s > bestScore) { bestScore = s; best = { kind: 'social', target: other, sid: pickSocial(sim, other) }; }
  }
  return best;
}
export function pickSocial(a, b) {
  const rel = a.relWith(b.id), ok = SOCIALS.filter((s) => s.req(rel) && s.id !== 'argue' && s.id !== 'date');
  if (a.vibe === 'angry' && Math.random() < 0.5) return 'argue';
  if (a.has('romantic') && ok.some((s) => s.id === 'flirt') && Math.random() < 0.4) return 'flirt';
  return ok[Math.floor(Math.random() * ok.length)].id;
}

// Per-frame update for a locally simulated sim. gm = game minutes elapsed, rdt = real dt * speed.
export function updateSim(sim, gm, rdt, world, sims, events) {
  const p = sim.mesh.userData.parts;
  // needs decay
  for (const k of NEED_KEYS) { let d = NEEDS[k].decay; if (k === 'social' && sim.has('outgoing')) d *= 1.4; if (k === 'hygiene' && sim.has('neat')) d *= 1.2; sim.needs[k] = clamp(sim.needs[k] - d * gm / 60, 0, 100); }
  if ((sim.vibeTimer -= gm * (sim.has('chill') ? 2 : 1)) <= 0 && sim.vibe !== 'neutral') sim.vibe = 'neutral';
  if (sim.vibe === 'neutral') { if (sim.needs.fun < 20) sim.vibe = 'bored'; else if (sim.mood() < 25) sim.vibe = 'sad'; else if (sim.mood() > 80) sim.vibe = 'happy'; }
  // emotional contagion: strong vibes spread to nearby sims (original mechanic)
  if (['happy', 'inspired', 'angry', 'energized', 'flirty'].includes(sim.vibe)) for (const o of sims) if (o !== sim && !o.remote && o.vibe === 'neutral' && o.pos.distanceTo(sim.pos) < 3 && Math.random() < gm * 0.01) { o.setVibe(sim.vibe, 45); events.push({ type: 'contagion', a: sim, b: o }); }

  // action state machine
  if (!sim.current && sim.queue.length) { sim.current = sim.queue.shift(); sim.current.stage = 'walk'; sim.path = null; }
  if (!sim.current && sim.autonomy && Math.random() < 0.02) { const a = chooseAction(sim, world, sims); if (a) { sim.current = a; a.stage = 'walk'; a.auto = true; if (a.obj) a.obj.busy = sim.id; } }
  const cur = sim.current;
  let moving = false;
  if (cur) {
    if (cur.stage === 'walk') {
      let target;
      if (cur.kind === 'object') { if (!world.objects.has(cur.obj.id)) { sim.current = null; return; } target = world.useSpot(cur.obj); }
      else if (cur.kind === 'social') target = cur.target.tile();
      else if (cur.kind === 'goto') target = cur.tile;
      if (!sim.path) { const [i, j] = sim.tile(); sim.path = world.path(i, j, target[0], target[1]) || []; sim.path.shift(); if (!sim.path.length && Math.hypot(i - target[0], j - target[1]) > 1.5 && cur.kind !== 'goto') { sim.bubble = '❓'; sim.current = null; return; } }
      if (cur.kind === 'social' && sim.pos.distanceTo(cur.target.pos) < 1.6) sim.path = [];
      if (sim.path.length) {
        const [ti, tj] = sim.path[0], tx = toWorld(ti), tz = toWorld(tj), dx = tx - sim.pos.x, dz = tz - sim.pos.z, dist = Math.hypot(dx, dz), step = WALK_SPEED * rdt;
        sim.heading = Math.atan2(dx, dz); moving = true;
        if (dist <= step) { sim.pos.x = tx; sim.pos.z = tz; sim.path.shift(); } else { sim.pos.x += dx / dist * step; sim.pos.z += dz / dist * step; }
      } else {
        if (cur.kind === 'goto') { sim.current = null; }
        else if (cur.kind === 'object') { if (cur.obj.busy && cur.obj.busy !== sim.id) { sim.current = null; sim.bubble = '😤'; return; } cur.obj.busy = sim.id; cur.stage = 'do'; cur.left = cur.act.mins; sim.pose = cur.act.pose || 'use'; const m = cur.obj.mesh.position; sim.heading = Math.atan2(m.x - sim.pos.x, m.z - sim.pos.z); if (cur.act.pose) { sim.pos.set(m.x, 0, m.z); sim.heading = cur.obj.mesh.rotation.y * -1 + 0; } if (cur.act.cost) sim.money -= cur.act.cost; }
        else { cur.stage = 'do'; cur.left = 20; sim.heading = Math.atan2(cur.target.pos.x - sim.pos.x, cur.target.pos.z - sim.pos.z); events.push({ type: 'social', a: sim, b: cur.target, sid: cur.sid }); }
      }
    } else if (cur.stage === 'do') {
      cur.left -= gm;
      if (cur.kind === 'object') {
        const a = cur.act; for (const [k, v] of Object.entries(a.adv)) sim.needs[k] = clamp(sim.needs[k] + v * gm / 60 * (a.trait && sim.has(a.trait) && v > 0 ? 1.25 : 1), 0, 100);
        if (a.skill) sim.skillUp(a.skill, gm / 60 * 0.35 * (a.trait && sim.has(a.trait) ? 1.5 : 1));
        sim.bubble = a.skill ? SKILLS[a.skill].icon : NEEDS[Object.keys(a.adv)[0]]?.icon || '✨';
        const full = a.id === 'sleep' && sim.needs.energy >= 99;
        if (cur.left <= 0 || full) {
          if (a.pay) { const pay = Math.round(a.pay * (1 + (sim.skills[a.skill] || 0) * 0.25) * (sim.has('ambitious') ? 1.3 : 1)); sim.money += pay; events.push({ type: 'earn', sim, amount: pay, act: a }); }
          if (a.followers) { const f = Math.round(5 + (sim.skills.charisma || 0) * 12 * Math.random()); sim.followers += f; events.push({ type: 'post', sim, text: `${sim.name} went live and gained ${f} followers 📈` }); }
          if (a.vibe) sim.setVibe(a.vibe, 150);
          if (a.id === 'sleep') sim.setVibe('energized', 120);
          if (a.id === 'paint' && Math.random() < 0.3) events.push({ type: 'post', sim, text: `${sim.name} finished a painting 🎨` });
          finish(sim);
        }
      } else if (cur.left <= 0) finish(sim);
    }
  } else if (Math.random() < 0.003 && sim.autonomy) { // idle wander
    const [i, j] = sim.tile(); const ti = i + Math.floor(Math.random() * 7) - 3, tj = j + Math.floor(Math.random() * 7) - 3;
    if (!world.isBlocked(ti, tj)) sim.current = { kind: 'goto', tile: [ti, tj], stage: 'walk' };
  }
  animate(sim, moving, rdt);
}
function finish(sim) { const c = sim.current; if (c?.obj) c.obj.busy = null; sim.current = null; sim.pose = 'stand'; sim.bubble = ''; sim.path = null; }

export function animate(sim, moving, rdt) {
  const p = sim.mesh.userData.parts; sim.anim += rdt * (moving ? 9 : 2);
  const sw = moving ? Math.sin(sim.anim) * 0.7 : 0;
  p.legL.rotation.x = sw; p.legR.rotation.x = -sw; p.armL.rotation.x = -sw * 0.8; p.armR.rotation.x = sw * 0.8;
  p.body.position.y = moving ? Math.abs(Math.sin(sim.anim)) * 0.05 : Math.sin(sim.anim) * 0.01;
  p.body.rotation.x = 0; p.body.position.z = 0;
  if (sim.pose === 'sit') { p.legL.rotation.x = p.legR.rotation.x = -1.4; p.body.position.y = -0.35; }
  if (sim.pose === 'lie') { p.body.rotation.x = -Math.PI / 2; p.body.position.y = 0.55; p.body.position.z = 0.7; }
  if (sim.pose === 'use') { p.armL.rotation.x = p.armR.rotation.x = -1.0 + Math.sin(sim.anim * 3) * 0.15; }
  if (sim.current?.kind === 'social' && sim.current.stage === 'do') { p.armR.rotation.z = Math.sin(sim.anim * 4) * 0.4 + 0.3; } else p.armR.rotation.z = 0;
  p.ring.material.color.set(VIBES[sim.vibe].color); p.ring.material.opacity = sim.vibe === 'neutral' ? 0.15 : 0.5 + Math.sin(sim.anim * 2) * 0.15;
  sim.mesh.position.lerp(sim.pos, sim.remote ? 0.2 : 1);
  let dh = sim.heading - sim.mesh.rotation.y; dh = Math.atan2(Math.sin(dh), Math.cos(dh)); sim.mesh.rotation.y += dh * Math.min(1, rdt * 10);
}

export function randomLook() {
  const pick = (a) => a[Math.floor(Math.random() * a.length)];
  return { skin: pick(SKIN), hair: pick(['#1d1a17', '#5a3a22', '#c8a26b', '#e6e1d6', '#d0452c', '#7c4dff', '#ff6fb1', '#35c3ff']), hairStyle: pick(HAIR), top: pick(['#ff6b6b', '#4ecdc4', '#ffe66d', '#7c6cff', '#2d3142', '#f7fff7', '#ff9f1c', '#3a86ff']), bottom: pick(['#22223b', '#4a4e69', '#3d405b', '#1b998b', '#8d6346', '#e0e0e0']), height: 0.92 + Math.random() * 0.16, build: 0.9 + Math.random() * 0.25 };
}
export function randomTraits(n = 3) { return Object.keys(TRAITS).sort(() => Math.random() - 0.5).slice(0, n); }
export const NPC_NAMES = ['Nova Reyes', 'Kai Okafor', 'Mila Chen', 'Jaden Brooks', 'Sage Patel', 'River Kim', 'Zuri Adeyemi', 'Leo Moreau', 'Aria Silva', 'Theo Nakamura', 'Imani Cole', 'Ezra Lind'];
