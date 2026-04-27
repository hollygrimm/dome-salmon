# Cycle Color Ramp — Design

*Author: Holly Grimm. Drafted Mon Apr 27, 2026 for Week 15 (May 8 finals draft).*

## Context

Dome-salmon's three shaders (`salmon_body`, `water_surface`, `riverbed`) are functional but visually static. For Ashley Cordes's Swimming Salmon residency context — and specifically the *Salmon Afterlives* framing ("by means of the river the ocean fed the forest") — the visuals should *do something* over the dome viewing rather than just decorate.

This design adds a wall-clock-driven color shift over a 180-second "run." Salmon flanks redden as if approaching spawning grounds; the surrounding water and riverbed pick up subtle warm undertones to keep the palette coherent. After 180s, the scene holds in spawning-state.

## Concept

Audience experience under the dome:
- t=0 to ~60s: salmon are pre-spawning copper, water cool teal, riverbed caustics blue
- t=60s to ~120s: flanks gradually redden, water shifts subtly warmer
- t=120s to 180s: salmon are spawning-red, riverbed caustics now warm amber (light coming through autumn leaves overhead)
- t=180s+: hold

The riverbed caustic shift carries the most conceptual weight: caustic shimmer transitioning from cold sea-light to amber forest-light directly supports "the ocean fed the forest." Audience may not consciously read it; they should feel the warmth move in.

## Design

### Time source

Each shader-owning script computes its own `cycle_amount` from `Time.get_ticks_msec()`. Both stay in sync because they share the engine clock — no central CycleClock node needed.

```gdscript
const RUN_DURATION_SEC: float = 180.0
var cycle_amount := clamp(Time.get_ticks_msec() * 0.001 / RUN_DURATION_SEC, 0.0, 1.0)
```

After t=180s, `cycle_amount` clamps to 1.0 and stays there.

### Shader uniforms driven from GDScript

No new uniforms — all already exist. No shader source edits required.

| Shader | Uniform | t=0 value | t=180s value |
|---|---|---|---|
| `salmon_body` | `spawn_color_amount` | `0.0` | `1.0` |
| `water_surface` | `water_shallow` | `(0.18, 0.42, 0.48, 0.72)` cool teal | `(0.32, 0.38, 0.40, 0.72)` warm-grey |
| `riverbed` | `caustic_tint` | `(0.4, 0.75, 0.8, 1.0)` cool blue | `(0.85, 0.55, 0.30, 1.0)` warm amber |

### Code locations

**`scripts/SalmonSchool.gd`:**
- Promote local `mat` in `_init_multimesh()` to member `_salmon_mat: ShaderMaterial`
- In `_process(delta)`, compute `cycle_amount` and call `_salmon_mat.set_shader_parameter("spawn_color_amount", cycle_amount)`

**`scripts/RiverEnvironment.gd`:**
- In `_ready()`, capture `_water_mat` and `_bed_mat` references from `WaterSurface` and `Riverbed` `material_override`
- In `_process(delta)`, compute the same `cycle_amount`, lerp the two color uniforms between t=0 and t=180s endpoints, and write back via `set_shader_parameter`

Total addition: ~15 lines across two files.

## Out of Scope

Explicitly *not* doing:
- Per-fish lifecycle (every salmon transitions together — the run is a collective event)
- Particles, post-mortem behavior, leaf imagery, ambient sound shifts
- Keyboard scrubbing of the cycle (purely wall-clock driven so dome viewing is reproducible)
- Looping or fade-out (after 180s the scene holds in spawning-state until ESC)
- A "death" or "decomposition" stage beyond the red-flank color
- Modifying any shader source files

These belong to a residency-grade implementation, not this draft.

## Implementation Budget

60–90 minutes total. If implementation overruns, the riverbed `caustic_tint` ramp is the first thing to drop (salmon-body + water alone still reads as a warmth shift).
