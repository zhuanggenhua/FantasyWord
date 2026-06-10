# Technique Routing

Read this file when the user asks for a visual effect or rendering technique rather than naming a Unity API. Load only the technique files needed for the request.

## Primary routing

| User request | Read first | Often combine with |
| --- | --- | --- |
| Raymarched scene, distance-field world, metaballs | `techniques/ray-marching.md`, `techniques/sdf-3d.md` | `techniques/lighting-model.md`, `techniques/shadow-techniques.md`, `techniques/ambient-occlusion.md`, `techniques/sdf-tricks.md` |
| 2D signed-distance UI, outlines, procedural icons | `techniques/sdf-2d.md` | `techniques/anti-aliasing.md`, `techniques/color-palette.md`, `techniques/sdf-tricks.md` |
| Water, ocean, stylized sea | `techniques/water-ocean.md` | `techniques/lighting-model.md`, `techniques/atmospheric-scattering.md`, `techniques/post-processing.md` |
| Clouds, fog, fire, smoke, god rays | `techniques/volumetric-rendering.md` | `techniques/procedural-noise.md`, `techniques/atmospheric-scattering.md`, `techniques/camera-effects.md` |
| Terrain, landscapes, planets | `techniques/terrain-rendering.md` | `techniques/procedural-noise.md`, `techniques/texture-mapping-advanced.md`, `techniques/atmospheric-scattering.md` |
| Procedural noise, FBM, Worley, Voronoi | `techniques/procedural-noise.md`, `techniques/voronoi-cellular-noise.md` | `techniques/domain-warping.md`, `techniques/color-palette.md` |
| Organic deformation, distortion, warped UVs | `techniques/domain-warping.md`, `techniques/polar-uv-manipulation.md` | `techniques/procedural-noise.md`, `techniques/procedural-2d-pattern.md` |
| Particle effects, sparks, rain, snow | `techniques/particle-system.md` | `techniques/procedural-noise.md`, `techniques/color-palette.md`, `techniques/simulation-physics.md` |
| Fluids, reaction diffusion, sand, GPU sim | `techniques/fluid-simulation.md`, `techniques/cellular-automata.md`, `techniques/simulation-physics.md` | `techniques/multipass-buffer.md`, `techniques/post-processing.md` |
| PBR, toon, rim light, stylized lighting | `techniques/lighting-model.md` | `techniques/shadow-techniques.md`, `techniques/ambient-occlusion.md`, `techniques/normal-estimation.md` |
| Bloom, tone mapping, glitch, lens effects | `techniques/post-processing.md`, `techniques/camera-effects.md` | `techniques/anti-aliasing.md`, `techniques/multipass-buffer.md` |
| Custom sampling, triplanar, no-tile mapping | `techniques/texture-sampling.md`, `techniques/texture-mapping-advanced.md` | `techniques/terrain-rendering.md`, `techniques/procedural-noise.md` |
| Fractals, kaleidoscopes, procedural patterns | `techniques/fractal-rendering.md`, `techniques/procedural-2d-pattern.md`, `techniques/polar-uv-manipulation.md` | `techniques/color-palette.md`, `techniques/anti-aliasing.md` |
| Fullscreen buffers, temporal accumulation, ping-pong | `techniques/multipass-buffer.md` | `techniques/post-processing.md`, `techniques/fluid-simulation.md`, `techniques/path-tracing-gi.md` |

## Unity adaptation hints

- For material-local surface effects, favor a mesh shader in ShaderLab.
- For fullscreen image effects in URP, favor a `ScriptableRendererFeature` plus `ScriptableRenderPass`.
- For HDRP fullscreen effects, favor Custom Pass or fullscreen material workflows.
- For stateful techniques such as fluid simulation or temporal accumulation, use `RenderTexture` or RTHandle orchestration from C# instead of copying ShaderToy buffer semantics.
- For ray marching, decide whether the effect is object-local, volume-local, or fullscreen before writing any code.

## When to read deeper references

- If the math is non-trivial, read the matching file from `references/glsl-reference/`.
- If the technique doc already gives enough implementation guidance, stop there and keep context small.
