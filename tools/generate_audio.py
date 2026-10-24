"""Original procedural court effects. No external recordings or packages."""
import math
import random
import struct
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RATE = 22050
rng = random.Random(71)

def write(name, duration, sample):
    path = ROOT / 'assets' / 'audio' / f'{name}.wav'
    path.parent.mkdir(parents=True, exist_ok=True)
    frames = bytearray()
    for i in range(int(RATE * duration)):
        t = i / RATE
        fade = min(1, t * 300) * min(1, (duration - t) * 80)
        value = max(-1, min(1, sample(t) * fade))
        frames.extend(struct.pack('<h', int(value * 27000)))
    with wave.open(str(path), 'wb') as f:
        f.setparams((1, 2, RATE, 0, 'NONE', 'not compressed'))
        f.writeframes(frames)

noise = lambda: rng.uniform(-1, 1)
write('bounce', .19, lambda t: math.sin(2 * math.pi * (110 * t - 80 * t*t)) * math.exp(-t*25) * .8 + noise()*math.exp(-t*110)*.3)
write('squeak', .18, lambda t: math.sin(2 * math.pi * (1550*t + 220*t*t))*math.sin(math.pi*t/.18)**2*.2 + noise()*.035)
write('release', .22, lambda t: noise() * math.sin(math.pi*t/.22)**2 * .24)
write('swish', .4, lambda t: noise()*math.sin(math.pi*t/.4)**2*math.exp(-t*4)*.8)
write('rim', .42, lambda t: (math.sin(2*math.pi*740*t)+.5*math.sin(2*math.pi*1140*t)+.3*math.sin(2*math.pi*2130*t))*math.exp(-t*13)*.4)
write('block', .25, lambda t: noise()*math.exp(-t*28)*.65+math.sin(2*math.pi*140*t)*math.exp(-t*20)*.5)
write('whistle', .25, lambda t: math.sin(2*math.pi*(2200*t + 15*math.sin(t*35)))*math.sin(math.pi*t/.25)**2*.18)
write('slam', .5, lambda t: (math.sin(2*math.pi*86*t)*.8 + math.sin(2*math.pi*380*t)*.25 + noise()*.25)*math.exp(-t*11))
write('landing', .16, lambda t: (math.sin(2*math.pi*65*t)*.7 + noise()*.25)*math.exp(-t*28))
print('Generated 9 original WAV effects.')
