// NextGen Life neighborhood server: static hosting + WebSocket rooms (shards of 8 lots each).
// Zero-cost: runs on any free Node host (Render/Fly/Glitch/Koyeb) or your own PC. Persists to a JSON file.
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { WebSocketServer } from 'ws';

const ROOT = path.join(path.dirname(fileURLToPath(import.meta.url)), '..');
const DIST = path.join(ROOT, 'dist'), DATA = path.join(ROOT, 'server', 'data'), DB = path.join(DATA, 'rooms.json');
const PORT = process.env.PORT || 8787, LOTS = 8, MAX_PLAYERS = 16;
const TYPES = new Set(['bed', 'fridge', 'stove', 'shower', 'toilet', 'sofa', 'tv', 'pc', 'easel', 'guitar', 'books', 'treadmill', 'plant', 'lamp', 'table']);

let db = { rooms: [] };
try { db = JSON.parse(fs.readFileSync(DB, 'utf8')); } catch {}
const save = () => { fs.mkdirSync(DATA, { recursive: true }); fs.writeFileSync(DB, JSON.stringify(db)); };
let dirty = false; setInterval(() => dirty && (save(), (dirty = false)), 5000);

function getRoom(token) {
  let r = db.rooms.find((r) => r.lots.some((l) => l.token === token));
  r ||= db.rooms.find((r) => r.lots.some((l) => !l.token) && clientsIn(r.id).length < MAX_PLAYERS);
  if (!r) { r = { id: db.rooms.length + 1, lots: Array.from({ length: LOTS }, (_, i) => ({ id: 'lot' + i, token: null, owner: null, objects: [] })), feed: [], start: Date.now() }; db.rooms.push(r); }
  return r;
}
const clients = new Map(); // ws -> {id, room, token, state}
const clientsIn = (room) => [...clients.values()].filter((c) => c.room === room);
const send = (ws, m) => ws.readyState === 1 && ws.send(JSON.stringify(m));
const broadcast = (room, m, except) => { for (const [ws, c] of clients) if (c.room === room && ws !== except) send(ws, m); };
const pub = (c) => ({ id: c.id, name: c.name, look: c.look, traits: c.traits, state: c.state });
const clean = (s, n = 200) => String(s ?? '').replace(/[<>]/g, '').slice(0, n);

const MIME = { '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css', '.png': 'image/png', '.svg': 'image/svg+xml', '.json': 'application/json' };
const server = http.createServer((req, res) => {
  if (req.url === '/health') return res.end('ok');
  let p = path.normalize(decodeURIComponent(req.url.split('?')[0])).replace(/^(\.\.[/\\])+/, '');
  let f = path.join(DIST, p); if (!f.startsWith(DIST)) return res.writeHead(403).end();
  if (!fs.existsSync(f) || fs.statSync(f).isDirectory()) f = path.join(DIST, 'index.html');
  if (!fs.existsSync(f)) return res.end('Build the client first: npm run build');
  res.writeHead(200, { 'Content-Type': MIME[path.extname(f)] || 'application/octet-stream' }); fs.createReadStream(f).pipe(res);
});

const wss = new WebSocketServer({ server, path: '/ws', maxPayload: 32 * 1024 });
wss.on('connection', (ws) => {
  let c = null, msgs = 0; const rl = setInterval(() => (msgs = 0), 1000);
  ws.on('message', (raw) => {
    if (++msgs > 30) return; let m; try { m = JSON.parse(raw); } catch { return; }
    if (m.t === 'hello' && !c) {
      const token = clean(m.token, 40) || Math.random().toString(36).slice(2), room = getRoom(token);
      let lot = room.lots.find((l) => l.token === token) || room.lots.find((l) => !l.token);
      if (lot && !lot.token) { lot.token = token; lot.owner = clean(m.name, 24); lot.fresh = true; dirty = true; }
      c = { id: 'p' + Math.random().toString(36).slice(2, 9), room: room.id, token, name: clean(m.name, 24), look: m.look, traits: (m.traits || []).slice(0, 3).map((t) => clean(t, 16)), state: null };
      clients.set(ws, c);
      send(ws, { t: 'welcome', id: c.id, room: room.id, lot: lot?.id || null, lots: room.lots.map(({ token, ...l }) => l), players: clientsIn(room.id).filter((x) => x !== c).map(pub), feed: room.feed.slice(-40), start: room.start });
      if (lot) lot.fresh = false;
      broadcast(room.id, { t: 'join', p: pub(c) }, ws);
      return;
    }
    if (!c) return;
    const room = db.rooms.find((r) => r.id === c.room), myLot = room.lots.find((l) => l.token === c.token);
    switch (m.t) {
      case 'state': c.state = { x: +m.x || 0, z: +m.z || 0, h: +m.h || 0, pose: clean(m.pose, 8), vibe: clean(m.vibe, 12), bubble: clean(m.bubble, 24) }; broadcast(c.room, { t: 'state', id: c.id, s: c.state }, ws); break;
      case 'chat': broadcast(c.room, { t: 'chat', id: c.id, name: c.name, text: clean(m.text, 160) }); break;
      case 'social': case 'socialResult': for (const [w2, c2] of clients) if (c2.id === m.to && c2.room === c.room) send(w2, { ...m, from: c.id, sid: clean(m.sid, 16) }); break;
      case 'post': { const p = { name: c.name, text: clean(m.text, 140), at: Date.now() }; room.feed.push(p); room.feed = room.feed.slice(-100); dirty = true; broadcast(c.room, { t: 'post', p }); break; }
      case 'build': {
        if (!myLot || myLot.id !== m.lot) return;
        if (m.op === 'add' && TYPES.has(m.o?.type) && myLot.objects.length < 120) { const o = { id: clean(m.o.id, 20), type: m.o.type, i: m.o.i | 0, j: m.o.j | 0, rot: (m.o.rot | 0) % 4, color: clean(m.o.color, 9) }; myLot.objects.push(o); broadcast(c.room, { t: 'build', op: 'add', lot: myLot.id, o }, ws); }
        if (m.op === 'remove') { myLot.objects = myLot.objects.filter((o) => o.id !== m.id); broadcast(c.room, { t: 'build', op: 'remove', lot: myLot.id, id: clean(m.id, 20) }, ws); }
        if (m.op === 'sync' && Array.isArray(m.objects)) { myLot.objects = m.objects.filter((o) => TYPES.has(o.type)).slice(0, 120).map((o) => ({ id: clean(o.id, 20), type: o.type, i: o.i | 0, j: o.j | 0, rot: (o.rot | 0) % 4, color: clean(o.color, 9) })); broadcast(c.room, { t: 'lot', lot: myLot.id, owner: myLot.owner, objects: myLot.objects }, ws); }
        dirty = true; break;
      }
    }
  });
  ws.on('close', () => { clearInterval(rl); if (c) { clients.delete(ws); broadcast(c.room, { t: 'leave', id: c.id }); } });
});
server.listen(PORT, () => console.log(`NextGen Life server on http://localhost:${PORT}`));
