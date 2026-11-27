"""Terrace & Rose asset generator (original assets, CC0 by the project).

Run:  blender -b --python-exit-code 1 -P tools/blender/build_assets.py
Outputs (relative to project root):
  assets/source/*.blend           editable Blender sources (one per avatar body + one for props)
  assets/models/avatars/*.glb     shared-rig avatar bodies with hair/outfit/accessory variants + animations
  assets/models/furniture/*.glb   catalog furniture (front faces -Y in Blender => +Z in Godot)
  assets/models/building/*.glb    door, window, arch, pendant, roof modules
  assets/textures/*.png           tileable textures (walnut, stucco, fabric, knit, tile, grass ...)
  assets/audio/*.wav              ambient + UI sounds (synthesised)
Materials are named; Godot's Palette replaces them by name so the art direction lives in one place.
"""
import bpy, bmesh, math, os, sys, random, wave, struct
import numpy as np
from mathutils import Vector, Matrix

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
OUT = lambda *p: os.path.join(ROOT, 'assets', *p)
FPS = 24

# ------------------------------------------------------------------ utilities
def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True); MATS.clear()
    bpy.context.scene.render.fps = FPS

MATS = {}
PREVIEW = {  # flat preview colours; Godot replaces these by name
    'skin': (0.55, 0.36, 0.24), 'hair': (0.05, 0.04, 0.03), 'eye_white': (0.92, 0.9, 0.86), 'iris': (0.18, 0.1, 0.05),
    'brow': (0.05, 0.04, 0.03), 'lip': (0.45, 0.22, 0.2), 'gold': (0.85, 0.65, 0.25), 'shoe': (0.2, 0.13, 0.08),
    'cloth_top': (0.7, 0.35, 0.22), 'cloth_bottom': (0.3, 0.3, 0.32), 'cloth_outer': (0.35, 0.22, 0.12), 'cloth_knit': (0.9, 0.86, 0.76),
    'walnut': (0.32, 0.19, 0.11), 'stucco': (0.93, 0.89, 0.8), 'teal_paint': (0.45, 0.68, 0.64), 'brass': (0.78, 0.6, 0.3),
    'linen': (0.92, 0.89, 0.82), 'terracotta': (0.72, 0.38, 0.25), 'stone_top': (0.9, 0.88, 0.84), 'leaf': (0.2, 0.42, 0.22),
    'soil': (0.2, 0.14, 0.1), 'glass': (0.7, 0.85, 0.9), 'lamp_shade': (1.0, 0.92, 0.75), 'rug': (0.75, 0.5, 0.35),
    'book': (0.5, 0.3, 0.3), 'ceramic': (0.9, 0.9, 0.86), 'roof_tile': (0.66, 0.33, 0.22), 'teal_tile': (0.3, 0.6, 0.58),
}
def mat(name):
    if name in MATS: return MATS[name]
    m = bpy.data.materials.new(name); m.use_nodes = True
    c = PREVIEW.get(name, (0.8, 0.8, 0.8)); m.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value = (*c, 1)
    MATS[name] = m; return m

def obj_from_bm(name, bm, material):
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new(name, me); bpy.context.collection.objects.link(o)
    me.materials.append(mat(material)); return o

def prim(kind, name, material, loc=(0, 0, 0), scale=(1, 1, 1), rot=(0, 0, 0), **kw):
    bm = bmesh.new()
    if kind == 'box': bmesh.ops.create_cube(bm, size=1.0)
    elif kind == 'sphere': bmesh.ops.create_uvsphere(bm, u_segments=kw.get('u', 24), v_segments=kw.get('v', 16), radius=1.0)
    elif kind == 'ico': bmesh.ops.create_icosphere(bm, subdivisions=kw.get('sub', 1), radius=1.0)
    elif kind == 'cyl': bmesh.ops.create_cone(bm, cap_ends=True, segments=kw.get('seg', 24), radius1=1.0, radius2=kw.get('r2', 1.0), depth=1.0)
    elif kind == 'torus':
        # build torus manually (bmesh has no torus op)
        R, r, s1, s2 = 1.0, kw.get('minor', 0.25), kw.get('seg', 24), 10
        verts = [[bm.verts.new(((R + r * math.cos(b)) * math.cos(a), (R + r * math.cos(b)) * math.sin(a), r * math.sin(b)))
                  for b in [j * 2 * math.pi / s2 for j in range(s2)]] for a in [i * 2 * math.pi / s1 for i in range(s1)]]
        for i in range(s1):
            for j in range(s2):
                bm.faces.new((verts[i][j], verts[(i + 1) % s1][j], verts[(i + 1) % s1][(j + 1) % s2], verts[i][(j + 1) % s2]))
    m = Matrix.LocRotScale(Vector(loc), Matrix.Rotation(rot[0], 3, 'X') @ Matrix.Rotation(rot[1], 3, 'Y') @ Matrix.Rotation(rot[2], 3, 'Z'), Vector(scale))
    bmesh.ops.transform(bm, matrix=m, verts=bm.verts)
    o = obj_from_bm(name, bm, material)
    if kind in ('sphere', 'ico', 'torus', 'cyl'):
        for p in o.data.polygons: p.use_smooth = kind != 'cyl' or kw.get('smooth', True)
    return o

def join(objs, name):
    objs = [o for o in objs if o]
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs: o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    if len(objs) > 1: bpy.ops.object.join()
    o = bpy.context.view_layer.objects.active; o.name = name; o.data.name = name
    return o

def cube_uv(o, size=1.0):
    bpy.ops.object.select_all(action='DESELECT'); o.select_set(True); bpy.context.view_layer.objects.active = o
    bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.cube_project(cube_size=size, scale_to_bounds=False, correct_aspect=False)
    bpy.ops.object.mode_set(mode='OBJECT')

def export(objs, path, anim=False):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:
        o.select_set(True)
        for c in o.children_recursive: c.select_set(True)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', use_selection=True, export_yup=True, export_apply=False,
                              export_animations=anim, export_animation_mode='ACTIONS', export_skins=True,
                              export_def_bones=True, export_force_sampling=True)

# ------------------------------------------------------------------ textures (tileable, numpy)
def tile_noise(n, scale, seed):
    rng = np.random.default_rng(seed); f = np.fft.fft2(rng.standard_normal((n, n)))
    ky = np.fft.fftfreq(n)[:, None]; kx = np.fft.fftfreq(n)[None, :]
    g = np.exp(-(kx ** 2 + ky ** 2) * (scale ** 2) * 40); r = np.real(np.fft.ifft2(f * g))
    return (r - r.min()) / (r.max() - r.min() + 1e-9)

def save_png(name, rgb):
    h, w = rgb.shape[:2]; img = bpy.data.images.new(name, w, h, alpha=False)
    px = np.ones((h, w, 4), np.float32); px[..., :3] = np.clip(rgb, 0, 1); img.pixels.foreach_set(px.ravel())
    img.filepath_raw = OUT('textures', name + '.png'); img.file_format = 'PNG'; img.save()

def normal_from_height(hm, strength):
    gy, gx = np.gradient(hm); nx, ny = -gx * strength, -gy * strength; nz = np.ones_like(hm)
    l = np.sqrt(nx ** 2 + ny ** 2 + nz ** 2); return np.stack([nx / l * 0.5 + 0.5, ny / l * 0.5 + 0.5, nz / l * 0.5 + 0.5], -1)

