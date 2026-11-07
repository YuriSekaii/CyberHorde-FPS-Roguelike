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
    col = lerp((0.30, 0.20, 0.12), (0.50, 0.36, 0.22), g) * (0.5 + 0.5 * plank)[..., None]
    return save("castle_wood", col), save("castle_wood_n", normal_from(plank * 0.6 + g * 0.2, 3.0), True)

def tex_flagstone(n=2048, tile=4.0, rows=8, seed=51):
    """Courtyard paving: rows of 0.5 m stones with random lengths, moss and dirt in the joints."""
    r = np.random.default_rng(seed)
    u, v = grid(n)
    ry = v * rows; row = np.floor(ry).astype(int); fy = ry - row
    du = np.zeros((n, n)); sid = np.zeros((n, n), int)
    band = n // rows
    for k in range(rows):
        w = 0.6 + r.random(r.integers(4, 7)); w /= w.sum()        # min stone ~0.4 m, no slivers
        cuts = np.sort((np.cumsum(w) + r.random()) % 1.0)
        sl = slice(k * band, (k + 1) * band); uu = u[sl]
        diff = np.abs(uu[..., None] - cuts)
        du[sl] = np.minimum(diff, 1 - diff).min(-1) * tile     # cuts wrap around, so the row tiles
        sid[sl] = k * 16 + np.searchsorted(cuts, uu) % len(cuts)
    # centuries of wear: ragged, broken edges and corners, cracked stones, stains, dirt and moss creeping in
    jit = pnoise(n, 30, seed=seed + 1, octaves=4) - 0.5
    chip = smooth(pnoise(n, 60, seed=seed + 7, octaves=3), 0.6, 0.75)
    d = np.minimum(du, np.minimum(fy, 1 - fy) * tile / rows) + jit * 0.045 - chip * 0.05
    r1 = r.random(rows * 16)[sid]; r2 = r.random(rows * 16)[sid]; r3 = r.random(rows * 16)[sid]
    grain = pnoise(n, 220, seed=seed + 2, octaves=3)
    dirt = pnoise(n, 4, seed=seed + 3, octaves=4)
    stain = smooth(pnoise(n, 9, seed=seed + 5, octaves=4), 0.55, 0.8)
    crack = (1 - smooth(np.abs(pnoise(n, 6, seed=seed + 6, octaves=3) - 0.5), 0.003, 0.011)) * (r3 < 0.3)
    dips = pnoise(n, 14, seed=seed + 8, octaves=3)                          # worn hollows collect dirt
    edge = smooth(d, 0.006, 0.08)
    h = edge * (0.8 + 0.2 * r2) + (grain - 0.5) * 0.14 - crack * 0.6 - smooth(dips, 0.6, 0.85) * 0.15
    col = lerp((0.40, 0.38, 0.34), (0.27, 0.26, 0.24), r1)
    col = lerp(col, (0.38, 0.33, 0.26), (r2 > 0.8).astype(float) * 0.6)
    col = col * (0.8 + 0.3 * grain)[..., None] * (0.72 + 0.3 * dirt)[..., None]
    col = lerp(col, (0.16, 0.15, 0.13), stain * 0.55)                       # old water / soot stains
    col = lerp(col, (0.21, 0.18, 0.14), smooth(dips, 0.6, 0.85) * 0.6)
    moss = smooth(pnoise(n, 25, seed=seed + 4, octaves=2), 0.4, 0.6)
    joint = lerp((0.12, 0.11, 0.09), (0.17, 0.22, 0.10), moss)
    col = lerp(col, joint, (1 - smooth(d, 0.0, 0.05)) * moss * 0.5)          # moss creeping onto the edges
    col = lerp(joint, col, smooth(d, 0.004, 0.016))
    col = col * (0.62 + 0.38 * edge)[..., None] * (1 - 0.65 * crack)[..., None]
    return save("castle_flagstone", col), save("castle_flagstone_n", normal_from(h, 6.0), True)

