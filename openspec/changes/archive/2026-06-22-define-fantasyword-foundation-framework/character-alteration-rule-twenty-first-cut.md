# Character Alteration Rule Twenty First Cut

## Scope

本次第二十一刀建立“角色改变规则”的最小数据资产：`CharacterAlterationRule`。它服务变形、感染、丧尸化这类会改变角色能力集合的规则，让它们不再只靠调用方传入任意字符串 id。

本刀仍不实现完整形态系统，也不裁决装备、背包、控制权、AI、阵营或表现层换装。

## Implemented Shape

- 新增 `CharacterAlterationRule`：
  - 作为 `DatabaseEntry` 资产进入项目正式数据层。
  - 规则类型当前为 `Transformation / Infection`；丧尸化暂按感染类规则处理，若后续需要独立来源类型再单独裁决。
  - 规则资产保存 `grantedAbilities` 和 `suppressedAbilities` 两组能力引用。
  - 规则生效时先压制既有能力，再授予替代能力。
  - 规则撤回时按同一来源键撤回全部授予能力和压制层。
- 来源 id 不再由调用方随手传字符串，而是用该规则资产在 `DatabaseRegistry` 中登记的 GUID。
- 如果规则资产没有登记进 `DatabaseRegistry`，`TryCreateAbilitySourceKey(...)` 直接失败，不伪造 `default` 来源，也不触发数据库断言日志。
- `Invoke-FoundationStaticGate.ps1` 已检查第二十一刀文件、来源键解析、数据库登记查询、授予/压制和撤回入口。

## Runtime Meaning

- 变狼规则、感染规则、丧尸化规则可以成为稳定资产，能力变化来源可保存、可审计、可回滚。
- 读档时现有角色能力来源桶仍能恢复来源和压制层；后续完整形态/感染系统只需要保存“当前角色身上有哪些规则资产处于激活态”，而不是重新发明能力来源系统。
- 同一个角色可同时受到多个规则影响。每个规则只撤回自己资产 GUID 对应的来源，不误删装备、物品学习、永久成长或其它状态来源。

## Still Not Implemented

- 当前角色身上已激活的形态/感染规则列表及其持久化。
- 形态/感染叠层优先级、互斥组、阶段推进和感染传播。
- 装备隐藏、锁定、掉落、继续生效或禁用裁决。
- 背包锁定、尸体容器化、控制权、AI、阵营和命令权限。
- 最小端到端 smoke：带规则资产的角色应用、保存、加载、撤回。

## Verification

- `powershell -ExecutionPolicy Bypass -File .\scripts\Invoke-FoundationStaticGate.ps1 -AsJson`：通过，`CharacterAlterationRuleMissingPatternCount = 0`。
- `git diff --check -- Assets/Scripts/GameCore/Runtime/Database/Characters/CharacterAlterationRule.cs scripts/Invoke-FoundationStaticGate.ps1 openspec/changes/define-fantasyword-foundation-framework/character-alteration-rule-twenty-first-cut.md openspec/changes/define-fantasyword-foundation-framework/tasks.md openspec/changes/define-fantasyword-foundation-framework/composite-sandbox-character-foundation-tasks.md openspec/changes/define-fantasyword-foundation-framework/verification-notes.md`：通过。
- `npx openspec validate define-fantasyword-foundation-framework --strict`：通过。
- AIBridge `assets-refresh {"options":"ForceSynchronousImport"}`：成功，并生成 `CharacterAlterationRule.cs.meta`。
- AIBridge `editor-application-get-state`：`isPlaying = false`、`isCompiling = false`、`isUpdating = false`。
- 资产刷新后的最近 1 分钟 Console：`Error = []`、`Exception = []`。
