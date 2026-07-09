# Formal Temporal Spec Snapshot Twenty-Second Cut

## Scope

本次第二十二刀继续收口 formal effect 规则侧的读取边界。目标不是改动持续效果语义，而是把 formal live spec 的读取从“多个方法各自直接扫 `GameplayEffectContainer`”收成统一快照入口。

## Implemented Shape

- [CharacterBase.GASRuntime.cs](C:/Gamedev/Unity/Project/FantasyWord/Assets/Scripts/GameCore/Runtime/Entities/Characters/CharacterBase.GASRuntime.cs) 已新增 `CreateLiveFormalTemporalEffectSpecSnapshot(...)` 与 `ContainsLiveFormalTemporalEffectSpec(...)`。
- formal 展示投影、spec 查找、写盘 runtimeKey 收集、formal 清理和叠层目标查找，当前都先消费同一份 `GameplayEffectSpec[]` 快照。
- `TrackFormalTemporalGameplayEffectSpec(...)` 与 `CollectFormalTemporalEffectRuntimeKeys(...)` 已同步改成接收 formal spec 快照，不再直接接 `AbilitySystemComponent` 去读 live 容器。
- [Invoke-FoundationStaticGate.ps1](C:/Gamedev/Unity/Project/FantasyWord/scripts/Invoke-FoundationStaticGate.ps1) 已同步要求这组快照 helper 存在，并把旧 `AbilitySystemComponent` 形参签名与旧 `GameplayEffects().Contains(...)` 形状记成回归违规。

## Runtime Meaning

- formal effect 规则真相仍然在 EX-GAS `GameplayEffectContainer`，但项目侧读取这份真相时，现在先固定成一份明确快照，再分发给多个角色语义入口消费。
- `m_formalTemporalGameplayEffectSpecs` 继续只是 runtimeKey 到 live spec 的快速索引，不升格为第二真相。
- 这一步收掉的是“formal live truth 从哪读”的边界漂移，不是新增项目侧容器，也不是删除 `m_effects` 执行壳注册表。

## Still Not Implemented

- `m_effects` 执行壳注册表的最终退场。
- unmapped fallback 共享合同对旧 payload 细节的进一步去依赖。
- AIBridge 运行态 smoke。

## Verification

- `Invoke-FoundationStaticGate.ps1 -AsJson`：通过，`CharacterBaseGasRuntimeMissingPatternCount = 0`、`CharacterBaseGasRuntimeDisallowedPatternCount = 0`。
- `npx openspec validate define-fantasyword-foundation-framework --strict`：通过。
- 定向 `git diff --check`：通过。