def tex_temple(n=1024, seed=61, moss=False):
    """Ancient temple limestone (2 m tile): worn, rain-grimed, cracked. The moss variant goes low and on ledges."""
    mott = pnoise(n, 5, seed=seed, octaves=5)
    grain = pnoise(n, 220, seed=seed + 1, octaves=3)
    streak = pnoise(n, 25, 5, seed=seed + 2, octaves=3)
    crack = 1 - smooth(np.abs(pnoise(n, 7, seed=seed + 3, octaves=4) - 0.5), 0.0, 0.008)
    crack *= smooth(pnoise(n, 3, seed=seed + 4, octaves=2), 0.45, 0.6)      # cracks only in some areas
    pits = smooth(pnoise(n, 140, seed=seed + 5, octaves=2), 0.72, 0.8)
    col = lerp((0.68, 0.62, 0.51), (0.50, 0.46, 0.38), mott) * (0.85 + 0.25 * grain)[..., None]
    col = lerp(col, (0.34, 0.32, 0.27), smooth(streak, 0.6, 0.9) * 0.35)  # rain grime
    col = lerp(col, (0.47, 0.50, 0.36), smooth(mott, 0.7, 0.9) * 0.5)      # lichen
    if moss:
        m = smooth(pnoise(n, 8, seed=seed + 6, octaves=4), 0.4, 0.68)
        col = lerp(col, lerp((0.20, 0.25, 0.12), (0.31, 0.35, 0.18), grain), m * 0.7)
    col = col * (1 - 0.6 * crack)[..., None] * (1 - 0.35 * pits)[..., None]
    h = (grain - 0.5) * 0.15 - crack * 0.8 - pits * 0.4 + mott * 0.2
    name = "temple_moss" if moss else "temple_stone"
    return save(name, col), save(name + "_n", normal_from(h, 4.0), True)

def seg_dist(px, py, a, b):
    dx, dy = b[0] - a[0], b[1] - a[1]
    t = np.clip(((px - a[0]) * dx + (py - a[1]) * dy) / (dx * dx + dy * dy), 0, 1)
    return np.hypot(px - a[0] - t * dx, py - a[1] - t * dy)

def rune_mask(n=1024, glyphs=12, seed=71):
    """Jump-pad sigil in pad UV space (0..1 spans the 3.56 m pad): rings, a band of runes, a hexagram.
    Returns (line mask, glow mask with soft halo)."""
    r = np.random.default_rng(seed)
    u, v = grid(n)
    x, y = u * 2 - 1, v * 2 - 1
    R, T = np.hypot(x, y), np.arctan2(y, x)
    w = 0.011
    line = lambda d, wd=w: 1 - smooth(d, wd * 0.5, wd)
    m = np.maximum.reduce([line(np.abs(R - 0.82)), line(np.abs(R - 0.76), 0.007), line(np.abs(R - 0.53)),
                           line(np.abs(R - 0.16), 0.009), 1 - smooth(R, 0.03, 0.045)])
    pts = [(0.48 * math.cos(math.pi / 2 + k * math.pi / 3), 0.48 * math.sin(math.pi / 2 + k * math.pi / 3)) for k in range(6)]
    d = np.full(R.shape, 9.0)
    for k in range(6):
        d = np.minimum(d, seg_dist(x, y, pts[k], pts[(k + 2) % 6]))
    m = np.maximum(m, line(d))
    span = 2 * math.pi / glyphs
    gi = np.floor((T + math.pi) / span)
    px, py = (T - (-math.pi + (gi + 0.5) * span)) * R, R - 0.655
    d = np.full(R.shape, 9.0)
    grid3 = (-0.05, 0.0, 0.05)
    for g in range(glyphs):
        sel = (np.abs(py) < 0.09) & (gi == g)
        segs = [((0.0, -0.06), (0.0, 0.06))]                     # every rune has a stem
        while len(segs) < 3 + r.integers(0, 2):
            a = (float(r.choice(grid3)), float(r.choice(grid3)) * 1.2)
            b = (float(r.choice(grid3)), float(r.choice(grid3)) * 1.2)
            if a != b:
                segs.append((a, b))
        dd = np.full(int(sel.sum()), 9.0)
        for a, b in segs:
            dd = np.minimum(dd, seg_dist(px[sel], py[sel], a, b))
        d[sel] = dd
    m = np.maximum(m, line(d))
    f2 = np.fft.fftfreq(n)[:, None] ** 2 + np.fft.fftfreq(n)[None, :] ** 2
    halo = np.real(np.fft.ifft2(np.fft.fft2(m) * np.exp(-2 * math.pi ** 2 * 36 * f2)))   # gaussian, sigma 6 px
    return m, np.maximum(m, np.clip(halo * 1.5, 0, 1) * 0.45)

