# Erzeugte Foto-Materialien für die Orte (27.11.): Kalkputz, Wellblech, Beton, Holzschindeln, Rost, Kies.
# Schindeln nehmen echte Holzmaserung aus den Möbel-Fotos (CC0), Kies kommt aus dem Bodenstapel, der Rest ist
# berechnetes Rauschen. Alle kachelbar, 1024 px, je Farbe/Normal/Rauheit.
# Aufruf: python3 -I tools/textures_gen.py PROJEKT
import sys
import numpy as np
from PIL import Image

PROJ = sys.argv[1]
OUT = PROJ + '/assets/textures/ground/'
S = 1024
rng = np.random.default_rng(1127)


def noise(octaves, base=4, persist=0.55, seed=0):
    """Kachelbares Wertrauschen (Summe weicher Gitter)."""
    r = np.random.default_rng(seed)
    out = np.zeros((S, S), np.float32)
    amp, tot = 1.0, 0.0
    for o in range(octaves):
        n = base * 2 ** o
        g = r.random((n, n)).astype(np.float32)
        im = Image.fromarray((g * 255).astype(np.uint8)).resize((S, S), Image.BICUBIC)
        # kachelbar: Gitter wiederholen, dann mittleres Stück nehmen
        big = np.tile(g, (3, 3))
        im = Image.fromarray((big * 255).astype(np.uint8)).resize((S * 3, S * 3), Image.BICUBIC)
        a = np.asarray(im, np.float32)[S:2 * S, S:2 * S] / 255.0
        out += a * amp
        tot += amp
        amp *= persist
    return out / tot


def normal_from_height(h, strength):
    gx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * strength
    gy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * strength
    n = np.dstack([-gx, gy, np.ones_like(h)])
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    return Image.fromarray(((n * 0.5 + 0.5) * 255).astype(np.uint8))


def save(name, color, height, nstrength, rough):
    Image.fromarray((np.clip(color, 0, 1) * 255).astype(np.uint8)).save(OUT + name + '_color.jpg', quality=90)
    normal_from_height(height, nstrength).save(OUT + name + '_normal.jpg', quality=92)
    Image.fromarray((np.clip(rough, 0, 1) * 255).astype(np.uint8)).save(OUT + name + '_rough.jpg', quality=90)
    print(name, 'mittel', color.mean(axis=(0, 1)))


# --- Kalkputz (weiß gekalkt, leicht fleckig, feine Risse) -------------------------------------
n1 = noise(7, 3, 0.6, 1)
n2 = noise(5, 16, 0.5, 2)
cracks = np.abs(noise(6, 6, 0.5, 3) - 0.5) < 0.0025
h = n1 * 0.6 + n2 * 0.4
h[cracks] -= 0.12
base = np.array([0.90, 0.88, 0.82], np.float32)
stain = np.array([0.72, 0.68, 0.58], np.float32)
t = np.clip((n1 - 0.55) * 3.0, 0, 1)[..., None]
col = base * (1 - t) + stain * t
col *= (0.92 + n2[..., None] * 0.12)
col[cracks] *= 0.9
save('plaster', col, h, 6.0, 0.85 + n2 * 0.1)

# --- Wellblech (grau-grün lackiert, Kratzer und Rost an den Kanten) --------------------------
x = np.linspace(0, 1, S, endpoint=False)
wave = (np.sin(x * np.pi * 2 * 12) * 0.5 + 0.5)[None, :].repeat(S, 0)   # 12 Wellen je Kachel (Kachel ≈ 0,9 m)
rn = noise(6, 4, 0.6, 4)
rust_t = np.clip((rn - 0.7) * 4.0, 0, 1)
streak = noise(4, 2, 0.5, 5)
streak = np.clip((np.repeat(streak[:, ::8], 8, 1)[:, :S] - 0.5) * 2, 0, 1)   # Laufspuren senkrecht
paint = np.array([0.42, 0.47, 0.42], np.float32)
rust = np.array([0.42, 0.22, 0.1], np.float32)
col = paint * (0.85 + wave[..., None] * 0.2)
t = np.clip(rust_t * 0.8 + streak * 0.12 * rn, 0, 1)[..., None]
col = col * (1 - t) + rust * t * (0.8 + rn[..., None] * 0.4)
save('corrugated', col, wave * 1.0 + rn * 0.05, 40.0, 0.55 + t[..., 0] * 0.4)

# --- Beton (grau, Schalungsporen, Flecken) -----------------------------------------------------
c1 = noise(7, 4, 0.55, 6)
pores = noise(2, 128, 0.5, 7) < 0.12
h = c1 * 0.5
h[pores] -= 0.3
col = np.array([0.6, 0.6, 0.58], np.float32) * (0.82 + c1[..., None] * 0.3)
col[pores] *= 0.8
save('concrete', col, h, 4.0, 0.9 + c1 * 0.08)

