extends SceneTree
var failures=0
var cases=0
var max_knee_speed=0.0
var max_palm_speed=0.0
func _init():call_deferred("run")
func check(ok: bool,message: String):
	if not ok:
		failures+=1
		if failures<22:push_error(message)
func key(code: Key,down: bool):
	var e=InputEventKey.new();e.keycode=code;e.physical_keycode=code;e.pressed=down;Input.parse_input_event(e);Input.flush_buffered_events()
func run():
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_physics_process(false);game.sound_enabled=false
	for mode in ["practice","team"]:
		for fps in [30,60,120]:
			for hand in [-1.0,1.0]:
				for style in ["hook","fadeaway"]:
					for code in [KEY_UP,KEY_DOWN,KEY_W,KEY_A,KEY_D]:key(code,false)
					game.start_mode(mode);var p=game.players[0];var v=p.skinned;var dt=1.0/fps
					p.position=Vector3(1.2,0,-3.6) if style=="hook" else Vector3(0,0,1.0)
					p.rotation.y=PI;p.facing=PI;p.reset_stance();p.dribble_hand=hand;p.feet_world.clear()
					if mode=="team":game.team_match.decisions=99
					for i in range(1,game.players.size()):game.players[i].position=Vector3(6,0,4+i*.2)
					for f in int(fps*.2):game._physics_process(dt)
					# Test the actual existing-key chord, not a direct shot invocation.
					if hand>0:key(KEY_W,true)
					else:
						key(KEY_A,true)
						for f in maxi(1,int(.05*fps)):game._physics_process(dt)
					if style=="fadeaway":key(KEY_DOWN,true)
					key(KEY_D,true)
					var released=false;var aerial_turn=0.0;var old_yaw=p.rotation.y;var launched=false;var start=Vector3.ZERO
					var old_knees=[];var old_palms=v.palm_world.duplicate()
					for chain in v.feet:old_knees.append(v.bone_world(chain[1]).origin)
					for f in int(fps*1.6):
						game._physics_process(dt)
						if p.action=="gather":check(p.shot_style==style,"Input chord selected wrong shot")
						if p.action=="shot" and not launched:launched=true;start=p.position
						if p.action=="shot" and p.jump>.02:aerial_turn+=absf(angle_difference(old_yaw,p.rotation.y))
						if game.phase=="flight" and not released:
							released=true
							if style=="fadeaway":
								check(p.position.distance_to(start)>.55,"Fadeaway did not create space")
								check(p.global_basis.z.dot((game.HOOP-p.position).normalized())>.92,"Fadeaway released backwards")
							else:
								check(absf(p.global_basis.z.dot(((game.HOOP-p.position)*Vector3(1,0,1)).normalized()))<.18,"Hook did not protect the ball side-on")
								check(p.palm_position(1 if hand>0 else 0).y>v.bone_world(v.skeleton.find_bone("head")).origin.y+.1,"Hook hand did not extend above head")
								check(p.palm_position(0).distance_to(p.palm_position(1))>.30,"Hook guide hand did not peel away")
						if p.action in ["gather","shot"]:
							for i in 2:
								var knee=v.bone_world(v.feet[i][1]).origin
								var ks=knee.distance_to(old_knees[i])/dt;var ps=v.palm_world[i].distance_to(old_palms[i])/dt
								max_knee_speed=maxf(max_knee_speed,ks);max_palm_speed=maxf(max_palm_speed,ps)
								check(ks<18 and ps<14,"Skill joint snapped "+style+" "+str(fps)+" knee="+str(ks)+" palm="+str(ps))
						for i in 2:old_knees[i]=v.bone_world(v.feet[i][1]).origin;old_palms[i]=v.palm_world[i]
						old_yaw=p.rotation.y
					check(released and game.attempts==1,"Skill failed to release exactly once "+mode+" "+style)
					if style=="hook":check(aerial_turn>.15,"Hook rotation stopped before jumping")
					cases+=1
	for code in [KEY_UP,KEY_DOWN,KEY_W,KEY_A,KEY_D]:key(code,false)
	print("SHOT_SKILLS cases=",cases," max_knee_speed=",max_knee_speed," max_palm_speed=",max_palm_speed," failures=",failures)
	game.queue_free();await process_frame;quit(1 if failures else 0)
