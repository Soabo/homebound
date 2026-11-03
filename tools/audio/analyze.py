import subprocess, sys, numpy as np, glob, os, re
SR=48000
def load(p):
    raw=subprocess.run(["ffmpeg","-v","error","-i",p,"-ac","1","-ar",str(SR),"-f","f32le","-"],capture_output=True).stdout
    return np.frombuffer(raw,dtype=np.float32).copy()
def onsets(x, min_gap):
    hop=240  # 5 ms
    n=len(x)//hop
    env=np.sqrt(np.mean(x[:n*hop].reshape(n,hop)**2,axis=1))
    # Anstieg der Hüllkurve
    db=20*np.log10(env+1e-6)
    floor=np.percentile(db,20); peak=np.percentile(db,99)
    thr=floor+0.45*(peak-floor)
    res=[]; last=-1e9
    for i in range(1,n):
        if db[i]>=thr and db[i-1]<thr and (i-last)*hop/SR>=min_gap:
            # Rückwärts bis zum Beginn des Anstiegs
            j=i
            while j>0 and db[j-1]<db[j] and db[j-1]>floor+0.15*(peak-floor): j-=1
            res.append(j*hop); last=i
    return res, env, floor, peak
if __name__=="__main__":
    d=sys.argv[1]
    for p in sorted(glob.glob(d+"/*.mp3")):
        x=load(p); gap=0.22 if "running" in p else 0.35
        o,env,f,pk=onsets(x,gap)
        iv=np.diff(o)/SR if len(o)>1 else []
        print(f"{os.path.basename(p)[:48]:48s} len={len(x)/SR:5.1f}s steps={len(o):3d} median_iv={np.median(iv) if len(iv) else 0:.2f} peak={pk:.0f} floor={f:.0f} maxamp={np.abs(x).max():.2f}")
