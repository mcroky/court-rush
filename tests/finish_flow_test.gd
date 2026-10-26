extends SceneTree
var failures=0
var cases=0
var plants=0
var landing_samples=0
var worst_slide=0.0
var max_palm_speed=0.0
var max_knee_speed=0.0
var max_gather_ball_speed=0.0

func _init():call_deferred("run")
func key(code: Key, down: bool):
	var e=InputEventKey.new();e.keycode=code;e.physical_keycode=code;e.pressed=down
	Input.parse_input_event(e);Input.flush_buffered_events()
func check(ok: bool, message: String):
	if not ok:
		failures+=1
		if failures<80:push_error(message)

func run():
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game);game.set_physics_process(false);game.sound_enabled=false
	for fps in [30,60,120]:
		for hand in [-1.0,1.0]:
			for finish_case in ["shot","quick_shot","layup"]:
				var finish="layup" if finish_case=="layup" else "shot"
				key(KEY_UP,false);key(KEY_D,false)
				game.start_mode("practice")
				var p=game.players[0]
				var v=p.skinned
				var pelvis=v.skeleton.find_bone("pelvis")
				var dt=1.0/fps
				p.position=Vector3(hand*.55,0,1.5 if finish=="shot" else -1.9)
				p.dribble_hand=hand;p.feet_world.clear();p.reset_stance()
				game._physics_process(dt)
				key(KEY_UP,true)
				for f in int(fps*.30):game._physics_process(dt)
				var approach_speed=p.motion.length()
				var gather_origin=p.position
				var old_palms=v.palm_world.duplicate()
				var old_toes=v.toe_world.duplicate()
				var old_locks=v.locked.duplicate()
				var old_ball=game.ball.position
				var old_knees=[]
				for i in 2:old_knees.append(v.bone_world(v.feet[i][1]).origin)
				var landed_height=0.0
				var min_landing_height=10.0
				var max_recover_height=-10.0
				var touchdown=false
				var released=false
				var decelerated=false
				key(KEY_D,true)
				for f in int(fps*1.75):
					game._physics_process(dt)
					# Keep a missed shot live so the score presentation cannot freeze
					# this fixture just as the shooter touches down.
					game.flight_made=false
					if finish_case=="quick_shot" and p.action=="gather" and p.action_time>=.24:key(KEY_D,false)
					if p.action=="gather" and p.action_time>.12 and finish=="shot":
						check(p.motion.length()<approach_speed*.45,"Running shot did not brake into the plant")
						decelerated=true
					if p.action=="gather":check(p.step_serial-p.gather_step_start<=2,"Gather scheduled an illegal third step")
					if p.action=="gather" or game.phase=="takeoff":
						var ball_speed=game.ball.position.distance_to(old_ball)/dt
						max_gather_ball_speed=maxf(max_gather_ball_speed,ball_speed)
						check(ball_speed<14,"Ball popped while gathering/lifting fps=%d case=%s action=%s kind=%s t=%.3f speed=%.3f ball=%s palm0=%s palm1=%s prev=%s" % [fps,finish_case,p.action,p.finish_kind,p.action_time,ball_speed,str(game.ball.position),str(v.palm_world[0]),str(v.palm_world[1]),str(old_ball)])
					old_ball=game.ball.position
					if game.phase=="flight":released=true
					var active=p.action==finish
					var times=v.finish_times(p)
					var pelvis_height=v.bone_world(pelvis).origin.y
					if active and p.action_time>=times.y and not touchdown:
						touchdown=true;landed_height=pelvis_height
					if active and p.action_time>=times.y and p.action_time<=times.y+.10:
						min_landing_height=minf(min_landing_height,pelvis_height);landing_samples+=1
					if active and p.action_time>=times.y+.11:
						max_recover_height=maxf(max_recover_height,pelvis_height)
					for i in 2:
						var palm_speed=v.palm_world[i].distance_to(old_palms[i])/dt
						max_palm_speed=maxf(max_palm_speed,palm_speed)
						check(palm_speed<14,"Actual finish palm jumped fps=%d kind=%s t=%.3f hand=%d speed=%.3f" % [fps,finish,p.action_time,i,palm_speed])
						var chain=v.feet[i]
						var hip=v.bone_world(chain[0]).origin
						var knee=v.bone_world(chain[1]).origin
						var ankle=v.bone_world(chain[2]).origin
						var upper=v.skeleton.get_bone_rest(chain[1]).origin.length()*v.SCALE
						var lower=v.skeleton.get_bone_rest(chain[2]).origin.length()*v.SCALE
						check(absf(hip.distance_to(knee)-upper)<.0003 and absf(knee.distance_to(ankle)-lower)<.0003,"Actual finish leg stretched")
						var axis=(ankle-hip).normalized()
						var bend=knee-hip-axis*(knee-hip).dot(axis)
						var forward=p.global_basis.z-axis*p.global_basis.z.dot(axis)
						if bend.length()>.012 and forward.length()>.1:check(bend.normalized().dot(forward.normalized())>-.1,"Actual finish knee bent backwards")
						var knee_speed=knee.distance_to(old_knees[i])/dt
						max_knee_speed=maxf(max_knee_speed,knee_speed)
						check(knee_speed<18,"Actual finish knee snapped fps=%d kind=%s t=%.3f foot=%d speed=%.3f" % [fps,finish,p.action_time,i,knee_speed])
						var plant=active and p.action_time<=times.x and (finish=="shot" or i==p.layup_plant_index)
						if active and old_locks[i] and v.locked[i] and (plant or p.action_time>times.y+dt):
							var slide=v.toe_world[i].distance_to(old_toes[i])
							worst_slide=maxf(worst_slide,slide);plants+=1
							check(slide<.012,"Actual finish support slid fps=%d kind=%s t=%.3f foot=%d slide=%.3f" % [fps,finish,p.action_time,i,slide])
						old_palms[i]=v.palm_world[i];old_toes[i]=v.toe_world[i];old_locks[i]=v.locked[i];old_knees[i]=knee
				check(released and game.attempts==1,"Finish did not release exactly once")
				check(touchdown and min_landing_height<landed_height-.02,"No knee absorption after actual foot contact fps=%d kind=%s land=%.3f low=%.3f" % [fps,finish,landed_height,min_landing_height])
				check(max_recover_height>min_landing_height+.02,"Finish did not recover from landing load fps=%d case=%s hand=%.0f low=%.4f recover=%.4f" % [fps,finish_case,hand,min_landing_height,max_recover_height])
				if finish=="shot":
					check(decelerated and p.position.distance_to(gather_origin)>.12,"Running shot gather lost incoming travel")
				cases+=1
	key(KEY_UP,false);key(KEY_D,false)
	print("FINISH_FLOW cases=",cases," visible_plants=",plants," landing_samples=",landing_samples," worst_slide=",worst_slide," max_palm_speed=",max_palm_speed," max_knee_speed=",max_knee_speed," max_gather_ball_speed=",max_gather_ball_speed," failures=",failures)
	game.queue_free();await process_frame
	quit(1 if failures else 0)
