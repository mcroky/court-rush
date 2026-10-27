extends Node3D

const Actor = preload("res://scripts/actor.gd")
const TeamMatch = preload("res://scripts/team_match.gd")
var team_match
const Art = preload("res://scripts/art.gd")
const Rules = preload("res://scripts/rules.gd")
const CourtAudio = preload("res://scripts/court_audio.gd")
const HOOP = Vector3(0, 3.05, -5.65)
const DRIBBLE_DURATIONS = {"cross": .38, "spin": .64, "twostep": .64, "behind": .48, "hesi": .58}
var players: Array = []
var ball: Node3D
var ball_shadow: Node3D
var camera: Camera3D
var trail: Array = []
var trail_positions: Array = []
var sounds: Dictionary = {}
var audio_pool: Array = []
var audio_index = 0
var court_audio: Node
var audio_settings: Dictionary = {}
var audio_settings_json = ""
var web_input: Variant # JavaScriptObject in web builds; a dictionary may supply the same controls in tests.
var frame_probe=false
var web_switch_seq=0
var web_pass_seq=0
var web_shoot_seq=0
var web_control_reset=-1
var rng = RandomNumberGenerator.new()
var time = 0.0
var mode = "practice"
var career_match_id=""
var career_stage=0
var paused = true
var pause_reason = ""
var resume_input_lock = false
var started = false
var phase = "live"
var ball_owner = 0
var shooter = 0
var scores: Array = [0, 0]
var clock_left = 90.0
var shot_clock = 15.0
var needs_clear = false
var flight_t = 0.0
var flight_duration = 1.0
var flight_start = Vector3.ZERO
var flight_target = Vector3.ZERO
var flight_arc = 2.0
var flight_made = false
var flight_points = 2
var shot_committed = false
var shot_hold = 0.0
var last_shoot = false
var last_cross = false
var last_spin = false
var last_twostep = false
var last_behind = false
var last_hesi = false
var skill_forward = Vector3.FORWARD
var skill_side = Vector3.RIGHT
var last_steal = false
var last_pause = false
var crossover_cooldown = 0.0
var cross_direction = Vector3.ZERO
var steal_cooldown = 0.0
var ai_decision = 0.0
var ai_goal = Vector3.ZERO
var ai_freeze = 0.0
var ai_reaction = 0.0
var ai_reaction_cooldown = 0.0
var ai_reaction_velocity = Vector2.ZERO
var boxout_feedback_cooldown = 0.0
var ai_boxout_time = 0.0
var ai_boxout_side = 1.0
var ball_velocity = Vector3.ZERO
var previous_ball_position = Vector3.ZERO
var reset_timer = 0.0
var loose_timer = 0.0
var feedback = "코트에 들어갈 준비가 됐나요?"
var feedback_sub = "연습으로 손을 풀거나, RIVAL과 1대1을 시작하세요."
var feedback_timer = 0.0
var attempts = 0
var makes = 0
var sound_enabled = true
var reduced_motion = false
var last_command = 0
var ui_time = 0.0
var bounce_index = -1
var camera_home = Vector3(0, 10.8, 12.8)
var camera_focus = Vector3(0, 0, -2.8)
var camera_follow = Vector3.ZERO
var camera_mobile_zoom = 1.0
var camera_mobile_follow = Vector3.ZERO

func controlled_player():
	return players[team_match.selected] if mode == "team" and team_match != null and players.size() == 6 else players[0]

func frame_court(delta: float) -> void:
	var viewport_size = get_viewport().get_visible_rect().size
	var aspect = viewport_size.x / maxf(viewport_size.y, 1)
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = clampf(rad_to_deg(2 * atan(tan(deg_to_rad(35.0) * .5) * 1.6 / maxf(aspect, .55))), 32, 85)
	var follow = Vector3.ZERO
	if started:
		follow.z = clampf(controlled_player().position.z - 1.6, 0, 4.7)
		follow.x = clampf(controlled_player().position.x * .28, -1.3, 1.3)
	camera_follow = camera_follow.lerp(follow, 1 - exp(-delta * 4)) if delta > 0 else follow
	camera.position = camera_home + camera_follow
	camera.look_at(camera_focus + camera_follow)
	var compact_camera = aspect < 1.05
	if web_input != null: compact_camera = compact_camera or bool(web_input.compactCamera)
	else: compact_camera = compact_camera or (viewport_size.x < 950 and viewport_size.y < 560)
	if compact_camera and started: frame_mobile_court(delta, aspect, viewport_size)
	if mode == "practice" and practice_slow and practice_drill == "layup" and started:
		var study_focus = players[0].position.lerp(Vector3(HOOP.x,0,HOOP.z), .38) + Vector3.UP * 1.20
		camera.fov = clampf(42 * maxf(1, 1.3/maxf(aspect,.55)), 42, 78)
		camera.position = study_focus + Vector3(0,2.0,5.1)
		camera.look_at(study_focus)
	elif mode == "practice" and practice_slow and practice_drill in ["boxout","block","rebound","steal","cross","cut","rim","recovery"] and started:
		var study_focus = players[0].position.lerp(players[1].position,.5) + Vector3.UP*1.05
		if practice_drill == "rebound": study_focus = players[0].position+Vector3.UP*1.25
		if practice_drill in ["cross","cut"]: study_focus = players[0].position+Vector3.UP*.95
		camera.fov = clampf(45*maxf(1,1.3/maxf(aspect,.55)),45,78)
		camera.position = study_focus + Vector3(4.0,1.8,4.4)
		if practice_drill == "rebound": camera.position = study_focus+Vector3(4.8,1.5,.8)
		if practice_drill == "block": camera.position = study_focus+Vector3(5.0,1.5,.8)
		if practice_drill == "steal": camera.position = study_focus+Vector3(-4.8,1.5,.8)
		if practice_drill == "cross": camera.position = study_focus+Vector3(3.6,1.4,-3.7)
		if practice_drill == "cut": camera.position = study_focus+Vector3(-4.7,1.5,-1.6)
		if practice_drill == "recovery": camera.position = study_focus+Vector3(4.5,1.8,4.5)
		if practice_drill == "rim":
			study_focus = players[0].position.lerp(Vector3(HOOP.x,0,HOOP.z),.35)+Vector3.UP*1.6
			camera.position = study_focus+Vector3(4.8,2.8,5.4)
		camera.look_at(study_focus)

func frame_mobile_court(delta: float, aspect: float, viewport_size: Vector2) -> void:
	# Portrait is a player-follow view, not a wide court squeezed into a phone.
	var player = controlled_player()
	var focus = Vector3(player.position.x * .5, .85, lerpf(player.position.z, HOOP.z, .08))
	focus += Vector3(player.motion.x, 0, player.motion.y).limit_length(5) * .08
	var desired = focus - camera_focus
	camera_mobile_follow = camera_mobile_follow.lerp(desired, 1 - exp(-delta * 9)) if delta > 0 else desired
	focus = camera_focus + camera_mobile_follow
	var offset = Vector3(0, 3.8, 11.5) if aspect < 1.05 else Vector3(0, 4.2, 10.8)
	camera.fov = 44
	var targets = [player.position + Vector3.UP * .1, player.position + Vector3.UP * 2.15, HOOP]
	if mode == "duel" and players[1].position.distance_to(player.position) < 6:
		targets.append(players[1].position + Vector3.UP * .1)
		targets.append(players[1].position + Vector3.UP * 2.15)
	if ball != null and phase in ["takeoff", "flight", "loose"]:
		targets.append(ball.position)
	# Solve the perspective bounds continuously; the old 7% search snapped at
	# every distance threshold. All targets share the same fixed viewing angle.
	camera.position = focus + offset
	camera.look_at(focus)
	var projection = camera.get_camera_projection()
	var distance = offset.length()
	var zoom = 1.0
	for target in targets:
		var relative: Vector3 = target - focus
		var horizontal = absf(relative.dot(camera.basis.x)) * projection.x.x / .88
		var vertical = relative.dot(camera.basis.y)
		vertical *= projection.y.y / (.72 if vertical >= 0 else -.34)
		var depth = maxf(.1, maxf(horizontal, vertical))
		zoom = maxf(zoom, (depth + relative.dot(camera.basis.z)) / distance)
	# Both directions ease in real time. A small framing reserve gives the
	# pull-back room to catch a running player without exposing each fit step.
	zoom = maxf(1.0, zoom * 1.025)
	var rate = 7.0 if zoom > camera_mobile_zoom else 3.0
	camera_mobile_zoom = lerpf(camera_mobile_zoom, zoom, 1 - exp(-delta * rate)) if delta > 0 else zoom
	camera.position = focus + offset * camera_mobile_zoom
	camera.look_at(focus)
var native_hud: Label
var event_id = 0
var last_scored_event = -1
var last_event = "ready"
var finish_kind = "shot"
var takeoff_start = Vector3.ZERO
var takeoff_target = Vector3.ZERO
var release_at = 0.22
var timing_bonus = 0.0
var impact = 0.0
var impact_ring: Node3D
var practice_drill = "free"
var practice_slow = false
var inspecting = false
var showroom: Node3D
var showroom_players: Array = []
var showroom_time = 0.0
var showroom_closeup = false
var showroom_motion = 0
var showroom_balls: Array = []
var wardrobe_preview=false
var wardrobe_prior_inspecting=false
var wardrobe_yaw=0.0
var equipped_appearance: Dictionary={}
var web_appearance=""

func open_wardrobe(data: Dictionary) -> void:
	if not wardrobe_preview:
		wardrobe_prior_inspecting=inspecting
		if not inspecting:toggle_showroom()
	wardrobe_preview=true
	showroom_players[0].marker.visible=false
	showroom_players[0].shadow.visible=false
	wardrobe_yaw=float(data.get("yaw",0))
	showroom_players[0].apply_athlete(data.get("athlete",{}))
	showroom_players[0].apply_appearance(data.get("appearance",{}))
	showroom_players[0].reset_stance()
	showroom_players[0].action="showcase"

func close_wardrobe() -> void:
	if not wardrobe_preview:return
	wardrobe_preview=false
	showroom_players[0].marker.visible=true
	showroom_players[0].shadow.visible=true
	showroom_players[0].apply_appearance(equipped_appearance)
	if not wardrobe_prior_inspecting and inspecting:toggle_showroom()

func tick_wardrobe(delta: float) -> void:
	showroom_time+=delta
	for index in range(showroom_players.size()):
		var model=showroom_players[index]
		model.visible=index==0
		showroom_balls[index].visible=false
		if index==0:
			model.action="showcase"
			model.has_ball=false
			model.facing=wardrobe_yaw
			model.animate(delta,showroom_time)
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect=Camera3D.KEEP_HEIGHT
	camera.size=2.65
	camera.position=Vector3(99.28,1.65,5)
	camera.look_at(Vector3(99.28,1.01,0))

func toggle_showroom() -> void:
	inspecting = not inspecting
	if inspecting and showroom == null:
		showroom = Node3D.new()
		showroom.position = Vector3(100, 0, 0)
		add_child(showroom)
		Art.box(showroom, Vector3(0, -.05, 0), Vector3(30, .1, 30), "85877c")
		for i in range(2):
			var model = Actor.new()
			showroom.add_child(model)
			model.setup(i == 1)
			model.position.x = -.72 if i == 0 else .72
			model.facing = .22 if i == 0 else -.22
			model.rotation.y = model.facing
			model.action = "showcase"
			showroom_players.append(model)
			var demo_ball = Art.basketball(showroom)
			demo_ball.visible = false
			showroom_balls.append(demo_ball)
	if showroom != null: showroom.visible = inspecting
	if not inspecting:
		frame_court(0)
		last_shoot = true
	send_state()

