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
@export var spawn_volume: Vector3 = Vector3(20.0, 3.0, 60.0)  # width, height, depth (Z matches river length)
@export var spawn_center_y: float = 0.05  # centers school in water column (surface=1.8, bed=-1.7)
@export var spawn_center_z: float = 0.0  # 0 = river center; range = [-30, +30] with spawn_volume.z=60
@export var upstream_direction: Vector3 = Vector3(0, 0, -1)   # -Z = upstream

# --- Boids weights (tunable) ---
@export var weight_separation: float = 1.8
@export var weight_alignment:  float = 1.0
@export var weight_cohesion:   float = 0.8
@export var weight_upstream:   float = 1.2
@export var fish_scale:          float = 0.25          # scale each fish instance — adjust for GLB models
@export var fish_rotation_offset: Vector3 = Vector3(0, 180, 0)  # degrees — LowPolySalmonv2 raw-mesh axis fix: Z180 rolls belly down, X90 lays nose forward

# --- Student contribution wiring (Week 15 residency) ---
# Each CSAT201 student contributes one file under scripts/contributions/.
# Uncomment each hook as its PR lands. If a contribution doesn't arrive in
# time, leave the hook commented — the school runs fine without it.
#
# See docs/CONTRIBUTING.md and scripts/contributions/{name}/README.md.
@export var enable_ticoh_schooling: bool = false   # SchoolingBehavior modulator
@export var enable_jacob_mode: bool = false        # BehaviorMode state machine
@export var enable_shawn_flee: bool = true         # FleeBehavior per-fish force
## Threats for Shawn's flee behavior (rocks, boats, disturbance zones).
## Main.gd maintains this list; can be empty.
var threats: Array = []

# --- River current coupling (set by Main.gd at runtime) ---
## RiverCurrent node providing flow-field samples. Optional — boids fall
## back to pure upstream bias when null.
var river_current: RiverCurrent = null
## Flow contribution to steering. Note: steering is treated as acceleration
## while flow is velocity (m/s), so values above ~0.3 will dominate the
## boid forces and collapse the school. 0.15 is a gentle directional bias.
@export_range(0.0, 2.0, 0.01) var current_influence: float = 0.15
@export_range(0.0, 2.0, 0.05) var karman_gait_sensitivity: float = 0.4
## How much the upstream bias is dampened when fish is in an eddy (pool holding).
## Only the upstream component is dampened — separation/cohesion are preserved.
@export_range(0.0, 1.0, 0.05) var pool_rest_factor: float = 0.85

# --- Internal state ---
var _positions: PackedVector3Array
var _velocities: PackedVector3Array
var _phases: PackedFloat32Array      # per-fish undulation phase offset
var _flee_states: PackedByteArray    # per-fish hysteresis flag for FleeBehavior


func _ready() -> void:
	_init_multimesh()
	_spawn_fish()


func _init_multimesh() -> void:
	# Build MultiMesh resource programmatically
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count = fish_count

	# Try to load salmon.glb — fall back to capsule if not present
	var mesh: Mesh = _load_fish_mesh()

	# Apply salmon body shader
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/salmon_body.gdshader")
	mat.set_shader_parameter("base_color", Color(0.72, 0.58, 0.52, 1.0))
	mat.set_shader_parameter("belly_color", Color(0.88, 0.82, 0.76, 1.0))
	mat.set_shader_parameter("spawn_color", Color(0.78, 0.18, 0.12, 1.0))
	mat.set_shader_parameter("undulation_speed", 3.5)
	mat.set_shader_parameter("undulation_amplitude", 0.06)
	mat.set_shader_parameter("wave_frequency", 1.5)
	for s in mesh.get_surface_count():
		mesh.surface_set_material(s, mat)

	mm.mesh = mesh
	multimesh = mm


func _load_fish_mesh() -> Mesh:
	# Look for salmon.glb in assets/ — swap in Ashley's model when ready.
	# Falls back to capsule placeholder if the file isn't there yet.
	var scene := load("res://assets/salmon.glb") as PackedScene
	if scene:
		var temp := scene.instantiate()
		var mesh_instance := _find_mesh_instance(temp)
		
		if mesh_instance:
			var mesh := mesh_instance.mesh.duplicate() as Mesh
			temp.free()
			print("[SalmonSchool] Loaded salmon.glb")
			return mesh
		temp.free()
		push_warning("[SalmonSchool] salmon.glb loaded but no MeshInstance3D found inside.")

	# Fallback
	print("[SalmonSchool] salmon.glb not found — using capsule placeholder.")
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.08
	capsule.height = 0.5
	return capsule


