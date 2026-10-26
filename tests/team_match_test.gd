extends SceneTree
var game
var failures = 0
var checks = 0
func _init(): call_deferred("run")
func check(value: bool, label: String):
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL: "+label)
	else: print("PASS: "+label)
func ticks(count: int):
	for i in count: game._physics_process(1.0/60.0)
func run():
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.sound_enabled = false
	game.players[0].court_role = "center"
	game.start_mode("team")
	var t = game.team_match
	check(game.players.size() == 6,"six actors enter the team court")
	check(game.players.all(func(p): return p.visible),"all six visible")
	check(game.players[0].court_role == "center" and game.players[0].growth.height == 204,"chosen position retains role height")
	check(game.players.slice(0,3).map(func(p): return p.court_role).has("guard") and game.players.slice(0,3).map(func(p): return p.court_role).has("forward"),"balanced G/F/C friendly roster")
	check(game.career_match_id.is_empty() and game.clock_left == 180,"no career ticket; three minute team clock")
	check(t.team(0) == 0 and t.team(2) == 0 and t.team(3) == 1 and t.team(5) == 1,"player and team IDs distinct")
	t.reset(1)
	ticks(2)
	var old_selection = t.selected
	Input.action_press("team_switch")
	ticks(1)
	Input.action_release("team_switch")
	check(t.selected != old_selection,"E action changes the controlled defender")
	var selected_after = t.selected
	Input.action_press("team_switch")
	ticks(1)
	Input.action_release("team_switch")
	check(t.selected == selected_after,"switch cooldown prevents repeated cycling")
	ticks(4)
	# Open chest pass: keep the lane clear, but keep real render palms/poses active.
	t.reset(0)
	for i in range(3,6): game.players[i].position = Vector3(5,0,-5+i*.4)
	game.players[0].position = Vector3(-2,0,0)
	game.players[1].position = Vector3(1.5,0,0)
	for p in game.players:
		p.reset_stance()
		p.animate(.016,game.time)
	game.ball.position = game.players[0].ball_anchor(game.time)
	check(t.begin_pass(0,1),"pass begins from current owner")
	check(game.ball_owner == 0 and game.players[0].action == "pass","sender owns through windup")
	for i in 90:
		game._physics_process(1.0/60.0)
		if t.passes > 0: break
	check(t.passes == 1 and game.ball_owner == 1 and t.selected == 1,"visible receiver catches and becomes controlled")
	check(game.players[1].action == "receive" and game.players[1].transfer_caught,"two-hand catch has a chest tuck phase")
	check(game.ball.position.distance_to((game.players[1].palm_position(0)+game.players[1].palm_position(1))*.5) < .02,"caught ball follows rendered palms")
	check(game.players.filter(func(p): return p.has_ball).size() == 1,"one atomic owner after pass")
	ticks(35)
	check(game.players[1].action == "idle" and not game.players[1].dribble_ended,"catch recovers into legal dribble")
	# Any friendly slot can score; an event can score only once.
	game.shooter = 2
	game.event_id += 1
	game.flight_points = 2
	t.register_score()
	t.register_score()
	check(game.scores == [2,0],"forward/center score credits team once")
	ticks(94)
	check(t.possession == 1 and game.ball_owner == 3,"made basket gives opposing team check ball")
	var shoot_before = game.event_id
	ticks(660)
	check(game.event_id > shoot_before or t.passes > 1,"opponent team creates offense")
	# Change team via rebound/pickup requires clearing; same-team reception does not reset clock.
	t.reset(1)
	game.players[2].position = Vector3(0,0,-3)
	t.claim(2,"LOOSE BALL")
	check(t.possession == 0 and game.needs_clear and game.ball_owner == 2,"defensive possession must clear beyond arc")
	game.shot_clock = 7
	t.claim(1,"NICE PASS")
	check(game.needs_clear and game.shot_clock == 7,"same-team pass preserves clear requirement and clock")
	game.players[1].position = Vector3(0,0,2.3)
	ticks(1)
	check(not game.needs_clear,"controlled receiver clears from outside arc")
	t.reset(0)
	game.shot_clock = .005
	ticks(1)
	check(t.possession == 1,"team shot clock changes possession")
	game.clock_left = .005
	game.scores = [6,4]
	ticks(1)
	check(game.phase == "ended","team game ends with both-team score comparison")
	game.start_mode("team")
	var before = game.clock_left
	game.set_paused(true)
	ticks(10)
	check(game.clock_left == before,"pause freezes six-player simulation")
	game.start_mode("duel")
	check(game.players.size() == 2 and game.players[1].is_opponent,"legacy one-on-one roster restored")
	check(t.extras.all(func(p): return not p.visible),"team-only actors hidden outside mode")
	game.start_mode("practice")
	check(game.players.size() == 2 and not game.players[1].visible,"practice restored without team actors")
	print("TEAM_MATCH_TEST_COMPLETE checks=",checks," failures=",failures)
	game.queue_free()
	quit(1 if failures else 0)
