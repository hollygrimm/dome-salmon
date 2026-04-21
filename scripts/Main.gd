## Main.gd
## Root scene controller.
## Handles: debug UI, window sizing for TouchDesigner capture, keyboard stubs.
##
## Scene tree:
##   Main (Node3D)          ← this script
##   ├── Camera3D
##   ├── DirectionalLight3D
##   ├── SalmonSchool (MultiMeshInstance3D + SalmonSchool.gd)
##   ├── RiverEnvironment (Node3D — placeholder)
##   └── DebugPanel (CanvasLayer > VBoxContainer > Label)

extends Node3D

@onready var debug_label: Label = $DebugPanel/VBox/Label
@onready var camera: Camera3D = $Camera3D

# River geometry — built procedurally in _ready()
var river_path: Path3D
var river_current: RiverCurrent
var dome_camera: DomeCamera

# Procedural meander config
const RIVER_LENGTH: float = 60.0
const MEANDER_AMPLITUDE: float = 5.0
const MEANDER_WAVES: float = 2.5
const PATH_POINT_COUNT: int = 32

# Keyboard stubs — simulate OSC while sensors aren't connected yet
# Keys 1-5 raise each performer parameter; holding nothing lets them decay
const STUB_KEYS := [
	KEY_1, KEY_2, KEY_3, KEY_4, KEY_5
]
const STUB_ADDRESSES : PackedStringArray = [
	"/performer/1/velocity",
	"/performer/2/lateral",
	"/performer/3/vertical",
	"/performer/4/rotation",
	"/performer/5/stillness",
]

var _debug_visible := true


func _ready() -> void:
	# Dome demo: launch fullscreen on the second display if present.
	# Dome is 1:1 aspect; Mac Mini M4 second display maxes at 3840x2160,
	# so a square viewport letterboxes cleanly via stretch aspect "keep".
	var screen_count := DisplayServer.get_screen_count()
	var target_screen := 1 if screen_count > 1 else 0
	DisplayServer.window_set_current_screen(target_screen)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	DisplayServer.window_set_title("DomeSalmon — OSC Port 8000")
	print("[Main] Ready. OSC listening on port 8000.")
	print("[Main] Keyboard stubs: 1-5 to simulate performers, D to toggle debug.")

	_build_river_path()
	_build_river_current()
	_wire_salmon_school()
	_build_dome_camera()


# ── Procedural river setup ─────────────────────────────────────────────────────

## Builds a sinusoidal Path3D from downstream (+Z) to upstream (-Z), matching
## RiverEnvironment's river_length and SalmonSchool's upstream_direction.
## Progress 0 = estuary, progress 1 = headwaters.
func _build_river_path() -> void:
	river_path = Path3D.new()
	river_path.name = "RiverPath"

	var curve := Curve3D.new()
	for i in PATH_POINT_COUNT:
		var t := float(i) / float(PATH_POINT_COUNT - 1)
		var z := lerpf(RIVER_LENGTH * 0.5, -RIVER_LENGTH * 0.5, t)
		var x := sin(t * PI * MEANDER_WAVES) * MEANDER_AMPLITUDE
		# Smooth in/out handles tangent to the local sine derivative
		var dz := -RIVER_LENGTH / float(PATH_POINT_COUNT - 1)
		var dx := cos(t * PI * MEANDER_WAVES) * MEANDER_AMPLITUDE \
				* (PI * MEANDER_WAVES / float(PATH_POINT_COUNT - 1))
		var handle := Vector3(dx, 0.0, dz) * 0.5
		curve.add_point(Vector3(x, 0.0, z), -handle, handle)
	river_path.curve = curve
	add_child(river_path)


## Creates the RiverCurrent node and binds the path before _ready fires.
func _build_river_current() -> void:
	river_current = RiverCurrent.new()
	river_current.name = "RiverCurrent"
	river_current.river_path = river_path
	river_current.base_speed = 1.4
	river_current.channel_half_width = 8.0
	add_child(river_current)


## Hand the RiverCurrent reference to SalmonSchool so its boids sample the flow.
func _wire_salmon_school() -> void:
	var school := $SalmonSchool as MultiMeshInstance3D
	if school and school.has_method("set"):
		school.set("river_current", river_current)


## Replace the static Camera3D with a DomeCamera riding a PathFollow3D.
func _build_dome_camera() -> void:
	var follow := PathFollow3D.new()
	follow.name = "CameraFollow"
	follow.rotation_mode = PathFollow3D.ROTATION_ORIENTED
	follow.loop = true
	river_path.add_child(follow)

	dome_camera = DomeCamera.new()
	dome_camera.name = "DomeCamera"
	dome_camera.camera_mode = DomeCamera.CameraMode.UNDERWATER
	dome_camera.look_ahead_distance = 14.0  # look further down the river
	dome_camera.travel_speed = 0.015        # ~0.9 m/s, slower than fish so they catch up
	follow.add_child(dome_camera)
	dome_camera.make_current()

	# Retire the original static camera from the scene
	if camera and is_instance_valid(camera):
		camera.queue_free()


func _process(_delta: float) -> void:
	_handle_keyboard_stubs()
	_update_debug()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_D:
			_debug_visible = !_debug_visible
			debug_label.visible = _debug_visible
		if event.keycode == KEY_ESCAPE:
			get_tree().quit()


func _handle_keyboard_stubs() -> void:
	# While sensors aren't connected: hold number keys to ramp params up,
	# release to let them decay naturally through OSCReceiver's smoothing.
	for i in STUB_KEYS.size():
		var address := STUB_ADDRESSES[i]
		if Input.is_key_pressed(STUB_KEYS[i]):
			# Inject directly into OSCReceiver targets (bypasses UDP)
			OSCReceiver._targets[address] = min(
				OSCReceiver._targets.get(address, 0.0) + 0.02, 1.0
			)
		else:
			OSCReceiver._targets[address] = max(
				OSCReceiver._targets.get(address, 0.0) - 0.01, 0.0
			)


func _update_debug() -> void:
	if not _debug_visible:
		return
	debug_label.text = (
		"=== DomeSalmon Debug ===\n" +
		ParameterBank.debug_string() +
		"\n[D] toggle  [1-5] simulate performers  [ESC] quit\n" +
		"OSC port: 8000  |  Display: fullscreen screen 1 → DisplayPort → ScreenBerry"
	)
