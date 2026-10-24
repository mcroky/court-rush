extends Node3D
## Source-clip comparison only. This scene does not replace match animation.
const Model = preload("res://assets/experiments/mannequiny/mannequiny.glb")
const Actor = preload("res://scripts/actor.gd")
const Art = preload("res://scripts/art.gd")
var legacy: Node3D
var rig: Node3D
var animation: AnimationPlayer
var skeleton: Skeleton3D
var elapsed = 0.0
var speed = 0.0
var mode = "run"
var previous_mode = ""
var last_replay = -1
var paused = false
var slow = false
var side_view = false
var web_controls
var camera: Camera3D

func _ready() -> void:
	var world = WorldEnvironment.new()
	var environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("162e32")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("ccd9e7")
	environment.ambient_light_energy = .65
	world.environment = environment
	add_child(world)
	var sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50,-25,0)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	add_child(sun)
	Art.box(self,Vector3(0,-.055,0),Vector3(30,.1,30),"247c7a")
	for x in [-1.05,1.05]:
		Art.arc(self,Vector3(x,.004,0),.65,0,TAU,"e5d7b7",.015,48)
	Art.box(self,Vector3(0,.002,0),Vector3(.015,.006,4.5),"a9c5b5")
	legacy = Actor.new()
	legacy.use_skinned = false
	add_child(legacy)
	legacy.setup(false)
	legacy.position = Vector3(-1.05,0,0)
	legacy.rotation.y = .45
	legacy.facing = .45
	legacy.has_ball = false
	legacy.animate(.016,0)
	rig = Model.instantiate()
	add_child(rig)
	rig.position = Vector3(1.05,0,0)
	rig.rotation.y = .45
	animation = rig.find_child("AnimationPlayer",true,false)
	skeleton = rig.find_children("*","Skeleton3D")[0]
	# Keep loop settings local to the comparison; preserve the original GLB.
	var library = animation.get_animation_library("").duplicate(true)
	animation.remove_animation_library("")
	animation.add_animation_library("",library)
	for clip in ["idle","run"]: animation.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	animation.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	animation.play("run")
	animation.advance(0)
	camera = Camera3D.new()
	add_child(camera)
	camera.current = true
	if OS.has_feature("web"): web_controls = JavaScriptBridge.get_interface("window").crMotionInput
	else:
		var layer = CanvasLayer.new()
		add_child(layer)
		var label = Label.new()
		label.text = "MOTION LAB | Left: procedural / Right: skinned source clip\n1 Run   2 Idle / Run blend   3 Original landing clip   Space Pause"
		label.position = Vector2(20,20)
		layer.add_child(label)
	update_camera()

func update_camera() -> void:
	var size = get_viewport().get_visible_rect().size
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = clampf(38*maxf(1,1.6/maxf(size.x/maxf(size.y,1),.5)),38,80)
	camera.position = Vector3(0,2.15,5.7)
	camera.look_at(Vector3(0,.88,0))

func set_mode(value: String, replay: bool = false) -> void:
	if value not in ["run","flow","land","idle"]: return
	mode = value
	if mode != previous_mode or replay:
		elapsed = 0
		previous_mode = mode
		if mode == "land":
			animation.stop()
			animation.play("air_land",.12)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo(): return
	if event.is_action_pressed("ui_accept"): paused = not paused
	if event is InputEventKey:
		if event.keycode == KEY_1: set_mode("run")
		if event.keycode == KEY_2: set_mode("flow")
		if event.keycode == KEY_3: set_mode("land")

func _physics_process(delta: float) -> void:
	if web_controls != null:
		var replay = int(web_controls.replay)
		set_mode(str(web_controls.mode),replay!=last_replay)
		last_replay = replay
		paused = bool(web_controls.paused)
		slow = bool(web_controls.slow)
		side_view = bool(web_controls.side)
	update_camera()
	if paused: return
	if slow: delta *= .35
	elapsed += delta
	var desired_speed = 4.7
	if mode == "idle" or mode == "land": desired_speed = 0
	if mode == "flow":
		var phase = fposmod(elapsed,7)
		desired_speed = 4.7 if phase>1.3 and phase<5.2 else 0.0
	speed = move_toward(speed,desired_speed,delta*12)
	if mode != "land":
		var clip = "run" if speed>.45 else "idle"
		if animation.current_animation != clip: animation.play(clip,.20)
		animation.speed_scale = clampf(speed/4.7,.45,1.0) if clip == "run" else 1.0
	else: animation.speed_scale = 1.0
	animation.advance(delta)
	var yaw = PI*.5 if side_view else .45
	rig.rotation.y = yaw
	legacy.rotation.y = yaw
	legacy.facing = yaw
	var desired = Vector2(sin(yaw),cos(yaw))*desired_speed
	legacy.steer_motion(desired,12,delta)
	var travel = legacy.movement_step(delta)
	legacy.position += travel
	legacy.animate(delta,elapsed)
	# Same treadmill normalization as the existing character showroom.
	legacy.position -= travel
	legacy.previous_position -= travel
	for i in range(2):
		legacy.feet_world[i] -= travel
		legacy.swing_from[i] -= travel
		legacy.swing_to[i] -= travel
