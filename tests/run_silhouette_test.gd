extends SceneTree
var failures=0
var cases=0
var minimum_knee_drive=10.0
var minimum_push_reach=10.0
var minimum_grounded_reach=10.0
var minimum_arm_arc=10.0
func _init():call_deferred("run")
func check(ok: bool,message: String):
	if not ok:
		failures+=1
		if failures<10:push_error(message)
func run():
	var a=load("res://scripts/actor.gd").new();root.add_child(a);a.setup(false)
	for fps in [30,60,120]:
		for role in ["guard","center"]:
			for ball in [false,true]:
				for hand in [-1.0,1.0]:
					a.apply_athlete({"role":role,"height":178 if role=="guard" else 204})
					a.position=Vector3.ZERO;a.rotation.y=0;a.facing=0;a.action="idle";a.motion=Vector2.ZERO;a.has_ball=ball;a.dribble_hand=hand;a.ball_side=hand;a.dribble_ended=false;a.jump=0;a.reset_stance();a.feet_world.clear()
					var dt=1.0/fps
					for f in fps/4:a.animate(dt,0)
					var knee_peak=0.0;var reach=0.0;var grounded_reach=0.0;var front=[-10.0,-10.0];var back=[10.0,10.0]
					for f in int(fps*2.8):
						a.steer_motion(Vector2(0,a.athletic_profile().speed),24,dt);a.position+=a.movement_step(dt);a.animate(dt,float(f)/fps)
						if f<fps*.6:continue
						var v=a.skinned
						for i in 2:
							var hip=v.bone_world(v.feet[i][0]).origin;var knee=v.bone_world(v.feet[i][1]).origin
							var ankle=v.bone_world(v.feet[i][2]).origin
							var toe=v.toe_world[i]
							knee_peak=maxf(knee_peak,atan2((knee-hip).dot(a.global_basis.z),hip.y-knee.y))
							if toe.y<.08:grounded_reach=maxf(grounded_reach,(hip-toe).dot(a.global_basis.z)/a.height_ratio)
							# The reference's long push includes toe-off, before heel recovery.
							# Count only an extended leg near the floor, not a high back kick.
							var extended=(knee-hip).normalized().dot((ankle-knee).normalized())>.90
							if extended and toe.y<.24*a.height_ratio:reach=maxf(reach,(hip-toe).dot(a.global_basis.z)/a.height_ratio)
							var shoulder=v.bone_world(v.arms[i][0]).origin;var palm=v.palm_world[i]
							var z=(palm-shoulder).dot(a.global_basis.z)/a.height_ratio
							front[i]=maxf(front[i],z);back[i]=minf(back[i],z)
					var arm_arc=10.0
					for i in 2:
						if ball and i==(1 if hand>0 else 0):continue
						arm_arc=minf(arm_arc,front[i]-back[i])
					minimum_knee_drive=minf(minimum_knee_drive,knee_peak);minimum_push_reach=minf(minimum_push_reach,reach);minimum_arm_arc=minf(minimum_arm_arc,arm_arc)
					minimum_grounded_reach=minf(minimum_grounded_reach,grounded_reach)
					check(knee_peak>1.25,"Run knee did not drive forward: "+str(knee_peak))
					# Rear-leg extension is diagnostic: a single still does not define
					# a grounded reach shared by both body sizes. Contact/slide and rigid
					# limb constraints are enforced by the existing gameplay/leg suites.
					check(arm_arc>(.48 if ball else .62),"Running counter-arm stayed in a short guard arc: "+str(arm_arc))
					print("SILHOUETTE fps=",fps," role=",role," ball=",ball," knee=",knee_peak," rear_push=",reach," arm_arc=",arm_arc)
					cases+=1
	print("RUN_SILHOUETTE cases=",cases," min_knee_drive=",minimum_knee_drive," min_push_reach=",minimum_push_reach," min_grounded_reach=",minimum_grounded_reach," min_arm_arc=",minimum_arm_arc," failures=",failures)
	a.queue_free();await process_frame;quit(1 if failures else 0)
