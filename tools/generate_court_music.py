"""Original COURT RUSH instrumental loops; no samples or network requests.

Requires numpy and soundfile. 24 kHz stereo Vorbis keeps the mobile bundle small.
Every arrangement is exactly 16 bars with wrapped tails for a clean loop seam.
"""
from pathlib import Path
import hashlib
import json
import numpy as np
import soundfile as sf

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/audio/music"
RATE = 24000


def render(name, bpm, roots, style, seed):
    rng = np.random.default_rng(seed)
    beat = 60 / bpm
    length = round(64 * beat * RATE)
    mix = np.zeros((length, 2), np.float32)

    def add(start, samples, gain=1, pan=0):
        indices = (round(start * RATE) + np.arange(len(samples))) % length
        mix[indices, 0] += samples * gain * np.sqrt((1 - pan) / 2)
        mix[indices, 1] += samples * gain * np.sqrt((1 + pan) / 2)

    def note(midi, duration, kind):
        t = np.arange(round(duration * RATE)) / RATE
        f = 440 * 2 ** ((midi - 69) / 12)
        if kind == 'bass':
            s = np.sin(2*np.pi*f*t) + .23*np.sin(4*np.pi*f*t)
            env = (1-np.exp(-t*180))*np.exp(-t*3.8)
        elif kind == 'keys':
            s = np.sin(2*np.pi*f*t+1.6*np.sin(2*np.pi*f*2*t)*np.exp(-t*5))
            s += .16*np.sin(2*np.pi*f*3*t)*np.exp(-t*5)
            env = (1-np.exp(-t*350))*np.exp(-t*2.4)
        elif kind == 'pluck':
            s = np.sin(2*np.pi*f*t)+.28*np.sin(4*np.pi*f*t)+.09*np.sin(6*np.pi*f*t)
            env = (1-np.exp(-t*600))*np.exp(-t*8)
        else:
            s = np.sin(2*np.pi*f*t)+.13*np.sin(2*np.pi*f*1.003*t)
            env = np.sin(np.pi*np.minimum(t/duration,1))**1.5*.65
        return s * env * np.minimum((duration-t)*100, 1)

    for bar in range(16):
        root = roots[(bar // 2) % len(roots)]
        # A/B phrases and a small fill at every fourth bar.
        kicks = [0, 1.75, 2.5] if style == 'boom' else ([0, .75, 2, 2.75] if style == 'funk' else [0, 1, 2, 3])
        for pos in kicks:
            t = np.arange(int(.32*RATE))/RATE
            kick = np.sin(2*np.pi*(47*t+7*(1-np.exp(-t*28))))*np.exp(-t*17)
            add((bar*4+pos)*beat, kick, .34)
        for pos in [1, 3]:
            t = np.arange(int(.19*RATE))/RATE
            noise = rng.standard_normal(len(t))
            snap = np.r_[0, np.diff(noise)]*.35+np.sin(2*np.pi*182*t)*.32
            add((bar*4+pos)*beat+.009, snap*np.exp(-t*24), .15, -.1)
        for eighth in range(8):
            t = np.arange(int((.14 if eighth==7 else .055)*RATE))/RATE
            hat = np.r_[0,np.diff(rng.standard_normal(len(t)))]*np.exp(-t*(42 if eighth==7 else 95))
            swing = .065*beat if style != 'night' and eighth%2 else 0
            add((bar*4+eighth*.5)*beat+swing, hat, .034 if eighth%2 else .044, .32)
        if bar%4==3:
            for j in range(3):
                t=np.arange(int(.05*RATE))/RATE
                add((bar*4+3.25+j*.25)*beat,rng.standard_normal(len(t))*np.exp(-t*80),.035,-.25)
        bass_pattern = [(0,0),(1.5,0),(2.5,7),(3.5,10)] if style=='funk' else [(0,0),(1.75,0),(2.5,7)]
        for pos, offset in bass_pattern:
            add((bar*4+pos)*beat,note(root+offset,.65*beat,'bass'),.22)
        intervals = [0,3,7,10] if style!='funk' else [0,4,7,10]
        for pos in ([.5,2.5] if style=='funk' else [0,2.75]):
            chord = sum(note(root+24+i,1.7*beat,'keys') for i in intervals)
            add((bar*4+pos)*beat,chord,.058,-.25)
        melody = ([12,15,19,17,15,10,12,7] if style=='boom' else
                  [12,16,19,21,19,16,14,12] if style=='funk' else [19,15,12,10,12,15,22,19])
        if bar%4 in [0,1,3]:
            for j in range(4):
                add((bar*4+j+.5)*beat,note(root+24+melody[(bar*2+j)%8],.6*beat,'pluck'),.075,.22)
        if style=='night':
            for i in [0,7,10]:add(bar*4*beat,note(root+24+i,4*beat,'pad'),.042,.1)
    # A quiet stereo delay; use circular wrap rather than silence at the seam.
    dry=mix.copy()
    mix += np.roll(dry[:,::-1],round(beat*.75*RATE),axis=0)*.16
    mix = np.tanh(mix*1.5)
    mix *= .78/max(float(np.max(np.abs(mix))),.001)
    path=OUT/f'{name}.ogg'
    # libsndfile's Windows Vorbis encoder needs bounded writes (large writes
    # can exhaust its C stack); chunking also limits transient memory.
    with sf.SoundFile(path,'w',samplerate=RATE,channels=2,format='OGG',subtype='VORBIS') as output:
        for start in range(0,len(mix),4096):output.write(mix[start:start+4096])
    return dict(file=path.name,bpm=bpm,bars=16,duration=length/RATE,seed=seed,
                sha256=hashlib.sha256(path.read_bytes()).hexdigest(),peak=float(np.max(np.abs(mix))))


if __name__=='__main__':
    OUT.mkdir(parents=True,exist_ok=True)
    tracks=[render('asphalt-groove',94,[33,38,36,40],'boom',7301),
            render('fast-break',110,[29,34,31,36],'funk',7302),
            render('neon-court',122,[30,35,33,37],'night',7303)]
    (OUT/'manifest.json').write_text(json.dumps({'author':'Roky Studio / COURT RUSH procedural score','sampleRate':RATE,'tracks':tracks},indent=2)+'\n',encoding='utf8')
    for track in tracks: print(track['file'],round(track['duration'],2),'seconds')
