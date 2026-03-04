# DomeSalmon — Godot 4 Project Scaffold

Dome visualization: 5 OSC sensor performers → hundreds of salmon → TouchDesigner → VIOSO → dome.

---

## Project Structure

```
dome_salmon/
├── project.godot
├── scripts/
│   ├── OSCReceiver.gd        ← Autoload: UDP listener + OSC parser
│   ├── ParameterBank.gd      ← Autoload: smoothed behavioral params
│   ├── SalmonSchool.gd       ← MultiMeshInstance3D boids controller
│   ├── RiverEnvironment.gd   ← Water, riverbed, lighting, fog
│   └── Main.gd               ← Scene root, debug overlay, keyboard stubs
├── shaders/
│   ├── salmon_body.gdshader  ← Vertex undulation + spawning coloration
│   ├── water_surface.gdshader ← Animated translucent water
│   └── riverbed.gdshader     ← Rocky bed with caustic light
├── scenes/
│   └── Main.tscn             ← Build this manually (see Scene Setup below)
└── assets/
    └── (salmon.glb goes here when ready)
```

---

## Setup: Autoloads

In Godot: **Project → Project Settings → Globals → Autoload**, add in this order. The first file will load as `OscReceiver`, rename to `OSCReceiver`.:

| Name           | Path                          |
|----------------|-------------------------------|
| OSCReceiver    | res://scripts/OSCReceiver.gd  |
| ParameterBank  | res://scripts/ParameterBank.gd|



---

## Setup: Main Scene (Main.tscn)

Build this scene tree manually in the Godot editor. Create Root Node: 3D Scene, save as Main.tscn in scenes folder

```
Main  (Node3D)  ← attach Main.gd "Attach Script..."
├── Camera3D ← "Add Child Node..."
│     position = (0, 2, 15) ← Inspector -> Transform
│     rotation = (-5°, 0, 0) ← Inspector -> Transform
├── DirectionalLight3D
│     rotation = (-45°, -30°, 0)
│     shadow on checkbox
├── SalmonSchool  (MultiMeshInstance3D)  ← attach SalmonSchool.gd
│     position = (0, 0, 0)
├── RiverEnvironment  (Node3D)  ← attach RiverEnvironment.gd
│   ├── WaterSurface  (MeshInstance3D)   ← mesh built in code
│   ├── Riverbed      (MeshInstance3D)   ← mesh built in code
│   ├── SunLight      (DirectionalLight3D)
│   └── WorldEnvironment (WorldEnvironment)
└── DebugPanel  (CanvasLayer)
      └── VBox  (VBoxContainer)
            anchors: top-left (Layout)
            └── Label  (name it "Label")
                  custom_min_size = (400, 0) under Layout
```

---

## How the Environment Reacts to Performers

| Performer action       | Environmental response                         |
|------------------------|------------------------------------------------|
| Key 1 (swim_urgency)   | Water waves speed up, current intensifies      |
| Key 4 (evasion_drive)  | Turbulence spikes, sunlight dims (predator)    |
| Keys 1+4 together      | Maximum turbulence — rapids conditions         |
| Key 5 (rest)           | Water calms, caustics slow, glassy surface     |

---

## Pipeline: Godot → TouchDesigner

**Syphon status:** No stable Godot 4 Syphon GDExtension exists as of early 2026.

### Milestone 1 Workaround: Screen Capture TOP

1. Run Godot (exported or in editor) at 1920×1080
2. In TouchDesigner: add a **Screen Capture TOP**
3. Set it to capture the Godot window
4. Feed into your dome warp/VIOSO chain

### Future: Syphon (when available)

Watch these repos for a Godot 4 GDExtension:
- https://gitlab.com/frankiezafe/gsyphon (currently Godot 3)
- Smithery skill ecosystem — search "syphon godot 4"

---

## OSC Configuration

Default port: **8000** (UDP)

Edit `OSCReceiver.gd` → `LISTEN_PORT` to match your sender.

Expected OSC addresses:
```
/performer/1/velocity    → swim urgency / speed
/performer/2/lateral     → school cohesion
/performer/3/vertical    → leap / vertical energy
/performer/4/rotation    → predator evasion
/performer/5/stillness   → resting in eddies
```

All values expected in range [0.0, 1.0].

**Testing without sensors:** Hold keys 1–5 in the running Godot window to
simulate performer input. Press D to toggle the debug overlay.

---

## Milestone Checklist

- [x] **M1: Pipeline** — Godot window → Screen Capture TOP in TD → one projector
- [x] **M2: Boids** — SalmonSchool running with keyboard stubs, looks good in TD
- [ ] **M3: Shader** — salmon_body.gdshader on the MultiMesh, undulation working
- [ ] **M4: OSC** — real sensor data flowing, ParameterBank driving behavior
- [ ] **M5: Dome** — VIOSO calibration, all 5 projectors, full school in the dome

---

## Performance Notes

- 300 fish on Mac Studio M2: ~60fps with O(n²) boids — fine for prototype
- For 500+ fish: move boids to a compute shader (Godot 4 RenderingDevice)
- MultiMesh writes happen every frame on CPU; profile with Godot's built-in profiler

---

## OOP Architecture Notes

This project demonstrates:

| Pattern | Where |
|---------|-------|
| Inheritance | BaseOrganism → Salmon (add later) |
| Composition | RiverSystem has-a CurrentField, has-a SalmonSchool |
| Encapsulation | OSCReceiver hides UDP/parse details behind `get_param()` |
| Signal-driven | Godot signals for leap events, predator triggers |
| Singleton | OSCReceiver, ParameterBank as Autoload singletons |
