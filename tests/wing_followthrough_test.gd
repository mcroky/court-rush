extends SceneTree
var failures=0
var cases=0
var max_palm_speed=0.0
var max_elbow_speed=0.0
func _init():call_deferred("run")
func check(ok: bool,message: String):
	if not ok:
		failures+=1
		if failures<16:push_error(message)
func key(down: bool):
	var e=InputEventKey.new();e.keycode=KEY_D;e.physical_keycode=KEY_D;e.pressed=down;Input.parse_input_event(e);Input.flush_buffered_events()
func run():
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_physics_process(false);game.sound_enabled=false
	for fps in [30,60,120]:
		for role in ["guard","forward","center"]:
			for side in [-1.0,1.0]:
				for hand in [-1.0,1.0]:
					key(false);game.start_mode("practice");var p=game.players[0];var v=p.skinned;var dt=1.0/fps
					p.apply_athlete({"role":role,"height":{"guard":178,"forward":190,"center":204}[role]})
					p.position=Vector3(side*5.1,0,game.HOOP.z+5.1);p.rotation.y=atan2(-p.position.x,-5.1);p.facing=p.rotation.y;p.reset_stance();p.dribble_hand=hand;p.feet_world.clear()
					for f in int(fps*.25):game._physics_process(dt)
					key(true);game.begin_gather(0)
					for f in int(fps*.4):game._physics_process(dt)
					game.launch_shot(0);key(false)
					var shooter=1 if hand>0 else 0;var guide=1-shooter
					var old_palms=v.palm_world.duplicate();var old_elbows=[]
					for chain in v.arms:old_elbows.append(v.bone_world(chain[1]).origin)
					var peeled=false;var folded=false
					for f in int(fps*.87):
						game._physics_process(dt)
						var t=p.shot_arm_time();var head=v.bone_world(v.skeleton.find_bone("head")).origin
						var tag="fps="+str(fps)+" side="+str(side)+" hand="+str(hand)+" t="+str(t)
						if t>=.36 and t<=.44:
							check(v.palm_world[guide].y<head.y-.10,"Guide hand stayed raised like a second shooting hand "+tag)
							check(v.palm_world[shooter].y>head.y+.12,"Shooting arm collapsed before follow-through "+tag)
							peeled=true
						if t>=.34 and t<=.44:
							check(p.palm_frame(shooter).y.dot(Vector3.DOWN)>.65,"Shooting wrist lost its follow-through "+tag);folded=true
						for i in 2:
							var elbow=v.bone_world(v.arms[i][1]).origin
							var ps=v.palm_world[i].distance_to(old_palms[i])/dt;var es=elbow.distance_to(old_elbows[i])/dt
							max_palm_speed=maxf(max_palm_speed,ps);max_elbow_speed=maxf(max_elbow_speed,es)
							check(ps<14 and es<18,"Follow-through snapped "+tag)
							old_palms[i]=v.palm_world[i];old_elbows[i]=elbow
					check(peeled and folded and game.attempts==1,"Wing follow-through coverage missing")
					cases+=1
	print("WING_FOLLOWTHROUGH cases=",cases," max_palm_speed=",max_palm_speed," max_elbow_speed=",max_elbow_speed," failures=",failures)
	game.queue_free();await process_frame;quit(1 if failures else 0)