func _ready() -> void:
	frame_probe="--frame-probe" in OS.get_cmdline_user_args()
	for binding in [["team_pass",KEY_Q],["team_switch",KEY_E]]:
		if not InputMap.has_action(binding[0]):
			InputMap.add_action(binding[0])
			var event = InputEventKey.new()
			event.physical_keycode = binding[1]
			InputMap.action_add_event(binding[0],event)
	if "--character-lab" in OS.get_cmdline_user_args():
		set_physics_process(false)
		get_tree().change_scene_to_file.call_deferred("res://scenes/character_lab.tscn")
		return
	if "--motion-lab" in OS.get_cmdline_user_args():
		set_physics_process(false)
		get_tree().change_scene_to_file.call_deferred("res://scenes/motion_lab.tscn")
		return
	rng.seed = 7137
	setup_environment()
	var static_court=Node3D.new()
	static_court.name="StaticCourt"
	add_child(static_court)
	Art.court(static_court)
	Art.batch_static(static_court)
	for i in range(2):
		var player = Actor.new()
		add_child(player)
		player.setup(i == 1)
		players.append(player)
	ball = Art.basketball(self)
	ball_shadow = Art.cylinder(self, Vector3.ZERO, 0.2, 0.2, 0.008, "365a58")
	impact_ring = Node3D.new()
	add_child(impact_ring)
	Art.arc(impact_ring, Vector3.ZERO, 0.6, 0, TAU, "ffdc86", 0.035, 32)
	impact_ring.visible = false
	for i in range(6):
		var point = Art.sphere(self, Vector3.ZERO, Vector3.ONE * (0.12 - i * 0.014), "f8c77c")
		point.visible = false
		trail.append(point)
	load_audio()
	if OS.has_feature("web"):
		web_input = JavaScriptBridge.get_interface("window").ufInput
	else:
		var layer = CanvasLayer.new()
		add_child(layer)
		native_hud = Label.new()
		layer.add_child(native_hud)
		native_hud.position = Vector2(24, 24)
		native_hud.add_theme_font_size_override("font_size", 22)
	reset_positions(0)
	send_state()
	if "--smoke" in OS.get_cmdline_user_args():
		start_mode("duel")
		for i in range(900):
			_physics_process(1.0 / 60.0)
		print("SMOKE_OK phase=", phase, " score=", scores, " actors=", players.size())
		get_tree().quit()

func setup_environment() -> void:
	var world = WorldEnvironment.new()
	var environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("c7b39a")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("c5d1e0")
	environment.ambient_light_energy = 0.38
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	world.environment = environment
	add_child(world)
	var sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.light_color = Color("fff4df")
	sun.light_energy = 0.85
	sun.shadow_enabled = true
	# This bounded half court needs one shadow map, not four depth cascades.
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 45
	add_child(sun)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.position = camera_home
	add_child(camera)
	camera.look_at(camera_focus)
	camera.current = true

func load_audio() -> void:
	court_audio = CourtAudio.new()
	add_child(court_audio)
	for name in ["bounce", "squeak", "release", "swish", "rim", "block", "whistle", "slam", "landing"]:
		var path = "res://assets/audio/" + name + ".wav"
		if ResourceLoader.exists(path):
			sounds[name] = load(path)
	for i in range(8):
		var stream = AudioStreamPlayer.new()
		stream.bus = "CourtSFX"
		add_child(stream)
		audio_pool.append(stream)

func _notification(what: int) -> void:
	if not OS.has_feature("web") and what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT] and started:
		set_paused(true,"앱을 벗어나 경기를 멈췄습니다.")
		if court_audio != null: court_audio.configure(sound_enabled,false,audio_settings)

func play_sound(name: String, volume: float = -9) -> void:
	if not sound_enabled or not sounds.has(name):
		return
	var stream = audio_pool[audio_index % audio_pool.size()]
	audio_index += 1
	stream.stream = sounds[name]
	stream.volume_db = volume
	stream.pitch_scale = 1.0 + sin(time * 17) * 0.025
	stream.play()

func start_mode(next_mode: String) -> void:
	get_viewport().msaa_3d=Viewport.MSAA_DISABLED if next_mode=="team" else Viewport.MSAA_2X
	close_wardrobe()
	if inspecting: toggle_showroom()
	var chosen_role: String = players[0].court_role
	if team_match != null: team_match.stop()
	career_match_id=""
	career_stage=0
	for p in players:p.apply_athlete({})
	players[1].court_role="guard"
	mode = next_mode
	if mode != "practice": practice_slow = false
	practice_drill = "free"
	started = true
	paused = false
	pause_reason = ""
	resume_input_lock = false
	scores = [0, 0]
	clock_left = 90
	attempts = 0
	makes = 0
	rng.seed = 7137 + int(Time.get_ticks_msec())
	reset_positions(0)
	players[1].visible = mode == "duel"
	announce("CHECK BALL" if mode == "duel" else "FIND YOUR RHYTHM", "11점 먼저, 또는 90초 승부" if mode == "duel" else "방향키로 이동 · D를 눌러 슛 · 짧게 누르면 페이크", 3)
	if mode == "team":
		if team_match == null: team_match = TeamMatch.new(self)
		team_match.start(chosen_role)
	play_sound("whistle", -16)
	send_state()

func start_career(data: Dictionary) -> void:
	if data.get("mode","")=="team":
		if not data.get("athlete",null) is Dictionary or not data.get("opponents",null) is Array or data.opponents.size()!=3 or str(data.get("matchId","")).length()!=36:return
		if str(data.athlete.get("role","")) not in ["guard","forward","center"]:return
		for opponent in data.opponents:
			if not opponent is Dictionary or str(opponent.get("role","")) not in ["guard","forward","center"]:return
		players[0].court_role=str(data.athlete.role)
		start_mode("team")
		career_match_id=str(data.matchId)
		players[0].apply_athlete(data.athlete)
		for i in 3:players[i+3].apply_athlete(data.opponents[i])
		team_match.reset(0)
		announce("MY TEAM", "성장 팀전 · 직접 조작하며 완주하면 경험치와 코인을 받아요.",4)
		send_state()
		return
	if not data.get("athlete",null) is Dictionary or not data.get("opponent",null) is Dictionary:return
	var opponent=data.opponent.get("athlete",{})
	if not opponent is Dictionary or opponent.is_empty() or str(data.get("matchId","")).length()!=36:return
	start_mode("duel")
	career_match_id=str(data.matchId)
	career_stage=clampi(int(data.get("stage",1)),1,8)
	players[0].apply_athlete(data.athlete)
	players[1].apply_athlete(opponent)
	reset_positions(0)
	announce("COURT %02d" % career_stage,str(data.opponent.get("name","코트 도전"))+" · 11점 또는 90초 승부",4)
	send_state()

func opponent_enabled() -> bool:
	return mode == "duel" or (mode == "practice" and practice_drill in ["boxout","block","steal","rim","recovery"])

func reset_positions(next_owner: int) -> void:
	if mode == "team" and team_match != null and not team_match.legacy.is_empty():
		team_match.reset(0)
		return
	ball_owner = next_owner
	phase = "live"
	needs_clear = false
	shot_clock = 15
	shot_hold = 0
	shot_committed = false
	finish_kind = "shot"
	impact = 0
	crossover_cooldown = 0
	steal_cooldown = 0
	last_shoot = true # A held button across a restart must not trigger a shot.
	players[0].position = Vector3(-1.3, 0, 1.9) if ball_owner == 0 else Vector3(0.4, 0, -0.3)
	players[1].position = Vector3(-0.5, 0, -0.1) if ball_owner == 0 else Vector3(-1.1, 0, 2.5)
	for i in range(2):
		players[i].motion = Vector2.ZERO
		players[i].jump = 0
		players[i].action = "idle"
		players[i].action_time = 0
		players[i].finish_kind = "shot"
		players[i].finish_running = false
		players[i].finish_target_valid = false
		# Reset feet only after placing the hips in their initial heading. Turning
		# a fresh idle rig over its locked old-facing soles crosses both legs.
		players[i].facing = PI
		players[i].rotation.y = PI
		players[i].reset_stance()
		players[i].has_ball = i == ball_owner
		players[i].dribble_ended = false
		players[i].facing = PI
		players[i].animate(0.016, time)
	players[1].visible = opponent_enabled()
	if mode == "practice" and practice_drill in ["layup", "dunk"]:
		players[0].position = Vector3(0.75, 0, -3.2) if practice_drill == "layup" else Vector3(0, 0, -2.55)
		face_target(0, HOOP)
	ball.position = players[ball_owner].ball_anchor(time)
	previous_ball_position = ball.position
	ai_decision = 0
	ai_freeze = 0.4
	ai_reaction = 0
	ai_reaction_cooldown = 0
	ai_boxout_time = 0
	trail_positions.clear()
	for point in trail:
		point.visible = false

func set_drill(kind: String) -> void:
	if mode != "practice" or not started: return
	practice_drill = kind
	paused = false
	reset_positions(0)
	if kind == "recovery":
		players[0].position = Vector3(0,0,1)
		players[1].position = Vector3(0,0,-.3)
		for index in range(2):
			players[index].facing = PI if index == 0 else 0.0
			players[index].rotation.y = players[index].facing
			players[index].feet_world.clear()
			players[index].animate(.016,time)
		ball.position = players[0].ball_anchor(time)
		previous_ball_position = ball.position
		ai_freeze = 0
		announce("BREAK & CHASE","←/→ + A로 속인 뒤 ↑로 돌파. 수비의 디딤 → 중심 회복 → 돌아서 추격.",5)
		send_state()
		return
	if kind == "rim":
		reset_positions(1)
		players[0].position = Vector3(0,0,-3.8)
		players[1].position = Vector3(.4,0,-1.9)
		for p in players:
			p.feet_world.clear()
			p.animate(.016,time)
		ai_freeze = .7
		begin_gather(1)
		players[1].finish_kind = "shot"
		players[1].finish_running = false
		announce("RIM BATTLE","연습용 미스 슛. W로 박스아웃 → 내려오는 공을 D로 캐치.",5)
		send_state()
		return
	if kind in ["cross","cut"]:
		players[0].position = Vector3(0,0,1)
		players[0].rotation.y = PI
		players[0].facing = PI
		players[0].dribble_phase = TAU*.94
		players[0].feet_world.clear()
		players[0].animate(.016,time)
		ball.position = players[0].ball_anchor(time)
		previous_ball_position = ball.position
		if kind == "cut": announce("PLANT & DRIVE","↑로 달린 뒤 ←/→. 발 디딤 → 몸통·팔 회전 → 밀고 나가기.",5)
		else: announce("CROSSOVER LAB","↑로 달린 뒤 ←/→ + A. 속임 → 강한 바운스 → 반대 손 캐치 → 돌파.",5)
		send_state()
		return
	if kind == "steal":
		reset_positions(1)
		players[0].position = Vector3(-.25,0,-4.05)
		players[1].position = Vector3(0,0,-2.90)
		for p in players:
			p.feet_world.clear()
			p.facing = 0.0 if p == players[0] else PI
			p.rotation.y = p.facing
			p.dribble_phase = 0
			p.animate(.016,time)
		ball.position = players[1].ball_anchor(time)
		previous_ball_position = ball.position
		ai_freeze = 10
		announce("STEAL LAB","S → 짧게 파고들어 공 쪽 손 뻗기. 손이 닿아야 스틸을 시도합니다.",5)
		send_state()
		return
	if kind == "rebound":
		players[0].position = Vector3(0,0,-3.65)
		players[0].has_ball = false
		players[0].feet_world.clear()
		players[0].animate(.016,time)
		ball_owner = -1
		shooter = 1
		phase = "loose"
		ball.position = players[0].position+Vector3(0,3.15,-.28)
		previous_ball_position = ball.position
		ball_velocity = Vector3(0,-.3,.15)
		loose_timer = 0
		announce("REBOUND LAB","공이 내려올 때 D → 두 손 캐치 → 가슴으로 당겨 착지. 버튼으로 다시 연습하세요.",5)
		send_state()
		return
	if kind == "block":
		reset_positions(1)
		players[0].position = Vector3(0,0,-4.45)
		players[1].position = Vector3(0,0,-3.30)
		face_target(0,players[1].position)
		players[0].rotation.y = players[0].facing
		for p in players:
			p.feet_world.clear()
			p.animate(.016,time)
		face_target(0,players[1].position)
		ai_freeze = 10
		begin_gather(1)
		players[1].finish_kind = "shot"
		players[1].finish_running = false
		announce("BLOCK LAB","상대가 공을 들어 올릴 때 D → 손바닥으로 내려치기 → 팔 회수 → 착지.",5)
		send_state()
		return
	if kind == "boxout":
		players[0].position = Vector3(0,0,-3.5)
		players[1].position = Vector3(0,0,-2.6)
		for p in players:
			p.has_ball = false
			p.feet_world.clear()
			p.animate(.016,time)
		ball_owner = -1
		shooter = 1
		event_id += 1
		phase = "flight"
		flight_start = Vector3(1.8,3.5,-2.2)
		flight_target = HOOP
		flight_t = 0
		flight_duration = 1.6
		flight_arc = 1.3
		flight_made = false
		ball.position = flight_start
		previous_ball_position = ball.position
		announce("BOX OUT LAB", "W 유지로 뒤의 상대 막기 → D로 리바운드. 옆으로 돌아가면 박스아웃이 풀립니다.",5)
		send_state()
		return
	announce("FINISH LAB", "골밑에서 D 유지 → 레이업" if kind == "layup" else "↑로 도움닫기 → 골밑에서 D 유지. D · DUNK 표시를 확인하세요.", 5)
	send_state()

