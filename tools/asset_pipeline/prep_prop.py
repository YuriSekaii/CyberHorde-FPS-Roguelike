"""Blender: turn a raw Hunyuan3D-2 .glb into a game-ready Godot asset (no rig).
Run: blender -b --factory-startup --python prep_prop.py -- <raw.glb> <out.glb> <height_m> <max_tris> <tex_px> [yaw_deg] [preview.png]
- welds seams, drops tiny floating bits, decimates to max_tris, smooth shading with sharp edges > 35 deg
- scales so the tallest side (Z) is height_m, origin at bottom centre, faces Godot -Z (yaw_deg turns it first:
  0 for creatures/props shown front-on, 90 for weapons drawn in side profile with the barrel pointing right)
- resizes the texture to tex_px and adds an emission map from the bright saturated (neon/glowing) texels
"""
import bpy, bmesh, sys, math, json
import numpy as np
a = sys.argv[sys.argv.index("--") + 1:]
src, out, height, max_tris, tex = a[0], a[1], float(a[2]), int(a[3]), int(a[4])
yaw = float(a[5]) if len(a) > 5 else 0.0
preview = a[6] if len(a) > 6 else None

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
bpy.ops.object.select_all(action='DESELECT')
for o in meshes: o.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
if len(meshes) > 1: bpy.ops.object.join()
o = bpy.context.view_layer.objects.active
o.parent = None
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
for e in [x for x in bpy.data.objects if x != o]: bpy.data.objects.remove(e)

bm = bmesh.new(); bm.from_mesh(o.data)
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)  # Hunyuan output is split along UV seams
bm.verts.ensure_lookup_table()
seen, islands = set(), []
for v in bm.verts:
    if v in seen: continue
    cur, st = [], [v]; seen.add(v)
    while st:
        x = st.pop(); cur.append(x)
        for ed in x.link_edges:
            y = ed.other_vert(x)
            if y not in seen: seen.add(y); st.append(y)
    islands.append(cur)
tiny = [v for isl in islands if len(isl) < 0.005 * len(bm.verts) for v in isl]  # floaters; real parts are bigger
bmesh.ops.delete(bm, geom=tiny, context='VERTS')
bm.to_mesh(o.data); bm.free()

tris0 = sum(len(p.vertices) - 2 for p in o.data.polygons)
if tris0 > max_tris:
    m = o.modifiers.new("Dec", 'DECIMATE'); m.ratio = max_tris / tris0
    bpy.ops.object.modifier_apply(modifier=m.name)
o.data.set_sharp_from_angle(angle=math.radians(35))
o.data.shade_smooth()

# orient (Hunyuan front = Blender -Y), scale, origin at bottom centre
import mathutils
# +180: Blender -Y front ends up as Godot -Z forward (rotate the data; transform_apply can silently skip here)
o.data.transform(mathutils.Matrix.Rotation(math.radians(yaw) + math.pi, 4, 'Z'))
pts = np.array([v.co[:] for v in o.data.vertices])
lo, hi = pts.min(0), pts.max(0)
s = height / max(hi[2] - lo[2], 1e-6)
for v in o.data.vertices:
    v.co = ((v.co[0] - (lo[0] + hi[0]) / 2) * s, (v.co[1] - (lo[1] + hi[1]) / 2) * s, (v.co[2] - lo[2]) * s)

# texture: resize + emission from neon texels
mat = o.data.materials[0] if o.data.materials else None
emit_px = 0
if mat and mat.node_tree:
    nt = mat.node_tree
    texn = next((n for n in nt.nodes if n.type == 'TEX_IMAGE'), None)
    bsdf = next((n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED'), None)
    if texn and texn.image:
        img = texn.image
        if img.size[0] > tex: img.scale(tex, tex)
        W, H = img.size
        px = np.empty(W * H * 4, np.float32); img.pixels.foreach_get(px); px = px.reshape(H, W, 4)
        rgb = px[..., :3]; mx = rgb.max(-1); mn = rgb.min(-1)
        sat = (mx - mn) / np.maximum(mx, 1e-4)
        mask = (sat > 0.55) & (mx > 0.6)  # glowing neon / eyes / energy cores
        emit_px = int(mask.sum())
        alb = bpy.data.images.new(o.name + "_albedo", W, H); alb.pixels.foreach_set(px.ravel()); alb.pack()
        texn.image = alb
        if emit_px > 0.0005 * W * H and bsdf:
            e = px.copy(); e[..., :3] *= mask[..., None]; e[..., 3] = 1
            em = bpy.data.images.new(o.name + "_emission", W, H); em.pixels.foreach_set(e.ravel()); em.pack()
            en = nt.nodes.new('ShaderNodeTexImage'); en.image = em
            nt.links.new(en.outputs['Color'], bsdf.inputs['Emission Color'])
            bsdf.inputs['Emission Strength'].default_value = 2.0
    mat.name = o.name + "_mat"

name = out.replace("\\", "/").split("/")[-1].rsplit(".", 1)[0]
o.name = o.data.name = name
o.data.validate()
bpy.ops.export_scene.gltf(filepath=out, export_format='GLB', export_yup=True, export_apply=True)

if preview:  # quick look: front + 3/4, textured
    sc = bpy.context.scene
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam")); sc.collection.objects.link(cam); sc.camera = cam
    bpy.context.view_layer.update()
    cam.data.type = 'ORTHO'; dim = o.dimensions; cam.data.ortho_scale = max(dim) * 1.25
    sc.render.engine = 'BLENDER_WORKBENCH'; sc.display.shading.light = 'STUDIO'; sc.display.shading.color_type = 'TEXTURE'
    sc.render.resolution_x, sc.render.resolution_y = 700, 700
    sc.render.film_transparent = False
    c = np.array([0, 0, dim[2] / 2]); d = max(dim) * 4
    # Godot -Z forward = Blender +Y after the turn above, so the front camera sits at +Y
    import mathutils
    shots = []
    for tag, off in (("front", (0, d, 0)), ("q34", (-d * 0.7, d * 0.7, d * 0.3))):
        cam.location = mathutils.Vector(c) + mathutils.Vector(off)
        cam.rotation_euler = (mathutils.Vector(c) - cam.location).to_track_quat('-Z', 'Y').to_euler()
        p = preview.replace(".png", f"_{tag}.png"); sc.render.filepath = p; bpy.ops.render.render(write_still=True); shots.append(p)

tris = sum(len(p.vertices) - 2 for p in o.data.polygons)
print("PREP " + json.dumps({"out": out, "tris_in": tris0, "tris": tris, "size_m": [round(x, 3) for x in o.dimensions],
                            "tex": tex, "emission_px": emit_px}))
