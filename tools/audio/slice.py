## Schneidet lange Schritt-Aufnahmen in einzelne Schritte.
import sys, os, glob, subprocess, numpy as np
from scipy.signal import find_peaks, butter, sosfilt
sys.path.insert(0, os.path.dirname(__file__)); from analyze import load, SR
SRC, OUT = sys.argv[1], sys.argv[2]
KEEP = int(sys.argv[3]) if len(sys.argv) > 3 else 12
SURF = {"carpet": "carpet", "forest floor": "forest", "grass": "grass", "wooden floor": "wood", "wooden porch": "porch"}
HOP = 240
hp = butter(4, 70, "highpass", fs=SR, output="sos")

def gait_of(n):
    return "run" if "running" in n else ("sneak" if "slowly" in n else "walk")
def surf_of(n):
    for k, v in SURF.items():
        if k in n: return v

def period(db):
    e = db - np.median(db); e = np.clip(e, 0, None)
    ac = np.correlate(e, e, "full")[len(e)-1:]
    lo, hi = int(0.2*SR/HOP), int(0.95*SR/HOP)
    return (lo + np.argmax(ac[lo:hi])) * HOP / SR

groups = {}
for p in sorted(glob.glob(SRC + "/*.mp3")):
    n = os.path.basename(p)
    x = sosfilt(hp, load(p)).astype(np.float32)
    m = len(x)//HOP
    env = np.sqrt(np.mean(x[:m*HOP].reshape(m, HOP)**2, axis=1))
    db = 20*np.log10(env + 1e-6)
    sm = np.convolve(db, np.ones(3)/3, "same")
    per = period(sm)
    pk, props = find_peaks(sm, distance=max(1, int(0.7*per*SR/HOP)), prominence=6)
    segs = []
    for i, k in enumerate(pk):
        # Anfang: rückwärts bis die Lautstärke nahe am Grundrauschen ist (max. 80 ms)
        floor = np.percentile(sm[max(0, k-60):k+1], 15)
        j = k
        while j > 0 and k-j < int(0.08*SR/HOP) and sm[j-1] > floor + 4: j -= 1
        start = max(0, j*HOP - int(0.012*SR))
        start = max(start, k*HOP - int(0.045*SR))
        nxt = pk[i+1]*HOP - int(0.06*SR) if i+1 < len(pk) else len(x)
        length = min(int(min(0.85*per, 0.6)*SR), nxt - start)
        # Ende vor einem zweiten Aufsetzen: steigt die Lautstärke nach dem Abklingen wieder deutlich an
        s0, e0 = start//HOP, (start+length)//HOP
        lo = sm[k]; lo_i = k
        for t in range(k + int(0.07*SR/HOP), min(e0, len(sm))):
            if sm[t] < lo: lo, lo_i = sm[t], t
            if sm[t] > lo + 7 and sm[t] > sm[k] - 14:
                length = min(length, lo_i*HOP - start); break
        if length < int(0.12*SR) or start + length > len(x) or start < int(0.05*SR): continue
        seg = x[start:start+length].copy()
        pre = x[max(0, start-int(0.05*SR)):start]
        snr = 20*np.log10((np.abs(seg).max()+1e-6)/(np.sqrt(np.mean(pre**2))+1e-6))
        segs.append((snr, props["prominences"][i], seg, n))
    key = (surf_of(n), gait_of(n))
    groups.setdefault(key, []).extend(segs)
    print(f"{n[:50]:50s} periode={per:.2f}s schritte={len(segs)}")

for (surf, gait), segs in sorted(groups.items()):
    # die saubersten Schritte, möglichst aus allen Aufnahmen gemischt
    segs.sort(key=lambda s: -(s[0] + 0.5*s[1]))
    chosen, per_file = [], {}
    for s in segs:
        if per_file.get(s[3], 0) >= (KEEP+3)//4 + 1: continue
        chosen.append(s); per_file[s[3]] = per_file.get(s[3], 0) + 1
        if len(chosen) >= KEEP: break
    d = os.path.join(OUT, surf); os.makedirs(d, exist_ok=True)
    for f in glob.glob(os.path.join(d, gait + "_*.ogg")): os.remove(f)
    for idx, (snr, prom, seg, n) in enumerate(chosen):
        fi = int(0.004*SR); fo = int(min(0.08, len(seg)/SR*0.35)*SR)
        seg[:fi] *= np.linspace(0, 1, fi); seg[-fo:] *= np.linspace(1, 0, fo)**2
        # gleiche Lautheit für alle (Lautstärke-Unterschiede regelt das Spiel)
        mm = len(seg)//HOP
        e = np.sqrt(np.mean(seg[:mm*HOP].reshape(mm, HOP)**2, axis=1))
        seg *= 0.22 / (e.max() + 1e-6)
        seg = np.clip(seg, -0.98, 0.98).astype(np.float32)
        path = os.path.join(d, f"{gait}_{idx+1:02d}.ogg")
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "f32le", "-ar", str(SR), "-ac", "1", "-i", "-",
                        "-ar", "44100", "-c:a", "libvorbis", "-q:a", "4", path], input=seg.tobytes(), check=True)
    print(f"{surf:7s} {gait:5s}: {len(chosen)} von {len(segs)} (snr {chosen[-1][0]:.0f}..{chosen[0][0]:.0f} dB)")