func announce(title: String, subtitle: String = "", duration: float = 2.0) -> void:
	feedback = title
	feedback_sub = subtitle
	feedback_timer = duration

func read_controls() -> Dictionary:
	var controls = {"x": 0.0, "z": 0.0, "shoot": false, "shoot_pressed":false, "cross": false, "spin": false, "twostep": false, "behind": false, "hesi": false, "steal": false, "guard": false, "pause": false,"pass":false,"switch":false}
	if web_input != null:
		var appearance_text=str(web_input.appearance)
		if appearance_text!=web_appearance:
			web_appearance=appearance_text
			var ids=JSON.parse_string(appearance_text)
			if ids is Dictionary:
				equipped_appearance=CourtWardrobe.appearance(ids)
				players[0].apply_appearance(equipped_appearance)
		sound_enabled = bool(web_input.sound)
		reduced_motion = bool(web_input.reduced)
		controls.x = float(web_input.x)
		controls.z = float(web_input.z)
		controls.shoot = bool(web_input.shoot)
		controls.cross = bool(web_input.cross)
		controls.spin = bool(web_input.spin)
		controls.twostep = bool(web_input.twostep)
		controls.behind = bool(web_input.behind)
		controls.hesi = bool(web_input.hesi)
		controls.steal = bool(web_input.steal)
		controls.guard = bool(web_input.guard)
		controls["pass"] = bool(web_input.passBall)
		var reset=int(web_input.controlReset)
		var switch_seq=int(web_input.switchSeq)
		var pass_seq=int(web_input.passSeq)
		var shoot_seq=int(web_input.shootSeq)
		var cancelled=reset!=web_control_reset
		controls.shoot_pressed = not cancelled and shoot_seq!=web_shoot_seq and shoot_seq!=int(web_input.shootCancelSeq)
		controls["switch"] = not cancelled and (bool(web_input.switchPlayer) or switch_seq!=web_switch_seq)
		controls["pass"] = not cancelled and (bool(web_input.passBall) or pass_seq!=web_pass_seq)
		web_switch_seq=switch_seq
		web_pass_seq=pass_seq
		web_shoot_seq=shoot_seq
		web_control_reset=reset
		var command = int(web_input.commandId)
		if command != last_command:
			last_command = command
			match str(web_input.command):
				"wardrobe":
					var data=JSON.parse_string(str(web_input.wardrobe))
					if data is Dictionary:open_wardrobe(data)
				"wardrobe-close":close_wardrobe()
				"practice", "duel", "team": start_mode(str(web_input.command))
				"career":
					var career_data=JSON.parse_string(str(web_input.career))
					if career_data is Dictionary:start_career(career_data)
				"pause":
					if started and phase != "ended": set_paused(not paused)
				"resume":
					if started and phase != "ended" and not bool(web_input.suspended): set_paused(false)
				"reset": reset_positions(0)
				"showroom": toggle_showroom()
				"showroom-detail":
					showroom_closeup = not showroom_closeup
					send_state()
				"showroom-motion":
					showroom_motion = (showroom_motion + 1) % 7
					showroom_closeup = false
					showroom_time = 0
					for p in showroom_players:
						p.cross_valid = false
						p.cross_exit_left = 0
						p.set_meta("cross_preview_cycle",-1)
					send_state()
				"drill-layup": set_drill("layup")
				"drill-dunk": set_drill("dunk")
				"drill-boxout": set_drill("boxout")
				"drill-rebound": set_drill("rebound")
				"drill-block": set_drill("block")
				"drill-steal": set_drill("steal")
				"drill-cross": set_drill("cross")
				"drill-cut": set_drill("cut")
				"drill-recovery": set_drill("recovery")
				"drill-rim": set_drill("rim")
				"position-guard": set_court_role("guard")
				"position-forward": set_court_role("forward")
				"position-center": set_court_role("center")
				"drill-slow":
					if mode == "practice": practice_slow = not practice_slow
					send_state()
				"drill-free":
					if mode == "practice":
						practice_drill = "free"
						reset_positions(0)
				"sound": sound_enabled = bool(web_input.sound)
				"motion": reduced_motion = bool(web_input.reduced)
				"blur":
					if started and phase != "ended": set_paused(true,"창을 벗어나 경기를 멈췄습니다.")
		# A pause request cannot be overwritten by a settings/drill command.
		if bool(web_input.suspended) and started and phase != "ended": set_paused(true,str(web_input.pauseReason))
	else:
		controls.x = float(Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_LEFT))
		controls.z = float(Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_UP))
		controls.shoot = Input.is_physical_key_pressed(KEY_D)
		controls.cross = Input.is_physical_key_pressed(KEY_A)
		controls.spin = Input.is_physical_key_pressed(KEY_Z)
		controls.twostep = Input.is_physical_key_pressed(KEY_C)
		controls.behind = Input.is_physical_key_pressed(KEY_V)
		controls.hesi = Input.is_physical_key_pressed(KEY_X)
		controls.steal = Input.is_physical_key_pressed(KEY_S)
		controls.guard = Input.is_physical_key_pressed(KEY_W)
		controls["pass"] = Input.is_action_pressed("team_pass")
		controls["switch"] = Input.is_action_pressed("team_switch")
		controls.pause = Input.is_physical_key_pressed(KEY_ESCAPE)
		if Input.is_physical_key_pressed(KEY_1): start_mode("practice")
		if Input.is_physical_key_pressed(KEY_2): start_mode("duel")
	return controls

func set_paused(value: bool,reason: String = "잠시 쉬었다가 직접 이어가세요.") -> void:
	if value:
		if not paused:
			# Releasing D outside the game must not release an interrupted shot.
			var player = controlled_player()
			if player.action=="square" or player.action=="held_fake" or player.action == "gather" and not player.finish_running:
				player.held.freeze(player,ball.position)
				player.action = "idle"
				player.action_time = 0
				shot_hold = 0
			for p in players: p.motion = Vector2.ZERO
		paused = true
		pause_reason = reason
	else:
		if paused: resume_input_lock = true
		paused = false
		pause_reason = ""

func gate_resumed_input(input: Dictionary) -> void:
	if not resume_input_lock or paused: return
	var neutral = absf(input.x)+absf(input.z) < .01
	for action in ["shoot","shoot_pressed","cross","spin","twostep","behind","hesi","steal","guard","pass","switch"]:
		neutral = neutral and not input[action]
	if neutral:
		resume_input_lock = false
	else:
		input.x = 0.0
		input.z = 0.0
		for action in ["shoot","shoot_pressed","cross","spin","twostep","behind","hesi","steal","guard","pass","switch"]: input[action] = false

