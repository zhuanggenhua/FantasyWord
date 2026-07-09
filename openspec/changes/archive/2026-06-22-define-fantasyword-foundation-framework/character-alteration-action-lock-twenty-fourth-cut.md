# Character Alteration Action Lock Twenty Fourth Cut

## Scope

本次第二十四刀把 `CharacterAlterationRule` 从“只改变能力集合”推进到“可以锁定角色动作”。目标是让变形、感染、丧尸化、诅咒等规则能影响玩家控制和 AI 行为，例如丧尸化后不能交互、根须缠绕后不能移动、沉默类感染不能施法。

本刀仍不实现装备隐藏/掉落、背包锁定、控制权转移、AI 阵营改写、感染传播或完整形态阶段推进。

## Implemented Shape

- `CharacterAlterationRule` 新增 `lockedActions`：
  - 使用现有 `EActionFlags`，不新增第二套控制权限枚举。
  - 规则应用时通过来源键登记动作锁。
  - 规则撤回时按同一来源撤回动作锁。
  - 叠层规则撤回单层时只减少一层动作锁计数。
- `CharacterBase.ActionStateRuntime` 新增来源化动作锁计数：
  - `CharacterAbilitySourceKey -> CharacterActionLockRuntimeEntry`。
  - 同一规则多层叠加时会累计计数。
  - `IsActionLocked(...)` 会同时检查普通动作锁、变形/感染规则动作锁和持续效果动作锁。
- `CharacterBase.StateApi` 新增规则动作锁入口：
  - `ApplyAlterationActionLockRule(...)`
  - `RemoveAlterationActionLockRuleStack(...)`
  - `RemoveAllAlterationActionLockRules(...)`
  - `ClearAlterationActionLockRules()`
- `CharacterBase.Alterations` 读档恢复时会从 `activeAlterationRules` 重建非能力动作锁，但仍不重新应用能力授予/压制，避免和 `abilitySources / abilitySuppressions` 双重叠加。
- `Invoke-FoundationStaticGate.ps1` 已检查规则资产动作锁、来源化动作锁计数、StateApi 入口、激活/撤回/读档恢复路径。

## Runtime Meaning

- 玩家控制：`PlayerController` 的移动、交互、施法入口已经通过 `CharacterBase.Can(...)` 或能力权限判断，因此规则动作锁会直接影响本地玩家输入。
- AI 行为：`AIController` 移动走 `CharacterBase.CanMove()`，攻击走正式能力入口；规则动作锁会阻断对应 AI 移动和能力触发。
- 存档恢复：动作锁不单独写一份新字段，而是从已保存的 `activeAlterationRules` 重建，避免动作锁和规则激活列表形成第三套真相。

## Still Not Implemented

- 装备影响：隐藏、锁定、掉落、继续生效或禁用裁决。
- 背包影响：背包锁定、尸体容器化、物品可用性、负重或容器 owner 变化。
- 控制权影响：玩家失控、AI 接管、阵营切换、命令权限变化。
- 感染传播、形态阶段推进、可见反馈和端到端 smoke。

## Verification

- `powershell -ExecutionPolicy Bypass -File .\scripts\Invoke-FoundationStaticGate.ps1 -AsJson`：通过，`CharacterAlterationRuleMissingPatternCount = 0`、`CharacterBaseAlterationsMissingPatternCount = 0`、`CharacterBaseActionStateRuntimeMissingPatternCount = 0`、`CharacterBaseStateApiMissingPatternCount = 0`。
- `git diff --check -- Assets/Scripts/GameCore/Runtime/Database/Characters/CharacterAlterationRule.cs Assets/Scripts/GameCore/Runtime/Entities/Characters/CharacterBase.ActionStateRuntime.cs Assets/Scripts/GameCore/Runtime/Entities/Characters/CharacterBase.StateApi.cs Assets/Scripts/GameCore/Runtime/Entities/Characters/CharacterBase.Alterations.cs scripts/Invoke-FoundationStaticGate.ps1`：通过。
- `npx openspec validate define-fantasyword-foundation-framework --strict`：通过。
- AIBridge `assets-refresh {"options":"ForceSynchronousImport"}`：成功。
- AIBridge `editor-application-get-state`：`isPlaying = false`、`isCompiling = false`、`isUpdating = false`。
- 资产刷新后的最近 1 分钟 Console：`Error = []`、`Exception = []`。
