extends SceneTree
## Compare bounded Lean vectors with the real runtime sampler and layer guards.
var failures=0
func _init():call_deferred("run")
func check(ok: bool,message: String):
	if not ok:
		failures+=1
		push_error(message)
func quaternion_matches(a: Quaternion,b: Quaternion)->bool:
	# Component error avoids acos(dot(q,q)) amplifying float32 normalization noise.
	return minf((a-b).length(),(a+b).length())<.00001
func run():
	var p=load("res://scripts/actor.gd").new()
	root.add_child(p);p.setup(false)
	var v=p.skinned
	var layer=v.motionbricks
	var sampling=0
	var vectors=[]
	for first in [0,12,25]:
		for channel in [0,22,44]:
			var a=first*180+channel*4
			var b=mini(first+1,25)*180+channel*4
			vectors.append([first,channel,a,b])
			for label in ["run","stop_l","stop_r","left_l","left_r","right_l","right_r"]:
				var values:PackedFloat32Array=layer.BANK.get_meta(label).rotations
				var expected=Quaternion(values[a],values[a+1],values[a+2],values[a+3]).normalized()
				check(quaternion_matches(layer.sample(label,first/25.0,channel),expected),"Sampler boundary vector disagrees")
				sampling+=1
	# Halfway between frames12 and13 exercises the next-index read as well.
	for channel in [0,22,44]:
		for label in ["run","stop_l","stop_r","left_l","left_r","right_l","right_r"]:
			var values:PackedFloat32Array=layer.BANK.get_meta(label).rotations
			var a=12*180+channel*4
			var b=13*180+channel*4
			var qa=Quaternion(values[a],values[a+1],values[a+2],values[a+3]).normalized()
			var qb=Quaternion(values[b],values[b+1],values[b+2],values[b+3]).normalized()
			check(quaternion_matches(layer.sample(label,.5,channel),qa.slerp(qb,.5)),"Sampler next-frame vector disagrees")
			sampling+=1
	var guard_outputs=[]
	for mask in 256:
		layer.reset();layer.weight=1;layer.enabled=bool(mask&128)
		p.action="idle" if mask&1 else "shot"
		p.jump=0 if mask&2 else .2
		p.defense_weight=0 if mask&4 else .4
		p.boxout_weight=0 if mask&8 else .4
		p.dribble_ended=not bool(mask&16)
		p.chase_recovery=not bool(mask&32)
		p.shot_recovery_left=0 if mask&64 else .2
		p.brake_state="";p.redirect_left=0
		var before=layer.applied_frames
		layer.apply(v.skeleton,p,1.0/60,.31,4.7)
		var applied=layer.applied_frames>before
		guard_outputs.append(applied)
		check(applied==(mask==255),"Layer eligibility vector disagrees: "+str(mask))
	layer.enabled=true;p.action="idle";p.jump=0;p.defense_weight=0;p.boxout_weight=0;p.dribble_ended=false;p.chase_recovery=false;p.shot_recovery_left=0
	var clips=[]
	var expired=[]
	for angle in [-1.0,1.0]:
		for support in [0,1]:
			layer.reset();layer.weight=1
			p.redirect_left=.22;p.redirect_angle=angle;p.redirect_support=support
			p.brake_state="plant";p.brake_foot=1-support
			layer.apply(v.skeleton,p,1.0/60,.31,4.7)
			var expected=("left" if angle<0 else "right")+("_r" if support==0 else "_l")
			clips.append(layer.active)
			check(layer.active==expected,"Cut/brake priority or support vector disagrees")
			p.redirect_left=0;p.brake_state=""
			layer.clock=float(layer.BANK.get_meta(layer.active).duration)-1.0/120
			layer.apply(v.skeleton,p,1.0/60,.31,4.7)
			expired.append(layer.active)
			check(layer.active=="run","Expired transition did not return to run")
	var stops=[]
	for support in [0,1]:
		layer.reset();layer.weight=1;p.redirect_left=0;p.brake_state="plant";p.brake_foot=support
		layer.apply(v.skeleton,p,1.0/60,.31,4.7)
		stops.append(layer.active)
		check(layer.active==("stop_r" if support==0 else "stop_l"),"Stop support vector disagrees")
	layer.reset()
	var offsets_clear=true
	for q in layer.offsets:offsets_clear=offsets_clear and quaternion_matches(q,Quaternion.IDENTITY)
	var reset_state={"active":layer.active,"clock":layer.clock,"weight":layer.weight,"previous_redirect":layer.previous_redirect,"previous_braking":layer.previous_braking,"offsets_clear":offsets_clear}
	check(layer.active=="run" and layer.clock==0 and layer.weight==0 and layer.previous_redirect==0 and not layer.previous_braking and offsets_clear,"Reset vector disagrees")
	print("FORMAL_INDEX_VECTORS ",JSON.stringify(vectors))
	print("FORMAL_GUARD_VECTORS ",JSON.stringify(guard_outputs))
	print("FORMAL_CLIP_VECTORS ",JSON.stringify(clips))
	print("FORMAL_EXPIRE_VECTORS ",JSON.stringify(expired))
	print("FORMAL_STOP_VECTORS ",JSON.stringify(stops))
	print("FORMAL_RESET_VECTOR ",JSON.stringify(reset_state))
	print("MOTIONBRICKS_FORMAL_DIFFERENTIAL sampler=",sampling," guards=256 cuts=4 expiry=4 stops=2 reset=1 failures=",failures)
	p.queue_free();await process_frame;quit(1 if failures else 0)
