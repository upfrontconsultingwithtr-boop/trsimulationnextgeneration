// World: tile grid, lots, procedural houses, furniture catalog, pathfinding.
import * as THREE from 'three';
import { WORLD_SIZE as N, WALL_HEIGHT } from './config.js';

export const toWorld = (i) => i - N / 2 + 0.5;
export const toTile = (x) => Math.floor(x + N / 2);
const M = (c, o = {}) => new THREE.MeshStandardMaterial({ color: c, roughness: 0.75, ...o });

// --- Furniture catalog. adv = need restore per game-hour while using. ---
export const CATALOG = {
  bed:     { name: 'Cloud Bed', price: 900, w: 2, d: 2, color: '#8fb3ff', acts: [{ id: 'sleep', label: 'Sleep', mins: 420, adv: { energy: 14 }, pose: 'lie' }, { id: 'nap', label: 'Nap', mins: 90, adv: { energy: 12 }, pose: 'lie' }] },
  fridge:  { name: 'Smart Fridge', price: 700, w: 1, d: 1, color: '#e9eef5', acts: [{ id: 'snack', label: 'Grab Snack', mins: 15, adv: { hunger: 110 }, skill: null }, { id: 'cook', label: 'Cook Meal', mins: 50, adv: { hunger: 95 }, skill: 'cooking', trait: 'foodie' }] },
  stove:   { name: 'Induction Stove', price: 500, w: 1, d: 1, color: '#2d2f38', acts: [{ id: 'cook', label: 'Cook Feast', mins: 60, adv: { hunger: 100, fun: 10 }, skill: 'cooking', trait: 'foodie' }] },
  shower:  { name: 'Rain Shower', price: 600, w: 1, d: 1, color: '#bfe8ff', acts: [{ id: 'shower', label: 'Shower', mins: 25, adv: { hygiene: 220 } }] },
  toilet:  { name: 'Toilet', price: 300, w: 1, d: 1, color: '#ffffff', acts: [{ id: 'pee', label: 'Use Toilet', mins: 8, adv: { bladder: 700 } }] },
  sofa:    { name: 'Lounge Sofa', price: 650, w: 2, d: 1, color: '#ff8a7a', acts: [{ id: 'relax', label: 'Chill', mins: 45, adv: { fun: 25, energy: 4 }, pose: 'sit', trait: 'homebody' }] },
  tv:      { name: 'Holo TV', price: 1100, w: 2, d: 1, color: '#1b1d26', acts: [{ id: 'watch', label: 'Watch Stream', mins: 60, adv: { fun: 45 }, trait: 'homebody' }] },
  pc:      { name: 'Creator Rig', price: 1500, w: 1, d: 1, color: '#6b5cff', acts: [{ id: 'game', label: 'Play Games', mins: 60, adv: { fun: 55 }, skill: 'logic', trait: 'gamer' }, { id: 'gig', label: 'Freelance Gig', mins: 120, adv: { fun: -10 }, skill: 'logic', pay: 220, trait: 'ambitious' }, { id: 'stream', label: 'Go Live (Stream)', mins: 90, adv: { fun: 25, social: 20 }, skill: 'charisma', pay: 120, followers: 1 }] },
  easel:   { name: 'Easel', price: 350, w: 1, d: 1, color: '#c89b6d', acts: [{ id: 'paint', label: 'Paint', mins: 90, adv: { fun: 35 }, skill: 'creativity', pay: 60, trait: 'creative', vibe: 'inspired' }] },
  guitar:  { name: 'Guitar Stand', price: 400, w: 1, d: 1, color: '#d9643a', acts: [{ id: 'jam', label: 'Jam', mins: 60, adv: { fun: 40 }, skill: 'music', trait: 'creative' }] },
  books:   { name: 'Bookshelf', price: 450, w: 1, d: 1, color: '#7a5235', acts: [{ id: 'read', label: 'Read', mins: 60, adv: { fun: 25 }, skill: 'logic', trait: 'bookworm', vibe: 'focused' }] },
  treadmill:{ name: 'Treadmill', price: 800, w: 1, d: 2, color: '#444955', acts: [{ id: 'run', label: 'Work Out', mins: 60, adv: { fun: 15, hygiene: -20, energy: -10 }, skill: 'fitness', trait: 'athletic', vibe: 'energized' }] },
  plant:   { name: 'Monstera', price: 120, w: 1, d: 1, color: '#3fae5b', acts: [] },
  lamp:    { name: 'Glow Lamp', price: 150, w: 1, d: 1, color: '#ffd27a', acts: [] },
  table:   { name: 'Dining Table', price: 400, w: 2, d: 1, color: '#b98a5e', acts: [] },
  bench:   { name: 'Park Bench', price: 200, w: 2, d: 1, color: '#8a6a4a', acts: [{ id: 'sit', label: 'Sit & Vibe', mins: 30, adv: { fun: 12, energy: 3 }, pose: 'sit' }], hidden: true },
  booth:   { name: 'DJ Booth', price: 2000, w: 2, d: 1, color: '#ff3d9a', acts: [{ id: 'dj', label: 'DJ a Set', mins: 60, adv: { fun: 50, social: 25 }, skill: 'music', vibe: 'energized' }, { id: 'dance', label: 'Dance', mins: 40, adv: { fun: 45, social: 15, hygiene: -10 }, skill: 'fitness', vibe: 'happy' }], hidden: true },
  stall:   { name: 'Food Truck', price: 2000, w: 2, d: 1, color: '#ffb400', acts: [{ id: 'buy', label: 'Buy Tacos ($15)', mins: 15, adv: { hunger: 220, fun: 10 }, cost: 15 }], hidden: true },
};

