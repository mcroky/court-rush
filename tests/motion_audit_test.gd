extends SceneTree
## Measure the rendered rig, including the defensive actions that older tests
## inspected only on the hidden prototype. No accounts, rewards or network calls.
var failures=0
var samples=0
var report={}
func _init():call_deferred("run")
func run():
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game);game.set_physics_process(false);game.sound_enabled=false
	for kind in ["run","cut","stop","cross","block","rebound"]:
		var stats={"palm_speed":0.0,"knee_speed":0.0,"toe_min":10.0,"cpu_us":[],"torso_step":0.0}
		for fps in [30,60,120]:
			game.start_mode("practice")
			var p=game.players[0];var v=p.skinned;var dt=1.0/fps
			p.position=Vector3.ZERO;p.rotation.y=0;p.facing=0;p.reset_stance();p.feet_world.clear()
			p.has_ball=kind not in ["block","rebound"]
			p.animate(dt,0)
			for f in int(fps*.6):
				p.steer_motion(Vector2(0,4.7),24,dt);p.position+=p.movement_step(dt);p.animate(dt,f*dt)
			if kind in ["block","rebound"]:p.prepare_defense(kind,p.position+Vector3(.16,2.6,.25))
			if kind=="cross":p.prepare_cross(p.ball_anchor(0));p.action="cross";p.action_time=0
			var old_palms=v.palm_world.duplicate();var old_knees=[]
			for chain in v.feet:old_knees.append(v.bone_world(chain[1]).origin)
			var chest=v.skeleton.find_bone("spine_02")
			var old_chest=v.bone_world(chest).basis.orthonormalized().get_rotation_quaternion()
			for f in int(fps*1.6):
				var at=f*dt
				if p.defensive_jump():
					p.action_time+=dt;p.jump=p.defense_height();p.position=p.defense_position()
					if p.action_time>=.30:
						if kind=="rebound" and not p.defense_caught:p.has_ball=true;p.capture_rebound(p.rebound_anchor(),Vector3(0,-3,0))
						if kind=="block" and not p.block_contact:p.record_block_contact()
					if p.action_time>=p.defense_duration():p.finish_defense()
				else:
					var direction=Vector2(1,0) if kind=="cut" else Vector2(0,1)
					p.facing=atan2(direction.x,direction.y)
					p.steer_motion(direction*(0 if kind=="stop" else 4.7),24,dt)
					p.position+=p.movement_step(dt)
					if p.crossing():
						p.action_time+=dt
						if p.action_time>=p.cross_duration() and p.cross_received:p.finish_cross()
				var before=Time.get_ticks_usec();p.animate(dt,at)
				if fps==60:stats.cpu_us.append(Time.get_ticks_usec()-before)
				var current_chest=v.bone_world(chest).basis.orthonormalized().get_rotation_quaternion()
				stats.torso_step=maxf(stats.torso_step,old_chest.angle_to(current_chest)/dt);old_chest=current_chest
				for i in 2:
					var knee=v.bone_world(v.feet[i][1]).origin
					if knee.distance_to(old_knees[i])/dt>stats.knee_speed:stats["knee_at"]="%dfps %.3f %s %.3f %s" % [fps,at,p.action,p.action_time,p.brake_state]
					if v.palm_world[i].distance_to(old_palms[i])/dt>stats.palm_speed:stats["palm_at"]="%dfps %.3f %s %.3f" % [fps,at,p.action,p.action_time]
					stats.palm_speed=maxf(stats.palm_speed,v.palm_world[i].distance_to(old_palms[i])/dt)
					stats.knee_speed=maxf(stats.knee_speed,knee.distance_to(old_knees[i])/dt)
					stats.toe_min=minf(stats.toe_min,v.toe_world[i].y)
					old_palms[i]=v.palm_world[i];old_knees[i]=knee
					if not knee.is_finite() or v.toe_world[i].y<-.015:failures+=1
					samples+=1
		# Bounds catch the old single-frame snaps without slowing the strike itself.
		if stats.knee_speed>17 or stats.palm_speed>(24 if kind=="block" else 15):
			failures+=1;push_error("Rendered transition snapped: "+kind+" "+JSON.stringify(stats))
		stats.cpu_us.sort()
		stats["cpu_p50_us"]=stats.cpu_us[stats.cpu_us.size()/2]
		stats["cpu_p95_us"]=stats.cpu_us[int(stats.cpu_us.size()*.95)]
		stats.erase("cpu_us");report[kind]=stats
	print("MOTION_AUDIT ",JSON.stringify(report)," samples=",samples," failures=",failures)
	game.queue_free();await process_frame;quit(1 if failures else 0)
