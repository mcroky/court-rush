extends SceneTree
var failures=0
var held_samples=0
var releases=0
var follows=0
func _init():call_deferred("run")
func check(ok: bool,message: String):
	if not ok:
		failures+=1
		if failures<14:push_error(message)
func run():
	var a=load("res://scripts/actor.gd").new();root.add_child(a);a.setup(false)
	for fps in [30,60,120]:
		for side in [-1.0,1.0]:
			a.position=Vector3.ZERO;a.rotation.y=0;a.facing=0;a.motion=Vector2.ZERO
			a.reset_stance();a.feet_world.clear();a.has_ball=true;a.dribble_ended=true;a.dribble_hand=side;a.finish_kind="shot";a.action="idle";a.jump=0
			var dt=1.0/fps
			for f in fps:
				a.animate(dt,f*dt)
				if f<fps*.3:continue
				var v=a.skinned
				var hip=v.bone_world(v.skeleton.find_bone("pelvis")).origin.y
				check(hip>.80,"Held-ball standing pose collapsed into a crouch")
				var ball=a.ball_anchor(0)
				for i in 2:
					var chain=v.arms[i]
					var shoulder=v.bone_world(chain[0]).origin
					var elbow=v.bone_world(chain[1]).origin
					var wrist=v.bone_world(chain[2]).origin
					check((elbow-shoulder).normalized().dot((wrist-elbow).normalized())<.85,"Held-ball arms hung straight instead of supporting ball")
					check(absf(v.palm_world[i].distance_to(ball)-.125)<.03,"Held ball did not sit between actual palm surfaces")
					held_samples+=1
			a.action="gather";a.action_time=0
			for f in int(fps*.5):
				a.action_time=f*dt;a.animate(dt,1+f*dt)
			a.action="shot"
			var shooter=1 if side>0 else 0
			for f in int(fps*.87):
				a.action_time=f*dt;a.jump=a.shot_height(a.action_time)
				a.has_ball=a.action_time<.22
				a.animate(dt,1.5+f*dt)
				var v=a.skinned
				var chain=v.arms[shooter]
				var palm=v.palm_world[shooter]
				var frame=v.bone_world(chain[2]).basis.orthonormalized()*v.palm_frames[shooter]
				if a.action_time>=.18 and a.action_time<=.22:
					check(palm.y>v.bone_world(v.skeleton.find_bone("head")).origin.y+.15,"Shot palm did not rise above the face")
					check(v.bone_world(chain[1]).origin.y<palm.y-.08,"Shooting elbow was not below ball")
					check(frame.z.dot(Vector3.UP)>.70,"Shooting palm did not support underside of ball")
					releases+=1
				if a.action_time>=.36 and a.action_time<=.45:
					check(frame.y.dot(Vector3.DOWN)>.65,"Shot follow-through did not fold the wrist")
					check(palm.distance_to(v.palm_world[1-shooter])>.24,"Guide hand stayed attached through release")
					follows+=1
	check(releases>12 and follows>18,"Missing shot phase coverage")
	print("HELD_SHOT_POSE held_palm_samples=",held_samples," release_samples=",releases," wrist_follow_samples=",follows," failures=",failures)
	quit(1 if failures else 0)
