extends RefCounted
## Half-court AI teams. Player IDs never double as team IDs.
const Actor = preload("res://scripts/actor.gd")
const Rules = preload("res://scripts/rules.gd")
const ROLES = ["guard", "forward", "center"]
var game
var legacy: Array = []
var extras: Array = []
var labels: Array = []
var selected = 0
var possession = 0
var last_touch = 0
var marks: Array = [3,4,5,0,1,2]
var goals: Array = []
var decisions = 0.0
var ai_cooldown = 1.0
var switch_cooldown = 0.0
var edges: Dictionary = {}
var passing_from = -1
var passing_to = -1
var pass_time = 0.0
var pass_duration = .5
var pass_start = Vector3.ZERO
var pass_target = Vector3.ZERO
var pass_caught = false
var passes = 0
var interceptions = 0
var rebounds = 0
var blocks = 0
var controlled_stats: Dictionary = {}
var activity_seconds=0.0
var human_shooter=false
var pass_by_user=false
var assist_candidate=-1
var assist_receiver=-1
var assist_until=0.0
var rebound_live=false
var feint_cooldowns: Array = [0.0,0.0,0.0,0.0,0.0,0.0]
var offball_cursor: Array=[0,1,2,0,1,2]
var offball_hold: Array=[0.0,0.0,0.0,0.0,0.0,0.0]
var label_sources: Array=["","","","","",""]
var marker_selection=-1
var marker_owner=-2

func _init(owner_game) -> void:
	game = owner_game

func team(index: int) -> int:
	return index / 3 if index >= 0 else -1

func start(role: String) -> void:
	legacy = game.players.duplicate()
	if extras.is_empty():
		for i in 4:
			var actor = Actor.new()
			game.add_child(actor)
			actor.setup(i >= 2)
			extras.append(actor)
	game.players = [legacy[0],extras[0],extras[1],legacy[1],extras[2],extras[3]]
	var friendly_roles = [role]
	for value in ROLES:
		if value != role: friendly_roles.append(value)
	for i in 6:
		var r: String = friendly_roles[i] if i < 3 else ROLES[i-3]
		game.players[i].apply_athlete({"role":r,"height":{"guard":178,"forward":190,"center":204}[r]})
		game.players[i].visible = true
		if labels.size() <= i:
			var label = Label3D.new()
			game.add_child(label)
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			label.font_size = 40
			label.pixel_size = .006
			label.outline_size = 8
			label.no_depth_test = true
			labels.append(label)
		labels[i].visible = true
	for i in 6:
		for j in 6:
			if team(i) != team(j) and game.players[i].court_role == game.players[j].court_role: marks[i] = j
	goals.resize(6)
	selected = 0
	passes = 0
	interceptions = 0
	rebounds = 0
	blocks = 0
	controlled_stats={"points":0,"assists":0,"rebounds":0,"blocks":0,"steals":0}
	activity_seconds=0.0
	game.clock_left = 180
	reset(0)
	game.announce("3 ON 3", "Q 패스 · E 수비 전환 · 11점 또는 3분 · 보상 없는 AI 팀전", 5)

func stop() -> void:
	if legacy.is_empty(): return
	for actor in extras: actor.visible = false
	for label in labels: label.visible = false
	game.players = legacy.duplicate()
	for actor in game.players: actor.marker.visible = true
	legacy.clear()

func reset(next_team: int) -> void:
	possession = next_team
	last_touch = next_team*3
	game.ball_owner = next_team*3
	game.phase = "live"
	game.needs_clear = false
	game.shot_clock = 18
	game.shot_hold = 0
	game.shot_committed = false
	game.crossover_cooldown = 0
	game.steal_cooldown = 0
	game.last_shoot = true
	game.trail_positions.clear()
	passing_from = -1
	passing_to = -1
	pass_caught = false
	assist_candidate=-1
	rebound_live=false
	feint_cooldowns.fill(0.0)
	offball_cursor=[0,1,2,0,1,2]
	offball_hold.fill(0.0)
	label_sources.fill("")
	edges = {"shoot":true,"pass":true,"switch":true}
	ai_cooldown = 1.0
	decisions = 0
	for i in 6:
		var p = game.players[i]
		var attacking = team(i) == next_team
		var slot = i%3
		var spots = [Vector3(0,0,1.9),Vector3(-4.3,0,-1.8),Vector3(2.7,0,-3.8)]
		p.position = spots[slot]+(Vector3.ZERO if attacking else Vector3(.45,0,-1.05))
		p.motion = Vector2.ZERO
		p.jump = 0
		p.action = "idle"
		p.action_time = 0
		p.finish_target_valid = false
		p.finish_running = false
		p.reset_stance()
		p.has_ball = i == game.ball_owner
		p.dribble_ended = false
		p.facing = PI if attacking else 0.0
		p.rotation.y = p.facing
		p.animate(.016,game.time)
		goals[i] = p.position
	selected = game.ball_owner if next_team == 0 else nearest_friendly(game.players[game.ball_owner].position)
	game.ball.position = game.players[game.ball_owner].ball_anchor(game.time)
	game.previous_ball_position = game.ball.position
	update_labels()

