# -*- coding: utf-8 -*-
"""
Génère les modèles 3D du jeu (style low-poly) dans Blender :
personnages animés (survivant, zombies) et armes.

Utilisation : dans Blender, onglet Scripting, console Python :
    exec(open(r'E:\\_jeu perso\\JeuZombie\\blender\\generer_modeles.py', encoding='utf-8').read())
ou en ligne de commande :
    blender.exe -b -P generer_modeles.py

Sorties :
    jeu-zombie/modeles/*.glb  (utilisés par le jeu)
    blender/fichiers/*.blend  (modifiables dans Blender)
"""
import bpy
import bmesh
import math
import os
import traceback
from mathutils import Vector, Matrix, Euler, Quaternion

BASE = r"E:\_jeu perso\JeuZombie"
OUT_GLB = os.path.join(BASE, "jeu-zombie", "modeles")
OUT_BLEND = os.path.join(BASE, "blender", "fichiers")
LOG = os.path.join(BASE, "blender", "log.txt")
os.makedirs(OUT_GLB, exist_ok=True)
os.makedirs(OUT_BLEND, exist_ok=True)

# Liste des modèles à générer (None = tout)
SEULEMENT = globals().get("SEULEMENT", None)

_log_lines = []


def log(*args):
    line = " ".join(str(a) for a in args)
    _log_lines.append(line)
    with open(LOG, "w", encoding="utf-8") as f:
        f.write("\n".join(_log_lines) + "\n")


# ====================================================================== outils
def srgb(c):
    """Couleur sRGB (0-1) -> linéaire pour Blender."""
    return tuple((x / 12.92) if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c)


def clear_scene():
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    for coll in (bpy.data.meshes, bpy.data.armatures, bpy.data.actions, bpy.data.materials):
        for b in list(coll):
            try:
                coll.remove(b)
            except Exception:
                pass


def make_mat(name, color, rough=0.85, metal=0.0, emit=None):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    lin = srgb(color)
    m.diffuse_color = (*lin, 1.0)
    bsdf = None
    for n in m.node_tree.nodes:
        if n.type == "BSDF_PRINCIPLED":
            bsdf = n
    if bsdf:
        bsdf.inputs["Base Color"].default_value = (*lin, 1.0)
        bsdf.inputs["Roughness"].default_value = rough
        bsdf.inputs["Metallic"].default_value = metal
        if emit is not None:
            for key in ("Emission Color", "Emission"):
                if key in bsdf.inputs:
                    bsdf.inputs[key].default_value = (*srgb(emit), 1.0)
                    break
            if "Emission Strength" in bsdf.inputs:
                bsdf.inputs["Emission Strength"].default_value = 1.5
    return m


class Builder:
    """Construit un maillage low-poly à partir de boîtes / cylindres biseautés."""

    def __init__(self, materials):
        # materials : liste de (nom, couleur, rugosité, métal[, émission])
        self.bm = bmesh.new()
        self.dl = self.bm.verts.layers.deform.verify()
        self.mat_names = []
        self.mats = []
        for spec in materials:
            self.mat_names.append(spec[0])
            self.mats.append(make_mat(*spec))
        self.groups = []

    def _mi(self, name):
        return self.mat_names.index(name)

    def _gi(self, group):
        if group is None:
            return None
        if group not in self.groups:
            self.groups.append(group)
        return self.groups.index(group)

    def _finish(self, before_faces, before_verts, mat, group, bevel, edges):
        if bevel > 0 and edges:
            try:
                bmesh.ops.bevel(self.bm, geom=list(edges), offset=bevel, segments=1,
                                affect="EDGES", profile=0.5, clamp_overlap=True)
            except TypeError:
                bmesh.ops.bevel(self.bm, geom=list(edges), offset=bevel, segments=1, profile=0.5)
        mi = self._mi(mat)
        gi = self._gi(group)
        for f in self.bm.faces:
            if f not in before_faces:
                f.material_index = mi
        if gi is not None:
            for v in self.bm.verts:
                if v not in before_verts:
                    v[self.dl][gi] = 1.0

    def box(self, center, size, mat, group=None, rot=(0, 0, 0), bevel=0.012, taper=(1.0, 1.0)):
        """Boîte centrée. taper = échelle (x, y) de la face du haut (Z+) pour des formes coniques."""
        bf = set(self.bm.faces)
        bv = set(self.bm.verts)
        res = bmesh.ops.create_cube(self.bm, size=1.0)
        verts = res["verts"]
        for v in verts:
            x, y, z = v.co.x * size[0], v.co.y * size[1], v.co.z * size[2]
            if v.co.z > 0:
                x *= taper[0]
                y *= taper[1]
            v.co = Vector((x, y, z))
        rm = Euler(tuple(math.radians(a) for a in rot)).to_matrix().to_4x4()
        bmesh.ops.transform(self.bm, matrix=Matrix.Translation(Vector(center)) @ rm, verts=verts)
        edges = set()
        for v in verts:
            for e in v.link_edges:
                edges.add(e)
        bev = min(bevel, min(size) * 0.3)
        self._finish(bf, bv, mat, group, bev, edges)

    def cyl(self, center, radius, depth, mat, group=None, rot=(0, 0, 0), segments=8, radius2=None, bevel=0.0):
        """Cylindre (axe Z local) ; rot pour l'orienter."""
        bf = set(self.bm.faces)
        bv = set(self.bm.verts)
        rm = Euler(tuple(math.radians(a) for a in rot)).to_matrix().to_4x4()
        mtx = Matrix.Translation(Vector(center)) @ rm
        res = bmesh.ops.create_cone(self.bm, cap_ends=True, cap_tris=False, segments=segments,
                                    radius1=radius, radius2=radius if radius2 is None else radius2,
                                    depth=depth, matrix=mtx)
        edges = set()
        if bevel > 0:
            for v in res["verts"]:
                for e in v.link_edges:
                    edges.add(e)
        self._finish(bf, bv, mat, group, bevel, edges)

    def to_object(self, name):
        me = bpy.data.meshes.new(name)
        self.bm.normal_update()
        self.bm.to_mesh(me)
        self.bm.free()
        for m in self.mats:
            me.materials.append(m)
        for p in me.polygons:
            p.use_smooth = False
        obj = bpy.data.objects.new(name, me)
        bpy.context.scene.collection.objects.link(obj)
        for g in self.groups:
            obj.vertex_groups.new(name=g)
        return obj


