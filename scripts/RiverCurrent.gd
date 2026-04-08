# RiverCurrent.gd
# Generates a 2D flow field (in the XZ river plane) from:
#   - A Path3D defining the main channel centerline
#   - A list of Obstacle resources (rocks, log jams, placed deadfall)
#   - A health_factor (0.0–1.0) encoding river condition by year
#
# The flow field is sampled by Salmon boids each frame via:
#   RiverCurrent.sample(world_position) -> Vector3
#
# Physics modeled:
#   1. Main channel flow  — follows path tangent, faster in narrows
#   2. Meander geometry   — helical secondary flow in bends (slower on inside)
#   3. Pool / eddy zones  — low-velocity recirculation downstream of bends
#   4. Obstacle wakes     — von-Kármán vortex streets behind rocks/debris
#   5. River health       — degraded geometry straightens flow, reduces habitat
#
# Scene tree:
#   RiverCurrent (Node3D)  ← attach this script
#   └─ (no required children; reads Path3D and obstacles via export vars)
#
# Usage:
#   var flow = $RiverCurrent.sample(global_position)
#   velocity += flow * current_influence * delta

class_name RiverCurrent
extends Node3D

# ── Obstacle resource ────────────────────────────────────────────────────────

class Obstacle:
	var position: Vector3      # world position of obstacle center
	var radius: float          # physical radius (m)
	var drag: float            # how much it slows flow (0–1)
	var vortex_strength: float # amplitude of shed vortices

	func _init(pos: Vector3, r: float = 1.2, d: float = 0.7, vs: float = 1.0) -> void:
		position = pos
		radius = r
		drag = d
		vortex_strength = vs

# ── Exports ──────────────────────────────────────────────────────────────────

## The Path3D tracing the river centerline (upstream = progress 0→1)
@export var river_path: Path3D

## Base flow speed in metres/second at full health
@export_range(0.1, 5.0, 0.05) var base_speed: float = 1.4

## Channel half-width in metres
@export_range(1.0, 30.0, 0.5) var channel_half_width: float = 8.0

## River health this year (1.0 = pre-degradation, 0.0 = channelised/logged)
## Drive this from your yearly spawner data normalised 0–1
@export_range(0.0, 1.0, 0.01) var health_factor: float = 1.0

## Meander amplitude multiplier (healthy rivers curve more)
@export_range(0.0, 2.0, 0.05) var meander_amplitude: float = 1.0

## Strength of vortex shedding behind obstacles
@export_range(0.0, 2.0, 0.05) var vortex_strength_global: float = 1.0

## Visualise the flow field in the editor (expensive — disable for performance)
@export var debug_draw: bool = false
@export_range(2, 20, 1) var debug_grid_size: int = 8

# ── Internal state ───────────────────────────────────────────────────────────

var _obstacles: Array[Obstacle] = []
var _time: float = 0.0
var _baked_length: float = 0.0

# ── Closest-point grid cache ─────────────────────────────────────────────────
# At _ready() we sample _closest_point_on_path_linear() across a 2D grid in XZ
# world space. Subsequent sample() calls become O(1) cell lookups instead of
# a 120-step linear scan, which is critical when 100+ fish each query the
# field multiple times per frame.

const GRID_COLS: int = 64
const GRID_ROWS: int = 128

var _grid_origin: Vector2 = Vector2.ZERO  # world XZ of cell (0,0) corner
var _grid_cell: Vector2 = Vector2.ONE     # cell size in world units
var _grid_inv_cell: Vector2 = Vector2.ONE
var _path_cache_point: PackedVector3Array
var _path_cache_tangent: PackedVector3Array
var _path_cache_t: PackedFloat32Array
var _grid_baked: bool = false

# ── Lifecycle ────────────────────────────────────────────────────────────────

func _ready() -> void:
	if river_path and river_path.curve:
		_baked_length = river_path.curve.get_baked_length()
	_build_default_obstacles()
	_bake_path_cache()


func _process(delta: float) -> void:
	_time += delta
	if debug_draw:
		_draw_debug_field()


# ── Public API ───────────────────────────────────────────────────────────────