func _physics_process(delta: float) -> void:
	var input = read_controls()
	if web_input != null and str(web_input.audio) != audio_settings_json:
		audio_settings_json = str(web_input.audio)
		var settings = JSON.parse_string(audio_settings_json)
		if settings is Dictionary: audio_settings = settings
	if court_audio != null:
		court_audio.configure(sound_enabled,started and not paused and not inspecting and (web_input == null or not bool(web_input.audioSuspended)),audio_settings)
	if practice_slow and mode == "practice" and not inspecting: delta *= .35
	if inspecting:
		if wardrobe_preview:
			tick_wardrobe(delta)
			return
		if input.pause and not last_pause:
			last_pause = input.pause
			toggle_showroom()
			return
		last_pause = input.pause
		showroom_time += delta
		for index in range(showroom_players.size()):
			var model = showroom_players[index]
			model.visible = not showroom_closeup or not model.is_opponent
			model.facing = (.40 if not model.is_opponent else -.40) + (sin(showroom_time * .35) * .18 if not reduced_motion else 0.0)
			model.action = "showcase"
			model.has_ball = showroom_motion > 0
			var travel = Vector3.ZERO
			if showroom_motion > 0:
				var beat = fposmod(showroom_time, 2.4)
				model.action = "idle"
				if showroom_motion == 2:
					var cycle = int(showroom_time/2.4)
					if beat >= .8 and int(model.get_meta("cross_preview_cycle",-1)) != cycle:
						model.prepare_cross(model.ball_anchor(showroom_time))
						model.set_meta("cross_preview_cycle",cycle)
					if model.cross_valid:
						model.action = "cross"
						model.action_time += delta
						if model.action_time >= model.cross_duration() and model.cross_received: model.finish_cross()
				else: model.action_time = 0
				var preview_skill: String = ["idle", "idle", "cross", "spin", "twostep", "behind", "hesi"][showroom_motion]
				if showroom_motion >= 3 and beat > .8 and beat < .8 + DRIBBLE_DURATIONS[preview_skill]:
					model.action = preview_skill
					model.action_time = beat - .8
					model.turn_origin = .16 if index == 0 else -.16
					model.turn_sign = 1.0 if index == 0 else -1.0
				var side = 1.0 if not model.is_opponent else -1.0
				var velocity = Vector3(side * (4.0 if model.action == "cross" else .6), 0, 3.7)
				if model.action == "twostep": velocity.x = side * sin(model.action_time / .64 * TAU) * 2.7
				if model.action == "hesi": velocity *= .22 if model.action_time < .25 else 1.25
				model.facing = atan2(velocity.x, velocity.z)
				travel = velocity * delta
				model.position += travel
			model.animate(delta, showroom_time)
			# A treadmill view of the same simulation; all world contacts move with the belt.
			model.position -= travel
			model.previous_position -= travel
			if model.skinned != null: model.skinned.shift_world_contacts(-travel)
			for foot in range(2):
				model.feet_world[foot] -= travel
				model.swing_from[foot] -= travel
				model.swing_to[foot] -= travel
			showroom_balls[index].visible = model.visible and showroom_motion > 0
			showroom_balls[index].global_position = model.ball_anchor(showroom_time)
		var viewport = get_viewport().get_visible_rect().size
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = (1.28 if showroom_closeup else 2.8) * maxf(1, .9 / maxf(viewport.x / maxf(viewport.y, 1), .3))
		camera.position = Vector3(99.28, 1.85, 6) if showroom_closeup else Vector3(100, 2.3, 8)
		camera.look_at(Vector3(99.28, 1.55, 0) if showroom_closeup else Vector3(100, 1.02, 0))
		return
	if input.pause and not last_pause and started:
		set_paused(not paused)
	last_pause = input.pause
	ui_time += delta
	gate_resumed_input(input)
	if ui_time >= 0.1:
		ui_time = 0
		send_state()
	frame_court(delta)
	if paused or phase == "ended":
		if not started:
			time += delta
			players[0].animate(delta, time)
			players[1].animate(delta, time)
			ball.position = players[0].ball_anchor(time)
		update_ball_visual()
		last_shoot = input.shoot
		return
	if mode == "team":
		team_match.tick(delta,input)
		return
	time += delta
	feedback_timer = maxf(0, feedback_timer - delta)
	crossover_cooldown = maxf(0, crossover_cooldown - delta)
	steal_cooldown = maxf(0, steal_cooldown - delta)
	ai_freeze = maxf(0, ai_freeze - delta)
	ai_reaction = maxf(0, ai_reaction - delta)
	ai_reaction_cooldown = maxf(0, ai_reaction_cooldown - delta)
	boxout_feedback_cooldown = maxf(0, boxout_feedback_cooldown - delta)
	if mode == "duel" and phase in ["live", "takeoff", "flight", "loose"]:
		clock_left = maxf(0, clock_left - delta)
		if phase in ["live", "takeoff"]:
			shot_clock -= delta
			if shot_clock <= 0:
				turnover("SHOT CLOCK", "15초 안에 슛을 시도하세요.")
				return
			if clock_left <= 0 and scores[0] != scores[1]:
				finish_match()
				return
	update_actions(delta)
	var direction = Vector2(input.x, input.z).limit_length()
	players[0].defending = input.guard and not players[0].has_ball
	# Camera-relative input makes left/right agree with the visible court.
	var right = Vector3(camera.global_basis.x.x, 0, camera.global_basis.x.z).normalized()
	var down = Vector3(camera.global_basis.z.x, 0, camera.global_basis.z.z).normalized()
	var desired = right * direction.x + down * direction.y
	held_ball_controls(0,input,desired,delta)
	if players[0].action=="shot":players[0].shot_exit_intent=Vector2(desired.x,desired.z)*players[0].athletic_profile().speed
	var speed: float = players[0].athletic_profile().speed if not input.guard else 2.7
	if players[0].action=="pickup":speed*=.45
	if input.guard and players[0].boxing_out: speed = 1.7
	if players[0].action in ["gather", "shot", "layup", "dunk", "fake", "block", "rebound"]:
		speed *= 0.16
	if phase == "takeoff" and shooter == 0: speed = 0
	if phase == "dead": speed = 0
	speed *= players[0].landing_speed_scale()
	var desired_motion = Vector2(desired.x, desired.z) * speed
	if players[0].crossing():
		var beat = players[0].cross_phase()
		desired_motion += Vector2(cross_direction.x,cross_direction.z)*2.8*sin(clampf((beat-.35)/.65,0,1)*PI)
		desired_motion = desired_motion.limit_length(6.5)
	if players[0].action in ["spin", "twostep", "behind", "hesi"]:
		var t: float = players[0].action_time / DRIBBLE_DURATIONS[players[0].action]
		var skill_velocity = skill_forward * (2.8 + sin(t * PI) * 1.4)
		if players[0].action == "spin":
			skill_velocity += skill_side * sin(t * TAU) * 2.2
		elif players[0].action == "twostep":
			skill_velocity += skill_side * (2.7 if t < .5 else -2.7) * sin(fposmod(t * 2, 1) * PI)
		elif players[0].action == "behind":
			skill_velocity += skill_side * sin(t * PI) * 2.3
		else:
			skill_velocity = skill_forward * (.65 if t < .43 else 5.7)
		desired_motion = Vector2(skill_velocity.x, skill_velocity.z)
	players[0].steer_motion(desired_motion,24 if direction.length() > 0 else 35,delta)
	if players[0].has_ball and players[0].dribble_ended:
		players[0].motion = players[0].gather_velocity() if players[0].action == "gather" else Vector2.ZERO
	if not (phase == "takeoff" and shooter == 0): move_player(0, delta)
	if players[0].defensive_jump() or players[0].stealing():
		pass # Keep the chosen catch/block direction through takeoff and landing.
	elif input.guard and not players[0].has_ball and opponent_enabled():
		face_target(0,players[1].position)
	elif direction.length() > 0.1 and not players[0].action in ["gather", "shot", "layup", "dunk", "fake", "spin", "twostep", "behind", "hesi"]:
		players[0].facing = atan2(desired.x, desired.z)
	elif not players[0].has_ball and mode == "duel":
		face_target(0, players[1].position)
	if opponent_enabled():
		update_ai(delta)
		update_boxouts(input.guard)
		separate_players()
	if ball_owner == 0 and phase == "live":
		if needs_clear and Rules.is_clear(players[0].position):
			needs_clear = false
			announce("CLEARED", "이제 공격할 수 있어요.", 1.2)
		var combo_entry=input.cross and ((players[0].action=="cross" and players[0].action_time<.12) or (players[0].action=="held_fake" and players[0].held.kind=="pivot" and players[0].action_time<.12))
		var can_finish = combo_entry or players[0].action == "idle" or (players[0].action=="held_fake" and players[0].held.can_chain(players[0])) or (players[0].crossing() and players[0].cross_received) or (players[0].action in DRIBBLE_DURATIONS and players[0].action != "cross" and players[0].action_time >= DRIBBLE_DURATIONS[players[0].action] * .55)
		if ((input.shoot and not last_shoot) or players[0].held.pending_shot_left>0) and can_finish:
			if needs_clear:
				announce("CLEAR THE BALL", "외곽선 밖으로 공을 가져가세요.")
			else:
				begin_gather(0,false,combo_shot(0,input,desired),desired)
		if players[0].action == "gather":
			gather_input(0,input.shoot,delta)
		if input.cross and not last_cross and crossover_cooldown <= 0 and players[0].action == "idle":
			crossover(direction)
		elif input.spin and not last_spin:
			start_dribble_skill("spin", desired)
		elif input.twostep and not last_twostep:
			start_dribble_skill("twostep", desired)
		elif input.behind and not last_behind:
			start_dribble_skill("behind", desired)
		elif input.hesi and not last_hesi:
			start_dribble_skill("hesi", desired)
	elif phase in ["live", "takeoff", "flight", "loose"]:
		if ((input.shoot and not last_shoot) or input.get("shoot_pressed",false)) and players[0].action == "idle":
			start_defensive_jump(0,defense_kind(0))
		if input.steal and not last_steal and steal_cooldown <= 0 and phase == "live" and ball_owner == 1 and players[0].action == "idle":
			attempt_steal()
	last_shoot = input.shoot
	last_cross = input.cross
	last_spin = input.spin
	last_twostep = input.twostep
	last_behind = input.behind
	last_hesi = input.hesi
	last_steal = input.steal
	if phase == "takeoff" and finish_kind == "shot":
		var progress = clampf((players[shooter].action_time-Actor.SHOT_PLANT_TIME) / (release_at-Actor.SHOT_PLANT_TIME), 0, 1)
		players[shooter].position = takeoff_start.lerp(takeoff_target, smoothstep(0, 1, progress))
	var pose_players = [players[1],players[0]] if (players[0].stealing() and phase == "live" and ball_owner == 1) or (players[0].action == "block" and shooter == 1 and phase == "takeoff") else players
	for player in pose_players:
		if player.stealing() and not player.steal_success and phase == "live" and ball_owner == 1:
			player.steal_target = players[1].ball_anchor(time)
		if player.action in ["layup", "dunk"] and player.finish_target_valid and player.action_time <= .82:
			player.position = Rules.clamp_to_court(player.finish_position())
		if player.defensive_jump():
			if not player.block_contact: player.defense_target = ball.position
			if player.action == "block" and phase in ["live","takeoff"]:
				player.defense_target = players[maxi(ball_owner,shooter)].ball_anchor(time)
				# Keep the above-head strike plane used at takeoff. A lower new
				# shooting pocket must not pull the windup down to the shooter's waist.
				player.defense_target.y=maxf(2.30,player.defense_target.y)
			player.position = Rules.clamp_to_court(player.defense_position())
		player.animate(delta, time)
	if phase == "live":
		ball.position = players[ball_owner].ball_anchor(time)
		resolve_steal()
		if players[ball_owner].action == "idle" and not players[ball_owner].dribble_ended:
			var next_bounce = int(floor((players[ball_owner].dribble_phase - TAU * 0.42) / TAU))
			if next_bounce != bounce_index:
				bounce_index = next_bounce
				play_sound("bounce", -14)
	elif phase == "takeoff":
		ball.position = players[shooter].ball_anchor(time)
		if not try_block() and players[shooter].action_time >= release_at:
			release_ball()
	elif phase == "flight":
		update_flight(delta)
	elif phase == "loose":
		update_loose(delta)
	elif phase == "dead":
		reset_timer -= delta
		ball.position.y = maxf(Actor.DRIBBLE_FLOOR, ball.position.y - delta * 5)
		if reset_timer <= 0:
			if mode == "duel" and Rules.winner(scores, clock_left, true) >= 0:
				finish_match()
			else:
				reset_positions(1 - shooter if mode == "duel" else 0)
	impact = maxf(0, impact - delta)
	impact_ring.visible = impact > 0 and not reduced_motion
	impact_ring.scale = Vector3.ONE * (1 + (0.32 - impact) * 5)
	camera.position += Vector3(sin(impact * 105) * impact * 0.16, sin(impact * 83) * impact * 0.12, 0) if not reduced_motion else Vector3.ZERO
	update_ball_visual()
	previous_ball_position = ball.position

func defense_kind(index: int) -> String:
	if phase == "loose": return "rebound"
	if phase == "flight" and (shooter == index or flight_t/maxf(flight_duration,.01) >= .45): return "rebound"
	# W also establishes inside position as the shot leaves the hand. It must
	# not replace a reachable early-flight block with a two-hand catch.
	if players[index].boxing_out and ball.position.y > 2.45*players[index].height_ratio+.62: return "rebound"
	return "block"

func start_defensive_jump(index: int,kind: String) -> void:
	var player = players[index]
	if player.action != "idle" or player.has_ball: return
	var target = ball.position
	if kind == "block": target.y = maxf(2.30,target.y)
	var direction = target-player.position
	direction.y = 0
	if direction.length() > .10: player.facing = atan2(direction.x,direction.z)
	player.prepare_defense(kind,target)
	player.defense_end = Rules.clamp_to_court(player.defense_end)
	play_sound("squeak",-19)