def export(objs, name, active=None):
    path_glb = os.path.join(OUT_GLB, name + ".glb")
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = active or objs[0]
    kw = dict(filepath=path_glb, export_format="GLB", use_selection=True,
              export_animations=True, export_yup=True, export_apply=False)
    try:
        bpy.ops.export_scene.gltf(export_animation_mode="ACTIONS", **kw)
    except TypeError:
        bpy.ops.export_scene.gltf(**kw)
    try:
        bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT_BLEND, name + ".blend"), copy=True)
    except Exception as e:
        log("  (blend non enregistré :", e, ")")
    log("  ->", path_glb)


# ====================================================================== squelette humain
# Le personnage regarde vers +Y (= -Z dans Godot), pieds à Z=0, droite = +X.
BONES = [
    # nom, tête, queue, parent
    ("hanches", (0, 0, 0.95), (0, 0, 1.08), None),
    ("colonne", (0, 0, 1.08), (0, 0, 1.32), "hanches"),
    ("torse", (0, 0, 1.32), (0, 0, 1.50), "colonne"),
    ("cou", (0, 0, 1.50), (0, 0, 1.58), "torse"),
    ("tete", (0, 0, 1.58), (0, 0, 1.82), "cou"),
]
for side, sx in (("R", 1), ("L", -1)):
    BONES += [
        ("epaule." + side, (sx * 0.06, 0, 1.46), (sx * 0.19, 0, 1.46), "torse"),
        ("bras." + side, (sx * 0.20, 0, 1.46), (sx * 0.22, 0, 1.18), "epaule." + side),
        ("avantbras." + side, (sx * 0.22, 0, 1.18), (sx * 0.23, 0, 0.94), "bras." + side),
        ("main." + side, (sx * 0.23, 0, 0.94), (sx * 0.23, 0, 0.84), "avantbras." + side),
        ("cuisse." + side, (sx * 0.10, 0, 0.95), (sx * 0.10, 0, 0.52), "hanches"),
        ("tibia." + side, (sx * 0.10, 0, 0.52), (sx * 0.10, 0, 0.09), "cuisse." + side),
        ("pied." + side, (sx * 0.10, 0, 0.09), (sx * 0.10, 0.14, 0.035), "tibia." + side),
    ]


def make_armature(name):
    arm_data = bpy.data.armatures.new(name + "_squelette")
    arm = bpy.data.objects.new(name + "_squelette", arm_data)
    bpy.context.scene.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm_data.edit_bones
    for bn, h, t, par in BONES:
        b = eb.new(bn)
        b.head = Vector(h)
        b.tail = Vector(t)
        b.roll = 0.0
        if par:
            b.parent = eb[par]
            b.use_connect = False
    bpy.ops.object.mode_set(mode="OBJECT")
    for pb in arm.pose.bones:
        pb.rotation_mode = "QUATERNION"
    return arm


def body_base(b, style):
    """Corps humain low-poly commun (survivant et zombies)."""
    S = style
    # bassin / ventre / torse
    b.box((0, 0, 1.0), (0.34, 0.2, 0.17), "Bas", "hanches", bevel=0.03)
    b.box((0, 0, 1.2), (0.31, 0.19, 0.25), "Haut", "colonne", bevel=0.035, taper=(1.08, 1.05))
    b.box((0, 0, 1.40), (0.40, 0.23, 0.22), "Haut", "torse", bevel=0.045, taper=(0.92, 0.95))
    # cou / tête
    b.box((0, 0, 1.54), (0.1, 0.1, 0.09), "Peau", "cou", bevel=0.02)
    b.box((0, 0.015, 1.68), (0.22, 0.24, 0.25), "Peau", "tete", bevel=0.06, taper=(0.95, 0.92))
    b.box((0, 0.135, 1.645), (0.045, 0.04, 0.06), "Peau", "tete", bevel=0.012)  # nez
    for sx in (1, -1):
        b.box((sx * 0.052, 0.127, 1.695), (0.04, 0.012, 0.028), "Yeux", "tete", bevel=0.004)
        b.box((sx * 0.052, 0.13, 1.722), (0.055, 0.012, 0.012), "Cheveux", "tete", bevel=0.003)  # sourcils
        b.box((sx * 0.115, 0.005, 1.67), (0.025, 0.05, 0.06), "Peau", "tete", bevel=0.01)  # oreilles
    if S.get("cheveux", True):
        b.box((0, -0.005, 1.78), (0.235, 0.255, 0.075), "Cheveux", "tete", bevel=0.03)
        b.box((0, -0.085, 1.7), (0.235, 0.085, 0.17), "Cheveux", "tete", bevel=0.03)
    # bouche
    b.box((0, 0.128, 1.6), (0.07, 0.012, 0.012 if not S.get("bouche_ouverte") else 0.03), "Bouche", "tete", bevel=0.003)
    for side, sx in (("R", 1), ("L", -1)):
        b.box((sx * 0.215, 0, 1.33), (0.115, 0.115, 0.29), "Manche", "bras." + side, bevel=0.03, taper=(0.9, 0.9))
        b.box((sx * 0.225, 0, 1.065), (0.095, 0.095, 0.25), S.get("avantbras", "Peau"), "avantbras." + side, bevel=0.025, taper=(1.1, 1.1))
        b.box((sx * 0.232, 0.012, 0.885), (0.075, 0.05, 0.11), "Peau", "main." + side, bevel=0.018)
        b.box((sx * 0.1, 0, 0.74), (0.155, 0.165, 0.44), "Bas", "cuisse." + side, bevel=0.035, taper=(1.12, 1.08))
        b.box((sx * 0.1, 0, 0.3), (0.125, 0.135, 0.42), "Bas", "tibia." + side, bevel=0.03, taper=(1.1, 1.05))
        b.box((sx * 0.1, 0.045, 0.05), (0.125, 0.26, 0.1), "Chaussures", "pied." + side, bevel=0.03)