// Procedural mesh per furniture type, built from primitives. Origin = footprint centre on floor.
export function buildFurniture(type, color) {
  const def = CATALOG[type], g = new THREE.Group(), c = color || def.color;
  const box = (w, h, d, col, x = 0, y = 0, z = 0, o) => { const m = new THREE.Mesh(new THREE.BoxGeometry(w, h, d), M(col, o)); m.position.set(x, y + h / 2, z); m.castShadow = m.receiveShadow = true; g.add(m); return m; };
  const W = def.w * 0.92, D = def.d * 0.92;
  switch (type) {
    case 'bed': box(W, 0.35, D, '#d8c7a8'); box(W * 0.98, 0.18, D * 0.75, c, 0, 0.35, D * 0.1); box(W * 0.8, 0.12, 0.35, '#fff', 0, 0.38, -D * 0.38); box(W, 0.9, 0.1, '#8a6a4a', 0, 0, -D / 2); break;
    case 'fridge': box(0.85, 1.9, 0.8, c, 0, 0, 0, { metalness: 0.4, roughness: 0.3 }); box(0.04, 0.5, 0.04, '#999', 0.3, 1.1, 0.42); break;
    case 'stove': box(0.9, 0.9, 0.8, '#ddd'); box(0.88, 0.04, 0.78, c, 0, 0.9, 0, { roughness: 0.2 }); break;
    case 'shower': box(0.95, 0.08, 0.95, '#fff'); box(0.95, 2.1, 0.05, c, 0, 0, -0.45, { transparent: true, opacity: 0.4 }); box(0.1, 0.1, 0.3, '#aaa', 0, 1.95, -0.3); break;
    case 'toilet': box(0.45, 0.42, 0.6, c); box(0.45, 0.5, 0.18, c, 0, 0.3, -0.25); break;
    case 'sofa': box(W, 0.42, D, c); box(W, 0.45, 0.22, c, 0, 0.42, -D / 2 + 0.11); box(0.2, 0.3, D, c, -W / 2 + 0.1, 0.42); box(0.2, 0.3, D, c, W / 2 - 0.1, 0.42); break;
    case 'tv': box(W * 0.8, 0.5, 0.45, '#3a3d48'); box(W * 0.9, 0.9, 0.06, c, 0, 0.55, 0, { emissive: '#3344aa', emissiveIntensity: 0.6 }); break;
    case 'pc': box(0.95, 0.75, 0.6, '#ece6df'); box(0.6, 0.38, 0.04, '#111', 0, 0.85, -0.15, { emissive: c, emissiveIntensity: 1 }); box(0.2, 0.45, 0.4, c, 0.33, 0.75, 0.05, { emissive: c, emissiveIntensity: 0.4 }); break;
    case 'easel': box(0.06, 1.5, 0.06, c, -0.25); box(0.06, 1.5, 0.06, c, 0.25); box(0.7, 0.55, 0.04, '#fff', 0, 0.8, 0.05); break;
    case 'guitar': box(0.35, 0.45, 0.12, c, 0, 0.2); box(0.07, 0.6, 0.05, '#3a2516', 0, 0.65); break;
    case 'books': box(0.9, 1.9, 0.4, c); for (let i = 0; i < 4; i++) box(0.8, 0.28, 0.3, ['#d14', '#2a7', '#36c', '#eb3'][i], 0, 0.2 + i * 0.45, 0.04); break;
    case 'treadmill': box(0.7, 0.18, D, c); box(0.7, 1.1, 0.08, '#222', 0, 0, -D / 2 + 0.1); break;
    case 'plant': box(0.4, 0.4, 0.4, '#e9dccb'); { const s = new THREE.Mesh(new THREE.IcosahedronGeometry(0.45, 1), M(c, { flatShading: true })); s.position.y = 0.85; s.castShadow = true; g.add(s); } break;
    case 'lamp': box(0.06, 1.5, 0.06, '#333'); box(0.4, 0.3, 0.4, c, 0, 1.45, 0, { emissive: c, emissiveIntensity: 2.5 }); break;
    case 'table': box(W, 0.06, D, c, 0, 0.72); box(0.08, 0.72, 0.08, c, -W / 2 + 0.1, 0, 0); box(0.08, 0.72, 0.08, c, W / 2 - 0.1, 0, 0); break;
    case 'bench': box(W, 0.08, 0.5, c, 0, 0.42); box(W, 0.4, 0.06, c, 0, 0.5, -0.22); box(0.1, 0.42, 0.45, '#333', -W / 2 + 0.2); box(0.1, 0.42, 0.45, '#333', W / 2 - 0.2); break;
    case 'booth': box(W, 1.0, 0.8, '#151520'); box(W, 0.08, 0.8, c, 0, 1.0, 0, { emissive: c, emissiveIntensity: 2 }); break;
    case 'stall': box(W, 1.8, 0.9, c); box(W * 1.05, 0.08, 1.3, '#fff', 0, 2.1, 0.2); box(W * 0.7, 0.5, 0.05, '#222', 0, 1.0, 0.46); break;
  }
  return g;
}