func update_actions(delta: float) -> void:
	for player in players:
		if player.action in ["square","held_fake"] and not player.has_ball:
			player.action="idle";player.action_time=0;player.dribble_ended=false;player.held.reset()
		if player.action=="square":player.held.yaw_target=atan2(HOOP.x-player.position.x,HOOP.z-player.position.z)
		if player.action=="held_fake" and player.held.kind in ["pivot","jab","turn","upunder","through"]:
			var beats=[player.held.duration*.22,player.held.duration*.64] if player.held.kind in ["upunder","turn"] else [player.held.duration*.22]
			for beat in beats:
				if player.action_time<beat and player.action_time+delta>=beat:play_sound("squeak",-12 if beat==.12 else -16)
		if player.action in ["spin", "twostep", "behind", "hesi"]:
			for beat in ([.16, .48] if player.action == "twostep" else [DRIBBLE_DURATIONS[player.action] * .5]):
				if player.action_time < beat and player.action_time + delta >= beat: play_sound("bounce", -11)
		var cross_bounce = player.cross_wait+.19 if player.crossing() else .19
		if player.action == "cross" and player.action_time < cross_bounce and player.action_time + delta >= cross_bounce:
			play_sound("bounce", -10)
		player.action_time += delta
		if player.action=="pickup":
			player.jump=maxf(0,player.pickup_height+player.pickup_velocity*player.action_time-4.9*player.action_time*player.action_time)
			if player.action_time>=.28 and player.jump<=.001:player.action="idle";player.action_time=0
		elif player.action=="square" and player!=controlled_player() and player.held.square_ready(player):
			begin_gather(players.find(player),true)
		elif player.action=="held_fake" and player.action_time>=player.held.duration:
			player.action="idle";player.action_time=0
		elif player.crossing():
			if player.action_time >= player.cross_duration() and player.cross_received: player.finish_cross()
		elif player.stealing():
			if player.action_time >= player.STEAL_DURATION:
				if player.steal_success:
					player.rebound_release_from = player.ball_anchor(time)
					player.rebound_release_left = .20
					player.dribble_phase = 0
				elif not player.steal_resolved and player == controlled_player(): announce("REACH MISSED","공이 있는 쪽으로 접근해 손이 닿는 거리를 만드세요.",1.2)
				player.steal_valid = false
				player.action = "idle"
				player.motion = Vector2.ZERO
		elif player.defensive_jump():
			var previous_jump = player.jump
			player.jump = player.defense_height()
			if previous_jump > 0 and player.jump <= .001: play_sound("landing",-18)
			# Both heels have settled and the knees have absorbed the impact.
			# Held movement can now use that loaded leg instead of waiting upright.
			var moving_exit = player.motion.length() > .10 and player.action_time >= player.defense_land_time()+.115
			if moving_exit or player.action_time >= player.defense_duration(): player.finish_defense()
		elif player.action in ["shot", "layup", "dunk", "block"]:
			var height = 0.62 if player.action == "shot" else (1.0 if player.action == "layup" else 1.12)
			var duration = 0.82 if player.action in ["layup", "dunk"] else 0.72
			var before_jump = player.jump
			player.jump = sin(clampf(player.action_time / duration, 0, 1) * PI) * height
			if player.action == "layup": player.jump = Actor.layup_height(player.action_time)
			if player.action == "shot": player.jump = Actor.shot_height(player.action_time)
			if before_jump > 0 and player.jump <= 0.001:
				play_sound("landing", -20)
				if player.action!="shot":player.feet_world.clear()
			if player.action_time >= duration + 0.16:
				if player.action=="shot":player.finish_shot()
				else:
					player.action = "idle"
					player.jump = 0
		elif player.action in ["fake", "cross", "steal", "spin", "twostep", "behind", "hesi"] and player.action_time >= DRIBBLE_DURATIONS.get(player.action, .38):
			if player.action in DRIBBLE_DURATIONS: player.dribble_phase = 0
			if player.action == "spin": player.rotation.y = player.turn_origin + player.turn_sign * TAU
			player.action = "idle"
			player.action_time = 0

func move_player(index: int, delta: float) -> void:
	var player = players[index]
	if player.defensive_jump(): return
	if player.stealing():
		var travel = player.steal_root_target()-player.position
		player.motion = Vector2(travel.x,travel.z)/maxf(delta,.001)
	# Finish trajectories own travel until the landing load is recovered.
	# Input used to add a slow root drift after release, dragging planted feet.
	if player.action in ["shot","layup","dunk"]: return
	player.position += player.movement_step(delta)
	player.position = Rules.clamp_to_court(player.position)

func face_target(index: int, target: Vector3) -> void:
	var direction = target - players[index].position
	players[index].facing = atan2(direction.x, direction.z)

func rebound_target() -> Vector3:
	if phase == "loose":
		var t = clampf((ball_velocity.y+sqrt(maxf(0,ball_velocity.y*ball_velocity.y+19.6*maxf(0,ball.position.y-2.7))))/9.8,0,.65)
		return Rules.clamp_to_court(Vector3(ball.position.x+ball_velocity.x*t,0,ball.position.z+ball_velocity.z*t))
	return Vector3(flight_target.x,0,flight_target.z)

func set_court_role(role: String) -> void:
	if not Rules.ROLE_PROFILES.has(role): return
	if started and phase != "ended" and (mode != "practice" or phase != "live" or players[0].action != "idle"): return
	players[0].court_role = role
	send_state()

func ai_rebound_ready(index: int) -> bool:
	if phase != "loose" or ball_velocity.y >= -.25 or rebound_blocked(index): return false
	var reach = 2.15+players[index].athletic_profile().rebound_jump
	var ahead = ball.position+ball_velocity*.28+Vector3.DOWN*4.9*.28*.28
	var distance = Vector2(ahead.x-players[index].position.x,ahead.z-players[index].position.z).length()
	return ahead.y > 1.8 and ahead.y < reach and distance < 1.0

func update_boxouts(guard: bool) -> void:
	var window = opponent_enabled() and phase in ["flight", "loose"]
	var target = rebound_target()
	for i in range(2):
		var player = players[i]
		var opponent = players[1-i]
		var was_boxing = player.boxing_out
		player.contact_pressure = 0
		player.watch_direction = opponent.position-player.position if player.defending else Vector3.ZERO
		var requested = guard if i == 0 else (shooter == 0 and ball.position.y > .9)
		player.boxing_out = window and requested and player.action == "idle" and player.jump < .05 and not player.has_ball and Rules.can_box_out(player.position,players[1-i].position,target)
		if player.boxing_out:
			var back = opponent.position-player.position
			back.y = 0
			player.contact_direction = back.normalized()
			player.facing = atan2(-back.x,-back.z)
			player.watch_direction = target-player.position
			var approach = -(opponent.motion-player.motion).dot(Vector2(back.x,back.z).normalized())
			player.contact_pressure = clampf((.94-back.length())/.20 + maxf(0,approach)*.12,0,1)
			if i == 0 and not was_boxing and boxout_feedback_cooldown <= 0:
				announce("BOX OUT", "W로 자리 지키기 · D로 뛰어 리바운드", 1.3)
				boxout_feedback_cooldown = 1.8
	for i in range(2):
		var player = players[i]
		player.contesting_boxout = window and players[1-i].boxing_out and player.action == "idle" and player.jump < .05 and not player.has_ball and player.position.distance_to(players[1-i].position) < 1.08
		if player.contesting_boxout: player.watch_direction = target-player.position

func rebound_blocked(index: int) -> bool:
	return opponent_enabled() and players[1-index].boxing_out and Rules.can_box_out(players[1-index].position,players[index].position,rebound_target())

func separate_players() -> void:
	if players[0].jump > .25 or players[1].jump > .25: return
	var offset = players[0].position - players[1].position
	var distance = offset.length()
	# Widen the contact surface as the hips settle, avoiding an instant separation pop.
	var contact_distance = .7 + .16*maxf(players[0].boxout_weight,players[1].boxout_weight)
	contact_distance+=maxf(players[0].guard_contact_extra(players[1]),players[1].guard_contact_extra(players[0]))
	if distance < contact_distance and distance > 0.001:
		var normal = offset.normalized()
		var push = normal * (contact_distance - distance)
		if players[0].has_ball and players[0].dribble_ended:
			players[1].position -= push
		elif players[1].has_ball and players[1].dribble_ended:
			players[0].position += push
		else:
			var attacker_weight = .85 if ball_owner == 0 else (.15 if ball_owner == 1 else .5)
			if players[0].boxing_out: attacker_weight = .12/players[0].athletic_profile().box_strength
			elif players[1].boxing_out: attacker_weight = 1-.12/players[1].athletic_profile().box_strength
			players[0].position += push * attacker_weight
			players[1].position -= push * (1 - attacker_weight)
		var plane = Vector2(normal.x, normal.z)
		players[0].motion -= plane * minf(0, players[0].motion.dot(plane))
		players[1].motion -= plane * maxf(0, players[1].motion.dot(plane))
		players[0].position = Rules.clamp_to_court(players[0].position)
		players[1].position = Rules.clamp_to_court(players[1].position)

func held_ball_controls(index: int,input: Dictionary,desired: Vector3,delta: float) -> void:
	var p=players[index]
	var h=p.held
	h.pending_shot_left=maxf(0,h.pending_shot_left-delta)
	if phase=="live" and ball_owner==index and p.action=="held_fake" and not h.can_chain(p) and input.shoot:
		h.pending_shot_left=.14;h.pending_kind=""
	if p.action=="square":
		if input.shoot:h.press_time+=delta
		elif not h.queued_release:
			h.queued_release=true;h.pump_release=h.press_time<.18
		if h.square_ready(p):begin_gather(index,true)
	if phase=="live" and ball_owner==index and p.has_ball and p.dribble_ended and p.action in ["idle","held_fake"] and not input.shoot:
		h.capture(p,ball.position)
		h.pending_left=maxf(0,h.pending_left-delta)
		if h.pending_left<=0:h.pending_kind=""
		var requested=""
		for key in ["cross","spin","twostep","behind","hesi"]:
			if input.get(key,false) and not h.input_edges.get(key,false):requested={"cross":"pivot","spin":"turn","twostep":"upunder","behind":"through","hesi":"pump"}[key];break
		if desired.length()<.2:h.direction_latched=false
		elif (not h.direction_latched or h.last_direction.dot(desired.normalized())<.5) and requested=="":
			h.direction_latched=true
			h.last_direction=desired.normalized()
			requested="jab" if desired.normalized().dot(p.global_basis.z)>.65 else "pivot"
		if requested!="":
			if desired.length()>.2:h.direction_latched=true;h.last_direction=desired.normalized()
			h.pending_kind=requested;h.pending_direction=desired;h.pending_left=.14
		if h.pending_kind!="" and h.can_chain(p):
			requested=h.pending_kind
			var feint_direction=h.pending_direction
			h.begin(p,requested,feint_direction,ball.position)
			announce({"pivot":"PIVOT FAKE","jab":"JAB STEP","pump":"PUMP FAKE","upunder":"UP AND UNDER","through":"THROUGH THE LEGS","turn":"TURN FAKE"}[requested],"축발 유지 · 방향 피벗 / A 피벗 · Z 턴 · C 업앤언더 · V 다리 사이 · X 펌프",1.8)
			if requested in ["jab","pivot","turn"]:defender_feint(feint_direction if feint_direction.length()>.1 else p.global_basis.x*p.dribble_hand)
	for key in ["cross","spin","twostep","behind","hesi","shoot"]:h.input_edges[key]=input.get(key,false)

