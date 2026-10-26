extends SceneTree
var failures=0
var cases=0
var samples=0
var max_guide_lean=0.0
var min_face_clearance=10.0
var max_elbow_speed=0.0
var max_palm_speed=0.0
func _init():call_deferred("run")
func check(ok: bool,message: String):
 if not ok:
  failures+=1
  if failures<16:push_error(message)
func inspect_pose(a,tag: String):
 var v=a.skinned
 var guide=0 if a.dribble_hand>0 else 1
 var elbow=a.to_local(v.bone_world(v.arms[guide][1]).origin)
 var palm=a.to_local(v.palm_world[guide])
 var head=a.to_local(v.bone_world(v.skeleton.find_bone("head")).origin)
 var lean=absf(elbow.x-palm.x)/a.height_ratio
 max_guide_lean=maxf(max_guide_lean,lean)
 check(lean<.045,"Guide forearm flared beside face "+tag+" lateral="+str(lean))
 check(elbow.y<palm.y-.06,"Guide elbow rose above supporting hand "+tag)
 var u=clampf((head.y-elbow.y)/maxf(.01,palm.y-elbow.y),0,1)
 var face_line=elbow.lerp(palm,u)
 var clearance=(face_line.z-head.z)/a.height_ratio
 min_face_clearance=minf(min_face_clearance,clearance)
 check(clearance>.14,"Forearm passed beside/behind head "+tag+" clearance="+str(clearance))
 check(absf(face_line.x-head.x)<.115*a.height_ratio,"Guide arm stayed outside face corridor "+tag)
 check(absf(v.palm_world[guide].distance_to(a.ball_anchor(0))-.125)<.03,"Guide hand lost ball contact "+tag)
 samples+=1
func run():
 var a=load("res://scripts/actor.gd").new();root.add_child(a);a.setup(false)
 for role in ["guard","forward","center"]:
  for fps in [30,60,120]:
   for hand in [-1.0,1.0]:
    for heading in [-.80,.28,.80]:
     for moving in [false,true]:
      a.apply_athlete({"role":role,"height":{"guard":178,"forward":190,"center":204}[role]})
      a.action="idle";a.has_ball=true;a.dribble_ended=false;a.dribble_hand=hand;a.finish_kind="shot";a.motion=Vector2.ZERO;a.position=Vector3.ZERO;a.rotation.y=heading;a.facing=heading;a.jump=0
      a.reset_stance();a.feet_world.clear()
      var dt=1.0/fps
      for f in int(fps*.4):a.animate(dt,f*dt)
      if moving:
       a.motion=Vector2(sin(heading),cos(heading))*4.7
       for f in int(fps*.45):a.position+=Vector3(a.motion.x,0,a.motion.y)*dt;a.animate(dt,1+f*dt)
      a.approach_velocity=a.motion;a.shot_gather_turn=moving;a.shot_gather_yaw=a.rotation.y;a.gather_step_start=a.step_serial
      a.facing=heading+(.7 if moving else 0.0);a.action="gather";a.dribble_ended=true
      var old_elbows=[];var old_palms=a.skinned.palm_world.duplicate()
      for chain in a.skinned.arms:old_elbows.append(a.skinned.bone_world(chain[1]).origin)
      for state in ["gather","shot"]:
       a.action=state
       for f in int(fps*((.25 if moving else .55) if state=="gather" else .87)):
        var t=f*dt;a.action_time=t;a.jump=a.shot_height(t) if state=="shot" else 0.0;a.has_ball=state=="gather" or t<.22
        a.motion=a.gather_velocity() if state=="gather" else Vector2.ZERO
        a.position+=Vector3(a.motion.x,0,a.motion.y)*dt;a.animate(dt,2+t)
        var tag="%s fps=%d hand=%.0f moving=%s %s t=%.3f" % [role,fps,hand,str(moving),state,t]
        if (state=="gather" and t>.20) or (state=="shot" and t<=.10):inspect_pose(a,tag)
        var v=a.skinned
        for i in 2:
         var chain=v.arms[i];var elbow=v.bone_world(chain[1]).origin
         var elbow_speed=elbow.distance_to(old_elbows[i])/dt;var palm_speed=v.palm_world[i].distance_to(old_palms[i])/dt
         max_elbow_speed=maxf(max_elbow_speed,elbow_speed);max_palm_speed=maxf(max_palm_speed,palm_speed)
         check(elbow_speed<18,"Elbow snapped "+tag+" speed="+str(elbow_speed))
         check(palm_speed<14,"Palm snapped "+tag+" speed="+str(palm_speed))
         for pair in [[chain[0],chain[1]],[chain[1],chain[2]]]:
          var length=v.skeleton.get_bone_rest(pair[1]).origin.length()*v.render_scale
          check(absf(v.bone_world(pair[0]).origin.distance_to(v.bone_world(pair[1]).origin)-length)<.0004,"Arm stretched "+tag)
         old_elbows[i]=elbow;old_palms[i]=v.palm_world[i]
      cases+=1
 print("SHOT_ARM_LINE cases=",cases," front_face_samples=",samples," max_guide_lean=",max_guide_lean," min_face_clearance=",min_face_clearance," max_elbow_speed=",max_elbow_speed," max_palm_speed=",max_palm_speed," failures=",failures)
 a.queue_free();await process_frame;quit(1 if failures else 0)
