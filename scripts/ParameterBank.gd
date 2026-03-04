## ParameterBank.gd
## Central store of named behavioral parameters driven by OSC.
## Sits between OSCReceiver (raw UDP) and the simulation (boids, shaders).
##
## Add as Autoload: Project > Project Settings > Autoload > ParameterBank
##
## Any script in the project can read:
##   ParameterBank.swim_urgency
##   ParameterBank.school_cohesion
##   etc.

extends Node

# --- Behavioral Parameters ---
# All values normalized to [0.0, 1.0] unless noted.

## How fast/urgently the school moves upstream. Driven by performer 1.
var swim_urgency: float = 0.3

## How tightly the school clusters (0=dispersed, 1=tight ball). Performer 2.
var school_cohesion: float = 0.5

## Tendency to leap / depth of school in water column. Performer 3.
var vertical_energy: float = 0.0

## Predator evasion intensity — triggers spiral/burst behavior. Performer 4.
var evasion_drive: float = 0.0

## Resting / stillness — fish slow and hold in eddies. Performer 5.
var rest_factor: float = 0.0

# --- Derived parameters (computed each frame) ---
## Overall school speed in world units/sec
var school_speed: float = 2.0

## Boids separation radius in world units
var separation_radius: float = 1.2

## Upstream bias force magnitude
var upstream_force: float = 1.0


func _process(_delta: float) -> void:
	_read_from_osc()
	_derive_parameters()


func _read_from_osc() -> void:
	# OSCReceiver is an Autoload — read its smoothed params
	swim_urgency   = OSCReceiver.get_param("/performer/1/velocity")
	school_cohesion = OSCReceiver.get_param("/performer/2/lateral")
	vertical_energy = OSCReceiver.get_param("/performer/3/vertical")
	evasion_drive   = OSCReceiver.get_param("/performer/4/rotation")
	rest_factor     = OSCReceiver.get_param("/performer/5/stillness")


func _derive_parameters() -> void:
	# School speed: base 1.5 m/s, urgency adds up to 4x
	school_speed = lerp(1.5, 6.0, swim_urgency)

	# Separation: loosen when evasion is high (school disperses in panic)
	separation_radius = lerp(0.8, 2.5, evasion_drive)

	# Upstream force: reduced by rest, amplified by urgency
	upstream_force = lerp(0.2, 3.0, swim_urgency) * (1.0 - rest_factor * 0.7)


# --- Debug helper ---
## Call from a Label node in your debug UI to display current state.
func debug_string() -> String:
	return (
		"swim_urgency: %.2f\n" % swim_urgency +
		"school_cohesion: %.2f\n" % school_cohesion +
		"vertical_energy: %.2f\n" % vertical_energy +
		"evasion_drive: %.2f\n" % evasion_drive +
		"rest_factor: %.2f\n" % rest_factor +
		"--- derived ---\n" +
		"school_speed: %.2f m/s\n" % school_speed +
		"separation_r: %.2f\n" % separation_radius +
		"upstream_f: %.2f\n" % upstream_force
	)
