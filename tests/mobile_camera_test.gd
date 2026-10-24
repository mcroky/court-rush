extends SceneTree

var failures = 0

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.sound_enabled = false
	game.start_mode("practice")
	for size in [Vector2i(390,510), Vector2i(320,510), Vector2i(390,650), Vector2i(844,390)]:
		root.size = size
		root.content_scale_size = size
		await process_frame
		for position in [Vector3(0,0,3),Vector3(0,0,-5),Vector3(-7.2,0,6.475),Vector3(7.2,0,-6.925)]:
			game.players[0].position = position
			game.players[0].motion = Vector2.ZERO
			game.frame_court(0)
			var cam: Camera3D = game.camera
			var feet = cam.unproject_position(position+Vector3.UP*.1)
			var head = cam.unproject_position(position+Vector3.UP*1.9)
			var rim = cam.unproject_position(game.HOOP)
			var height = feet.distance_to(head)
			print("MOBILE_CAMERA ",size," at=",position," height=",height," feet=",feet/Vector2(size)," rim=",rim/Vector2(size)," zoom=",game.camera_mobile_zoom)
			if not Rect2(Vector2.ZERO,Vector2(size)).has_point(feet) or not Rect2(Vector2.ZERO,Vector2(size)).has_point(head): failures+=1
			if size.x<size.y and (height<55 or feet.y/size.y>.68 or rim.y/size.y<.12): failures+=1
			if absf(position.x)<.1 and size.x<size.y and height<75: failures+=1
	# Movement smoothing must converge without reusing the wide camera's follow offset.
	root.size=Vector2i(390,510)
	root.content_scale_size=root.size
	await process_frame
	game.players[0].position=Vector3(0,0,3)
	game.frame_court(0)
	game.players[0].position=Vector3(3,0,1)
	for i in range(120): game.frame_court(1.0/60)
	var settled=game.camera.global_position
	game.frame_court(0)
	if settled.distance_to(game.camera.global_position)>.05: failures+=1
	# Keep the high shot / rebound and a nearby defender in view as well as the player.
	game.start_mode("duel")
	game.players[0].position=Vector3(0,0,2)
	game.players[1].position=Vector3(1,0,0)
	for phase in ["takeoff","flight","loose"]:
		game.phase=phase
		for ball in [Vector3(1,6.5,-2),game.HOOP+Vector3.UP,Vector3(-3,2,1)]:
			game.ball.position=ball
			game.frame_court(0)
			for point in [ball,game.players[0].position+Vector3.UP*1.9,game.players[1].position+Vector3.UP*1.9,game.HOOP]:
				if not Rect2(Vector2.ZERO,Vector2(root.size)).has_point(game.camera.unproject_position(point)): failures+=1
	print("MOBILE_CAMERA_TEST failures=",failures)
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
