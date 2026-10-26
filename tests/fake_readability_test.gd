extends SceneTree
var failures=0
var cases=0
func _init():call_deferred("run")
func check(ok: bool,message: String):
	if not ok:
		failures+=1
		push_error(message)
func run():
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_physics_process(false)
	game.sound_enabled=true;game.court_audio.configure(false,false)
	for kind in ["pivot","jab","pump","upunder","through","turn"]:
		game.start_mode("practice");game.court_audio.configure(false,false);var p=game.players[0];p.position=Vector3(0,0,1);p.rotation.y=PI;p.facing=PI;p.reset_stance();p.feet_world.clear()
		for f in 20:game._physics_process(1.0/60)
		game.fake_shot(0)
		for f in 50:game._physics_process(1.0/60)
		var v=p.skinned;var ball_start=game.ball.position;var start=game.camera.unproject_position(ball_start)
		var player_pixels=game.camera.unproject_position(p.position).distance_to(game.camera.unproject_position(p.position+Vector3.UP*1.78))
		var shoulder_start=(v.bone_world(v.arms[1][0]).origin-v.bone_world(v.arms[0][0]).origin).normalized()
		p.held.begin(p,kind,p.global_basis.z if kind=="jab" else p.global_basis.x,game.ball.position)
		var max_pixels=0.0;var max_ball=0.0;var max_shoulders=0.0;var sounds_before=game.audio_index
		for f in 70:
			game._physics_process(1.0/60)
			max_pixels=maxf(max_pixels,game.camera.unproject_position(game.ball.position).distance_to(start))
			max_ball=maxf(max_ball,game.ball.position.distance_to(ball_start))
			var shoulders=(v.bone_world(v.arms[1][0]).origin-v.bone_world(v.arms[0][0]).origin).normalized()
			max_shoulders=maxf(max_shoulders,shoulder_start.angle_to(shoulders))
		check(max_pixels/player_pixels>.12,"Fake too small at actual game camera: "+kind)
		check(max_ball>.28,"Ball threat did not move enough: "+kind)
		if kind!="pump":check(max_shoulders>.15,"Shoulders did not sell fake: "+kind)
		var expected=0 if kind=="pump" else 2 if kind in ["turn","upunder"] else 1
		check(game.audio_index-sounds_before==expected,"Foot-contact squeak duplicated or missing: "+kind)
		print("FAKE ",kind," pixels/player=",snappedf(max_pixels/player_pixels,.001)," ball_m=",snappedf(max_ball,.001)," shoulders_rad=",snappedf(max_shoulders,.001)," squeaks=",game.audio_index-sounds_before)
		cases+=1
	print("FAKE_READABILITY cases=",cases," failures=",failures)
	game.court_audio.configure(false,false)
	for stream in game.audio_pool:stream.stop();stream.stream=null
	game.queue_free();await create_timer(.20).timeout;quit(1 if failures else 0)