## Primary sample point. Returns a world-space velocity vector.
## Call this from Salmon._process() each frame.
func sample(world_pos: Vector3) -> Vector3:
	# Channel flow is preserved at full strength regardless of health.
	# Secondary, pool, and wake components scale with habitat quality —
	# degraded rivers lose their meander structure and recirculation zones.
	var channel := _channel_flow(world_pos)
	var habitat_scale := lerpf(0.25, 1.0, health_factor)
	var secondary := _meander_secondary(world_pos) * habitat_scale
	var pool := _pool_recirculation(world_pos) * habitat_scale
	var wake := _obstacle_wakes(world_pos) * habitat_scale
	return channel + secondary + pool + wake


## Add an obstacle at runtime (e.g. placed deadfall from restoration data)
func add_obstacle(pos: Vector3, radius: float = 1.2,
		drag: float = 0.7, vortex: float = 1.0) -> void:
	_obstacles.append(Obstacle.new(pos, radius, drag, vortex))


## Remove all obstacles and rebuild defaults
func clear_obstacles() -> void:
	_obstacles.clear()


## Set health from normalised spawner count (call from SalmonRun year loop)
## raw_count: actual spawner number   max_count: historical max (e.g. 32071)
func set_health_from_count(raw_count: int, max_count: int = 32071) -> void:
	health_factor = clamp(float(raw_count) / float(max_count), 0.0, 1.0)
	# Degrade meander geometry in low-health years (logged / channelised)
	meander_amplitude = lerpf(0.3, 1.0, health_factor)


# ── Flow components ──────────────────────────────────────────────────────────

## 1. Main channel flow — follows path tangent, magnitude varies with
##    cross-channel distance (faster in thalweg, slow near banks)
func _channel_flow(world_pos: Vector3) -> Vector3:
	if river_path == null or river_path.curve == null:
		return Vector3.ZERO

	var closest := _closest_point_on_path(world_pos)
	var tangent: Vector3 = closest.tangent  # upstream direction
	var lateral_dist: float = closest.lateral_dist
	var t: float = closest.t  # 0–1 along path

	# Cross-channel speed profile: parabolic, fastest at centre
	var lateral_norm := lateral_dist / channel_half_width
	var speed_profile: float = maxf(0.0, 1.0 - lateral_norm * lateral_norm)

	# Speed increases in high-curvature sections (narrows / riffles)
	var curvature := _path_curvature(t)
	var riffle_boost := 1.0 + curvature * 0.6 * health_factor

	var speed: float = base_speed * speed_profile * riffle_boost
	return tangent * speed  # tangent points upstream (Path3D progress 0→1)


## 2. Meander secondary flow — helical cross-current in bends.
##    On the outside of a bend water piles up; inside it slows.
##    Models the centrifugal force that creates point bars and cut banks.
func _meander_secondary(world_pos: Vector3) -> Vector3:
	if river_path == null:
		return Vector3.ZERO

	var closest := _closest_point_on_path(world_pos)
	var curvature := _path_curvature(closest.t)
	if curvature < 0.01:
		return Vector3.ZERO

	# Bend direction: cross product of tangent and up gives inward normal
	var inward := closest.tangent.cross(Vector3.UP).normalized()
	# Lateral signed distance: negative = inside of bend, positive = outside
	var lateral_signed := closest.lateral_signed

	# Secondary current pushes toward inside near surface, outside at depth
	# Simplified: surface flow tilts inward on outside of bend
	var secondary_speed: float = curvature * base_speed * 0.35 * meander_amplitude
	var direction: Vector3 = -inward * signf(lateral_signed)

	return direction * secondary_speed


## 3. Pool / eddy recirculation — slow counter-rotating flow in meander pools.
##    Pools form on the inside of bends; eddies form downstream of obstacles.
##    Salmon use these as rest zones between upstream pushes.
func _pool_recirculation(world_pos: Vector3) -> Vector3:
	if river_path == null:
		return Vector3.ZERO

	var closest := _closest_point_on_path(world_pos)
	var curvature := _path_curvature(closest.t)

	# Pool zone: inside of bend (lateral_signed < 0), high curvature
	if curvature < 0.08 or closest.lateral_signed > 0:
		return Vector3.ZERO

	var pool_depth := (-closest.lateral_signed / channel_half_width)
	pool_depth = clamp(pool_depth, 0.0, 1.0)

	# Recirculation: gentle counter-flow (back downstream) in pool interior
	var recirculation_speed := curvature * base_speed * 0.4 * pool_depth
	# Pool flow opposes main channel (returns slightly downstream)
	var recirculation := -closest.tangent * recirculation_speed

	# Add slow rotational component — the eddy spin
	var spin_axis := Vector3.UP
	var spin := closest.tangent.cross(spin_axis).normalized()
	recirculation += spin * recirculation_speed * 0.5

	return recirculation * health_factor  # pools disappear in degraded rivers


