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
# The wide main crack: keep its jagged shape but drop the soft halo (it read as a blob of light) and shrink it a little.
T = nd.binary_dilation(nd.grey_opening(m, size=(11, 11)) > 0.3, iterations=6)    # where the wide crack is
hot = np.clip((v - 0.86) / 0.06, 0, 1)                                           # only the white-hot crack interior
hot = nd.grey_erosion(hot, size=(3, 3))                                          # a little thinner, edges stay jagged
m = np.where(T, hot, m)
glow = im / np.maximum(v, 1e-3)[..., None]          # normalised hue (white core stays white)
glow = glow ** 2.2                                   # push the cyan, keep white-hot core white
e = glow * m[..., None]
Image.fromarray((e * 255).astype(np.uint8)).resize((2048, 630), Image.LANCZOS).save(out)
