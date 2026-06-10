# Unity Technique Translation

Use this file when adapting ideas from GLSL, ShaderToy, or WebGL-oriented material into Unity ShaderLab and HLSL.

## Principle

Treat the bundled technique library as effect knowledge, not as copy-paste code. Translate the algorithm into the target Unity pipeline instead of preserving the original entry points, uniforms, or buffer model.

## Common mapping

| Generic shader concept | Unity equivalent |
| --- | --- |
| `mainImage(out vec4 fragColor, in vec2 fragCoord)` | Fragment function returning `SV_Target` |
| `fragCoord` or `gl_FragCoord.xy` | Screen position derived from clip space, `IN.positionHCS`, `ComputeScreenPos`, or normalized screen UV |
| `iResolution.xy` | `_ScreenParams.xy` or `_ScaledScreenParams.xy`; use explicit material properties when render target size matters |
| `iTime` | `_Time.y` for scaled time, or a custom C# parameter for deterministic control |
| `iMouse` | Custom C# parameter, input system value, or editor-only debug control |
| `iChannel0..3` | Named textures and samplers such as `_BaseMap`, `_NoiseTex`, `_HistoryTex` |
| `texture()` / `texture2D()` | `SAMPLE_TEXTURE2D`, `SAMPLE_TEXTURE2D_LOD`, or pipeline-specific macros |
| ShaderToy Buffer A/B | `RenderTexture`, RTHandle, Custom Pass buffers, or URP render targets managed from C# |

## Translation rules

1. Rewrite coordinate handling in Unity terms.
   Screen shaders often need normalized screen UV and aspect correction. Surface shaders often need object, world, tangent, or view space instead.
2. Choose the correct pass topology before coding.
   A fullscreen effect, a mesh material, and a simulation step are different systems in Unity even if they share math.
3. Replace generic uniforms with stable Unity properties.
   Name textures, colors, and scalars for inspector use; move transient frame state into C# when necessary.
4. Keep SRP Batcher compatibility.
   Put material parameters in `CBUFFER_START(UnityPerMaterial)` for URP or HDRP shaders.
5. Convert buffer feedback into explicit render-target orchestration.
   If a technique depends on previous frames or multiple buffers, include the C# setup that allocates, swaps, and binds those textures.
6. Re-evaluate performance budgets per platform.
   ShaderToy examples often assume desktop fullscreen demos. In Unity, the same loop counts can be unacceptable on mobile, VR, or WebGL.

## Effect-specific notes

### Ray marching and SDF

- Decide whether the ray march happens in object space, world space, or fullscreen view space.
- Integrate scene depth when the effect must intersect with rasterized geometry.
- Cap steps aggressively and expose quality tiers.

### Volumetrics

- Prefer reduced step counts with blue-noise jitter or temporal reprojection rather than brute-force loops.
- Explain whether the effect belongs in a fullscreen pass, local volume, or billboard-based approximation.

### Post-processing

- URP usually needs a renderer feature and pass setup.
- HDRP may prefer Custom Pass or built-in fullscreen infrastructure.
- Built-in RP may require `OnRenderImage` or a camera effect path if the project still uses it.

### Simulation and multipass effects

- Use compute shaders when the platform and project support them and the simulation is state-heavy.
- Fall back to fragment-pass ping-pong only when compute is unavailable or overkill.

## Output expectation

When you adapt a technique, return the Unity implementation that a developer can drop into a project, plus the minimal setup code and usage notes needed to run it.
