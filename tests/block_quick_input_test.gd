extends SceneTree
var failures=0
func _init():call_deferred("run")
func check(ok:bool,message:String):
	if not ok:failures+=1;push_error(message)
static func web() -> Dictionary:
	return {"appearance":"{}","sound":false,"reduced":false,"x":0,"z":0,"shoot":false,"shootSeq":0,"shootCancelSeq":0,"cross":false,"spin":false,"twostep":false,"behind":false,"hesi":false,"steal":false,"guard":false,"passBall":false,"switchPlayer":false,"controlReset":0,"switchSeq":0,"passSeq":0,"commandId":0,"command":"","suspended":false,"pauseReason":"","audio":"{}","audioSuspended":false,"compactCamera":false}
func run():
	var g=load("res://scenes/main.tscn").instantiate();root.add_child(g);g.set_physics_process(false);g.sound_enabled=false
	for mode in ["practice","team"]:
		g.web_input=null;g.start_mode(mode)
		if mode=="practice":g.set_drill("block")
		else:
			var t=g.team_match;t.reset(1);t.selected=0;t.decisions=999
			for i in 6:
				g.players[i].position=Vector3((i-2)*2.5,0,2);g.players[i].motion=Vector2.ZERO;t.goals[i]=g.players[i].position
			g.players[3].position=Vector3(0,0,-3.3);t.goals[3]=g.players[3].position;g.ball_owner=3;g.players[3].has_ball=true
			g.begin_gather(3);g.players[3].finish_kind="shot";g.players[3].finish_running=false
		var p=g.players[0];p.position=Vector3(0,0,-4.1);p.reset_stance();p.feet_world.clear();g.face_target(0,g.players[1 if mode=="practice" else 3].position);p.rotation.y=p.facing
		var input=web();g.web_input=input;g.web_control_reset=-1;g.web_shoot_seq=0
		for frame in 20:g._physics_process(1.0/60)
		# Press and release entirely between two game ticks.
		input.shootSeq=1
		g._physics_process(1.0/60)
		check(p.action=="block",mode+" missed a quick defensive jump")
		var touched=false
		for frame in 55:
			if mode=="team" and frame==8:g.launch_shot(3)
			g._physics_process(1.0/60)
			if p.block_contact:
				touched=true
				check(g.phase=="loose" and g.ball_velocity.y< -5,mode+" did not swat the ball")
				break
		check(touched,mode+" quick press did not reach the real ball")
		var contact_point=g.ball.position
		for frame in 12:
			g._physics_process(1.0/60)
			if frame<9:check(g.phase=="loose" and g.ball_owner<0,mode+" immediately recaptured a swatted ball")
			if frame==5:check(g.ball.position.distance_to(contact_point)>.85,mode+" block did not visibly leave the contact")
		# An input released by lifecycle reset or pointer cancellation must not jump.
		g.web_input=null;g.start_mode(mode);p=g.players[0];p.has_ball=false;g.ball_owner=1 if mode=="practice" else 3;g.phase="live"
		input=web();g.web_input=input;g.web_control_reset=-1;g.web_shoot_seq=0;g.read_controls()
		input.shootSeq=1;input.shootCancelSeq=1
		check(not g.read_controls().shoot_pressed,mode+" fired a cancelled touch")
		input.shootSeq=2;input.controlReset=1
		check(not g.read_controls().shoot_pressed,mode+" fired a press invalidated by pause/reset")
		input.shootSeq=3;input.shoot=true
		var held=g.read_controls();check(held.shoot and held.shoot_pressed,mode+" did not retain a held press")
		held=g.read_controls();check(held.shoot and not held.shoot_pressed,mode+" repeated a held press")
		input.shoot=false;input.shootSeq=4;g.resume_input_lock=true
		var resumed=g.read_controls();g.gate_resumed_input(resumed)
		check(not resumed.shoot_pressed and g.resume_input_lock,mode+" fired a quick press before neutral resume")
		resumed=g.read_controls();g.gate_resumed_input(resumed);check(not g.resume_input_lock,mode+" did not unlock after neutral resume")
	# Recoveries after the escape period name the block and correct owner.
	for mode in ["practice","team"]:
		for owner in [0,1]:
			g.web_input=null;g.start_mode(mode);g.phase="loose";g.last_event="block";g.loose_timer=.3
			if mode=="team":g.team_match.claim(0 if owner==0 else 3,"LOOSE BALL")
			else:g.claim_ball(owner)
			check(g.feedback==("블록 성공! · 우리 공" if owner==0 else "블록 성공! · 상대 공"),mode+" wrong block/recovery owner")
		g.start_mode(mode);g.phase="loose";g.last_event="block";g.loose_timer=.9
		if mode=="team":g.team_match.claim(0,"LOOSE BALL")
		else:g.claim_ball(0)
		check(not g.feedback.begins_with("블록 성공!"),mode+" stale block replaced a later rebound")
	print("BLOCK_QUICK_INPUT practice+team, real contact, swat escape/later possession, cancelled/paused inputs failures=",failures)
	g.web_input=null;g.queue_free();await process_frame;quit(1 if failures else 0)