def tex_pad(mask, n=1024, seed=81):
    """Dark round stone: inner disc + ring of 12 wedge blocks, with the sigil carved in."""
    u, v = grid(n)
    x, y = u * 2 - 1, v * 2 - 1
    R, T = np.hypot(x, y), np.arctan2(y, x)
    grain = pnoise(n, 200, seed=seed, octaves=3)
    mott = pnoise(n, 6, seed=seed + 1, octaves=4)
    fw = ((T + math.pi) / (2 * math.pi) * 12) % 1.0
    jd = np.where(R > 0.62, np.minimum(fw, 1 - fw) * 2 * math.pi / 12 * R, 9.0)
    joint = smooth(np.minimum(jd, np.abs(R - 0.62)), 0.004, 0.012)
    col = lerp((0.31, 0.32, 0.34), (0.22, 0.23, 0.25), mott) * (0.85 + 0.3 * grain)[..., None]
    col = col * (0.5 + 0.5 * joint)[..., None]
    col = lerp(col, (0.07, 0.08, 0.09), mask * 0.9)                      # carved grooves
    h = joint * 0.6 + (grain - 0.5) * 0.1 - mask * 0.8
    return save("jump_pad_stone", col), save("jump_pad_stone_n", normal_from(h, 4.0), True)

def save_alpha(name, alpha, path):
    n = alpha.shape[0]
    img = bpy.data.images.new(name, n, n, alpha=True)
    a = np.ones((n, n, 4), np.float32); a[..., 3] = np.clip(alpha, 0, 1)
    img.pixels.foreach_set(a.ravel())
    img.filepath_raw = path; img.file_format = "PNG"; img.save()

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

TEX = {"stone": tex_stone(), "roof": tex_roof(), "column": tex_column(), "wood": tex_wood(),
       "flagstone": tex_flagstone(), "temple": tex_temple(), "templemoss": tex_temple(moss=True)}
RUNES, RUNE_GLOW = rune_mask()
TEX["pad"] = tex_pad(RUNES)
MATS = {
    "stone": mat("CastleStone", TEX["stone"], rough=0.92),
    "roof": mat("CastleRoof", TEX["roof"], rough=0.85),
    "column": mat("CastleColumn", TEX["column"], rough=0.8),
    "wood": mat("CastleWood", TEX["wood"], rough=0.8),
    "iron": mat("CastleIron", base=(0.06, 0.06, 0.065), rough=0.45, metal=0.7),
    "dark": mat("CastleSlit", base=(0.015, 0.014, 0.012), rough=1.0),
    "temple": mat("TempleStone", TEX["temple"], rough=0.88),
    "templemoss": mat("TempleMoss", TEX["templemoss"], rough=0.95),
    "pad": mat("JumpPadStone", TEX["pad"], rough=0.8),
}
TILE = {"stone": 6.0, "roof": 2.0, "column": 2.0, "wood": 1.0, "iron": 1.0, "dark": 1.0,
        "temple": 2.0, "templemoss": 2.0, "pad": 3.56}
OFF = {"pad": 0.5}   # pad UVs are centred so the sigil texture sits on the disc

# ---------------------------------------------------------------- geometry
class Part:
    def __init__(self, name, keys):
        self.name, self.keys = name, keys
        self.bm = bmesh.new(); self.uv = self.bm.loops.layers.uv.new("UVMap")

