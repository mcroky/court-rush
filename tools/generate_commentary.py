"""Render our original short English calls locally, never at game runtime.

pip install --target artifacts/audio-tools/python kokoro-onnx==0.4.9 soundfile
Model/voices: official thewh1teagle/kokoro-onnx model-files-v1.0 release.
Kokoro-82M v1.0 (Apache-2.0), stock am_michael voice, not a voice clone.
Do not distribute the inference runtime or model as part of the game.
"""
from pathlib import Path
import sys
import json
import hashlib
import tempfile
import shutil
import os

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'artifacts/audio-tools/python'))
import numpy as np
import soundfile as sf
import onnxruntime as ort
from kokoro_onnx import Kokoro
from kokoro_onnx.config import EspeakConfig
import espeakng_loader

LINES={
    'score':['Nothing but net!','Oh, what a bucket!','That is money!'],
    'three':['From downtown!','Three points! Let it fly!'],
    'layup':['What a finish!','Soft touch, right at the rim!'],
    'dunk':['Oh! Throw it down!','Up high! Bring it home!'],
    'cross':['What a crossover!','Quick hands, quick feet!'],
    'spin':['Spin move!','Around and away!'],
    'twostep':['One, two! There you go!','Change of pace!'],
    'behind':['Behind the back!','Smooth handles!'],
    'hesi':['Hesitate, and go!','Look at that handle!'],
    'block':['Get that out of here!','Denied at the rim!'],
    'rebound':['Up high! Got the rebound!','Big rebound!'],
    'steal':['Quick hands! What a steal!','Picked it clean!'],
    'win':["That is game! What a performance!",'Big win on the court!'],
}

if __name__=='__main__':
    models=ROOT/'artifacts/audio-tools/models'
    options=ort.SessionOptions()
    options.intra_op_num_threads=4
    session=ort.InferenceSession(str(models/'kokoro-v1.0.onnx'),sess_options=options,providers=['CPUExecutionProvider'])
    # eSpeak's C data loader on Windows cannot open the Korean workspace path.
    data=Path(tempfile.gettempdir())/'court-rush-espeak-data'
    shutil.copytree(espeakng_loader.get_data_path(),data,dirs_exist_ok=True)
    os.environ['ESPEAK_DATA_PATH']=str(data)
    engine=Kokoro.from_session(session,str(models/'voices-v1.0.bin'),espeak_config=EspeakConfig(data_path=str(data)))
    out=ROOT/'assets/audio/voice'
    out.mkdir(parents=True,exist_ok=True)
    entries=[]
    for event,lines in LINES.items():
        for index,text in enumerate(lines):
            samples,rate=engine.create(text,voice='am_michael',speed=1.10,lang='en-us')
            # Trim dead air, mild saturation and a quiet short arena reflection.
            active=np.flatnonzero(np.abs(samples)>.006)
            samples=samples[max(0,active[0]-240):min(len(samples),active[-1]+960)]
            samples=np.tanh(samples*1.5)
            samples*=.85/max(float(np.max(np.abs(samples))),.001)
            wet=np.pad(samples,(0,round(rate*.08)))
            wet[round(rate*.055):round(rate*.055)+len(samples)]+=samples*.055
            wet*=.88
            path=out/f'{event}-{index+1}.wav'
            sf.write(path,wet,rate,subtype='PCM_16')
            entries.append(dict(event=event,text=text,file=path.name,duration=len(wet)/rate,sha256=hashlib.sha256(path.read_bytes()).hexdigest()))
            print(path.name,round(len(wet)/rate,2),flush=True)
    manifest={'generator':'kokoro-onnx 0.4.9','model':'Kokoro-82M v1.0','modelLicense':'Apache-2.0','voice':'am_michael','speed':1.10,
              'source':'https://github.com/thewh1teagle/kokoro-onnx/releases/tag/model-files-v1.0',
              'modelSha256':hashlib.sha256((models/'kokoro-v1.0.onnx').read_bytes()).hexdigest(),
              'voicesSha256':hashlib.sha256((models/'voices-v1.0.bin').read_bytes()).hexdigest(),'lines':entries}
    (out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf8')
