# Ability Source Twentieth Cut

## Scope

本次第二十刀继续收紧角色能力来源的正式入口。目标不是改动来源桶协议编号，而是删除匿名 `LegacyBonus` 运行时入口，让新的能力增减必须显式携带来源键。

## Implemented Shape

- [CharacterBase.Abilities.cs](C:/Gamedev/Unity/Project/FantasyWord/Assets/Scripts/GameCore/Runtime/Entities/Characters/CharacterBase.Abilities.cs) 已删除 `AddBonusAbility(AbilitySheet, int)` 与 `RemoveBonusAbility(AbilitySheet)`。
- [CharacterBase.AbilitySetRuntime.cs](C:/Gamedev/Unity/Project/FantasyWord/Assets/Scripts/GameCore/Runtime/Entities/Characters/CharacterBase.AbilitySetRuntime.cs) 已删除匿名 `LegacyBonus` 注册/撤回重载。
- [CharacterBase.Contracts.cs](C:/Gamedev/Unity/Project/FantasyWord/Assets/Scripts/GameCore/Runtime/Entities/Characters/CharacterBase.Contracts.cs) 当前只把 `ECharacterAbilitySourceKind.LegacyBonus` 与 `CharacterAbilitySourceKey.LegacyBonus` 保留为历史协议保留位，不再作为新的正式运行时入口。
- [Invoke-FoundationStaticGate.ps1](C:/Gamedev/Unity/Project/FantasyWord/scripts/Invoke-FoundationStaticGate.ps1) 已把这组旧匿名入口记成回归违规。

## Runtime Meaning

- 角色获得或失去临时能力时，正式代码现在必须明确说明“是谁授予的、是谁撤回的”。
- 来源桶现在不仅是持久化真相，也是运行时能力增减的唯一正式入口。
- 历史 `LegacyBonus` 只留下协议编号保留位，避免旧存档的来源种类整体错位。

## Still Not Implemented

- 变形、感染、丧尸化的具体业务规则。
- 装备/背包/控制权/AI 影响。
- 保存/加载端到端 smoke。

## Verification

- `Invoke-FoundationStaticGate.ps1 -AsJson`：通过，`CharacterBaseAbilitiesMissingPatternCount = 0`、`CharacterBaseAbilitiesDisallowedPatternCount = 0`、`CharacterBaseAbilitySetRuntimeMissingPatternCount = 0`、`CharacterBaseAbilitySetRuntimeDisallowedPatternCount = 0`。
- `npx openspec validate define-fantasyword-foundation-framework --strict`：通过。
- 定向 `git diff --check`：通过。
- `rg -n "AddBonusAbility|RemoveBonusAbility|LegacyBonus" Assets -g "*.unity" -g "*.prefab" -g "*.asset" -g "*.meta"`：无命中，说明正式资产里没有这组旧匿名入口的 UnityEvent/Prefab/Scene 引用。
