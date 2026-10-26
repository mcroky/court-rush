extends SceneTree
var failures=0
func _init():call_deferred("run")
func check(ok:bool,message:String):
	if not ok:failures+=1;push_error(message)
func legacy_zoom(game,focus:Vector3,offset:Vector3) -> float:
	var zoom=1.0
	for attempt in 14:
		game.camera.position=focus+offset*zoom;game.camera.look_at(focus)
		var fits=true
		for point in [game.players[0].position+Vector3.UP*.1,game.players[0].position+Vector3.UP*2.15,game.HOOP]:
			var screen=game.camera.unproject_position(point)/Vector2(root.size)
			if game.camera.is_position_behind(point) or screen.x<.06 or screen.x>.94 or screen.y<.14 or screen.y>.67:fits=false
		if fits:break
		zoom*=1.07
	return zoom
func run():
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_physics_process(false);game.sound_enabled=false
	root.size=Vector2i(390,510);root.content_scale_size=root.size;await process_frame
	game.start_mode("practice")
	var peaks=[];var final_zoom=[];var legacy_peak=0.0
	for fps in [30,60,120]:
		game.players[0].position=Vector3(0,0,3);game.players[0].motion=Vector2.ZERO;game.frame_court(0)
		var previous=game.camera_mobile_zoom;var old_previous=1.0;var peak=0.0
		for frame in fps*3:
			var u=float(frame+1)/(fps*3)
			game.players[0].position=Vector3(7.2*u,0,3+3.4*u);game.players[0].motion=Vector2(2.4,1.13)
			game.frame_court(1.0/fps)
			peak=maxf(peak,absf(game.camera_mobile_zoom/previous-1));previous=game.camera_mobile_zoom
			var focus=game.camera_focus+game.camera_mobile_follow
			var old=legacy_zoom(game,focus,Vector3(0,3.8,11.5))
			if frame>0:legacy_peak=maxf(legacy_peak,absf(old/old_previous-1))
			old_previous=old
		game.players[0].motion=Vector2.ZERO
		for frame in fps*2:game.frame_court(1.0/fps)
		peaks.append(peak);final_zoom.append(game.camera_mobile_zoom)
		check(peak<.035,"Camera still steps during a continuous run at "+str(fps)+" FPS")
		for target in [game.players[0].position+Vector3.UP*.1,game.players[0].position+Vector3.UP*1.9,game.HOOP]:
			check(Rect2(Vector2.ZERO,Vector2(root.size)).has_point(game.camera.unproject_position(target)),"Settled framing clipped a target")
	check(legacy_peak>.06,"Regression path did not reproduce the old zoom steps")
	check(absf(final_zoom[0]-final_zoom[2])<.01,"Frame-rate-dependent camera settling")
	print("MOBILE_CAMERA_TRANSITION legacy_peak=",legacy_peak," new_peaks_30_60_120=",peaks," settled=",final_zoom," failures=",failures)
	game.queue_free();await process_frame;quit(1 if failures else 0)