// --- World state ---
export class World {
  constructor(scene) {
    this.scene = scene;
    this.blocked = new Uint8Array(N * N);   // static blockers (walls, trees)
    this.objects = new Map();               // id -> {id,type,i,j,rot,color,lot,mesh}
    this.lots = [];
    this.walls = [];
    this.nextId = 1;
  }
  idx(i, j) { return j * N + i; }
  inside(i, j) { return i >= 0 && j >= 0 && i < N && j < N; }
  isBlocked(i, j) {
    if (!this.inside(i, j) || this.blocked[this.idx(i, j)]) return true;
    for (const o of this.objects.values()) if (this.covers(o, i, j)) return true;
    return false;
  }
  footprint(o) { const d = CATALOG[o.type]; return o.rot % 2 ? [d.d, d.w] : [d.w, d.d]; }
  covers(o, i, j) { const [w, d] = this.footprint(o); return i >= o.i && i < o.i + w && j >= o.j && j < o.j + d; }
  // Tile in front of an object where a sim stands to use it.
  useSpot(o) {
    const [w, d] = this.footprint(o), dirs = [[0, 1], [-1, 0], [0, -1], [1, 0]], [dx, dz] = dirs[o.rot % 4];
    const ci = o.i + Math.floor((w - 1) / 2), cj = o.j + Math.floor((d - 1) / 2);
    const cand = [[dx > 0 ? o.i + w : dx < 0 ? o.i - 1 : ci, dz > 0 ? o.j + d : dz < 0 ? o.j - 1 : cj]];
    for (let a = o.i - 1; a <= o.i + w; a++) for (let b = o.j - 1; b <= o.j + d; b++) cand.push([a, b]);
    return cand.find(([a, b]) => !this.isBlocked(a, b)) || cand[0];
  }
  canPlace(type, i, j, rot) {
    const t = { type, i, j, rot }, [w, d] = this.footprint(t);
    for (let a = i; a < i + w; a++) for (let b = j; b < j + d; b++) if (this.isBlocked(a, b)) return false;
    return true;
  }
  addObject(o) {
    o.id = o.id || 'o' + this.nextId++;
    const [w, d] = this.footprint(o), mesh = buildFurniture(o.type, o.color);
    mesh.position.set(toWorld(o.i) + (w - 1) / 2, 0, toWorld(o.j) + (d - 1) / 2);
    mesh.rotation.y = -o.rot * Math.PI / 2;
    mesh.userData.obj = o; mesh.traverse((m) => (m.userData.obj = o));
    o.mesh = mesh; this.scene.add(mesh); this.objects.set(o.id, o);
    if (o.type === 'lamp') (this.lamps ||= []).push(o);
    return o;
  }
  removeObject(id) { const o = this.objects.get(id); if (!o) return; this.scene.remove(o.mesh); this.objects.delete(id); return o; }
  lotAt(i, j) { return this.lots.find((l) => i >= l.x && i < l.x + l.w && j >= l.z && j < l.z + l.d); }

