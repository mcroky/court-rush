extends SceneTree
var failures=0
var cases=0
var worst_response=0.0
var worst_stall=0.0
func _init():call_deferred("run")
func check(ok: bool,message: String):
	if not ok:
		failures+=1
		if failures<10:push_error(message)
func run():
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.sound_enabled=false
	for fps in [30,60,120]:
		for ball in [false,true]:
			for entry in [.33,.44,.55]:
				for angle in [-PI*.5,PI*.25,PI*.5,PI]:
					game.start_mode("practice")
					var p=game.players[0]
					p.position=Vector3.ZERO
					p.rotation.y=0
					p.facing=0
					p.has_ball=ball
					p.reset_stance()
					p.feet_world.clear()
					var dt=1.0/fps
					p.animate(dt,0)
					for f in int(fps*entry):
						p.steer_motion(Vector2(0,4.7),24,dt)
						p.position+=p.movement_step(dt)
						p.animate(dt,f*dt)
					var desired=Vector2(sin(angle),cos(angle))*4.7
					var dir=Vector3(desired.x,0,desired.y).normalized()
					var response=-1.0
					var stall=0.0
					var longest=0.0
					var start=p.position
					for f in int(fps*.65):
						p.steer_motion(desired,24,dt)
						var before=p.position
						p.position+=p.movement_step(dt)
						p.facing=angle
						p.animate(dt,entry+f*dt)
						var actual=(p.position-before)/dt
						if actual.dot(dir)>1 and response<0:response=(f+1)*dt
						stall=stall+dt if actual.length()<.15 else 0.0
						longest=maxf(longest,stall)
						check(not(p.swinging[0] and p.swinging[1]),"Quick cut released both supports")
					worst_response=maxf(worst_response,response)
					worst_stall=maxf(worst_stall,longest)
					print("CUT_RESPONSE fps=",fps," ball=",ball," entry=",entry," angle=",angle," response=",response," stall=",longest," advance=",(p.position-start).dot(dir))
					check(response>0 and response<=.20,"Input took over200ms to move into requested direction")
					check(longest<=.067,"Input cut produced a visible stationary pause")
					check((p.position-start).dot(dir)>1.35,"Quick cut did not carry momentum into requested direction")
					cases+=1
	print("CUT_RESPONSE_TOTAL cases=",cases," worst_response_s=",worst_response," worst_stall_s=",worst_stall," failures=",failures)
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
