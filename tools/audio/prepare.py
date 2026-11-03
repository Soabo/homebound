## Bereitet Einzel-Geräusche und lange Klangflächen auf (Stille abschneiden, gleich laut, mono OGG).
## Aufruf: python3 prepare.py oneshot|long ZIELPRAEFIX DATEI...
##   oneshot: kurze Laute (Schrei, Schmerz) – Anfang/Ende knapp beschnitten
##   long:    Atmen/Klicken – bleibt lang, das Spiel spielt zufällige Ausschnitte daraus
import sys, os, subprocess, numpy as np
from scipy.signal import butter, sosfilt
sys.path.insert(0, os.path.dirname(__file__)); from analyze import load, SR
HOP = 240
mode, prefix, files = sys.argv[1], sys.argv[2], sys.argv[3:]
hp = butter(4, 50, "highpass", fs=SR, output="sos")
os.makedirs(os.path.dirname(prefix), exist_ok=True)
for i, f in enumerate(sorted(files)):
    x = sosfilt(hp, load(f)).astype(np.float32)
    m = len(x)//HOP
    db = 20*np.log10(np.sqrt(np.mean(x[:m*HOP].reshape(m, HOP)**2, axis=1)) + 1e-6)
    top = db.max()
    on = np.where(db > top - (40 if mode == "oneshot" else 45))[0]
    a = max(0, on[0]*HOP - int(0.01*SR)); b = min(len(x), (on[-1]+1)*HOP + int(0.05*SR))
    y = x[a:b].copy()
    fi, fo = int(0.005*SR), int(min(0.12, len(y)/SR*0.2)*SR)
    y[:fi] *= np.linspace(0, 1, fi); y[-fo:] *= np.linspace(1, 0, fo)**2
    mm = len(y)//HOP
    e = np.sqrt(np.mean(y[:mm*HOP].reshape(mm, HOP)**2, axis=1))
    ref = e.max() if mode == "oneshot" else np.percentile(e, 95)
    y *= (0.3 if mode == "oneshot" else 0.22) / (ref + 1e-6)
    pk = np.abs(y).max()
    if pk > 0.97: y *= 0.97 / pk
    out = f"{prefix}_{i+1:02d}.ogg"
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "f32le", "-ar", str(SR), "-ac", "1", "-i", "-",
                    "-ar", "44100", "-c:a", "libvorbis", "-q:a", "4", out], input=y.astype(np.float32).tobytes(), check=True)
    print(f"{os.path.basename(f):40s} -> {out}  {len(y)/SR:.2f}s")
