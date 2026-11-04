## Entfernt Brummen und gleichmäßiges Hintergrundrauschen aus einer Aufnahme.
## 1) Hochpass (tiefes Brummen weg), 2) Kerbfilter auf Brummtöne (gefundene Spitzen + Obertöne),
## 3) Rausch-Abzug: Rauschprofil aus den leisesten Stellen, dann pro Frequenz abziehen (weich).
## Aufruf: python3 denoise.py EINGANG AUSGANG [staerke=1.5] [hochpass_hz=150]
import sys, os, subprocess, numpy as np
from scipy.signal import butter, sosfiltfilt, iirnotch, filtfilt, welch, find_peaks, stft, istft
sys.path.insert(0, os.path.dirname(__file__)); from analyze import load, SR
src, dst = sys.argv[1], sys.argv[2]
strength = float(sys.argv[3]) if len(sys.argv) > 3 else 1.5
x = load(src).astype(np.float64)
HP = float(sys.argv[4]) if len(sys.argv) > 4 else 150.0
x = sosfiltfilt(butter(6, HP, "highpass", fs=SR, output="sos"), x)
fr, p = welch(x, SR, nperseg=16384)
db = 10 * np.log10(p + 1e-20)
base = np.convolve(db, np.ones(41) / 41, "same")
pk, _ = find_peaks(db - base, height=8)
hums = [fr[k] for k in pk if 50 < fr[k] < 2000]
for h in hums:
    for mult in (1, 2, 3):
        if h * mult < SR / 2 - 100:
            b, a = iirnotch(h * mult, 25, SR)
            x = filtfilt(b, a, x)
f, t, Z = stft(x, SR, nperseg=2048)
mag = np.abs(Z)
frame_e = mag.mean(axis=0)
quiet = frame_e <= np.percentile(frame_e, 15)
noise = np.median(mag[:, quiet], axis=1, keepdims=True)
gain = np.clip(1.0 - strength * noise / (mag + 1e-12), 0.08, 1.0)
# Verstärkung über Zeit glätten, damit es nicht "zwitschert"
k = np.ones(5) / 5
gain = np.apply_along_axis(lambda g: np.convolve(g, k, "same"), 1, gain)
_, y = istft(Z * gain, SR, nperseg=2048)
y = y[:len(x)].astype(np.float32)
y *= 0.9 / (np.abs(y).max() + 1e-9)
subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "f32le", "-ar", str(SR), "-ac", "1", "-i", "-", "-b:a", "192k", dst],
               input=y.tobytes(), check=True)
print(os.path.basename(src), "Brummtöne:", [round(h) for h in hums])
