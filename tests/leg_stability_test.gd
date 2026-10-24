extends SceneTree
var failures=0
var samples=0
var min_bend=1.0
var max_knee_speed=0.0
var previous: Dictionary={}
func _init():call_deferred("run")
func check(ok: bool,message: String):
	if not ok:
		failures+=1
		if failures<12:push_error(message)
func inspect(actor,dt: float,tag: String):
	var v=actor.skinned
	for i in range(2):
		var chain=v.feet[i]
		var hip=v.bone_world(chain[0]).origin
		var knee=v.bone_world(chain[1]).origin
		var ankle=v.bone_world(chain[2]).origin
		var axis=(ankle-hip).normalized()
		var bend=knee-hip-axis*(knee-hip).dot(axis)
		var forward=actor.global_basis.z-axis*actor.global_basis.z.dot(axis)
		if bend.length()>.012 and forward.length()>.1:
			var alignment=bend.normalized().dot(forward.normalized())
			min_bend=minf(min_bend,alignment)
			check(alignment>-.1,"Backwards knee %s foot=%d bend=%.3f" % [tag,i,alignment])
		check(knee.is_finite() and ankle.is_finite(),"Invalid visible leg "+tag)
		var id=str(actor.get_instance_id())+str(i)
		if previous.has(id):
			var before: Array=previous[id]
			if actor.position.distance_to(before[1])<.4:
				var speed=knee.distance_to(before[0])/dt
				max_knee_speed=maxf(max_knee_speed,speed)
				check(speed<22,"Visible knee jumped %.2fm/s %s foot=%d" % [speed,tag,i])
		previous[id]=[knee,actor.position]
		samples+=1
func run():
	var actor=load("res://scripts/actor.gd").new()
	root.add_child(actor)
	actor.setup(false)
	for fps in [30,60,120]:
		for ball in [false,true]:
			actor.position=Vector3.ZERO
			actor.facing=0
			actor.rotation.y=0
			actor.has_ball=ball
			actor.motion=Vector2.ZERO
			actor.reset_stance()
			actor.feet_world.clear()
			actor.animate(1.0/fps,0)
			previous.clear()
			var dt=1.0/fps
			for stage in range(7):
				var yaw=[0.0,PI*.5,PI,-PI*.5,0.0,PI,PI][stage]
				for f in range(int(fps*1.2)):
					var velocity=Vector2(sin(yaw),cos(yaw))*(0.0 if stage==6 else 4.7)
					actor.steer_motion(velocity,24,dt)
					actor.facing=yaw
					actor.position+=actor.movement_step(dt)
					actor.animate(dt,stage*1.2+f*dt)
					inspect(actor,dt,"%dfps ball=%s stage=%d f=%d" % [fps,ball,stage,f])
	for fps in [30,60,120]:
		for kind in ["rebound","block"]:
			for side in [-1.0,1.0]:
				actor.position=Vector3.ZERO
				actor.facing=0;actor.rotation.y=0
				actor.motion=Vector2.ZERO
				actor.has_ball=false
				actor.reset_stance();actor.feet_world.clear()
				actor.animate(1.0/fps,0)
				actor.prepare_defense(kind,Vector3(side*.2,2.6,.32))
				previous.clear()
				var dt=1.0/fps
				for f in range(int(fps*actor.defense_duration())):
					actor.action_time=f*dt
					actor.jump=actor.defense_height()
					actor.position=actor.defense_position()
					actor.animate(dt,f*dt)
					inspect(actor,dt,"%dfps %s side=%s f=%d" % [fps,kind,side,f])
				actor.finish_defense()
				for f in range(fps):
					actor.steer_motion(Vector2(0,4.7),24,dt)
					actor.position+=actor.movement_step(dt)
					actor.animate(dt,f*dt)
					inspect(actor,dt,"%dfps %s landing-to-run f=%d" % [fps,kind,f])
	print("LEG_STABILITY samples=",samples," minimum_forward_bend=",min_bend," maximum_knee_speed=",max_knee_speed," failures=",failures)
	quit(1 if failures else 0)
