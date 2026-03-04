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
	# Set window to 1920×1080 — TouchDesigner Screen Capture TOP grabs this
	# Until a Godot 4 Syphon GDExtension exists, Screen Capture is the bridge.
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	DisplayServer.window_set_title("DomeSalmon — OSC Port 8000")
	print("[Main] Ready. OSC listening on port 8000.")
	print("[Main] Keyboard stubs: 1-5 to simulate performers, D to toggle debug.")


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
		"OSC port: 8000  |  Syphon: use Screen Capture TOP in TD"
	)
