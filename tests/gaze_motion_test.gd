extends SceneTree
var failures=0
var samples=0
var looking_up=0
var secured=0
func _init():call_deferred("run")
func check(ok: bool,message: String):
	if not ok:
		failures+=1
		if failures<10:push_error(message)
func forward(a) -> Vector3:
	var v=a.skinned
	return (v.bone_world(v.skeleton.find_bone("head")).basis*v.head_forward_local).normalized()
func run():
	var a=load("res://scripts/actor.gd").new();root.add_child(a);a.setup(false)
	for fps in [30,60,120]:
		var dt=1.0/fps
		a.position=Vector3.ZERO;a.facing=0;a.rotation.y=0;a.action="idle";a.jump=0
		a.reset_stance();a.feet_world.clear();a.has_ball=true;a.dribble_ended=false
		for f in int(fps*1.5):
			a.facing=0 if f<fps*.6 else .9
			a.steer_motion(Vector2(sin(a.facing),cos(a.facing))*4.2,24,dt)
			a.position+=a.movement_step(dt);a.animate(dt,f*dt)
			if f>fps*.3:
				var face=forward(a)
				check(face.is_finite() and absf(face.y)<.18,"Running head lost its level gaze")
				var horizontal=Vector3(face.x,0,face.z).normalized()
				check(horizontal.dot(a.global_basis.z)>.85,"Head turned away from travel instead of leading the cut")
				samples+=1
		a.position=Vector3.ZERO;a.facing=0;a.rotation.y=0;a.motion=Vector2.ZERO;a.jump=0;a.has_ball=false
		a.reset_stance();a.feet_world.clear();a.animate(dt,2)
		a.prepare_defense("rebound",Vector3(0,3.1,.3))
		for f in int(fps*.98):
			a.action_time=(f+1)*dt;a.jump=a.defense_height()
			if a.action_time>.36 and not a.defense_caught:
				a.capture_rebound(a.rebound_anchor(),Vector3.DOWN*2);a.has_ball=true
			a.animate(dt,2+(f+1)*dt)
			var face=forward(a)
			check(face.is_finite() and absf(face.y)<.45,"Rebound gaze over-rotated neck/head")
			if a.action_time>.20 and a.action_time<.34:
				check(face.y>.12,"Rebound head did not look toward falling ball fps=%d t=%.3f forward=%s gaze=%s" % [fps,a.action_time,face,a.skinned.gaze_target]);looking_up+=1
			if a.action_time>.84:
				check(face.y<.05,"Secured rebound kept staring upward after the chest tuck");secured+=1
	check(looking_up>20 and secured>20,"Missing gaze state coverage")
	print("GAZE_MOTION running_samples=",samples," air_watch_samples=",looking_up," secured_samples=",secured," failures=",failures)
	quit(1 if failures else 0)