func nearest_friendly(target: Vector3) -> int:
	var best = 0
	for i in range(1,3):
		if game.players[i].position.distance_to(target) < game.players[best].position.distance_to(target): best = i
	return best

func pressed(input: Dictionary, action: String) -> bool:
	return bool(input.get(action,false)) and not bool(edges.get(action,false))

func defense_kind() -> String:
	return "rebound" if game.phase == "loose" or (game.phase == "flight" and game.flight_t/maxf(game.flight_duration,.01) > .45) or team(game.shooter) == 0 and game.phase == "flight" else "block"

func tick(delta: float, input: Dictionary) -> void:
	game.time += delta
	var active=absf(float(input.get("x",0)))+absf(float(input.get("z",0)))>.15
	for key in ["shoot","cross","spin","twostep","behind","hesi","steal","guard","pass","switch"]:active=active or bool(input.get(key,false))
	if active and game.phase!="dead":activity_seconds=minf(600,activity_seconds+delta)
	game.feedback_timer = maxf(0,game.feedback_timer-delta)
	game.crossover_cooldown = maxf(0,game.crossover_cooldown-delta)
	game.steal_cooldown = maxf(0,game.steal_cooldown-delta)
	ai_cooldown = maxf(0,ai_cooldown-delta)
	switch_cooldown = maxf(0,switch_cooldown-delta)
	for i in 6: feint_cooldowns[i] = maxf(0,feint_cooldowns[i]-delta)
	if game.phase != "dead":
		game.clock_left = maxf(0,game.clock_left-delta)
		if game.phase in ["live","pass_windup","pass_flight","takeoff"]:
			game.shot_clock -= delta
			if game.shot_clock <= 0:
				turnover("SHOT CLOCK", "18초 안에 슛을 시도하세요.",1-possession)
				return
		if game.clock_left <= 0 and game.scores[0] != game.scores[1] and game.phase in ["live","pass_windup","pass_flight","loose"]:
			game.finish_match()
			return
	game.update_actions(delta)
	for p in game.players:
		if p.action == "pass" and p.action_time > .50: p.action = "idle"
		if p.action == "receive" and p.transfer_caught and p.action_time > .32:
			p.rebound_release_from = p.ball_anchor(game.time)
			p.rebound_release_left = .20
			p.dribble_phase = 0
			p.action = "idle"
	var direction = Vector2(input.x,input.z).limit_length()
	var desired = (Vector3(game.camera.global_basis.x.x,0,game.camera.global_basis.x.z).normalized()*direction.x+Vector3(game.camera.global_basis.z.x,0,game.camera.global_basis.z.z).normalized()*direction.y)
	if pressed(input,"switch") and switch_cooldown <= 0 and (possession != 0 or game.ball_owner<0):
		selected = (selected+1)%3
		switch_cooldown = .18
		game.announce("SWITCH", "선택한 선수의 발밑 링을 확인하세요.", 1)
	var p = game.players[selected]
	game.held_ball_controls(selected,input,desired,delta)
	p.defending = input.guard and not p.has_ball
	move_actor(selected,desired*float(p.athletic_profile().speed if not input.guard else 2.7),delta)
	if desired.length() > .1 and p.action == "idle":
		p.facing = atan2(desired.x,desired.z)
	elif not p.has_ball and game.ball_owner >= 0: game.face_target(selected,game.players[game.ball_owner].position)
	if game.phase == "live" and game.ball_owner == selected:
		if game.needs_clear and Rules.is_clear(p.position):
			game.needs_clear = false
			game.announce("CLEARED", "이제 공격할 수 있어요.",1)
		if pressed(input,"pass") and (p.action in ["idle","fake"] or p.action=="held_fake" and p.held.can_chain(p)): begin_pass(selected,choose_receiver(selected,desired))
		elif (pressed(input,"shoot") or p.held.pending_shot_left>0) and ((input.cross and p.action_time<.12 and (p.action=="cross" or p.action=="held_fake" and p.held.kind=="pivot")) or p.action == "idle" or p.action=="held_fake" and p.held.can_chain(p) or p.crossing() and p.cross_received):
			if game.needs_clear: game.announce("CLEAR THE BALL", "외곽선 밖으로 공을 가져가세요.")
			else: game.begin_gather(selected,false,game.combo_shot(selected,input,desired),desired)
		if p.action == "gather":
			game.gather_input(selected,input.shoot,delta)
		if p.action == "idle" and not p.dribble_ended and game.crossover_cooldown <= 0:
			for kind in ["cross","spin","twostep","behind","hesi"]:
				if pressed(input,kind):
					dribble(selected,kind,desired)
					break
	elif game.phase in ["live","takeoff","flight","loose"]:
		if pressed(input,"shoot") and p.action == "idle": game.start_defensive_jump(selected,defense_kind())
		if pressed(input,"steal") and game.steal_cooldown <= 0 and game.phase == "live" and possession == 1 and p.action == "idle":
			steal(selected)
			game.steal_cooldown = 1.1
	decisions -= delta
	if decisions <= 0:
		decisions = .18
		decide()
	for i in 6:
		if i == selected: continue
		var actor = game.players[i]
		var offset: Vector3 = goals[i]-actor.position
		offset.y = 0
		var speed = float(actor.athletic_profile().speed)
		var velocity = offset.normalized()*minf(speed,offset.length()*3.5)
		if actor.chase_recovery: velocity *= .68
		move_actor(i,velocity,delta)
		if actor.defending and game.ball_owner >= 0: game.face_target(i,game.players[marks[i]].position)
		elif offset.length() > .2 and actor.action == "idle": actor.facing = atan2(offset.x,offset.z)
	update_boxouts(input.guard)
	separate()
	# Pose the owner first: block/steal targets follow this tick's visible ball.
	var order = range(6) as Array
	if game.ball_owner >= 0:
		order.erase(game.ball_owner)
		order.push_front(game.ball_owner)
	for i in order:
		var actor = game.players[i]
		if actor.action in ["layup","dunk"] and actor.finish_target_valid and actor.action_time <= .82: actor.position = Rules.clamp_to_court(actor.finish_position())
		if actor.stealing() and game.ball_owner >= 0 and team(i) != possession: actor.steal_target = game.players[game.ball_owner].ball_anchor(game.time)
		if actor.defensive_jump():
			if not actor.block_contact: actor.defense_target = game.ball.position
			if actor.action == "block" and game.phase in ["live","takeoff"] and game.ball_owner >= 0:
				actor.defense_target = game.players[game.ball_owner].ball_anchor(game.time)
				actor.defense_target.y = maxf(2.30,actor.defense_target.y)
			actor.position = Rules.clamp_to_court(actor.defense_position())
		if game.phase=="takeoff" and i==game.shooter and game.finish_kind=="shot":
			var progress=clampf((actor.action_time-Actor.SHOT_PLANT_TIME)/(game.release_at-Actor.SHOT_PLANT_TIME),0,1)
			actor.position=game.takeoff_start.lerp(game.takeoff_target,smoothstep(0,1,progress))
		actor.animate(delta,game.time)
	if game.phase == "live":
		game.ball.position = game.players[game.ball_owner].ball_anchor(game.time)
		resolve_steals()
		var holder = game.players[game.ball_owner]
		if holder.ordinary_dribble():
			var beat = int(floor((holder.dribble_phase-TAU*.42)/TAU))
			if beat != game.bounce_index:
				game.bounce_index = beat
				game.play_sound("bounce",-14)
	elif game.phase == "pass_windup": update_pass_windup()
	elif game.phase == "pass_flight": update_pass(delta)
	elif game.phase == "takeoff":
		game.ball.position = game.players[game.shooter].ball_anchor(game.time)
		if not try_block() and game.players[game.shooter].action_time >= game.release_at: game.release_ball()
	elif game.phase == "flight":
		game.update_flight(delta)
		if game.phase=="loose":assist_candidate=-1
	elif game.phase == "loose": update_loose(delta)
	elif game.phase == "dead":
		game.reset_timer -= delta
		game.ball.position.y = maxf(Actor.DRIBBLE_FLOOR,game.ball.position.y-delta*5)
		if game.reset_timer <= 0:
			if Rules.winner(game.scores,game.clock_left,true) >= 0: game.finish_match()
			else: reset(1-team(game.shooter))
	game.previous_ball_position = game.ball.position
	game.impact = maxf(0,game.impact-delta)
	game.update_ball_visual()
	update_labels()
	for action in input: edges[action] = input[action]