def make_textures():
    os.makedirs(OUT('textures'), exist_ok=True); n = 512
    y, x = np.mgrid[0:n, 0:n] / n
    # walnut planks: grain along X, plank seams every 1/4
    warp = tile_noise(n, 3, 1) * 0.08
    grain = 0.5 + 0.5 * np.sin((y + warp) * 2 * np.pi * 38 + tile_noise(n, 1.5, 2) * 6)
    plank = np.floor(y * 4) ; tone = (np.sin(plank * 12.9898) * 43758.5453) % 1 * 0.18
    seam = (np.abs((y * 4) % 1 - 0.0) < 0.012) | (np.abs((y * 4) % 1 - 1.0) < 0.012)
    v = 0.55 + grain * 0.25 - tone; v[seam] *= 0.45
    base = np.array([0.36, 0.22, 0.13]); save_png('walnut_albedo', base[None, None, :] * v[..., None] * 1.25)
    save_png('walnut_normal', normal_from_height(grain * 0.4 + seam * -1.0, 6))
    # stucco
    s = tile_noise(n, 0.4, 3) * 0.6 + tile_noise(n, 1.2, 4) * 0.4
    save_png('stucco_albedo', np.array([0.95, 0.91, 0.83])[None, None, :] * (0.92 + s[..., None] * 0.1))
    save_png('stucco_normal', normal_from_height(s, 10))
    # fabric weave (grayscale detail, tinted in Godot)
    weave = 0.5 + 0.25 * np.sin(x * 2 * np.pi * 64) * np.sign(np.sin(y * 2 * np.pi * 32)) + 0.25 * np.sin(y * 2 * np.pi * 64) * np.sign(np.sin(x * 2 * np.pi * 32))
    fn = tile_noise(n, 0.3, 5) * 0.15; f = 0.85 + (weave - 0.5) * 0.18 + fn
    save_png('fabric_detail', np.repeat(f[..., None], 3, -1)); save_png('fabric_normal', normal_from_height(weave * 0.6 + fn, 4))
    # knit ribs
    rib = np.abs(np.sin(x * 2 * np.pi * 24)) ; chev = np.abs(np.sin((y * 48 + np.abs(((x * 24) % 1) - 0.5)) * np.pi))
    k = rib * 0.5 + chev * 0.5; save_png('knit_detail', np.repeat((0.8 + k * 0.2)[..., None], 3, -1)); save_png('knit_normal', normal_from_height(k, 8))
    # hair strand detail
    hs = tile_noise(n, 0.15, 6); strands = 0.5 + 0.5 * np.sin(x * 2 * np.pi * 90 + hs * 20)
    save_png('hair_detail', np.repeat((0.75 + strands * 0.25)[..., None], 3, -1)); save_png('hair_normal', normal_from_height(strands, 3))
    # skin micro detail
    sk = tile_noise(n, 0.2, 7); save_png('skin_normal', normal_from_height(sk, 2))
    # glazed teal tile, terracotta roof tile, grass, path stone
    tx, ty = (x * 8) % 1, (y * 8) % 1; grout = (tx < 0.04) | (ty < 0.04); gl = tile_noise(n, 0.8, 8)
    t = np.array([0.27, 0.58, 0.56])[None, None, :] * (0.85 + gl[..., None] * 0.3); t[grout] = [0.9, 0.88, 0.82]; save_png('teal_tile_albedo', t)
    g = tile_noise(n, 0.25, 9) * 0.5 + tile_noise(n, 2, 10) * 0.5
    save_png('grass_albedo', np.stack([0.30 + g * 0.12, 0.47 + g * 0.15, 0.22 + g * 0.06], -1))
    p = tile_noise(n, 1.0, 11); cells = ((np.floor(x * 6) + np.floor(y * 6 + (np.floor(x * 6) % 2) * 0.5)) % 3) * 0.04
    save_png('path_albedo', np.stack([0.78 + p * 0.1 - cells, 0.72 + p * 0.1 - cells, 0.62 + p * 0.08 - cells], -1))
    rt = 0.8 + 0.2 * np.abs(np.sin(x * 2 * np.pi * 10)) * (((y * 12) % 1) > 0.15)
    save_png('roof_albedo', np.array([0.66, 0.33, 0.22])[None, None, :] * rt[..., None])
    # rug: original geometric pattern (terracotta / cream / teal)
    cx, cy = np.abs(x - 0.5), np.abs(y - 0.5); d = np.maximum(cx, cy * 1.3)
    band = ((d * 18).astype(int) % 3); rug = np.where(band[..., None] == 0, [0.72, 0.38, 0.25], np.where(band[..., None] == 1, [0.93, 0.88, 0.78], [0.32, 0.58, 0.55]))
    rug = rug * (0.9 + 0.1 * f[..., None]); rug[(cx > 0.46) | (cy > 0.44)] = [0.6, 0.3, 0.2]; save_png('rug_albedo', rug)

# ------------------------------------------------------------------ audio (synthesised, original)
def make_audio():
    os.makedirs(OUT('audio'), exist_ok=True); sr = 22050
    def wav(name, sig):
        sig = np.clip(sig, -1, 1); data = (sig * 32000).astype('<i2').tobytes()
        with wave.open(OUT('audio', name + '.wav'), 'wb') as w: w.setnchannels(1); w.setsampwidth(2); w.setframerate(sr); w.writeframes(data)
    rng = np.random.default_rng(42)
    def lowpass(x, a): y = np.empty_like(x); acc = 0.0
        # simple one-pole (vectorised via cumulative filter is overkill here)
    def onepole(x, a):
        y = np.zeros_like(x); acc = 0.0
        for i in range(len(x)): acc += a * (x[i] - acc); y[i] = acc
        return y
    # coastal ambience: 16 s loop of filtered surf swells + soft wind
    n = sr * 16; t = np.arange(n) / sr; noise = rng.standard_normal(n)
    surf = onepole(noise, 0.04) * (0.35 + 0.65 * (0.5 - 0.5 * np.cos(2 * np.pi * t / 8)) ** 2)
    wind = onepole(rng.standard_normal(n), 0.01) * 0.6
    amb = surf * 1.6 + wind; fade = np.minimum(1, np.minimum(t, 16 - t) / 0.5); wav('ambient_coast', amb / np.abs(amb).max() * 0.5 * fade)
    def tone(freqs, dur, decay=6, amp=0.4):
        tt = np.arange(int(sr * dur)) / sr; s = sum(np.sin(2 * np.pi * f * tt) * (0.6 ** k) for k, f in enumerate(freqs))
        return s * np.exp(-tt * decay) * amp * np.minimum(1, tt * 400)
    wav('ui_click', tone([1320, 2640], 0.08, 40, 0.3))
    wav('ui_error', np.concatenate([tone([330], 0.12, 12), tone([262], 0.18, 10)]))
    wav('chime_done', np.concatenate([tone([784, 1568], 0.18, 9), tone([1047, 2093], 0.5, 6)]))
    wav('knock', np.concatenate([onepole(rng.standard_normal(1200), 0.2) * np.exp(-np.arange(1200) / 200) * 3 for _ in range(3) for __ in [0]] + []))
    sz = onepole(rng.standard_normal(sr * 3), 0.5) - onepole(rng.standard_normal(sr * 3), 0.05)
    wav('sizzle', sz * 0.25 * (0.8 + 0.2 * np.sin(np.arange(sr * 3) / sr * 13)))
    wav('coins', np.concatenate([tone([2093, 3136], 0.09, 25), tone([2637, 3951], 0.25, 14)]))

