import os, sys
os.environ["OPENCV_IO_ENABLE_OPENEXR"] = "1"
import numpy as np, cv2
from PIL import Image, ImageEnhance
OUT = sys.argv[1]
S = 1024
def load(p, mode='RGB'):
    return Image.open(p).convert(mode).resize((S, S), Image.LANCZOS)
def norm_mean(img, target, sat):
    img = ImageEnhance.Color(img).enhance(sat)
    a = np.asarray(img, dtype=np.float32) / 255.0
    m = a.mean()
    a = np.clip(a * (target / m), 0, 1)
    return Image.fromarray((a * 255).astype(np.uint8))
def with_ao(col, ao, k=0.5):
    a = np.asarray(col, dtype=np.float32); o = np.asarray(ao, dtype=np.float32)[..., None] / 255.0
    return Image.fromarray(np.clip(a * (1 - k + k * o), 0, 255).astype(np.uint8))
def exr_normal(p):
    im = cv2.imread(p, cv2.IMREAD_UNCHANGED)
    if im is None:
        # EXR nicht lesbar: Normalen aus der Höhenkarte berechnen
        d = np.asarray(Image.open(p.replace('nor_gl_2k.exr', 'disp_2k.png')).convert('F').resize((S, S), Image.LANCZOS), dtype=np.float32)
        d = d / max(d.max(), 1.0)
        gx = (np.roll(d, -1, 1) - np.roll(d, 1, 1)) * 6.0
        gy = (np.roll(d, -1, 0) - np.roll(d, 1, 0)) * 6.0
        n = np.dstack([-gx, gy, np.ones_like(d)])
        n /= np.linalg.norm(n, axis=2, keepdims=True)
        return Image.fromarray(((n * 0.5 + 0.5) * 255).astype(np.uint8))
    im = cv2.cvtColor(im[..., :3], cv2.COLOR_BGR2RGB)
    im = np.clip(im, 0, 1)
    return Image.fromarray((im * 255).astype(np.uint8)).resize((S, S), Image.LANCZOS)
T = '/tmp/tx_'
floor_c = Image.open('/home/claude/homebound/assets/textures/ground/forest_floor_color.jpg').convert('RGB').resize((S, S))
floor_n = Image.open('/home/claude/homebound/assets/textures/ground/forest_floor_normal.jpg').convert('RGB').resize((S, S))
layers = []
# 0 Waldboden (wie bisher)
layers.append((floor_c, floor_n))
# 1 Wiese/Boden allgemein (Ground110) – Detail, wird mit der Eckpunktfarbe getönt
c = with_ao(load(T+'Wiese/Ground110_2K-JPG_Color.jpg'), load(T+'Wiese/Ground110_2K-JPG_AmbientOcclusion.jpg', 'L'))
layers.append((norm_mean(c, 0.82, 0.45), load(T+'Wiese/Ground110_2K-JPG_NormalGL.jpg')))
# 2 Fels (Rock030)
c = with_ao(load(T+'Felsen/Rock030_2K-JPG_Color.jpg'), load(T+'Felsen/Rock030_2K-JPG_AmbientOcclusion.jpg', 'L'))
layers.append((norm_mean(c, 0.85, 0.5), load(T+'Felsen/Rock030_2K-JPG_NormalGL.jpg')))
# 3 Bachbett (dry river pebbles)
layers.append((norm_mean(load(T+'Flussbett/textures/dry_river_pebbles_diff_2k.jpg'), 0.85, 0.6), exr_normal(T+'Flussbett/textures/dry_river_pebbles_nor_gl_2k.exr')))
# 4 Weg (Gravel040)
c = with_ao(load(T+'Weg/Gravel040_1K-JPG_Color.jpg'), load(T+'Weg/Gravel040_1K-JPG_AmbientOcclusion.jpg', 'L'))
layers.append((norm_mean(c, 0.85, 0.6), load(T+'Weg/Gravel040_1K-JPG_NormalGL.jpg')))
# 5 Schnee (Snow014)
c = with_ao(load(T+'Schnee/Snow014_2K-JPG_Color.jpg'), load(T+'Schnee/Snow014_2K-JPG_AmbientOcclusion.jpg', 'L'), 0.4)
layers.append((norm_mean(c, 0.93, 0.8), load(T+'Schnee/Snow014_2K-JPG_NormalGL.jpg')))
col = Image.new('RGB', (S, S * len(layers))); nrm = Image.new('RGB', (S, S * len(layers)))
for i, (c, n) in enumerate(layers):
    col.paste(c, (0, i * S)); nrm.paste(n, (0, i * S))
col.save(OUT + '/ground_color_array.jpg', quality=90)
nrm.save(OUT + '/ground_normal_array.png')
# Fels einzeln für Felsbrocken (Material), Hüttenboden
rc = with_ao(load(T+'Felsen/Rock030_2K-JPG_Color.jpg'), load(T+'Felsen/Rock030_2K-JPG_AmbientOcclusion.jpg', 'L'))
norm_mean(rc, 0.5, 0.55).save(OUT + '/rock_color.jpg', quality=90)
load(T+'Felsen/Rock030_2K-JPG_NormalGL.jpg').save(OUT + '/rock_normal.jpg', quality=92)
load(T+'Felsen/Rock030_2K-JPG_Roughness.jpg', 'L').save(OUT + '/rock_rough.jpg', quality=90)
wc = with_ao(load(T+'Boden_H_tte/WoodFloor041_2K-JPG_Color.jpg'), load(T+'Boden_H_tte/WoodFloor041_2K-JPG_AmbientOcclusion.jpg', 'L'), 0.4)
wc.save(OUT + '/wood_floor_color.jpg', quality=90)
load(T+'Boden_H_tte/WoodFloor041_2K-JPG_NormalGL.jpg').save(OUT + '/wood_floor_normal.jpg', quality=92)
load(T+'Boden_H_tte/WoodFloor041_2K-JPG_Roughness.jpg', 'L').save(OUT + '/wood_floor_rough.jpg', quality=90)
print('ok', np.asarray(wc).reshape(-1, 3).mean(0) / 255)
