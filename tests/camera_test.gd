extends SceneTree

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.sound_enabled = false
	game.start_mode("practice")
	game.frame_court(0)
	var camera: Camera3D = game.camera
	var far_width = camera.unproject_position(Vector3(-7.5, 0, -7.225)).distance_to(camera.unproject_position(Vector3(7.5, 0, -7.225)))
	var near_width = camera.unproject_position(Vector3(-7.5, 0, 4)).distance_to(camera.unproject_position(Vector3(7.5, 0, 4)))
	var failures = 0
	if camera.projection != Camera3D.PROJECTION_PERSPECTIVE or near_width / far_width < 1.5: failures += 1
	for size in [Vector2i(960,650),Vector2i(390,510),Vector2i(844,390)]:
		root.size = size
		root.content_scale_size = size
		await process_frame
		for position in [Vector3(-7.2,0,6.475),Vector3(7.2,0,6.475),Vector3(-7.2,0,-6.925),Vector3(7.2,0,-6.925)]:
			game.players[0].position = position
			game.frame_court(0)
			var rect = root.get_visible_rect()
			for height in [.1, 2.05]:
				var screen = camera.unproject_position(position + Vector3.UP * height)
				if not rect.has_point(screen):
					print("OUTSIDE_FRAME ", position, " => ", screen, " viewport ", rect)
					failures += 1
	print("CAMERA_TEST perspective_ratio=", near_width / far_width, " failures=", failures)
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