## 4. Von-Kármán vortex streets behind obstacles.
##    Each obstacle sheds alternating vortices at a frequency proportional
##    to flow speed / obstacle diameter (Strouhal number ≈ 0.2).
##    Salmon synchronise tail beats with this frequency (Kármán gait).
func _obstacle_wakes(world_pos: Vector3) -> Vector3:
	var total := Vector3.ZERO

	for obs in _obstacles:
		var to_obs := world_pos - obs.position
		var dist := to_obs.length()

		# Only affects wake zone (downstream cone behind obstacle)
		var obs_upstream := _channel_flow(obs.position).normalized()
		var downstream_proj := to_obs.dot(-obs_upstream)  # + = downstream of obs

		if downstream_proj < 0.0 or dist > obs.radius * 18.0:
			continue

		# Wake width grows downstream
		var wake_width := obs.radius * (1.0 + downstream_proj * 0.15)
		var lateral_to_wake := to_obs - obs_upstream * -downstream_proj
		var lateral_dist_wake := lateral_to_wake.length()

		if lateral_dist_wake > wake_width * 2.0:
			continue

		# Strouhal vortex shedding frequency
		var flow_speed := _channel_flow(obs.position).length()
		var strouhal_freq := (flow_speed * 0.2) / (obs.radius * 2.0)
		var phase := _time * strouhal_freq * TAU

		# Alternating vortex: sign flips with downstream distance
		var vortex_sign: float = signf(sin(phase + downstream_proj * 0.8))

		# Vortex velocity: rotational, perpendicular to wake axis
		var vortex_dir: Vector3 = obs_upstream.cross(Vector3.UP).normalized() * vortex_sign
		var strength := obs.vortex_strength * vortex_strength_global
		var falloff := exp(-lateral_dist_wake / wake_width)
		var wake_falloff := exp(-downstream_proj / (obs.radius * 12.0))

		total += vortex_dir * strength * falloff * wake_falloff * 0.6

	return total


# ── Path geometry helpers ─────────────────────────────────────────────────────

class ClosestPointResult:
	var point: Vector3
	var tangent: Vector3
	var t: float            # 0–1 along path
	var lateral_dist: float # unsigned distance from centerline
	var lateral_signed: float # signed: negative = inside bend


## Find closest point on river path. Routes to the O(1) grid cache when baked,
## falls back to the linear scan otherwise (used during the bake itself and
## when world_pos lies outside the grid bounds).
func _closest_point_on_path(world_pos: Vector3) -> ClosestPointResult:
	if not _grid_baked:
		return _closest_point_on_path_linear(world_pos)

	var fx: float = (world_pos.x - _grid_origin.x) * _grid_inv_cell.x
	var fz: float = (world_pos.z - _grid_origin.y) * _grid_inv_cell.y
	var ix: int = int(fx)
	var iz: int = int(fz)
	if ix < 0 or ix >= GRID_COLS or iz < 0 or iz >= GRID_ROWS:
		return _closest_point_on_path_linear(world_pos)

	var idx: int = ix * GRID_ROWS + iz
	var result := ClosestPointResult.new()
	result.point = _path_cache_point[idx]
	result.tangent = _path_cache_tangent[idx]
	result.t = _path_cache_t[idx]
	# Lateral distances are recomputed per-call from the actual world_pos.
	# Only the path-derived data (point, tangent, t) is cached, since those
	# are the expensive parts and depend only on grid cell.
	result.lateral_dist = world_pos.distance_to(result.point)
	var to_pos := world_pos - result.point
	var right := result.tangent.cross(Vector3.UP)
	result.lateral_signed = to_pos.dot(right)
	return result