func move_actor(index: int, desired: Vector3, delta: float) -> void:
	var p = game.players[index]
	if p.action=="shot":p.shot_exit_intent=Vector2(desired.x,desired.z)
	var velocity = Vector2(desired.x,desired.z)*p.landing_speed_scale()
	if p.action=="pickup":velocity*=.45
	if p.action in ["gather","shot","layup","dunk","block","rebound","pass","receive","fake"] or game.phase == "dead": velocity = Vector2.ZERO
	if p.defensive_jump() and p.action_time >= p.defense_land_time()+.115:
		velocity = Vector2(desired.x,desired.z)*p.landing_speed_scale()*.4
	if p.action == "gather": velocity = p.gather_velocity()
	if p.has_ball and p.dribble_ended: velocity = Vector2.ZERO if p.action!="gather" else p.gather_velocity()
	if p.crossing():
		velocity += Vector2(cos(p.facing),-sin(p.facing))*p.cross_to*2*sin(clampf(p.cross_phase(),0,1)*PI)
	elif p.action in ["spin","twostep","behind","hesi"]:
		var t = p.action_time/game.DRIBBLE_DURATIONS[p.action]
		var forward = Vector2(sin(p.turn_origin),cos(p.turn_origin))
		velocity = forward*(.65 if p.action == "hesi" and t < .43 else 4.1)
		if p.action != "hesi": velocity += Vector2(forward.y,-forward.x)*sin(t*TAU if p.action == "twostep" else t*PI)*2*p.turn_sign
	p.steer_motion(velocity,24 if velocity.length() > .1 else 35,delta)
	game.move_player(index,delta)

