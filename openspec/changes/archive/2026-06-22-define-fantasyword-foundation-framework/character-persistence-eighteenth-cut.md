# Character Persistence Eighteenth Cut

## Scope

本次第十八刀继续清掉角色正式存档协议里的第二真相。目标不是新增能力系统，而是把 `CharacterBase` 的能力来源写盘彻底收回 `abilitySources`，不再同时保留旧 `bonusAbilities` 汇总镜像和读档回退。

## Implemented Shape

- `CharacterBaseDataBlock` 已删除 `bonusAbilities` 字段。
- `CharacterBase.Persistence.OnSave(...)` 不再把来源桶再镜像写成旧汇总字典。
- `CharacterBase.Persistence.OnLoad(...)` 不再在 `abilitySources` 缺席时回退 `bonusAbilities` 恢复。
- `RestoreAbilitySources(...)` 现在只负责正式来源桶恢复，不再返回“是否需要回退旧镜像”的布尔分支。
- `Invoke-FoundationStaticGate.ps1` 已把 `CharacterBaseDataBlock.bonusAbilities`、`characterBlock.bonusAbilities = ...` 和 `RestoreBonusAbilities(...)` 记为回归违规。

## Runtime Meaning

- 角色能力来源存档现在只认“能力是谁给的、给了几层、结束时该撤哪一层”。
- 同一角色不再把 `abilitySources` 和 `bonusAbilities` 两份结构同时写盘，再靠读档时选一份恢复。
- 这一步只删除角色级旧镜像，不改变装备、召唤、物品、脚本、状态效果、变形或感染这些来源桶本身。

## Still Not Implemented

- 变形、感染、丧尸化的具体业务规则。
- 装备/背包/控制权/AI 影响。
- 保存/加载端到端 smoke。

## Verification

- `Invoke-FoundationStaticGate.ps1 -AsJson`：通过，`CharacterBaseContractsDisallowedPatternCount = 0`、`CharacterBasePersistenceMissingPatternCount = 0`、`CharacterBasePersistenceDisallowedPatternCount = 0`。
- `npx openspec validate define-fantasyword-foundation-framework --strict`：通过。
- 定向 `git diff --check`：通过。