# ------------------------------------------------------------------ avatars
BODIES = {
    # name: height, shoulder, hip, bust, waist, limb thickness, posture(elder), head scale
    'curvy':   dict(h=1.66, sh=1.0, hip=1.28, bust=1.18, waist=1.05, limb=1.12, stoop=0.0, head=1.0, femme=1),
    'slender': dict(h=1.76, sh=1.02, hip=0.92, bust=0.95, waist=0.88, limb=0.9, stoop=0.0, head=0.97, femme=0),
    'classic': dict(h=1.73, sh=1.08, hip=1.02, bust=1.05, waist=1.06, limb=1.02, stoop=0.06, head=1.0, femme=0),
}

def skeleton_points(b):
    h = b['h']; sx = 0.105 * h * b['sh']; hx = 0.052 * h * b['hip']
    P = {
        'pelvis': (0, 0, 0.53 * h), 'waist': (0, 0, 0.61 * h), 'chest': (0, 0.0, 0.70 * h), 'upper': (0, 0, 0.79 * h), 'neck': (0, 0, 0.845 * h),
        'shoulder.L': (sx, 0, 0.805 * h), 'elbow.L': (sx + 0.045 * h, 0.01, 0.625 * h), 'wrist.L': (sx + 0.06 * h, -0.01, 0.47 * h), 'hand.L': (sx + 0.065 * h, -0.02, 0.405 * h),
        'hip.L': (hx, 0, 0.505 * h), 'knee.L': (hx * 0.95, -0.01, 0.285 * h), 'ankle.L': (hx * 0.92, 0.01, 0.05 * h), 'toe.L': (hx * 0.92, -0.13, 0.015),
    }
    for k in list(P):
        if k.endswith('.L'): x, y, z = P[k]; P[k[:-2] + '.R'] = (-x, y, z)
    return {k: Vector(v) for k, v in P.items()}

def build_rig(b):
    P = skeleton_points(b); h = b['h']
    arm = bpy.data.armatures.new('Rig'); rig = bpy.data.objects.new('Rig', arm); bpy.context.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig; bpy.ops.object.mode_set(mode='EDIT'); eb = arm.edit_bones
    def bone(name, head, tail, parent=None, connect=False):
        e = eb.new(name); e.head = head; e.tail = tail; e.roll = 0
        if parent: e.parent = eb[parent]; e.use_connect = connect
        return e
    head_c = Vector((0, 0, 0.925 * h))
    bone('hips', P['pelvis'], P['waist'])
    bone('spine', P['waist'], P['chest'], 'hips', True); bone('chest', P['chest'], P['upper'], 'spine', True)
    bone('neck', P['upper'], P['neck'] + Vector((0, 0, 0.02)), 'chest', True); bone('head', P['neck'] + Vector((0, 0, 0.02)), Vector((0, 0, h)), 'neck', True)
    bone('jaw', head_c + Vector((0, -0.01, -0.01)), head_c + Vector((0, -0.08, -0.06)), 'head')
    for s in 'LR':
        sg = 1 if s == 'L' else -1
        bone('brow.' + s, head_c + Vector((sg * 0.03, -0.08, 0.035)), head_c + Vector((sg * 0.03, -0.1, 0.035)), 'head')
        bone('lid.' + s, head_c + Vector((sg * 0.033, -0.085, 0.012)), head_c + Vector((sg * 0.033, -0.105, 0.012)), 'head')
        bone('upper_arm.' + s, P['shoulder.' + s], P['elbow.' + s], 'chest'); bone('forearm.' + s, P['elbow.' + s], P['wrist.' + s], 'upper_arm.' + s, True)
        bone('hand.' + s, P['wrist.' + s], P['hand.' + s], 'forearm.' + s, True)
        bone('thigh.' + s, P['hip.' + s], P['knee.' + s], 'hips'); bone('shin.' + s, P['knee.' + s], P['ankle.' + s], 'thigh.' + s, True)
        bone('foot.' + s, P['ankle.' + s], P['toe.' + s], 'shin.' + s, True)
    bpy.ops.object.mode_set(mode='OBJECT')
    return rig, P

def skin_mesh(name, P, edges, radii, material, subdiv=2):
    """Organic mesh from a skeleton graph using Blender's Skin modifier (elliptical radii)."""
    names = sorted({n for e in edges for n in e}); idx = {n: i for i, n in enumerate(names)}
    me = bpy.data.meshes.new(name); me.from_pydata([P[n] for n in names], [(idx[a], idx[b]) for a, b in edges], [])
    o = bpy.data.objects.new(name, me); bpy.context.collection.objects.link(o)
    sk = o.modifiers.new('skin', 'SKIN'); sk.use_smooth_shade = True; sk.branch_smoothing = 0.6
    for i, n in enumerate(names):
        r = radii[n]; me.skin_vertices[0].data[i].radius = (r[0], r[1]) if isinstance(r, tuple) else (r, r)
        me.skin_vertices[0].data[i].use_root = (n == names[0])
    sd = o.modifiers.new('sub', 'SUBSURF'); sd.levels = subdiv; sd.render_levels = subdiv
    bpy.context.view_layer.objects.active = o; o.select_set(True)
    bpy.ops.object.modifier_apply(modifier='skin'); bpy.ops.object.modifier_apply(modifier='sub')
    me.materials.append(mat(material)); return o

def body_radii(b, inflate=1.0, extra={}):
    h = b['h'] / 1.7; L = b['limb']
    R = {
        'pelvis': (0.135 * b['hip'], 0.10 * b['hip']), 'waist': (0.115 * b['waist'], 0.085 * b['waist']), 'chest': (0.13 * b['bust'], 0.095 * b['bust'] * (1.08 if b['femme'] else 1)),
        'upper': (0.12 * b['sh'], 0.075), 'neck': (0.045, 0.045),
        'shoulder': (0.05 * L, 0.05 * L), 'elbow': (0.036 * L, 0.036 * L), 'wrist': (0.026, 0.022), 'hand': (0.03, 0.014),
        'hip': (0.078 * b['hip'] * L, 0.078 * b['hip'] * L), 'knee': (0.05 * L, 0.05 * L), 'ankle': (0.032, 0.032), 'toe': (0.03, 0.022),
    }
    out = {}
    for k, v in R.items():
        v = tuple(x * h * inflate * extra.get(k, 1.0) for x in v)
        if k in ('pelvis', 'waist', 'chest', 'upper', 'neck'): out[k] = v
        else: out[k + '.L'] = v; out[k + '.R'] = v
    return out

TORSO = [('pelvis', 'waist'), ('waist', 'chest'), ('chest', 'upper'), ('upper', 'neck')]
def arm(s, upto='hand'): seq = ['upper', 'shoulder.' + s, 'elbow.' + s, 'wrist.' + s, 'hand.' + s]; seq = seq[:seq.index(upto + ('.' + s if upto != 'upper' else '')) + 1]; return list(zip(seq, seq[1:]))
def leg(s, upto='toe'): seq = ['pelvis', 'hip.' + s, 'knee.' + s, 'ankle.' + s, 'toe.' + s]; seq = seq[:seq.index(upto + '.' + s) + 1]; return list(zip(seq, seq[1:]))

