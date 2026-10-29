extends RefCounted
## Offline SOMA poses layered before contact IK. Gameplay owns root and timing.
const BANK=preload("res://assets/motionbricks/locomotion.res")
const CHANNELS=["pelvis","spine_01","spine_02","clavicle.r","upperarm.r","lowerarm.r","clavicle.l","upperarm.l","lowerarm.l"]
var bones=PackedInt32Array()
var channels=PackedInt32Array()
var weight=0.0
var active="run"
var clock=0.0
var previous_redirect=0.0
var previous_braking=false
var applied_frames=0
var enabled=true
var offsets:Array[Quaternion]=[]

func reset()->void:
	weight=0
	active="run"
	clock=0
	previous_redirect=0
	previous_braking=false
	for i in offsets.size():offsets[i]=Quaternion.IDENTITY

func setup(skeleton: Skeleton3D)->void:
	var names:PackedStringArray=BANK.get_meta("names")
	for name in CHANNELS:
		bones.append(skeleton.find_bone(name))
		channels.append(names.find(name))
		offsets.append(Quaternion.IDENTITY)

func sample(label: String, progress: float, channel: int)->Quaternion:
	var clip:Dictionary=BANK.get_meta(label)
	var cursor=clampf(progress,0,1)*(int(clip.frames)-1)
	var first=int(cursor)
	var second=mini(first+1,int(clip.frames)-1)
	var values:PackedFloat32Array=clip.rotations
	var width:int=BANK.get_meta("names").size()*4
	var a=first*width+channel*4
	var b=second*width+channel*4
	return Quaternion(values[a],values[a+1],values[a+2],values[a+3]).normalized().slerp(Quaternion(values[b],values[b+1],values[b+2],values[b+3]).normalized(),cursor-first)

func apply(skeleton: Skeleton3D,actor,delta: float,phase: float,speed: float)->void:
	if not enabled:return
	var eligible=actor.action=="idle" and actor.jump<.02 and actor.defense_weight<.2 and actor.boxout_weight<.2 and not actor.dribble_ended and not actor.chase_recovery and actor.shot_recovery_left<=0
	var braking:bool=actor.brake_state!=""
	var trigger_cut:bool=actor.redirect_left>previous_redirect+.01
	if eligible and trigger_cut:
		active=("left" if actor.redirect_angle<0 else "right")+("_r" if actor.redirect_support==0 else "_l")
		clock=0
	elif eligible and braking and not previous_braking:
		active="stop_r" if actor.brake_foot==0 else "stop_l"
		clock=0
	previous_redirect=actor.redirect_left
	previous_braking=braking
	clock+=delta
	if active!="run" and clock>=float(BANK.get_meta(active).duration):active="run"
	var desired=clampf(speed/3.0,0,1) if eligible else 0.0
	if eligible and active.begins_with("stop") and braking:desired=1.0
	weight=move_toward(weight,desired,delta*8)
	# Action poses retain their exact shoulder/hand chain with no residual layer.
	if not eligible:
		for i in offsets.size():offsets[i]=Quaternion.IDENTITY
		return
	if weight<.001:return
	var progress=phase if active=="run" else clock/float(BANK.get_meta(active).duration)
	# Match the contact phase of the input run at both ends of each transition.
	var envelope=1.0 if active=="run" else sin(clampf(progress,0,1)*PI)
	for i in bones.size():
		var bone=bones[i]
		var source=skeleton.get_bone_pose_rotation(bone)
		var target=sample("run",phase,channels[i])
		if active!="run":target=target.slerp(sample(active,progress,channels[i]),envelope)
		# Retargeted body motion cannot force an extreme shoulder/pelvis rotation.
		var angle=source.angle_to(target)
		if angle>.52:target=source.slerp(target,.52/angle)
		offsets[i]=offsets[i].slerp(source.inverse()*target,1-exp(-delta*18))
		target=source*offsets[i]
		var amount=(.48 if i<3 else .38)*weight
		skeleton.set_bone_pose_rotation(bone,source.slerp(target,amount))
	applied_frames+=1