  // A* on the tile grid (8-dir, no corner cutting).
  path(si, sj, ti, tj) {
    if (!this.inside(ti, tj)) return null;
    const key = (i, j) => j * N + i, open = [[si, sj]], g = new Map([[key(si, sj), 0]]), from = new Map(), closed = new Set();
    const h = (i, j) => Math.hypot(ti - i, tj - j);
    let guard = 0;
    while (open.length && guard++ < 6000) {
      let bi = 0; for (let k = 1; k < open.length; k++) if (g.get(key(...open[k])) + h(...open[k]) < g.get(key(...open[bi])) + h(...open[bi])) bi = k;
      const [ci, cj] = open.splice(bi, 1)[0], ck = key(ci, cj);
      if (ci === ti && cj === tj) { const p = [[ci, cj]]; let k = ck; while (from.has(k)) { k = from.get(k); p.unshift([k % N, Math.floor(k / N)]); } return p; }
      closed.add(ck);
      for (let dx = -1; dx <= 1; dx++) for (let dz = -1; dz <= 1; dz++) {
        if (!dx && !dz) continue; const ni = ci + dx, nj = cj + dz, nk = key(ni, nj);
        if (closed.has(nk) || (this.isBlocked(ni, nj) && !(ni === ti && nj === tj))) continue;
        if (dx && dz && (this.isBlocked(ci + dx, cj) || this.isBlocked(ci, cj + dz))) continue;
        const ng = g.get(ck) + (dx && dz ? 1.414 : 1);
        if (!g.has(nk) || ng < g.get(nk)) { g.set(nk, ng); from.set(nk, ck); if (!open.some(([a, b]) => a === ni && b === nj)) open.push([ni, nj]); }
      }
    }
    return null;
  }