func openness(index: int) -> float:
	var distance = 12.0
	for i in 6:
		if team(i) != team(index): distance = minf(distance,game.players[i].position.distance_to(game.players[index].position))
	return distance

func choose_receiver(sender: int, direction: Vector3 = Vector3.ZERO) -> int:
	var best = -1
	var best_score = -INF
	for i in 6:
		if i == sender or team(i) != team(sender) or game.players[i].action != "idle": continue
		var offset: Vector3 = game.players[i].position-game.players[sender].position
		var value = openness(i)*.7-offset.length()*.06
		if direction.length() > .1: value += direction.normalized().dot(offset.normalized())*5
		if value > best_score:
			best = i
			best_score = value
	return best

func begin_pass(sender: int, receiver: int) -> bool:
	if game.phase != "live" or game.ball_owner != sender or receiver < 0 or team(sender) != team(receiver) or receiver == sender: return false
	var p = game.players[sender]
	var r = game.players[receiver]
	if (p.action not in ["idle","fake"] and not (p.action=="held_fake" and p.action_time>=p.held.duration*.6)) or r.action != "idle": return false
	passing_from = sender
	pass_by_user=sender==selected and team(sender)==0
	rebound_live=false
	passing_to = receiver
	game.face_target(sender,r.position)
	game.face_target(receiver,p.position)
	p.transfer_from = game.ball.position
	p.action = "pass"
	p.action_time = 0
	p.dribble_ended = true
	r.action = "receive"
	r.action_time = 0
	r.transfer_caught = false
	r.transfer_target = r.position+Vector3.UP*(1.25*r.height_ratio)+Vector3(sin(r.facing),0,cos(r.facing))*.38
	game.phase = "pass_windup"
	game.announce("MOVE THE BALL", "패스 후 받는 선수로 자동 전환됩니다.",1.2)
	return true

func update_pass_windup() -> void:
	var sender = game.players[passing_from]
	game.ball.position = sender.ball_anchor(game.time)
	if sender.action_time < .22: return
	pass_start = game.ball.position
	pass_target = game.players[passing_to].transfer_target
	pass_time = 0
	pass_duration = clampf(.18+pass_start.distance_to(pass_target)/15,.32,.78)
	sender.has_ball = false
	game.ball_owner = -1
	game.phase = "pass_flight"
	game.last_event = "pass"
	last_touch = passing_from
	game.play_sound("release",-19)

func update_pass(delta: float) -> void:
	pass_time += delta
	var t = clampf(pass_time/pass_duration,0,1)
	var receiver = game.players[passing_to]
	var hands: Vector3 = (receiver.palm_position(0)+receiver.palm_position(1))*.5
	game.ball.position = pass_start.lerp(pass_target.lerp(hands,smoothstep(.55,.90,t)),t)+Vector3.UP*sin(t*PI)*.13
	for i in 6:
		if team(i) == possession: continue
		var p = game.players[i]
		if p.stealing() and p.action_time >= .12 and p.action_time <= .32 and game.hand_ball_distance(p.hand_world,p.previous_hand_world) < .25 and p.hand_world.distance_to(game.ball.position) < .25:
			p.steal_resolved = true
			p.receive_steal(game.ball.position)
			interceptions += 1
			record_contribution(i,"steals")
			claim(i,"INTERCEPTED!")
			receiver.action = "idle"
			return
		if p.action == "idle":
			var lane = Vector2(pass_target.x-pass_start.x,pass_target.z-pass_start.z)
			var offset = Vector2(p.position.x-pass_start.x,p.position.z-pass_start.z)
			var near = clampf(offset.dot(lane)/maxf(lane.length_squared(),.01),.08,.92)
			var contact = pass_start.lerp(pass_target,near)+Vector3.UP*sin(near*PI)*.13
			var remaining = near*pass_duration-pass_time
			var gap = Vector2(contact.x-p.position.x,contact.z-p.position.z).length()
			# Prepare before the flight reaches the body. A reach started only
			# when the ball was nearby always trailed a fast chest pass.
			if remaining > .13 and remaining < .25 and gap < .85:
				game.face_target(i,contact)
				p.prepare_steal(contact,receiver.position,true)
				var forward = Vector3(sin(p.facing),0,cos(p.facing))
				p.steal_end = Rules.clamp_to_court(p.position+forward*clampf(gap-.30,0,.18))
	if t > .72 and game.ball.position.distance_to(hands) < .22 and maxf(receiver.palm_position(0).distance_to(game.ball.position),receiver.palm_position(1).distance_to(game.ball.position)) < .34:
		receiver.transfer_caught = true
		receiver.transfer_target = game.ball.position
		receiver.action_time = 0
		passes += 1
		assist_candidate=passing_from if pass_by_user else -1
		assist_receiver=passing_to
		assist_until=game.time+6.0
		pass_caught = true
		claim(passing_to,"NICE PASS")
		return
	if pass_time > pass_duration+.10:
		receiver.action = "idle"
		game.phase = "loose"
		game.loose_timer = 0
		game.ball_velocity = (pass_target-pass_start).normalized()*4+Vector3.DOWN
		game.last_event = "loose"

