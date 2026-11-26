# Foto-Texturen Runde 2 (Christian 26.11.): Kreatur-/Sucherhaut, Blockhütten-Stämme, Gred-Pflaster, Bretterwand innen.
# Aufruf: python3 -I tools/textures_prep2.py ZIELORDNER_PROJEKT QUELL_GRED QUELL_BRETTER BILD_KREATUR BILD_SUCHER BILD_STAEMME
import os, sys
os.environ["OPENCV_IO_ENABLE_OPENEXR"] = "1"
import numpy as np, cv2
from PIL import Image, ImageEnhance, ImageFilter

PROJ, GRED, PLANKS, CREA, SEEK, LOGS = sys.argv[1:7]
S = 1024
GROUND = PROJ + '/assets/textures/ground/'
CREAT = PROJ + '/assets/textures/creatures/'


def load(p, mode='RGB'):
    return Image.open(p).convert(mode).resize((S, S), Image.LANCZOS)


def arr(img):
    return np.asarray(img, dtype=np.float32) / 255.0


def img(a):
    return Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8))


def norm_mean(im, target, sat):
    im = ImageEnhance.Color(im).enhance(sat)
    a = arr(im)
    return img(a * (target / a.mean()))


def normal_from_height(h, strength):
    # h 0..1, nahtlos (np.roll) – Normalen im OpenGL-Format (Godot)
    gx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * strength
    gy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * strength
    n = np.dstack([-gx, gy, np.ones_like(h)])
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    return img(n * 0.5 + 0.5)


def make_tileable(a, feather=0.18, seed=1):
    # Halb verschoben überblenden: Ränder aus der verschobenen Kopie (dort nahtlos), Mitte aus dem Original,
    # Übergang mit verrauschter Maske, damit keine geraden Linien entstehen.
    r = np.roll(np.roll(a, S // 2, 0), S // 2, 1)
    yy, xx = np.mgrid[0:S, 0:S] / (S - 1.0)
    d = np.minimum(np.minimum(xx, 1 - xx), np.minimum(yy, 1 - yy))
    rng = np.random.default_rng(seed)
    noise = cv2.GaussianBlur(rng.random((S, S)).astype(np.float32), (0, 0), 18)
    noise = (noise - noise.mean()) / (noise.std() + 1e-6) * 0.04
    m = np.clip((d + noise - 0.08) / feather, 0, 1)[..., None]
    return a * m + r * (1 - m)


def flatten(a, sigma=70, keep=0.25):
    # große Helligkeitsflecken (Spiegelmuster) einebnen, damit die Kachel nicht als Muster auffällt
    low = cv2.GaussianBlur(a, (0, 0), sigma)
    return a - low * (1 - keep) + a.mean((0, 1)) * (1 - keep)


def luma(a):
    return a[..., 0] * 0.3 + a[..., 1] * 0.59 + a[..., 2] * 0.11


def save_set(base, col, nrm, rough):
    col.save(base + 'color.jpg', quality=90)
    nrm.save(base + 'normal.jpg', quality=92)
    rough.save(base + 'rough.jpg', quality=90)


# --- Kreatur: blasse, feucht schimmernde Netzhaut ---------------------------------------------
c = flatten(make_tileable(arr(load(CREA)), seed=3))
c = arr(norm_mean(img(c), 0.48, 0.7))
h = cv2.GaussianBlur(luma(c), (0, 0), 1.2)
save_set(CREAT + 'creature_skin_', img(c), normal_from_height(h, 5.0), img(0.45 + (1 - h) * 0.35))

# --- Sucher: vertrocknete Platten mit dunklen Fugen ---------------------------------------------
c = flatten(make_tileable(arr(load(SEEK)), seed=5), 90, 0.5)
c = arr(norm_mean(img(c), 0.5, 0.45))
h = cv2.GaussianBlur(luma(c), (0, 0), 1.5)
c = c.mean((0, 1)) + (c - c.mean((0, 1))) * 0.55   # weniger Kontrast: Fugen dunkel, Platten nicht grellweiß
save_set(CREAT + 'seeker_skin_', img(c), normal_from_height(h, 6.0), img(0.7 + (1 - h) * 0.25))

# --- Blockhütte: Stämme (Bild um 90° gedreht, Maserung läuft längs der Stämme) -------------------
c = load(LOGS).rotate(90)
ca = arr(norm_mean(c, 0.36, 0.9))
h = cv2.GaussianBlur(luma(ca), (0, 0), 1.0)
save_set(GROUND + 'logs_', img(ca), normal_from_height(h, 4.0), img(0.75 + (1 - h) * 0.2))

# --- Gred: Granit-Pflaster (PavingStones070), Moos in den Fugen etwas zurückgenommen -------------
pre = GRED + '/PavingStones070_1K-JPG_'
c = arr(load(pre + 'Color.jpg'))
ao = arr(load(pre + 'AmbientOcclusion.jpg', 'L'))[..., None]
c = c * (0.55 + 0.45 * ao)
c = arr(norm_mean(img(c), 0.42, 0.55))
load(pre + 'NormalGL.jpg').save(GROUND + 'gred_normal.jpg', quality=92)
img(c).save(GROUND + 'gred_color.jpg', quality=90)
load(pre + 'Roughness.jpg', 'L').save(GROUND + 'gred_rough.jpg', quality=90)

# --- Bretterwand innen (Poly Haven raw_plank_wall) -----------------------------------------------
pre = PLANKS + '/textures/raw_plank_wall_'
c = load(pre + 'diff_1k.jpg')
ex = cv2.imread(pre + 'nor_gl_1k.exr', cv2.IMREAD_UNCHANGED)
if ex is not None:
    n = img(np.clip(cv2.cvtColor(ex[..., :3], cv2.COLOR_BGR2RGB), 0, 1)).resize((S, S), Image.LANCZOS)
else:
    d = np.asarray(Image.open(pre + 'disp_1k.png').convert('F').resize((S, S), Image.LANCZOS), dtype=np.float32)
    n = normal_from_height(d / max(d.max(), 1.0), 6.0)
rx = cv2.imread(pre + 'rough_1k.exr', cv2.IMREAD_UNCHANGED)
if rx is not None:
    r = img(np.clip(rx if rx.ndim == 2 else rx[..., 0], 0, 1)).resize((S, S), Image.LANCZOS).convert('L')
else:
    r = Image.new('L', (S, S), 200)
save_set(GROUND + 'plank_wall_', norm_mean(c, 0.42, 0.85), n, r)
print('ok')
