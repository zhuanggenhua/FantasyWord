# Assets, Performance, And Builds

## Asset Loading

- Use the repo's existing loading strategy first.
- For new runtime-loaded content, prefer Addressables over `Resources`.
- Group assets by load context and lifetime, not by file type alone.
- Track load and release ownership clearly to avoid leaks.

## Pooling And Lifetime

- Pool objects that are created and destroyed frequently.
- Separate pooled instance reset logic from spawn logic.
- Release Addressables handles and instances symmetrically.

## Memory And CPU

- Watch for GC allocations in frame-critical code.
- Split static and dynamic UI or content when rebuild cost matters.
- Profile using Unity Profiler, Memory Profiler, Frame Debugger, and platform GPU tools when relevant.

## Rendering

- Respect the active render pipeline instead of mixing APIs.
- Prefer SRP-friendly approaches for modern Unity projects.
- Batch repeated content through instancing, atlasing, sensible material usage, and culling.

## Import And Content Rules

- Keep import settings platform-aware for textures, meshes, and audio.
- Avoid large uncompressed textures or audio assets unless quality requirements justify them.
- Use sprite atlases, mesh LODs, and baked lighting where appropriate.

## Build And Platform Work

- Do not change platform-specific settings blindly; inspect current targets first.
- Call out any manual Unity editor steps for signing, scenes-in-build, scripting defines, or package configuration.
- Treat build failures as configuration problems first, not just code problems.

## Upgrade And Migration

- Minimize package churn during unrelated feature work.
- When touching version-sensitive systems, verify package and engine API behavior against official Unity docs.
- Prefer focused migrations: one subsystem at a time, with validation after each step.

## Common Risks

- Loading assets synchronously on the main thread
- Leaking handles or pooled instances
- Rebuilding giant UI or scene hierarchies unnecessarily
- Mixing Built-in RP assumptions into URP or HDRP projects
- Shipping debug-only assets or editor scripts into runtime assemblies