func claim(index: int, title: String) -> void:
	var changed = team(index) != possession
	if changed:assist_candidate=-1
	rebound_live=false
	possession = team(index)
	last_touch = index
	game.ball_owner = index
	game.phase = "live"
	for i in 6:
		game.players[i].has_ball = i == index
		game.players[i].boxing_out = false
	game.players[index].dribble_ended = false
	if changed:
		game.shot_clock = 18
		game.needs_clear = not Rules.is_clear(game.players[index].position)
	if team(index) == 0: selected = index
	game.ball.position = game.players[index].ball_anchor(game.time)
	game.previous_ball_position = game.ball.position
	game.announce(title,"외곽선 밖으로 공을 빼세요." if game.needs_clear else "공격을 이어가세요.",1.4)
	game.last_event = "pass" if title == "NICE PASS" else ("steal" if title == "INTERCEPTED!" else "rebound")
	ai_cooldown = .8

func decide() -> void:
	var target: Vector3 = game.rebound_target()
	var carrier: int = game.ball_owner
	if carrier < 0 and game.phase in ["pass_windup","pass_flight"]: carrier = passing_to
	for i in 6:
		var p = game.players[i]
		p.defending = false if i != selected else p.defending
		if game.phase in ["flight","loose"]:
			# Guards protect the outlet; the closest two on each team contest the glass.
			var role_offset = Vector3(-.65 if i%2 == 0 else .65,0,.4)
			goals[i] = target+role_offset if p.court_role != "guard" or p.position.distance_to(target) < 2.2 else Vector3(-3.3 if team(i) == 0 else 3.3,0,-.2)
			if i != selected and game.phase == "loose" and p.action == "idle" and not rebound_blocked(i) and game.ball_velocity.y < -.25:
				var ahead: Vector3 = game.ball.position+game.ball_velocity*.26+Vector3.DOWN*4.9*.26*.26
				if ahead.y > 1.65 and ahead.y < 2.15+p.athletic_profile().rebound_jump and Vector2(ahead.x-p.position.x,ahead.z-p.position.z).length() < .9: game.start_defensive_jump(i,"rebound")
			continue
		if carrier < 0:
			goals[i] = p.position
			continue
		var owner = game.players[carrier]
		if team(i) == possession:
			if i == carrier:
				var lane = Vector3(-1.2 if i%2 else 1.2,0,-4.4)
				goals[i] = Vector3(clampf(p.position.x,-3,3),0,2.2) if game.needs_clear else lane
				if i == selected or game.phase != "live": continue
				if game.needs_clear and Rules.is_clear(p.position): game.needs_clear = false
				if p.action == "gather" and p.action_time > (.20 if p.finish_running else .48): game.launch_shot(i)
				elif p.action == "idle" and ai_cooldown <= 0:
					var receiver = choose_receiver(i)
					if receiver >= 0 and openness(i) < 1.8 and openness(receiver) > openness(i)+.6 and game.shot_clock > 4:
						begin_pass(i,receiver)
						ai_cooldown = 1.5
					elif not game.needs_clear and (p.position.z < -3.0 or game.shot_clock < 4): game.begin_gather(i)
			else:
				goals[i] = offball_goal(i,owner)
		else:
			var mark = marks[i]
			var attack = game.players[mark]
			var gap: Vector3 = attack.position-p.position
			var toward: Vector3 = (Vector3(game.HOOP.x,0,game.HOOP.z)-attack.position).normalized()
			var behind = (p.position-attack.position).dot(toward) < -.25
			goals[i] = attack.position+toward*(1.0 if mark == carrier else .8)
			if mark==carrier:goals[i]+=Vector3(toward.z,0,-toward.x)*sin(game.time*1.4+i)*.20
			if mark != carrier and p.court_role == "center" and owner.position.z < -3.4 and owner.position.distance_to(p.position) < 2.0: goals[i] = owner.position+(Vector3(game.HOOP.x,0,game.HOOP.z)-owner.position).normalized()*.7
			if i != selected: p.defending = gap.length() < 2.4 and not behind and not p.chase_recovery
			if i != selected and p.action == "idle" and not behind and not p.chase_recovery and game.phase == "takeoff" and p.position.distance_to(owner.position) < 1.45 and owner.action_time > .04: game.start_defensive_jump(i,"block")

