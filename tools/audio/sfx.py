## Bereitet Christians Geräusch-Aufnahmen für SoundBank auf (assets/audio/sfx/<id>_NN.ogg).
## Aufruf: python3 sfx.py QUELLORDNER
## Die Zuordnung Dateiname -> Geräusch steht unten in MAP. Modi:
##   one:  kurzer Laut – Stille vorn/hinten weg, gleich laut
##   loop: Klangfläche – Anfang und Ende überblendet, damit sie nahtlos wiederholt
##   clip: nur die ersten N Sekunden, sanft ausgeblendet
import sys, os, glob, subprocess, numpy as np
from scipy.signal import butter, sosfilt
sys.path.insert(0, os.path.dirname(__file__)); from analyze import load, SR

HOP = 240
OUT = os.path.join(os.path.dirname(__file__), "../../assets/audio/sfx")
# (Dateimuster, Geräusch-ID, Modus, Zusatz)
MAP = [
    ("House knocking *", "knock", "one", None),
    ("House glass breaking *", "glass_break", "one", None),
    ("House wooden plank shatters *", "plank_break", "one", None),
    ("House break open door *", "door_break", "one", None),
    ("House opening door *", "door_open", "one", None),
    ("House closing door *", "door_close", "one", None),
    ("House locking door *", "door_lock", "one", None),
    ("House Jiggling doorknob *", "rattle", "one", None),
    ("House Picture falling *", "picture_fall", "one", None),
    ("House active faucet *", "faucet", "clip", 3.0),
    ("House dripping faucet *", "drip", "loop", None),
    ("House creaking floorboard *", "floor_creak", "one", None),
    ("House ceiling light *", "light_buzz", "one", None),
    ("House dull footsteps on the roof *", "roof_steps", "one", None),
    ("House radio *", "radio", "loop", None),
    ("House running generator*", "generator", "loop", None),
    ("House sound of music box *", "music_box", "one", None),
    ("House surring monitor *", "monitor_hum", "loop", None),
    ("House switching camera *", "camera_switch", "click", 0.6),  # Hauptgeräusch erst nach 1,4 s – ab dort
    ("House light switch *", "light_switch", "click", None),  # Vorgeräusch weg, ab dem Klick
    ("House Campfire*", "fire", "loop", None),
    ("Ambient cracking branch *", "twig", "one", None),
    ("Ambient howling owl *", "owl", "one", None),
    ("Ambient birds singing *", "birds", "loop", None),
    ("Ambient c*rickets chirping *", "crickets", "loop", None),
    ("Ambient croaking frogs *", "frogs", "loop", None),
    ("Ambient babbling brook *", "brook", "loop", None),
    ("Ambient wind blowing*", "wind", "loop", None),
    ("Ambient heavy gusts of wind *", "gusts", "loop", None),
    ("Ambient opressive silence *", "silence", "loop", None),
    ("Build chopping wood *", "chop", "clip", 0.45),  # Aufnahme hat 3 Hiebe – nur der erste
    ("Build clattering cans *", "clatter", "one", None),
    ("Build collecting metal *", "collect_metal", "one", None),
    ("Build collecting stone *", "collect_stone", "one", None),
    ("Build picking something up *", "pickup", "one", None),
    ("Build placing somthing on ground *", "place", "one", None),
    ("Build working on a work bench *", "workbench", "one", None),
    ("Build fence breaks down *", "fence_break", "one", None),
    ("Build motion detector clicks *", "motion_click", "one", None),
    ("Menu klick*", "menu_click", "one", None),
    ("Menu opening backpack *", "backpack", "one", None),
    ("Scare creature appears *", "sting_creature", "one", None),
    ("Scare sound of dawn *", "sting_dawn", "one", None),
    ("Scare sound of dusk *", "sting_dusk", "one", None),
]

hp = butter(4, 40, "highpass", fs=SR, output="sos")


def env_db(y):
    m = len(y) // HOP
    e = np.sqrt(np.mean(y[:m * HOP].reshape(m, HOP) ** 2, axis=1))
    return e, 20 * np.log10(e + 1e-7)


def write(y, out):
    pk = np.abs(y).max()
    if pk > 0.97:
        y = y * 0.97 / pk
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "f32le", "-ar", str(SR), "-ac", "1", "-i", "-",
                    "-ar", "44100", "-c:a", "libvorbis", "-q:a", "4", out], input=y.astype(np.float32).tobytes(), check=True)


def one(x):
    e, db = env_db(x)
    on = np.where(db > db.max() - 40)[0]
    a = max(0, on[0] * HOP - int(0.01 * SR)); b = min(len(x), (on[-1] + 1) * HOP + int(0.08 * SR))
    y = x[a:b].copy()
    fi, fo = int(0.004 * SR), int(min(0.15, len(y) / SR * 0.2) * SR)
    y[:fi] *= np.linspace(0, 1, fi); y[-fo:] *= np.linspace(1, 0, fo) ** 2
    e, _ = env_db(y)
    return y * 0.3 / (np.percentile(e, 98) + 1e-6)


def loop(x):
    xf = int(1.5 * SR)
    body = x[:len(x) - xf].copy()
    tail = x[len(x) - xf:]
    t = np.linspace(0, np.pi / 2, xf)
    # Ende gleichmäßig in den Anfang überblenden
    body[:xf] = body[:xf] * np.sin(t) + tail * np.cos(t)
    e, _ = env_db(body)
    return body * 0.12 / (np.sqrt(np.mean(e ** 2)) + 1e-6)


def click(x, secs=None):
    # nur der eigentliche Klick: ab dem lautesten Einsatz, kurz
    e = np.sqrt(np.convolve(x ** 2, np.ones(120) / 120, "same"))
    i = int(np.argmax(e > e.max() * 0.3))
    a = max(0, i - int(0.008 * SR))
    y = x[a:a + int((secs or 0.35) * SR)].copy()
    fo = int(0.08 * SR)
    y[-fo:] *= np.linspace(1, 0, fo) ** 2
    return y * 0.5 / (np.abs(y).max() + 1e-6)


def clip(x, secs):
    y = one(x)[:int(secs * SR)].copy()
    fo = int(min(0.5, secs * 0.3) * SR)
    y[-fo:] *= np.linspace(1, 0, fo) ** 2
    return y


src = sys.argv[1]
os.makedirs(OUT, exist_ok=True)
for pattern, sid, mode, extra in MAP:
    files = sorted(glob.glob(os.path.join(src, pattern + ".mp3")) + glob.glob(os.path.join(src, pattern.rstrip("*").rstrip() + ".mp3")))
    files = sorted(set(files))
    if not files:
        print("FEHLT:", pattern)
        continue
    for i, f in enumerate(files):
        x = sosfilt(hp, load(f)).astype(np.float32)
        y = one(x) if mode == "one" else loop(x) if mode == "loop" else click(x, extra) if mode == "click" else clip(x, extra)
        out = os.path.join(OUT, f"{sid}_{i + 1:02d}.ogg")
        write(y, out)
        print(f"{os.path.basename(f)[:44]:44s} -> {sid}_{i + 1:02d}  {len(y) / SR:5.2f}s  {mode}")
