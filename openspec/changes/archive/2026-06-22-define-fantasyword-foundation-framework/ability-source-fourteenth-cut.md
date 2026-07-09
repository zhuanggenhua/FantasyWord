# Ability Source Fourteenth Cut

## Scope

本次第十四刀把状态效果、变形和感染授予能力的来源与回滚合同接到角色正式能力运行时。目标不是实现具体变形、感染、丧尸化规则，而是先保证这些规则未来改动能力时不会继续混进永久能力、装备能力或旧 `bonusAbilities` 汇总。

## Implemented Shape

- `CharacterBase` 新增临时来源能力 API：
  - `AddSourcedBonusAbility(...)`
  - `RemoveSourcedBonusAbility(...)`
  - `RemoveAllSourcedBonusAbilities(...)`
- `CharacterBase` 新增三类明确来源 helper：
  - `AddStatusEffectAbility / RemoveStatusEffectAbility / RemoveAllStatusEffectAbilities`
  - `AddTransformationAbility / RemoveTransformationAbility / RemoveAllTransformationAbilities`
  - `AddInfectionAbility / RemoveInfectionAbility / RemoveAllInfectionAbilities`
- `CharacterAbilitySetRuntime` 新增按 `CharacterAbilitySourceKey` 投影来源快照的入口。
- 临时来源 API 只接受 `StatusEffect / Transformation / Infection`，避免外部调用者误用它批量删除装备、物品学习、脚本或召唤来源。
- 状态效果来源 id 使用 `效果类型全名:runtimeKey`；变形和感染来源 id 由调用方传入稳定规则 id。
- 批量回滚返回被移除的来源快照，方便未来表现层或日志层说明“哪些能力因形态/感染/状态结束而失效”。

## Why This Is Needed

目标游戏受 `Kenshi / Baldur's Gate / ToME4` 影响，角色能力会经常被临时规则重写：

- 角色变成熊、亡灵或史莱姆时，应保留部分种族/职业/学习能力，同时替换动作能力。
- 角色感染或丧尸化时，可能失去开锁、交涉、施法等能力，但获得啃咬、感染传播或不眠等能力。
- 临时祝福、诅咒、药剂和畸变效果可能只持续一段时间，结束后必须撤回自己授予的能力，而不能误删同名装备能力或永久学习能力。

因此能力来源必须能回答“这项能力是谁给的、给了几层、结束时撤哪几层”。这比只保存能力总数更适合复杂 RPG、RTS 队伍和未来主机权威裁决。

## Still Not Implemented

这刀没有实现以下内容：

- 变形/感染/丧尸化的实体数据模型。
- 变形后装备是禁用、掉落、隐藏、锁定还是继续生效。
- 背包是保留、锁定、转移、掉落还是变成尸体/容器库存。
- 阵营、AI、控制权、交互权限和命令权限变化。
- 保存/加载后同时验证状态效果、能力来源和状态结束回滚的 PlayMode smoke。

这些仍属于 `P0 Ability And Status Ownership` 后续切片。

## Verification Hook

`Invoke-FoundationStaticGate.ps1` 已把本次新增的临时来源 API、三类来源 helper 和按来源快照撤回入口纳入门禁。后续若这些入口被删除或退回旧汇总字段，foundation gate 会失败。