func offball_goal(index: int,owner) -> Vector3:
	var p=game.players[index]
	var side=-1.0 if index%3==1 else 1.0
	var path: Array
	if p.court_role=="guard":
		path=[Vector3(side*4.8,0,.5),Vector3(side*2.8,0,1.7),Vector3(-side*4.6,0,-.2)]
	elif p.court_role=="forward":
		path=[Vector3(side*4.5,0,-2.2),Vector3(side*1.2,0,-4.6),Vector3(-side*4.5,0,-3.7),Vector3(-side*3.2,0,-1.3)]
	else:
		path=[owner.position+Vector3(side*1.2,0,-1.1),Vector3(side*.9,0,-4.65),Vector3(side*3.3,0,-4.2),Vector3(-side*2.2,0,-2.4)]
	var cursor=int(offball_cursor[index])%path.size()
	if p.court_role=="center" and cursor==0 and owner.position.z<-2.0:cursor=1
	var goal=space_offball_goal(index,path[cursor],owner)
	if p.position.distance_to(goal)<.6:
		if offball_hold[index]<=0:offball_hold[index]=game.time+(.40 if p.court_role=="center" and cursor==0 else .24)
		if game.time>=offball_hold[index]:
			cursor=(cursor+1)%path.size()
			offball_hold[index]=0.0
			goal=space_offball_goal(index,path[cursor],owner)
	else:offball_hold[index]=0.0
	offball_cursor[index]=cursor
	return goal

func space_offball_goal(index: int,point: Vector3,owner) -> Vector3:
	var goal=point
	var side=-1.0 if index%3==1 else 1.0
	if owner.position.z<-3.0 and goal.z<-2.8:
		# Clear the paint for a handler already driving; do not send two cutters
		# and their defenders into the same finishing lane.
		goal.x=side*maxf(3.2,absf(goal.x))
		goal.z=maxf(-4.2,goal.z)
	if goal.distance_to(owner.position)<1.15:goal+=Vector3(side*1.4,0,.5)
	for i in 6:
		if i!=index and i!=game.ball_owner and team(i)==team(index) and goal.distance_to(goals[i])<1.5:goal.x+=side*.8
	return Rules.clamp_to_court(goal)

func dribble(index: int, kind: String, direction: Vector3) -> void:
	var p = game.players[index]
	if kind == "cross": p.prepare_cross(game.ball.position)
	else:
		p.action = kind
		p.action_time = 0
		p.dribble_phase = 0
		p.turn_origin = p.rotation.y if direction.length() < .1 else atan2(direction.x,direction.z)
		p.turn_sign = p.dribble_hand
		if kind == "behind": p.dribble_hand *= -1
	game.crossover_cooldown = p.cross_duration()+.08 if kind == "cross" else game.DRIBBLE_DURATIONS[kind]+.08
	for i in 6:
		if team(i) == team(index): continue
		var defender = game.players[i]
		var gap: Vector3 = p.position-defender.position
		var forward = Vector3(sin(defender.facing),0,cos(defender.facing))
		if defender.action == "idle" and not defender.chase_recovery and feint_cooldowns[i] <= 0 and gap.length() < 2.1 and gap.length() > .6 and gap.normalized().dot(forward) > .35:
			var side = Vector2(cos(p.facing),-sin(p.facing))*p.dribble_hand
			defender.prepare_chase_recovery((defender.motion*.5+side*1.8).limit_length(3.1))
			feint_cooldowns[i] = .9
	game.court_audio.cue(kind)
	game.play_sound("squeak",-13)

func steal(index: int) -> void:
	if game.ball_owner < 0 or team(index) == possession: return
	var p = game.players[index]
	var owner = game.players[game.ball_owner]
	var forward = Vector3(sin(p.facing),0,cos(p.facing))
	p.prepare_steal(game.ball.position,owner.position,Rules.can_steal(owner.position,p.position,forward) and owner.action == "idle")
	p.steal_end = Rules.clamp_to_court(p.steal_end)

func resolve_steals() -> void:
	for i in 6:
		var p = game.players[i]
		if team(i) == possession or not p.stealing() or p.steal_resolved or not p.steal_eligible or p.action_time < .12 or p.action_time > .32: continue
		if game.hand_ball_distance(p.hand_world,p.previous_hand_world) < .25 and p.hand_world.distance_to(game.ball.position) < .25:
			p.steal_resolved = true
			if game.rng.randf() < .65:
				p.receive_steal(game.ball.position)
				record_contribution(i,"steals")
				claim(i,"INTERCEPTED!")
				game.court_audio.cue("steal")
				return