def planar_uv(p, f, key):
    n = f.normal; ax = max(range(3), key=lambda i: abs(n[i]))
    tile, off = TILE[key], OFF.get(key, 0.0)
    for l in f.loops:
        c = l.vert.co
        uv = (c.y, c.z) if ax == 0 else (c.x, c.z) if ax == 1 else (c.x, c.y)
        l[p.uv].uv = (uv[0] / tile + off, uv[1] / tile + off)

def box(p, key, lo, hi, rot=0.0, cuts=0):
    """Axis-aligned box in a local frame, then rotated about world Z (used for radial pieces).
    cuts > 0 grid-subdivides it so it can be eroded."""
    before = set(p.bm.faces)
    vs = bmesh.ops.create_cube(p.bm, size=1.0)["verts"]
    R = Matrix.Rotation(rot, 3, "Z")
    for v in vs:
        loc = Vector([lo[i] + (v.co[i] + 0.5) * (hi[i] - lo[i]) for i in range(3)])
        v.co = R @ loc
    if cuts:
        bmesh.ops.subdivide_edges(p.bm, edges=list({e for v in vs for e in v.link_edges}), cuts=cuts, use_grid_fill=True)
    for f in set(p.bm.faces) - before:
        f.material_index = p.keys.index(key); f.normal_update(); planar_uv(p, f, key)

def lathe(p, key, prof, seg=64, U=None, mod=None, keyfn=None, phase=0.0):
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
                t += phase
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
                planar_uv(p, f, k)
            else:
                for l, (_, uv) in zip(f.loops, pts):
                    l[p.uv].uv = (uv[0], uv[1] / tile)
    return {v for ring in rings for v in ring}

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

# ---- ancient temple column: square plinth, Attic base, five re-stacked fluted drums slightly out of line,
#      Doric capital + abacus; everything eroded inward (never outward, so the colliders stay outside the mesh),
#      chipped edges and corners, moss low down and on ledges
def build_pillar():
    from mathutils import noise
    rng = np.random.default_rng(5)
    p = Part("castle_pillar", ["temple", "templemoss"])
    box(p, "temple", (-1.25, -1.25, 0), (1.25, 1.25, 0.6), cuts=10)
    box(p, "temple", (-1.15, -1.15, 0.6), (1.15, 1.15, 0.85), cuts=10)
    lathe(p, "temple", [(1.12, 0.85), (1.12, 1.0), (1.02, 1.1), (0.97, 1.22), (1.04, 1.32), (1.04, 1.4),
                        (0.93, 1.48)], seg=96)
    fl = 20
    flute = lambda t: 1 - 0.07 * math.sin(math.pi * ((fl * t / (2 * math.pi)) % 1.0))
    rad = lambda z: float(np.interp(z, [1.45, 4.0, 7.0, 10.45], [0.93, 0.925, 0.895, 0.845]))
    for k in range(5):
        z0, z1 = 1.45 + 1.8 * k, 1.45 + 1.8 * (k + 1)
        prof = ([(0, z0), (rad(z0) - 0.035, z0), (rad(z0 + 0.05), z0 + 0.05)]
                + [(rad(z), z) for z in np.linspace(z0 + 0.2, z1 - 0.2, 8)]
                + [(rad(z1 - 0.05), z1 - 0.05), (rad(z1) - 0.035, z1), (0, z1)])
        vs = lathe(p, "temple", prof, seg=fl * 6, mod=flute, phase=float(rng.uniform(-0.06, 0.06)))
        off = Vector((rng.uniform(-0.02, 0.02), rng.uniform(-0.02, 0.02), 0))
        for v in vs:
            v.co += off
    lathe(p, "temple", [(0.84, 10.4), (0.9, 10.45), (0.9, 10.58), (0.86, 10.62), (0.88, 10.7), (1.02, 10.84),
                        (1.15, 10.97), (1.23, 11.08), (1.25, 11.16)], seg=96)
    box(p, "temple", (-1.25, -1.25, 11.15), (1.25, 1.25, 11.62), cuts=10)
    box(p, "temple", (-1.1, -1.1, 11.62), (1.1, 1.1, 12.0), cuts=8)

    bm = p.bm; bm.normal_update()
    allv = list(bm.verts)
    chips = [(allv[int(rng.integers(len(allv)))].co.copy(), float(rng.uniform(0.08, 0.3))) for _ in range(45)]
    for sx in (-1, 1):
        for sy in (-1, 1):
            for zc in (0.6, 0.85, 11.15, 11.62, 12.0):
                if rng.random() < 0.6:
                    chips.append((Vector((sx * 1.2, sy * 1.2, zc)), float(rng.uniform(0.15, 0.42))))
    disp = []
    for v in allv:
        c = v.co
        e = 0.04 * max(0.0, noise.noise(c * 1.3)) + 0.012 * noise.noise(c * 7.0)
        for cc, r in chips:
            d = (c - cc).length
            if d < r:
                e += (r - d) * 0.7
        disp.append(v.normal * max(e, 0.0) if c.z > 0.02 else Vector())   # keep the footprint on the floor
    for v, d in zip(allv, disp):
        v.co -= d
    mi = p.keys.index("templemoss")
    for f in bm.faces:
        f.normal_update(); c = f.calc_center_median()
        low = c.z < 0.7 + 0.9 * (noise.noise(c * 0.8) + 1) / 2
        ledge = f.normal.z > 0.6 and noise.noise(c * 2.0) > -0.2
        if low or ledge:
            f.material_index = mi
    return finish(p)

