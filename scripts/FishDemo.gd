## FishDemo.gd
## Demonstrates loading a GLB model, playing its animation,
## and driving movement from CulturalValue resources.
##
## Attach to a Node3D in your scene.
## Assign .tres value files in the Inspector under "Values".
## Drop your .glb file into res://assets/ and update the lines marked ←.

extends Node3D

# --- Cultural values (assign .tres files in the Inspector) ---
@export var values: Array[CulturalValue] = []

# --- Internal state ---
var _mesh_instance: Node3D
var _anim: AnimationPlayer
var _velocity := Vector3.ZERO
var _phase := 0.0


func _ready() -> void:
	# ← Update this path to match your GLB filename
	var scene := load("res://assets/medaka.glb") as PackedScene
	if scene == null:
		push_error("[FishDemo] Could not load GLB — check the file path.")
		return

	_mesh_instance = scene.instantiate()

	# ← Adjust scale until the fish looks right in your scene
	_mesh_instance.scale = Vector3(150.0, 150.0, 150.0)

	# Fix orientation — find the mesh/armature node and rotate it.
	# Open the GLB in the editor to find the exact node name.
	# ← Update "Madeka fish" to match the node name inside your GLB
	var fish_node := _mesh_instance.find_child("Madeka fish") as Node3D
	if fish_node:
		fish_node.rotation_degrees = Vector3(90, 90, 90)
	else:
		push_warning("[FishDemo] Armature node not found — check the node name.")

	# Find the AnimationPlayer and play the first animation on loop
	_anim = _mesh_instance.find_child("AnimationPlayer") as AnimationPlayer
	if _anim:
		var anim_name := _anim.get_animation_list()[0]
		print("[FishDemo] Playing animation: ", anim_name)
		_anim.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
		_anim.play(anim_name)
	else:
		push_warning("[FishDemo] AnimationPlayer not found.")

	add_child(_mesh_instance)


func _process(delta: float) -> void:
	_behave(delta)
	if _mesh_instance:
		_mesh_instance.position += _velocity * delta


func _behave(delta: float) -> void:
	# Read cultural values and accumulate their influence
	var playfulness  := 0.0
	var persistence  := 0.0
	var restraint    := 0.0

	for v in values:
		playfulness += v.playfulness
		persistence += v.persistence
		restraint   += v.restraint

	# Playfulness — joyful, wandering movement
	_phase += delta * (1.0 + playfulness * 2.0)
	var wander := Vector3(
		sin(_phase * 0.7) * playfulness * 10.0,
		sin(_phase * 0.3) * playfulness * 3.0,
		cos(_phase * 1.1) * playfulness * 10.0
	)

	# Persistence — holds a steady upstream course
	var upstream := Vector3(0.0, 0.0, -1.0) * persistence * 20.0

	# Restraint — slows overall movement
	var speed_limit: float = lerp(30.0, 5.0, restraint)

	# Soft boundary — pull back toward origin when too far
	var fish_pos := _mesh_instance.position if _mesh_instance else Vector3.ZERO
	var dist := fish_pos.length()
	var home := Vector3.ZERO
	if dist > 80.0:
		home = -fish_pos.normalized() * (dist - 80.0) * 0.5

	_velocity = (wander + upstream + home).limit_length(speed_limit)