func try_block() -> bool:
	if game.phase not in ["takeoff","flight"]: return false
	for i in 6:
		if team(i) == team(game.shooter): continue
		var p = game.players[i]
		if p.action != "block" or p.action_time < .16 or p.action_time > .40 or not game.block_lane_open(p): continue
		var relative_speed = (p.hand_world.y-p.previous_hand_world.y)/maxf(p.pose_delta,.0001)-p.body_vertical_velocity
		if relative_speed >= -.12 or game.hand_ball_distance(p.hand_world,p.previous_hand_world) >= .28: continue
		p.record_block_contact()
		game.players[game.shooter].has_ball = false
		game.ball_owner = -1
		game.phase = "loose"
		game.loose_timer = 0
		game.ball_velocity = p.block_contact_stroke.normalized()*9.2
		last_touch = i
		blocks += 1
		record_contribution(i,"blocks")
		rebound_live=true
		game.last_event = "block"
		game.court_audio.cue("block")
		game.play_sound("block",-7)
		game.announce("GET THAT OUT!", "손바닥으로 쳐냈습니다! 튕겨 나간 공을 따라가세요.")
		return true
	return false

func update_boxouts(guard: bool) -> void:
	var active = game.phase in ["flight","loose"]
	var target: Vector3 = game.rebound_target()
	for i in 6:
		var p = game.players[i]
		p.boxing_out = false
		p.contesting_boxout = false
		p.contact_pressure = 0
		if not active or p.action != "idle" or p.has_ball or i == selected and not guard: continue
		var opponent = game.players[marks[i]]
		if Rules.can_box_out(p.position,opponent.position,target):
			p.boxing_out = true
			p.contact_direction = (opponent.position-p.position).normalized()
			p.facing = atan2(-p.contact_direction.x,-p.contact_direction.z)
			p.watch_direction = target-p.position
			p.contact_pressure = clampf((1.1-p.position.distance_to(opponent.position))/.35,0,1)
	for i in 6: game.players[i].contesting_boxout = rebound_blocked(i)

func rebound_blocked(index: int) -> bool:
	for j in 6:
		if team(j) != team(index) and game.players[j].boxing_out and Rules.can_box_out(game.players[j].position,game.players[index].position,game.rebound_target()): return true
	return false

func separate() -> void:
	for i in 6:
		for j in range(i+1,6):
			var a = game.players[i]
			var b = game.players[j]
			if a.jump > .25 or b.jump > .25: continue
			var offset: Vector3 = a.position-b.position
			var distance = offset.length()
			var contact_distance=.73
			if team(i)!=team(j):contact_distance+=maxf(a.guard_contact_extra(b),b.guard_contact_extra(a))
			if distance >= contact_distance: continue
			var normal = offset.normalized() if distance > .001 else Vector3.RIGHT
			var push = normal*(contact_distance-distance)
			var weight = .5
			if a.boxing_out: weight = .12/a.athletic_profile().box_strength
			elif b.boxing_out: weight = 1-.12/b.athletic_profile().box_strength
			if a.action in ["pass","receive"] or a.has_ball and a.dribble_ended: weight = 0
			elif b.action in ["pass","receive"] or b.has_ball and b.dribble_ended: weight = 1
			a.position = Rules.clamp_to_court(a.position+push*weight)
			b.position = Rules.clamp_to_court(b.position-push*(1-weight))

func update_loose(delta: float) -> void:
	game.loose_timer += delta
	var previous=game.ball.position
	game.ball_velocity.y -= 9.8*delta
	game.ball.position += game.ball_velocity*delta
	if game.ball.position.y < Actor.DRIBBLE_FLOOR:
		game.ball.position.y = Actor.DRIBBLE_FLOOR
		game.ball_velocity = Vector3(game.ball_velocity.x*.76,absf(game.ball_velocity.y)*.56,game.ball_velocity.z*.76)
		game.play_sound("bounce",-15)
	if Rules.ball_outside(game.ball.position):
		turnover("OUT OF BOUNDS", "체크볼로 다시 시작합니다.",1-team(last_touch))
		return
	var candidates: Array = []
	for i in 6:
		var p = game.players[i]
		var distance = game.hand_ball_distance(p.rebound_anchor(),p.previous_rebound_anchor)
		var both = maxf(game.ball.position.distance_to(p.palm_position(0)),game.ball.position.distance_to(p.palm_position(1))) < .34
		var air = p.action == "rebound" and p.jump > .18 and p.action_time > .16 and p.action_time < p.defense_land_time() and distance < .24 and both
		var contact=game.loose_contact(p,previous)
		if contact<1.0 or air and not rebound_blocked(i): candidates.append({"id":i,"distance":distance if air else contact,"air":air})
	if not candidates.is_empty():
		candidates.sort_custom(func(a,b): return a.distance < b.distance if a.distance != b.distance else a.id < b.id)
		var winner = candidates[0]
		if rebound_live:
			record_contribution(winner.id,"rebounds")
			rebounds+=1
		if winner.air:
			game.players[winner.id].capture_rebound(game.ball.position,game.ball_velocity)
			game.court_audio.cue("rebound")
		else:game.players[winner.id].begin_pickup(game.ball.position)
		if team(winner.id) == possession: game.shot_clock = maxf(game.shot_clock,12)
		claim(winner.id,"AIR CATCH!" if winner.air else "LOOSE BALL")
	elif game.loose_timer > 8: turnover("CHECK BALL", "체크볼로 다시 시작합니다.",1-possession)