# ====================================================================== animations
def _rest(arm):
    return {b.name: b.matrix_local.to_quaternion() for b in arm.data.bones}


def bake_action(arm, name, frames, pose_fn, loop=True, step=2):
    """pose_fn(t in [0,1]) -> {os: (rx, ry, rz) en degrés, axes du monde} + clé spéciale 'pos' pour les hanches."""
    rest = _rest(arm)
    ad = arm.animation_data or arm.animation_data_create()
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    ad.action = act
    last = frames if loop else frames - 1
    fr = list(range(0, last + 1, step))
    if fr[-1] != last:
        fr.append(last)
    for f in fr:
        t = (f / frames) if loop else (f / max(1, frames - 1))
        pose = pose_fn(t)
        for pb in arm.pose.bones:
            rot = pose.get(pb.name, (0, 0, 0))
            qw = Euler(tuple(math.radians(a) for a in rot), "XYZ").to_quaternion()
            r = rest[pb.name]
            pb.rotation_quaternion = r.inverted() @ qw @ r
            pb.keyframe_insert("rotation_quaternion", frame=f + 1)
            if pb.name == "hanches":
                off = Vector(pose.get("pos", (0, 0, 0)))
                pb.location = r.inverted() @ off
                pb.keyframe_insert("location", frame=f + 1)
    return act


S = math.sin
C = math.cos
TAU = math.tau


def anims_survivant(arm):
    def idle(t):
        b = S(t * TAU)
        return {"torse": (-2 * b, 0, 0), "tete": (2 * b, 0, 0),
                "bras.R": (5, 0, 4 + b), "bras.L": (5, 0, -4 - b),
                "avantbras.R": (12, 0, 0), "avantbras.L": (12, 0, 0),
                "pos": (0, 0, 0.004 * b)}

    def walk(amp, knee, arm_a, elbow, lean, bob):
        def f(t):
            p = t * TAU
            return {
                "cuisse.R": (amp * S(p), 0, 0), "cuisse.L": (-amp * S(p), 0, 0),
                "tibia.R": (-knee * max(0.0, -C(p)) - 4, 0, 0), "tibia.L": (-knee * max(0.0, C(p)) - 4, 0, 0),
                "pied.R": (8 * S(p), 0, 0), "pied.L": (-8 * S(p), 0, 0),
                "bras.R": (-arm_a * S(p), 0, 5), "bras.L": (arm_a * S(p), 0, -5),
                "avantbras.R": (elbow + 10 * max(0.0, -S(p)), 0, 0), "avantbras.L": (elbow + 10 * max(0.0, S(p)), 0, 0),
                "colonne": (-lean, 3 * S(p), 0), "torse": (0, 0, 4 * S(p)), "tete": (lean * 0.6, 0, -3 * S(p)),
                "pos": (0, 0, -bob * abs(S(p))),
            }
        return f

    def crouch(t):
        b = S(t * TAU)
        return {"cuisse.R": (75, 0, 6), "cuisse.L": (75, 0, -6), "tibia.R": (-115, 0, 0), "tibia.L": (-115, 0, 0),
                "pied.R": (40, 0, 0), "pied.L": (40, 0, 0), "colonne": (-22, 0, 0), "tete": (18, 0, 0),
                "bras.R": (30, 0, 6), "bras.L": (30, 0, -6), "avantbras.R": (40, 0, 0), "avantbras.L": (40, 0, 0),
                "pos": (0, -0.05, -0.36 + 0.004 * b)}

    def crouch_walk(t):
        p = t * TAU
        d = crouch(t)
        d["cuisse.R"] = (75 + 22 * S(p), 0, 6)
        d["cuisse.L"] = (75 - 22 * S(p), 0, -6)
        d["tibia.R"] = (-115 + 25 * S(p), 0, 0)
        d["tibia.L"] = (-115 - 25 * S(p), 0, 0)
        return d

    def strike(t):
        # lever le bras droit puis frapper vers l'avant
        if t < 0.35:
            k = t / 0.35
            a, e, tw = 150 * k, 70 * k, -20 * k
        else:
            k = min(1.0, (t - 0.35) / 0.25)
            a, e, tw = 150 - 120 * k, 70 - 60 * k, -20 + 45 * k
        return {"bras.R": (a, 0, 10), "avantbras.R": (e, 0, 0), "torse": (-5, 0, tw),
                "bras.L": (20, 0, -10), "avantbras.L": (30, 0, 0), "colonne": (-8, 0, 0)}

    def aim(t):
        b = S(t * TAU)
        return {"bras.R": (82 + b, 0, -8), "avantbras.R": (8, 0, 0), "main.R": (0, 0, 0),
                "bras.L": (72 + b, 0, 32), "avantbras.L": (20, 0, -30),
                "torse": (0, 0, 0), "tete": (-4, 0, 0)}

    bake_action(arm, "idle", 60, idle)
    bake_action(arm, "marche", 32, walk(26, 45, 22, 14, 3, 0.02))
    bake_action(arm, "course", 20, walk(46, 85, 45, 70, 12, 0.05))
    bake_action(arm, "accroupi", 40, crouch)
    bake_action(arm, "accroupi_marche", 36, crouch_walk)
    bake_action(arm, "frappe", 18, strike, loop=False, step=1)
    bake_action(arm, "visee", 40, aim)


