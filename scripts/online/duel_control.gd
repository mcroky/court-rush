extends RefCounted
## A controller owns only one slot's intentions; the match owns the ball and clock.
const Rules = preload("res://scripts/rules.gd")
const Movement=preload("res://scripts/online/movement_prediction.gd")
var edges: Dictionary = {}
var cross_cooldown = 0.0
var steal_cooldown = 0.0
var cross_direction = Vector3.ZERO
var skill_forward = Vector3.FORWARD
var skill_side = Vector3.RIGHT

static func neutral() -> Dictionary:
	return {"x":0.0,"z":0.0,"shoot":false,"shoot_pressed":false,"cross":false,"spin":false,"twostep":false,"behind":false,"hesi":false,"steal":false,"guard":false}

func pressed(input: Dictionary, key: String) -> bool:
	return bool(input.get(key,false)) and not bool(edges.get(key,false))

func tick(game, index: int, input: Dictionary, delta: float) -> void:
	var p = game.players[index]
	var opponent = game.players[1-index]
	cross_cooldown = maxf(0,cross_cooldown-delta)
	steal_cooldown = maxf(0,steal_cooldown-delta)
	var desired = Vector3(float(input.x),0,float(input.z)).limit_length()
	p.defending = bool(input.guard) and not p.has_ball
	game.held_ball_controls(index,input,desired,delta)
	if p.action == "shot": p.shot_exit_intent = Vector2(desired.x,desired.z)*p.athletic_profile().speed
	var speed: float = p.athletic_profile().speed if not input.guard else 2.7
	if p.action == "pickup": speed *= .45
	if p.defending and p.boxing_out: speed = 1.7
	if p.action in ["gather","shot","layup","dunk","fake","block","rebound"]: speed *= .16
	if game.phase == "dead" or game.phase == "takeoff" and game.shooter == index: speed = 0
	var velocity = Movement.target(desired.x,desired.z,speed)*p.landing_speed_scale()
	if p.crossing():
		velocity += Vector2(cross_direction.x,cross_direction.z)*2.8*sin(clampf((p.cross_phase()-.35)/.65,0,1)*PI)
		velocity = velocity.limit_length(6.5)
	elif p.action in ["spin","twostep","behind","hesi"]:
		var t: float = p.action_time/game.DRIBBLE_DURATIONS[p.action]
		var movement = skill_forward*(2.8+sin(t*PI)*1.4)
		if p.action == "spin": movement += skill_side*sin(t*TAU)*2.2
		elif p.action == "twostep": movement += skill_side*(2.7 if t<.5 else -2.7)*sin(fposmod(t*2,1)*PI)
		elif p.action == "behind": movement += skill_side*sin(t*PI)*2.3
		else: movement = skill_forward*(.65 if t<.43 else 5.7)
		velocity = Vector2(movement.x,movement.z)
	p.steer_motion(velocity,24 if desired.length()>.0 else 35,delta)
	if p.has_ball and p.dribble_ended: p.motion = p.gather_velocity() if p.action=="gather" else Vector2.ZERO
	if not (game.phase == "takeoff" and game.shooter == index): game.move_player(index,delta)
	if not p.defensive_jump() and not p.stealing():
		if not p.has_ball and (p.defending or desired.length()<.1): game.face_target(index,opponent.position)
		elif desired.length()>.1 and p.action not in ["gather","shot","layup","dunk","fake","spin","twostep","behind","hesi"]: p.facing = atan2(desired.x,desired.z)
	if game.phase == "live" and game.ball_owner == index:
		if game.needs_clear and Rules.is_clear(p.position): game.needs_clear=false
		var combo = input.cross and p.action_time<.12 and (p.action=="cross" or p.action=="held_fake" and p.held.kind=="pivot")
		var can_shoot = combo or p.action=="idle" or p.action=="held_fake" and p.held.can_chain(p) or p.crossing() and p.cross_received or p.action in game.DRIBBLE_DURATIONS and p.action!="cross" and p.action_time>=game.DRIBBLE_DURATIONS[p.action]*.55
		if (pressed(input,"shoot") or input.get("shoot_pressed",false) or p.held.pending_shot_left>0) and can_shoot and not game.needs_clear:
			game.begin_gather(index,false,game.combo_shot(index,input,desired),desired)
		if p.action=="gather": game.gather_input(index,input.shoot,delta)
		if p.action=="idle" and not p.dribble_ended and cross_cooldown<=0:
			for kind in ["cross","spin","twostep","behind","hesi"]:
				if pressed(input,kind):
					if kind=="cross":
						p.prepare_cross(game.ball.position)
						cross_direction = Vector3(cos(p.facing),0,-sin(p.facing))*p.cross_to
						cross_cooldown=p.cross_duration()+maxf(.015,.08-p.skill_rank("cross")*.01-clampf(float(p.growth.get("handle",50))-50,-20,40)*.0007)
					else:
						p.action=kind; p.action_time=0; p.dribble_phase=0
						p.turn_origin=p.rotation.y; p.turn_sign=p.dribble_hand
						skill_forward=desired.normalized() if desired.length()>.1 else Vector3(sin(p.facing),0,cos(p.facing))
						skill_side=Vector3(skill_forward.z,0,-skill_forward.x)*p.dribble_hand
						p.facing=p.turn_origin if kind=="spin" else atan2(skill_forward.x,skill_forward.z)
						if kind=="behind": p.dribble_hand *= -1
						cross_cooldown=game.DRIBBLE_DURATIONS[kind]+maxf(.015,.06-p.skill_rank("spin")*.009-clampf(float(p.growth.get("handle",50))-50,-20,40)*.0007)
					break
	elif game.phase in ["live","takeoff","flight","loose"]:
		if (pressed(input,"shoot") or input.get("shoot_pressed",false)) and p.action=="idle": game.start_defensive_jump(index,game.defense_kind(index))
		if pressed(input,"steal") and steal_cooldown<=0 and game.phase=="live" and game.ball_owner==1-index and p.action=="idle":
			steal_cooldown=1.1
			var forward=Vector3(sin(p.facing),0,cos(p.facing))
			var target=game.ball.position if (game.ball.position-p.position).dot(forward)>0 else p.position+forward*.8+Vector3.UP
			p.prepare_steal(target,opponent.position,Rules.can_steal(opponent.position,p.position,forward) and opponent.action=="idle")
			p.steal_end=Rules.clamp_to_court(p.steal_end)
	edges=input.duplicate()