func _find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var result := _find_mesh_instance(child)
		if result:
			return result
	return null


func _spawn_fish() -> void:
	_positions   = PackedVector3Array()
	_velocities  = PackedVector3Array()
	_phases      = PackedFloat32Array()
	_flee_states = PackedByteArray()

	for i in fish_count:
		var pos := Vector3(
			randf_range(-spawn_volume.x * 0.5, spawn_volume.x * 0.5),
			spawn_center_y,
			spawn_center_z + randf_range(-spawn_volume.z * 0.5, spawn_volume.z * 0.5)
		)
		var y_offset := randf_range(-spawn_volume.y * 0.5, spawn_volume.y * 0.5)
		pos.y = spawn_center_y + _soft_clamp(y_offset, spawn_volume.y * 0.5)
		_positions.append(pos)
		# Initial velocity: mostly upstream with small random spread
		_velocities.append(upstream_direction * 1.5 + Vector3(
			randf_range(-0.3, 0.3),
			randf_range(-0.1, 0.1),
			randf_range(-0.3, 0.3)
		))
		_phases.append(randf() * TAU)
		_flee_states.append(0)


func _process(delta: float) -> void:
	_update_boids(delta)
	_write_transforms()


func _update_boids(delta: float) -> void:
	var speed       : float = ParameterBank.school_speed
	var sep_radius  : float = ParameterBank.separation_radius
	var coh_radius  : float = sep_radius * 3.0
	var up_force    : float = ParameterBank.upstream_force
	var cohesion_w  : float = lerp(weight_cohesion, weight_cohesion * 2.5,
							ParameterBank.school_cohesion)
	var evasion     : float = ParameterBank.evasion_drive
	var rest        : float = ParameterBank.rest_factor
	var vert_energy : float = ParameterBank.vertical_energy

	for i in fish_count:
		var pos := _positions[i]
		var vel := _velocities[i]
		var mode_speed_scale := 1.0  # updated below if Jacob's mode is enabled

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

			# Ticoh's contribution: per-fish cohesion weight modulator.
			# See scripts/contributions/ticoh/SchoolingBehavior.gd
			var ticoh_mod := 1.0
			if enable_ticoh_schooling:
				ticoh_mod = SchoolingBehavior.cohesion_weight(i, _phases[i], delta)
			steering += to_center * cohesion_w * ticoh_mod

		# Upstream bias — accumulated separately so pool-holding can dampen
		# *only* this component without nuking separation/cohesion forces.
		var upstream_bias := upstream_direction * up_force * weight_upstream

		# Jacob's contribution: per-fish behavior mode (WANDER ↔ SEEK_UPSTREAM).
		# See scripts/contributions/jacob/BehaviorMode.gd
		if enable_jacob_mode:
			var river_progress: float = clamp(
				(spawn_center_z + spawn_volume.z * 0.5 - pos.z) / spawn_volume.z,
				0.0, 1.0)
			var elapsed: float = Time.get_ticks_msec() * 0.001
			var mode: int = BehaviorMode.mode_for(i, river_progress, elapsed)
			var scale: Dictionary = BehaviorMode.force_scale(mode)
			upstream_bias *= scale.get("upstream", 1.0)
			mode_speed_scale = scale.get("speed", 1.0)

		# Shawn's contribution: flee force when threats are nearby.
		# See scripts/contributions/shawn/FleeBehavior.gd
		if enable_shawn_flee and not threats.is_empty():
			var fleeing := bool(_flee_states[i])
			# Update hysteresis state before passing to flee_force
			var nearest_threat_dist := INF
			for t in threats:
				nearest_threat_dist = minf(nearest_threat_dist, pos.distance_to(t))
			if fleeing:
				if nearest_threat_dist > FleeBehavior.FLEE_RADIUS * FleeBehavior.FLEE_STOP_MULTIPLIER:
					fleeing = false
			else:
				if nearest_threat_dist < FleeBehavior.FLEE_RADIUS:
					fleeing = true
			_flee_states[i] = int(fleeing)
			steering += FleeBehavior.flee_force(pos, threats, fleeing)

		# River current — flow field drift, Kármán gait, pool resting
		if river_current != null:
			var flow := river_current.sample(pos)
			steering += flow * current_influence

			# Kármán gait: when flow has strong rotational component (vortex
			# wake behind a rock), tail-beat syncs to vortex frequency and
			# extracts energy from the street. Net cost approaches zero.
			var curl := _estimate_flow_curl(pos, flow)
			if curl > 0.15:
				steering += flow * karman_gait_sensitivity * curl

			# Pool holding: if local flow opposes upstream direction, fish is
			# in an eddy — dampen the active upstream urge so it stages there.
			if flow.dot(upstream_direction) < -0.1:
				upstream_bias *= (1.0 - pool_rest_factor)

		steering += upstream_bias

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

		# Clamp to max speed (scaled by Jacob's per-fish mode if enabled)
		var effective_speed: float = speed * mode_speed_scale
		if vel.length() > effective_speed:
			vel = vel.normalized() * effective_speed

		pos += vel * delta

		# Soft boundary — push back toward spawn volume center
		pos.x = _soft_clamp(pos.x, spawn_volume.x * 0.5)
		pos.y = spawn_center_y + _soft_clamp(pos.y - spawn_center_y, spawn_volume.y * 0.5)
		# No Z soft-clamp — fish exit upstream and respawn at the downstream end
		# (treadmill loop). Without this, 300 fish pile against the headwaters wall.
		var upstream_end: float = spawn_center_z - spawn_volume.z * 0.5
		var downstream_end: float = spawn_center_z + spawn_volume.z * 0.5
		if pos.z < upstream_end:
			pos.z = downstream_end
			pos.x = randf_range(-spawn_volume.x * 0.5, spawn_volume.x * 0.5)
			pos.y = spawn_center_y + randf_range(
					-spawn_volume.y * 0.4, spawn_volume.y * 0.4)
			vel = upstream_direction * 1.5 + Vector3(
					randf_range(-0.3, 0.3),
					randf_range(-0.1, 0.1),
					randf_range(-0.3, 0.3))

		_positions[i]  = pos
		_velocities[i] = vel


