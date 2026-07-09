# Character Persistence Nineteenth Cut

## Scope

本次第十九刀处理的是第十八刀删完 `bonusAbilities` 镜像协议后留下的最后一段死口。目标不是新增能力系统，而是把角色能力来源的正式持久化形状彻底固定为“只认来源桶”，不再保留任何只服务旧镜像汇总的伪正式读取口。

## Implemented Shape

- [CharacterBase.AbilitySetRuntime.cs](C:/Gamedev/Unity/Project/FantasyWord/Assets/Scripts/GameCore/Runtime/Entities/Characters/CharacterBase.AbilitySetRuntime.cs) 已删除 `CreateBonusAbilityEntrySnapshot()`。
- [CharacterBase.Persistence.cs](C:/Gamedev/Unity/Project/FantasyWord/Assets/Scripts/GameCore/Runtime/Entities/Characters/CharacterBase.Persistence.cs) 当前正式写盘继续只通过 `CreateAbilitySourceDataBlocks(...)` 导出 `abilitySources`。
- [Invoke-FoundationStaticGate.ps1](C:/Gamedev/Unity/Project/FantasyWord/scripts/Invoke-FoundationStaticGate.ps1) 不再要求 `CreateBonusAbilityEntrySnapshot()` 存在，并把旧 `GetBonusAbilityEntries()` 与旧 `CreateBonusAbilityEntrySnapshot()` 一并记成回归违规。

## Runtime Meaning

- 角色能力来源的正式持久化现在只关心“哪项能力由哪个来源授予了几层”。
- 角色运行时不再额外投影一份“把所有来源加总后的 bonus ability 总数快照”给旧镜像协议使用。
- 这一步不改变装备、物品学习、召唤、状态效果、变形或感染这些来源桶自身的语义。

## Still Not Implemented

- 变形、感染、丧尸化的具体业务规则。
- 装备/背包/控制权/AI 影响。
- 保存/加载端到端 smoke。

## Verification

- `Invoke-FoundationStaticGate.ps1 -AsJson`：通过，`CharacterBaseAbilitySetRuntimeMissingPatternCount = 0`、`CharacterBaseAbilitySetRuntimeDisallowedPatternCount = 0`、`CharacterBasePersistenceMissingPatternCount = 0`、`CharacterBasePersistenceDisallowedPatternCount = 0`。
- `npx openspec validate define-fantasyword-foundation-framework --strict`：通过。
- 定向 `git diff --check`：通过。