def auto_weights(o, rig, exclude=('jaw', 'brow.L', 'brow.R', 'lid.L', 'lid.R')):
    """Deterministic distance-to-bone-segment weighting (sharp falloff, max 3 influences)."""
    bones = [(b.name, Vector(b.head_local), Vector(b.tail_local)) for b in rig.data.bones if b.name not in exclude]
    groups = {n: o.vertex_groups.new(name=n) for n, _, _ in bones}
    for v in o.data.vertices:
        p = v.co; ds = []
        for n, a, bb in bones:
            ab = bb - a; t = max(0.0, min(1.0, (p - a).dot(ab) / ab.length_squared)); ds.append((((a + ab * t) - p).length, n))
        ds.sort(); dmin = ds[0][0] + 1e-4; cand = [(d, n) for d, n in ds[:3] if d < dmin * 1.6]
        ws = [(1.0 / (d + 1e-4) ** 4, n) for d, n in cand]; tot = sum(w for w, _ in ws)
        for w, n in ws: groups[n].add([v.index], w / tot, 'REPLACE')
    attach(o, rig)

def rigid(o, rig, bone='head'):
    g = o.vertex_groups.new(name=bone); g.add([v.index for v in o.data.vertices], 1.0, 'REPLACE'); attach(o, rig)

def attach(o, rig):
    o.parent = rig; m = o.modifiers.new('Armature', 'ARMATURE'); m.object = rig

def build_head(b, rig, P):
    h = b['h']; c = Vector((0, -0.005, 0.925 * h)); s = b['head']; parts = []
    hd = prim('sphere', 'head', 'skin', c, (0.088 * s, 0.1 * s, 0.112 * s), u=40, v=28)
    for v in hd.data.vertices:  # jaw taper, cheek and brow shaping
        d = v.co - c
        if d.z < 0: k = 1 - min(1, -d.z / 0.11) * 0.28; v.co.x = c.x + d.x * k; v.co.y = c.y + d.y * (1 - min(1, -d.z / 0.11) * 0.1)
        if d.y < -0.06 and abs(d.z - 0.035) < 0.02: v.co.y -= 0.004  # brow ridge
    parts.append(hd)
    parts.append(prim('sphere', 'nose', 'skin', c + Vector((0, -0.1 * s, -0.012)), (0.016, 0.022, 0.026), u=16, v=12))
    parts.append(prim('sphere', 'nose_tip', 'skin', c + Vector((0, -0.112 * s, -0.03)), (0.019, 0.017, 0.015), u=16, v=12))
    for sg in (1, -1):
        parts.append(prim('sphere', 'ear', 'skin', c + Vector((sg * 0.087 * s, 0.005, -0.005)), (0.012, 0.026, 0.034), u=16, v=12))
    head = join(parts, 'head'); cube_uv(head, 0.3); rigid(head, rig, 'head')
    face = []
    for sg, sd in ((1, 'L'), (-1, 'R')):
        e = c + Vector((sg * 0.033 * s, -0.082 * s, 0.012))
        ew = prim('sphere', 'eye', 'eye_white', e, (0.016, 0.012, 0.012), u=16, v=12); rigid(ew, rig, 'head'); face.append(ew)
        ir = prim('sphere', 'iris', 'iris', e + Vector((0, -0.0105, 0)), (0.0085, 0.004, 0.0085), u=16, v=12); rigid(ir, rig, 'head'); face.append(ir)
        lid = prim('sphere', 'lid.' + sd, 'skin', e + Vector((0, -0.001, 0.004)), (0.0175, 0.0135, 0.009), u=16, v=10); rigid(lid, rig, 'lid.' + sd); face.append(lid)
        br = prim('box', 'brow.' + sd, 'brow', c + Vector((sg * 0.034 * s, -0.093 * s, 0.037)), (0.03, 0.006, 0.006), rot=(0, sg * -0.12, 0)); rigid(br, rig, 'brow.' + sd); face.append(br)
    ul = prim('torus', 'lip_upper', 'lip', c + Vector((0, -0.094 * s, -0.052)), (0.021, 0.008, 0.009), rot=(math.pi / 2, 0, 0), minor=0.45); rigid(ul, rig, 'head')
    ll = prim('sphere', 'lip_lower', 'lip', c + Vector((0, -0.092 * s, -0.064)), (0.018, 0.009, 0.007), u=16, v=10); rigid(ll, rig, 'jaw')
    return [head] + face + [ul, ll], c

