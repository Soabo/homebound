# Foto-Texturen für Möbel (Christian 26.11., Poly Haven, CC0): Stühle/Bänke, Tische/Werkbank, Schrank/Truhe, Kinderzimmer.
# Aufruf: python3 -I tools/textures_prep3.py PROJEKT QUELLORDNER   (QUELLORDNER enthält die entpackten Zip-Ordner)
import os, sys
os.environ["OPENCV_IO_ENABLE_OPENEXR"] = "1"
import numpy as np, cv2
from PIL import Image

PROJ, SRC = sys.argv[1:3]
OUT = PROJ + '/assets/textures/ground/'
S = 1024
SETS = {
    # Name im Spiel: (Ordner, Dateianfang, Farb-Endung, Zielhelligkeit, Sättigung)
    "furn_fine": ("St_hle_Schaukelstuhl_B_nke", "fine_grained_wood", "col", 0.5, 0.95),
    "furn_table": ("Werkbank_Esstisch_Funktisch", "wood_table_worn", "diff", 0.42, 0.95),
    "furn_cabinet": ("Schrank_Truhe_Kommode", "wood_cabinet_worn_long", "diff", 0.4, 0.9),
    "furn_painted": ("Kinderzimmer", "weathered_brown_planks", "diff", 0.4, 0.95),
}


def luma(a):
    return a[..., 0] * 0.3 + a[..., 1] * 0.59 + a[..., 2] * 0.11


def normal_from_height(h, strength):
    gx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * strength
    gy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * strength
    n = np.dstack([-gx, gy, np.ones_like(h)])
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    return Image.fromarray(((n * 0.5 + 0.5) * 255).astype(np.uint8))


for name, (folder, base, col, target, sat) in SETS.items():
    t = os.path.join(SRC, folder, 'textures', base + '_')
    c = np.asarray(Image.open(t + col + '_1k.jpg').convert('RGB').resize((S, S), Image.LANCZOS), dtype=np.float32) / 255
    g = luma(c)[..., None]
    c = g + (c - g) * sat
    c = np.clip(c * (target / c.mean()), 0, 1)
    Image.fromarray((c * 255).astype(np.uint8)).save(OUT + name + '_color.jpg', quality=90)
    # Normale: aus der EXR-Datei, sonst aus der Höhenkarte, sonst aus der Farbe
    ex = cv2.imread(t + 'nor_gl_1k.exr', cv2.IMREAD_UNCHANGED)
    if ex is not None:
        n = Image.fromarray((np.clip(cv2.cvtColor(ex[..., :3], cv2.COLOR_BGR2RGB), 0, 1) * 255).astype(np.uint8)).resize((S, S), Image.LANCZOS)
    elif os.path.exists(t + 'disp_1k.png'):
        d = np.asarray(Image.open(t + 'disp_1k.png').convert('F').resize((S, S), Image.LANCZOS), dtype=np.float32)
        n = normal_from_height(d / max(d.max(), 1.0), 5.0)
    else:
        n = normal_from_height(cv2.GaussianBlur(luma(c), (0, 0), 1.0), 3.0)
    n.save(OUT + name + '_normal.jpg', quality=92)
    r = None
    if os.path.exists(t + 'rough_1k.jpg'):
        r = Image.open(t + 'rough_1k.jpg').convert('L').resize((S, S), Image.LANCZOS)
    else:
        rx = cv2.imread(t + 'rough_1k.exr', cv2.IMREAD_UNCHANGED)
        if rx is not None:
            rr = rx if rx.ndim == 2 else rx[..., 0]
            r = Image.fromarray((np.clip(rr, 0, 1) * 255).astype(np.uint8)).resize((S, S), Image.LANCZOS)
    if r is None:
        r = Image.fromarray(((0.65 + (1 - luma(c)) * 0.25) * 255).astype(np.uint8))
    r.save(OUT + name + '_rough.jpg', quality=90)
    print(name, 'ok', 'normal exr' if ex is not None else 'normal berechnet')
