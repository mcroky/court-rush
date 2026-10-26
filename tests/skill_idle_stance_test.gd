extends SceneTree
var failures=0
var cases=0
var min_width=10.0
var max_knee_speed=0.0
func _init():call_deferred("run")
func key(code: Key,down: bool):
	var e=InputEventKey.new();e.keycode=code;e.physical_keycode=code;e.pressed=down;Input.parse_input_event(e);Input.flush_buffered_events()
func run():
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_physics_process(false);game.sound_enabled=false
	for fps in [30,60,120]:
		for code in [KEY_A,KEY_Z,KEY_C,KEY_V,KEY_X]:
			for dir in [KEY_UP,KEY_LEFT,KEY_RIGHT]:
				game.start_mode("practice");var p=game.players[0];var dt=1.0/fps
				for f in fps/4:game._physics_process(dt)
				key(dir,true)
				for f in int(fps*.45):game._physics_process(dt)
				key(code,true);game._physics_process(dt);key(code,false);key(dir,false)
				var old_knees=[]
				for chain in p.skinned.feet:old_knees.append(p.skinned.bone_world(chain[1]).origin)
				for f in fps*3:
					game._physics_process(dt)
					for i in 2:
						var knee=p.skinned.bone_world(p.skinned.feet[i][1]).origin
						var speed=knee.distance_to(old_knees[i])/dt;max_knee_speed=maxf(max_knee_speed,speed);old_knees[i]=knee
						if speed>22:
							failures+=1
							if failures<9:push_error("Skill recovery knee snapped: "+str(speed))
					if f>fps and p.skinned.toe_world[0].y>.06 and p.skinned.toe_world[1].y>.06:
						failures+=1
						if failures<9:push_error("Standing recovery lifted both support feet")
				var a=p.to_local(p.skinned.toe_world[0]);var b=p.to_local(p.skinned.toe_world[1]);var width=b.x-a.x;min_width=minf(min_width,width)
				if width<.27 or a.x>-.10 or b.x<.10 or absf(a.z)>.34 or absf(b.z)>.34:
					failures+=1
					if failures<9:push_error("Skill did not return to standing fps=%d key=%d dir=%d toes=%s/%s"%[fps,code,dir,a,b])
				cases+=1
	print("SKILL_IDLE_STANCE cases=",cases," min_width=",min_width," max_knee_speed=",max_knee_speed," failures=",failures)
	game.queue_free();quit(1 if failures else 0)
