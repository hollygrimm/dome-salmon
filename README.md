# DomeSalmon

A real-time dome installation: salmon swim upstream through a procedural river,
responding to five OSC sensor performers. Built in Godot 4 for fullscreen
projection through ScreenBerry to a fulldome.

This is the technical scaffold for **Ashley Cordes**' *Swimming Salmon* —
Coquille Indian Tribe — a piece about return, endurance, and the cultural
weight a school carries upstream.

---

## Contributors

This project includes contributions from four CSAT201 students at the
**Institute of American Indian Arts (IAIA)**, Spring 2026:

| Student | Contribution | Repository |
|---------|--------------|------------|
| **Ticoh Japp** | `scripts/SchoolingBehavior.gd` — per-fish cohesion modulation that gives the school internal variation while keeping it tight | [cs-iaia/sp26-csat201-godot-ticohj](https://github.com/cs-iaia/sp26-csat201-godot-ticohj) |
| **Shawn Olivar** | `scripts/FleeBehavior.gd` — flee force from threats, with hysteresis so fish don't flicker between states | [cs-iaia/sp26-csat201-godot-solivar](https://github.com/cs-iaia/sp26-csat201-godot-solivar) |
| **Keanu Begay** | `scripts/PlayerFish.gd` — WASD-piloted hero salmon that the school responds to as a presence | [cs-iaia/sp26-csat201-godot-KeanuBegay](https://github.com/cs-iaia/sp26-csat201-godot-KeanuBegay) |
| **Jacob Crazy Bull** | `scripts/contributions/jacob/BehaviorMode.gd` — design contract for a per-fish WANDER ↔ SEEK_UPSTREAM state machine (interface defined; implementation pending) | [cs-iaia/sp26-csat201-godot-JacobCrazyBull](https://github.com/cs-iaia/sp26-csat201-godot-JacobCrazyBull) |

The students contributed as creative technologists supporting the artist's
vision. Course taught by **Holly Grimm (Diné)**.

---

## Running it

1. Open Godot 4.6 (or later).
2. Open `project.godot`.
3. Press **F5** (or click ▶ in the editor toolbar).

The piece launches fullscreen on the second display if one is attached, or
the primary display otherwise. Window is locked to a 2160×2160 square so the
fulldome's circular projection lands cleanly with no letterboxing.

### Controls (live)

| Key | Effect |
|-----|--------|
| `1`–`5` | Hold to ramp each performer parameter (sensor stubs) |
| `F3` | Toggle on-screen debug overlay |
| `ESC` | Quit |
| WASD + arrows | Pilot the hero salmon (Keanu's PlayerFish) |

OS cursor is hidden by default — this is passive viewing.

---

## Performer parameters (OSC)

Default port: **UDP 8000**. Edit `OSCReceiver.gd` → `LISTEN_PORT` to change.

| OSC address | Meaning | Visible effect |
|-------------|---------|----------------|
| `/performer/1/velocity` | swim urgency | school speeds up; current intensifies |
| `/performer/2/lateral` | school cohesion | tightens / loosens the school |
| `/performer/3/vertical` | leap energy | vertical movement, breaching |
| `/performer/4/rotation` | predator evasion | turbulence spikes; sunlight dims |
| `/performer/5/stillness` | rest | calms water; school holds in eddies |

All values expected in `[0.0, 1.0]`. Without sensors, hold keys 1–5 to
simulate. The `1`+`4` combination produces maximum turbulence — rapids.

---

## Tuning the school's cultural feel

Authored cultural values live in `resources/salmon_endurance.tres` and can
be edited in the Godot Inspector. They shape how the school looks the same
way each run (distinct from OSC, which is live and time-varying).

| Field | Range | What it does |
|-------|-------|--------------|
| `cohesion` | 0.0–1.0 | Baseline school tightness — low loosens, high tightens |
| `playfulness` | 0.0–1.0 | Per-fish variation amplitude — 0 = uniform, 1 = erratic |
| `care` | 0.0–1.0 | (Reserved for Jacob's `BehaviorMode` once his PR lands) |
| `generosity`, `persistence`, `restraint` | 0.0–1.0 | Reserved for future contributions |

Adjust the `.tres` and re-run the scene to see the change.

---

## Project Structure

```
dome_salmon/
├── project.godot
├── scripts/
│   ├── OSCReceiver.gd          ← Autoload: UDP listener + OSC parser
│   ├── ParameterBank.gd        ← Autoload: smoothed behavioral params
│   ├── Main.gd                 ← Scene root, river, dome camera, debug
│   ├── SalmonSchool.gd         ← MultiMeshInstance3D boids controller
│   ├── RiverEnvironment.gd     ← Water, riverbed, lighting, fog
│   ├── RiverCurrent.gd         ← Flow field along the procedural river path
│   ├── DomeCamera.gd           ← Path-following dome-aspect camera
│   ├── CulturalValue.gd        ← Resource type for authored values (.tres)
│   ├── SchoolingBehavior.gd    ← Per-fish cohesion modulator (Ticoh)
│   ├── FleeBehavior.gd         ← Per-fish flee force from threats (Shawn)
│   ├── PlayerFish.gd           ← WASD-piloted hero salmon (Keanu)
│   └── contributions/
│       └── jacob/
│           └── BehaviorMode.gd ← WANDER ↔ SEEK_UPSTREAM contract (Jacob, stub pending PR)
├── shaders/
│   ├── salmon_body.gdshader    ← Vertex undulation + spawning coloration
│   ├── water_surface.gdshader  ← Animated translucent water
│   └── riverbed.gdshader       ← Rocky bed with caustic light
├── scenes/
│   └── Main.tscn               ← Open this to run the piece
├── resources/
│   └── salmon_endurance.tres   ← Authored cultural values for the school
└── assets/
    └── salmon.glb              ← Salmon mesh
```

---

## Dome pipeline

The piece is built to run on a **Mac mini's second display** at 2160×2160,
output via DisplayPort to a touch table running **ScreenBerry**, which warps
the square frame for the fulldome.

**No fisheye shader is needed** — ScreenBerry handles the projection math.
The Godot scene composes for a square viewport with the camera positioned for
center-weighted action.

Technical contact at IAIA: **Drew** (dome integration). Justin is the dome
manager. They handle the pipeline downstream of the Godot output.

---

## Performance Notes

- ~300 fish on Mac mini M4: ~60fps with O(n²) boids.
- For 500+ fish, consider moving the boid loop to a compute shader
  (`RenderingDevice` in Godot 4) — current implementation writes MultiMesh
  transforms on the CPU each frame.
- Profile with Godot's built-in profiler (Debug → Profiler).
