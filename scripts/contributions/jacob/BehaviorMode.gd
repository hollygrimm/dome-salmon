## BehaviorMode.gd — per-fish WANDER ↔ SEEK_UPSTREAM state-machine contract.
## Originally contributed by Jacob Crazy Bull during CSAT201,
## Institute of American Indian Arts, Spring 2026.
##
## Ports the OBSERVING ↔ CARING state-machine pattern from Jacob's desert
## ecosystem Person.gd (sp26-csat201-godot-JacobCrazyBull/scripts/Person.gd)
## into a per-fish behavior mode for dome-salmon.
##
## In his own project: a Person switched between OBSERVING (drifting, watching)
## and CARING (actively tending plants) based on a threshold over an
## environmental count and a cultural `care` value. Same skeleton here, but
## the modes are salmon-appropriate: WANDER ↔ SEEK_UPSTREAM.
##
## WANDER        — relaxed cohesion, slow pace, fish holds in place
## SEEK_UPSTREAM — strong upstream force, higher speed, fish pushes on
##
## The mode transition happens when some condition crosses a threshold.
## In Jacob's Person.gd the condition was `plant_count < threshold`. For
## salmon, plausible conditions: distance to spawning headwaters, river
## health, time elapsed, a performer parameter from OSC. You pick.
##
## ─── CONTRACT ──────────────────────────────────────────────────────────────
## Implement two functions:
##
##   mode_for(fish_index, river_progress, elapsed_seconds) -> int
##     Returns an enum value: Mode.WANDER (0) or Mode.SEEK_UPSTREAM (1).
##     inputs:
##       fish_index       — which fish (0 to fish_count - 1)
##       river_progress   — this fish's 0.0 (estuary) → 1.0 (headwaters)
##                          normalized distance along the river
##       elapsed_seconds  — seconds since the scene started
##
##   force_scale(mode) -> Dictionary
##     Returns scaling factors for three forces, as a dict:
##       { "upstream": 1.0, "cohesion": 1.0, "speed": 1.0 }
##     1.0 = neutral. > 1.0 amplifies. 0.0 cancels. Stay in [0.0, 2.5].
##
## Rules:
##   - DO NOT mutate shared state. Both functions are pure.
##   - DO NOT call into Main.gd, ParameterBank, or other singletons.
##   - Both functions must be O(1).
##
## Your extraction target:
##   Lines 24-67 of your Person.gd. The key pattern is:
##     enum Mode { OBSERVING, CARING }
##     var threshold := 5 if care > 0.5 else 3
##     if plant_count < threshold:
##       mode = Mode.CARING
##     else:
##       mode = Mode.OBSERVING
##     match mode:
##       Mode.OBSERVING: ...
##       Mode.CARING: ...
## ───────────────────────────────────────────────────────────────────────────

class_name BehaviorMode

enum Mode { WANDER, SEEK_UPSTREAM }


## Replace this stub with your threshold logic.
## Default returns WANDER for all fish, all the time.
static func mode_for(fish_index: int, river_progress: float, elapsed_seconds: float) -> int:
	# TODO (Jacob): implement your state transition here.
	#
	# Example sketch — change the condition and threshold:
	#   if river_progress < 0.6:
	#     return Mode.WANDER          # early in the journey, fish holds
	#   else:
	#     return Mode.SEEK_UPSTREAM   # closer to headwaters, push on
	#
	# Or use elapsed_seconds for a time-based transition. Or combine both.
	return Mode.WANDER


## Replace this stub with your per-mode force scaling.
## Default returns neutral (all 1.0) for every mode.
static func force_scale(mode: int) -> Dictionary:
	# TODO (Jacob): implement your per-mode scaling here.
	#
	# Example sketch:
	#   match mode:
	#     Mode.WANDER:
	#       return { "upstream": 0.3, "cohesion": 1.4, "speed": 0.6 }
	#     Mode.SEEK_UPSTREAM:
	#       return { "upstream": 1.8, "cohesion": 0.7, "speed": 1.3 }
	return { "upstream": 1.0, "cohesion": 1.0, "speed": 1.0 }
