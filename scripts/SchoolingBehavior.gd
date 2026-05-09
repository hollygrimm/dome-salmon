## SchoolingBehavior.gd — per-fish cohesion modulation.
## Originally contributed by Ticoh Japp during CSAT201,
## Institute of American Indian Arts, Spring 2026.
##
## Ports the cohesion → orbit-radius pattern from Ticoh's pilot-fish ecosystem
## (sp26-csat201-godot-ticohj/scripts/fish.gd:21-52) into dome-salmon's
## MultiMesh boid loop.
##
## In her own project: each fish orbited around an imaginary center at a
## radius controlled by its cultural `cohesion` value. Tighter cohesion,
## smaller radius. That same logic here becomes a *cohesion-weight modulator*
## — a per-fish multiplier that tightens the school when cultural values
## point that way.
##
## ─── CONTRACT ──────────────────────────────────────────────────────────────
## Implement `cohesion_weight(fish_index, phase, delta,
##                            cultural_cohesion, cultural_playfulness) -> float`.
##
## Inputs:
##   fish_index           — which fish in the school (0 to fish_count - 1)
##   phase                — per-fish phase offset in [0, TAU); already randomized
##   delta                — frame time in seconds
##   cultural_cohesion    — averaged `cohesion` across SalmonSchool.values, in
##                          [0.0, 1.0]. Drives the school's baseline tightness.
##   cultural_playfulness — averaged `playfulness` across SalmonSchool.values, in
##                          [0.0, 1.0]. Scales per-fish personality variation:
##                          0.0 = uniform/disciplined school, 1.0 = erratic school.
##
## Return:
##   A non-negative multiplier. 1.0 = neutral (no change).
##   > 1.0 tightens the school (stronger pull toward neighbors).
##   < 1.0 loosens the school.
##
## Rules:
##   - DO NOT read or write positions/velocities. Your function returns a
##     scalar, not a force. SalmonSchool.gd multiplies the cohesion weight
##     by your scalar.
##   - DO NOT call into Main.gd, ParameterBank, or other singletons.
##   - Your function must be O(1) — it runs 300× per frame.
##
## Your extraction target:
##   Lines 21-52 of your fish.gd. The inner pattern is:
##     var radius: float = lerp(2.5, 0.8, clamp(cohesion, 0.0, 1.0))
##   Here you'll produce a *weight* instead of a radius, but the same lerp
##   idea applies — map your cultural value to a number in some range.
## ───────────────────────────────────────────────────────────────────────────

class_name SchoolingBehavior

static func cohesion_weight(_fish_index: int, phase: float, _delta: float, cultural_cohesion: float, cultural_playfulness: float) -> float:
	var personality := (sin(phase) * 0.5 + 0.5) * cultural_playfulness
	return lerp(0.8, 1.6, clamp(cultural_cohesion + personality, 0.0, 1.0))
