"""Stage 1 castle arena pieces: corner tower, fantasy column (pillar), crenellated wall.
blender -b --factory-startup --python build.py -- <assets/models dir> [preview_dir]
Blender +Z up, +Y = Godot -Z. Origins at bottom centre. Wall inner (arena) face = Blender -Y = Godot +Z.
Textures are procedural and tileable (FFT-filtered noise), UVs are world-scaled so tiles stay square."""
import sys, os, math, tempfile, bpy, bmesh
import numpy as np
from mathutils import Vector, Matrix

argv = sys.argv[sys.argv.index("--") + 1:]
OUT = argv[0]
PREV = argv[1] if len(argv) > 1 else None
HERE = os.path.dirname(os.path.abspath(__file__))
TMP = tempfile.mkdtemp()
bpy.ops.wm.read_factory_settings(use_empty=True)
scn = bpy.context.scene

# ---------------------------------------------------------------- textures
def smooth(x, a, b):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)

def pnoise(n, cx, cy=None, seed=0, octaves=4, persist=0.5):
    """Periodic fractal noise in [0,1]: white noise low-passed in frequency space, so it tiles."""
    cy = cx if cy is None else cy
    r = np.random.default_rng(seed)
    fy = np.fft.fftfreq(n)[:, None] * n
    fx = np.fft.fftfreq(n)[None, :] * n
    out = np.zeros((n, n)); amp = 1.0; tot = 0.0
    for o in range(octaves):
        k = 2 ** o
        F = np.fft.fft2(r.standard_normal((n, n))) * np.exp(-(fx / (cx * k)) ** 2 - (fy / (cy * k)) ** 2)
        layer = np.real(np.fft.ifft2(F)); layer /= layer.std() + 1e-9
        out += amp * layer; tot += amp; amp *= persist
    out /= tot
    return (out - out.min()) / (out.max() - out.min())

def lerp(a, b, t):
    t = t[..., None] if np.ndim(t) else t
    return np.asarray(a) * (1 - t) + np.asarray(b) * t

def normal_from(h, s):
    nx = -(np.roll(h, -1, 1) - np.roll(h, 1, 1)) * 0.5 * s
    ny = -(np.roll(h, -1, 0) - np.roll(h, 1, 0)) * 0.5 * s   # array row 0 = image bottom (+V up)
    l = np.sqrt(nx * nx + ny * ny + 1)
    return np.stack([nx / l, ny / l, 1 / l], -1) * 0.5 + 0.5

def save(name, rgb, noncolor=False):
    n = rgb.shape[0]
    img = bpy.data.images.new(name, n, n, alpha=False)
    if noncolor:
        img.colorspace_settings.name = "Non-Color"
    a = np.ones((n, n, 4), np.float32); a[..., :3] = np.clip(rgb, 0, 1)
    img.pixels.foreach_set(a.ravel())
    img.filepath_raw = os.path.join(TMP, name + ".png"); img.file_format = "PNG"; img.save()
    return img

def grid(n):
    v, u = (np.mgrid[0:n, 0:n] + 0.5) / n
    return u, v

def tex_stone(n=2048, tile=6.0, rows=24, cols=12, seed=11):
    """Mossy castle bricks, 0.5 x 0.25 m."""
    r = np.random.default_rng(seed)
    u, v = grid(n)
    ry = v * rows; row = np.floor(ry).astype(int); fy = ry - row
    rx = u * cols + (row % 2) * 0.5; fl = np.floor(rx); fx = rx - fl
    bid = row * cols + fl.astype(int) % cols
    bw, bh = tile / cols, tile / rows
    jit = pnoise(n, 40, seed=seed + 1, octaves=3) - 0.5
    d = np.minimum(np.minimum(fx, 1 - fx) * bw, np.minimum(fy, 1 - fy) * bh) + jit * 0.014
    r1 = r.random(rows * cols)[bid]; r2 = r.random(rows * cols)[bid]
    grain = pnoise(n, 260, seed=seed + 2, octaves=3)
    chips = smooth(pnoise(n, 90, seed=seed + 5, octaves=3), 0.72, 0.8)
    h = smooth(d, 0.006, 0.035) * (0.85 + 0.15 * r2) + (grain - 0.5) * 0.12 - chips * 0.25
    col = lerp((0.56, 0.53, 0.46), (0.45, 0.44, 0.39), r1)
    col = lerp(col, (0.57, 0.50, 0.40), (r2 > 0.85).astype(float) * 0.5)
    col = col * (0.82 + 0.3 * grain)[..., None]
    macro = pnoise(n, 5, seed=seed + 3, octaves=4)
    moss = smooth(macro, 0.5, 0.78) * (0.45 + 0.4 * pnoise(n, 60, seed=seed + 4, octaves=2))
    streak = pnoise(n, 30, 2, seed=seed + 6, octaves=3)
    col = col * (0.8 + 0.2 * streak)[..., None]
    col = lerp((0.36, 0.34, 0.30), col, smooth(d, 0.003, 0.010))          # mortar
    col = lerp(col, (0.27, 0.34, 0.17), np.clip(moss + (1 - smooth(d, 0.0, 0.02)) * moss, 0, 0.8))
    col = col * (0.78 + 0.22 * smooth(d, 0.003, 0.05))[..., None] * (1 - chips * 0.3)[..., None]
    return save("castle_stone", col), save("castle_stone_n", normal_from(h, 5.0), True)

