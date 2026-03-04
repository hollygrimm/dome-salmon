## SalmonSchool.gd
## Attach to a MultiMeshInstance3D node.
## Manages a boids simulation for hundreds of salmon,
## writing transforms to the MultiMesh buffer each frame.
##
## Scene setup:
##   MultiMeshInstance3D
##     └── [this script]
##   The MultiMesh resource is created in code — no manual setup needed.

extends MultiMeshInstance3D

# --- Configuration (edit in Inspector) ---
@export var fish_count: int = 300
@export var spawn_volume: Vector3 = Vector3(20.0, 4.0, 40.0)  # width, height, depth
@export var upstream_direction: Vector3 = Vector3(0, 0, -1)   # -Z = upstream

# --- Boids weights (tunable) ---
@export var weight_separation: float = 1.8
@export var weight_alignment:  float = 1.0
@export var weight_cohesion:   float = 0.8
@export var weight_upstream:   float = 1.2

# --- Internal state ---
var _positions: PackedVector3Array
var _velocities: PackedVector3Array
var _phases: PackedFloat32Array   # per-fish undulation phase offset


func _ready() -> void:
	_init_multimesh()
	_spawn_fish()


func _init_multimesh() -> void:
	# Build MultiMesh resource programmatically
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count = fish_count
	# Mesh: use a simple capsule as placeholder until salmon.glb is imported
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.08
	mesh.height = 0.5
	mm.mesh = mesh
	multimesh = mm


func _spawn_fish() -> void:
	_positions  = PackedVector3Array()
	_velocities = PackedVector3Array()
	_phases     = PackedFloat32Array()

	for i in fish_count:
		var pos := Vector3(
			randf_range(-spawn_volume.x * 0.5, spawn_volume.x * 0.5),
			randf_range(-spawn_volume.y * 0.5, spawn_volume.y * 0.5),
			randf_range(-spawn_volume.z * 0.5, spawn_volume.z * 0.5)
		)
		_positions.append(pos)
		# Initial velocity: mostly upstream with small random spread
		_velocities.append(upstream_direction * 1.5 + Vector3(
			randf_range(-0.3, 0.3),
			randf_range(-0.1, 0.1),
			randf_range(-0.3, 0.3)
		))
		_phases.append(randf() * TAU)


func _process(delta: float) -> void:
	_update_boids(delta)
	_write_transforms()


func _update_boids(delta: float) -> void:
	var speed       := ParameterBank.school_speed
	var sep_radius  := ParameterBank.separation_radius
	var coh_radius  := sep_radius * 3.0
	var up_force    := ParameterBank.upstream_force
	var cohesion_w  : float = lerp(weight_cohesion, weight_cohesion * 2.5,
							ParameterBank.school_cohesion)
	var evasion     := ParameterBank.evasion_drive
	var rest        := ParameterBank.rest_factor
	var vert_energy := ParameterBank.vertical_energy

	for i in fish_count:
		var pos := _positions[i]
		var vel := _velocities[i]

		var sep_force   := Vector3.ZERO
		var align_force := Vector3.ZERO
		var coh_center  := Vector3.ZERO
		var neighbor_count := 0

		# Neighbor scan — O(n²), fine for 300 fish at 60fps on Mac Studio
		for j in fish_count:
			if i == j:
				continue
			var diff := pos - _positions[j]
			var dist := diff.length()
			if dist < sep_radius and dist > 0.001:
				sep_force += diff.normalized() / dist
			if dist < coh_radius:
				align_force += _velocities[j]
				coh_center  += _positions[j]
				neighbor_count += 1

		var steering := Vector3.ZERO
		steering += sep_force * weight_separation

		if neighbor_count > 0:
			align_force  = (align_force / neighbor_count).normalized()
			coh_center   = coh_center / neighbor_count
			var to_center := (coh_center - pos).normalized()
			steering += align_force * weight_alignment
			steering += to_center  * cohesion_w

		# Upstream bias
		steering += upstream_direction * up_force * weight_upstream

		# Evasion: add perpendicular swirl
		if evasion > 0.1:
			var swirl := Vector3(sin(Time.get_ticks_msec() * 0.002 + _phases[i]),
								 0.0,
								 cos(Time.get_ticks_msec() * 0.002 + _phases[i]))
			steering += swirl * evasion * 2.0

		# Vertical energy: occasional upward burst (leaping)
		if vert_energy > 0.5 and randf() < vert_energy * 0.01:
			vel.y += vert_energy * 3.0

		# Gravity / depth return
		vel.y -= 0.5 * delta

		# Rest: dampen velocity
		if rest > 0.1:
			vel = vel.lerp(Vector3.ZERO, rest * delta * 2.0)

		# Integrate
		vel = vel.lerp(vel + steering * delta, 0.15)

		# Clamp to max speed
		if vel.length() > speed:
			vel = vel.normalized() * speed

		pos += vel * delta

		# Soft boundary — push back toward spawn volume center
		pos.x = _soft_clamp(pos.x, spawn_volume.x * 0.5)
		pos.y = _soft_clamp(pos.y, spawn_volume.y * 0.5)
		pos.z = _soft_clamp(pos.z, spawn_volume.z * 0.5)

		_positions[i]  = pos
		_velocities[i] = vel


func _write_transforms() -> void:
	for i in fish_count:
		var vel := _velocities[i]
		if vel.length_squared() < 0.0001:
			continue
		# Orient fish along velocity (nose points in direction of travel)
		var basis := Basis.looking_at(vel.normalized(), Vector3.UP)
		var t := Transform3D(basis, _positions[i])
		multimesh.set_instance_transform(i, t)


func _soft_clamp(value: float, half_extent: float) -> float:
	var margin := half_extent * 0.2
	var inner  := half_extent - margin
	if absf(value) > inner:
		return value + (-sign(value) * (absf(value) - inner) * 0.3)
	return value
