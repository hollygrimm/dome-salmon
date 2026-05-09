## FleeBehavior.gd — per-fish flee force from threats, with hysteresis.
## Originally contributed by Shawn Olivar during CSAT201,
## Institute of American Indian Arts, Spring 2026.
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
##   Deer2D.gd lines 55-68:
##     var flee_radius: float = lerp(80.0, 200.0, clamp(cohesion, 0.0, 1.0))
##     var lion := _nearest_predator()
##     var dist := _wrapped_dist(lion.position) if lion != null else INF
##
##     # Hysteresis: start fleeing at flee_radius, stop only at 1.4x that distance
##     if lion != null and dist < flee_radius:
##         _fleeing = true
##     elif dist > flee_radius * 1.4:
##         _fleeing = false
##
##     if _fleeing and lion != null:
##         var away := _wrapped_away(lion.position)   # wrap-corrected direction
##         velocity = away * 180.0 * (1.0 - restraint * 0.3)
##
## Changes needed:
##   - Vector2 → Vector3 (fish can also flee vertically — no Y stripping needed)
##   - Units shrink: your 80–200 pixel radius becomes ~3–8 meters
##   - Return a force, not a velocity override
##   - No world-wrapping in 3D, so use plain (fish_pos - threat).normalized()
##   - Port the hysteresis: add a flee_stop_multiplier (default 1.4) so fish
##     don't oscillate in and out of flee state at the boundary
## ───────────────────────────────────────────────────────────────────────────

class_name FleeBehavior

const MAX_FORCE: float = 4.0

## Radius at which fleeing begins (metres — scaled down from Deer2D's 80–200 px)
const FLEE_RADIUS: float = 6.0
## Hysteresis multiplier: fleeing stops only when distance exceeds this × FLEE_RADIUS
const FLEE_STOP_MULTIPLIER: float = 1.4

static func flee_force(fish_position: Vector3, threats: Array, is_fleeing: bool) -> Vector3:

	if threats.is_empty():
		return Vector3.ZERO

	var nearest: Vector3 = threats[0]
	var nearest_dist := fish_position.distance_to(nearest)
	for t in threats:
		var d := fish_position.distance_to(t)
		if d < nearest_dist:
			nearest = t
			nearest_dist = d

	var stop_radius := FLEE_RADIUS * FLEE_STOP_MULTIPLIER
	var threshold := stop_radius if is_fleeing else FLEE_RADIUS
	if nearest_dist > threshold:
		return Vector3.ZERO

	var away := (fish_position - nearest).normalized()
	var urgency := 1.0 - (nearest_dist / FLEE_RADIUS)  # 0..1
	return away * clamp(urgency, 0.0, 1.0) * MAX_FORCE
