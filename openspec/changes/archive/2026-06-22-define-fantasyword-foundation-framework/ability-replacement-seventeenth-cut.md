# Ability Replacement Seventeenth Cut

## Scope

本次第十七刀建立并追平“来源化能力替换”执行壳：一个持续效果可以同时压制一组既有能力，并授予一组替代能力。它服务变形、感染、丧尸化、诅咒和奇特 Roguelike 效果中“保留部分能力、替换部分能力”的用户故事，但当前目标仍是框架闭包，不实现完整形态系统、感染规则、装备裁决、背包裁决、控制权或 AI 变化。

## Implemented Shape

- 新增 `TemporalAbilityReplacementEffect`：
  - `OnApply()` 先按 `StatusEffect` 来源压制旧能力，再按同一来源授予替代能力。
  - `OnRuntimeStateRestored()` 在读档恢复持续效果时重建压制和授予。
  - `OnCompleted()` 同时调用 `RemoveAllStatusEffectAbilities(...)` 与 `RemoveAllStatusEffectAbilitySuppressions(...)`，只撤回该状态来源的替代能力和压制层。
  - `TryCapturePersistedState(...)` 分别保存被授予能力和被压制能力的数据库引用。
  - `RestorePersistedState(...)` 分别恢复 `grantedAbilities` 与 `suppressedAbilities`。
- 该效果复用第十四到第十六刀已经落地的角色来源键、能力授予桶和能力压制桶，不新增第二套能力系统。
- `FormalGasAssetTemplateBootstrap` 已同步补 `正式持续效果模板-能力替换.asset`，并把 `TemporalAbilityReplacementEffect` 写入正式能力表模板第 9 个持续效果位。
- `Invoke-FoundationStaticGate.ps1` 已纳入第十七刀文件、持久化字段、应用/恢复/完成撤回和 formal 模板第 9 位检查。
- `FormalGasAssetTemplateBootstrap.EnsureMinimalFormalGasTemplateAssets()` 当前再次执行时 `UpdatedAssets = []`，说明磁盘模板资产链已追平，不再存在“代码加了 replacement，但模板没跟上”的缺口。

## Runtime Meaning

- 角色被变成狼、丧尸或感染体时，可以在状态持续期间禁用原有施法/对话能力，同时授予撕咬、感染传播或野兽动作。
- 多个状态同时替换能力时，每个状态只撤回自己的授予和压制来源，不误恢复仍被其它来源压制的能力，也不误删装备、物品学习或永久成长授予的能力。
- 替换效果不销毁原能力实例；旧能力被压制，新能力按状态来源临时授予，结束后回到原能力集合。

## Still Not Implemented

- 形态、感染、丧尸化的稳定业务 id、规则资产和内容生成入口。
- 装备在形态变化时继续生效、隐藏、锁定、掉落或被禁用的裁决。
- 背包锁定、掉落、尸体容器化和控制组 UI。
- 控制权、AI、阵营、交互权限、命令权限和可见反馈。
- 保存/加载端到端 smoke 中实际构造一个带 `TemporalAbilityReplacementEffect` 的资产并验证替换恢复。

## Verification

- AIBridge `editor-application-get-state`：`isPlaying = false`、`isCompiling = false`、`isUpdating = false`。
- AIBridge `assets-refresh {"options":"ForceSynchronousImport"}`：成功。
- AIBridge `script-execute -> FormalGasAssetTemplateBootstrap.EnsureMinimalFormalGasTemplateAssets()`：成功，`UpdatedAssets = []`。
- AIBridge `script-execute -> FormalGasMappingAudit.Inspect()`：通过，`HasMissingMappings = false`、`HasCoverageGaps = false`、`TemporalEffectReferenceCount = 9`、`TemporalEffectMappedCount = 9`、`UncoveredTemporalEffectTypes = []`。
- `npx openspec validate define-fantasyword-foundation-framework --strict`：通过。
- 最近 10 分钟 Console 中仍可见 AIBridge 自身 `script-execute Out of memory` 与 heartbeat 原子写入 fallback 的工具日志；这些是桥接工具噪音，不是 `FantasyWord` 运行时代码回归。
