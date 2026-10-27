extends SceneTree

var failures=0
var cases=0
var contacts=0
var rising_contacts=0

func _init():call_deferred("run")
func check(ok:bool,message:String):
	if not ok:
		failures+=1
		if failures<20:push_error(message)
func key(code:Key,down:bool):
	var e=InputEventKey.new();e.keycode=code;e.physical_keycode=code;e.pressed=down
	Input.parse_input_event(e);Input.flush_buffered_events()
func setup(game,profile:Dictionary,gap:float):
	key(KEY_D,false);key(KEY_W,false)
	game.start_mode("practice");game.set_drill("block")
	var p=game.players[0]
	p.apply_athlete(profile);game.players[1].apply_athlete({"role":"forward","height":190})
	p.position=Vector3(0,0,-3.30-gap);p.reset_stance();p.feet_world.clear()
	game.face_target(0,game.players[1].position);p.rotation.y=p.facing
	return p
func run():
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game);game.set_physics_process(false);game.sound_enabled=false
	for fps in [30,60,120]:
		var dt=1.0/fps
		for profile in [{"role":"guard","height":178},{"role":"center","height":204}]:
			var rising_in_window=false
			# Sample a reaction window rather than expecting every press time to
			# catch the same moving ball after frame-rate quantization.
			var delays=[.48,.50,.52,.54,.56] if profile.role=="guard" else [.54,.56,.58,.60,.62]
			for delay in delays:
				var p=setup(game,profile,.80)
				for f in int(round(delay*fps)):game._physics_process(dt)
				key(KEY_D,true)
				var contact_time=-1.0
				var contact_height=0.0
				var follow_checked=false
				for f in fps:
					var before=p.block_contact
					game._physics_process(dt)
					if p.block_contact and not before:
						contacts+=1
						contact_time=p.action_time
						contact_height=p.hand_world.y-p.body.global_position.y
						var velocity=(p.hand_world-p.previous_hand_world)/dt
						if velocity.y>0:rising_contacts+=1;rising_in_window=true
						var normal=p.palm_frame(1 if p.dribble_hand>0 else 0).z
						var incoming=((game.ball.position-game.previous_ball_position)/dt-velocity).dot(normal)
						check(velocity.y-p.body_vertical_velocity<-.12 or incoming<-.25,"Neither a downward stroke nor an incoming ball met the palm")
						check(p.palm_frame(1 if p.dribble_hand>0 else 0).z.dot(Vector3.DOWN)>.55,"Visible palm struck edge-on")
						check(game.phase=="loose" and game.ball_velocity.y<-5 and game.ball_velocity.length()>8.5,"Block did not swat the real ball away")
					if contact_time>=0 and not follow_checked and p.action_time-contact_time>=.10:
						follow_checked=true
						check(p.hand_world.y-p.body.global_position.y<contact_height-.06,"Swatting arm did not follow down through contact")
				if contact_time>=0:check(follow_checked,"Contact did not continue into follow-through")
				cases+=1
			check(rising_in_window,"No valid jumping downward stroke in reaction window: %s %dfps"%[profile.role,fps])
		# W may establish inside position while the shot is still rising. D must
		# still select a block while the ball is in reachable early flight.
		var p=setup(game,{"role":"forward","height":190},.80)
		key(KEY_W,true)
		for f in int(round(.84*fps)):game._physics_process(dt)
		check(p.boxing_out,"Guarded fixture did not establish inside position")
		key(KEY_D,true);game._physics_process(dt)
		check(p.action=="block","Holding W converted an early shot block into a rebound")
		cases+=1
		# Turning toward a shot uses the chosen jump direction, while the feet
		# and body continue rotating from the incoming running pose.
		p=setup(game,{"role":"forward","height":190},.80)
		for f in int(round(.34*fps)):game._physics_process(dt)
		p.rotation.y=PI
		key(KEY_D,true)
		var turned_contact=false
		for f in fps:
			game._physics_process(dt)
			turned_contact=turned_contact or p.block_contact
		check(turned_contact,"Incoming heading locked the block behind the actual shot: %dfps"%fps)
		cases+=1
		for profile in [{"role":"guard","height":178},{"role":"center","height":204}]:
			p=setup(game,profile,1.70)
			for f in int(round(.34*fps)):game._physics_process(dt)
			key(KEY_D,true)
			for f in fps:game._physics_process(dt)
			check(not p.block_contact,"Unreachable shot was blocked without palm contact");cases+=1
	key(KEY_D,false);key(KEY_W,false)
	check(rising_contacts>0,"No actual upward-moving palm contact covered the body-relative strike")
	print("BLOCK_PLAYABILITY cases=",cases," contacts=",contacts," rising_contacts=",rising_contacts," failures=",failures)
	game.queue_free();await process_frame;quit(1 if failures else 0)