## Build the closest-point grid cache. Called once from _ready().
func _bake_path_cache() -> void:
	if river_path == null or river_path.curve == null:
		return
	var curve := river_path.curve

	# Compute path AABB in world XZ
	var min_x := INF
	var max_x := -INF
	var min_z := INF
	var max_z := -INF
	var samples := 64
	for i in samples + 1:
		var local_pt := curve.sample_baked(float(i) / float(samples) * _baked_length)
		var world_pt: Vector3 = river_path.to_global(local_pt)
		min_x = minf(min_x, world_pt.x)
		max_x = maxf(max_x, world_pt.x)
		min_z = minf(min_z, world_pt.z)
		max_z = maxf(max_z, world_pt.z)

	# Pad bounds so fish near the banks still hit cached cells
	var margin: float = channel_half_width * 2.5
	min_x -= margin; max_x += margin
	min_z -= margin; max_z += margin

	_grid_origin = Vector2(min_x, min_z)
	_grid_cell = Vector2(
		(max_x - min_x) / float(GRID_COLS),
		(max_z - min_z) / float(GRID_ROWS)
	)
	_grid_inv_cell = Vector2(1.0 / _grid_cell.x, 1.0 / _grid_cell.y)

	var total: int = GRID_COLS * GRID_ROWS
	_path_cache_point.resize(total)
	_path_cache_tangent.resize(total)
	_path_cache_t.resize(total)

	for ix in GRID_COLS:
		for iz in GRID_ROWS:
			var wx: float = _grid_origin.x + (float(ix) + 0.5) * _grid_cell.x
			var wz: float = _grid_origin.y + (float(iz) + 0.5) * _grid_cell.y
			var raw := _closest_point_on_path_linear(Vector3(wx, 0.0, wz))
			var idx: int = ix * GRID_ROWS + iz
			_path_cache_point[idx] = raw.point
			_path_cache_tangent[idx] = raw.tangent
			_path_cache_t[idx] = raw.t

	_grid_baked = true
	print("[RiverCurrent] Baked %d×%d closest-point grid (%d cells)" % [GRID_COLS, GRID_ROWS, total])


## Linear-scan implementation. Used by the bake step and as fallback.
func _closest_point_on_path_linear(world_pos: Vector3) -> ClosestPointResult:
	var result := ClosestPointResult.new()
	if river_path == null or river_path.curve == null:
		result.point = world_pos
		result.tangent = Vector3.FORWARD
		result.t = 0.0
		result.lateral_dist = 0.0
		result.lateral_signed = 0.0
		return result

	var curve := river_path.curve
	var path_local := river_path.to_local(world_pos)

	# Sample baked points to find closest
	var closest_dist := INF
	var closest_offset := 0.0
	var step := _baked_length / 120.0

	var offset := 0.0
	while offset <= _baked_length:
		var pt := curve.sample_baked(offset)
		var d := pt.distance_to(path_local)
		if d < closest_dist:
			closest_dist = d
			closest_offset = offset
		offset += step

	# Refine with smaller step around closest
	var refine_start: float = maxf(0.0, closest_offset - step)
	var refine_end: float = minf(_baked_length, closest_offset + step)
	var fine_step := step / 20.0
	offset = refine_start
	while offset <= refine_end:
		var pt := curve.sample_baked(offset)
		var d := pt.distance_to(path_local)
		if d < closest_dist:
			closest_dist = d
			closest_offset = offset
		offset += fine_step

	result.t = closest_offset / _baked_length if _baked_length > 0 else 0.0

	# Tangent in world space (upstream = positive progress direction).
	# Curve3D's sample_baked_with_rotation returns a basis where -Z is forward
	# along the curve, matching PathFollow3D ORIENTED convention.
	var tangent_local := -curve.sample_baked_with_rotation(closest_offset).basis.z
	result.tangent = river_path.global_transform.basis * tangent_local
	result.tangent = result.tangent.normalized()

	result.point = river_path.to_global(curve.sample_baked(closest_offset))
	result.lateral_dist = world_pos.distance_to(result.point)

	# Signed lateral: negative = inside bend (left when facing upstream)
	var to_pos := (world_pos - result.point)
	var right := result.tangent.cross(Vector3.UP)
	result.lateral_signed = to_pos.dot(right)

	return result


