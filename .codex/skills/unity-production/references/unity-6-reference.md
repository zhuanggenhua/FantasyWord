# Unity 6 Reference

Last reviewed: 2026-03-30

## Version Assumptions

- Treat `6000.x` projects as Unity 6 family projects.
- If the repo is pinned to 2021 LTS or 2022 LTS, do not force Unity 6 patterns into it.
- If the user asks for the latest Unity behavior, verify it with official Unity documentation before answering.

## Practical Unity 6 Watchouts

- UI Toolkit is mature enough to be a default option for new screen-space UI, but many repos still rely on UGUI.
- Input System should be preferred for new work, but migration of legacy input code must be explicit.
- URP and HDRP custom rendering work is more RenderGraph-oriented than older examples.
- DOTS and Entities APIs differ substantially from pre-1.0 tutorials.
- Addressables and package APIs may differ from older blog posts or pre-Unity-6 examples.

## Safe Guidance

- Detect the installed packages before recommending APIs.
- Prefer official Unity docs and package manuals over third-party tutorials when package versions matter.
- When giving migration advice, distinguish clearly between incremental patching and full subsystem migration.

## Official Starting Points

- Unity Manual: `https://docs.unity3d.com/6000.0/Documentation/Manual/`
- Unity Scripting API: `https://docs.unity3d.com/6000.0/Documentation/ScriptReference/`
- Upgrade guides: `https://docs.unity3d.com/6000.0/Documentation/Manual/upgrade-guides.html`
- Unity release hub: `https://unity.com/releases/editor/archive`

## Common Deprecation Direction

- Prefer Input System over legacy `Input.*`
- Prefer Addressables over `Resources.Load`
- Prefer SRP-native rendering paths over Built-in RP-era hooks
- Prefer current Entities APIs only when the project already uses DOTS or clearly needs it
