"""Bake licensed Court Rush source poses through pinned SOMA FP32 on CPU.

No bundled BVH/CSV or evaluation output is loaded. Upstream Apache-2.0
encoding/decoding kernels are imported read-only; model weights stay local.
"""
import json,sys,time,hashlib
from pathlib import Path
import numpy as np
ROOT=Path(__file__).resolve().parents[1]
INSTALL=Path('C:/Users/SVSCORP/.codex/tools/motionbricks')
SOURCE=INSTALL/'source'
sys.path.insert(0,str(SOURCE))
import warp as wp
import onnxruntime as ort
from motionbricks.io.usd import load_skeleton_from_usd
from motionbricks.io.utils import SOMA_SKELETON_PRIM_PATH,get_asset_file
from motionbricks.model.soma import kernels
from motionbricks.model.contract import MODEL_MAX_VALID_FRAMES

def mul(a,b):
    a=np.asarray(a);b=np.asarray(b)
    return np.r_[a[3]*b[:3]+b[3]*a[:3]+np.cross(a[:3],b[:3]),a[3]*b[3]-np.dot(a[:3],b[:3])]
def inv(q):return np.r_[-q[:3],q[3]]
def unit(q):return q/max(np.linalg.norm(q),1e-10)
def rotate(q,v):return mul(mul(q,np.r_[v,0]),inv(q))[:3]
def blend(a,b,t):
    b=b.copy()
    dot=np.dot(a,b)
    if dot<0:b=-b;dot=-dot
    if dot>.9995:return unit(a*(1-t)+b*t)
    angle=np.arccos(np.clip(dot,-1,1))
    return (np.sin((1-t)*angle)*a+np.sin(t*angle)*b)/np.sin(angle)
def yaw(v):return np.array([0,np.sin(v/2),0,np.cos(v/2)])
def world(local,parents):
    out=local.copy()
    for i,p in enumerate(parents):
        if p>=0:out[i,:3]=out[p,:3]+rotate(out[p,3:],local[i,:3]);out[i,3:]=unit(mul(out[p,3:],local[i,3:]))
    return out