func contest(shooter: int) -> float:
	var value = 0.0
	for i in 6:
		if team(i) == team(shooter): continue
		var defender = game.players[i]
		var pressure = clampf(1-game.players[shooter].position.distance_to(defender.position)/2.15,0,1)
		value = maxf(value,pressure+(.15 if defender.action == "block" else 0))
	return minf(value,1)

func register_score() -> void:
	if game.last_scored_event == game.event_id: return
	game.last_scored_event = game.event_id
	if team(game.shooter)==0:
		if human_shooter:controlled_stats.points+=game.flight_points
		if assist_candidate>=0 and assist_receiver==game.shooter and game.time<=assist_until:controlled_stats.assists+=1
	assist_candidate=-1
	rebound_live=false
	game.scores[team(game.shooter)] += game.flight_points
	if team(game.shooter) == 0: game.makes += 1
	game.phase = "dead"
	game.reset_timer = 1.5
	game.last_event = "score"
	game.court_audio.cue(game.finish_kind if game.finish_kind in ["layup","dunk"] else "three" if game.flight_points == 3 else "score")
	game.play_sound("swish",-6)
	game.announce("TEAM BUCKET!" if team(game.shooter) == 0 else "RIVAL BUCKET", "다음 공격은 상대 팀 체크볼입니다.",1.5)
	if game.finish_kind == "dunk": game.play_sound("slam",-5)

func turnover(title: String, subtitle: String, next_team: int) -> void:
	reset(next_team)
	game.announce(title,subtitle,2)
	game.last_event = "turnover"
	game.play_sound("whistle",-16)

func update_labels() -> void:
	var changed=marker_selection!=selected or marker_owner!=game.ball_owner
	marker_selection=selected
	marker_owner=game.ball_owner
	for i in 6:
		var p = game.players[i]
		p.marker.visible = i == selected or i == game.ball_owner
		if changed:
			for part in p.marker.find_children("*","MeshInstance3D",true,false):part.material_override=CourtArt.material("fff0a6" if i==selected else "ed9a6a")
		labels[i].position = p.position+Vector3.UP*.28
		var text=("YOU · " if i == selected else "")+{"guard":"G","forward":"F","center":"C"}[p.court_role]
		if label_sources[i]!=text:
			label_sources[i]=text
			labels[i].text=text
			labels[i].modulate = Color("fff0a6") if i == selected else Color("b8f1dd") if team(i) == 0 else Color("ffbc9c")

func decorate_state(state: Dictionary) -> void:
	var p = game.players[selected]
	state.owner = 0 if game.ball_owner == selected else 1 if game.ball_owner >= 3 else 2 if game.ball_owner >= 0 else -1
	state["selectedPlayer"] = selected
	state["canSwitchDefender"]=possession!=0 or game.ball_owner<0
	state["ballPlayer"] = game.ball_owner
	state["possessionTeam"] = possession
	state["roster"] = game.players.map(func(actor): return {"role":actor.court_role,"height":roundi(float(actor.growth.get("height",185))),"x":snappedf(actor.position.x,.01),"z":snappedf(actor.position.z,.01),"action":actor.action})
	state.action = p.action
	state.player = [p.position.x,p.position.z]
	state.charge = game.shot_hold/.62 if p.action == "gather" else 0
	state.finish = (p.shot_style if p.shot_style!="jumper" else p.finish_kind) if p.action in ["gather","shot"] else Rules.finish_type(p.position,p.motion)
	if p.has_ball and p.dribble_ended and p.action not in ["gather","shot"]:state.finish="shot"
	state.sweet = Rules.release_bonus(game.shot_hold) > 0 and p.action == "gather"
	state.held = p.has_ball and p.dribble_ended
	state.boxout = p.boxing_out
	state.guard = p.defending and p.action == "idle" and not p.has_ball
	state.secured = p.action == "rebound" and p.defense_caught
	state.courtRole = p.court_role
	state.canChangeRole = false
	state.defenseAction = defense_kind() if not p.has_ball and game.phase in ["live","takeoff","flight","loose"] else ""
	state.reboundWindow = state.defenseAction == "rebound"
	state["teamPasses"] = passes
	state["teamInterceptions"] = interceptions
	state["teamRebounds"] = rebounds
	state["teamBlocks"] = blocks
	state["careerStats"]=controlled_stats.duplicate()
	state.careerStats["activeSeconds"]=floori(activity_seconds)

func record_contribution(index: int, key: String, amount: int=1) -> void:
	if index==selected and team(index)==0:controlled_stats[key]+=amount

func capture_shot(index: int) -> void:
	human_shooter=index==selected and team(index)==0
	rebound_live=true
