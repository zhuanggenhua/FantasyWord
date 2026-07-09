# Attribute Bootstrap Twenty-First Cut

## Scope

本次第二十一刀继续收紧属性真相的过渡窗口。目标不是删除 `AttributeBootstrapBuffer`，而是把它从“正式 ASC 还没 ready 就一直宽容”的长期 fallback，收成只允许 `Awake` 启动阶段临时借用的 bootstrap 缓冲。

## Implemented Shape

- [CharacterBase.cs](C:/Gamedev/Unity/Project/FantasyWord/Assets/Scripts/GameCore/Runtime/Entities/Characters/CharacterBase.cs) 已新增 `m_allowAttributeBootstrapRead`，并在 `Awake()` 里于 `InitializeFormalAbilitySystemFromCurrentAttributes()` 返回后立即关闭。
- [CharacterBase.Resources.cs](C:/Gamedev/Unity/Project/FantasyWord/Assets/Scripts/GameCore/Runtime/Entities/Characters/CharacterBase.Resources.cs) 的 `ShouldAllowAttributeBootstrapRead()` 已改为只认启动窗口标志，不再使用 `!m_isFormalAbilitySystemReady`。
- [Invoke-FoundationStaticGate.ps1](C:/Gamedev/Unity/Project/FantasyWord/scripts/Invoke-FoundationStaticGate.ps1) 已同步追平到这版 owning-shape，并把旧表达式记成回归违规。

## Runtime Meaning

- 正式角色 prefab 既然已经强制挂 `AbilitySystemComponent`，运行态属性读取就不应再因为正式链路损坏而长期默默吃旧缓冲。
- `AttributeBootstrapBuffer` 现在仍可服务启动前快照、旧档导入和正式镜像回填，但它不再是正式运行态的兜底真相。
- 如果 `Awake` 结束后正式 ASC 或 AttributeSet 仍不可用，当前应直接报错暴露配置或生命周期问题，而不是继续双轨。

## Still Not Implemented

- `AttributeBootstrapBuffer` 的最终退场。
- 持续效果 live truth 与能力规则的后续收口。
- AIBridge 运行态 smoke。

## Verification

- `Invoke-FoundationStaticGate.ps1 -AsJson`：通过，`CharacterBaseMainMissingPatternCount = 0`、`CharacterBaseResourcesMissingPatternCount = 0`、`CharacterBaseResourcesDisallowedPatternCount = 0`。
- `npx openspec validate define-fantasyword-foundation-framework --strict`：通过。
- 定向 `git diff --check`：通过。