def anims_zombie(arm):
    ARMS = 72

    def idle(t):
        p = t * TAU
        return {"colonne": (-14, 0, 4 * S(p)), "torse": (-6, 0, 0), "tete": (12 + 3 * S(p), 14 * S(p * 0.5), 10),
                "bras.R": (ARMS + 6 * S(p), 0, 4), "bras.L": (ARMS - 10 + 6 * S(p + 1), 0, -4),
                "avantbras.R": (12, 0, 0), "avantbras.L": (25, 0, 0), "main.R": (-20, 0, 0), "main.L": (-25, 0, 0),
                "cuisse.R": (4, 0, 2), "cuisse.L": (-4, 0, -2), "tibia.R": (-8, 0, 0), "tibia.L": (-4, 0, 0),
                "pos": (0, 0, -0.02 + 0.006 * S(p))}

    def shamble(t):
        p = t * TAU
        return {"cuisse.R": (22 * S(p), 0, 3), "cuisse.L": (-14 * S(p) - 4, 0, -6),
                "tibia.R": (-38 * max(0.0, -C(p)) - 6, 0, 0), "tibia.L": (-14 * max(0.0, C(p)) - 10, 0, 0),
                "pied.R": (8 * S(p), 0, 0), "pied.L": (-10, 0, -12),
                "colonne": (-18, 4 * S(p), 9 * S(p)), "torse": (-6, 0, -5 * S(p)),
                "tete": (14, 10 * S(p), 16 + 6 * S(p)),
                "bras.R": (ARMS + 10 * S(p + 1.5), 0, 6), "bras.L": (ARMS - 12 + 8 * S(p), 0, -6),
                "avantbras.R": (10, 0, 0), "avantbras.L": (28, 0, 0), "main.R": (-20, 0, 0), "main.L": (-25, 0, 0),
                "pos": (0.02 * S(p), 0, -0.03 - 0.03 * abs(S(p)))}

    def run(t):
        p = t * TAU
        return {"cuisse.R": (44 * S(p), 0, 3), "cuisse.L": (-44 * S(p), 0, -3),
                "tibia.R": (-80 * max(0.0, -C(p)) - 8, 0, 0), "tibia.L": (-80 * max(0.0, C(p)) - 8, 0, 0),
                "pied.R": (10 * S(p), 0, 0), "pied.L": (-10 * S(p), 0, 0),
                "colonne": (-28, 0, 6 * S(p)), "torse": (-8, 0, -6 * S(p)), "tete": (26, 0, 8 * S(p)),
                "bras.R": (ARMS + 18 + 18 * S(p * 2), 0, 10), "bras.L": (ARMS + 12 + 18 * S(p * 2 + 1.6), 0, -10),
                "avantbras.R": (15, 0, 0), "avantbras.L": (20, 0, 0),
                "pos": (0, 0.05, -0.06 - 0.05 * abs(S(p)))}

    def attack(t):
        if t < 0.4:
            k = t / 0.4
            a, lean = ARMS + 60 * k, -10 * k
        elif t < 0.6:
            k = (t - 0.4) / 0.2
            a, lean = ARMS + 60 - 95 * k, -10 - 30 * k
        else:
            k = (t - 0.6) / 0.4
            a, lean = ARMS - 35 + 35 * k, -40 + 26 * k
        return {"bras.R": (a, 0, 8), "bras.L": (a - 5, 0, -8), "avantbras.R": (15, 0, 0), "avantbras.L": (15, 0, 0),
                "colonne": (lean, 0, 0), "torse": (-6, 0, 0), "tete": (-10 if 0.4 < t < 0.7 else 10, 0, 0),
                "cuisse.R": (20 * min(1, t * 3), 0, 0), "tibia.R": (-20 * min(1, t * 3), 0, 0),
                "pos": (0, 0.12 * S(min(1.0, t * 1.6) * math.pi), -0.03)}

    def death(t):
        k = min(1.0, t * 1.4)
        e = k * k * (3 - 2 * k)
        return {"hanches": (78 * e, 0, 6 * e), "colonne": (8 * e, 0, 0), "tete": (25 * e, 20 * e, 0),
                "cuisse.R": (-70 * e + 40 * e, 0, 12 * e), "cuisse.L": (-40 * e + 20 * e, 0, -8 * e),
                "tibia.R": (-30 * e, 0, 0), "tibia.L": (-10 * e, 0, 0),
                "bras.R": (ARMS * (1 - e) + 150 * e, 0, 45 * e), "bras.L": (ARMS * (1 - e) + 120 * e, 0, -60 * e),
                "avantbras.R": (10, 0, 0), "avantbras.L": (25 * (1 - e), 0, 0),
                "pos": (0, -0.35 * e, -0.82 * e)}

    def hit(t):
        k = S(min(1.0, t) * math.pi)
        return {"colonne": (-14 + 22 * k, 0, -8 * k), "torse": (-6 + 10 * k, 0, 0), "tete": (12 + 20 * k, 0, 10),
                "bras.R": (ARMS - 30 * k, 0, 15 * k), "bras.L": (ARMS - 10 - 30 * k, 0, -15 * k),
                "avantbras.R": (12, 0, 0), "avantbras.L": (25, 0, 0),
                "pos": (0, -0.08 * k, -0.02)}

    bake_action(arm, "idle", 80, idle)
    bake_action(arm, "marche", 48, shamble)
    bake_action(arm, "course", 22, run)
    bake_action(arm, "attaque", 24, attack, loop=False, step=1)
    bake_action(arm, "mort", 36, death, loop=False, step=1)
    bake_action(arm, "touche", 12, hit, loop=False, step=1)


