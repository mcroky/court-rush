extends SceneTree
var failures=0
var cases=0
var samples=0
var min_plant_width=10.0
var max_slide=0.0
var max_knee_speed=0.0
var max_palm_speed=0.0
var max_toe_speed=0.0
func _init():call_deferred("run")
func key(code: Key, down: bool):
 var e=InputEventKey.new();e.keycode=code;e.physical_keycode=code;e.pressed=down
 Input.parse_input_event(e);Input.flush_buffered_events()
func check(ok: bool,message: String):
 if not ok:
  failures+=1
  if failures<22:push_error(message)
func run():
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_physics_process(false);game.sound_enabled=false
 var directions=[[KEY_UP],[KEY_DOWN],[KEY_LEFT],[KEY_RIGHT],[KEY_UP,KEY_LEFT],[KEY_UP,KEY_RIGHT],[KEY_DOWN,KEY_LEFT],[KEY_DOWN,KEY_RIGHT]]
 for fps in [30,60,120]:
  var dt=1.0/fps
  for direction in directions:
   for run_time in [.15,.24,.33,.42,.51,.60]:
    for hand in [-1.0,1.0]:
     for code in [KEY_UP,KEY_DOWN,KEY_LEFT,KEY_RIGHT,KEY_D]:key(code,false)
     game.start_mode("practice")
     var p=game.players[0];var v=p.skinned
     var role=["guard","forward","center"][cases%3]
     p.apply_athlete({"role":role,"height":{"guard":178,"forward":190,"center":204}[role]})
     p.position=Vector3(0,0,3.5);p.feet_world.clear();p.reset_stance();p.dribble_hand=hand
     for f in int(fps*.20):game._physics_process(dt)
     for code in direction:key(code,true)
     for f in int(run_time/dt):game._physics_process(dt)
     var old_toes=v.toe_world.duplicate();var old_locks=v.locked.duplicate();var old_palms=v.palm_world.duplicate()
     var old_knees=[]
     for i in 2:old_knees.append(v.bone_world(v.feet[i][1]).origin)
     var approach_yaw=p.rotation.y
     var initial_gap=(old_toes[1]-old_toes[0]).dot(p.global_basis.x)
     var gathered=false;var released=false;var landed=false
     var squared=false;var square_finished=false
     key(KEY_D,true)
     # Include the new grounded turnaround before gather, plus full recovery.
     for f in int(fps*2.70):
      game._physics_process(dt);game.flight_made=false
      if p.action=="square":squared=true
      if squared and not square_finished and p.action=="gather":
       square_finished=true;approach_yaw=p.rotation.y
       initial_gap=(v.toe_world[1]-v.toe_world[0]).dot(p.global_basis.x)
       check(absf(angle_difference(approach_yaw,atan2(game.HOOP.x-p.position.x,game.HOOP.z-p.position.z)))<.10,"Grounded turn did not square before lifting")
      if cases%2==0 and p.action=="gather" and p.action_time>=.20:key(KEY_D,false)
      var gather=p.action=="gather"
      var shot=p.action=="shot"
      var tag="fps=%d dir=%s run=%.2f hand=%.0f action=%s t=%.3f" % [fps,str(direction),run_time,hand,p.action,p.action_time]
      if gather or shot:
       var gap=(v.toe_world[1]-v.toe_world[0]).dot(p.global_basis.x)
       var knee_gap=(v.bone_world(v.feet[1][1]).origin-v.bone_world(v.feet[0][1]).origin).dot(p.global_basis.x)
       if gather:
        if p.turnaround_shot:approach_yaw=p.rotation.y
        check(absf(angle_difference(approach_yaw,p.rotation.y))<.002,"Hips turned across the running plants "+tag)
        check(gap>=minf(initial_gap,.12)-.025,"Receiving foot cut across the old support "+tag+" width="+str(gap))
        if p.action_time>=.10:
         check(gap>.12*p.height_ratio,"Gather feet crossed before takeoff "+tag+" width="+str(gap))
         check(knee_gap>.10*p.height_ratio,"Gather knees crossed "+tag+" width="+str(knee_gap))
         if not p.turnaround_shot or p.held.entry_time>=.12:check(v.locked[0] or v.locked[1],"Gather lost both supporting feet "+tag)
        if p.action_time>=.19:
         gathered=true;min_plant_width=minf(min_plant_width,gap)
         if p.action_time>=.25 and (not p.turnaround_shot or p.held.square_ready(p)):
          for toe in v.toe_world:check(absf(toe.y-.026)<.006,"Shoe was still airborne at the shot load "+tag+" toe="+str(toe)+" ready="+str(p.held.square_ready(p)))
        check(p.step_serial-p.gather_step_start<=2,"Gather added an illegal third step "+tag)
       if shot and p.action_time<=p.SHOT_PLANT_TIME:
        if p.turnaround_shot:approach_yaw=p.shot_gather_yaw
        check(gap>.12*p.height_ratio and knee_gap>.10*p.height_ratio,"Shot began with twisted legs "+tag)
        if p.action_time>=.075:
         for toe in v.toe_world:check(absf(toe.y-.026)<.006,"Closing step missed the takeoff plant "+tag)
        check(absf(angle_difference(approach_yaw,p.rotation.y))<.002,"Turn started before toe-off "+tag)
       if shot and p.action_time>.80:landed=true
       for i in 2:
        var chain=v.feet[i]
        var knee=v.bone_world(chain[1]).origin
        var knee_speed=knee.distance_to(old_knees[i])/dt
        var palm_speed=v.palm_world[i].distance_to(old_palms[i])/dt
        var toe_speed=v.toe_world[i].distance_to(old_toes[i])/dt
        max_knee_speed=maxf(max_knee_speed,knee_speed);max_palm_speed=maxf(max_palm_speed,palm_speed);max_toe_speed=maxf(max_toe_speed,toe_speed)
        check(knee_speed<18,"Knee snapped "+tag+" speed="+str(knee_speed))
        check(palm_speed<14,"Palm snapped "+tag+" speed="+str(palm_speed))
        for pair in [[chain[0],chain[1]],[chain[1],chain[2]]]:
         var length=v.skeleton.get_bone_rest(pair[1]).origin.length()*v.render_scale
         check(absf(v.bone_world(pair[0]).origin.distance_to(v.bone_world(pair[1]).origin)-length)<.0004,"Leg stretched "+tag)
        var plant=gather or (shot and (p.action_time<=p.SHOT_PLANT_TIME or p.action_time>.76))
        if plant and old_locks[i] and v.locked[i]:
         var slide=v.toe_world[i].distance_to(old_toes[i]);max_slide=maxf(max_slide,slide)
         check(slide<.012,"Planted forefoot slid "+tag+" slide="+str(slide)+" drop="+str(v.ground_drop)+" root="+str(v.root_height)+" goal="+str(v.anchors[i])+" toe="+str(v.toe_world[i]))
        old_knees[i]=knee;samples+=1
      if game.phase=="flight":released=true
      for i in 2:
       old_toes[i]=v.toe_world[i];old_locks[i]=v.locked[i];old_palms[i]=v.palm_world[i]
       old_knees[i]=v.bone_world(v.feet[i][1]).origin
     check(gathered and released and landed and game.attempts==1,"Shot sequence did not complete exactly once fps="+str(fps)+" direction="+str(direction)+" run="+str(run_time)+" hand="+str(hand)+" action="+p.action+" t="+str(p.action_time)+" gather="+str(gathered)+" release="+str(released)+" landed="+str(landed)+" attempts="+str(game.attempts))
     cases+=1
 for code in [KEY_UP,KEY_DOWN,KEY_LEFT,KEY_RIGHT,KEY_D]:key(code,false)
 print("SHOT_ENTRY cases=",cases," actual_leg_frames=",samples," min_ready_width=",min_plant_width," max_slide=",max_slide," max_toe_speed=",max_toe_speed," max_knee_speed=",max_knee_speed," max_palm_speed=",max_palm_speed," failures=",failures)
 game.queue_free();await process_frame;quit(1 if failures else 0)
