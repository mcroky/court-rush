extends SceneTree
const Authority=preload("res://scripts/online/duel_simulation.gd")
const Predictor=preload("res://scripts/online/local_prediction.gd")
var failures=0
func _init() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	if ok: print("PASS: ",message)
	else: push_error("FAIL: "+message); failures+=1
func packet(authority, ack: int) -> Dictionary:
	return JSON.parse_string(JSON.stringify(authority.snapshot([ack,ack])))
func run() -> void:
	var authority=Authority.new();root.add_child(authority)
	authority.reset_positions(0); authority.needs_clear=false
	authority.players[0].position=Vector3(-3,0,2)
	authority.players[1].position=Vector3(3,0,2)
	var initial=packet(authority,-1)
	var prediction=Predictor.new()
	var host=Node3D.new();root.add_child(host)
	prediction.start(host,{"slot":0,"participants":[{"athlete":{"role":"guard","height":178,"speed":76}},{"athlete":{"role":"center","height":204}}]})
	prediction.receive(initial)
	var controls=Authority.ControlSlot.neutral();controls.x=1.0
	prediction.tick(1.0/60,controls,0,true)
	check(prediction.active and prediction.simulation.players[0].position.x>initial.players[0].position[0],"movement starts in the first 16.7ms frame without any server reply")
	var start=prediction.simulation.players[0].position
	for frame in 8: prediction.tick(1.0/60,controls,frame/2,true)
	check(prediction.simulation.players[0].position.x>start.x+.1,"own movement and rig keep advancing across a 150ms packet gap")
	var actor=prediction.simulation.players[0]
	var bone=actor.skinned.skeleton.get_bone_pose_rotation(10)
	prediction.tick(1.0/60,controls,5,true)
	check(not bone.is_equal_approx(actor.skinned.skeleton.get_bone_pose_rotation(10)),"own animation advances between server snapshots")
	controls.x=0;controls.shoot=true;controls.shoot_pressed=true
	prediction.tick(1.0/60,controls,6,true)
	check(actor.action in ["square","gather","shot","layup","dunk"],"shoot preparation starts locally without a packet round trip")
	check(prediction.simulation.ball.position.distance_to(actor.ball_anchor(prediction.simulation.time))<.001,"predicted held ball stays at the actual local rig anchor")
	check(int(initial.score[0])==0 and int(initial.score[1])==0 and authority.scores==[0,0] and authority.ball_owner==0,"visual prediction never writes the authoritative score or owner")
	# The server takes possession away while our locally predicted shot is pending.
	var stolen=initial.duplicate(true);stolen.tick=3;stolen.owner=1;stolen.possessionRevision+=1
	stolen.players[0].action="steal";stolen.players[0].held=false
	prediction.receive(stolen)
	check(not prediction.active and prediction.pending.is_empty(),"authoritative possession change immediately cancels pending speculative action")
	for frame in 8:prediction.tick(1.0/60,Authority.ControlSlot.neutral(),7,true)
	check(prediction.weight<.001,"rejected action blends back to server poses within 80ms")
	prediction.receive(initial)
	prediction.tick(1.0/60,Authority.ControlSlot.neutral(),8,true)
	for frame in 25:prediction.tick(1.0/60,controls,8,true)
	check(not prediction.active and prediction.pending.size()<=24,"missing packets stop speculation at 300ms with bounded history")
	prediction.receive(initial)
	prediction.tick(1.0/60,controls,9,false)
	check(not prediction.active,"background and dialog input gates disable speculation")
	var flight=initial.duplicate(true);flight.owner=-1;flight.phase="flight";flight.shooter=1
	flight.possessionRevision+=2;flight.players[0].defense="rebound"
	prediction.receive(flight)
	var rebound=Authority.ControlSlot.neutral();rebound.shoot=true;rebound.shoot_pressed=true
	prediction.tick(1.0/60,rebound,10,true)
	check(prediction.active and actor.action=="rebound" and prediction.simulation.ball_owner==-1,"airborne-ball rebound input starts immediately without predicting a catch or ownership")
	# Reproduce a 100ms input/100ms snapshot delay with irregular deliveries.
	# All actors use the same canonical growth, so drift is not hidden by a speed mismatch.
	for i in 2: authority.players[i].apply_athlete({"role":"forward","height":190})
	authority.reset_positions(0);authority.needs_clear=false
	authority.players[0].position=Vector3(-3,0,2);authority.players[1].position=Vector3(3,0,2)
	for i in 2: prediction.simulation.players[i].apply_athlete({"role":"forward","height":190})
	prediction.active=false;prediction.receive(packet(authority,-1))
	var deliveries: Array=[]
	var last=authority.players[0].position
	var max_step=0.0
	var stopped=0
	var begun=Time.get_ticks_usec()
	for frame in 120:
		var move=Authority.ControlSlot.neutral();move.z=-1
		var remote=move if frame>=6 else Authority.ControlSlot.neutral()
		authority.step(1.0/60,[remote,Authority.ControlSlot.neutral()])
		if frame%3==0: deliveries.append({"at":frame+6+(3 if frame%12==0 else 0),"state":packet(authority,(frame-6)/2)})
		while not deliveries.is_empty() and int(deliveries[0].at)<=frame: prediction.receive(deliveries.pop_front().state)
		prediction.tick(1.0/60,move,frame/2+1,true)
		var now=prediction.simulation.players[0].position
		if frame>12:
			max_step=maxf(max_step,last.distance_to(now))
			if last.distance_to(now)<.00001:stopped+=1
		last=now
	print("PREDICTED_JITTER max_step_m=",max_step," stopped_frames=",stopped," test_wall_ms=",(Time.get_ticks_usec()-begun)/1000.0)
	check(max_step<.15 and stopped==0,"100ms delayed jittering snapshots produce continuous 60Hz own movement without packet-sized jumps")
	prediction.stop();host.queue_free();authority.queue_free();await process_frame
	quit(1 if failures else 0)

