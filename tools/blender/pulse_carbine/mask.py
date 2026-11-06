# Vein emission texture: reference crop (gun bbox) -> RGB glow * smoothstep mask. UV mapping in build uses the same crop.
import sys
from PIL import Image
import numpy as np
CROP = (120, 395, 2620, 1165)   # x0,y0,x1,y1 in reference pixels
src, out = sys.argv[1], sys.argv[2]
im = np.asarray(Image.open(src).convert("RGB").crop(CROP)).astype(np.float32) / 255
v = im.max(2)
t = np.clip((v - 0.47) / (0.72 - 0.47), 0, 1); m = t * t * (3 - 2 * t)
from scipy import ndimage as nd
thick = nd.grey_opening(m, size=(11, 11)) > 0.3                     # only the wide main crack survives an 11 px opening
T = np.clip(nd.gaussian_filter(nd.binary_dilation(thick, iterations=3).astype(np.float32), 2), 0, 1)
dist = nd.distance_transform_edt(thick)
line = (dist >= 0.8 * nd.maximum_filter(dist, size=41)) & (dist > 1)  # centre ~20% of the crack's width, wherever it is
line = np.clip(nd.gaussian_filter(line.astype(np.float32), 1.0) * 1.6, 0, 1)
dim = 0.45 * np.exp(-nd.distance_transform_edt(line < 0.5) / 7.0)  # soft cyan halo hugging the thin line
m = np.maximum(m * (1 - T), line)                                  # wide crack -> thin bright line; thin veins untouched
glow = im / np.maximum(v, 1e-3)[..., None]          # normalised hue (white core stays white)
glow = glow ** 2.2                                   # push the cyan, keep white-hot core white
e = np.maximum(glow * m[..., None], np.array([0.2, 0.8, 1.0]) * dim[..., None])
Image.fromarray((e * 255).astype(np.uint8)).resize((2048, 630), Image.LANCZOS).save(out)
