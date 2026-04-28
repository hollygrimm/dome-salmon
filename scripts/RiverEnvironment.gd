## RiverEnvironment.gd
## Manages all environmental elements: water surface, riverbed,
## lighting, underwater fog, and particle systems.
##
## Scene setup (add as child of Main, or as its own scene):
##
##   RiverEnvironment (Node3D)  ← this script
##   ├── WaterSurface (MeshInstance3D)
##   ├── Riverbed (MeshInstance3D)
##   ├── SunLight (DirectionalLight3D)
##   ├── AmbientFill (DirectionalLight3D)
##   ├── WorldEnvironment
##   └── BubbleParticles (GPUParticles3D)   ← optional, add later

extends Node3D

# --- Node references (set in _ready via find_child or @onready) ---
@onready var water_surface: MeshInstance3D   = $WaterSurface
@onready var riverbed: MeshInstance3D        = $Riverbed
@onready var sun_light: DirectionalLight3D   = $SunLight
@onready var world_env: WorldEnvironment     = $WorldEnvironment

# --- Configuration ---
@export var river_width: float  = 28.0
@export var river_length: float = 60.0
@export var water_depth: float  = 3.5   # distance from surface to bed

# --- Cycle color ramp (Salmon Afterlives) ---
## Match SalmonSchool.run_duration_sec so the warmth shift is in lock-step
## with the spawning-flank ramp on the salmon body.
## See docs/specs/2026-04-27-cycle-color-ramp-design.md.
@export var run_duration_sec: float = 180.0
@export var water_shallow_start: Color = Color(0.18, 0.42, 0.48, 0.72)  # cool teal
@export var water_shallow_end:   Color = Color(0.45, 0.30, 0.30, 0.72)  # warm rose-grey
@export var caustic_tint_start:  Color = Color(0.40, 0.75, 0.80, 1.0)   # cool blue
@export var caustic_tint_end:    Color = Color(0.85, 0.55, 0.30, 1.0)   # warm amber

# Turbulence driven by ParameterBank — water reacts to performer energy
var _turbulence: float = 0.2


func _ready() -> void:
	_build_water_surface()
	_build_riverbed()
	_setup_lighting()
	_setup_environment()


func _process(_delta: float) -> void:
	# Blend turbulence toward swim_urgency + evasion_drive
	var target_turb : float = clamp(
		ParameterBank.swim_urgency * 0.6 + ParameterBank.evasion_drive * 0.4,
		0.05, 1.0
	)
	_turbulence = lerp(_turbulence, target_turb, 0.03)
	_update_shader_params()


# --- Build geometry ---

func _build_water_surface() -> void:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(river_width, river_length)
	mesh.subdivide_width  = 24   # enough verts for wave displacement
	mesh.subdivide_depth  = 48
	water_surface.mesh = mesh

	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/water_surface.gdshader")
	# Generate a simple noise texture procedurally
	mat.set_shader_parameter("noise_tex", _make_noise_texture())
	water_surface.material_override = mat

	# Position: just above the salmon school center
	water_surface.position = Vector3(0.0, 1.8, 0.0)


func _build_riverbed() -> void:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(river_width * 1.2, river_length * 1.1)
	mesh.subdivide_width = 8
	mesh.subdivide_depth = 12
	riverbed.mesh = mesh

	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/riverbed.gdshader")
	mat.set_shader_parameter("noise_tex", _make_noise_texture())
	riverbed.material_override = mat

	# Position: below the salmon school
	riverbed.position = Vector3(0.0, -(water_depth - 1.8), 0.0)


# --- Lighting ---

func _setup_lighting() -> void:
	# Main sun: warm, angled as if through water surface
	sun_light.light_color     = Color(1.0, 0.92, 0.78)
	sun_light.light_energy    = 1.4
	sun_light.shadow_enabled  = true
	sun_light.rotation_degrees = Vector3(-55.0, -30.0, 0.0)

	# Subtle underwater blue-green fill from below
	# (simulates light bouncing off riverbed)
	var fill := DirectionalLight3D.new()
	fill.name = "AmbientFill"
	fill.light_color  = Color(0.3, 0.6, 0.65)
	fill.light_energy = 0.25
	fill.rotation_degrees = Vector3(70.0, 15.0, 0.0)
	fill.shadow_enabled = false
	add_child(fill)


# --- Environment / Fog ---

func _setup_environment() -> void:
	var env := Environment.new()

	# Sky: deep water blue-green gradient
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color    = Color(0.04, 0.12, 0.22)
	sky_mat.sky_horizon_color = Color(0.15, 0.38, 0.45)
	sky_mat.ground_bottom_color = Color(0.08, 0.14, 0.10)
	sky_mat.ground_horizon_color = Color(0.12, 0.28, 0.25)
	sky_mat.sun_angle_max = 30.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.sky = sky
	env.background_mode = Environment.BG_SKY

	# Underwater fog
	env.fog_enabled    = true
	env.fog_light_color = Color(0.08, 0.25, 0.32)
	env.fog_density    = 0.04
	env.fog_depth_begin = 2.0
	env.fog_depth_end  = 35.0

	# Subtle glow for bioluminescence / light shafts feel
	env.glow_enabled   = true
	env.glow_intensity = 0.3
	env.glow_bloom     = 0.1

	# Color correction: slight cool/teal grade for underwater
	env.adjustment_enabled    = true
	env.adjustment_saturation = 1.15
	env.adjustment_contrast   = 1.05

	world_env.environment = env


# --- Dynamic shader updates ---

func _update_shader_params() -> void:
	# Wall-clock cycle amount, shared with SalmonSchool's spawn-color ramp.
	var elapsed := Time.get_ticks_msec() * 0.001
	var cycle_amount := clampf(elapsed / run_duration_sec, 0.0, 1.0)

	if water_surface and water_surface.material_override:
		var mat := water_surface.material_override as ShaderMaterial
		mat.set_shader_parameter("turbulence", _turbulence)
		# Wave speed increases with urgency
		mat.set_shader_parameter("wave_speed",
			lerp(0.3, 1.2, ParameterBank.swim_urgency))
		mat.set_shader_parameter("water_shallow",
			water_shallow_start.lerp(water_shallow_end, cycle_amount))

	if riverbed and riverbed.material_override:
		var mat := riverbed.material_override as ShaderMaterial
		mat.set_shader_parameter("turbulence", _turbulence)
		mat.set_shader_parameter("caustic_tint",
			caustic_tint_start.lerp(caustic_tint_end, cycle_amount))

	# Sun flickers slightly during evasion (predator shadow)
	if sun_light:
		sun_light.light_energy = lerp(1.4, 0.9,
			ParameterBank.evasion_drive * 0.5)


# --- Noise texture generator ---
# Creates a simple Value Noise texture at runtime — no external image needed.

func _make_noise_texture() -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.noise_type   = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency    = 0.025
	noise.fractal_octaves = 4
	noise.fractal_gain = 0.5

	var tex := NoiseTexture2D.new()
	tex.width   = 512
	tex.height  = 512
	tex.seamless = true
	tex.noise    = noise
	return tex
