## FleeBehavior.gd — Shawn's contribution to dome-salmon
##
## Ports the deer-flees-from-lion pattern from Shawn's 2D desert ecosystem
## (sp26-csat201-godot-solivar/scripts/Deer2D.gd:14-30) into a per-fish
## flee force for dome-salmon.
##
## In his own project: each Deer2D checked its distance to the nearest
## Mountain Lion. If within a `flee_radius` scaled by a cultural cohesion
## value, the deer velocity flipped to an "away from predator" vector.
##
## In dome-salmon the logic is the same, but the threat is configurable.
## Could be a fishing boat, a disturbance zone, a hazard — or (if Keanu's
## PlayerFish lands in the same build) the viewer's hero fish itself.
##
## ─── CONTRACT ──────────────────────────────────────────────────────────────
## Implement `flee_force(fish_position, threats) -> Vector3`.
##
## Inputs:
##   fish_position — this fish's world-space position (Vector3)
##   threats       — array of world-space Vector3 positions of threats
##                   (may be empty; SalmonSchool passes it from Main.gd)
##
## Return:
##   A Vector3 force to ADD into this fish's steering. Zero vector if
##   no threat is close enough.
##
## Rules:
##   - The force should point AWAY from the closest threat (or blended
##     away-from-all).
##   - Force magnitude should scale with proximity — the closer the
##     threat, the stronger the push.
##   - Clamp magnitude to avoid exploding the boid integration. Stay
##     under ~4.0 m/s² equivalent.
##   - Your function must be O(n_threats). n_threats is small (≤ 5).
##   - Must be pure — no state, no mutation.
##
## Your extraction target:
##   Deer2D.gd lines 22-30:
##     var flee_radius: float = lerp(80.0, 200.0, clamp(cohesion, 0.0, 1.0))
##     var lion := _nearest_predator()
##     if lion != null and position.distance_to(lion.position) < flee_radius:
##       var away := (position - lion.position).normalized()
##       velocity = away * 180.0 * (1.0 - restraint * 0.3)
##
## Changes needed:
##   - Vector2 → Vector3 (just use x/y/z, no Y stripping necessary — fish
##     can also flee vertically)
##   - Units shrink: your 80–200 pixel radius becomes ~3–8 meters
##   - Return a force, not a velocity override
## ───────────────────────────────────────────────────────────────────────────

class_name FleeBehavior

const MAX_FORCE: float = 4.0


## Replace this stub with your flee logic.
## Default returns Vector3.ZERO (no flee force, school ignores threats).
static func flee_force(fish_position: Vector3, threats: Array) -> Vector3:
	# TODO (Shawn): implement the flee force here.
	#
	# Example sketch — adapt the distance thresholds and magnitudes:
	#
	#   if threats.is_empty():
	#     return Vector3.ZERO
	#
	#   var nearest: Vector3 = threats[0]
	#   var nearest_dist := fish_position.distance_to(nearest)
	#   for t in threats:
	#     var d := fish_position.distance_to(t)
	#     if d < nearest_dist:
	#       nearest = t
	#       nearest_dist = d
	#
	#   var flee_radius := 6.0  # metres (tune this)
	#   if nearest_dist > flee_radius:
	#     return Vector3.ZERO
	#
	#   var away := (fish_position - nearest).normalized()
	#   var urgency := 1.0 - (nearest_dist / flee_radius)  # 0..1
	#   var force := away * urgency * MAX_FORCE
	#   return force
	return Vector3.ZERO
