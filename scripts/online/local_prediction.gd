extends RefCounted
## Visual speculation only. This sandbox never steps ball outcomes or reports results.
const Rules=preload("res://scripts/rules.gd")
var simulation
var slot=0
var active=false
var weight=0.0
var age=0.0
var revision=-1
var owner=-1
var action_age=0.0
var action_seq=-1
var acknowledged=-1
var pending: Array=[]
var correction=Vector3.ZERO
var state: Dictionary={}

func start(game, data: Dictionary) -> void:
	slot=int(data.slot)
	# Runtime load avoids the game -> view -> game preload cycle.
	simulation=load("res://scripts/online/duel_simulation.gd").new()
	game.add_child(simulation)
	simulation.visible=false
	simulation.selected_slot=slot
	for i in 2:
		simulation.players[i].apply_athlete(data.participants[i].get("athlete",{}))

func stop() -> void:
	if is_instance_valid(simulation): simulation.queue_free()
	simulation=null
	pending.clear()

func receive(next: Dictionary) -> void:
	state=next; age=0
	var next_owner=int(state.owner)
	var next_revision=int(state.possessionRevision)
	acknowledged=int(state.acks[slot]) if state.get("acks",[]).size()==2 else -1
	if next_owner!=owner or next_revision!=revision or state.phase in ["check","dead","ended"]:
		active=false; pending.clear(); correction=Vector3.ZERO
	owner=next_owner; revision=next_revision
	var kept: Array=[]
	for step in pending:
		if int(step.seq)>acknowledged: kept.append(step)
	pending=kept
	if not active: return
	var p=simulation.players[slot]
	var server: Dictionary=state.players[slot]
	# A rejected action must not continue indefinitely on the client.
	if str(server.action)!=p.action and action_age>.30 and acknowledged>=action_seq:
		active=false; return
	var target=vec(server.position)
	for step in pending: target+=step.travel
	correction=target-p.position
	if correction.length()>1.5: active=false

func seed_from_state() -> void:
	var p=simulation.players[slot]
	var server: Dictionary=state.players[slot]
	p.reset_stance(); p.action="idle"; p.action_time=0; p.jump=0
	p.position=vec(server.position); p.motion=Vector2(server.motion[0],server.motion[1])
	p.rotation.y=float(server.yaw); p.facing=p.rotation.y
	p.dribble_phase=float(server.get("dribblePhase",0))
	p.stride=float(server.get("stride",0))
	p.dribble_hand=float(server.get("dribbleHand",1))
	p.dribble_ended=bool(server.held)
	simulation.time=float(state.time)
	simulation.phase=str(state.phase); simulation.ball_owner=owner
	simulation.ball.position=vec(state.ball); simulation.needs_clear=bool(state.clear)
	simulation.shot_hold=0
	simulation.controllers[slot].edges={}
	pending.clear(); correction=Vector3.ZERO; action_age=0; active=true

func tick(delta: float, input: Dictionary, next_seq: int, enabled: bool) -> void:
	if simulation==null or state.is_empty(): return
	age+=delta
	if not enabled or age>.30 or state.phase in ["check","dead","ended"]: active=false
	var server: Dictionary=state.players[slot]
	if not active and enabled and age<=.30 and state.phase=="live" and str(server.action)=="idle" and float(server.jump)<.001:
		seed_from_state()
	weight=move_toward(weight,1.0 if active else 0.0,delta/0.08)
	if not active or delta<=0: return
	var p=simulation.players[slot]
	var other=simulation.players[1-slot]
	var rival: Dictionary=state.players[1-slot]
	other.position=vec(rival.position); other.jump=float(rival.jump)
	other.motion=Vector2(rival.motion[0],rival.motion[1])
	other.has_ball=owner==1-slot; other.dribble_ended=bool(rival.held)
	other.action="idle" # No speculative rival actions, steals or ball outcomes.
	p.has_ball=owner==slot
	simulation.ball_owner=owner; simulation.shooter=int(state.shooter)
	simulation.needs_clear=bool(state.clear)
	# Keep a locally initiated takeoff until its server confirmation arrives.
	if not (simulation.phase=="takeoff" and state.phase=="live" and action_age<.30):
		simulation.phase=str(state.phase)
	if owner!=slot or simulation.phase not in ["live","takeoff"]:
		simulation.ball.position=vec(state.ball)
	simulation.time+=delta
	var before=p.position
	var previous_action=str(p.action)
	# Same action, locomotion and IK code as single player; no match step/score RNG.
	var square=p.action=="square"
	if square: p.action="online_square"
	simulation.update_actions(delta)
	if square: p.action="square"
	simulation.selected_slot=slot
	simulation.controllers[slot].tick(simulation,slot,input,delta)
	simulation.separate_players()
	if simulation.phase=="takeoff" and p.action=="shot":
		var t=clampf((p.action_time-p.SHOT_PLANT_TIME)/maxf(.01,simulation.release_at-p.SHOT_PLANT_TIME),0,1)
		p.position=simulation.takeoff_start.lerp(simulation.takeoff_target,smoothstep(0,1,t))
	if p.action in ["layup","dunk"] and p.finish_target_valid and p.action_time<=.82:
		p.position=Rules.clamp_to_court(p.finish_position())
	if p.defensive_jump(): p.position=Rules.clamp_to_court(p.defense_position())
	if p.stealing(): p.steal_target=simulation.ball.position
	if p.action!=previous_action:
		action_age=0; action_seq=next_seq
	else: action_age+=delta
	pending.append({"seq":next_seq,"travel":p.position-before})
	# Bound history during a bad connection, even if the server stops acknowledging.
	while pending.size()>24: pending.pop_front()
	var adjustment=(correction*(1-exp(-12*delta))).limit_length(2.1*delta)
	p.position=Rules.clamp_to_court(p.position+adjustment); correction-=adjustment
	p.animate(delta,simulation.time)
	if owner==slot and simulation.phase in ["live","takeoff"]:
		simulation.ball.position=p.ball_anchor(simulation.time)

static func vec(value: Array) -> Vector3:
	return Vector3(value[0],value[1],value[2])