def tex_roof(n=1024, tile=2.0, rows=8, cols=8, seed=21):
    """Weathered olive shingles, butt edge at the bottom of each row (+V = up the slope)."""
    r = np.random.default_rng(seed)
    u, v = grid(n)
    ry = v * rows; row = np.floor(ry).astype(int); fy = ry - row
    rx = u * cols + (row % 2) * 0.5; fl = np.floor(rx); fx = rx - fl
    sid = row * cols + fl.astype(int) % cols
    r1 = r.random(rows * cols)[sid]; r2 = r.random(rows * cols)[sid]
    sw = tile / cols
    gap = smooth(np.minimum(fx, 1 - fx) * sw, 0.004, 0.012)
    grain = pnoise(n, 120, 30, seed=seed + 1, octaves=3)
    h = (1 - 0.6 * fy + (r2 - 0.5) * 0.2 * (fx - 0.5)) * gap + (grain - 0.5) * 0.08
    col = lerp((0.43, 0.46, 0.33), (0.32, 0.36, 0.26), r1)
    col = col * (0.8 + 0.35 * grain)[..., None]
    lichen = smooth(pnoise(n, 70, seed=seed + 2, octaves=3), 0.66, 0.74)
    col = lerp(col, (0.62, 0.62, 0.54), lichen * 0.7)
    col = col * (1 - 0.45 * smooth(fy, 0.75, 1.0))[..., None]               # shadow under next row
    col = lerp((0.08, 0.08, 0.07), col, gap)
    return save("castle_roof", col), save("castle_roof_n", normal_from(h, 6.0), True)

def tex_column(n=1024, tile=2.0, seed=31):
    """Pale limestone with mottling, rain streaks and one drum joint per tile."""
    u, v = grid(n)
    mott = pnoise(n, 6, seed=seed, octaves=5)
    grain = pnoise(n, 200, seed=seed + 1, octaves=3)
    streak = pnoise(n, 40, 2, seed=seed + 2, octaves=3)
    col = lerp((0.70, 0.66, 0.57), (0.52, 0.50, 0.44), mott)
    col = col * (0.88 + 0.2 * grain)[..., None] * (0.78 + 0.22 * streak)[..., None]
    joint = smooth(np.minimum(v, 1 - v) * tile, 0.003, 0.012)
    pits = smooth(pnoise(n, 150, seed=seed + 3, octaves=2), 0.75, 0.82)
    col = lerp(col, (0.42, 0.47, 0.30), smooth(mott, 0.72, 0.9) * 0.45)    # lichen blotches
    col = col * (0.55 + 0.45 * joint)[..., None] * (1 - 0.35 * pits)[..., None]
    h = joint * 0.8 + (grain - 0.5) * 0.08 - pits * 0.3
    return save("castle_column", col), save("castle_column_n", normal_from(h, 4.0), True)

def tex_wood(n=512, seed=41):
    u, v = grid(n)
    g = pnoise(n, 60, 1.5, seed=seed, octaves=4)
    plank = smooth(np.minimum((u * 4) % 1, 1 - (u * 4) % 1), 0.0, 0.03)
    col = lerp((0.20, 0.13, 0.08), (0.38, 0.26, 0.15), g) * (0.4 + 0.6 * plank)[..., None]
    return save("castle_wood", col), save("castle_wood_n", normal_from(plank * 0.6 + g * 0.2, 3.0), True)

