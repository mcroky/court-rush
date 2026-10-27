extends SceneTree
## Paired CPU timing: identical seed/input, alternating execution order.
## This is not a GPU timer or a claim about browser/device frame rate.
const Web=preload("res://tests/block_quick_input_test.gd")
func _init():call_deferred("run")
func stats(values:Array)->Dictionary:
	var sorted=values.duplicate();sorted.sort();var total=0.0
	for n in sorted:total+=n
	return {"mean_ms":total/sorted.size()/1000,"p95_ms":sorted[floori(sorted.size()*.95)]/1000.0,"p99_ms":sorted[floori(sorted.size()*.99)]/1000.0,"max_ms":sorted[-1]/1000.0,"samples":sorted.size()}
func run():
	var games=[]
	for i in 2:
		var g=load("res://scenes/main.tscn").instantiate();root.add_child(g);g.set_physics_process(false);g.sound_enabled=false;games.append(g)
	for mode in ["team","duel"]:
		for i in 2:
			var g=games[i];g.web_input=null;g.start_mode(mode);g.rng.seed=623817
			for p in g.players:p.skinned.motion_cache_enabled=i==1;p.motion_buffers_enabled=i==1
			g.web_input=Web.web();g.web_control_reset=-1
		var values=[[],[]]
		for frame in 1500:
			for i in ([0,1] if frame%2==0 else [1,0]):
				var g=games[i];var input=g.web_input
				input.x=sin(frame*.013)*.75;input.z=cos(frame*.013)*.75
				input.shoot=frame%210>=95 and frame%210<130
				input.cross=frame%180==35;input.guard=frame%200>145
				if frame%110==0:input.passSeq+=1
				var before=Time.get_ticks_usec();g._physics_process(1.0/60)
				if frame>=90:values[i].append(Time.get_ticks_usec()-before)
		var hits=0;var misses=0
		for p in games[1].players:hits+=p.skinned.finger_cache_hits;misses+=p.skinned.finger_cache_misses
		print("MOTION_BENCH ",JSON.stringify({"mode":mode,"original":stats(values[0]),"optimized":stats(values[1]),"finger_hits":hits,"finger_misses":misses}))
	for g in games:g.web_input=null;g.queue_free()
	await process_frame;quit()