def finish_character(name, builder, arm):
    body = builder.to_object(name)
    body.parent = arm
    mod = body.modifiers.new("Squelette", "ARMATURE")
    mod.object = arm
    if arm.animation_data and bpy.data.actions.get("idle"):
        arm.animation_data.action = bpy.data.actions["idle"]
    export([arm, body], name, active=arm)


# ====================================================================== personnages
def survivant():
    b = Builder([
        ("Peau", (0.86, 0.66, 0.52), 0.8, 0.0),
        ("Haut", (0.32, 0.38, 0.30), 0.9, 0.0),       # veste kaki
        ("Manche", (0.32, 0.38, 0.30), 0.9, 0.0),
        ("Bas", (0.22, 0.25, 0.32), 0.9, 0.0),        # jean
        ("Chaussures", (0.25, 0.18, 0.12), 0.8, 0.0),
        ("Cheveux", (0.2, 0.14, 0.09), 0.9, 0.0),
        ("Yeux", (0.08, 0.08, 0.1), 0.4, 0.0),
        ("Bouche", (0.45, 0.25, 0.22), 0.8, 0.0),
        ("Sac", (0.42, 0.33, 0.2), 0.9, 0.0),
        ("Ceinture", (0.15, 0.12, 0.09), 0.7, 0.0),
        ("Tissu", (0.55, 0.15, 0.12), 0.9, 0.0),
    ])
    body_base(b, {"avantbras": "Manche"})
    # sac à dos, sangles, ceinture, foulard, poches
    b.box((0, -0.18, 1.32), (0.3, 0.14, 0.38), "Sac", "torse", bevel=0.04)
    b.box((0, -0.255, 1.22), (0.24, 0.05, 0.14), "Sac", "torse", bevel=0.02)
    b.box((0, -0.1, 1.53), (0.32, 0.12, 0.1), "Tissu", "torse", bevel=0.03)  # sac de couchage roulé
    for sx in (1, -1):
        b.box((sx * 0.11, 0.105, 1.36), (0.05, 0.03, 0.3), "Ceinture", "torse", bevel=0.01)
        b.box((sx * 0.1, 0.09, 0.76), (0.07, 0.03, 0.09), "Bas", "cuisse." + ("R" if sx > 0 else "L"), bevel=0.01)
    b.box((0, 0, 1.08), (0.35, 0.215, 0.045), "Ceinture", "hanches", bevel=0.01)
    b.box((0.13, 0.06, 1.0), (0.07, 0.09, 0.1), "Ceinture", "hanches", bevel=0.015)  # étui
    b.box((0, 0.03, 1.515), (0.2, 0.17, 0.07), "Tissu", "cou", bevel=0.025)  # foulard
    arm = make_armature("survivant")
    anims_survivant(arm)
    finish_character("survivant", b, arm)


ZOMBIE_VARIANTS = {
    "zombie_civil": {"haut": (0.45, 0.38, 0.3), "bas": (0.28, 0.27, 0.3), "peau": (0.55, 0.6, 0.45), "cheveux": (0.18, 0.15, 0.12)},
    "zombie_policier": {"haut": (0.16, 0.2, 0.36), "bas": (0.12, 0.14, 0.24), "peau": (0.6, 0.62, 0.5), "cheveux": (0.1, 0.1, 0.1)},
    "zombie_militaire": {"haut": (0.3, 0.34, 0.2), "bas": (0.28, 0.31, 0.19), "peau": (0.52, 0.56, 0.44), "cheveux": (0.15, 0.13, 0.1)},
    "zombie_patient": {"haut": (0.72, 0.8, 0.82), "bas": (0.72, 0.8, 0.82), "peau": (0.65, 0.66, 0.56), "cheveux": (0.3, 0.28, 0.25)},
}