  // ---- Generation ----
  generate(seed = 7) {
    let s = seed; const rnd = () => ((s = (s * 16807) % 2147483647) / 2147483647);
    this.lamps = [];
    // ground (procedural grass texture)
    const tex = (draw, rep) => { const c = document.createElement('canvas'); c.width = c.height = 256; draw(c.getContext('2d')); const t = new THREE.CanvasTexture(c); t.wrapS = t.wrapT = THREE.RepeatWrapping; t.repeat.set(rep, rep); t.colorSpace = THREE.SRGBColorSpace; t.anisotropy = 8; return t; };
    const grass = tex((x) => { x.fillStyle = '#5fae4e'; x.fillRect(0, 0, 256, 256); for (let k = 0; k < 4000; k++) { x.fillStyle = `hsl(${95 + Math.random() * 30},${45 + Math.random() * 20}%,${35 + Math.random() * 20}%)`; x.fillRect(Math.random() * 256, Math.random() * 256, 2, 3); } }, 16);
    const ground = new THREE.Mesh(new THREE.PlaneGeometry(N + 40, N + 40), M('#fff', { map: grass, roughness: 1 }));
    ground.rotation.x = -Math.PI / 2; ground.receiveShadow = true; ground.userData.ground = true; this.scene.add(ground); this.ground = ground;
    // roads: grid of 3x3 blocks
    const roadMat = M('#3a3d47', { roughness: 0.9 });
    for (const r of [20, 40]) for (const vertical of [0, 1]) {
      const m = new THREE.Mesh(new THREE.PlaneGeometry(vertical ? 4 : N, vertical ? N : 4), roadMat);
      m.rotation.x = -Math.PI / 2; m.position.set(vertical ? toWorld(r) + 1.5 : 0, 0.01, vertical ? 0 : toWorld(r) + 1.5); m.receiveShadow = true; m.userData.ground = true; this.scene.add(m);
    }
    // plaza (centre block) — social hub
    const plaza = new THREE.Mesh(new THREE.PlaneGeometry(16, 16), M('#d9cbb3', { roughness: 0.95 }));
    plaza.rotation.x = -Math.PI / 2; plaza.position.set(toWorld(24) + 7.5, 0.015, toWorld(24) + 7.5); plaza.receiveShadow = true; plaza.userData.ground = true; this.scene.add(plaza);
    const fountain = new THREE.Group();
    const f1 = new THREE.Mesh(new THREE.CylinderGeometry(2.2, 2.4, 0.6, 32), M('#c8c2b8')); f1.position.y = 0.3;
    const f2 = new THREE.Mesh(new THREE.CylinderGeometry(2.0, 2.0, 0.1, 32), M('#4fb7ff', { roughness: 0.05, metalness: 0.2, emissive: '#0b4f88', emissiveIntensity: 0.4 })); f2.position.y = 0.58;
    const f3 = new THREE.Mesh(new THREE.CylinderGeometry(0.25, 0.4, 1.8, 16), M('#c8c2b8')); f3.position.y = 0.9;
    fountain.add(f1, f2, f3); fountain.children.forEach((m) => (m.castShadow = m.receiveShadow = true)); fountain.position.set(0, 0, 0); this.scene.add(fountain);
    for (let i = 30; i <= 33; i++) for (let j = 30; j <= 33; j++) this.blocked[this.idx(i, j)] = 1;
    this.addObject({ type: 'bench', i: 27, j: 27, rot: 0, lot: 'plaza' });
    this.addObject({ type: 'bench', i: 35, j: 27, rot: 0, lot: 'plaza' });
    this.addObject({ type: 'bench', i: 27, j: 36, rot: 2, lot: 'plaza' });
    this.addObject({ type: 'booth', i: 35, j: 36, rot: 2, lot: 'plaza' });
    this.addObject({ type: 'stall', i: 25, j: 31, rot: 3, lot: 'plaza' });
    // lots in the 8 outer blocks
    const spans = [[1, 18], [25, 14], [45, 18]];
    let n = 0;
    for (const [bz, dz] of spans) for (const [bx, dx] of spans) {
      if (bx === 25 && bz === 25) continue;
      this.lots.push({ id: 'lot' + n++, x: bx, z: bz, w: dx, d: dz, owner: null });
    }
    // trees around edges / between lots
    const trunk = M('#6b4a2e'), leaf = M('#3f9a4a', { flatShading: true });
    for (let k = 0; k < 70; k++) {
      const i = Math.floor(rnd() * N), j = Math.floor(rnd() * N);
      if (this.lotAt(i, j) || this.isRoadOrPlaza(i, j) || this.blocked[this.idx(i, j)]) continue;
      const t = new THREE.Group(), h = 1.2 + rnd() * 1.2;
      const tr = new THREE.Mesh(new THREE.CylinderGeometry(0.12, 0.18, h, 6), trunk); tr.position.y = h / 2;
      const lf = new THREE.Mesh(new THREE.IcosahedronGeometry(0.9 + rnd() * 0.6, 0), leaf); lf.position.y = h + 0.6;
      t.add(tr, lf); t.children.forEach((m) => (m.castShadow = true)); t.position.set(toWorld(i), 0, toWorld(j)); this.scene.add(t);
      this.blocked[this.idx(i, j)] = 1;
    }
  }
  isRoadOrPlaza(i, j) { const r = (v) => (v >= 20 && v < 24) || (v >= 40 && v < 44); return r(i) || r(j) || (i >= 24 && i < 40 && j >= 24 && j < 40); }

