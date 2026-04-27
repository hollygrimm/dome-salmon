## PlayerFish.gd — Keanu's contribution to dome-salmon
##
## A single viewer-controlled salmon that swims alongside the MultiMesh
## school. WASD moves in the XZ plane, Q/E or Space/Shift moves up/down.
##
## This is a Node3D hero fish (not part of the MultiMesh buffer). It lives
## in the scene tree as its own MeshInstance3D with its own transform.
## DomeCamera can follow it via SALMON_POV mode.
##
## Ports directly from Keanu's own sp26-csat201-godot-KeanuBegay/Script/
## PlayerFish.gd + ChaseCamera.gd. The salmon model is loaded from the
## same assets/ folder SalmonSchool.gd uses, so visually it blends with
## the school.
##
## ─── CONTRACT ──────────────────────────────────────────────────────────────
## This is a full scene-ready Node3D. You implement:
##
##   _read_input() -> Vector3
##     Returns the desired velocity this frame based on input actions.
##     See input map setup below.
##
##   Optional: tune @export vars for swim_speed, turn_smoothing, etc.
##
## Rules:
##   - DO NOT touch SalmonSchool.gd's internals. Your fish is a separate
##     Node3D — the school doesn't know it exists.
##   - DO NOT spawn your own camera. DomeCamera (existing) handles viewing.
##     Just expose a `global_position` so DomeCamera can track you.
##
## Input map (add to project.godot via Project Settings → Input Map):
##   move_left      → A
##   move_right     → D
##   move_forward   → W
##   move_back      → S
##   move_up        → Space (or Q)
##   move_down      → Shift (or E)
## ───────────────────────────────────────────────────────────────────────────

class_name PlayerFish
extends Node3D

@export var swim_speed: float = 4.0
@export var turn_smoothing: float = 0.15
@export var salmon_glb_path: String = "res://assets/salmon.glb"

var velocity: Vector3 = Vector3.ZERO
var _mesh_instance: Node3D


func _ready() -> void:
	_load_mesh()


func _physics_process(delta: float) -> void:
	velocity = _read_input()
	global_position += velocity * delta

	# Face the direction of travel. Guard against zero-length to avoid
	# look_at errors when the fish is idle.
	if velocity.length() > 0.01:
		var target := global_position + velocity
		look_at(target, Vector3.UP)


func _read_input() -> Vector3:
	var planar := Input.get_vector(
	"move_left", "move_right", "move_forward", "move_back")
	var vertical := Input.get_axis("move_down", "move_up")
	return Vector3(planar.x, -vertical, planar.y) * swim_speed


func _load_mesh() -> void:
	# Load the salmon.glb used by the rest of the school so the hero fish
	# visually matches. Falls back to a colored capsule if not found.
	var scene := load(salmon_glb_path) as PackedScene
	if scene:
		_mesh_instance = scene.instantiate()
		add_child(_mesh_instance)
		return

	# Fallback placeholder
	var mi := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.15
	capsule.height = 0.8
	mi.mesh = capsule
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.861, 0.286, 0.369, 1.0)  # distinguish from school
	mi.set_surface_override_material(0, mat)
	add_child(mi)
	_mesh_instance = mi
	push_warning("[PlayerFish] salmon.glb not found — using capsule placeholder.")
