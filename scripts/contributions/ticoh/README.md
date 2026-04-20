# Ticoh's contribution — SchoolingBehavior

**File:** `SchoolingBehavior.gd`

## What this does

Modulates the boid cohesion weight per fish, so the school tightens or
loosens depending on a value you choose. Ports your pilot-fish cohesion
→ orbit-radius pattern from your own Godot project into the dome-salmon
MultiMesh boid loop.

## How it's wired into dome-salmon

`SalmonSchool.gd` calls `SchoolingBehavior.cohesion_weight(i, phase, delta)`
once per fish per frame, multiplying the result into the cohesion force:

```gdscript
var ticoh_mod := SchoolingBehavior.cohesion_weight(i, _phases[i], delta)
steering += to_center * cohesion_w * ticoh_mod
```

If your function returns `1.0`, the school behaves as before. Return
`> 1.0` to tighten, `< 1.0` to loosen.

## Your job

1. Open `SchoolingBehavior.gd`.
2. Replace the `return 1.0` stub with your logic.
3. Use the `lerp(..., cohesion_value)` pattern from your fish.gd lines 21–52.
4. Keep your function O(1) — it runs 300× per frame.

## Testing

You can't run dome-salmon locally (it needs the OSC/dome setup), but your
function is pure GDScript. Test it in isolation by calling it from a
simple `_ready()` in any Godot scene and printing the return value for
varied inputs.

## When you're done

Open a PR titled `Add Ticoh contribution: SchoolingBehavior`. Include a
one-paragraph description in the PR body explaining what your modulator
does and why you chose the range you chose.
