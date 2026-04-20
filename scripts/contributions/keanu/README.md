# Keanu's contribution — PlayerFish

**File:** `PlayerFish.gd`

## What this does

Adds a single viewer-controlled salmon that swims alongside the school.
WASD moves in the river plane, up/down keys handle vertical movement.
Ports directly from your own repo's `PlayerFish.gd`.

DomeCamera already has a `SALMON_POV` mode — once your PlayerFish is
spawned, it can be assigned to `DomeCamera.salmon_flock` and the camera
will soft-track it automatically. No new camera code needed on your side.

## How it's wired into dome-salmon

`Main.gd` spawns one PlayerFish after the school is built:

```gdscript
var player := preload("res://scripts/contributions/keanu/PlayerFish.gd").new()
player.position = Vector3(0.0, 0.0, 10.0)  # downstream of the school
add_child(player)

# Point DomeCamera at it
dome_camera.salmon_flock = player
dome_camera.set_mode(DomeCamera.CameraMode.SALMON_POV)
```

## Your job

1. Open `PlayerFish.gd`.
2. Replace the `_read_input()` stub with your WASD + up/down logic.
   You have the exact pattern already in your sp26-csat201-godot-KeanuBegay
   PlayerFish.gd — copy it over.
3. Verify the six input actions exist in `project.godot`:
   `move_left`, `move_right`, `move_forward`, `move_back`, `move_up`,
   `move_down`. If they don't, add them via Project Settings → Input Map.
   **Commit the `project.godot` changes too.**

## Testing

Open dome-salmon in Godot, open `scenes/Main.tscn`, press F5. You should
see the school running as before plus your hero salmon responding to WASD.
If you can't run dome-salmon locally, test in a scratch scene: add a
PlayerFish as the root, press F5, verify the capsule moves.

## When you're done

Open a PR titled `Add Keanu contribution: PlayerFish`. Include the input
map changes in the same PR. In the body, mention which keys do what so
reviewers know how to test.