# --- Rost (stark verrostetes Blech) ----------------------------------------------------------
r1 = noise(7, 4, 0.6, 8)
r2 = noise(5, 24, 0.5, 9)
col = np.array([0.38, 0.2, 0.09], np.float32) * (0.7 + r1[..., None] * 0.6)
dark = np.clip((r2 - 0.6) * 4, 0, 1)[..., None]
col = col * (1 - dark * 0.5)
save('rust', col, r1 * 0.5 + r2 * 0.5, 8.0, 0.8 + r2 * 0.15)

# --- Holzschindeln (versetzte Reihen, vergraut) aus echter Maserung -----------------------------
wood = np.asarray(Image.open(OUT + 'furn_fine_color.jpg').convert('RGB'), np.float32) / 255
wood = np.rot90(wood)   # Maserung senkrecht
rows = 8                # Reihen je Kachel
rh = S // rows
col = np.zeros((S, S, 3), np.float32)
h = np.zeros((S, S), np.float32)
r = np.random.default_rng(10)
for ri in range(rows):
    y0 = ri * rh
    off = (rh // 2) * (ri % 2) + r.integers(0, 30)
    x = -off
    while x < S:
        w = int(r.integers(70, 150))
        sx, sy = int(r.integers(0, S - w)), int(r.integers(0, S - rh))
        piece = wood[sy:sy + rh, sx:sx + w]
        grey = piece.mean(axis=2, keepdims=True)
        piece = grey * 0.65 + piece * 0.35                 # vergraut
        piece = piece * r.uniform(0.75, 1.1)
        grad = np.linspace(1.0, 0.55, rh)[:, None, None]  # oben im Schatten der darüberliegenden Reihe
        piece = piece * grad
        hh = np.linspace(0.2, 1.0, rh)[:, None].repeat(w, 1)
        for xx in range(w):
            X = (x + xx) % S
            col[y0:y0 + rh, X] = piece[:, xx]
            h[y0:y0 + rh, X] = hh[:, xx]
        # Fuge
        for g in range(3):
            X = (x + w - 1 - g) % S
            col[y0:y0 + rh, X] *= 0.35
            h[y0:y0 + rh, X] = 0.0
        x += w
col = col * np.array([0.95, 0.93, 0.9], np.float32)
save('shingles_wood', col, h, 10.0, 0.88 + noise(4, 8, 0.5, 11) * 0.1)

# --- Kies (aus dem Bodenstapel, Lage 4) ----------------------------------------------------
arr = np.asarray(Image.open(OUT + 'ground_color_array.jpg').convert('RGB'), np.float32) / 255
nrm = Image.open(OUT + 'ground_normal_array.jpg').convert('RGB')
g = arr[4 * S:5 * S] * 0.62
Image.fromarray((np.clip(g, 0, 1) * 255).astype(np.uint8)).save(OUT + 'gravel_color.jpg', quality=90)
nrm.crop((0, 4 * S, S, 5 * S)).save(OUT + 'gravel_normal.jpg', quality=92)
Image.fromarray(np.full((S, S), 230, np.uint8)).save(OUT + 'gravel_rough.jpg', quality=90)
print('gravel', g.mean(axis=(0, 1)))

# --- Bretterwand senkrecht (plank_wall um 90° gedreht, Normalen mitgedreht) -----------------------
c = np.asarray(Image.open(OUT + 'plank_wall_color.jpg').convert('RGB'))
n = np.asarray(Image.open(OUT + 'plank_wall_normal.jpg').convert('RGB'), np.float32) / 127.5 - 1.0
ro = np.asarray(Image.open(OUT + 'plank_wall_rough.jpg').convert('L'))
c2 = np.rot90(c)
n2 = np.rot90(n).copy()
nx, ny = n2[..., 0].copy(), n2[..., 1].copy()
n2[..., 0], n2[..., 1] = -ny, nx      # Drehung gegen den Uhrzeigersinn: (x, y) → (−y, x)
Image.fromarray(np.ascontiguousarray(c2)).save(OUT + 'plank_wall_v_color.jpg', quality=90)
Image.fromarray(((n2 * 0.5 + 0.5) * 255).clip(0, 255).astype(np.uint8)).save(OUT + 'plank_wall_v_normal.jpg', quality=92)
Image.fromarray(np.ascontiguousarray(np.rot90(ro))).save(OUT + 'plank_wall_v_rough.jpg', quality=90)
print('plank_wall_v')

# --- Maschendraht (Rauten aus Draht, Rest durchsichtig) – für Zäune -------------------------------
N = 512
yy, xx = np.mgrid[0:N, 0:N].astype(np.float32)
cells = 6                                  # Rauten je Kachel
u = (xx + yy) / N * cells
v = (xx - yy) / N * cells
du = np.abs(u - np.round(u))
dv = np.abs(v - np.round(v))
wire_w = 0.045
a = np.clip(1.0 - np.minimum(du, dv) / wire_w, 0, 1)
a = (a > 0.35).astype(np.float32)
shade = 0.55 + 0.35 * np.clip(1.0 - np.minimum(du, dv) / wire_w, 0, 1)
rgba = np.dstack([shade * 0.62, shade * 0.64, shade * 0.66, a])
Image.fromarray((rgba * 255).astype(np.uint8), 'RGBA').save(OUT + 'chainlink.png')
print('chainlink')