# ---------------------------------------------------------------- materials
def mat(name, tex=None, base=(0.5, 0.5, 0.5), rough=0.9, metal=0.0):
    m = bpy.data.materials.new(name); m.use_nodes = True
    nt = m.node_tree; b = nt.nodes["Principled BSDF"]
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    b.inputs["Base Color"].default_value = (*base, 1)
    if tex:
        c = nt.nodes.new("ShaderNodeTexImage"); c.image = tex[0]
        nt.links.new(c.outputs["Color"], b.inputs["Base Color"])
        t = nt.nodes.new("ShaderNodeTexImage"); t.image = tex[1]
        nm = nt.nodes.new("ShaderNodeNormalMap")
        nt.links.new(t.outputs["Color"], nm.inputs["Color"])
        nt.links.new(nm.outputs["Normal"], b.inputs["Normal"])
    return m

MATS = {
    "stone": mat("CastleStone", tex_stone(), rough=0.92),
    "roof": mat("CastleRoof", tex_roof(), rough=0.85),
    "column": mat("CastleColumn", tex_column(), rough=0.8),
    "wood": mat("CastleWood", tex_wood(), rough=0.8),
    "iron": mat("CastleIron", base=(0.06, 0.06, 0.065), rough=0.45, metal=0.7),
    "dark": mat("CastleSlit", base=(0.015, 0.014, 0.012), rough=1.0),
}
TILE = {"stone": 6.0, "roof": 2.0, "column": 2.0, "wood": 1.0, "iron": 1.0, "dark": 1.0}

# ---------------------------------------------------------------- geometry
class Part:
    def __init__(self, name, keys):
        self.name, self.keys = name, keys
        self.bm = bmesh.new(); self.uv = self.bm.loops.layers.uv.new("UVMap")

def planar_uv(p, f, tile):
    n = f.normal; ax = max(range(3), key=lambda i: abs(n[i]))
    for l in f.loops:
        c = l.vert.co
        uv = (c.y, c.z) if ax == 0 else (c.x, c.z) if ax == 1 else (c.x, c.y)
        l[p.uv].uv = (uv[0] / tile, uv[1] / tile)

def box(p, key, lo, hi, rot=0.0):
    """Axis-aligned box in a local frame, then rotated about world Z (used for radial pieces)."""
    vs = bmesh.ops.create_cube(p.bm, size=1.0)["verts"]
    R = Matrix.Rotation(rot, 3, "Z")
    for v in vs:
        loc = Vector([lo[i] + (v.co[i] + 0.5) * (hi[i] - lo[i]) for i in range(3)])
        v.co = R @ loc
    for f in {f for v in vs for f in v.link_faces}:
        f.material_index = p.keys.index(key); f.normal_update(); planar_uv(p, f, TILE[key])

def lathe(p, key, prof, seg=64, U=None, mod=None, keyfn=None):
    """Revolve (r, z) profile. Walk the profile with the solid on the left so normals face out."""
    tile = TILE[key]
    U = U or max(1, round(2 * math.pi * max(r for r, z in prof) / tile))
    vs = [0.0]
    for (r0, z0), (r1, z1) in zip(prof, prof[1:]):
        vs.append(vs[-1] + math.hypot(r1 - r0, z1 - z0))
    rings = []
    for r, z in prof:
        if r < 1e-6:
            c = p.bm.verts.new((0, 0, z)); rings.append([c] * seg)
        else:
            ring = []
            for j in range(seg):
                t = 2 * math.pi * j / seg; m = mod(t) if mod else 1.0
                ring.append(p.bm.verts.new((r * m * math.cos(t), r * m * math.sin(t), z)))
            rings.append(ring)
    for i in range(len(prof) - 1):
        for j in range(seg):
            j2 = (j + 1) % seg
            q = [(rings[i][j], (j / seg * U, vs[i])), (rings[i][j2], ((j + 1) / seg * U, vs[i])),
                 (rings[i + 1][j2], ((j + 1) / seg * U, vs[i + 1])), (rings[i + 1][j], (j / seg * U, vs[i + 1]))]
            seen, pts = set(), []
            for vert, uv in q:
                if vert not in seen:
                    seen.add(vert); pts.append((vert, uv))
            if len(pts) < 3:
                continue
            f = p.bm.faces.new([a for a, _ in pts]); f.normal_update()
            k = keyfn(f) if keyfn else key
            f.material_index = p.keys.index(k)
            if abs(f.normal.z) > 0.75:
                planar_uv(p, f, TILE[k])
            else:
                for l, (_, uv) in zip(f.loops, pts):
                    l[p.uv].uv = (uv[0], uv[1] / tile)