def hair_variants(b, rig, hc, s):
    rnd = random.Random(7); out = []
    def shell(n, r, ok):  # points on an ellipsoid around the head
        pts = []
        while len(pts) < n:
            v = Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-1, 1)))
            if v.length < 0.01 or v.length > 1: continue
            v.normalize(); p = Vector((v.x * r[0], v.y * r[1], v.z * r[2]))
            if ok(v): pts.append(p)
        return pts
    # natural coils: dense volume of small coiled clusters with a rounded, slightly taller silhouette
    parts = [prim('sphere', 'hc_base', 'hair', hc + Vector((0, 0.012, 0.03)), (0.112 * s, 0.122 * s, 0.118 * s), u=24, v=16)]
    for p in shell(260, (0.13 * s, 0.135 * s, 0.13 * s), lambda v: v.z > -0.25 and not (v.y < -0.55 and v.z < 0.45)):
        parts.append(prim('ico', 'coil', 'hair', hc + Vector((0, 0.01, 0.045)) + p, (0.024, 0.024, 0.024), sub=1))
    o = join(parts, 'hair_coils'); cube_uv(o, 0.1); rigid(o, rig); out.append(o)
    # wavy: cap + swept waves with a side part
    parts = [prim('sphere', 'hw_cap', 'hair', hc + Vector((0, 0.008, 0.022)), (0.096 * s, 0.108 * s, 0.108 * s), u=24, v=16)]
    for i in range(46):
        a = (i / 46) * math.pi * 2; base = hc + Vector((math.cos(a) * 0.07, math.sin(a) * 0.075 + 0.01, 0.085))
        if math.sin(a) < -0.2: base.z += 0.01
        pts = []
        for k in range(6):
            t = k / 5; down = 0.0 if math.sin(a) < -0.3 else 0.07
            pts.append(base + Vector((math.cos(a) * (0.03 + 0.02 * t), math.sin(a) * (0.03 + 0.025 * t) - (0.04 * t if math.sin(a) < -0.3 else 0), -down * t + 0.012 * math.sin(t * 7 + i))))
        cu = bpy.data.curves.new('strand', 'CURVE'); cu.dimensions = '3D'; sp = cu.splines.new('POLY'); sp.points.add(len(pts) - 1)
        for j, p in enumerate(pts): sp.points[j].co = (*p, 1)
        cu.bevel_depth = 0.014 * (1 - 0.0); cu.bevel_resolution = 2
        co = bpy.data.objects.new('strand', cu); bpy.context.collection.objects.link(co)
        bpy.context.view_layer.objects.active = co; bpy.ops.object.select_all(action='DESELECT'); co.select_set(True); bpy.ops.object.convert(target='MESH')
        co.data.materials.clear(); co.data.materials.append(mat('hair')); parts.append(co)
    o = join(parts, 'hair_wavy'); cube_uv(o, 0.1); rigid(o, rig); out.append(o)
    # short silver curls (close crop)
    parts = [prim('sphere', 'hs_cap', 'hair', hc + Vector((0, 0.01, 0.02)), (0.093 * s, 0.104 * s, 0.103 * s), u=24, v=16)]
    for p in shell(170, (0.095 * s, 0.105 * s, 0.106 * s), lambda v: v.z > 0.05 and v.y > -0.6 or (v.z > -0.3 and v.y > 0.2)):
        parts.append(prim('ico', 'curl', 'hair', hc + Vector((0, 0.01, 0.02)) + p, (0.013, 0.013, 0.013), sub=1))
    o = join(parts, 'hair_curls_short'); cube_uv(o, 0.1); rigid(o, rig); out.append(o)
    # low bun
    parts = [prim('sphere', 'hb_cap', 'hair', hc + Vector((0, 0.008, 0.02)), (0.094 * s, 0.106 * s, 0.106 * s), u=24, v=16),
             prim('sphere', 'bun', 'hair', hc + Vector((0, 0.1, -0.02)), (0.05, 0.045, 0.045), u=20, v=14)]
    o = join(parts, 'hair_bun'); cube_uv(o, 0.1); rigid(o, rig); out.append(o)
    # straight shoulder length
    parts = [prim('sphere', 'hl_cap', 'hair', hc + Vector((0, 0.008, 0.02)), (0.097 * s, 0.108 * s, 0.108 * s), u=24, v=16),
             prim('box', 'hl_back', 'hair', hc + Vector((0, 0.06, -0.08)), (0.18, 0.07, 0.2)),
             prim('box', 'hl_l', 'hair', hc + Vector((0.08, 0.0, -0.07)), (0.04, 0.12, 0.18)), prim('box', 'hl_r', 'hair', hc + Vector((-0.08, 0.0, -0.07)), (0.04, 0.12, 0.18))]
    o = join(parts, 'hair_long'); cube_uv(o, 0.1); rigid(o, rig); out.append(o)
    # short beard
    parts = []
    for p in shell(150, (0.09 * s, 0.1 * s, 0.112 * s), lambda v: v.z < -0.25 and v.y < -0.05 and not (v.z > -0.55 and abs(v.x) < 0.3 and v.y < -0.8)):
        parts.append(prim('ico', 'bc', 'hair', hc + Vector((0, -0.003, 0)) + p, (0.011, 0.011, 0.011), sub=1))
    o = join(parts, 'acc_beard'); cube_uv(o, 0.1); rigid(o, rig, 'jaw'); out.append(o)
    # gold earrings
    ers = [prim('torus', 'ear_ring', 'gold', hc + Vector((sg * 0.09 * s, -0.002, -0.05)), (0.013, 0.013, 0.013), rot=(0, math.pi / 2, 0), minor=0.18) for sg in (1, -1)]
    o = join(ers, 'acc_earrings'); rigid(o, rig); out.append(o)
    return out

def outfits(b, rig, P):
    """Each outfit is a set of meshes named outfit_<id>__<part>; Godot toggles visibility by id."""
    out = []
    def piece(oid, part, edges, inflate, material, extra={}, cut_front=False):
        o = skin_mesh(f'outfit_{oid}__{part}', P, edges, body_radii(b, inflate, extra), material)
        if cut_front:  # open jacket front
            bm = bmesh.new(); bm.from_mesh(o.data); h = b['h']
            kill = [f for f in bm.faces if f.calc_center_median().y < -0.03 and abs(f.calc_center_median().x) < 0.045 * h * b['bust'] and 0.5 * h < f.calc_center_median().z < 0.83 * h]
            bmesh.ops.delete(bm, geom=kill, context='FACES'); bm.to_mesh(o.data); bm.free()
        cube_uv(o, 0.25); auto_weights(o, rig); out.append(o)
    legs = leg('L', 'ankle') + leg('R', 'ankle'); shoes = [('ankle.L', 'toe.L'), ('ankle.R', 'toe.R')]
    full_arms = arm('L', 'wrist') + arm('R', 'wrist'); short = [('upper', 'shoulder.L'), ('shoulder.L', 'elbow.L'), ('upper', 'shoulder.R'), ('shoulder.R', 'elbow.R')]
    for oid in ('jumpsuit', 'jacket', 'knit_jacket', 'casual', 'apron', 'dress'):
        piece(oid, 'shoes', shoes, 1.25, 'shoe')
    piece('jumpsuit', 'body', TORSO[:3] + short + legs, 1.07, 'cloth_top', {'ankle': 1.25, 'knee': 1.12})
    piece('jacket', 'top', TORSO[:3] + full_arms, 1.12, 'cloth_top', {'wrist': 1.3, 'upper': 1.05})
    piece('jacket', 'bottom', [('pelvis', 'hip.L'), ('pelvis', 'hip.R')] + legs, 1.1, 'cloth_bottom', {'ankle': 1.35, 'knee': 1.18})
    piece('knit_jacket', 'knit', TORSO[:3] + full_arms, 1.06, 'cloth_knit', {'upper': 1.1})
    piece('knit_jacket', 'outer', TORSO[:3] + full_arms, 1.14, 'cloth_outer', {'wrist': 1.2}, cut_front=True)
    piece('knit_jacket', 'bottom', [('pelvis', 'hip.L'), ('pelvis', 'hip.R')] + legs, 1.08, 'cloth_bottom', {'ankle': 1.2})
    piece('casual', 'top', TORSO[:3] + short, 1.06, 'cloth_top')
    piece('casual', 'bottom', [('pelvis', 'hip.L'), ('pelvis', 'hip.R')] + legs, 1.07, 'cloth_bottom', {'ankle': 1.25})
    piece('apron', 'top', TORSO[:3] + short, 1.06, 'cloth_top')
    piece('apron', 'bottom', [('pelvis', 'hip.L'), ('pelvis', 'hip.R')] + legs, 1.07, 'cloth_bottom', {'ankle': 1.25})
    piece('apron', 'apron', [('pelvis', 'waist'), ('waist', 'chest')] + [('pelvis', 'hip.L'), ('hip.L', 'knee.L'), ('pelvis', 'hip.R'), ('hip.R', 'knee.R')], 1.16, 'cloth_outer', {'knee': 1.6, 'hip': 1.3})
    piece('dress', 'top', TORSO[:3] + short, 1.06, 'cloth_top')
    piece('dress', 'skirt', [('pelvis', 'hip.L'), ('hip.L', 'knee.L'), ('pelvis', 'hip.R'), ('hip.R', 'knee.R')], 1.25, 'cloth_top', {'knee': 1.9, 'hip': 1.4})
    return out

