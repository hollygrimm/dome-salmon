# Integration TODOs

Deferred wiring tasks for after student PRs land. Not blocking Week 15
handoff — the contribution hooks in `SalmonSchool.gd` default to off, so
the school runs fine without these.

## Keanu — PlayerFish spawn in Main.gd

When Keanu's PR lands and `PlayerFish.gd` is implemented, add to
`Main.gd._ready()` after `_build_dome_camera()`:

```gdscript
# Spawn the viewer-controlled hero salmon
var player := preload("res://scripts/contributions/keanu/PlayerFish.gd").new()
player.position = Vector3(0.0, 0.0, 10.0)  # downstream of the school spawn
add_child(player)

# Point DomeCamera at it (soft-track via existing SALMON_POV mode)
dome_camera.salmon_flock = player
dome_camera.set_mode(DomeCamera.CameraMode.SALMON_POV)
```

Also verify the six input actions are committed to `project.godot`:
`move_left`, `move_right`, `move_forward`, `move_back`, `move_up`,
`move_down`. Keanu's PR should include them.

## Shawn — threats list wiring in Main.gd

When Shawn's PR lands and `FleeBehavior.gd` is implemented, populate
`SalmonSchool.threats` so the flee force has something to react to.

Simplest first test — a single static rock:

```gdscript
var school := $SalmonSchool as MultiMeshInstance3D
if school:
    school.set("threats", [Vector3(3.0, 0.0, 0.0)])
```

More interesting — use Keanu's PlayerFish as a moving threat (if both
contributions land). Update each frame in `Main._process()`:

```gdscript
if player and school:
    school.set("threats", [player.global_position])
```

This creates a viewer-as-threat dynamic: where the hero salmon goes,
the school scatters. Discuss with Ashley before enabling — it may or
may not fit the residency narrative.

## Toggle order for first dome test

Once PRs are landing, enable in this order from `Main.tscn`'s
SalmonSchool node:

1. Ticoh's `enable_ticoh_schooling` — lowest-risk, just modulates a
   weight. Verify school still looks cohesive.
2. Jacob's `enable_jacob_mode` — affects pacing and feel. Verify
   school still reaches the headwaters.
3. Shawn's `enable_shawn_flee` — needs threats array populated (above).
4. Keanu's PlayerFish — spawned separately, always active once wired.

Each one can be toggled off in isolation if something regresses.
