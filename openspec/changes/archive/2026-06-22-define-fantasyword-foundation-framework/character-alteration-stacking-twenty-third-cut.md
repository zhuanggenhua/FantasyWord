# Character Alteration Stacking Twenty Third Cut

## Scope

本次第二十三刀给 `CharacterAlterationRule` 补齐最小叠层、互斥组和优先级合同。目标是让变形、感染、丧尸化、诅咒等规则不再只是“有/没有”，而能表达同一角色身上多个奇特效果的基本共存关系。

本刀仍不实现完整形态系统、感染传播、装备裁决、背包裁决、控制权、AI、阵营或表现层换装。

## Implemented Shape

- `CharacterAlterationRule` 新增：
  - `ECharacterAlterationStackingPolicy.Unique / Stackable`。
  - `exclusiveGroupId`：非空时代表同一组身体状态或规则状态互斥。
  - `priority`：同一互斥组内，高优先级规则不会被低优先级规则覆盖；同级或更高优先级的新规则会替换旧规则。
  - `RemoveAbilityChangeStack(...)`：撤回一层规则带来的能力授予/压制。
- `CharacterBase.Alterations` 从 `HashSet<CharacterAlterationRule>` 改为 `Dictionary<CharacterAlterationRule, int>`：
  - 唯一规则仍只能激活一次。
  - 可叠层规则每次激活都会增加一层能力来源。
  - `RemoveCharacterAlterationRuleStack(...)` 可以只撤回一层。
  - `RemoveCharacterAlterationRule(...)` 仍按同一规则来源撤回全部能力授予/压制，并清掉该规则的激活计数。
- `activeAlterationRules` 存档字段保持数组形状不变：
  - 叠层规则通过重复保存同一个规则引用表达层数。
  - 读档时聚合重复引用恢复激活计数。
  - 读档仍不重新应用能力变化，能力来源和压制层继续由 `abilitySources / abilitySuppressions` 恢复，避免双重叠加。
- `Invoke-FoundationStaticGate.ps1` 已检查叠层策略、互斥组、优先级、计数字典、单层撤回和互斥替换入口。

## Runtime Meaning

- 感染类效果可以按层数推进，例如轻度感染、中度感染、丧尸化前兆不再只能用多个匿名字符串硬撑。
- 变形类效果可以配置成互斥组，例如狼人形态和熊形态不会同时保留能力来源。
- 更高优先级的形态或感染规则可以替换较低优先级规则，但低优先级规则不能覆盖高优先级状态。

## Still Not Implemented

- 叠层阈值、阶段推进、持续时间、感染传播和规则自动升级。
- 装备隐藏、锁定、掉落、继续生效或禁用裁决。
- 背包锁定、尸体容器化、控制权、AI、阵营和命令权限。
- 最小端到端 smoke：应用叠层规则、保存、加载、撤回单层和全部规则。

## Verification

- `git diff --check -- Assets/Scripts/GameCore/Runtime/Database/Characters/CharacterAlterationRule.cs Assets/Scripts/GameCore/Runtime/Entities/Characters/CharacterBase.Alterations.cs scripts/Invoke-FoundationStaticGate.ps1 openspec/changes/define-fantasyword-foundation-framework/character-alteration-rule-twenty-first-cut.md openspec/changes/define-fantasyword-foundation-framework/character-alteration-runtime-twenty-second-cut.md openspec/changes/define-fantasyword-foundation-framework/character-alteration-stacking-twenty-third-cut.md openspec/changes/define-fantasyword-foundation-framework/tasks.md openspec/changes/define-fantasyword-foundation-framework/composite-sandbox-character-foundation-tasks.md openspec/changes/define-fantasyword-foundation-framework/verification-notes.md`：通过。
- `powershell -ExecutionPolicy Bypass -File .\scripts\Invoke-FoundationStaticGate.ps1 -AsJson`：通过，`CharacterAlterationRuleMissingPatternCount = 0`，`CharacterBaseAlterationsMissingPatternCount = 0`。
- `npx openspec validate define-fantasyword-foundation-framework --strict`：通过。
- AIBridge `assets-refresh {"options":"ForceSynchronousImport"}`：成功。
- AIBridge `editor-application-get-state`：`isPlaying = false`、`isCompiling = false`、`isUpdating = false`。
- 资产刷新后的最近 1 分钟 Console：`Error = []`、`Exception = []`。
