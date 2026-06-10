---
name: unity-shader
description: Hand-write, debug, convert, and optimize Unity ShaderLab/HLSL shaders across URP, HDRP, and Built-in Render Pipeline with cross-platform targets (mobile, PC, console, WebGL). Use for shader authoring, pipeline migration, BRDF or lighting work, shader performance tuning, Custom Renderer Feature or Custom Pass integration, shader artifact troubleshooting, and whenever the user asks for an effect by technique name such as ray marching, SDF, volumetrics, water, post-processing, noise, particles, terrain, or atmospheric scattering and needs it translated into production-ready Unity code rather than generic GLSL.
---

# Unity Shader

## Goal

Deliver production-ready Unity shader solutions that stay explicit about render pipeline, platform constraints, and performance tradeoffs, while also using a broader shader-technique knowledge base when the request is effect-driven.

## Cross-Agent Use

- Treat this skill as an agent-agnostic instruction set.
- If the host does not support skill invocation syntax, load this file as system or developer instructions.
- Use the bundled `techniques/` and `references/glsl-reference/` files as optional research material, not as the default output target.

## Workflow

1. Confirm render pipeline, Unity version, target platforms, and requested task type.
2. Assume URP when the pipeline is not provided, and state that assumption explicitly.
3. Choose the response mode: new shader, concept explanation, optimization pass, or technique-to-Unity conversion.
4. Read `references/pipeline-rules.md` for pipeline API conventions and coding constraints.
5. Read `references/performance-and-response.md` when the request includes mobile, WebGL, performance tuning, or quality tiers.
6. If the request is effect-first rather than API-first, read `references/technique-routing.md`, then load only the relevant file(s) from `techniques/`.
7. If the technique needs deeper theory or derivation, read only the matching file(s) from `references/glsl-reference/`.
8. Translate the chosen technique into Unity-specific implementation details using `references/unity-technique-translation.md`.
9. Produce complete, paste-ready output files instead of partial fragments.
10. Validate platform and pipeline compatibility before responding.

## Response Contracts

### New shader implementation

- Start with a 2-3 sentence summary of the rendering technique and algorithm.
- Provide one complete `.shader` file ready to paste into Unity.
- Add a file header comment that states supported pipeline(s) and platform assumptions.
- Add inline comments for non-obvious math and coordinate-space transforms.
- List all shader properties with short control descriptions and practical defaults.
- Include required C# code when the shader depends on URP Renderer Features, HDRP Custom Passes, compute dispatch, runtime property binding, or ping-pong render targets.

### Technique-to-Unity conversion

- Name the source technique(s) you used from `techniques/`.
- Explain in 2-4 sentences how the generic shader idea maps onto Unity's render pipeline and frame lifecycle.
- Provide the complete Unity-side implementation, not raw ShaderToy or generic GLSL, unless the user explicitly asks for non-Unity output.
- Call out the adaptation points that matter: screen UVs, camera rays, texture macros, pass orchestration, depth usage, and performance limits.

### Concept explanation

- Explain required transforms: object -> world -> view -> clip -> NDC -> screen.
- Include the relevant formula when useful.
- Mention Unity helper functions that implement key steps.
- Note pipeline-specific differences for the same concept.
- If the question is technique-driven, point to the relevant bundled technique file(s).

### Optimization review

- Show before and after changes with estimated ALU and texture sample impact.
- Recommend profiler checks: RenderDoc, Unity Frame Debugger, Xcode GPU tools, Mali Offline Compiler.
- Suggest LOD or quality-tier strategy when applicable.
- Call out platform-specific risks.

## Non-Negotiable Rules

- Keep response language the same as the user language.
- Keep shader code and shader comments in English.
- Treat files under `techniques/` and `references/glsl-reference/` as conceptual references, not direct output templates.
- Do not return raw ShaderToy-style GLSL unless the user explicitly asks for non-Unity shader output.
- Do not mix pipeline conventions in one shader file.
- Keep one effect per shader file.
- Use `shader_feature` or `shader_feature_local` for material features; use `multi_compile` only for true global variants.
- Prefer reusable math in standalone `.hlsl` include files with no pipeline API calls.
- Avoid deprecated `fixed`.
- Avoid Surface Shaders outside Built-in RP.
- Avoid `tex2D()` inside `HLSLPROGRAM` blocks.
- Warn when expected variant count can become excessive.
- For fullscreen, post-process, or multipass effects, state whether the correct Unity vehicle is a material shader, Renderer Feature, Custom Pass, ScriptableRenderPass, or compute-driven pipeline.
- For stateful effects, include render-target orchestration instead of hand-waving "buffer A/buffer B" logic.

## Reference Map

- Read `references/pipeline-rules.md` for URP, HDRP, and Built-in conventions plus portability structure.
- Read `references/performance-and-response.md` for precision policy, optimization rules, quality tiers, and output formatting requirements.
- Read `references/technique-routing.md` when the request describes an effect or visual result rather than a specific Unity API.
- Read `references/unity-technique-translation.md` when adapting GLSL, ShaderToy, or WebGL-style material into Unity ShaderLab and HLSL.
- Read files in `techniques/` for compact implementation guidance on specific rendering techniques.
- Read files in `references/glsl-reference/` only when you need deeper mathematical explanation or advanced variants of a technique.
- Read `references/attribution.md` for the provenance of the bundled technique library.
- Read `references/generic-agent-template.md` for a host-agnostic prompt template.
