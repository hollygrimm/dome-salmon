## SchoolingBehavior.gd — Ticoh's contribution to dome-salmon
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
## Implement `cohesion_weight(fish_index, phase, delta) -> float`.
##
## Inputs:
##   fish_index — which fish in the school (0 to fish_count - 1)
##   phase      — per-fish phase offset in [0, TAU); already randomized
##   delta      — frame time in seconds
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


## Replace this stub with your logic. Default returns 1.0 (neutral).
static func cohesion_weight(fish_index: int, phase: float, delta: float) -> float:
	# TODO (Ticoh): implement your cohesion modulator here.
	#
	# Example sketch — feel free to change the values and math:
	#   var cohesion_value := 0.6  # eventually read from a cultural source
	#   return lerp(0.8, 1.6, clamp(cohesion_value, 0.0, 1.0))
	#
	# Optional: use `phase` to add subtle per-fish variation so not every
	# fish responds identically (your original fish.gd used phase for this).
	return 1.0