def zombie(name):
    v = ZOMBIE_VARIANTS[name]
    b = Builder([
        ("Peau", v["peau"], 0.75, 0.0),
        ("Haut", v["haut"], 0.95, 0.0),
        ("Manche", v["haut"], 0.95, 0.0),
        ("Bas", v["bas"], 0.95, 0.0),
        ("Chaussures", (0.15, 0.13, 0.11), 0.85, 0.0),
        ("Cheveux", v["cheveux"], 0.95, 0.0),
        ("Yeux", (0.85, 0.8, 0.45), 0.3, 0.0, (0.6, 0.55, 0.2)),
        ("Bouche", (0.25, 0.05, 0.05), 0.6, 0.0),
        ("Sang", (0.35, 0.04, 0.04), 0.5, 0.0),
        ("Accessoire", (0.15, 0.15, 0.15), 0.6, 0.2),
        ("Accessoire2", (0.2, 0.24, 0.15), 0.8, 0.0),
    ])
    body_base(b, {"bouche_ouverte": True, "cheveux": name != "zombie_militaire", "avantbras": "Peau"})
    # vêtements déchirés, plaies et sang (asymétriques)
    b.box((-0.12, 0.118, 1.18), (0.1, 0.012, 0.12), "Sang", "colonne", bevel=0.004)
    b.box((0.08, 0.125, 1.38), (0.07, 0.012, 0.06), "Sang", "torse", bevel=0.004)
    b.box((0.06, 0.13, 1.585), (0.05, 0.01, 0.04), "Sang", "tete", bevel=0.003)
    b.box((-0.07, 0.115, 1.735), (0.06, 0.012, 0.035), "Sang", "tete", bevel=0.003)
    b.box((-0.225, 0.05, 1.08), (0.03, 0.03, 0.08), "Sang", "avantbras.L", bevel=0.005)
    b.box((0.1, 0.085, 0.36), (0.07, 0.012, 0.09), "Peau", "tibia.R", bevel=0.004)  # pantalon déchiré
    b.box((0.17, -0.05, 1.09), (0.04, 0.12, 0.08), "Haut", "colonne", rot=(0, 25, 0), bevel=0.01)  # lambeau
    b.box((-0.1, -0.11, 1.05), (0.1, 0.03, 0.12), "Haut", "hanches", rot=(15, 0, 10), bevel=0.01)
    # mâchoire pendante
    b.box((0, 0.1, 1.575), (0.12, 0.06, 0.04), "Peau", "tete", rot=(18, 0, 0), bevel=0.012)
    if name == "zombie_policier":
        b.box((0, 0.015, 1.80), (0.26, 0.27, 0.06), "Haut", "tete", bevel=0.02)      # casquette
        b.box((0, 0.15, 1.785), (0.2, 0.09, 0.02), "Accessoire", "tete", bevel=0.005)  # visière
        b.box((0, 0, 1.3), (0.42, 0.26, 0.42), "Accessoire", "torse", bevel=0.04)     # gilet
        b.box((0.09, 0.135, 1.42), (0.05, 0.01, 0.05), "Yeux", "torse", bevel=0.004)  # insigne
        b.box((0, 0, 1.075), (0.36, 0.22, 0.05), "Accessoire", "hanches", bevel=0.01)
    elif name == "zombie_militaire":
        b.cyl((0, 0.0, 1.76), 0.15, 0.13, "Accessoire2", "tete", segments=10, radius2=0.12)  # casque
        b.box((0, 0.02, 1.7), (0.3, 0.3, 0.02), "Accessoire2", "tete", bevel=0.005)          # bord du casque
        b.box((0, 0, 1.31), (0.43, 0.27, 0.42), "Accessoire2", "torse", bevel=0.04)          # gilet tactique
        for x in (-0.1, 0, 0.1):
            b.box((x, 0.145, 1.24), (0.08, 0.04, 0.1), "Accessoire2", "torse", bevel=0.01)  # poches
        for sx in (1, -1):
            b.box((sx * 0.1, 0.05, 0.12), (0.135, 0.27, 0.2), "Chaussures", "tibia." + ("R" if sx > 0 else "L"), bevel=0.02)  # rangers
    elif name == "zombie_patient":
        b.box((0, 0, 1.0), (0.38, 0.24, 0.5), "Haut", "hanches", bevel=0.03, taper=(0.95, 0.95))  # blouse
        b.box((0.22, 0, 0.98), (0.06, 0.08, 0.02), "Yeux", "avantbras.R", bevel=0.005)  # bracelet
    else:
        b.box((0, -0.13, 1.3), (0.2, 0.05, 0.2), "Haut", "torse", rot=(0, 0, 8), bevel=0.02)  # capuche
    arm = make_armature(name)
    anims_zombie(arm)
    finish_character(name, b, arm)


# ====================================================================== armes
# Origine = point de prise en main. Le canon / la lame pointe vers +Y.
METAL = ("Metal", (0.35, 0.36, 0.38), 0.4, 0.8)
METAL_SOMBRE = ("MetalSombre", (0.12, 0.12, 0.13), 0.45, 0.7)
BOIS = ("Bois", (0.5, 0.32, 0.18), 0.8, 0.0)
BOIS_CLAIR = ("BoisClair", (0.72, 0.55, 0.35), 0.8, 0.0)
CAOUTCHOUC = ("Caoutchouc", (0.08, 0.08, 0.08), 0.9, 0.0)
LAME = ("Lame", (0.75, 0.76, 0.8), 0.25, 0.9)
RUBAN = ("Ruban", (0.6, 0.6, 0.62), 0.9, 0.0)
VERT = ("Vert", (0.25, 0.29, 0.18), 0.7, 0.1)


def weapon(name, mats, build):
    b = Builder(mats)
    build(b)
    obj = b.to_object(name)
    export([obj], name)


def w_couteau(b):
    b.box((0, -0.02, 0), (0.026, 0.11, 0.032), "Caoutchouc", bevel=0.008)
    b.box((0, 0.04, 0), (0.03, 0.012, 0.05), "MetalSombre", bevel=0.003)
    b.box((0, 0.14, 0.004), (0.005, 0.19, 0.034), "Lame", bevel=0.0015, taper=(1, 1))
    b.box((0, 0.245, 0.0), (0.005, 0.03, 0.02), "Lame", rot=(25, 0, 0), bevel=0.001)