def finish(p):
    me = bpy.data.meshes.new(p.name); p.bm.to_mesh(me); p.bm.free()
    for k in p.keys:
        me.materials.append(MATS[k])
    me.set_sharp_from_angle(angle=math.radians(35))
    o = bpy.data.objects.new(p.name, me); scn.collection.objects.link(o)
    return o

# ---- corner tower (reference: round stone keep, open gallery, shingled cone roof, spire)
def build_tower():
    t = Part("castle_tower", ["stone", "wood", "roof", "iron", "dark"])
    lathe(t, "stone", [(4.65, 0), (4.65, 0.9), (4.25, 1.3), (4.25, 7.7), (4.5, 7.75), (4.5, 8.35), (4.25, 8.4),
                       (4.25, 13.6), (5.15, 15.2), (5.15, 16.4), (5.27, 16.45), (5.27, 16.65), (4.75, 16.65),
                       (4.75, 15.5), (3.3, 15.5), (3.3, 19.6), (0, 19.6)], seg=64, U=4)
    for k in range(24):                      # corbels under the gallery
        box(t, "stone", (4.1, -0.2, 12.9), (4.9, 0.2, 13.75), 2 * math.pi * k / 24)
    for k in range(12):                      # gallery posts
        box(t, "wood", (4.86, -0.13, 16.65), (5.12, 0.13, 19.45), 2 * math.pi * (k + 0.5) / 12)
    for z0, a0 in ((4.2, 0.25), (10.4, 0.0)):  # arrow slits with sill + lintel
        for k in range(4):
            a = 2 * math.pi * (k / 4 + a0 / 4 + 0.125)
            box(t, "dark", (4.15, -0.12, z0), (4.29, 0.12, z0 + 1.3), a)
            box(t, "stone", (4.15, -0.28, z0 - 0.14), (4.38, 0.28, z0), a)
            box(t, "stone", (4.15, -0.28, z0 + 1.3), (4.38, 0.28, z0 + 1.46), a)
    lathe(t, "wood", [(3.2, 19.4), (5.32, 19.4), (5.32, 19.75), (3.2, 19.75)], seg=64)
    lathe(t, "roof", [(0, 19.62), (6.15, 19.5), (6.2, 19.68), (5.4, 20.35), (4.3, 21.9), (3.05, 23.9),
                      (1.85, 25.9), (0.85, 28.6), (0.3, 30.3), (0, 30.7)], seg=64, U=19,
          keyfn=lambda f: "wood" if f.normal.z < -0.5 else "roof")
    lathe(t, "iron", [(0, 30.3), (0.15, 30.4), (0.1, 31.6), (0.24, 31.75), (0.24, 32.0), (0.07, 32.2),
                      (0.035, 33.6), (0, 33.8)], seg=16)
    return finish(t)

# ---- column: square plinth, Attic base, fluted shaft with entasis, Doric capital + abacus
def build_pillar():
    p = Part("castle_pillar", ["column"])
    box(p, "column", (-1.25, -1.25, 0), (1.25, 1.25, 0.6))
    box(p, "column", (-1.15, -1.15, 0.6), (1.15, 1.15, 0.85))
    lathe(p, "column", [(1.12, 0.85), (1.12, 1.0), (1.02, 1.1), (0.97, 1.22), (1.04, 1.32), (1.04, 1.4),
                        (0.93, 1.48)], seg=64)
    fl = 20
    lathe(p, "column", [(0.93, 1.45), (0.925, 4.0), (0.895, 7.0), (0.845, 10.45)], seg=fl * 8,
          mod=lambda t: 1 - 0.07 * math.sin(math.pi * ((fl * t / (2 * math.pi)) % 1.0)))
    lathe(p, "column", [(0.84, 10.4), (0.9, 10.45), (0.9, 10.58), (0.86, 10.62), (0.88, 10.7), (1.02, 10.84),
                        (1.15, 10.97), (1.23, 11.08), (1.25, 11.16)], seg=64)
    box(p, "column", (-1.25, -1.25, 11.15), (1.25, 1.25, 11.62))
    box(p, "column", (-1.1, -1.1, 11.62), (1.1, 1.1, 12.0))
    return finish(p)

