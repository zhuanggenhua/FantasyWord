# Performance And Response Guide

## Precision Strategy

- Default to `half` for color, normals, and UV math on mobile and WebGL.
- Use `float` for position, depth, and precision-sensitive calculations.
- Keep code valid across mobile and desktop without relying on implicit casts.
- Annotate intentional precision choices when mixing types.

## Platform-Aware Optimization

### General

- Move computations from fragment to vertex when quality remains acceptable.
- Prefer `step`, `lerp`, and `saturate` over fragment branching where possible.
- Reduce texture fetch count and pack related scalar maps into shared textures.
- Use `[NoScaleOffset]` on textures that do not need tiling/offset controls.

### Mobile

- Assume tile-based GPUs and minimize overdraw.
- Avoid unnecessary alpha test where alpha blend can satisfy the requirement.
- Avoid dependent texture reads when possible.
- Provide reduced-quality feature paths with keywords.

### WebGL

- Keep target at `#pragma target 3.0` for WebGL 2.0 compatibility.
- Avoid compute shaders and tessellation.
- Favor GLSL ES 3.0-safe constructs when choosing HLSL features.

## Quality Tier Pattern

Use scalable variants for multi-platform support:

```hlsl
#pragma multi_compile _ _QUALITY_MED _QUALITY_HIGH

#if defined(_QUALITY_HIGH)
    // full effect
#elif defined(_QUALITY_MED)
    // reduced effect
#else
    // low-end path
#endif
```

## Optimization Review Expectations

- Report estimated ALU and texture sample delta for major changes.
- Explain visual tradeoffs for each optimization.
- Mention variant-count impact when introducing new keywords.
- Suggest profiling checkpoints: RenderDoc for pass and draw-call cost, Unity Frame Debugger for pass validation, Xcode GPU tools for iOS, and Mali Offline Compiler for Android fragment cost estimation.

## Response Formatting Rules

- Match the user language for prose.
- Keep shader code and code comments in English.
- For new shaders, include a 2-3 sentence algorithm summary, a complete `.shader` file, a clear property list with defaults, and required supporting C# files when applicable.
- For concept questions, include coordinate-space chain, relevant formula, Unity helper function mapping, and pipeline differences.
- For optimization requests, include before and after cost estimate, concrete profiler metrics to inspect, and platform-specific caveats.
