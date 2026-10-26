extends SceneTree
var failures=0
var cases=0
func _init():call_deferred("run")
func check(ok: bool,message: String):
 if not ok:failures+=1;push_error(message)
func run():
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_physics_process(false);game.sound_enabled=false
 game.start_mode("team")
 var t=game.team_match
 for team_owner in [0,1]:
  t.reset(team_owner)
  t.edges["switch"]=false
  var seen={t.selected:true}
  for n in 3:
   Input.action_press("team_switch");game._physics_process(1.0/60);Input.action_release("team_switch")
   for f in 14:game._physics_process(1.0/60)
   seen[t.selected]=true
  if team_owner==1:check(seen.size()==3,"Switch did not visit all three defenders")
  else:check(seen.size()==1,"Defender switch moved away from a friendly ball owner")
 t.reset(0);t.edges["switch"]=false;game.phase="flight";game.ball_owner=-1;game.shooter=0
 var selected=t.selected;Input.action_press("team_switch");game._physics_process(1.0/60);Input.action_release("team_switch")
 check(t.selected!=(selected),"Loose-ball/rebound phase did not permit a team switch")
 for role in ["guard","forward","center"]:
  game.players[0].court_role=role;game.start_mode("team");t=game.team_match
  var visited=[{},{}];var traveled=[0.0,0.0];var idle=[0.0,0.0];var longest=[0.0,0.0];var old=[game.players[1].position,game.players[2].position]
  for f in 600:
   game._physics_process(1.0/60)
   for i in 2:
    visited[i][t.offball_cursor[i+1]]=true
    var delta=game.players[i+1].position.distance_to(old[i]);traveled[i]+=delta
    idle[i]=idle[i]+1.0/60 if delta<.003 else 0.0;longest[i]=maxf(longest[i],idle[i]);old[i]=game.players[i+1].position
    check(game.players[i+1].position.distance_to(BasketballRules.clamp_to_court(game.players[i+1].position))<.001,"Off-ball player left court")
  for i in 2:
   check(visited[i].size()>=2,"Off-ball movement never advanced to another basketball waypoint")
   check(traveled[i]>9,"Off-ball player did not cut/relocate role="+role+" actor="+str(i+1)+" travel="+str(traveled[i]))
   check(longest[i]<1.25,"Off-ball player stopped too long role="+role+" actor="+str(i+1)+" idle="+str(longest[i]))
  print("OFFBALL role=",role," travel=",traveled," longest_idle=",longest)
  cases+=1
 var a=game.players[0];var b=game.players[3]
 a.position=Vector3(0,0,-4)
 var cleared=t.space_offball_goal(1,Vector3(.5,0,-4.8),a)
 check(absf(cleared.x)>=3.2 and cleared.z>=-4.2,"Off-ball target crowded a driving handler in the paint")
 a.position=Vector3.ZERO;a.rotation.y=0;a.defending=true;a.boxing_out=false;a.defense_weight=1;a.action="idle";a.jump=0;a.chase_recovery=false;b.has_ball=true
 b.position=Vector3(0,0,.78);check(absf(a.guard_contact_extra(b)-.10)<.001,"W frontal pad must be only 10cm")
 b.position=Vector3(.78,0,0);check(a.guard_contact_extra(b)==0,"W pad caught a flank drive")
 b.position=Vector3(0,0,-.78);check(a.guard_contact_extra(b)==0,"W pad caught a beaten defender's rear")
 b.position=Vector3(.67,0,.39);check(a.guard_contact_extra(b)==0,"W pad caught a 60 degree crossover")
 b.position=Vector3(0,0,.78);a.chase_recovery=true;check(a.guard_contact_extra(b)==0,"W pad restored contact during feint recovery")
 a.chase_recovery=false;a.defending=false;check(a.guard_contact_extra(b)==0,"W pad remained after guard release")
 print("TEAM_ACTIVITY cases=",cases," failures=",failures)
 game.queue_free();await process_frame;quit(1 if failures else 0)