# ---- wall: 82 m long (ends hide inside the corner towers), 2 m thick, crenellated both sides
def build_wall():
    w = Part("castle_wall", ["stone"])
    L = 41.0
    box(w, "stone", (-L, -1.0, 0), (L, 1.0, 7.6))
    box(w, "stone", (-L, -1.15, 0), (L, 1.15, 0.7))          # plinth
    box(w, "stone", (-L, -1.08, 0.7), (L, 1.08, 0.85))
    box(w, "stone", (-L, -1.2, 7.45), (L, 1.2, 7.8))         # cornice
    for s in (-1, 1):
        y0, y1 = sorted((s * 1.12, s * 0.55))
        box(w, "stone", (-L, y0, 7.8), (L, y1, 8.35))       # parapet
        for k in range(-20, 21):
            box(w, "stone", (k * 2.0 - 0.6, y0, 8.35), (k * 2.0 + 0.6, y1, 9.4))
        for x in (-30, -20, -10, 0, 10, 20, 30):             # shallow buttresses
            a0, a1 = sorted((s * 1.0, s * 1.3))
            box(w, "stone", (x - 0.65, a0, 0.85), (x + 0.65, a1, 7.45))
            a0, a1 = sorted((s * 1.0, s * 1.42))
            box(w, "stone", (x - 0.8, a0, 0), (x + 0.8, a1, 0.95))
    return finish(w)

objs = [build_tower(), build_pillar(), build_wall()]

def export(o):
    d = os.path.join(OUT, o.name); os.makedirs(d, exist_ok=True)
    bpy.context.view_layer.update()   # without this the first export sees no selection and writes an empty glb
    for x in bpy.context.view_layer.objects:
        x.select_set(x == o)
    bpy.context.view_layer.objects.active = o
    bpy.ops.export_scene.gltf(filepath=os.path.join(d, o.name + ".glb"), export_format="GLB", use_selection=True,
                              export_yup=True, export_apply=True, export_tangents=True, export_image_format="JPEG")
    print("EXPORT", o.name, len(o.data.polygons), "faces")

for o in objs:
    export(o)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "castle_arena.blend"))

# ---------------------------------------------------------------- preview (NE corner of the arena)
if PREV:
    tower, pillar, wall = objs
    def place(o, loc, rz=0.0):
        c = o.copy(); scn.collection.objects.link(c); c.location = loc; c.rotation_euler = (0, 0, rz); return c
    place(tower, (40, 40, 0)); place(tower, (-40, 40, 0)); place(tower, (40, -40, 0))
    place(wall, (0, 40, 0)); place(wall, (40, 0, 0), -math.pi / 2)
    place(pillar, (17.5, 17.5, 0)); place(pillar, (-17.5, 17.5, 0)); place(pillar, (17.5, -17.5, 0))
    bpy.ops.mesh.primitive_plane_add(size=90, location=(0, 0, 0))
    fm = bpy.data.materials.new("Floor"); fm.use_nodes = True
    fm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.03, 0.035, 0.045, 1)
    bpy.context.object.data.materials.append(fm)
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN")); scn.collection.objects.link(sun)
    sun.data.energy = 4.0; sun.rotation_euler = (math.radians(50), 0, math.radians(200))
    world = bpy.data.worlds.new("W"); scn.world = world; world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.45, 0.62, 0.85, 1)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.9
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam")); scn.collection.objects.link(cam)
    scn.camera = cam; cam.data.lens = 24
    scn.render.engine = "BLENDER_EEVEE"
    scn.render.resolution_x, scn.render.resolution_y = 1280, 720
    scn.view_settings.view_transform = "AgX"
    shots = {"corner": ((-6, -8, 2.0), (34, 36, 10)), "tower": ((24, 22, 1.8), (40, 40, 14)),
             "pillar": ((12, 10, 1.8), (17.5, 17.5, 6)), "overview": ((-10, -25, 22), (22, 30, 6))}
    for name, (eye, at) in shots.items():
        cam.location = eye
        cam.rotation_euler = (Vector(at) - Vector(eye)).to_track_quat("-Z", "Y").to_euler()
        scn.render.filepath = os.path.join(PREV, f"castle_{name}.png")
        bpy.ops.render.render(write_still=True)
        print("PREVIEW", scn.render.filepath)
