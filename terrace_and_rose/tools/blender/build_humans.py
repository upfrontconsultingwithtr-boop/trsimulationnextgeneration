"""Realistic human bodies for Terrace & Rose.

Built with MPFB (MakeHuman for Blender, GPL add-on — a tool, not shipped) and MakeHuman CC0 asset packs
(skins, eyes, eyebrows, eyelashes, teeth, hair, clothes, shoes). Output characters are CC0.

Each body GLB contains: one shared game skeleton (MPFB "game_engine"), body, eyes, brows, lashes, teeth,
hair_<style> variants, outfit_<id> variants, shoes, and blend shapes (morphs) refitted on every mesh:
african, asian, caucasian, heavy, slim, muscular, older, bust. Godot mixes these per character, so faces
and bodies are unique, editable in the creator and inheritable by children.
Animations are transferred from the hand-keyed set in build_assets.py by matching posed bone orientations.

Setup and run: see tools/blender/README_humans.md
"""
import bpy, os, sys, math, importlib, addon_utils
import numpy as np
from mathutils import Matrix, Vector

HERE = os.path.dirname(__file__)
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
OUT = lambda *p: os.path.join(ROOT, 'assets', *p)
sys.path.insert(0, HERE)
import build_assets as BA   # reuse the original rig + animation definitions

MOD = next(m.__name__ for m in addon_utils.modules() if m.__name__.endswith('mpfb'))
def enable():
    addon_utils.enable(MOD, default_set=True)
enable()
svc = lambda n: importlib.import_module(MOD + '.services.' + n.lower())
HS = svc('humanservice').HumanService
TS = svc('targetservice').TargetService
CS = svc('clothesservice').ClothesService
DATA = svc('locationservice').LocationService.get_user_data()
HOP = importlib.import_module(MOD + '.entities.objectproperties').HumanObjectProperties
A = lambda *p: os.path.join(DATA, *p)

def age_value(years):   # MakeHuman: 0.1875 = 11 y, 0.5 = 25 y, 1.0 = 90 y
    return 0.5 + (years - 25) / 130.0 if years >= 25 else 0.1875 + (years - 11) / 14.0 * 0.3125

NEUTRAL_RACE = dict(african=1 / 3, asian=1 / 3, caucasian=1 / 3)
BODIES = {
    'f_adult': dict(gender=0.0, age=age_value(32), weight=0.55, muscle=0.45, proportions=0.6, height=0.45, cupsize=0.55),
    'm_adult': dict(gender=1.0, age=age_value(32), weight=0.5, muscle=0.5, proportions=0.6, height=0.55, cupsize=0.5),
    'f_elder': dict(gender=0.0, age=age_value(70), weight=0.6, muscle=0.35, proportions=0.5, height=0.4, cupsize=0.5),
    'm_elder': dict(gender=1.0, age=age_value(70), weight=0.55, muscle=0.4, proportions=0.5, height=0.5, cupsize=0.5),
    'f_teen':  dict(gender=0.0, age=age_value(15), weight=0.45, muscle=0.45, proportions=0.55, height=0.45, cupsize=0.4),
    'm_teen':  dict(gender=1.0, age=age_value(15), weight=0.45, muscle=0.5, proportions=0.55, height=0.5, cupsize=0.5),
    'child':   dict(gender=0.5, age=age_value(9), weight=0.5, muscle=0.5, proportions=0.5, height=0.5, cupsize=0.5),
}
# morph name -> macro overrides (relative to the body's base)
MORPHS = {
    'african': dict(race=dict(african=1.0, asian=0.0, caucasian=0.0)),
    'asian': dict(race=dict(african=0.0, asian=1.0, caucasian=0.0)),
    'caucasian': dict(race=dict(african=0.0, asian=0.0, caucasian=1.0)),
    'heavy': dict(weight=1.0), 'slim': dict(weight=0.05), 'muscular': dict(muscle=1.0),
    'older': dict(age_years=+22), 'bust': dict(cupsize=1.0),
}
HAIRS = {'coils': 'afro01', 'wavy': 'short02', 'curls_short': 'short04', 'bun': 'rehmanpolanski_hair_bun_brown', 'long': 'long01', 'braid': 'braid01', 'bob': 'bob02'}
OUTFITS = {'casual': 'female_casualsuit01', 'shirt': 'male_casualsuit01', 'knit_jacket': 'male_casualsuit05', 'dress': 'female_elegantsuit01', 'overalls': 'male_worksuit01'}
OUTFIT_BITS = {k: i for i, k in enumerate(OUTFITS)}   # body vertex bitmask: covered by outfit k -> hide skin there

def clear():
    bpy.ops.wm.read_factory_settings(use_empty=True); BA.MATS.clear(); enable()