  // Procedural starter house on a lot.
  buildHouse(lot, palette = "#f1e6d8", furnish = true) {
    if (lot.house) { if (furnish) this.furnishHouse(lot); return lot; }
    const hx = lot.x + 2, hz = lot.z + 2, hw = Math.min(10, lot.w - 4), hd = Math.min(9, lot.d - 4);
    const floorMat = M('#b98d62', { roughness: 0.6 });
    const floor = new THREE.Mesh(new THREE.BoxGeometry(hw, 0.08, hd), floorMat);
    floor.position.set(toWorld(hx) + (hw - 1) / 2, 0.04, toWorld(hz) + (hd - 1) / 2); floor.receiveShadow = true; floor.userData.ground = true; this.scene.add(floor);
    const wallMat = M(palette, { roughness: 0.9 });
    const door = [hx + Math.floor(hw / 2), hz + hd - 1];
    const bathX = hx + hw - 4;
    const wallTiles = [];
    for (let i = hx; i < hx + hw; i++) for (let j = hz; j < hz + hd; j++) {
      const edge = i === hx || j === hz || i === hx + hw - 1 || j === hz + hd - 1;
      const inner = i === bathX && j < hz + 4 && j !== hz + 2; // bathroom partition with doorway
      const innerH = j === hz + 4 && i > bathX && i < hx + hw - 1;
      if ((edge || inner || innerH) && !(i === door[0] && j === door[1])) wallTiles.push([i, j]);
    }
    for (const [i, j] of wallTiles) {
      const m = new THREE.Mesh(new THREE.BoxGeometry(1, WALL_HEIGHT, 1), wallMat);
      m.position.set(toWorld(i), WALL_HEIGHT / 2, toWorld(j)); m.castShadow = m.receiveShadow = true;
      m.userData.lotCenter = new THREE.Vector3(toWorld(hx + hw / 2), 0, toWorld(hz + hd / 2)); this.scene.add(m); this.walls.push(m);
      this.blocked[this.idx(i, j)] = 1;
    }
    lot.house = { door, hx, hz, hw, hd, bathX };
    if (furnish) this.furnishHouse(lot);
    return lot;
  }
  furnishHouse(lot) {
    const { hx, hz, hw, hd, bathX } = lot.house;
    const put = (type, i, j, rot = 0, color) => this.canPlace(type, i, j, rot) && this.addObject({ type, i, j, rot, color, lot: lot.id });
    // bathroom (top-right)
    put('toilet', bathX + 1, hz + 1, 0); put('shower', bathX + 2, hz + 1, 0);
    // bedroom/living
    put('bed', hx + 1, hz + 1, 0); put('books', hx + 3, hz + 1, 0); put('lamp', hx + 4, hz + 1, 0);
    put('fridge', hx + 1, hz + hd - 3, 1); put('stove', hx + 1, hz + hd - 4, 1); put('table', hx + 3, hz + hd - 3, 0);
    put('sofa', hx + 5, hz + 4, 2); put('tv', hx + 5, hz + 6, 0); put('pc', bathX + 2, hz + hd - 2, 2);
    put('plant', hx + hw - 2, hz + 5, 0);
    // yard
    put('easel', lot.x + 1, lot.z + lot.d - 2, 0); put('treadmill', lot.x + lot.w - 2, lot.z + lot.d - 3, 0); put('guitar', lot.x + 1, lot.z + 1, 0);
  }
}