def w_batte(b, clous=False):
    b.cyl((0, -0.05, 0), 0.016, 0.16, "Ruban", rot=(-90, 0, 0), segments=8)
    b.cyl((0, -0.135, 0), 0.024, 0.02, "BoisClair", rot=(-90, 0, 0), segments=8)
    b.cyl((0, 0.3, 0), 0.018, 0.56, "BoisClair", rot=(-90, 0, 0), segments=8, radius2=0.034)
    b.cyl((0, 0.66, 0), 0.034, 0.16, "BoisClair", rot=(-90, 0, 0), segments=8, radius2=0.03)
    if clous:
        import random
        rnd = random.Random(4)
        for i in range(14):
            a = rnd.uniform(0, math.tau)
            y = rnd.uniform(0.45, 0.72)
            r = 0.04
            b.box((math.cos(a) * r, y, math.sin(a) * r), (0.006, 0.006, 0.05), "MetalSombre",
                  rot=(0, -math.degrees(a) + 90, 0), bevel=0)


def w_machette(b, artisanale=False):
    b.box((0, -0.02, 0), (0.028, 0.13, 0.035), "Bois" if artisanale else "Caoutchouc", bevel=0.008)
    if artisanale:
        for y in (-0.05, 0.0, 0.03):
            b.box((0, y, 0), (0.032, 0.012, 0.04), "Ruban", bevel=0.002)
        b.box((0, 0.26, 0.01), (0.006, 0.42, 0.05), "Metal", bevel=0.002, taper=(1, 1))
        b.box((0, 0.47, 0.005), (0.006, 0.05, 0.04), "Metal", rot=(-20, 0, 0), bevel=0.002)
    else:
        b.box((0, 0.05, 0), (0.035, 0.012, 0.045), "MetalSombre", bevel=0.003)
        b.box((0, 0.28, 0.012), (0.005, 0.46, 0.055), "Lame", bevel=0.0015)
        b.box((0, 0.52, 0.02), (0.005, 0.06, 0.06), "Lame", rot=(-25, 0, 0), bevel=0.0015)


def w_hache(b):
    b.cyl((0, 0.25, 0), 0.016, 0.66, "Bois", rot=(-90, 0, 0), segments=8)
    b.box((0, 0.52, 0.035), (0.03, 0.08, 0.06), "MetalSombre", bevel=0.006)
    b.box((0, 0.52, 0.12), (0.012, 0.11, 0.12), "Metal", bevel=0.003, taper=(1, 1.35))
    b.box((0, 0.52, 0.185), (0.006, 0.15, 0.012), "Lame", bevel=0.001)


def w_matraque(b):
    b.cyl((0, 0.2, 0), 0.018, 0.55, "Caoutchouc", rot=(-90, 0, 0), segments=8)
    b.cyl((0.03, 0.05, 0), 0.012, 0.09, "Caoutchouc", rot=(0, 90, 0), segments=6)


def w_pistolet(b):
    b.box((0, 0.065, 0.075), (0.03, 0.2, 0.034), "MetalSombre", bevel=0.004)   # culasse
    b.box((0, 0.06, 0.047), (0.028, 0.17, 0.024), "Caoutchouc", bevel=0.004)  # carcasse
    b.box((0, -0.005, -0.01), (0.027, 0.045, 0.11), "Caoutchouc", rot=(-14, 0, 0), bevel=0.006)  # poignée
    b.box((0, 0.04, 0.022), (0.006, 0.05, 0.03), "Caoutchouc", bevel=0.002)  # pontet
    b.box((0, 0.163, 0.08), (0.012, 0.01, 0.012), "Metal", bevel=0.002)       # bouche
    b.box((0, 0.14, 0.096), (0.005, 0.012, 0.008), "Metal", bevel=0)          # guidon


def w_revolver(b):
    b.cyl((0, 0.14, 0.07), 0.011, 0.18, "Metal", rot=(-90, 0, 0), segments=8)
    b.cyl((0, 0.035, 0.065), 0.024, 0.045, "Metal", rot=(-90, 0, 0), segments=6, bevel=0.003)
    b.box((0, 0.005, 0.07), (0.022, 0.05, 0.045), "Metal", bevel=0.004)
    b.box((0, -0.02, 0.0), (0.028, 0.045, 0.11), "Bois", rot=(-20, 0, 0), bevel=0.008)
    b.box((0, 0.02, 0.025), (0.006, 0.04, 0.03), "Metal", bevel=0.002)


def w_fusil_pompe(b):
    b.cyl((0, 0.42, 0.06), 0.013, 0.62, "MetalSombre", rot=(-90, 0, 0), segments=8)     # canon
    b.cyl((0, 0.36, 0.035), 0.011, 0.5, "MetalSombre", rot=(-90, 0, 0), segments=8)     # magasin tubulaire
    b.box((0, 0.3, 0.035), (0.04, 0.16, 0.04), "Bois", bevel=0.008)                      # pompe
    b.box((0, 0.04, 0.05), (0.04, 0.18, 0.06), "MetalSombre", bevel=0.006)               # boîtier
    b.box((0, -0.06, -0.02), (0.032, 0.06, 0.09), "Bois", rot=(-18, 0, 0), bevel=0.008) # poignée
    b.box((0, -0.25, 0.0), (0.038, 0.32, 0.07), "Bois", rot=(6, 0, 0), bevel=0.01, taper=(1, 1.6))  # crosse
    b.box((0, -0.41, -0.005), (0.04, 0.02, 0.12), "Caoutchouc", bevel=0.005)