def mhclo(kind, name):
    d = A(kind, name)
    return os.path.join(d, next(f for f in os.listdir(d) if f.endswith('.mhclo')))

def set_macro(base, md):
    for k, v in md.items():
        if k == 'race':
            for r, rv in v.items(): HOP.set_value(r, rv, entity_reference=base)
        else: HOP.set_value(k, v, entity_reference=base)
    TS.reapply_macro_details(base)

def macro_for(body, morph):
    md = dict(BODIES[body]); md['race'] = dict(NEUTRAL_RACE)
    for k, v in MORPHS.get(morph, {}).items():
        if k == 'age_years': md['age'] = min(1.0, md['age'] + v / 130.0)
        else: md[k] = v
    return md

def eval_coords(o):
    dg = bpy.context.evaluated_depsgraph_get()
    e = o.evaluated_get(dg); me = e.to_mesh()
    co = np.empty(len(me.vertices) * 3, np.float32); me.vertices.foreach_get('co', co)
    e.to_mesh_clear()
    return co.reshape(-1, 3)

def build(body):
    clear()
    base = HS.create_human(macro_detail_dict=macro_for(body, ''), feet_on_ground=True, scale=0.1)
    rig = HS.add_builtin_rig(base, 'game_engine')
    skin = 'young_african_female' if body.startswith('f') or body == 'child' else 'young_african_male'
    HS.set_character_skin(A('skins', skin, skin + '.mhmat'), base, skin_type='MAKESKIN')
    named = {}
    def add(path, kind, nm):
        before = set(rig.children)
        HS.add_mhclo_asset(path, base, asset_type=kind, subdiv_levels=0, material_type='MAKESKIN')
        for o in set(rig.children) - before: named[o.name] = nm
    add(A('eyes', 'high-poly', 'high-poly.mhclo'), 'Eyes', 'eyes')
    add(mhclo('eyebrows', 'eyebrow001'), 'Eyebrows', 'brows')
    add(mhclo('eyelashes', 'eyelashes01'), 'Eyelashes', 'lashes')
    add(mhclo('teeth', 'teeth_base'), 'Teeth', 'teeth')
    for k, h in HAIRS.items(): add(mhclo('hair', h), 'Hair', 'hair_' + k)
    for k, c in OUTFITS.items(): add(mhclo('clothes', c), 'Clothes', 'outfit_' + k)
    add(mhclo('clothes', 'shoes02'), 'Clothes', 'shoes')
    meshes = [o for o in rig.children if o.type == 'MESH']
    # skin under clothes: record per-vertex bitmask from MPFB delete groups, then drop the delete modifiers
    bits = np.zeros(len(base.data.vertices), np.int32)
    for k, c in OUTFITS.items():
        vg = base.vertex_groups.get('Delete.' + c) or next((g for g in base.vertex_groups if g.name.lower().startswith('delete') and c in g.name), None)
        if vg is None: continue
        for v in base.data.vertices:
            for g in v.groups:
                if g.group == vg.index and g.weight > 0.5: bits[v.index] |= 1 << OUTFIT_BITS[k]
    for m in list(base.modifiers):
        if m.name.startswith('Delete'): base.modifiers.remove(m)
    for o in meshes:
        for m in o.modifiers:
            if m.type == 'ARMATURE': m.show_viewport = False
    # capture morphs: change the macro, refit every proxy, record evaluated vertex positions
    captures = {}
    for morph in MORPHS:
        if morph == 'bust' and not body.startswith('f'): continue
        set_macro(base, macro_for(body, morph))
        for o in meshes:
            if o is not base: CS.fit_clothes_to_human(o, base, set_parent=False)
        bpy.context.view_layer.update()
        captures[morph] = {o.name: eval_coords(o) for o in meshes}
    set_macro(base, macro_for(body, ''))
    for o in meshes:
        if o is not base: CS.fit_clothes_to_human(o, base, set_parent=False)
    bpy.context.view_layer.update()
    # bake base shape, apply masks, then add morph shape keys
    for o in meshes:
        bpy.context.view_layer.objects.active = o
        if o.data.shape_keys:
            o.shape_key_add(name='final', from_mix=True)
            for kb in list(o.data.shape_keys.key_blocks):
                if kb.name != 'final': o.shape_key_remove(kb)
            o.shape_key_remove(o.data.shape_keys.key_blocks['final'])
        keep_idx = None
        if o is base:   # the helper mask removes vertices; track which survive for the bitmask
            o.data.attributes.new('orig_index', 'INT', 'POINT').data.foreach_set('value', np.arange(len(o.data.vertices), dtype=np.int32))
        for m in list(o.modifiers):
            if m.type != 'ARMATURE':
                try: bpy.ops.object.modifier_apply(modifier=m.name)
                except Exception as e: print('modifier', o.name, m.name, e)
        o.modifiers.foreach_set if False else None
        for m in o.modifiers:
            if m.type == 'ARMATURE': m.show_viewport = True
        n = len(o.data.vertices)
        o.shape_key_add(name='Basis', from_mix=False)
        for morph, cap in captures.items():
            co = cap.get(o.name)
            if co is None or len(co) != n: print('skip morph', morph, o.name, None if co is None else len(co), n); continue
            kb = o.shape_key_add(name=morph, from_mix=False); kb.data.foreach_set('co', co.ravel())
        # rename object + material for the game
        nm = 'body' if o is base else named.get(o.name, o.name)
        o.name = nm; o.data.name = nm
        mat_name = {'body': 'skin', 'eyes': 'eye', 'brows': 'brow', 'lashes': 'lash', 'teeth': 'teeth', 'shoes': 'shoes'}.get(nm, nm.replace('outfit_', 'cloth_'))
        for i, slot in enumerate(o.material_slots):
            if slot.material: slot.material = slot.material.copy() if slot.material.users > 1 else slot.material; slot.material.name = mat_name if i == 0 else f'{mat_name}_{i}'
        # vertex colour data for the game shader
        col = o.data.color_attributes.new('Col', 'FLOAT_COLOR', 'CORNER')
        cols = np.zeros((len(o.data.loops), 4), np.float32); cols[:, 3] = 1.0
        if o is base:
            orig = np.empty(n, np.int32); o.data.attributes['orig_index'].data.foreach_get('value', orig)
            vbits = bits[orig] / 31.0
            li = np.empty(len(o.data.loops), np.int32); o.data.loops.foreach_get('vertex_index', li)
            cols[:, 0] = vbits[li]
        elif nm.startswith('outfit_'):
            cols[:] = region_colours(o, base, nm[7:])
        col.data.foreach_set('color', cols.ravel())
        o.data.color_attributes.active_color = col
    # game-sized textures
    for img in bpy.data.images:
        lim = 1024 if 'skin' in img.name.lower() or 'young' in img.name.lower() else 512
        if img.size[0] > lim: img.scale(lim, max(1, int(img.size[1] * lim / img.size[0])))
    retarget_animations(rig, base)
    rig.name = 'Rig'
    bpy.ops.object.select_all(action='DESELECT')
    rig.select_set(True)
    for o in rig.children: o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=OUT('models', 'humans', f'human_{body}.glb'), export_format='GLB', use_selection=True, export_yup=True,
                              export_apply=False, export_skins=True, export_morph=True, export_morph_normal=False, export_animations=True,
                              export_animation_mode='ACTIONS', export_force_sampling=True, export_image_format='JPEG', export_jpeg_quality=85,
                              export_vertex_color='ACTIVE', export_all_vertex_colors=False)
    print(f'[human] {body}: {len(meshes)} meshes, morphs={list(captures)}, faces={sum(len(o.data.polygons) for o in meshes)}')

