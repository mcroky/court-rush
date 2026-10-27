extends "res://scripts/game.gd"
## Authority adapter: reuse the actual game rules and 45-bone contact rig without court/UI/audio.
const ControlSlot = preload("res://scripts/online/duel_control.gd")
const SilentAudio = preload("res://scripts/online/silent_audio.gd")
const PoseCodec = preload("res://scripts/online/pose_codec.gd")
var controllers: Array = []
var tick_id = 0
var overtime = 0.0
var outcome = ""
var selected_slot = 0
var event_sequence = 0
var possession_revision = 0

func _ready() -> void:
	set_physics_process(false)
	mode="duel"; started=true; paused=false; sound_enabled=false
	camera=Camera3D.new(); add_child(camera)
	ball=Node3D.new(); add_child(ball)
	impact_ring=Node3D.new(); add_child(impact_ring)
	court_audio=SilentAudio.new(); add_child(court_audio)
	for i in 2:
		var actor=Actor.new(); add_child(actor); actor.setup(i==1)
		actor.apply_athlete({"role":"forward","height":190})
		players.append(actor); controllers.append(ControlSlot.new())
	rng.randomize()
	reset_positions(rng.randi_range(0,1))

func controlled_player():
	return players[selected_slot]

func play_sound(_name: String, _volume: float=-9) -> void:
	pass

func send_state() -> void:
	pass

func announce(title: String, subtitle: String="", duration: float=2.0) -> void:
	feedback=title; feedback_sub=subtitle; feedback_timer=duration
	event_sequence+=1

func defender_feint(_feint: Vector3) -> void:
	pass # Human defenders own their input; no AI reaction injection.

func fake_shot(index: int) -> void:
	players[index].held.queued_release=false
	players[index].held.begin(players[index],"pump",Vector3.ZERO,ball.position)
	announce("PUMP FAKE") # Never trigger the AI mode's forced opposing jump.

func reset_positions(next_owner: int, preserve_pose: bool=false) -> void:
	super.reset_positions(next_owner,preserve_pose)
	possession_revision+=1

func finish_match() -> void:
	phase="ended"; ball_owner=-1
	for p in players: p.has_ball=false
	if outcome.is_empty(): outcome="draw" if scores[0]==scores[1] else "score"
	event_sequence+=1

func launch_shot(index: int) -> void:
	super.launch_shot(index)
	timing_bonus=Rules.release_bonus(shot_hold)

func step(delta: float, inputs: Array) -> void:
	if phase=="ended": return
	tick_id+=1
	if phase=="check":
		check_ball.tick(self,delta)
		return
	time+=delta
	feedback_timer=maxf(0,feedback_timer-delta)
	if phase in ["live","takeoff","flight","loose"]:
		clock_left=maxf(0,clock_left-delta)
		if clock_left<=0: overtime+=delta
		if phase in ["live","takeoff"]:
			shot_clock-=delta
			if shot_clock<=0:
				turnover("SHOT CLOCK","",1-maxi(ball_owner,shooter))
				possession_revision+=1
				return
	if clock_left<=0 and phase in ["live","loose"] and (scores[0]!=scores[1] or overtime>=60):
		finish_match(); return
	# update_actions must not auto-shoot for either human's held stance.
	var squares: Array=[]
	for p in players:
		if p.action=="square": squares.append(p); p.action="online_square"
	update_actions(delta)
	for p in squares: p.action="square"
	for i in 2:
		selected_slot=i
		controllers[i].tick(self,i,inputs[i],delta)
	selected_slot=ball_owner if ball_owner>=0 else shooter
	# Each human owns guard/boxout, unlike the AI mode's implicit rival boxout.
	for i in 2:
		var p=players[i]; var rival=players[1-i]
		p.boxing_out=false; p.contact_pressure=0
		if inputs[i].guard and phase in ["flight","loose"] and p.action=="idle" and not p.has_ball and Rules.can_box_out(p.position,rival.position,rebound_target()):
			p.boxing_out=true; p.contact_direction=(rival.position-p.position).normalized()
			p.facing=atan2(-p.contact_direction.x,-p.contact_direction.z)
			p.watch_direction=rebound_target()-p.position
			p.contact_pressure=clampf((1.1-p.position.distance_to(rival.position))/.35,0,1)
	separate_players()
	if phase=="takeoff" and finish_kind=="shot":
		var t=clampf((players[shooter].action_time-Actor.SHOT_PLANT_TIME)/maxf(.01,release_at-Actor.SHOT_PLANT_TIME),0,1)
		players[shooter].position=takeoff_start.lerp(takeoff_target,smoothstep(0,1,t))
	var order=[0,1] if ball_owner!=1 else [1,0]
	for i in order:
		var p=players[i]
		if p.stealing() and ball_owner>=0 and i!=ball_owner: p.steal_target=players[ball_owner].ball_anchor(time)
		if p.action in ["layup","dunk"] and p.finish_target_valid and p.action_time<=.82: p.position=Rules.clamp_to_court(p.finish_position())
		if p.defensive_jump():
			if not p.block_contact: p.defense_target=ball.position
			if p.action=="block" and phase in ["live","takeoff"]:
				p.defense_target=players[maxi(ball_owner,shooter)].ball_anchor(time)
				p.defense_target.y=maxf(2.30,p.defense_target.y)
			p.position=Rules.clamp_to_court(p.defense_position())
		p.animate(delta,time)
	var previous_owner=ball_owner
	if phase=="live":
		ball.position=players[ball_owner].ball_anchor(time)
		resolve_online_steals()
	elif phase=="takeoff":
		ball.position=players[shooter].ball_anchor(time)
		if not try_block() and players[shooter].action_time>=release_at: release_ball()
	elif phase=="flight": update_flight(delta)
	elif phase=="loose": update_loose(delta)
	elif phase=="dead":
		reset_timer-=delta
		ball.position.y=maxf(Actor.DRIBBLE_FLOOR,ball.position.y-delta*5)
		if reset_timer<=0:
			if Rules.winner(scores,clock_left,true)>=0: finish_match()
			else:
				reset_positions(1-shooter)
				for control in controllers: control.edges={"shoot":true}
	if previous_owner!=ball_owner: possession_revision+=1
	previous_ball_position=ball.position