def w_fusil_artisanal(b):
    b.cyl((0, 0.35, 0.05), 0.016, 0.55, "Metal", rot=(-90, 0, 0), segments=8)
    for y in (0.15, 0.35, 0.55):
        b.cyl((0, y, 0.05), 0.02, 0.03, "Ruban", rot=(-90, 0, 0), segments=8)
    b.box((0, 0.2, 0.02), (0.04, 0.35, 0.03), "Bois", bevel=0.006)
    b.box((0, 0.0, 0.03), (0.035, 0.08, 0.05), "Metal", bevel=0.004)
    b.box((0, -0.05, -0.03), (0.03, 0.05, 0.09), "Bois", rot=(-18, 0, 0), bevel=0.006)
    b.box((0, -0.24, 0.0), (0.035, 0.32, 0.05), "Bois", rot=(4, 0, 0), bevel=0.008, taper=(1, 1.5))


def _rifle_common(b, mat_corps, long=0.85, couleur_crosse="MetalSombre"):
    b.box((0, 0.05, 0.06), (0.04, 0.26, 0.07), mat_corps, bevel=0.006)                    # boîtier
    b.box((0, 0.27, 0.06), (0.045, 0.2, 0.06), mat_corps, bevel=0.008, taper=(0.9, 1))   # garde-main
    b.cyl((0, 0.48, 0.07), 0.009, 0.26, "MetalSombre", rot=(-90, 0, 0), segments=8)     # canon
    b.box((0, 0.6, 0.07), (0.022, 0.04, 0.022), "MetalSombre", bevel=0.004)              # cache-flamme
    b.box((0, 0.06, 0.112), (0.02, 0.16, 0.012), "MetalSombre", bevel=0.002)             # rail
    b.box((0, 0.0, 0.135), (0.028, 0.07, 0.035), "MetalSombre", bevel=0.005)             # viseur
    b.box((0, -0.05, -0.01), (0.03, 0.045, 0.1), "Caoutchouc", rot=(-18, 0, 0), bevel=0.007)  # poignée
    b.box((0, -0.24, 0.045), (0.035, 0.26, 0.06), couleur_crosse, bevel=0.008, taper=(1, 1.4))  # crosse
    b.box((0, -0.37, 0.035), (0.038, 0.02, 0.1), "Caoutchouc", bevel=0.004)


def w_carabine(b):
    _rifle_common(b, "MetalSombre")
    b.box((0, 0.08, -0.03), (0.026, 0.05, 0.12), "MetalSombre", rot=(8, 0, 0), bevel=0.004)  # chargeur droit


def w_fusil_assaut(b):
    _rifle_common(b, "Vert", couleur_crosse="Vert")
    b.box((0, 0.09, -0.02), (0.026, 0.05, 0.08), "MetalSombre", rot=(12, 0, 0), bevel=0.004)
    b.box((0, 0.105, -0.085), (0.026, 0.05, 0.07), "MetalSombre", rot=(26, 0, 0), bevel=0.004)  # chargeur courbe
    b.box((0, 0.3, 0.0), (0.02, 0.03, 0.06), "Caoutchouc", bevel=0.004)  # poignée avant


WEAPONS = {
    "couteau": ([CAOUTCHOUC, METAL_SOMBRE, LAME], w_couteau),
    "batte": ([RUBAN, BOIS_CLAIR, METAL_SOMBRE], lambda b: w_batte(b, False)),
    "batte_cloutee": ([RUBAN, BOIS_CLAIR, METAL_SOMBRE], lambda b: w_batte(b, True)),
    "machette": ([CAOUTCHOUC, METAL_SOMBRE, LAME], lambda b: w_machette(b, False)),
    "machette_art": ([BOIS, RUBAN, METAL], lambda b: w_machette(b, True)),
    "hache": ([BOIS, METAL_SOMBRE, METAL, LAME], w_hache),
    "matraque": ([CAOUTCHOUC], w_matraque),
    "pistolet": ([METAL_SOMBRE, CAOUTCHOUC, METAL], w_pistolet),
    "revolver": ([METAL, BOIS], w_revolver),
    "fusil_pompe": ([METAL_SOMBRE, BOIS, CAOUTCHOUC], w_fusil_pompe),
    "fusil_artisanal": ([METAL, RUBAN, BOIS], w_fusil_artisanal),
    "carabine": ([METAL_SOMBRE, CAOUTCHOUC], w_carabine),
    "fusil_assaut": ([METAL_SOMBRE, CAOUTCHOUC, VERT], w_fusil_assaut),
}


# ====================================================================== lancement
def run():
    log("Génération des modèles —", bpy.app.version_string)
    jobs = [("survivant", survivant)]
    for zn in ZOMBIE_VARIANTS:
        jobs.append((zn, (lambda n=zn: zombie(n))))
    for wn, (mats, fn) in WEAPONS.items():
        jobs.append((wn, (lambda n=wn, m=mats, f=fn: weapon(n, m, f))))
    ok = 0
    for name, fn in jobs:
        if SEULEMENT and name not in SEULEMENT:
            continue
        try:
            if bpy.context.object and bpy.context.object.mode != "OBJECT":
                bpy.ops.object.mode_set(mode="OBJECT")
        except Exception:
            pass
        clear_scene()
        log("•", name)
        try:
            fn()
            ok += 1
        except Exception:
            log("  ERREUR :", traceback.format_exc())
    log("TERMINÉ : %d modèle(s) générés" % ok)


run()