func gather_input(index: int,shoot: bool,delta: float) -> void:
	var p=players[index]
	shot_hold+=delta
	if p.held.queued_release and not shoot:
		if p.held.pump_release:
			if shot_hold>=.10:fake_shot(index)
		elif shot_hold>=.22:launch_shot(index)
	elif p.finish_running:
		if shot_hold>=.20:launch_shot(index)
	elif not shoot:
		if shot_hold+p.held.press_time<.18:fake_shot(index)
		elif not p.turnaround_shot or p.held.square_ready(p):launch_shot(index)
	elif shot_hold>=(.48 if p.turnaround_shot else .62) and (not p.turnaround_shot or p.held.square_ready(p)):launch_shot(index)

func combo_shot(index: int,input: Dictionary,desired: Vector3) -> String:
	if not (input.guard or input.cross):return "jumper"
	var toward=(HOOP-players[index].position)*Vector3(1,0,1)
	if desired.length()>.2 and desired.normalized().dot(toward.normalized())<-.35:return "fadeaway"
	return "hook" if toward.length()<3.5 else "fadeaway"

func begin_gather(index: int,aligned: bool=false,style: String="jumper",finish_input: Vector3=Vector3.ZERO) -> void:
	var p=players[index]
	var after_fake=p.has_ball and p.dribble_ended and not aligned
	var toward=(HOOP-p.position)*Vector3(1,0,1)
	var step_through=(aligned and p.finish_kind=="layup") or (after_fake and style=="jumper" and toward.length()<=3.0 and p.position.z>=HOOP.z-.1 and finish_input.length()>.2 and finish_input.normalized().dot(toward.normalized())>.35)
	if aligned:style=p.shot_style
	p.shot_style=style
	p.shot_rim_yaw=atan2(HOOP.x-p.position.x,HOOP.z-p.position.z)
	var aim=p.shot_rim_yaw-p.dribble_hand*PI*.5 if style=="hook" else p.shot_rim_yaw
	var moving_turn=not aligned and (style!="jumper" or (not p.dribble_ended and p.motion.length()>1.2 and Rules.finish_type(p.position,p.motion)=="shot" and absf(angle_difference(p.rotation.y,aim))>.65))
	p.turnaround_shot=moving_turn;p.shot_release_time=.34 if moving_turn else .22
	if not aligned:
		p.held.queued_release=false;p.held.pump_release=false;p.held.press_time=0
		p.held.clear_pending()
		if not moving_turn and (after_fake or Rules.finish_type(p.position,p.motion)=="shot") and absf(angle_difference(p.rotation.y,aim))>.65:
			p.held.begin(p,"square",Vector3.ZERO,ball.position,aim)
			p.finish_kind="layup" if step_through else "shot";p.finish_running=false
			p.approach_velocity=Vector2(finish_input.x,finish_input.z).normalized()*2.4 if step_through else Vector2.ZERO
			return
	players[index].gather_ball_from=players[index].to_local(ball.position)
	players[index].gather_ball_valid=true
	players[index].approach_velocity = (p.approach_velocity if aligned else Vector2(finish_input.x,finish_input.z).normalized()*2.4) if step_through else players[index].motion
	players[index].finish_kind = "layup" if step_through else p.finish_kind if aligned else "shot" if after_fake or style!="jumper" else Rules.finish_type(players[index].position, players[index].motion)
	players[index].shot_gather_turn = players[index].finish_kind=="shot" and (players[index].motion.length()>1.2 or aligned)
	players[index].shot_gather_yaw = players[index].rotation.y
	players[index].finish_running = step_through or (not players[index].dribble_ended and players[index].finish_kind != "shot" and players[index].motion.length() > 1.2)
	players[index].gather_step_start = players[index].step_serial
	players[index].shot_exit_intent=Vector2.ZERO
	players[index].shot_recovery_left=0.0
	players[index].dribble_ended = true
	players[index].action = "gather"
	players[index].action_time = 0
	players[index].motion = players[index].gather_velocity()
	shot_hold = 0
	face_target(index, HOOP)
	if moving_turn:p.held.begin_turn_shot(p,ball.position,aim);p.shot_gather_turn=true

func fake_shot(index: int) -> void:
	players[index].held.queued_release=false
	players[index].held.begin(players[index],"pump",Vector3.ZERO,ball.position)
	announce("PUMP FAKE", "드리블 종료 · 방향 피벗 / A·Z·C·V·X 페이크 / D 슛", 2.2)
	if mode == "duel" and index == 0 and players[0].position.distance_to(players[1].position) < 2.4 and rng.randf() < 0.65:
		start_defensive_jump(1,"block")
		ai_freeze = 0.9
	play_sound("squeak", -19)

func crossover(input_dir: Vector2) -> void:
	var player = players[0]
	if player.dribble_ended:
		announce("BALL HELD", "두 손으로 잡은 뒤에는 다시 드리블할 수 없습니다. D로 슛하세요.")
		return
	player.prepare_cross(ball.position)
	var handling=clampf(float(player.growth.get("handle",50))-50,-20,40)*.0007
	crossover_cooldown = player.cross_duration()+maxf(.015,.08-player.skill_rank("cross")*.01-handling)
	var side = player.cross_to if absf(input_dir.x) < .2 else signf(input_dir.x)
	var right = Vector3(camera.global_basis.x.x, 0, camera.global_basis.x.z).normalized()
	cross_direction = right * side
	defender_feint(-cross_direction)
	announce("CROSSOVER", "방향 전환으로 공간을 만드세요.", 1.0)
	court_audio.cue("cross")
	play_sound("squeak", -12)

func start_dribble_skill(kind: String, desired: Vector3) -> void:
	var player = players[0]
	if phase != "live" or ball_owner != 0 or player.dribble_ended or player.action != "idle" or crossover_cooldown > 0: return
	player.action = kind
	player.action_time = 0
	player.dribble_phase = 0
	player.turn_origin = player.rotation.y
	player.turn_sign = player.dribble_hand
	skill_forward = desired.normalized() if desired.length() > .1 else Vector3(sin(player.facing), 0, cos(player.facing))
	skill_side = Vector3(skill_forward.z, 0, -skill_forward.x) * player.dribble_hand
	player.facing = player.turn_origin if kind == "spin" else atan2(skill_forward.x, skill_forward.z)
	if kind == "behind": player.dribble_hand *= -1
	var handling=clampf(float(player.growth.get("handle",50))-50,-20,40)*.0007
	crossover_cooldown = DRIBBLE_DURATIONS[kind] + maxf(.015,.06-player.skill_rank("spin")*.009-handling)
	defender_feint(-skill_side if kind == "behind" else skill_side)
	var titles = {"spin": "SPIN MOVE", "twostep": "TWO STEP", "behind": "BEHIND THE BACK", "hesi": "HESITATION"}
	var hints = {"spin": "바깥손으로 공을 보호하며 회전 돌파", "twostep": "드리블을 유지하며 바깥쪽 → 안쪽으로 두 번 돌파", "behind": "등 뒤로 공을 넘기며 반대쪽 돌파", "hesi": "속도를 늦췄다가 첫발로 치고 나가기"}
	announce(titles[kind], hints[kind], 1.3)
	court_audio.cue(kind)
	play_sound("squeak", -13)

func defender_feint(feint: Vector3) -> void:
	if not (mode == "duel" or (mode == "practice" and practice_drill == "recovery")) or ai_reaction_cooldown > 0 or ball_owner != 0: return
	var defender = players[1]
	if defender.chase_recovery: return
	var gap = players[0].position - defender.position
	var to_hoop = Vector3(HOOP.x-players[0].position.x,0,HOOP.z-players[0].position.z).normalized()
	if -gap.dot(to_hoop)<-.25: return
	var forward = Vector3(sin(defender.facing), 0, cos(defender.facing))
	if gap.length() > 2.6 or gap.length() < .75 or gap.normalized().dot(forward) < .35 or defender.action != "idle": return
	var false_step = Vector2(feint.x, feint.z).normalized()
	# A committed defender takes time to reverse weight, but never freezes on a keypress.
	var commitment = maxf(0, defender.motion.dot(false_step))
	ai_reaction = .15 + minf(commitment * .05, .13)
	ai_reaction_velocity = (defender.motion * .65 + false_step * 1.8).limit_length(3.1)
	ai_reaction_cooldown = .85
	defender.prepare_chase_recovery(ai_reaction_velocity)

func launch_shot(index: int) -> void:
	if phase != "live" or ball_owner != index:
		return
	var player = players[index]
	player.held.queued_release=false
	player.finish_ball_from=player.to_local(ball.position)
	player.finish_ball_valid=true
	shooter = index
	event_id += 1
	finish_kind = player.finish_kind
	last_event = finish_kind
	player.action = finish_kind
	player.action_time = 0
	phase = "takeoff"
	shot_committed = true
	timing_bonus = Rules.release_bonus(shot_hold) if index == (team_match.selected if mode == "team" else 0) else 0.0
	release_at = player.shot_release_time if finish_kind == "shot" else (0.34 if finish_kind == "layup" else 0.38)
	takeoff_start = player.position
	takeoff_target = takeoff_start
	if finish_kind=="shot" and player.turnaround_shot:
		player.shot_gather_yaw=player.rotation.y
		var travel=Vector3(player.approach_velocity.x,0,player.approach_velocity.y).normalized()*.36
		if player.shot_style=="fadeaway":travel=Vector3(sin(player.shot_rim_yaw),0,cos(player.shot_rim_yaw))*-.68
		elif player.shot_style=="hook":travel=Vector3(sin(player.shot_rim_yaw),0,cos(player.shot_rim_yaw))*.18
		takeoff_target=Rules.clamp_to_court(takeoff_start+travel)
	if player.shot_style=="hook":player.facing=player.shot_rim_yaw-player.dribble_hand*PI*.5
	if finish_kind != "shot":
		var landing = Vector3(HOOP.x, 0, HOOP.z + 0.52)
		takeoff_target = takeoff_start.move_toward(landing, 1.5 if finish_kind == "dunk" else 0.9)
		player.finish_target_valid = true
		player.finish_rim_world = HOOP
		player.air_start = takeoff_start
		player.air_release = takeoff_target
		player.air_end = takeoff_target.move_toward(Vector3(HOOP.x, 0, HOOP.z + .30), .28)
		if finish_kind == "layup": player.air_end = takeoff_target.move_toward(Vector3(HOOP.x, 0, HOOP.z + .05), .50)
		player.air_release_time = release_at
		if finish_kind == "layup": player.prepare_layup()
	flight_points = Rules.shot_points(takeoff_start) if finish_kind == "shot" else 2
	if (index < 3 if mode == "team" else index == 0): attempts += 1
	play_sound("squeak", -16)
	if index == 0:
		announce("RISING UP" if finish_kind == "shot" else ("FINGER ROLL" if finish_kind == "layup" else "TAKE FLIGHT"), "정점에서 손목을 끝까지." if finish_kind == "shot" else ("한 발 도약, 손끝으로 부드럽게." if finish_kind == "layup" else "속도를 힘으로. 림 위로 올라갑니다."), 1.4)

