---
name: unity-production
description: Default skill for Unity project engineering across gameplay architecture, MonoBehaviour or DOTS decisions, scene and prefab safety, ScriptableObject data flow, Input System, Addressables, performance profiling, editor tooling, platform builds, and Unity 6 aware implementation. Use for most Unity coding tasks unless the request is primarily shader authoring or pure UI Toolkit work.
---

# Unity Production

## Goal

Handle the majority of Unity project work with production-safe defaults, minimal asset churn, and explicit routing for version-sensitive or subsystem-heavy tasks.

## Use This Skill For

- Gameplay systems, architecture, and refactors in Unity projects
- Scene, prefab, ScriptableObject, and serialization-safe changes
- Input System, animation, physics, save/load, and runtime flow
- Addressables, pooling, memory, loading, profiling, and build preparation
- Unity editor tooling, inspectors, import automation, and project setup
- Reviewing Unity code for engine-specific risks and regressions

## Prefer Dedicated Skills When Available

- Use `unity-uitoolkit` when the request is mainly UXML, USS, `UIDocument`, `VisualElement`, or runtime/editor UI Toolkit implementation.
- Use `unity-shader` when the request is mainly ShaderLab, HLSL, URP or HDRP shader work, fullscreen passes, or render-feature shader authoring.

## Detection First

Before proposing or editing code, inspect project reality instead of assuming:

- `ProjectSettings/ProjectVersion.txt`
- `Packages/manifest.json`
- `Packages/packages-lock.json`
- `ProjectSettings/GraphicsSettings.asset`
- `ProjectSettings/ProjectSettings.asset`
- `ProjectSettings/InputManager.asset`
- `Assets/**/*.asmdef`
- `Assets/**/*.inputactions`
- `Assets/**/AddressableAssetSettings.asset`
- Render pipeline packages under `Packages/`
- DOTS packages such as `com.unity.entities`

State the detected or assumed Unity version, render pipeline, input stack, asset loading approach, and whether the repo already uses asmdefs, Addressables, ECS, or UI Toolkit.

## Workflow

1. Detect the active Unity setup and existing project conventions.
2. Pick the relevant reference file before going deep:
   - `references/project-architecture.md` for foldering, scenes, prefabs, ScriptableObjects, asmdefs, and serialization safety.
   - `references/runtime-patterns.md` for gameplay/runtime code, input, physics, animation, async work, and testing.
   - `references/assets-performance-builds.md` for loading, pooling, profiling, import settings, builds, and platform work.
   - `references/unity-6-reference.md` when the task is version-sensitive, upgrade-related, or depends on newer Unity APIs.
3. Prefer the smallest change that fits the existing architecture and asset pipeline.
4. Preserve serialized data, GUID stability, scene references, prefab overrides, and package intent.
5. Validate by checking compile-sensitive call sites, tests, and inspector-facing side effects before finishing.

## Response Contracts

### Implementation

- Name the affected files and explain the runtime impact in plain terms.
- Call out any inspector or project-setting steps the user still needs to do in Unity.
- If a change is serialization-sensitive, state how compatibility is preserved.

### Architecture Advice

- Recommend one concrete structure first.
- Explain tradeoffs only where they affect maintenance, content workflow, or performance.
- Stay aligned with the repo's current level of complexity instead of introducing a framework for its own sake.

### Review Mode

- Findings first.
- Prioritize engine-specific risks: GC churn, lifecycle bugs, lost serialized data, scene/prefab breakage, wrong thread use, bad asset loading patterns, and platform regressions.

## Non-Negotiable Rules

- Do not assume URP, HDRP, Built-in RP, DOTS, or Addressables without checking the project.
- Do not rename serialized fields casually. Use `FormerlySerializedAs` when preserving existing data matters.
- Do not move or rewrite scenes, prefabs, `.meta` files, or package configuration unless the task requires it.
- Do not use `Find`, `FindObjectOfType`, `SendMessage`, or `Resources.Load` in production code unless the repo already depends on them and the task is a minimal patch.
- Do not allocate in obvious hot paths without justification.
- Do not put physics writes in `Update` when `FixedUpdate` or a different design is required.
- Do not add large third-party frameworks when Unity built-ins or existing project patterns already solve the problem.
- Do not silently switch UI systems, render pipelines, or input stacks.

## Default Engineering Bias

- Prefer composition over deep inheritance.
- Prefer `ScriptableObject` for stable design-time data and configuration.
- Prefer `SerializeField private` over public mutable fields.
- Prefer cached references, event-driven flow, pooled objects, and batch-friendly content.
- Prefer asmdef boundaries when the repo already uses them or when a new module clearly benefits.
- Prefer Addressables for runtime-loaded content, but avoid repo-wide migration unless requested.
- Prefer official Unity packages and primary documentation when behavior may have changed recently.

## Reference Map

- `references/project-architecture.md`
- `references/runtime-patterns.md`
- `references/assets-performance-builds.md`
- `references/unity-6-reference.md`