# ---- jump pad: dark round rune-stone (sigil carved in; the glow overlay lives in jump_pad.tscn)
def build_jump_pad():
    j = Part("jump_pad", ["pad", "stone"])
    lathe(j, "pad", [(1.78, 0), (1.78, 0.06), (1.72, 0.1), (1.62, 0.1), (1.62, 0.17), (1.57, 0.21), (0, 0.21)],
          seg=64, keyfn=lambda f: "pad" if f.normal.z > 0.75 else "stone")
    return finish(j)

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

objs = [build_tower(), build_pillar(), build_wall(), build_jump_pad()]

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
# Tileable textures for the arena's Godot box meshes (floor, platform, ramps, cover; world-triplanar materials)
TEXOUT = os.path.join(OUT, "..", "textures", "castle"); os.makedirs(TEXOUT, exist_ok=True)
for key in ("stone", "column", "wood", "flagstone"):
    for img in TEX[key]:
        img.file_format = "JPEG"; img.filepath_raw = os.path.join(TEXOUT, img.name + ".jpg"); img.save()
save_alpha("jump_pad_runes", RUNE_GLOW, os.path.join(TEXOUT, "jump_pad_runes.png"))   # white sigil, glow in alpha
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "castle_arena.blend"))

# ---------------------------------------------------------------- preview (NE corner of the arena)
if PREV:
    tower, pillar, wall, pad = objs
    def place(o, loc, rz=0.0):
        c = o.copy(); scn.collection.objects.link(c); c.location = loc; c.rotation_euler = (0, 0, rz); return c
    place(tower, (40, 40, 0)); place(tower, (-40, 40, 0)); place(tower, (40, -40, 0))
    place(wall, (0, 40, 0)); place(wall, (40, 0, 0), -math.pi / 2)
    place(pillar, (17.5, 17.5, 0)); place(pillar, (-17.5, 17.5, 0)); place(pillar, (17.5, -17.5, 0))
    place(pad, (22.5, 22.5, 0))
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
    shots = {"pillar": ((13, 11, 1.8), (17.5, 17.5, 5.5)), "pillar_base": ((15, 15.5, 1.2), (17.5, 17.5, 0.8)),
             "pillar_top": ((15, 15.5, 9.5), (17.5, 17.5, 11.3)), "pad": ((20.5, 20.5, 2.2), (22.5, 22.5, 0))}
    for name, (eye, at) in shots.items():
        cam.location = eye
        cam.rotation_euler = (Vector(at) - Vector(eye)).to_track_quat("-Z", "Y").to_euler()
        scn.render.filepath = os.path.join(PREV, f"castle_{name}.png")
        bpy.ops.render.render(write_still=True)
        print("PREVIEW", scn.render.filepath)
