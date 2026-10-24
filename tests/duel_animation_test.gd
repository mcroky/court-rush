extends SceneTree

var failures = 0
func _init() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.sound_enabled = false
	game.start_mode("duel")
	var p = game.players[0]
	var ai = game.players[1]
	p.position = Vector3(0,0,0)
	ai.position = Vector3(0,0,-1.4)
	ai.facing = 0
	ai.motion = Vector2(1,0)
	game.ai_freeze = 0
	game.defender_feint(Vector3.RIGHT)
	check(game.ai_reaction > 0 and game.ai_freeze == 0, "Feint should cause a weight shift, not freeze")
	check(game.ai_reaction_velocity.x > 1, "Defender momentum should continue into feint")
	var reaction = game.ai_reaction_velocity
	game.defender_feint(Vector3.LEFT)
	check(game.ai_reaction_velocity == reaction, "Repeated moves should not restart reaction immediately")
	for i in range(60): game._physics_process(1.0/60)
	check(game.ai_reaction == 0 and ai.motion.length() > .05, "Defender should recover and track the attacker")
	ai.position = Vector3(5,0,0)
	game.ai_reaction_cooldown = 0
	game.defender_feint(Vector3.RIGHT)
	check(game.ai_reaction == 0, "Distant defender should not react to a move")
	p.position = Vector3(0,0,0)
	ai.position = Vector3(0,0,-.6)
	p.motion = Vector2(2,-4)
	ai.motion = Vector2.ZERO
	p.jump = 0
	ai.jump = 0
	game.separate_players()
	check(p.position.distance_to(ai.position) >= .699, "Contact must resolve overlap")
	check(absf(p.motion.y) < .01 and absf(p.motion.x-2) < .01, "Contact should stop inward motion and preserve the side exit")
	check(ai.position.distance_to(Vector3(0,0,-.6)) < .03, "Attacker must not shove the defender along")
	game.start_mode("practice")
	p.position = Vector3.ZERO
	p.rotation.y = 0
	p.facing = 0
	p.feet_world.clear()
	p.action = "behind"
	p.dribble_hand = 1
	for frame in range(30):
		p.action_time = frame / 60.0
		p.animate(1.0/60, frame/60.0)
		check(p.hands[0].position.x < 0 and p.hands[1].position.x > 0, "Behind-back hand crossed the torso")
		if frame == 14: check(p.dribble_local().z < -.45, "Behind-back bounce must clear the hips")
	# Root motion must have a continuous velocity at ball release.
	p.position = Vector3(0,0,-3.9)
	p.motion = Vector2(0,-3)
	game.begin_gather(0)
	game.launch_shot(0)
	var t = p.air_release_time
	p.action_time = t - .0001
	var a = p.finish_position()
	p.action_time = t
	var b = p.finish_position()
	p.action_time = t + .0001
	var c = p.finish_position()
	check(((b-a)/.0001 - (c-b)/.0001).length() < .03, "Finish stops or changes velocity abruptly at release")
	print("DUEL_ANIMATION feint/recovery, contact, behind-back hands, finish continuity; failures=", failures)
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
