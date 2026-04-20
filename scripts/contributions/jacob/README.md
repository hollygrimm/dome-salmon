# Jacob's contribution — BehaviorMode

**File:** `BehaviorMode.gd`

## What this does

Adds a per-fish state machine to the salmon school — WANDER ↔ SEEK_UPSTREAM
— modeled directly on the OBSERVING ↔ CARING pattern in your desert
ecosystem Person.gd. Each frame, each fish evaluates a condition, picks a
mode, and the forces acting on that fish scale accordingly.

## How it's wired into dome-salmon

`SalmonSchool.gd` calls your functions per fish per frame:

```gdscript
var mode := BehaviorMode.mode_for(i, river_progress, elapsed)
var scale := BehaviorMode.force_scale(mode)
upstream_bias *= scale["upstream"]
cohesion_w   *= scale["cohesion"]
max_speed    *= scale["speed"]
```

If both functions return neutral defaults, the school behaves as before.

## Your job

1. Open `BehaviorMode.gd`.
2. Decide the condition for the WANDER → SEEK_UPSTREAM transition.
   Candidates: `river_progress > 0.6`, time-based (`elapsed_seconds > 30`),
   a mix, or something you invent.
3. Decide the per-mode force scaling. WANDER should feel relaxed (low
   upstream, higher cohesion, slower speed). SEEK_UPSTREAM should feel
   urgent (high upstream, looser cohesion, faster speed).
4. Replace both stubs.

## Testing

Both functions are pure — test them in isolation:
- Call `BehaviorMode.mode_for(0, 0.3, 5.0)` and verify it returns the
  mode you expect
- Call `BehaviorMode.force_scale(BehaviorMode.Mode.WANDER)` and confirm
  the dict has the keys and values you intend

## When you're done

Open a PR titled `Add Jacob contribution: BehaviorMode`. In the PR body,
explain (a) what triggers the transition and why, and (b) what the school
should *look like* in each mode.