# ---- animation: keyed pose-bone euler rotations (radians), shared names across bodies
def build_actions(rig, b):
    h = b['h']; pb = rig.pose.bones
    for p in pb: p.rotation_mode = 'XYZ'
    leg_len = (h * (0.505 - 0.05))
    def act(name, frames, keys, loop=True):
        a = bpy.data.actions.new(name); a.use_fake_user = True; rig.animation_data_create(); rig.animation_data.action = a
        for p in pb: p.rotation_euler = (0, 0, 0); p.location = (0, 0, 0); p.scale = (1, 1, 1)
        for f, pose in keys:
            for p in pb:
                v = pose.get(p.name, {})
                p.rotation_euler = v.get('r', (0, 0, 0)); p.location = v.get('l', (0, 0, 0)); p.scale = v.get('s', (1, 1, 1))
                p.keyframe_insert('rotation_euler', frame=f); p.keyframe_insert('location', frame=f); p.keyframe_insert('scale', frame=f)
        a.frame_range = (0, frames)
        return a
    stoop = {'chest': {'r': (b['stoop'], 0, 0)}, 'neck': {'r': (-b['stoop'] * 0.6, 0, 0)}}
    arms_rest = {'upper_arm.L': {'r': (0, 0, 0.08)}, 'upper_arm.R': {'r': (0, 0, -0.08)}, 'forearm.L': {'r': (-0.12, 0, 0)}, 'forearm.R': {'r': (-0.12, 0, 0)}}
    def P(*ds):
        o = {}
        for d in ds:
            for k, v in d.items(): o.setdefault(k, {}).update(v)
        return o
    blink = {'lid.L': {'s': (1, 1, 1.0)}, 'lid.R': {'s': (1, 1, 1.0)}}
    closed = {'lid.L': {'l': (0, 0, -0.006)}, 'lid.R': {'l': (0, 0, -0.006)}}
    base = P(stoop, arms_rest)
    act('idle', 48, [(0, base), (24, P(base, {'chest': {'r': (b['stoop'] - 0.025, 0, 0)}, 'head': {'r': (0.02, 0.05, 0)}})), (36, P(base, closed)), (38, base), (48, base)])
    def walk(f, ph):
        s = math.sin(ph); c = math.cos(ph)
        return P(stoop, {'thigh.L': {'r': (-0.45 * s, 0, 0)}, 'thigh.R': {'r': (0.45 * s, 0, 0)},
                         'shin.L': {'r': (0.55 * max(0, c), 0, 0)}, 'shin.R': {'r': (0.55 * max(0, -c), 0, 0)},
                         'foot.L': {'r': (-0.15 * s, 0, 0)}, 'foot.R': {'r': (0.15 * s, 0, 0)},
                         'upper_arm.L': {'r': (0.35 * s, 0, 0.08)}, 'upper_arm.R': {'r': (-0.35 * s, 0, -0.08)},
                         'forearm.L': {'r': (-0.3, 0, 0)}, 'forearm.R': {'r': (-0.3, 0, 0)},
                         'hips': {'l': (0, 0.015 * abs(c), 0), 'r': (0, 0.08 * s, 0)}, 'chest': {'r': (b['stoop'] + 0.04, -0.12 * s, 0)}})
    act('walk', 24, [(f, walk(f, f / 24 * 2 * math.pi)) for f in range(0, 25, 3)])
    drop = -(leg_len - 0.46) ; back = -0.12
    sit = P(stoop, arms_rest, {'hips': {'l': (0, drop, back)}, 'thigh.L': {'r': (-1.5, 0, 0.05)}, 'thigh.R': {'r': (-1.5, 0, -0.05)},
                               'shin.L': {'r': (1.45, 0, 0)}, 'shin.R': {'r': (1.45, 0, 0)}, 'forearm.L': {'r': (-0.7, 0, 0)}, 'forearm.R': {'r': (-0.7, 0, 0)},
                               'upper_arm.L': {'r': (-0.25, 0, 0.1)}, 'upper_arm.R': {'r': (-0.25, 0, -0.1)}})
    mid = P(stoop, {'hips': {'l': (0, drop * 0.5, back * 0.5)}, 'chest': {'r': (0.35, 0, 0)}, 'thigh.L': {'r': (-0.9, 0, 0)}, 'thigh.R': {'r': (-0.9, 0, 0)}, 'shin.L': {'r': (0.9, 0, 0)}, 'shin.R': {'r': (0.9, 0, 0)}, 'upper_arm.L': {'r': (-0.5, 0, 0.1)}, 'upper_arm.R': {'r': (-0.5, 0, -0.1)}})
    act('sit_down', 14, [(0, base), (7, mid), (14, sit)], False)
    act('stand_up', 14, [(0, sit), (7, mid), (14, base)], False)
    act('sit_idle', 48, [(0, sit), (24, P(sit, {'head': {'r': (0.05, -0.1, 0)}})), (30, P(sit, closed)), (32, sit), (48, sit)])
    eat_up = P(sit, {'upper_arm.R': {'r': (-0.9, 0, -0.25)}, 'forearm.R': {'r': (-1.9, 0, 0)}, 'jaw': {'r': (0.12, 0, 0)}})
    act('sit_eat', 32, [(0, sit), (10, eat_up), (16, P(eat_up, {'jaw': {'r': (0, 0, 0)}})), (22, eat_up), (32, sit)])
    stand_eat = P(base, {'upper_arm.R': {'r': (-0.7, 0, -0.25)}, 'forearm.R': {'r': (-1.9, 0, 0)}, 'upper_arm.L': {'r': (-0.5, 0, 0.1)}, 'forearm.L': {'r': (-1.2, 0, 0)}, 'jaw': {'r': (0.12, 0, 0)}})
    act('eat', 32, [(0, P(base, {'upper_arm.L': {'r': (-0.5, 0, 0.1)}, 'forearm.L': {'r': (-1.2, 0, 0)}})), (12, stand_eat), (20, P(stand_eat, {'jaw': {'r': (0, 0, 0)}})), (32, P(base, {'upper_arm.L': {'r': (-0.5, 0, 0.1)}, 'forearm.L': {'r': (-1.2, 0, 0)}}))])
    cook = lambda k: P(base, {'upper_arm.L': {'r': (-0.6, 0, 0.15)}, 'forearm.L': {'r': (-1.1, 0, 0)}, 'upper_arm.R': {'r': (-0.7 + 0.15 * k, 0.2 * k, -0.15)}, 'forearm.R': {'r': (-1.0 - 0.2 * k, 0, 0)}, 'chest': {'r': (b['stoop'] + 0.15, 0, 0)}, 'head': {'r': (0.25, 0, 0)}})
    act('cook', 32, [(0, cook(0)), (8, cook(1)), (16, cook(-1)), (24, cook(1)), (32, cook(0))])
    wave_ = lambda k: P(base, {'upper_arm.R': {'r': (0, -0.2, -2.5)}, 'forearm.R': {'r': (0, 0, -0.4 + 0.5 * k)}, 'brow.L': {'l': (0, 0, 0.004)}, 'brow.R': {'l': (0, 0, 0.004)}, 'head': {'r': (-0.08, 0, 0.08)}, 'jaw': {'r': (0.06, 0, 0)}})
    act('wave', 36, [(0, base), (8, wave_(1)), (14, wave_(-1)), (20, wave_(1)), (26, wave_(-1)), (36, base)], False)
    lie = P({'hips': {'r': (-math.pi / 2, 0, 0), 'l': (0, -(0.53 * h - 0.62), 0)}, 'upper_arm.L': {'r': (0, 0, 0.15)}, 'upper_arm.R': {'r': (0, 0, -0.15)}, 'thigh.L': {'r': (0, 0, 0.03)}, 'thigh.R': {'r': (0, 0, -0.03)}}, closed)
    act('sleep', 48, [(0, lie), (24, P(lie, {'chest': {'r': (-0.03, 0, 0)}})), (48, lie)])
    rig.animation_data.action = bpy.data.actions['idle']

