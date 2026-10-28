extends RefCounted
## Event-driven drill objectives; uses the ordinary rendered hand/ball contacts.
var game
var config: Dictionary = {}
var active = false
var value = 0
var rounds = 0
var round_time = 0.0
var rest = -1.0
var settled = false

func _init(owner_game) -> void:
	game=owner_game

func start(data: Dictionary) -> void:
	config=data.challenge.duplicate(true)
	active=true;value=0;rounds=0;rest=-1;round_time=0
	game.clock_left=float(config.seconds)
	if config.kind=="two_one":
		game.team_match.configure_one_vs_two()
		for i in 2:game.players[i+3].apply_athlete(data.opponents[i])
		game.team_match.reset(0)
	else: next_round()
	game.announce(str(config.tag),str(config.description),5)

func next_round() -> void:
	rest=-1;round_time=0;settled=false
	game.reset_positions(1 if config.kind=="steal" else 0)
	var p=game.players[0]
	var rival=game.players[1]
	game.practice_drill="free"
	if config.kind in ["free_throw","three"]:
		var spots=[Vector3(-6.85,0,-4.5),Vector3(-5.6,0,-.9),Vector3(0,0,1.65),Vector3(5.6,0,-.9),Vector3(6.85,0,-4.5)]
		p.position=Vector3(0,0,-1.05) if config.kind=="free_throw" else spots[(rounds/2) as int % 5]
		game.face_target(0,game.HOOP)
		# Mark the set-shot stance; movement is locked only during these drills.
		p.rotation.y=p.facing
	elif config.kind=="rebound":
		game.practice_drill="rim"
		p.position=Vector3(-.45,0,-3.8)
		rival.position=Vector3(.75,0,-3.1)
		p.has_ball=false;rival.has_ball=false
		game.ball_owner=-1;game.shooter=1
		game.phase="flight";game.event_id+=1
		game.flight_start=Vector3(2.7,3.7,-1.1)
		game.flight_target=game.HOOP+Vector3(game.rng.randf_range(-.16,.16),.06,.20)
		game.flight_t=0;game.flight_duration=1.25;game.flight_arc=1.4;game.flight_made=false
		game.ball.position=game.flight_start
		game.ai_freeze=maxf(0,1.25-float(config.tier)*.18)
	elif config.kind=="steal":
		game.practice_drill="steal"
		p.position=Vector3(-.35,0,-2.3)
		rival.position=Vector3(0,0,-1.15)
		game.face_target(0,rival.position);game.face_target(1,game.HOOP)
		game.ball.position=rival.ball_anchor(game.time)
	for actor in game.players:
		actor.visible=actor==p or config.kind in ["rebound","steal"]
		actor.feet_world.clear();actor.animate(.016,game.time)
	if config.kind in ["free_throw","three"]:game.ball.position=p.ball_anchor(game.time)
	game.previous_ball_position=game.ball.position

func tick(delta: float) -> bool:
	if not active or game.phase=="ended":return false
	if config.kind=="two_one":return false # Ordinary team clock, contact and score rules.
	game.clock_left=maxf(0,game.clock_left-delta)
	if rest>=0:
		rest+=delta;game.time+=delta
		game.feedback_timer=maxf(0,game.feedback_timer-delta)
		game.update_actions(delta)
		for i in game.players.size():
			var actor=game.players[i]
			if not actor.visible:continue
			actor.steer_motion(Vector2.ZERO,20,delta)
			if actor.defensive_jump():actor.position=game.Rules.clamp_to_court(actor.defense_position())
			else:game.move_player(i,delta)
			actor.animate(delta,game.time)
		if game.ball_owner>=0:game.ball.position=game.players[game.ball_owner].ball_anchor(game.time)
		else:game.ball.position.y=maxf(game.Actor.DRIBBLE_FLOOR,game.ball.position.y-delta*3)
		game.update_ball_visual()
		if rest>=1.65 and (game.players[0].action=="idle" or game.clock_left<=0):
			if rounds>=int(config.rounds) or game.clock_left<=0:finish()
			else:next_round()
		return true
	if game.clock_left<=0:finish();return true
	round_time+=delta
	if round_time> (9.0 if config.kind=="steal" else 10.0):complete(false)
	return rest>=0

func filter_input(input: Dictionary) -> void:
	if not active or config.kind not in ["free_throw","three"]:return
	input.x=0;input.z=0
	if game.ball_owner!=0:input.shoot=false;input.shoot_pressed=false
	for key in ["cross","spin","twostep","behind","hesi","steal","guard","pass","switch"]:input[key]=false

func complete(success: bool) -> void:
	if not active or rest>=0 or config.kind=="two_one":return
	# A timed-out gather needs its normal ball-protection recovery. Merely
	# advancing action_time never releases gather and would stall the rack.
	if game.players[0].action=="gather":game.fake_shot(0)
	rounds+=1;value+=int(success);rest=0
	game.announce("GOOD!" if success else "NEXT TRY", "%d / %d" % [value,int(config.target)],1.4)

func shot_result(made: bool) -> void:
	if active and config.kind in ["free_throw","three"]:
		complete(made and (config.kind!="three" or game.flight_points==3))

func catch_result(index: int, air: bool) -> void:
	if active and config.kind=="rebound":complete(index==0 and air)

func steal_result() -> void:
	if active and config.kind=="steal":complete(true)

func finish() -> void:
	if game.phase=="ended":return
	game.scores=[value,int(config.target)]
	game.phase="ended";game.ball_owner=-1
	for actor in game.players:actor.has_ball=false
	game.announce("CHALLENGE CLEAR" if value>=int(config.target) else "TRY AGAIN","%d / %d" % [value,int(config.target)],99)
	game.last_event="finished";game.play_sound("whistle",-9);game.send_state()

func state() -> Dictionary:
	return {"kind":config.kind,"tier":config.tier,"name":config.name,"target":config.target,"value":value,"rounds":rounds,"total":config.rounds,"ready":rest<0,"won":game.scores[0]>game.scores[1] if config.kind=="two_one" else value>=int(config.target)}