def region_colours(o, base, outfit):
    """Per-corner colour: R = top, G = bottom, B = outer layer (A = 1).
    Classified per connected garment piece: pieces reaching below the knee are bottoms (trousers, skirt, overalls);
    for the knit jacket, the upper piece furthest from the skin is the outer jacket, the other the knit."""
    import bmesh
    from mathutils.bvhtree import BVHTree
    bvh = BVHTree.FromObject(base, bpy.context.evaluated_depsgraph_get())
    zs = [v.co.z for v in base.data.vertices]; h = max(zs) - min(zs); z0 = min(zs)
    bm = bmesh.new(); bm.from_mesh(o.data); bm.faces.ensure_lookup_table()
    seen = set(); islands = []
    for f in bm.faces:
        if f.index in seen: continue
        stack = [f]; isl = []; seen.add(f.index)
        while stack:
            cur = stack.pop(); isl.append(cur.index)
            for e in cur.edges:
                for nf in e.link_faces:
                    if nf.index not in seen: seen.add(nf.index); stack.append(nf)
        islands.append(isl)
    info = []
    for isl in islands:
        cs = [bm.faces[i].calc_center_median() for i in isl]
        minz = min(c.z for c in cs); n = len(cs)
        sample = cs[::max(1, n // 60)]
        dist = sum((bvh.find_nearest(c)[3] or 0.0) for c in sample) / len(sample)
        info.append({'faces': isl, 'minz': minz, 'dist': dist, 'n': n})
    for it in info: it['region'] = 1 if it['minz'] < z0 + h * 0.3 else 0
    if outfit == 'knit_jacket':
        uppers = [it for it in info if it['region'] == 0 and it['n'] > 50]
        if len(uppers) >= 2:
            max(uppers, key=lambda it: it['dist'])['region'] = 2
    face_region = {}
    for it in info:
        for fi in it['faces']: face_region[fi] = it['region']
    bm.free()
    out = np.zeros((len(o.data.loops), 4), np.float32); out[:, 3] = 1
    for p in o.data.polygons:
        r = face_region.get(p.index, 0)
        for li in p.loop_indices: out[li, r] = 1.0
    return out

# ---------------------------------------------------------------- animation transfer
MAP = {'hips': 'pelvis', 'spine': 'spine_01', 'chest': 'spine_03', 'neck': 'neck_01', 'head': 'head',
       'upper_arm.L': 'upperarm_l', 'forearm.L': 'lowerarm_l', 'hand.L': 'hand_l', 'thigh.L': 'thigh_l', 'shin.L': 'calf_l', 'foot.L': 'foot_l',
       'upper_arm.R': 'upperarm_r', 'forearm.R': 'lowerarm_r', 'hand.R': 'hand_r', 'thigh.R': 'thigh_r', 'shin.R': 'calf_r', 'foot.R': 'foot_r'}
ORDER = ['hips', 'spine', 'chest', 'neck', 'head', 'upper_arm.L', 'forearm.L', 'hand.L', 'upper_arm.R', 'forearm.R', 'hand.R',
         'thigh.L', 'shin.L', 'foot.L', 'thigh.R', 'shin.R', 'foot.R']

def retarget_animations(rig, base):
    zs = [v.co.z for v in base.data.vertices]; height = max(zs) - min(zs)
    spec = dict(BA.BODIES['classic']); spec['h'] = height; spec['stoop'] = 0.0
    old, _ = BA.build_rig(spec); old.name = 'OldRig'
    BA.build_actions(old, spec)
    acts = [a for a in bpy.data.actions if a.name in ('idle', 'walk', 'sit_down', 'stand_up', 'sit_idle', 'sit_eat', 'eat', 'cook', 'wave', 'sleep')]
    scene = bpy.context.scene
    ob, nb = old.pose.bones, rig.pose.bones
    # per bone: keep the new bone's twist relative to the old one but align its direction with the OLD bone,
    # so the old rig's posed limb directions (arms down, etc.) carry over regardless of the new rest pose
    rest_off = {}
    for k, v in MAP.items():
        K = old.data.bones[k].matrix_local.to_3x3().inverted() @ rig.data.bones[v].matrix_local.to_3x3()
        swing = Vector(K.col[1]).normalized().rotation_difference(Vector((0, 1, 0))).to_matrix()
        rest_off[k] = swing @ K
    hips_rest_old = old.data.bones['hips'].head_local.copy()
    pelvis_rest = rig.data.bones['pelvis'].head_local.copy()
    rig.animation_data_create()
    for pb in nb: pb.rotation_mode = 'QUATERNION'
    for act in acts:
        frames = sorted({int(k.co.x) for fc in act.fcurves for k in fc.keyframe_points})
        new = bpy.data.actions.new(act.name + '__new'); new.use_fake_user = True
        rig.animation_data.action = new
        old.animation_data.action = act
        for f in frames:
            scene.frame_set(f)
            for pb in nb: pb.matrix_basis = Matrix.Identity(4)
            bpy.context.view_layer.update()
            for k in ORDER:
                src = ob[k]; dst = nb[MAP[k]]
                R = src.matrix.to_3x3() @ rest_off[k]
                M = R.to_4x4()
                if k == 'hips': M.translation = pelvis_rest + (src.head - hips_rest_old)
                else: M.translation = dst.matrix.translation
                dst.matrix = M
                bpy.context.view_layer.update()
            for k in ORDER:
                dst = nb[MAP[k]]
                dst.keyframe_insert('rotation_quaternion', frame=f)
                if k == 'hips': dst.keyframe_insert('location', frame=f)
        new.frame_range = act.frame_range
    for act in acts: bpy.data.actions.remove(act)
    for a in list(bpy.data.actions):
        if a.name.endswith('__new'): a.name = a.name[:-5]
    rig.animation_data.action = bpy.data.actions['idle']
    for pb in nb: pb.matrix_basis = Matrix.Identity(4)
    meshes = [c for c in old.children]
    for c in meshes: bpy.data.objects.remove(c)
    bpy.data.objects.remove(old)

if __name__ == '__main__':
    os.makedirs(OUT('models', 'humans'), exist_ok=True)
    args = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
    for b in BODIES:
        if not args or b in args: build(b)