def main():
    out=ROOT/(sys.argv[1] if len(sys.argv)>1 else 'artifacts/motionbricks-authored')
    if ROOT not in out.resolve().parents:raise ValueError('Output must stay in this project')
    out.mkdir(exist_ok=True)
    if (out/'bank.json').exists():raise RuntimeError('Choose a fresh authoring output; refusing overwrite')
    wp.config.kernel_cache_dir=str(out/'warp-cache')
    wp.init();wp.set_device('cpu')
    sk=load_skeleton_from_usd(get_asset_file('human','soma_base_skel_minimal_no_root.usd'),SOMA_SKELETON_PRIM_PATH)
    ref=sk.reference_local_transforms.numpy();parents=sk.parent_indices.numpy();rest=world(ref,parents)
    src=json.loads((ROOT/'artifacts/motionbricks-source.json').read_text(encoding='utf-8-sig'))
    sr=np.array(src['rest']);names=src['names'];indices={n:i for i,n in enumerate(names)}
    mapping={'Hips':'pelvis','Spine1':'spine_01','Spine2':'spine_02','Chest':'spine_02','Neck1':'neck_01','Head':'head'}
    for side,suffix in [('Left','.l'),('Right','.r')]:
        for a,b in [('Shoulder','clavicle'),('Arm','upperarm'),('ForeArm','lowerarm'),('Hand','hand'),('Leg','thigh'),('Shin','calf'),('Foot','foot'),('ToeBase','ball'),('HandThumbEnd','thumb_03'),('HandMiddleEnd','middle_03')]:mapping[side+a]=b+suffix
    soma={n:i for i,n in enumerate(sk.joint_names)}
    def sample(clip,phase):
        frames=np.array(src['clips'][clip]['poses']);u=(phase%1)*60;i=int(u);t=u-i
        result=frames[i].copy()
        result[:,:3]=frames[i,:,:3]*(1-t)+frames[i+1,:,:3]*t
        for j in range(len(names)):result[j,3:]=blend(frames[i,j,3:],frames[i+1,j,3:],t)
        return result
    def to_soma(clip,phase,pos,angle=0):
        frame=sample(clip,phase);w=rest.copy();result=ref.copy()
        for i,name in enumerate(sk.joint_names):
            p=parents[i];source=mapping.get(name)
            q=mul(mul(frame[indices[source],3:],inv(sr[indices[source],3:])),rest[i,3:]) if source else (mul(w[p,3:],ref[i,3:]) if p>=0 else ref[i,3:])
            if p>=0:
                w[i,:3]=w[p,:3]+rotate(w[p,3:],ref[i,:3]);w[i,3:]=unit(q)
                result[i,3:]=unit(mul(inv(w[p,3:]),q))
            else:
                w[i,:3]=rest[i,:3]+(frame[0,:3]-sr[0,:3]);w[i,:3]+=np.array(pos)
                w[i,3:]=unit(q);result[i]=w[i]
        for i in range(len(w)):
            w[i,:3]=rotate(yaw(angle),w[i,:3]-np.array(pos))+np.array(pos)
            w[i,3:]=mul(yaw(angle),w[i,3:])
        for i,p in enumerate(parents):
            if p<0:result[i]=w[i]
            else:result[i,:3]=rotate(inv(w[p,3:]),w[i,:3]-w[p,:3]);result[i,3:]=unit(mul(inv(w[p,3:]),w[i,3:]))
        return result,w
    spec=json.loads((SOURCE/'motionbricks/assets/onnx/soma/soma_n1.json').read_text())
    model_map=[soma[n] for n in spec['joint_names']]
    reverse=np.full(len(ref),-1,np.int32)
    for j,i in enumerate(model_map):reverse[i]=j
    model_wp=wp.array(model_map,dtype=wp.int32,device='cpu');reverse_wp=wp.array(reverse,dtype=wp.int32,device='cpu')
    options=ort.SessionOptions();options.intra_op_num_threads=4;options.inter_op_num_threads=1
    model=SOURCE/'motionbricks/assets/onnx/soma/mmm_v6_soma_fp32.onnx'
    session=ort.InferenceSession(str(model),sess_options=options,providers=['CPUExecutionProvider'])
    bank={'schema':1,'fps':30,'names':names,'source_sha256':hashlib.sha256((ROOT/'assets/experiments/mannequiny/mannequiny.glb').read_bytes()).hexdigest(),'clips':{}}
    reports=[]
    cases=[('run',0.0,0),('stop_l',0.0,0),('stop_r',.5,0),('left_l',0.0,-np.pi/2),('left_r',.5,-np.pi/2),('right_l',0.0,np.pi/2),('right_r',.5,np.pi/2)]
    inverse_mapping={v:k for k,v in mapping.items()};inverse_mapping['spine_02']='Chest'
    for label,start,angle in cases:
        context=[];target=[];guides=[]
        duration=src['clips']['run']['length'] if label=='run' else .60
        for k in range(8):
            dt=(k-3)/30 if k<4 else duration+(k-4)/30
            phase=start+dt/src['clips']['run']['length']
            is_stop=label.startswith('stop') and k>=4
            position=[0,0,dt*3.5] if k<4 or label=='run' else [np.sin(angle)*duration*2.3,0,np.cos(angle)*duration*2.3]
            local,w=to_soma('idle' if is_stop else 'run',0 if is_stop else phase,position,angle if k>=4 else 0)
            (context if k<4 else target).append(local);guides.append(w)
        context=wp.array(np.array(context,np.float32),dtype=wp.transform,device='cpu');target=wp.array(np.array(target,np.float32),dtype=wp.transform,device='cpu')
        guides=wp.array(np.array(guides,np.float32),dtype=wp.transform,device='cpu');align=wp.empty(1,dtype=wp.transform,device='cpu')
        right,left=soma['RightLeg'],soma['LeftLeg']
        wp.launch(kernels.compute_guide_alignment_kernel,dim=1,inputs=[right,left,wp.vec2(0,1),guides],outputs=[align],device='cpu')
        gr=wp.zeros((1,8,5),dtype=wp.float32,device='cpu');lr=wp.zeros((1,8,4),dtype=wp.float32,device='cpu');lp=wp.zeros((1,8,267),dtype=wp.float32,device='cpu')
        wp.launch(kernels.encode_motionbricks_inputs_kernel,dim=8,inputs=[30,right,left,model_wp,guides,align],outputs=[gr,lr,lp],device='cpu')
        mask=np.ones((1,8),np.int32);mask[0,[3,7]]=0
        allowed=np.zeros((1,11),np.int32);allowed[0,2]=1 # 26 valid frames, endpoint-corrected.
        feed={'global_root_values':gr.numpy(),'local_root_values':lr.numpy(),'local_poses':lp.numpy(),'has_global_root_values':np.ones((1,8),np.int32),'has_local_root_values':mask,'has_local_poses':np.ones((1,8),np.int32),'allowed_pred_num_tokens':allowed}
        begin=time.perf_counter();raw,tokens=session.run(None,feed);elapsed=time.perf_counter()-begin
        poses=wp.empty((MODEL_MAX_VALID_FRAMES,len(ref)),dtype=wp.transform,device='cpu');contacts=wp.zeros((MODEL_MAX_VALID_FRAMES,4),dtype=wp.float32,device='cpu');count=wp.zeros(1,dtype=wp.int32,device='cpu')
        wp.launch(kernels.decode_motionbricks_output_kernel,dim=MODEL_MAX_VALID_FRAMES,inputs=[30,len(ref),sk.parent_indices,reverse_wp,sk.reference_local_transforms,align,wp.transform_identity(),wp.array(raw,dtype=wp.float32,device='cpu'),wp.array(tokens,dtype=wp.int32,device='cpu')],outputs=[poses,contacts,count],device='cpu')
        a=wp.empty(len(ref),dtype=wp.transform,device='cpu');b=wp.empty_like(a)
        wp.launch(kernels.compute_endpoint_deltas_kernel,dim=len(ref),inputs=[count,context,target,poses],outputs=[a,b],device='cpu')
        wp.launch(kernels.apply_endpoint_deltas_kernel,dim=(MODEL_MAX_VALID_FRAMES,len(ref)),inputs=[count,a,b],outputs=[poses],device='cpu')
        n=int(count.numpy()[0]);generated=poses.numpy()[:n];assert np.isfinite(generated).all()
        baked=[]
        for f,local in enumerate(generated):
            w=world(local,parents);result=sample('run',start+f/max(n-1,1)).copy()
            # Remove world heading: gameplay turns the actor root itself.
            across=w[right,:3]-w[left,:3]
            forward=np.cross([0,1,0],across)
            heading=np.arctan2(forward[0],forward[2])
            for name,si in indices.items():
                sn=inverse_mapping.get(name)
                if not sn:continue
                j=soma[sn]
                delta=mul(mul(inv(yaw(heading)),w[j,3:]),inv(rest[j,3:]))
                result[si,3:]=unit(mul(delta,sr[si,3:]))
            # Return to the game's original parent basis without scaling limbs.
            q=[]
            for i,p in enumerate(src['parents']):q.append((mul(inv(result[p,3:]),result[i,3:]) if p>=0 else result[i,3:]).tolist())
            baked.append(q)
        bank['clips'][label]={'phase':start,'duration':(n-1)/30,'rotations':baked,'contacts':contacts.numpy()[:n].tolist()}
        np.savez_compressed(out/(label+'.npz'),local_poses=generated,foot_contacts=contacts.numpy()[:n])
        err=max(float(np.max(np.abs(generated[0,:,:3]-context.numpy()[-1,:,:3]))),float(np.max(np.abs(generated[-1,:,:3]-target.numpy()[0,:,:3]))))
        assert err<1e-4
        reports.append({'clip':label,'frames':n,'inference_seconds':elapsed,'endpoint_m':err})
        print(label,n,elapsed,flush=True)
    (out/'bank.json').write_text(json.dumps(bank,separators=(',',':')),encoding='utf-8')
    (out/'report.json').write_text(json.dumps({'backend':'ONNX Runtime CPU FP32','source_commit':'54fc563aeaaf819a753d72cc9fdc6713989cdd43','input':'Court Rush GDQuest CC-BY-4.0 GLB; no bundled motion samples','results':reports},indent=2),encoding='utf-8')
if __name__=='__main__':main()
