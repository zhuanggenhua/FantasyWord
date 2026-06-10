# Project Architecture

## Project Snapshot Checklist

Inspect these first:

- Unity version and package set
- Render pipeline and graphics package usage
- Folder layout under `Assets/`
- Existing `.asmdef` boundaries
- Scene bootstrap pattern
- Prefab-heavy or code-heavy feature flow
- Save data, localization, and content authoring patterns

## Recommended Default Structure

Use existing repo layout if it is coherent. If the project has no clear structure, prefer a light layout such as:

```text
Assets/_Game/
  Runtime/
    Core/
    Gameplay/
    UI/
    Systems/
  Editor/
  Art/
  Audio/
  Scenes/
  Settings/
```

Keep runtime and editor code separated. Add asmdefs only where they reduce compile scope or clarify ownership.

## Scene And Prefab Safety

- Prefer a stable bootstrap or entry scene instead of scattered singleton initialization.
- Avoid broad prefab rewrites when a component-level patch will do.
- Be careful with nested prefabs, override loss, and scene references.
- If a script rename or namespace move can break serialized references, preserve compatibility explicitly.
- Treat `.meta` stability as part of the feature, not an implementation detail.

## Data And Behavior Split

- Put authorable data in `ScriptableObject` assets.
- Keep runtime state in components, systems, or save models rather than mutating shared asset data.
- Use interfaces or narrow service abstractions for shared behaviors.
- Avoid global mutable singletons unless the repo already uses them and the task is incremental.

## Serialization Rules

- Preserve field names when possible.
- Use `FormerlySerializedAs` for renamed fields that already exist in scenes, prefabs, or assets.
- Prefer additive data migration over destructive asset rewrites.
- Use `OnValidate` for editor-time guardrails only, not gameplay logic.

## MonoBehaviour vs DOTS

Default to classic GameObject workflows unless the project already uses ECS or the task is explicitly data-oriented.

Choose MonoBehaviour when:

- Entity counts are modest
- Authoring happens mainly through prefabs and scenes
- Integration with animation, physics, and standard Unity tooling matters most

Choose DOTS when:

- The repo already uses Entities packages
- The workload is heavily parallel and data-oriented
- Entity counts or simulation cost justify the complexity

## Editor Tooling

- Put editor-only code under `Editor/` and, if used, editor asmdefs.
- Prefer custom inspectors, property drawers, validation windows, and menu items over manual asset edits.
- Keep editor tools deterministic and asset-safe.

## Common Anti-Patterns

- Public mutable fields everywhere
- Managers that both store data and own gameplay rules
- `DontDestroyOnLoad` chains with unclear lifetime
- Large god-scenes as the only composition root
- Hidden coupling through tags, names, or scene lookups