## Approximate curvature at normalised position t (0–1).
## Returns a 0–1 value where 1 = tight bend.
func _path_curvature(t: float) -> float:
	if river_path == null or river_path.curve == null:
		return 0.0

	var curve := river_path.curve
	var delta := 0.02
	var t0: float = clampf(t - delta, 0.0, 1.0)
	var t1: float = clampf(t + delta, 0.0, 1.0)

	var p0 := curve.sample_baked(t0 * _baked_length)
	var p1 := curve.sample_baked(t * _baked_length)
	var p2 := curve.sample_baked(t1 * _baked_length)

	var v0 := (p1 - p0).normalized()
	var v1 := (p2 - p1).normalized()
	var angle_change := v0.angle_to(v1)

	return clamp(angle_change / (delta * 2.0 * PI), 0.0, 1.0)


# ── Default obstacle placement ────────────────────────────────────────────────

## Scatter plausible obstacles along the path.
## In production, replace with actual Coquille River obstacle data.
func _build_default_obstacles() -> void:
	if river_path == null or river_path.curve == null:
		return

	var curve := river_path.curve
	# Place obstacles at intervals, offset from centerline
	var placements := [
		{"offset": 0.12, "lateral":  3.2, "r": 1.5, "vs": 1.2},  # riffle rock
		{"offset": 0.18, "lateral": -2.8, "r": 0.9, "vs": 0.9},
		{"offset": 0.31, "lateral":  4.5, "r": 2.1, "vs": 1.5},  # large boulder
		{"offset": 0.38, "lateral": -1.8, "r": 0.8, "vs": 0.8},
		{"offset": 0.47, "lateral":  2.0, "r": 1.8, "vs": 1.1},  # log jam
		{"offset": 0.55, "lateral": -3.5, "r": 1.4, "vs": 1.3},
		{"offset": 0.63, "lateral":  1.5, "r": 0.7, "vs": 0.7},
		{"offset": 0.72, "lateral": -2.2, "r": 1.6, "vs": 1.0},
		{"offset": 0.80, "lateral":  3.8, "r": 2.4, "vs": 1.6},  # restoration deadfall
		{"offset": 0.88, "lateral": -1.2, "r": 1.0, "vs": 0.9},
	]

	for p in placements:
		var p_offset: float = p["offset"]
		var p_lateral: float = p["lateral"]
		var p_r: float = p["r"]
		var p_vs: float = p["vs"]
		var path_pt := curve.sample_baked(p_offset * _baked_length)
		var world_pt := river_path.to_global(path_pt)
		# Offset laterally from centerline
		var tangent_local := -curve.sample_baked_with_rotation(
				p_offset * _baked_length).basis.z
		var tangent_world := river_path.global_transform.basis * tangent_local
		var right := tangent_world.cross(Vector3.UP).normalized()
		world_pt += right * p_lateral
		add_obstacle(world_pt, p_r, 0.65, p_vs)


# ── Debug visualisation ───────────────────────────────────────────────────────

func _draw_debug_field() -> void:
	if not river_path:
		return
	# Sample a grid around the river and draw velocity arrows
	# Uses DebugDraw3D if available, otherwise just prints
	var curve := river_path.curve
	var step := _baked_length / float(debug_grid_size)
	var offset := 0.0
	while offset <= _baked_length:
		var pt := river_path.to_global(curve.sample_baked(offset))
		var laterals: Array[float] = [-channel_half_width * 0.6, 0.0, channel_half_width * 0.6]
		for lateral in laterals:
			var tangent_local := -curve.sample_baked_with_rotation(offset).basis.z
			var tangent_world := river_path.global_transform.basis * tangent_local
			var right := tangent_world.cross(Vector3.UP).normalized()
			var sample_pt: Vector3 = pt + right * lateral + Vector3.UP * 0.5
			var _flow := sample(sample_pt)
			# If DebugDraw3D plugin is present:
			# DebugDraw3D.draw_arrow(sample_pt, sample_pt + flow * 0.5, Color.CYAN, 0.1)
		offset += step
