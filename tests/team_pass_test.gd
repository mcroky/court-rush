extends SceneTree
var game
var failures = 0
var catches = 0
var intercepts = 0
func _init(): call_deferred("run")
func check(ok: bool, label: String):
	if not ok:
		failures += 1
		push_error(label)
func setup(t, sender: int, receiver: int):
	t.reset(t.team(sender))
	t.decisions = 99
	for i in 6:
		var p = game.players[i]
		p.position = Vector3(5,0,-5+i*.35)
		if i == sender: p.position = Vector3(-2,0,0)
		if i == receiver: p.position = Vector3(2,0,0)
		p.reset_stance()
		p.animate(.016,game.time)
		t.goals[i] = p.position
	game.ball_owner = sender
	for i in 6: game.players[i].has_ball = i == sender
	game.ball.position = game.players[sender].ball_anchor(game.time)
	game.previous_ball_position = game.ball.position
	t.selected = sender if sender < 3 else 0
func run():
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.sound_enabled = false
	game.start_mode("team")
	var t = game.team_match
	for fps in [30,60]:
		for sender in 6:
			var receiver = (sender+1)%3+3*t.team(sender)
			setup(t,sender,receiver)
			var before = t.passes
			check(t.begin_pass(sender,receiver),"legal pass rejected")
			var received = false
			var flight_seen = false
			for frame in fps*2:
				game._physics_process(1.0/fps)
				if game.phase == "pass_flight":
					flight_seen = true
					check(game.ball_owner == -1 and game.players.filter(func(p): return p.has_ball).is_empty(),"pass has a premature owner")
				if t.passes > before:
					received = true
					check(game.ball_owner == receiver,"wrong pass receiver")
					break
			check(received and flight_seen,"missing visible pass flight and catch: slot %d / %dfps" % [sender,fps])
			if received: catches += 1
	for z in [-.45,-.30,-.15,0.0,.15,.30,.45]:
		setup(t,0,1)
		var defender = game.players[5]
		defender.position = Vector3(0,0,z)
		defender.reset_stance()
		defender.animate(.016,game.time)
		t.goals[5] = defender.position
		var before = t.interceptions
		t.begin_pass(0,1)
		for frame in 90:
			game._physics_process(1.0/60)
			if t.interceptions > before:
				intercepts += 1
				check(game.ball_owner == 5 and t.possession == 1 and game.needs_clear,"interception failed to transfer team possession/clear requirement")
				check(game.players.filter(func(p): return p.has_ball).size() == 1,"interception produced two owners")
				break
	check(intercepts > 0,"passing through a reachable defender never produced actual hand interception")
	for shooter in 6:
		setup(t,shooter,(shooter+1)%3+3*t.team(shooter))
		var before: int = game.scores[t.team(shooter)]
		game.begin_gather(shooter)
		for frame in 25:
			game._physics_process(1.0/60)
			# The human-controlled gather can fake on a released D; start the
			# shot below from the same real gather/palm state for every slot.
		game.players[shooter].finish_kind = "shot"
		game.launch_shot(shooter)
		var released = false
		for frame in 160:
			game._physics_process(1.0/60)
			if game.phase == "flight":
				released = true
				game.flight_made = true
			if game.scores[t.team(shooter)] > before: break
		check(released and game.scores[t.team(shooter)] == before+game.flight_points,"shot release/score failed from six-player slot %d" % shooter)
	print("TEAM_PASS catches=",catches," lane_intercepts=",intercepts," failures=",failures)
	game.queue_free()
	quit(1 if failures else 0)
