extends SceneTree
var failures=0
var contacts=0
var opposed=0
var wrong_phase=0
var worst_gap=0.0
var foot_lift: Array=[0.0,0.0]
func _init():call_deferred("run")
func check(ok: bool,message: String):
	if not ok:
		failures+=1
		if failures<12:push_error(message)
func run():
	var a=load("res://scripts/actor.gd").new()
	root.add_child(a);a.setup(false)
	var ball=CourtArt.basketball(a)
	var sphere=ball.get_child(0)
	var radius=sphere.mesh.radius*sphere.scale.y*ball.scale.y
	check(absf(a.DRIBBLE_FLOOR-radius-.003)<.001,"Dribble floor must match rendered sphere radius")
	check(absf(a.DRIBBLE_PALM-radius-.015)<.001,"Palm gap must match rendered sphere surface")
	for fps in [30,60,120]:
		for side in [-1.0,1.0]:
			a.position=Vector3.ZERO;a.rotation.y=0;a.facing=0
			a.motion=Vector2.ZERO;a.reset_stance();a.feet_world.clear()
			a.has_ball=true;a.dribble_hand=side;a.ball_side=side
			a.animate(1.0/fps,0)
			for f in int(fps*2.5):
				var dt=1.0/fps
				a.steer_motion(Vector2(0,4.7),24,dt)
				a.position+=a.movement_step(dt)
				a.animate(dt,f*dt)
				if f<fps*.5:continue
				var v=a.skinned
				for i in 2:foot_lift[i]=maxf(foot_lift[i],v.toe_world[i].y)
				var hip=v.bone_world(v.skeleton.find_bone("pelvis")).origin.y
				check(hip>.70 and hip<1.02,"Basketball stance must stay athletic rather than kneeling")
				check(v.torso_layer.x>.10,"Basketball drive lost its forward chest lean")
				var free=0 if side>0 else 1
				var foot=(v.bone_world(v.feet[free][2]).origin-v.bone_world(v.feet[1-free][2]).origin).dot(a.global_basis.z)
				var chest_frame=v.chest_motion_frame()
				var arm=(v.palm_world[free]-v.bone_world(v.arms[free][0]).origin).dot(chest_frame.z)-.17
				if absf(foot)>.20 and absf(arm)>.035:
					opposed+=1
					if arm*foot>0:wrong_phase+=1
				var phase=fposmod(a.dribble_phase,TAU)/TAU
				if phase<.18 or phase>.90:
					var gap=a.palm_position(1-free).distance_to(a.ball_anchor(0)+Vector3.UP*a.DRIBBLE_PALM)
					worst_gap=maxf(worst_gap,gap)
					check(gap<.03,"Visible pressing/cushioning palm missed ball surface")
					contacts+=1
			var old=a.run_swing_weight
			a.run_swing_weight=1.0
			var low=a.bounce_height(.42)
			check(absf(low-radius-.003)<.001,"Basketball bounced in empty air")
			check(a.bounce_height(.41)>low and a.bounce_height(.43)>low,"Floor contact did not reverse ball travel")
			check(a.bounce_height(.89)-a.bounce_height(.84)<a.bounce_height(.54)-a.bounce_height(.49),"Rebound did not decelerate before palm reception")
			check(absf(a.bounce_height(.99999)-a.bounce_height(0))<.001,"Bounce loop popped at hand reception")
			a.run_swing_weight=old
	check(opposed>100 and float(wrong_phase)/maxi(1,opposed)<.15,"Visible free arm did not counter-swing with visible feet")
	check(foot_lift[0]>.12 and foot_lift[1]>.12,"Running feet did not visibly leave the court during recovery")
	print("BASKETBALL_MOTION contacts=",contacts," free_arm_pairs=",opposed," wrong_phase=",wrong_phase," worst_palm_gap_m=",worst_gap," rendered_radius=",radius," recovery_toe_heights=",foot_lift," failures=",failures)
	quit(1 if failures else 0)
