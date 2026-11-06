"""Hand-built Pulse Carbine (v4 design). Blender -b --python build.py -- <parts_dir> <veins.png> <out.glb> [out.blend]
Side outlines are traced from the reference image (pixels), extruded to per-part widths, panel-inset and bevelled.
Blender axes: +Y = barrel (glTF/Godot -Z), +Z up, X = gun width."""
import sys, math, bpy, bmesh
argv = sys.argv[sys.argv.index("--") + 1:]
sys.path.insert(0, argv[0])
from parts import POLYS, MUZZLE, SIGHT, REAR_BLOCK, CYLS, GLOWS
VEINS, OUT = argv[1], argv[2]
BLEND = argv[3] if len(argv) > 3 else None
S = 0.00032                      # metres per reference pixel (gun ~0.24 m tall, ~0.79 m long)
CROP = (120, 395, 2620, 1165)    # must match mask.py
Y = lambda px: (1400 - px) * S
Z = lambda py: (1160 - py) * S

bpy.ops.wm.read_factory_settings(use_empty=True)
scn = bpy.context.scene

def mat(name, base, metal, rough, emis=None, strength=0.0, tex=None):
    m = bpy.data.materials.new(name); m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*base, 1)
    b.inputs["Metallic"].default_value = metal
    b.inputs["Roughness"].default_value = rough
    if emis: b.inputs["Emission Color"].default_value = (*emis, 1)
    if tex:
        t = m.node_tree.nodes.new("ShaderNodeTexImage"); t.image = bpy.data.images.load(tex)
        m.node_tree.links.new(t.outputs["Color"], b.inputs["Emission Color"])
    b.inputs["Emission Strength"].default_value = strength
    return m

M = {
  "armor": mat("Armor", (0.0025, 0.010, 0.017), 0.2, 0.5, strength=8.0, tex=VEINS),
  "metal": mat("Gunmetal", (0.011, 0.012, 0.014), 0.85, 0.42),
  "glow":  mat("Glow", (0.5, 0.9, 1.0), 0.0, 0.3, (0.55, 0.95, 1.0), 8.0),
}

def new_obj(name, bm, material):
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new(name, me); scn.collection.objects.link(o)
    o.data.materials.append(M[material]); return o

def slab(name, material, x0, x1, poly, panel=False):
    """Extrude a side outline (reference px) between x0..x1 metres."""
    bm = bmesh.new()
    vs = [bm.verts.new((x0, Y(px), Z(py))) for px, py in poly]
    f = bm.faces.new(vs)
    ext = bmesh.ops.extrude_face_region(bm, geom=[f])
    bmesh.ops.translate(bm, vec=(x1 - x0, 0, 0), verts=[e for e in ext["geom"] if isinstance(e, bmesh.types.BMVert)])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    if panel:  # chamfer the long top/bottom edges so the armour isn't a flat box
        for want, off in ((lambda n: n.z > 0.3, 0.0065), (lambda n: n.z < -0.3, 0.003)):
            es = [e for e in bm.edges if len(e.link_faces) == 2 and
                  any(abs(f.normal.x) > 0.99 for f in e.link_faces) and any(want(f.normal) for f in e.link_faces)]
            if es: bmesh.ops.bevel(bm, geom=es, offset=off, segments=1, affect="EDGES", profile=0.5)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    if panel:  # raised armour panel on each side face
        for side in [f for f in bm.faces if abs(f.normal.x) > 0.99]:
            bmesh.ops.inset_region(bm, faces=[side], thickness=0.0035, depth=0.0015)
    return new_obj(name, bm, material)

def cyl(name, material, x0, x1, cy, r, verts=24):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r * S, depth=(x1 - x0) * S,
        location=(0, Y((x0 + x1) / 2), Z(cy)), rotation=(math.pi / 2, 0, 0))
    o = bpy.context.active_object; o.name = name; o.data.materials.append(M[material]); return o

objs = []
for n, (m, w, p) in POLYS.items():
    objs.append(slab(n, m, -w, w, p, panel=(m == "armor" and w > 0.015)))
objs.append(slab("muzzle", MUZZLE[0], -MUZZLE[1], MUZZLE[1], MUZZLE[2]))
objs.append(slab("rear_block", REAR_BLOCK[0], -REAR_BLOCK[1], REAR_BLOCK[1], REAR_BLOCK[2]))
s = SIGHT; box = lambda x0, x1, t, btm: [(x0, t), (x1, t), (x1, btm), (x0, btm)]
objs += [slab("sight_base", "metal", -s["outer"], s["outer"], box(s["x0"], s["x1"], s["base"], s["bottom"])),
         slab("sight_top", "metal", -s["outer"], s["outer"], box(s["x0"], s["x1"], s["top"], s["bar"])),
         slab("sight_L", "metal", s["inner"], s["outer"], box(s["x0"], s["x1"], s["bar"], s["base"])),
         slab("sight_R", "metal", -s["outer"], -s["inner"], box(s["x0"], s["x1"], s["bar"], s["base"]))]
mid = (s["bar"] + s["base"]) / 2      # holo reticle dot at the rear of the window
objs.append(slab("reticle", "glow", -0.0009, 0.0009, box(s["x1"] - 8, s["x1"] - 2, mid - 3, mid + 3)))
for n, (m, x0, x1, cy, r) in CYLS.items():
    objs.append(cyl(n, m, x0, x1, cy, r))
host_w = {"mag": POLYS["mag"][1], "sight": s["outer"], "muzzle": MUZZLE[1]}
for n, (h, p) in GLOWS.items():
    w = host_w[h]
    objs += [slab(n + "_L", "glow", w - 0.0003, w + 0.0006, p), slab(n + "_R", "glow", -w - 0.0006, -w + 0.0003, p)]

for o in objs:   # crisp hard-surface edges
    bv = o.modifiers.new("bevel", "BEVEL"); bv.width = 0.0012 if o.dimensions.x > 0.004 else 0.0004
    bv.segments = 2; bv.limit_method = "ANGLE"; bv.angle_limit = math.radians(35); bv.harden_normals = True
bpy.ops.object.select_all(action="DESELECT")
for o in objs: o.select_set(True)
bpy.context.view_layer.objects.active = objs[0]
bpy.ops.object.convert(target="MESH")
bpy.ops.object.join()
gun = bpy.context.active_object; gun.name = "PulseCarbine"
bpy.ops.object.shade_smooth_by_angle(angle=math.radians(35))

# UVs: project every face from the side onto the reference crop (veins live in the armour emission texture)
uv = gun.data.uv_layers.new(name="UVMap")
for loop in gun.data.loops:
    co = gun.data.vertices[loop.vertex_index].co
    px, py = 1400 - co.y / S, 1160 - co.z / S
    uv.data[loop.index].uv = ((px - CROP[0]) / (CROP[2] - CROP[0]), 1 - (py - CROP[1]) / (CROP[3] - CROP[1]))

# origin at bottom centre
xs = [v.co for v in gun.data.vertices]
cy = (min(c.y for c in xs) + max(c.y for c in xs)) / 2; mz = min(c.z for c in xs)
for v in gun.data.vertices: v.co.y -= cy; v.co.z -= mz
gun.data.update()
tris = sum(len(p.vertices) - 2 for p in gun.data.polygons)
print("PULSE", "tris", tris, "dims", tuple(round(d, 3) for d in gun.dimensions))
if BLEND: bpy.ops.wm.save_as_mainfile(filepath=BLEND)
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", export_yup=True, export_apply=True)
