extends SceneTree
var failures=0
var gathers=0
var chase_samples=0
var pickup_samples=0
const Fixture=preload("res://tests/block_deflection_test.gd")
func _init():call_deferred("run")
func check(ok:bool,message:String):
	if not ok:failures+=1;push_error(message)
func run():
	var g=load("res://scenes/main.tscn").instantiate();root.add_child(g);g.set_physics_process(false);g.sound_enabled=false
	var fixture=Fixture.new()
	for fps in [30,60,120]:
		var dt=1.0/fps
		var input=fixture.setup(g,"practice")
		for f in roundi(.33*fps):g._physics_process(dt)
		input.shootSeq=1
		for f in fps:
			g._physics_process(dt)
			if g.players[0].block_contact:break
		check(g.players[0].block_contact,"Scramble fixture failed to make actual palm contact")
		var hit_time=g.time
		var previous=g.ball.position
		var settled=false
		for f in fps*5:
			var offset=g.loose_chase_target(g.players[0])-g.players[0].position
			var desired=Vector2(offset.x,offset.z).limit_length()
			input.x=desired.x;input.z=desired.y
			g._physics_process(dt)
			check(g.ball.position.distance_to(previous)<.7,"Scramble ball jumped between simulation frames")
			previous=g.ball.position
			if g.phase=="loose" and g.players[1].motion.length()>1.5:chase_samples+=1
			if g.ball_owner>=0 and g.phase=="live":
				gathers+=1
				var owner=g.players[g.ball_owner]
				check(owner.action=="pickup","Loose-ball contest skipped gathering motion")
				check(g.time-hit_time>.18,"Scramble bypassed block escape")
				for beat in roundi(.6*fps):
					g._physics_process(dt)
					if owner.action=="pickup":pickup_samples+=1
					check(g.ball.position.distance_to(previous)<.55,"Scoop/chest/dribble ball jumped")
					previous=g.ball.position
				check(owner.action=="idle" and owner.jump==0,"Gather failed to recover into running dribble")
				settled=true;break
			if g.phase=="check":break
		if not settled:print("SCRAMBLE_WAIT fps=",fps," phase=",g.phase," ball=",g.ball.position," actor0=",g.players[0].position," actor1=",g.players[1].position," actions=",g.players.map(func(a):return a.action))
		check(settled,"Actual block left no playable chase-and-gather opportunity at %s fps"%fps)
		# A human can stand still: the shooter must land, chase and actually
		# gather, rather than the practice timeout fabricating a new possession.
		input=fixture.setup(g,"practice")
		for f in roundi(.33*fps):g._physics_process(dt)
		input.shootSeq=1
		var saw_loose=false;var rival_gather=false
		for f in fps*6:
			g._physics_process(dt)
			if g.phase=="loose":saw_loose=true
			if saw_loose and g.phase=="check":break
			if saw_loose and g.phase=="live" and g.ball_owner==1:
				rival_gather=g.players[1].action=="pickup";break
		check(rival_gather,"Unassisted rival chase ended in a reset instead of actual contact")
	check(chase_samples>5,"Both actors never chased after landing")
	check(pickup_samples>10,"Pickup was not visible across multiple frames")
	print("BLOCK_SCRAMBLE gathers=",gathers," chase_samples=",chase_samples," pickup_samples=",pickup_samples," failures=",failures)
	g.web_input=null;fixture.free();g.queue_free();await process_frame;quit(1 if failures else 0)
