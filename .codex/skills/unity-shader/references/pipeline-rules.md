# Pipeline Rules

## Pipeline Awareness

- Ask for the target render pipeline before writing code.
- Default to URP when the user does not specify a pipeline, and state this assumption.
- Place supported pipeline(s) and platform assumptions in a comment header at the top of each shader file.
- Note key adaptation points when a technique can be ported across pipelines.

## URP Rules

- Use `HLSLPROGRAM` blocks.
- Include URP libraries such as `Core.hlsl` and `Lighting.hlsl` when needed.
- Ensure SRP Batcher compatibility with `CBUFFER_START(UnityPerMaterial)` and `CBUFFER_END`.
- Use `SAMPLE_TEXTURE2D` style macros, not `tex2D()`.
- Follow URP naming style with `Attributes` and `Varyings`.

## HDRP Rules

- Use HDRP ShaderLibrary includes and APIs.
- Respect HDRP material architecture (Lit, Unlit, fullscreen, Custom Pass workflows).
- State clearly when the effect should be implemented as a Custom Pass or fullscreen shader.
- Keep SRP Batcher-compatible constant buffer layout.

## Built-in RP Rules

- Use `CGPROGRAM` and `ENDCG` when appropriate.
- Allow Surface Shaders only in this pipeline.
- Use legacy sampling and lighting conventions such as `tex2D()` and `_LightColor0` where required.
- Follow Built-in style with `appdata` and `v2f`.

## Portability Pattern

- Keep pipeline-agnostic math in include files with no pipeline API dependencies.
- Keep pipeline wrappers in dedicated pipeline files or `#ifdef` blocks.
- Prefer this folder structure:

```text
Shaders/
  Includes/
    NoiseUtils.hlsl
    LightingHelpers.hlsl
  URP/
    MyEffect_URP.shader
  BuiltIn/
    MyEffect_BuiltIn.shader
```

## Coding Standards

- Use clear inspector property labels such as `_MainTex ("Base Map", 2D) = "white" {}`.
- Group inspector settings with `[Header()]` and `[Space]`.
- Keep one effect per shader file.
- Declare `#pragma target` based on required features.
- Add comments for non-obvious math and space conversions.
- Mark coordinate spaces in comments when context is ambiguous.
- Use toggles like `[Toggle] _FEATURE_ON ("Feature", Float) = 0` with `#pragma shader_feature_local _FEATURE_ON`.

## Variant Policy

- Use `multi_compile` for true global variants (fog, global shadows).
- Use `shader_feature` or `shader_feature_local` for material-local options.
- Prefer local keywords to avoid global keyword pollution.
- Warn when variant count is likely to exceed practical limits.

## Avoid List

- Avoid deprecated `fixed`.
- Avoid Surface Shaders in URP or HDRP.
- Avoid hardcoded magic numbers without comments.
- Avoid SRP shaders without proper constant buffers.
- Avoid `tex2D()` inside `HLSLPROGRAM` blocks.
- Avoid techniques that silently support only one pipeline without explicit disclosure.
- Avoid compute or tessellation assumptions on WebGL.
