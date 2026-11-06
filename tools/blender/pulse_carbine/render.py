import sys, math, bpy
from mathutils import Vector
out = sys.argv[sys.argv.index("--") + 1]
scn = bpy.context.scene
scn.render.engine = "BLENDER_EEVEE"; scn.render.resolution_x, scn.render.resolution_y = 1400, 800
w = bpy.data.worlds.new("w"); scn.world = w; w.use_nodes = True
w.node_tree.nodes["Background"].inputs[0].default_value = (0.02, 0.022, 0.026, 1); w.node_tree.nodes["Background"].inputs[1].default_value = 1
scn.view_settings.view_transform = "AgX"
def light(name, loc, energy, size=1.0):
    l = bpy.data.lights.new(name, "AREA"); l.energy = energy; l.size = size
    o = bpy.data.objects.new(name, l); scn.collection.objects.link(o); o.location = loc
    o.rotation_euler = (Vector((0, 0, 0.12)) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
light("key", (1.2, 0.4, 1.0), 120); light("rim", (-1.0, -0.6, 0.8), 80); light("fill", (0.6, -0.8, -0.2), 25)
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); scn.collection.objects.link(cam); scn.camera = cam
views = {"side": ((1.25, 0, 0.12), 32), "front34": ((0.75, 0.7, 0.3), 40), "fps": ((0.28, -0.55, 0.28), 55)}
for n, (loc, lens_fov) in views.items():
    cam.location = loc; cam.data.angle = math.radians(lens_fov)
    tgt = Vector((0, 0.05 if n == "fps" else 0, 0.12))
    cam.rotation_euler = (tgt - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    scn.render.filepath = f"{out}_{n}.png"; bpy.ops.render.render(write_still=True)