func resolve_online_steals() -> void:
	for i in 2:
		var p=players[i]
		if phase!="live" or ball_owner!=1-i or not p.stealing() or p.steal_resolved or not p.steal_eligible or p.action_time<.12 or p.action_time>.32: continue
		if players[ball_owner].action!="idle" or hand_ball_distance(p.hand_world,p.previous_hand_world)>=.25 or p.hand_world.distance_to(ball.position)>=.25: continue
		p.steal_resolved=true
		if rng.randf()<.65:
			players[ball_owner].has_ball=false; p.has_ball=true; p.dribble_ended=false
			p.receive_steal(ball.position); ball_owner=i; ball.position=p.ball_anchor(time)
			needs_clear=not Rules.is_clear(p.position); shot_clock=15; last_event="steal"
			event_sequence+=1

func snapshot(acks: Array=[]) -> Dictionary:
	var actors: Array=[]
	for i in 2:
		var p=players[i]
		actors.append({"predictable":p.action=="idle" and not p.dribble_ended and not p.defending and not p.boxing_out and p.brake_state=="" and p.landing_push_left<=0 and p.landing_recovery_left<=0 and not p.chase_recovery,"slot":i,"team":i,"position":vec(p.position),"yaw":snappedf(p.rotation.y,.0001),"body":pack_transform(p.body.transform),"rig":pack_transform(p.skinned.transform),"pose":PoseCodec.encode(p.skinned.skeleton),"boneCount":p.skinned.skeleton.get_bone_count(),"motion":[snappedf(p.motion.x,.0001),snappedf(p.motion.y,.0001)],"action":p.action,"actionTime":snappedf(p.action_time,.0001),"held":p.dribble_ended,"guard":p.defending,"boxout":p.boxing_out,"jump":snappedf(p.jump,.0001),"palms":[vec(p.palm_position(0)),vec(p.palm_position(1))],"finish":p.finish_kind,"style":p.shot_style})
	return {"tick":tick_id,"time":time,"phase":phase,"score":scores.duplicate(),"seconds":clock_left,"shotClock":shot_clock,"clear":needs_clear,"owner":ball_owner,"shooter":shooter,"ball":vec(ball.position),"players":actors,"acks":acks,"event":last_event,"eventSequence":event_sequence,"possessionRevision":possession_revision,"charge":shot_hold/.62 if ball_owner>=0 and players[ball_owner].action=="gather" else 0,"outcome":outcome}

static func vec(v: Vector3) -> Array:
	return [snappedf(v.x,.0001),snappedf(v.y,.0001),snappedf(v.z,.0001)]

static func pack_transform(t: Transform3D) -> Array:
	var q=t.basis.orthonormalized().get_rotation_quaternion()
	var scale=t.basis.get_scale()
	var values=[t.origin.x,t.origin.y,t.origin.z,q.x,q.y,q.z,q.w,scale.x,scale.y,scale.z]
	for i in values.size(): values[i]=snappedf(values[i],.00001)
	return values
