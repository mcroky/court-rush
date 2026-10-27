extends SceneTree

const WebFixture=preload("res://tests/block_quick_input_test.gd")
var failures=0
var cases=0
var contacts=0
var incoming_contacts=0
func _init():call_deferred("run")
func check(ok:bool,message:String):
	if not ok:
		failures+=1
		if failures<16:push_error(message)
static func setup(g,role:String,angle:float,gap:float):
	g.web_input=null;g.start_mode("duel");g.reset_positions(1);g.needs_clear=false
	var owner=g.players[1];var p=g.players[0]
	owner.position=Vector3(sin(angle)*3,0,g.HOOP.z+cos(angle)*3)
	p.apply_athlete({"role":role,"height":{"guard":178,"forward":190,"center":204}[role]})
	p.position=owner.position+(g.HOOP-owner.position).normalized()*gap
	g.ai_goal=owner.position;g.ai_decision=999;g.ai_freeze=999
	for i in 2:
		g.players[i].motion=Vector2.ZERO;g.players[i].reset_stance();g.players[i].feet_world.clear()
		g.face_target(i,owner.position if i==0 else g.HOOP);g.players[i].rotation.y=g.players[i].facing;g.players[i].animate(1.0/60,0)
	g.ball.position=owner.ball_anchor(0);g.previous_ball_position=g.ball.position
	g.begin_gather(1)
	var input=WebFixture.web();input.guard=true;g.web_input=input;g.web_control_reset=-1;g.web_shoot_seq=0
	return input
static func setup_drive(g,role:String,diagonal:bool):
	var input=setup(g,role,0,.8);var owner=g.players[1];var p=g.players[0]
	owner.position=Vector3(.95,0,-3.88) if diagonal else Vector3(0,0,-3.3)
	p.position=Vector3(.70,0,-4.88) if diagonal else Vector3(0,0,-4.1)
	owner.action="idle";owner.dribble_ended=false;owner.motion=Vector2(1.5,-3.0) if diagonal else Vector2(0,-3.35)
	g.ai_goal=Vector3(0,0,-4.4)
	for i in 2:
		g.players[i].reset_stance();g.face_target(i,owner.position if i==0 else g.HOOP);g.players[i].rotation.y=g.players[i].facing
		g.players[i].animate(1.0/60,0)
	g.ball.position=owner.ball_anchor(0);g.previous_ball_position=g.ball.position;g.begin_gather(1)
	return input
func run():
	var g=load("res://scenes/main.tscn").instantiate();root.add_child(g);g.set_physics_process(false);g.sound_enabled=false
	for fps in [30,60,120]:
		var dt=1.0/fps
		for role in ["guard","forward","center"]:
			for angle in [-PI/4,0,PI/4]:
				var successes=0
				# Normal-speed 1v1 AI owns the gather and takeoff. React at several
				# visible points, rather than matching a single practice-drill time.
				for reaction in [.30,.40,.50,.60,.65]:
					var input=setup(g,role,angle,.80);var p=g.players[0]
					for f in roundi(reaction*fps):g._physics_process(dt)
					input.shootSeq=1
					var touched=false
					var contact_height=0.0
					var contact_relative_height=0.0
					for f in roundi(.60*fps):
						g._physics_process(dt)
						if p.block_contact:
							touched=true;contacts+=1;successes+=1
							check(g.hand_ball_distance(p.hand_world,p.previous_hand_world)<.28,"1v1 swat without actual visible palm contact")
							check(p.palm_frame(1 if p.dribble_hand>0 else 0).z.dot(Vector3.DOWN)>.55,"1v1 palm did not face down at impact")
							check(g.phase=="loose" and g.ball_velocity.y < -5,"1v1 contact did not swat the real ball down")
							if (p.hand_world.y-p.previous_hand_world.y)/dt-p.body_vertical_velocity>=-.12:incoming_contacts+=1
							contact_height=p.hand_world.y
							contact_relative_height=p.hand_world.y-p.body.global_position.y
							break
					if touched:
						for f in ceili(.24*fps):g._physics_process(dt)
						# The torso may still rise at impact; during descent the whole
						# palm can fall while its height above the chest stays similar.
						check(p.hand_world.y<contact_height-.06 or p.hand_world.y-p.body.global_position.y<contact_relative_height-.06 or p.action=="pickup" and p.has_ball,"1v1 follow %s %s %s action=%s delta=%s relative=%s"%[role,reaction,fps,p.action,p.hand_world.y-contact_height,p.hand_world.y-p.body.global_position.y-contact_relative_height])
					cases+=1
				check(successes>=3,"1v1 reaction window too narrow %s angle=%s fps=%s hits=%s"%[role,angle,fps,successes])
		for role in ["guard","forward","center"]:
			for diagonal in [false,true]:
				var drive_contacts=0
				for reaction in [.18,.22,.26,.30,.34]:
					var input=setup_drive(g,role,diagonal);var owner=g.players[1];var p=g.players[0]
					check(owner.finish_kind=="layup","Running AI fixture did not choose a real layup")
					for f in roundi(reaction*fps):g._physics_process(dt)
					input.shootSeq=1
					for f in roundi(.6*fps):
						g._physics_process(dt)
						if p.block_contact:
							drive_contacts+=1;contacts+=1
							check(g.hand_ball_distance(p.hand_world,p.previous_hand_world)<.28 and g.phase=="loose","Running layup blocked without visible contact")
							break
					cases+=1
				check(drive_contacts>=2,"Running 1v1 layup window too narrow %s %s fps diagonal=%s contacts=%s"%[role,fps,diagonal,drive_contacts])
		# Late, high shots and far shots must still escape a real jumping palm.
		for gap in [.8,2.2]:
			var input=setup(g,"guard",0,gap)
			if gap<1:
				while g.phase!="flight":g._physics_process(dt)
				for f in roundi(.25*fps):g._physics_process(dt)
			else:
				for f in roundi(.4*fps):g._physics_process(dt)
			input.shootSeq=1
			for f in roundi(.6*fps):g._physics_process(dt)
			check(not g.players[0].block_contact,"Late/high or distant shot was blocked gap=%s fps=%s"%[gap,fps]);cases+=1
	print("BLOCK_REACTION normal 1v1 cases=",cases," contacts=",contacts," rising_arm_contacts=",incoming_contacts," failures=",failures)
	g.web_input=null;g.queue_free();await process_frame;quit(1 if failures else 0)



