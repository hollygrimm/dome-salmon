# Shawn's contribution — FleeBehavior

**File:** `FleeBehavior.gd`

## What this does

Adds a flee force to each salmon when a threat is nearby. Ports the
deer-flees-from-mountain-lion logic from your 2D desert ecosystem
(Deer2D.gd) into 3D, as a pure force function that slots into the boid
steering loop.

The "threat" is just a list of Vector3 positions that Main.gd supplies.
In the first integration, it'll be a single static rock position. Later
it can be a disturbance event, a boat, or (if Keanu's PlayerFish lands)
the viewer's hero fish.

## How it's wired into dome-salmon

`Main.gd` maintains a `threats: Array[Vector3]` and passes it to
SalmonSchool each frame. SalmonSchool adds your force into steering:

```gdscript
var flee := FleeBehavior.flee_force(pos, threats)
steering += flee
```

If your function returns `Vector3.ZERO`, the school behaves as before.

## Your job

1. Open `FleeBehavior.gd`.
2. Replace the stub with your flee logic. The example sketch in the
   docstring is close to what you need — start there.
3. Tune the `flee_radius` for world scale (meters, not pixels). ~5–8 m
   is reasonable for 300 fish in a ~60 m river.

## Testing

Pure function — test it in isolation:

```gdscript
var f := FleeBehavior.flee_force(
    Vector3(0, 0, 0),
    [Vector3(2, 0, 0)]
)
print(f)  # should be non-zero, pointing in -X direction
```

Also test the "no threat nearby" case returns Vector3.ZERO.

## When you're done

Open a PR titled `Add Shawn contribution: FleeBehavior`. In the body,
mention your chosen `flee_radius` (in meters) and MAX_FORCE cap.
