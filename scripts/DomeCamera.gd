# DomeCamera.gd
# Attaches to a Camera3D that is a child of a PathFollow3D node.
# Rides a Path3D tracing the river upstream, with configurable
# height/depth offset and soft look-ahead / look-at-salmon targeting.
#
# Scene tree expected:
#   Path3D  (drawn tracing river, upstream = progress 0 → 1)
#   └─ PathFollow3D
#      └─ Camera3D  ← attach this script here
#
# Usage:
#   1. Draw your Path3D along the river channel, tip-to-tail upstream.
#   2. Add PathFollow3D as child; set Rotation Mode = Oriented.
#   3. Add Camera3D as child of PathFollow3D.
#   4. Attach this script to Camera3D.
#   5. In the Inspector, set camera_mode, travel_speed, and optionally
#      assign salmon_flock (a Node3D whose global_position is the
#      centroid of your boid flock).

class_name DomeCamera
extends Camera3D

## ── Exported parameters ─────────────────────────────────────────────────────

enum CameraMode {
	DRONE,      ## Aerial, looking downstream-and-down along the river
	UNDERWATER, ## Below water surface, looking upstream and slightly up
	SALMON_POV  ## Soft lock-on to the salmon flock centroid
}

@export var camera_mode: CameraMode = CameraMode.UNDERWATER

## Travel speed along the path (0 = stationary, 1 = full path per second)
@export_range(0.0, 0.5, 0.001) var travel_speed: float = 0.012

## Pause travel when within this distance of a salmon cluster
@export var pause_near_salmon: bool = false
@export_range(1.0, 30.0, 0.5) var pause_distance: float = 8.0

## Height offset above/below the PathFollow3D origin (+ = above water)
@export var height_offset: float = 3.5      # DRONE default; set negative for UNDERWATER

## Forward offset: how far ahead of PathFollow3D origin the camera sits
@export var forward_offset: float = 0.0

## How far ahead of current position to look (0 = look at path direction)
@export_range(0.0, 20.0, 0.5) var look_ahead_distance: float = 6.0

## Smoothing for all camera rotations (lower = lazier)
@export_range(0.01, 1.0, 0.01) var rotation_smoothing: float = 0.06

## Optional: assign the centroid node of your salmon flock for SALMON_POV
@export var salmon_flock: Node3D = null

## How strongly the camera pulls toward the salmon flock (SALMON_POV mode)
@export_range(0.0, 1.0, 0.01) var flock_pull_strength: float = 0.35

## Loop the path when it reaches the end
@export var loop_path: bool = true

## ── Internal state ──────────────────────────────────────────────────────────

var _path_follow: PathFollow3D
var _target_basis: Basis
var _current_basis: Basis
var _paused: bool = false

## ── Lifecycle ───────────────────────────────────────────────────────────────

func _ready() -> void:
	_path_follow = get_parent() as PathFollow3D
	if _path_follow == null:
		push_error("DomeCamera must be a child of a PathFollow3D node.")
		return

	_apply_mode_defaults()
	_current_basis = global_transform.basis
	_target_basis = _current_basis


func _process(delta: float) -> void:
	if _path_follow == null:
		return

	# ── 1. Advance along path ────────────────────────────────────────────────
	_paused = false
	if pause_near_salmon and salmon_flock != null:
		var dist = global_position.distance_to(salmon_flock.global_position)
		if dist < pause_distance:
			_paused = true

	if not _paused:
		_path_follow.progress_ratio += travel_speed * delta
		if loop_path and _path_follow.progress_ratio >= 1.0:
			_path_follow.progress_ratio = 0.0

	# ── 2. Position offset (height + forward) ────────────────────────────────
	# PathFollow3D handles the path-tangent orientation; we shift in local space.
	position = Vector3(forward_offset, height_offset, 0.0)

	# ── 3. Compute target look direction ─────────────────────────────────────
	var look_target: Vector3

	match camera_mode:
		CameraMode.DRONE:
			look_target = _look_ahead_point() + Vector3.DOWN * 1.2

		CameraMode.UNDERWATER:
			look_target = _look_ahead_point() + Vector3.UP * 0.6

		CameraMode.SALMON_POV:
			if salmon_flock != null:
				var flock_pos = salmon_flock.global_position
				var ahead_pos = _look_ahead_point()
				# Blend between path look-ahead and flock centroid
				look_target = ahead_pos.lerp(flock_pos, flock_pull_strength)
			else:
				look_target = _look_ahead_point()

	# ── 4. Smooth rotation toward target ─────────────────────────────────────
	var desired_transform = global_transform.looking_at(look_target, Vector3.UP)
	_target_basis = desired_transform.basis
	_current_basis = _current_basis.slerp(_target_basis, rotation_smoothing)
	global_transform = Transform3D(_current_basis, global_transform.origin)


## ── Helpers ─────────────────────────────────────────────────────────────────

## Returns a world-space point look_ahead_distance units ahead on the path.
func _look_ahead_point() -> Vector3:
	if _path_follow == null:
		return global_position + global_transform.basis.z * -look_ahead_distance

	var path: Path3D = _path_follow.get_parent() as Path3D
	if path == null or path.curve == null:
		return global_position + global_transform.basis.z * -look_ahead_distance

	var curve_length: float = path.curve.get_baked_length()
	if curve_length <= 0.0:
		return global_position

	var ahead_ratio: float = clamp(
		_path_follow.progress_ratio + (look_ahead_distance / curve_length),
		0.0, 1.0
	)
	# Sample curve in local path space, then convert to world space
	var local_pt: Vector3 = path.curve.sample_baked(ahead_ratio * curve_length)
	return path.global_transform * local_pt


## Apply sensible height defaults per mode so first run looks reasonable.
## Assumes the Path3D sits at y=0 (riverbed "spine"), water surface at y≈1.8.
func _apply_mode_defaults() -> void:
	match camera_mode:
		CameraMode.DRONE:
			if height_offset == 3.5:   # only if user hasn't changed it
				height_offset = 5.0
		CameraMode.UNDERWATER:
			if height_offset == 3.5:
				height_offset = -1.0   # low in the channel, looking up at the school
		CameraMode.SALMON_POV:
			if height_offset == 3.5:
				height_offset = 0.3    # roughly at salmon swimming depth


## ── Public API ──────────────────────────────────────────────────────────────

## Switch modes at runtime (e.g. from a DomeSensor trigger).
func set_mode(mode: CameraMode) -> void:
	camera_mode = mode
	_apply_mode_defaults()


## Teleport to a specific point on the path (0.0 – 1.0).
func seek(ratio: float) -> void:
	if _path_follow:
		_path_follow.progress_ratio = clamp(ratio, 0.0, 1.0)


## Temporarily boost travel speed (useful for a "current surge" event).
func surge(speed_multiplier: float, duration: float) -> void:
	var original_speed = travel_speed
	travel_speed *= speed_multiplier
	await get_tree().create_timer(duration).timeout
	travel_speed = original_speed
