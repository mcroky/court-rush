extends SceneTree
var failures = 0
var catches = 0
var swats = 0
var game
func _init(): call_deferred("run")
func check(ok: bool, label: String):
	if not ok:
		failures += 1
		push_error(label)
func run():
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.sound_enabled = false
	game.start_mode("team")
	var t = game.team_match
	for fps in [30,60]:
		var dt = 1.0/fps
		for index in 6:
			t.reset(1-t.team(index))
			for i in 6:
				game.players[i].has_ball = false
				game.players[i].position = Vector3(5,0,3+i*.3)
				game.players[i].reset_stance()
				game.players[i].animate(dt,game.time)
				t.goals[i] = game.players[i].position
			var p = game.players[index]
			p.position = Vector3(0,0,-3.65)
			p.facing = PI
			p.rotation.y = PI
			p.reset_stance()
			p.animate(dt,game.time)
			t.goals[index] = p.position
			t.decisions = 99
			game.phase = "loose"
			game.ball_owner = -1
			game.shooter = 3 if index < 3 else 0
			game.ball.position = p.position+Vector3(0,3.15,-.28)
			game.previous_ball_position = game.ball.position
			game.ball_velocity = Vector3(0,-.3,.15)
			game.loose_timer = 0
			for f in int(round(.10*fps)): game._physics_process(dt)
			game.start_defensive_jump(index,"rebound")
			var caught = false
			for f in fps:
				game._physics_process(dt)
				if p.defense_caught:
					caught = true
					check(game.ball_owner == index,"Caught rebound ownership used legacy two-player index")
					check(game.players.filter(func(actor): return actor.has_ball).size() == 1,"Two owners in a six-player rebound")
			check(caught,"Missing air catch for slot %d / %dfps" % [index,fps])
			if caught: catches += 1
			# Every defending slot uses the same actual downward palm contact.
			t.reset(1-t.team(index))
			p = game.players[index]
			p.position = Vector3(0,0,-3.5)
			p.has_ball = false
			p.facing = 0
			p.rotation.y = 0
			p.reset_stance()
			p.animate(dt,game.time)
			game.shooter = 3 if index < 3 else 0
			game.players[game.shooter].position = Vector3(0,0,-.5)
			p.prepare_defense("block",p.position+Vector3(0,2.5,.40))
			for f in int(round(.30*fps)):
				p.action_time += dt
				p.jump = p.defense_height()
				p.position = p.defense_position()
				p.animate(dt,game.time)
			game.phase = "flight"
			game.ball.position = p.hand_world
			game.previous_ball_position = p.previous_hand_world
			var contact = t.try_block()
			check(contact,"Missing swat from slot %d / %dfps" % [index,fps])
			if contact: swats += 1
			check(game.phase == "loose" and game.ball_owner == -1 and game.ball_velocity.y < -5,"Swat did not atomically detach and deflect ball")
	print("TEAM_CONTACT catches=",catches," swats=",swats," failures=",failures)
	game.queue_free()
	quit(1 if failures else 0)

