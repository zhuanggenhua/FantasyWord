# Transit context steering: bounded scoring port

Source lock: Unity commit `31629d53a110dd4c87d4c85e6ad5a387fbafb931`.
Pure scoring only: **not an active NPC, world simulation, RVO avoidance,
navigation, contact correction or visual acceptance**.

## Source mapping

All classes are under `Assets/ProjectPlugins/ContextSteering2D/Runtime/`.

- `Defaults/DefaultContextSteeringProfile2D.asset`: transit group references
  6597 Seek, 6598 ObstacleAvoidance, 6599 Separation, 6601 SideStep, all enabled
  with weight 1. Side preference .35; forward dot threshold .15. Profile has
  16 samples, agent radius .35, obstacle/neighbor radius 1, max speed 1,
  combine enum 0 and selection enum 0.
- `SteeringDirectionSet2D.cs`: +Y first, clockwise samples.
- `SteeringDetectionFrame2D.Reset`: normalize forward above squared magnitude
  .0001; otherwise +X.
- The four corresponding behavior classes: exact proximity formula, overlap
  fallback, forward/cross gates and directional contributions.
- `SteeringContext2D.cs`: per-contribution directional maximum; sum interest
  across contributions, maximum constraint. Scores are clamp(interest) times
  (1 minus clamp(constraint)), NOT subtraction despite the enum name.
  Weighted blend normalizes above squared magnitude .0001; strength is the
  highest score, not weighted-vector magnitude.
- `ContextSteeringSolver2D.cs`: direction times max speed, speed scale and
  strength. Transit never limits speed. Nonnegative speed override is used;
  negative uses profile max speed.

## Adapter contract and limits

`transit_steering.gd.solve(frame, max_speed)` takes position, forward, nullable
target, obstacles (`point` is source ClosestPoint, `radius`), neighbours
(`position`, `radius`). All vectors use **Unity XY, Y up**. Reflect Y at
the Godot adapter boundary, not inside the algorithm.

The caller must supply real source-compatible detection and neighbor filtering.
No raycasts, collider deduplication, AI group selection, route generation,
RVO/contact resolution or native movement is supplied. Never substitute this
group for the authored predictive-target or combat-wander groups. The authored
training dummy explicitly has additional formal GAS code 20001; this module
does not grant or execute an attack.

Scalar accumulations use float32 rounding and vectors use Godot standard
single precision. Trigonometry/normalization across Unity and Godot is NOT
proven bit-identical. Numerical tests use 1e-5 tolerance, not bitwise parity.

## Checks

`godot --headless --path godot --script res://tests/test_transit_steering.gd`
passes 28 assertions: sample order, empty/near-zero targets, radius proximity,
max-not-sum obstacle contributions, side signs, boundary/coincident obstacles,
neighbor overlap/behind/zero fallback, weighted sum/clamp/attenuation and speed
overrides. Writable XDG data/cache directories are needed in sandboxed CI.
