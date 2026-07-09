# Character Alteration Runtime Twenty Second Cut

## Scope

本次第二十二刀把第二十一刀的 `CharacterAlterationRule` 接到角色运行时和存档：角色可以记录当前激活的变形/感染规则资产，并在保存/加载时保留这份规则激活列表。

本刀仍不实现完整形态系统、感染传播、装备裁决、背包裁决、控制权、AI 或表现层换装。

## Implemented Shape

- 新增 `CharacterBase.Alterations.cs`：
  - `ApplyCharacterAlterationRule(...)`：应用规则资产的能力授予/压制，并把规则登记为当前激活。
  - `RemoveCharacterAlterationRule(...)`：按规则来源撤回授予和压制层，并从激活列表移除。
  - `CreateActiveAlterationRuleSnapshots()`：保存当前激活规则资产引用。
  - `RestoreActiveAlterationRules(...)`：读档恢复激活规则列表。
- `CharacterBaseDataBlock` 新增 `activeAlterationRules`。
- `CharacterBase.Persistence` 保存 `activeAlterationRules`，并在读档时恢复激活规则列表。
- 读档时不重新调用规则资产的应用逻辑，避免和已有 `abilitySources / abilitySuppressions` 双重叠加；能力来源和压制层仍由现有来源桶恢复。
- `Invoke-FoundationStaticGate.ps1` 已检查 `CharacterBase.Alterations.cs`、`activeAlterationRules`、保存/恢复入口和门禁报表。

## Runtime Meaning

- 后续完整变形/感染系统可以查询角色当前激活的规则资产，而不是只从能力来源里反推状态。
- 能力变化仍由来源桶持久化；规则激活列表记录“为什么这些来源还应该存在”。
- 若规则资产未登记进 `DatabaseRegistry`，第二十一刀的来源键创建会失败，第二十二刀也不会把该规则登记成激活状态。

## Still Not Implemented

- 激活规则的叠层、互斥、优先级、阶段推进和持续时间。
- 装备隐藏、锁定、掉落、继续生效或禁用裁决。
- 背包锁定、尸体容器化、控制权、AI、阵营和命令权限。
- 最小端到端 smoke：应用规则、保存、加载、撤回规则并确认能力来源不重复叠加。

## Verification

- `powershell -ExecutionPolicy Bypass -File .\scripts\Invoke-FoundationStaticGate.ps1 -AsJson`：通过，`CharacterBaseAlterationsMissingPatternCount = 0`。
- `git diff --check -- Assets/Scripts/GameCore/Runtime/Database/Characters/CharacterAlterationRule.cs Assets/Scripts/GameCore/Runtime/Entities/Characters/CharacterBase.Alterations.cs Assets/Scripts/GameCore/Runtime/Entities/Characters/CharacterBase.Contracts.cs Assets/Scripts/GameCore/Runtime/Entities/Characters/CharacterBase.Persistence.cs scripts/Invoke-FoundationStaticGate.ps1 openspec/changes/define-fantasyword-foundation-framework/character-alteration-rule-twenty-first-cut.md openspec/changes/define-fantasyword-foundation-framework/character-alteration-runtime-twenty-second-cut.md openspec/changes/define-fantasyword-foundation-framework/tasks.md openspec/changes/define-fantasyword-foundation-framework/composite-sandbox-character-foundation-tasks.md openspec/changes/define-fantasyword-foundation-framework/verification-notes.md`：通过。
- `npx openspec validate define-fantasyword-foundation-framework --strict`：通过。
- AIBridge `assets-refresh {"options":"ForceSynchronousImport"}`：成功，并生成 `CharacterBase.Alterations.cs.meta`。
- AIBridge `editor-application-get-state`：`isPlaying = false`、`isCompiling = false`、`isUpdating = false`。
- 资产刷新后的最近 1 分钟 Console：`Error = []`、`Exception = []`。
