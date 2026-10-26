extends SceneTree
var failures=0
var cases=0
var max_palm_speed=0.0
var max_knee_speed=0.0
var max_exit_toe_jump=0.0
var min_release_alignment=1.0
func _init():call_deferred("run")
func check(ok: bool,message: String):
 if not ok:
  failures+=1
  if failures<16:push_error(message)
func key(code: Key,down: bool):
 var event=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=down;Input.parse_input_event(event);Input.flush_buffered_events()
func run():
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_physics_process(false);game.sound_enabled=false
 for fps in [30,60,120]:
  var dt=1.0/fps
  for hand in [-1.0,1.0]:
   for approach in [KEY_UP,KEY_DOWN,KEY_LEFT,KEY_RIGHT]:
    for run_after in [false,true]:
     for code in [KEY_UP,KEY_DOWN,KEY_LEFT,KEY_RIGHT,KEY_D]:key(code,false)
     game.start_mode("practice");var p=game.players[0];var v=p.skinned
     p.position=Vector3(0,0,3.5);p.dribble_hand=hand;p.feet_world.clear();p.reset_stance()
     for f in int(fps*.2):game._physics_process(dt)
     key(approach,true)
     for f in int(fps*.4):game._physics_process(dt)
     key(KEY_D,true);game._physics_process(dt);key(approach,false)
     var old_palms=v.palm_world.duplicate();var old_toes=v.toe_world.duplicate();var old_knees=[]
     for chain in v.feet:old_knees.append(v.bone_world(chain[1]).origin)
     var released=false;var folded=false;var lowered=false;var exited=false;var exit_origin=Vector3.ZERO;var was_shot=false;var tag=""
     # Turn away from the rim now requires a grounded plant/turn before gather.
     for f in int(fps*3.20):
      if p.action=="gather" and p.action_time>=.40:key(KEY_D,false)
      if run_after and p.action=="shot" and p.action_time>=.55:key(KEY_RIGHT,true)
      game._physics_process(dt);game.flight_made=false
      tag="fps=%d hand=%.0f approach=%d run=%s action=%s t=%.3f" % [fps,hand,approach,str(run_after),p.action,p.action_time]
      if game.phase=="flight" and not released:
       released=true
       var forward=v.chest_motion_frame().z
       var aim=(game.HOOP-p.position)*Vector3(1,0,1);aim=aim.normalized()
       var alignment=forward.dot(aim);min_release_alignment=minf(min_release_alignment,alignment)
       check(alignment>.93,"Released sideways instead of squared to hoop "+tag+" alignment="+str(alignment))
      if p.action=="shot":
       var shooter=1 if hand>0 else 0
       var frame=v.bone_world(v.arms[shooter][2]).basis.orthonormalized()*v.palm_frames[shooter]
       if p.shot_arm_time()>=.34 and p.shot_arm_time()<=.44:
        check(frame.y.dot(Vector3.DOWN)>.65,"No visible wrist snap "+tag);folded=true
       if p.action_time>=.79:
        var head=v.bone_world(v.skeleton.find_bone("head")).origin
        check(v.palm_world[0].y<head.y-.25 and v.palm_world[1].y<head.y-.25,"Hands did not recover before running "+tag);lowered=true
      if was_shot and p.action=="idle" and not exited:
       exited=true;exit_origin=p.position
       check(not p.dribble_ended,"Released ball left the runner in held-ball locomotion")
       for i in 2:
        var jump=v.toe_world[i].distance_to(old_toes[i]);max_exit_toe_jump=maxf(max_exit_toe_jump,jump)
        check(jump<.065,"Shoe teleported at shot-to-run handoff "+tag+" distance="+str(jump))
      for i in 2:
       var palm_speed=v.palm_world[i].distance_to(old_palms[i])/dt
       var knee=v.bone_world(v.feet[i][1]).origin;var knee_speed=knee.distance_to(old_knees[i])/dt
       max_palm_speed=maxf(max_palm_speed,palm_speed);max_knee_speed=maxf(max_knee_speed,knee_speed)
       check(palm_speed<14,"Palm snapped in recovery "+tag+" speed="+str(palm_speed))
       check(knee_speed<18,"Knee snapped in recovery "+tag+" speed="+str(knee_speed))
       old_palms[i]=v.palm_world[i];old_knees[i]=knee;old_toes[i]=v.toe_world[i]
      was_shot=p.action=="shot"
     check(released and folded and lowered and exited,"Incomplete shot/recovery coverage "+tag)
     if run_after:check(p.position.distance_to(exit_origin)>.50,"Landing did not push into the next run "+tag)
     cases+=1
 for code in [KEY_UP,KEY_DOWN,KEY_LEFT,KEY_RIGHT,KEY_D]:key(code,false)
 print("SHOT_RECOVERY cases=",cases," min_release_alignment=",min_release_alignment," max_exit_toe_jump=",max_exit_toe_jump," max_palm_speed=",max_palm_speed," max_knee_speed=",max_knee_speed," failures=",failures)
 game.queue_free();await process_frame;quit(1 if failures else 0)