func release_ball() -> void:
	if mode=="team":team_match.capture_shot(shooter)
	var player = players[shooter]
	# Release from the rendered hand after takeoff, never from a fixed world height.
	flight_start = ball.position
	player.has_ball = false
	player.dribble_ended = false
	ball_owner = -1
	phase = "flight"
	flight_t = 0
	var distance = Vector2(player.position.x, player.position.z - HOOP.z).length()
	flight_duration = clampf(0.52 + distance * 0.07, 0.65, 1.25)
	flight_arc = clampf(distance * 0.28, 1.1, 3.0)
	if player.shot_style=="hook":flight_arc=1.45;flight_duration=maxf(.75,flight_duration)
	if finish_kind == "layup":
		flight_duration = 0.48
		flight_arc = 0.45
	elif finish_kind == "dunk":
		flight_duration = 0.16
		flight_arc = 0.04
	var contest = 0.0
	if mode == "duel":
		var defender = players[1 - shooter]
		contest = clampf(1.0 - player.position.distance_to(defender.position) / 2.15, 0, 1)
		if defender.action == "block": contest = minf(1, contest + 0.15)
	elif mode == "team": contest = team_match.contest(shooter)
	var probability = Rules.shot_probability(distance, contest, player.approach_velocity.length() > 3.0 and finish_kind == "shot")
	if player.shot_style=="fadeaway":probability-=.06
	elif player.shot_style=="hook":probability-=maxf(0,distance-2.5)*.08
	if finish_kind == "dunk": probability = 0.98 - contest * 0.35
	if finish_kind == "layup": probability = 0.93 - contest * 0.48
	if not player.growth.is_empty():
		var stat="shoot" if finish_kind=="shot" else "finish"
		probability+=(float(player.growth.get(stat,55))-55)*.0025+player.skill_rank(stat)*.012
	flight_made = rng.randf() < clampf(probability + timing_bonus, 0.12, .99 if finish_kind == "dunk" else .94)
	if mode == "practice" and practice_drill == "rim" and shooter == 1: flight_made = false
	flight_target = HOOP
	if not flight_made:
		var angle = rng.randf_range(-1.2,1.2)
		if mode == "practice" and practice_drill == "rim" and shooter == 1: angle = 0
		flight_target += Vector3(sin(angle)*.23,.06,cos(angle)*.23)
	if shooter == 0 and player.shot_style!="jumper":
		announce("HOOK SHOT" if player.shot_style=="hook" else "FADEAWAY", "옆으로 몸을 보호하고 한 손으로 높게" if player.shot_style=="hook" else "뒤로 공간을 만들고 손목으로 마무리",1.8)
	elif shooter == 0 and finish_kind == "shot":
		announce("SWEET RELEASE" if timing_bonus > 0 else ("OPEN LOOK" if contest < 0.3 else "CONTESTED"), "좋은 릴리즈 타이밍!" if timing_bonus > 0 else ("좋은 공간에서 던졌어요." if contest < 0.3 else "수비가 가까워요. 페이크나 돌파로 공간을 만드세요."), 1.6)
	play_sound("release", -15)
	ball.position = flight_start

func update_flight(delta: float) -> void:
	flight_t += delta
	var t = clampf(flight_t / flight_duration, 0, 1)
	ball.position = flight_start.lerp(flight_target, t) + Vector3.UP * sin(t * PI) * flight_arc
	if t < 0.55 and try_block(): return
	if t >= 1:
		if flight_made:
			register_score()
		else:
			phase = "loose"
			var rebound_direction = Vector3(flight_target.x-HOOP.x,0,maxf(.08,flight_target.z-HOOP.z)).normalized()
			ball_velocity = rebound_direction*rng.randf_range(1.2,1.9)+Vector3.UP*rng.randf_range(3.9,4.5)
			loose_timer = 0
			play_sound("rim", -10)
			last_event = "rim"
			announce("OFF THE RIM", "W로 자리 잡고 박스아웃 → 내려오는 공을 D로 리바운드", 2.3)

func try_block() -> bool:
	if mode == "team": return team_match.try_block()
	if not opponent_enabled() or phase not in ["takeoff","flight"]: return false
	var defender = players[1 - shooter]
	if defender.action != "block" or defender.action_time < .13 or defender.action_time > .52: return false
	if defender.defensive_jump():
		if not block_lane_open(defender) or defender.action_time < .16 or defender.action_time > .40: return false
		# A downward palm stroke can still rise in world space during takeoff.
		# Measure the arm against the jumping torso; keep windup and recovery
		# inactive and require the same swept, visible palm/ball contact below.
		var palm_velocity = (defender.hand_world.y-defender.previous_hand_world.y)/maxf(defender.pose_delta,.0001)
		if palm_velocity-defender.body_vertical_velocity >= -.12: return false
	if hand_ball_distance(defender.hand_world,defender.previous_hand_world) >= .28: return false
	phase = "loose"
	ball_owner = -1
	players[shooter].has_ball = false
	defender.record_block_contact()
	ball_velocity = defender.block_contact_stroke.normalized()*9.2
	trail_positions.clear()
	loose_timer = 0
	last_event = "block"
	court_audio.cue("block")
	announce("GET THAT OUT!", "손바닥으로 쳐냈습니다! 튕겨 나간 공을 따라가세요.")
	play_sound("block", -7)
	return true

func block_lane_open(defender: Node3D) -> bool:
	var offset = ball.position-defender.position
	offset.y = 0
	# The launch direction is selected on input. The incoming run heading can
	# still differ while the feet and torso turn through the windup.
	var forward = Basis(Vector3.UP,defender.defense_landing_yaw).z
	if offset.length()>1.15 or (offset.length()>.15 and offset.normalized().dot(forward)<.15): return false
	var hand = defender.hand_world
	var path = ball.position-hand
	var chest = players[shooter].body.to_global(Vector3(0,1.8,0))
	var t = (chest-hand).dot(path)/maxf(path.length_squared(),.00001)
	if t>.1 and t<.9:
		var near = hand+path*t
		if Vector2(near.x-chest.x,near.z-chest.z).length()<.25 and absf(near.y-chest.y)<.50: return false
	return true

func ai_can_attempt_block() -> bool:
	if ai_reaction>0 or ai_freeze>0 or players[1].chase_recovery: return false
	var attack = players[0]
	var defender = players[1]
	var toward = Vector3(HOOP.x-attack.position.x,0,HOOP.z-attack.position.z).normalized()
	var gap = defender.position-attack.position
	var inside = gap.dot(toward)>=-.25
	return inside or (gap.length()<.75 and ai_reaction_cooldown<=0)

func hand_ball_distance(hand: Vector3,old_hand: Vector3) -> float:
	var distance = ball.position.distance_to(hand)
	# Sweep the relative path so a fast ball cannot skip the hand between ticks.
	if previous_ball_position.distance_to(ball.position) > 1.5 or old_hand.distance_to(hand) > .75: return distance
	var a = previous_ball_position-old_hand
	var b = ball.position-hand
	var path = b-a
	var t = clampf(-a.dot(path)/maxf(path.length_squared(),.000001),0,1)
	return minf(distance,(a+path*t).length())

func register_score() -> void:
	if mode == "team":
		team_match.register_score()
		return
	if last_scored_event == event_id:
		return
	last_scored_event = event_id
	scores[shooter] += flight_points
	if shooter == 0: makes += 1
	phase = "dead"
	reset_timer = 1.5
	last_event = "score"
	court_audio.cue(finish_kind if finish_kind in ["dunk","layup"] else ("three" if flight_points == 3 else "score"))
	announce("SWISH! +%d" % flight_points if shooter == 0 else "RIVAL +%d" % flight_points, "좋은 슛! 다음 플레이로 이어가세요." if shooter == 0 else "다음 공격은 내 차례입니다.", 2)
	play_sound("swish", -6)
	if finish_kind == "dunk":
		announce("BOOM! +2" if shooter == 0 else "RIVAL SLAM +2", "림 위에서 마무리. 다음 공격으로!", 2)
		play_sound("slam", -5)
		impact = 0.32
		impact_ring.position = Vector3(HOOP.x, 0.16, HOOP.z + 0.5)
	elif finish_kind == "layup":
		announce("SOFT TOUCH +2" if shooter == 0 else "RIVAL LAYUP +2", "손끝에서 림으로, 부드러운 마무리.", 2)

func update_loose(delta: float) -> void:
	loose_timer += delta
	var previous=ball.position
	ball_velocity.y -= 9.8 * delta
	ball.position += ball_velocity * delta
	if ball.position.y < Actor.DRIBBLE_FLOOR:
		ball.position.y = Actor.DRIBBLE_FLOOR
		if absf(ball_velocity.y) > 0.8: play_sound("bounce", -12)
		ball_velocity.y = absf(ball_velocity.y) * 0.56
		ball_velocity.x *= 0.76
		ball_velocity.z *= 0.76
	if Rules.ball_outside(ball.position):
		turnover("OUT OF BOUNDS", "체크볼로 다시 시작합니다.", 1 - shooter)
		return
	var candidates: Array = []
	for i in range(2 if opponent_enabled() else 1):
		var player = players[i]
		var catch_distance = hand_ball_distance(player.rebound_anchor(),player.previous_rebound_anchor)
		var both_hands = maxf(ball.position.distance_to(player.palm_position(0)),ball.position.distance_to(player.palm_position(1))) < .34
		var airborne_catch = player.action == "rebound" and player.jump > .18 and player.action_time > .16 and player.action_time < player.defense_land_time() and catch_distance < .24 and both_hands
		var contact=loose_contact(player,previous)
		if contact<1.0 or airborne_catch and not rebound_blocked(i):
			candidates.append({"id": i, "distance": catch_distance if airborne_catch else contact})
	if not candidates.is_empty():
		candidates.sort_custom(func(a, b): return a.distance < b.distance if a.distance != b.distance else a.id < b.id)
		claim_ball(candidates[0].id)
	elif mode == "practice" and loose_timer > 2.5:
		reset_positions(0)
	elif loose_timer > 10:
		turnover("CHECK BALL", "경기를 다시 이어갑니다.", 1 - shooter)

func claim_ball(index: int) -> void:
	var just_blocked = last_event == "block" and loose_timer < .75
	if players[index].action == "rebound": players[index].capture_rebound(ball.position,ball_velocity)
	else:players[index].begin_pickup(ball.position)
	ball_owner = index
	phase = "live"
	needs_clear = mode == "duel" and index != shooter and not Rules.is_clear(players[index].position)
	shot_clock = 15 if index != shooter else 10
	for i in range(2):
		players[i].has_ball = i == index
		players[i].dribble_ended = false
		players[i].boxing_out = false
	last_event = "rebound"
	ball.position = players[index].ball_anchor(time)
	var air_catch = players[index].action == "rebound" and players[index].defense_caught
	if air_catch: court_audio.cue("rebound")
	if just_blocked:
		announce("BLOCK! · YOUR BALL" if index == 0 else "BLOCK! · RIVAL BALL", "블록 성공! 내가 공을 확보했습니다." if index == 0 else "블록 성공! 상대가 공을 다시 잡았습니다.",1.8)
	else:
		announce("AIR CATCH!" if index == 0 and air_catch else ("YOUR REBOUND" if index == 0 else "RIVAL REBOUND"), "양손 확보 → 가슴으로 당기기 → 착지" if air_catch else ("외곽선 밖으로 공을 빼세요." if needs_clear and index == 0 else "다음 공격을 이어가세요."))
	play_sound("block", -18) # Short hand/ball impact, not a floor bounce at an air catch.

func loose_contact(player,previous: Vector3) -> float:
	# A free ball touching the body or an open catching hand is playable at
	# once, including the rising first bounce. No timer or low-height gate.
	var low=player.global_position+Vector3.UP*(player.jump+.18*player.height_ratio)
	var high=player.global_position+Vector3.UP*(player.jump+1.70*player.height_ratio)
	var distance=Rules.segment_gap(previous,ball.position,low,high)/(.31*player.height_ratio+Art.BALL_RADIUS)
	if player.action!="block":
		for side in 2:
			var palm=player.palm_position(side)
			distance=minf(distance,Rules.segment_gap(previous,ball.position,palm,palm)/(.13+Art.BALL_RADIUS))
	return distance

