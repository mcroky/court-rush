extends SceneTree
var failures=0
var cases=0
var repeated=0
var minimum_clearance=10.0
var minimum_stride_arc=10.0
func _init():call_deferred("run")
func check(ok: bool,message: String):
	if not ok:
		failures+=1
		if failures<14:push_error(message)
func run():
	var actor=load("res://scripts/actor.gd").new();root.add_child(actor);actor.setup(false)
	for fps in [30,60,120]:
		for ball in [false,true]:
			for role in ["guard","center"]:
				for heading in [-PI*.25,0.0,PI*.25]:
					actor.apply_athlete({"role":role,"height":178 if role=="guard" else 204})
					actor.position=Vector3.ZERO;actor.action="idle";actor.motion=Vector2.ZERO;actor.rotation.y=heading;actor.facing=heading;actor.jump=0;actor.has_ball=ball;actor.dribble_ended=false;actor.reset_stance();actor.feet_world.clear()
					var dt=1.0/fps
					for f in int(fps*.25):actor.animate(dt,0)
					var raised=[false,false];var previous=-1;var events=[];var old=actor.skinned.toe_world.duplicate()
					var peaks=[0.0,0.0];var front=[-10.0,-10.0];var back=[10.0,10.0]
					for f in int(fps*2.4):
						actor.steer_motion(Vector2(sin(heading),cos(heading))*actor.athletic_profile().speed,24,dt);actor.position+=actor.movement_step(dt);actor.animate(dt,float(f)/fps)
						for i in 2:
							var toe=actor.skinned.toe_world[i]
							var local_toe=actor.to_local(toe)
							peaks[i]=maxf(peaks[i],local_toe.y)
							front[i]=maxf(front[i],local_toe.z);back[i]=minf(back[i],local_toe.z)
							if toe.y>.075:raised[i]=true
							if raised[i] and toe.y<.045 and old[i].y>=.045:
								if previous==i:repeated+=1
								check(previous!=i,"Rendered runner landed the same foot twice: fps="+str(fps)+" ball="+str(ball)+" t="+str(float(f)/fps)+" source_phase="+str(actor.skinned.phase)+" physics_step="+str(actor.last_step))
								events.append([snappedf(float(f)/fps,.001),i]);previous=i;raised[i]=false
							old[i]=toe
					check(events.size()>=6,"Runner did not produce enough visible strides")
					for i in 2:
						minimum_clearance=minf(minimum_clearance,peaks[i]);minimum_stride_arc=minf(minimum_stride_arc,front[i]-back[i])
						check(peaks[i]>.22,"Runner never recovered the heel above a short shuffle")
						check(front[i]-back[i]>.65,"Runner did not reach forward and trail behind")
					print("RUN_CONTACT ",fps," ball=",ball," role=",role," heading=",snappedf(heading,.01)," landings=",events)
					cases+=1
	print("RUN_CONTACT_RHYTHM cases=",cases," repeated_feet=",repeated," min_heel_height=",minimum_clearance," min_stride_arc=",minimum_stride_arc," failures=",failures)
	actor.queue_free();await process_frame;quit(1 if failures else 0)