def build_avatar(body):
    reset(); b = BODIES[body]; rig, P = build_rig(b)
    edges = TORSO + arm('L') + arm('R') + leg('L') + leg('R')
    skin = skin_mesh('body', P, edges, body_radii(b), 'skin'); cube_uv(skin, 0.25); auto_weights(skin, rig)
    head_parts, hc = build_head(b, rig, P)
    hair = hair_variants(b, rig, hc, b['head']); clothes = outfits(b, rig, P)
    build_actions(rig, b)
    os.makedirs(OUT('source'), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=OUT('source', f'avatar_{body}.blend'))
    export([rig], OUT('models', 'avatars', f'avatar_{body}.glb'), anim=True)
    tris = sum(len(o.data.polygons) for o in rig.children)
    print(f'[avatar] {body}: {len(rig.children)} meshes, {tris} faces')

# ------------------------------------------------------------------ furniture & building modules
def furniture():
    reset(); items = {}
    def item(name, parts):
        o = join(parts, name); cube_uv(o, 0.5); items[name] = o; return o
    W = 'walnut'
    # chair 0.5 x 0.5, back at +Y
    p = [prim('box', 'seat', 'linen', (0, 0, 0.44), (0.42, 0.42, 0.06))]
    for x in (-0.18, 0.18):
        for y in (-0.18, 0.18): p.append(prim('cyl', 'leg', W, (x, y, 0.21), (0.02, 0.02, 0.42), seg=10))
    p += [prim('box', 'back', W, (0, 0.19, 0.72), (0.4, 0.035, 0.36)), prim('box', 'rail', W, (0, 0, 0.405), (0.42, 0.42, 0.03))]
    item('chair', p)
    # table 1 x 1
    p = [prim('box', 'top', W, (0, 0, 0.74), (0.94, 0.94, 0.045))] + [prim('cyl', 'leg', W, (x, y, 0.36), (0.03, 0.03, 0.72), seg=12) for x in (-0.4, 0.4) for y in (-0.4, 0.4)]
    item('table', p)
    # bed 2 x 2, headboard +Y
    p = [prim('box', 'frame', W, (0, 0, 0.2), (1.9, 1.95, 0.25)), prim('box', 'mattress', 'linen', (0, -0.02, 0.4), (1.82, 1.85, 0.2)),
         prim('box', 'duvet', 'linen', (0, -0.25, 0.51), (1.86, 1.35, 0.06)), prim('box', 'throw', 'teal_paint', (0, -0.72, 0.545), (1.88, 0.4, 0.04)),
         prim('box', 'head', W, (0, 0.96, 0.6), (1.95, 0.06, 0.95))]
    for x in (-0.45, 0.45): p.append(prim('sphere', 'pillow', 'linen', (x, 0.72, 0.56), (0.36, 0.17, 0.07)))
    item('bed', p)
    # prep counter 1 x 0.5: teal cabinets, stone top, brass pulls, back at +Y
    p = [prim('box', 'cab', 'teal_paint', (0, 0.0, 0.43), (0.98, 0.5, 0.86)), prim('box', 'top', 'stone_top', (0, -0.01, 0.885), (1.0, 0.54, 0.04)),
         prim('box', 'kick', W, (0, -0.02, 0.04), (0.96, 0.44, 0.08)), prim('box', 'board', W, (0.15, -0.05, 0.92), (0.35, 0.22, 0.02)),
         prim('cyl', 'bowl', 'ceramic', (-0.25, 0, 0.94), (0.1, 0.1, 0.06), r2=0.6, seg=20)]
    for x in (-0.24, 0.24): p.append(prim('box', 'door_line', 'teal_paint', (x, -0.252, 0.45), (0.46, 0.01, 0.74))); p.append(prim('cyl', 'pull', 'brass', (x + (0.17 if x < 0 else -0.17), -0.265, 0.7), (0.008, 0.008, 0.12), seg=8))
    item('prep_counter', p)
    # floor lamp (emissive shade)
    item('lamp', [prim('cyl', 'base', 'brass', (0, 0, 0.015), (0.16, 0.16, 0.03), seg=24), prim('cyl', 'stem', 'brass', (0, 0, 0.75), (0.015, 0.015, 1.45), seg=10),
                  prim('cyl', 'shade', 'lamp_shade', (0, 0, 1.45), (0.2, 0.2, 0.28), r2=0.7, seg=24)])
    # rug 2 x 1.5
    item('rug', [prim('box', 'rug', 'rug', (0, 0, 0.006), (1.95, 1.45, 0.012))])
    # plant: terracotta pot, layered leaves
    p = [prim('cyl', 'pot', 'terracotta', (0, 0, 0.16), (0.17, 0.17, 0.32), r2=0.75, seg=24), prim('cyl', 'soil', 'soil', (0, 0, 0.31), (0.15, 0.15, 0.02), seg=20)]
    rnd = random.Random(3)
    for i in range(14):
        a = i * 2.4; r = 0.08 + rnd.random() * 0.12; z = 0.45 + rnd.random() * 0.5
        p.append(prim('sphere', 'leaf', 'leaf', (math.cos(a) * r, math.sin(a) * r, z), (0.13, 0.05, 0.015), rot=(0.5 * math.cos(a), 0.4, a), u=12, v=8))
        p.append(prim('cyl', 'stem', 'leaf', (math.cos(a) * r * 0.5, math.sin(a) * r * 0.5, (z + 0.3) / 2), (0.006, 0.006, z - 0.3), seg=6))
    item('plant', p)
    # shelf 1 x 0.5 with books and ceramics, back at +Y
    p = [prim('box', 's', W, (x, 0.0, 0.9), (0.03, 0.4, 1.8)) for x in (-0.48, 0.48)] + [prim('box', 'b', W, (0, 0.19, 0.9), (0.96, 0.02, 1.8))]
    for z in (0.05, 0.5, 0.95, 1.4, 1.78): p.append(prim('box', 'board', W, (0, 0, z), (0.94, 0.4, 0.03)))
    cols = ['book', 'teal_paint', 'terracotta', 'linen']
    for k, z in enumerate((0.5, 0.95)):
        for i in range(7): p.append(prim('box', 'bk', cols[(i + k) % 4], (-0.38 + i * 0.06, 0.02, z + 0.13), (0.045, 0.28, 0.22 + 0.04 * ((i * 7) % 3))))
    p.append(prim('sphere', 'vase', 'ceramic', (0.25, 0, 1.08), (0.08, 0.08, 0.1))); p.append(prim('cyl', 'jar', 'terracotta', (0.25, 0, 1.52), (0.07, 0.07, 0.18), seg=16))
    item('shelf', p)
    # shop furniture: register counter (customer side -Y, staff side +Y), glass display case, flower stand
    p = [prim('box', 'base', W, (0, 0, 0.5), (0.98, 0.5, 1.0)), prim('box', 'top', 'stone_top', (0, 0, 1.02), (1.0, 0.54, 0.04)),
         prim('box', 'front', 'teal_paint', (0, -0.252, 0.5), (0.9, 0.01, 0.8)),
         prim('box', 'till', 'brass', (0.22, 0.05, 1.12), (0.3, 0.26, 0.16)), prim('box', 'screen', 'glass', (0.22, 0.0, 1.27), (0.24, 0.02, 0.14), rot=(0.4, 0, 0)),
         prim('cyl', 'jar', 'glass', (-0.25, -0.05, 1.12), (0.08, 0.08, 0.18), seg=16), prim('box', 'pastry', 'terracotta', (-0.25, -0.05, 1.08), (0.1, 0.1, 0.05))]
    item('register', p)
    p = [prim('box', 'base', W, (0, 0, 0.35), (0.98, 0.5, 0.7)), prim('box', 'glass', 'glass', (0, -0.05, 0.95), (0.96, 0.42, 0.5)),
         prim('box', 'shelf', 'stone_top', (0, 0, 0.72), (0.94, 0.44, 0.03))]
    for i in range(5): p.append(prim('sphere', 'bun', 'terracotta', (-0.36 + i * 0.18, -0.05, 0.79), (0.07, 0.07, 0.045), u=12, v=8))
    for i in range(3): p.append(prim('cyl', 'loaf', 'walnut', (-0.3 + i * 0.3, 0.05, 1.0), (0.06, 0.06, 0.22), rot=(0, math.pi / 2, 0), seg=12))
    item('display_case', p)
    p = [prim('box', 'step1', W, (0, 0.1, 0.2), (0.96, 0.3, 0.4)), prim('box', 'step2', W, (0, -0.1, 0.45), (0.96, 0.28, 0.08))]
    rnd2 = random.Random(9); cols = ['terracotta', 'linen', 'teal_paint', 'leaf']
    for i in range(6):
        x = -0.38 + i * 0.15; z0 = 0.42 if i % 2 else 0.52
        p.append(prim('cyl', 'bucket', 'brass', (x, -0.1 if i % 2 else 0.1, z0), (0.06, 0.06, 0.14), seg=12))
        for k in range(5): p.append(prim('sphere', 'bloom', cols[(i + k) % 3], (x + rnd2.uniform(-0.05, 0.05), (-0.1 if i % 2 else 0.1) + rnd2.uniform(-0.05, 0.05), z0 + 0.2 + rnd2.uniform(0, 0.12)), (0.045, 0.045, 0.04), u=10, v=6))
    item('flower_stand', p)
    for n, o in items.items(): export([o], OUT('models', 'furniture', n + '.glb'))
    # ---- building modules
    b = {}
    # door module: 1.0 m opening in a wall cell pair; frame + teal door (hinged leaf separate object)
    fr = [prim('box', 'jl', W, (-0.47, 0, 1.05), (0.06, 0.26, 2.1)), prim('box', 'jr', W, (0.47, 0, 1.05), (0.06, 0.26, 2.1)), prim('box', 'hd', W, (0, 0, 2.13), (1.0, 0.26, 0.06)),
          prim('box', 'lintel', 'stucco', (0, 0, 2.43), (1.0, 0.24, 0.54))]
    b['door_frame'] = join(fr, 'door_frame')
    b['door_leaf'] = join([prim('box', 'leaf', 'teal_paint', (0.44, 0, 1.04), (0.88, 0.045, 2.06)), prim('sphere', 'knob', 'brass', (0.8, -0.04, 1.0), (0.03, 0.03, 0.03)),
                           prim('box', 'panel', 'teal_paint', (0.44, -0.03, 1.45), (0.62, 0.02, 0.7)), prim('box', 'panel2', 'teal_paint', (0.44, -0.03, 0.55), (0.62, 0.02, 0.7))], 'door_leaf')
    # window module: 1 m wide, sill 0.9, glass
    b['window'] = join([prim('box', 'sill', 'stucco', (0, 0, 0.45), (1.0, 0.24, 0.9)), prim('box', 'top', 'stucco', (0, 0, 2.35), (1.0, 0.24, 0.7)),
                        prim('box', 'f1', W, (0, 0, 0.92), (1.0, 0.27, 0.05)), prim('box', 'f2', W, (0, 0, 1.98), (1.0, 0.27, 0.05)), prim('box', 'f3', W, (-0.48, 0, 1.45), (0.05, 0.27, 1.1)), prim('box', 'f4', W, (0.48, 0, 1.45), (0.05, 0.27, 1.1)),
                        prim('box', 'mull', W, (0, 0, 1.45), (0.035, 0.1, 1.06)), prim('box', 'glass', 'glass', (0, 0, 1.45), (0.92, 0.02, 1.02))], 'window')
    # arched porch bay: 2 m wide, columns at ±1 (each column owns its own cell), arch spans
    ap = [prim('box', 'colL', 'stucco', (-0.875, 0, 1.2), (0.25, 0.25, 2.4)), prim('box', 'colR', 'stucco', (0.875, 0, 1.2), (0.25, 0.25, 2.4)), prim('box', 'beam', 'stucco', (0, 0, 2.6), (2.0, 0.25, 0.4))]
    bm = bmesh.new(); seg = 18; r = 0.75; zc = 1.85
    pts = [(-r + 0.0 + (r - r * math.cos(math.pi * i / seg)) - r + r, 0) for i in range(seg + 1)]
    for i in range(seg):  # arch infill between columns and beam
        a0 = math.pi * i / seg; a1 = math.pi * (i + 1) / seg
        x0, z0 = -math.cos(a0) * r, zc + math.sin(a0) * 0.6; x1, z1 = -math.cos(a1) * r, zc + math.sin(a1) * 0.6
        for y in (-0.12, 0.12): pass
        vs = [bm.verts.new(v) for v in [(x0, -0.12, z0), (x1, -0.12, z1), (x1, -0.12, 2.4), (x0, -0.12, 2.4), (x0, 0.12, z0), (x1, 0.12, z1), (x1, 0.12, 2.4), (x0, 0.12, 2.4)]]
        bm.faces.new((vs[0], vs[1], vs[2], vs[3])); bm.faces.new((vs[7], vs[6], vs[5], vs[4])); bm.faces.new((vs[0], vs[4], vs[5], vs[1]))
    ap.append(obj_from_bm('arch', bm, 'stucco'))
    b['porch_arch'] = join(ap, 'porch_arch')
    # brass pendant (hangs from 2.7 m ceiling)
    b['pendant'] = join([prim('cyl', 'cord', 'brass', (0, 0, 2.35), (0.006, 0.006, 0.7), seg=6), prim('sphere', 'dome', 'brass', (0, 0, 1.98), (0.2, 0.2, 0.14), u=24, v=12),
                         prim('sphere', 'bulb', 'lamp_shade', (0, 0, 1.93), (0.07, 0.07, 0.07))], 'pendant')
    for n, o in b.items(): cube_uv(o, 0.5); export([o], OUT('models', 'building', n + '.glb'))
    bpy.ops.wm.save_as_mainfile(filepath=OUT('source', 'furniture_and_building.blend'))
    print('[props] exported', list(items) + list(b))

if __name__ == '__main__':
    args = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
    if not args or 'textures' in args: make_textures()
    if not args or 'audio' in args: make_audio()
    if not args or 'props' in args: furniture()
    for body in BODIES:
        if not args or 'avatars' in args or body in args: build_avatar(body)
    print('[done]')