func attempt_steal() -> void:
	if players[0].action != "idle" or phase != "live" or ball_owner != 1: return
	steal_cooldown = 1.1
	var forward = Vector3(sin(players[0].facing), 0, cos(players[0].facing))
	var eligible = Rules.can_steal(players[1].position,players[0].position,forward) and players[1].action == "idle"
	var target = ball.position if (ball.position-players[0].position).dot(forward) > 0 else players[0].position+forward*.8+Vector3.UP
	players[0].prepare_steal(target,players[1].position,eligible)
	players[0].steal_end = Rules.clamp_to_court(players[0].steal_end)
	play_sound("squeak",-19)

func resolve_steal() -> void:
	var player = players[0]
	if not player.stealing() or player.steal_success or player.steal_resolved or phase != "live" or ball_owner != 1: return
	player.steal_target = ball.position
	if player.action_time < .12 or player.action_time > .32: return
	if not player.steal_eligible or players[1].action != "idle": return
	if hand_ball_distance(player.hand_world,player.previous_hand_world) >= .25: return
	# Possession attaches at this tick's hand, so the current palm must still touch.
	if player.hand_world.distance_to(ball.position) >= .25: return
	player.steal_resolved = true
	if rng.randf() < clampf(.65+(float(player.growth.get("defense",50))-50)*.003+player.skill_rank("steal")*.012,.4,.85):
		players[1].has_ball = false
		player.has_ball = true
		player.dribble_ended = false
		player.receive_steal(ball.position)
		ball_owner = 0
		ball.position = player.ball_anchor(time)
		needs_clear = mode == "duel" and not Rules.is_clear(player.position)
		shot_clock = 15
		last_event = "steal"
		court_audio.cue("steal")
		announce("STEAL!", "외곽선 밖으로 공을 빼고 공격하세요." if needs_clear else "공을 가져왔어요. 드리블로 이어가세요.")
		play_sound("block", -12)
	else:
		announce("REACH MISSED", "상대가 공을 지켰어요. 손을 회수하고 수비로 돌아갑니다.", 1)

func update_ai(delta: float) -> void:
	var ai = players[1]
	if ai.contesting_boxout:
		if ai_boxout_time == 0: ai_boxout_side = signf(ai.position.x-players[0].position.x) if absf(ai.position.x-players[0].position.x) > .15 else 1.0
		ai_boxout_time += delta
	else:
		ai_boxout_time = 0
	var to_hoop = Vector3(HOOP.x-players[0].position.x,0,HOOP.z-players[0].position.z).normalized()
	var behind = (ai.position-players[0].position).dot(to_hoop)<-.25
	ai.defending = ball_owner == 0 and not behind and not ai.chase_recovery and ai.position.distance_to(players[0].position) < 2.6
	if phase == "dead":
		ai.motion = ai.motion.move_toward(Vector2.ZERO, delta * 20)
		return
	if mode == "practice" and practice_drill == "steal":
		ai.motion = Vector2.ZERO
		return
	ai_decision -= delta
	if ai_decision <= 0:
		ai_decision = rng.randf_range(0.16, 0.29)
		if phase == "loose":
			ai_goal = rebound_target()
		elif phase == "flight":
			var target = rebound_target()
			var attacker_side = (players[0].position-target).normalized()
			ai_goal = target + attacker_side * .65 if shooter == 0 else target
		elif ball_owner == 0:
			var toward_hoop = (Vector3(HOOP.x, 0, HOOP.z) - players[0].position).normalized()
			var prediction = Vector3(players[0].motion.x, 0, players[0].motion.y) * .12
			ai_goal = Rules.clamp_to_court(players[0].position + toward_hoop * 1.15 + prediction)
		elif ball_owner == 1:
			if needs_clear:
				ai_goal = Vector3(ai.position.x, 0, 1.6)
			else:
				ai_goal = Vector3(sin(time * 0.8) * 1.2, 0, -4.4) if event_id % 2 == 0 else Vector3(sin(time * 0.8) * 2.8, 0, -2.0)
		if (phase == "takeoff" or (phase == "flight" and flight_t/flight_duration < .30)) and shooter == 0 and ai.action == "idle" and ai.position.distance_to(players[0].position) < 2 and ai_can_attempt_block() and rng.randf() < 0.7:
			start_defensive_jump(1,"block")
	var offset = ai_goal - ai.position
	if ai_boxout_time > .25 and phase in ["flight","loose"]:
		var toward_ball = (rebound_target()-ai.position).normalized()
		var side = Vector3(-toward_ball.z,0,toward_ball.x)*ai_boxout_side
		offset = players[0].position + side*.92 + toward_ball*.20 - ai.position
	var speed = 3.7 if ball_owner != 1 else 3.35
	if not career_match_id.is_empty():speed=ai.athletic_profile().speed*(.80 if ball_owner!=1 else .74)
	if ai.boxing_out: speed = 1.6
	if ai_freeze > 0 or ai.action != "idle": speed = 0.35
	speed *= ai.landing_speed_scale()
	var movement = Vector2(offset.x, offset.z).limit_length() * speed if offset.length() > 0.16 else Vector2.ZERO
	if ball_owner == 0: movement *= clampf(offset.length() / .8, 0, 1)
	if ai_reaction > 0 and ai_freeze <= 0 and ai.action == "idle" and not ai.chase_recovery: movement = ai_reaction_velocity
	if ai.chase_recovery or (behind and ball_owner == 0):
		if movement.length()>.1: ai.facing = atan2(movement.x,movement.y)
	ai.steer_motion(movement,8 if ball_owner == 0 else 19,delta)
	if ai.has_ball and ai.dribble_ended:
		ai.motion = ai.gather_velocity() if ai.action == "gather" else Vector2.ZERO
	if not (phase == "takeoff" and shooter == 1): move_player(1, delta)
	if not ai.defensive_jump() and not ai.chase_recovery and not (behind and ball_owner == 0): face_target(1, players[0].position if ball_owner == 0 else HOOP)
	if ai.action == "idle" and ai_rebound_ready(1):
		start_defensive_jump(1,"rebound")
	if ball_owner == 1 and phase == "live":
		if needs_clear and Rules.is_clear(ai.position): needs_clear = false
		if not needs_clear and ai.action == "idle" and (ai.position.z < (-3.9 if event_id % 2 == 0 else -1.6) or shot_clock < 4):
			begin_gather(1)
		if ai.action == "gather" and ai.action_time > (.20 if ai.finish_running else .55):
			launch_shot(1)

func turnover(title: String, subtitle: String, next_owner: int = -1) -> void:
	var who = next_owner
	if who < 0: who = 1 - maxi(ball_owner, 0)
	if mode == "practice": who = 0
	reset_positions(who)
	last_event = "turnover"
	announce(title, subtitle)
	play_sound("whistle", -16)

func finish_match() -> void:
	phase = "ended"
	ball_owner = -1
	for player in players: player.has_ball = false
	announce("YOU WIN" if scores[0] > scores[1] else "RUN IT BACK", "한 판 더? 다음 경기는 또 다른 흐름입니다.", 99)
	last_event = "finished"
	if scores[0] > scores[1]: court_audio.cue("win")
	play_sound("whistle", -9)
	send_state()

func update_ball_visual() -> void:
	impact_ring.visible = impact > 0 and not reduced_motion
	ball_shadow.position = Vector3(ball.position.x, 0.145, ball.position.z)
	ball_shadow.scale = Vector3.ONE * clampf(1 - ball.position.y * 0.07, 0.4, 1)
	if not paused:
		ball.rotation.x += 0.07
		ball.rotation.z += 0.035
	if (phase == "flight" or (phase == "loose" and last_event == "block" and loose_timer < .22)) and not reduced_motion:
		if not paused: trail_positions.push_front(ball.position)
		if trail_positions.size() > 18: trail_positions.pop_back()
		for i in range(trail.size()):
			var index = (i + 1) * 2
			trail[i].visible = trail_positions.size() > index
			if trail[i].visible: trail[i].position = trail_positions[index]
	else:
		for point in trail: point.visible = false
		trail_positions.clear()

func send_state() -> void:
	var state = {
		"ready": true, "started": started, "paused": paused, "mode": mode,
		"pauseReason": pause_reason,
		"phase": phase, "owner": ball_owner, "score": scores, "seconds": ceili(clock_left),
		"shotClock": ceili(shot_clock), "clear": needs_clear, "attempts": attempts,
		"makes": makes, "headline": feedback, "detail": feedback_sub,
		"feedback": feedback_timer > 0, "charge": shot_hold / 0.62 if players[0].action == "gather" else 0,
		"crossReady": crossover_cooldown <= 0, "event": last_event,
		"player": [snappedf(players[0].position.x, 0.01), snappedf(players[0].position.z, 0.01)],
		"ball": [snappedf(ball.position.x, 0.01), snappedf(ball.position.y, 0.01), snappedf(ball.position.z, 0.01)],
		"action": players[0].action, "sound": sound_enabled
	}
	if frame_probe:
		state["profile"]={"processMs":Performance.get_monitor(Performance.TIME_PROCESS)*1000,"physicsMs":Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000,"drawCalls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),"objects":Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),"adapter":RenderingServer.get_video_adapter_name()}
	state["finish"] = (players[0].shot_style if players[0].shot_style!="jumper" else players[0].finish_kind) if players[0].action in ["gather","shot"] else Rules.finish_type(players[0].position, players[0].motion)
	if players[0].has_ball and players[0].dribble_ended and players[0].action not in ["gather","shot"]:state["finish"]="shot"
	state["sweet"] = Rules.release_bonus(shot_hold) > 0 and players[0].action == "gather"
	state["drill"] = practice_drill
	state["slowPractice"] = practice_slow
	state["boxout"] = players[0].boxing_out
	state["guard"] = players[0].defending and players[0].action == "idle" and not players[0].has_ball and not players[0].boxing_out
	state["secured"] = players[0].action == "rebound" and players[0].defense_caught
	state["inspecting"] = inspecting
	state["closeup"] = showroom_closeup
	state["motionPreview"] = showroom_motion
	state["held"] = players[0].has_ball and players[0].dribble_ended
	state["courtRole"] = players[0].court_role
	state["careerMatchId"]=career_match_id
	state["careerMode"]="team" if mode=="team" and not career_match_id.is_empty() else "duel" if not career_match_id.is_empty() else ""
	state["careerStage"]=career_stage
	state["canChangeRole"] = not started or phase == "ended" or (mode == "practice" and phase == "live" and players[0].action == "idle")
	if not career_match_id.is_empty():state["canChangeRole"]=false
	state["defenseAction"] = defense_kind(0) if not players[0].has_ball and phase in ["live","takeoff","flight","loose"] else ""
	state["reboundWindow"] = state["defenseAction"] == "rebound"
	if mode == "team" and team_match != null and players.size() == 6: team_match.decorate_state(state)
	if court_audio != null:
		state["musicTrack"] = court_audio.track_index
		state["audioCalls"] = court_audio.calls_played
		state["commentary"] = court_audio.last_call_key
		state["commentaryLine"] = court_audio.last_line
	if OS.has_feature("web"):
		JavaScriptBridge.eval("if(window.ufUpdate)window.ufUpdate(%s);" % JSON.stringify(state))
	elif native_hud != null:
		native_hud.text = "COURT RUSH   |   %d : %d\nArrows: move   D: shoot / jump   A: crossover   S: steal\n1: practice   2: 1v1   Esc: pause\n%s" % [scores[0], scores[1], feedback]