func _write_transforms() -> void:
	for i in fish_count:
		var vel := _velocities[i]
		if vel.length_squared() < 0.0001:
			continue
		# Orient fish along the horizontal projection of velocity, so accumulated
		# Y-velocity from gravity doesn't constantly pitch the school nose-down.
		# Apply scale and mesh rotation correction.
		var correction := Basis.from_euler(fish_rotation_offset * (PI / 180.0))
		var horiz := Vector3(vel.x, 0.0, vel.z)
		if horiz.length_squared() < 0.0001:
			horiz = upstream_direction
		var fish_basis := Basis.looking_at(horiz.normalized(), Vector3.UP) * correction
		fish_basis = fish_basis.scaled(Vector3(fish_scale, fish_scale, fish_scale))
		var t := Transform3D(fish_basis, _positions[i])
		multimesh.set_instance_transform(i, t)


## Cheap XZ-plane curl estimate. Compares flow at two small offsets to detect
## rotational structure (vortex street). Returns |curl_y|.
func _estimate_flow_curl(pos: Vector3, flow_at_center: Vector3) -> float:
	if river_current == null:
		return 0.0
	var offset := 0.4
	var flow_dx := river_current.sample(pos + Vector3(offset, 0.0, 0.0))
	var flow_dz := river_current.sample(pos + Vector3(0.0, 0.0, offset))
	var curl_y := ((flow_dz.x - flow_at_center.x) / offset) \
				- ((flow_dx.z - flow_at_center.z) / offset)
	return absf(curl_y)


func _soft_clamp(value: float, half_extent: float) -> float:
	var margin := half_extent * 0.2
	var inner  := half_extent - margin
	if absf(value) > inner:
		return value + (-sign(value) * (absf(value) - inner) * 0.3)
	return value
