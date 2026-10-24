extends SceneTree

var failures=0
var cases=0
var receiving=0
var max_shoulder_rate=0.0
var min_turn=100.0
func _init():call_deferred("run")
func check(ok: bool,message: String):
	if not ok:
		failures+=1
		if failures<12:push_error(message)
func shoulder_yaw(a) -> float:
	var v=a.skinned
	var line=a.global_basis.inverse()*(v.bone_world(v.arms[1][0]).origin-v.bone_world(v.arms[0][0]).origin)
	return atan2(-line.z,line.x)
func run():
	var a=load("res://scripts/actor.gd").new();root.add_child(a);a.setup(false)
	for fps in [30,60,120]:
		for hand in [-1.0,1.0]:
			for exit_yaw in [0.0,PI*.5,-PI*.5]:
				var dt=1.0/fps
				a.position=Vector3.ZERO;a.rotation.y=0;a.facing=0
				a.reset_stance();a.feet_world.clear();a.action="idle";a.action_time=0
				a.has_ball=true;a.dribble_ended=false;a.dribble_hand=hand;a.ball_side=hand
				for f in int(fps*.6):
					a.motion=Vector2(0,4.2);a.position+=a.movement_step(dt);a.animate(dt,f*dt)
				a.dribble_phase=TAU*.96;a.animate(.001,.6)
				a.prepare_cross(a.ball_anchor(0))
				var bait=0.0;var bait_count=0;var receive=0.0;var receive_count=0
				var last=shoulder_yaw(a)
				var received=false
				for f in int(fps*1.0):
					if a.crossing():
						a.action_time+=dt
						if a.action_time>=a.cross_duration() and a.cross_received:a.finish_cross()
					if a.crossing() and a.cross_phase()>.65 or received:a.facing=exit_yaw
					var desired=Vector2(sin(a.facing),cos(a.facing))*4.2
					a.steer_motion(desired,24,dt);a.position+=a.movement_step(dt);a.animate(dt,.6+(f+1)*dt)
					var yaw=shoulder_yaw(a)
					max_shoulder_rate=maxf(max_shoulder_rate,absf(angle_difference(last,yaw))/dt)
					check(absf(angle_difference(last,yaw))<12*dt,"Visible shoulder line snapped during receive/drive")
					last=yaw
					if a.crossing():
						var t=a.cross_phase()
						if t>=.14 and t<=.35:bait+=yaw;bait_count+=1
						if t>=.77 and t<=.96:receive+=yaw;receive_count+=1
						if a.cross_received:
							received=true;receiving+=1
							check(a.palm_position(1 if a.cross_to>0 else 0).distance_to(a.cross_ball_world()+Vector3.UP*a.DRIBBLE_PALM)<.045,"Receive separated hand from ball while torso rotated")
					for i in 2:
						var chain=a.skinned.arms[i]
						var shoulder=a.skinned.bone_world(chain[0]).origin
						var elbow=a.skinned.bone_world(chain[1]).origin
						var contact=a.cross_contact_weight(-1.0 if i==0 else 1.0) if a.crossing() else (1.0 if (i==1)==(a.dribble_hand>0) else 0.0)
						var ceiling=shoulder.y+(.03 if contact>.5 else -.08)
						check(elbow.y<ceiling,"Cross elbow lifted fps=%d from=%.0f exit=%.2f hand=%d frame=%d t=%.3f action=%s delta=%.3f" % [fps,hand,exit_yaw,i,f,a.cross_phase(),a.action,elbow.y-shoulder.y])
				check(received and not a.crossing(),"Cross never received and returned to running")
				check(bait_count>0 and receive_count>0,"Missing shoulder phase coverage")
				var turn=angle_difference(bait/maxi(1,bait_count),receive/maxi(1,receive_count))*hand
				min_turn=minf(min_turn,turn)
				check(turn>.12,"Shoulders did not turn with the receiving side fps=%d hand=%.0f exit=%.2f turn=%.3f" % [fps,hand,exit_yaw,turn])
				cases+=1
	print("CROSS_BODY_FLOW cases=",cases," receiving_samples=",receiving," min_receiving_turn=",min_turn," max_shoulder_rate=",max_shoulder_rate," failures=",failures)
	quit(1 if failures else 0)
