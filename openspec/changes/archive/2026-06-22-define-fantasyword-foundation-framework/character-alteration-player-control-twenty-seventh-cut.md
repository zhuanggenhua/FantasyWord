# Character Alteration Player Control: Twenty-Seventh Cut

## 背景

本轮继续服务 Kenshi、博德之门和 ToME4 风格的复杂角色规则：角色可能因为变形、感染、丧尸化、精神控制或失控形态，保留一部分能力与背包事实，同时失去玩家直接操控权。

第二十四到二十六刀已经让规则可以改变能力、动作、背包/装备主动操作和阵营，但还没有回答一个关键问题：如果当前玩家正在控制的角色变成丧尸或失控形态，输入目标是否还应该继续留在它身上。

## 用户故事

- 作为玩家，我控制一名队员时，如果该角色被感染并进入不可控丧尸阶段，游戏应立刻停止把我的移动、交互和施法输入送给它。
- 作为玩家，我仍应能继续控制尚可控的玩家实例或队伍成员，而不是因为一个角色失控导致输入链路挂在无效目标上。
- 作为系统设计者，我希望变形/感染规则能声明“锁定玩家直接控制权”，但不要求这一步同时实现 AI 接管、控制组、多选或联机访客权限。

## 实现

- `CharacterAlterationRule` 新增 `lockPlayerControl` 配置，规则生效期间按 `CharacterAbilitySourceKey` 对角色加一层玩家控制锁。
- `CharacterBase.StateApi` 新增来源化玩家控制锁运行时，并暴露 `CanBePlayerControlled()`。角色死亡或存在任意有效控制锁时，不允许作为玩家当前控制对象。
- `CharacterBase.Alterations` 在规则应用、撤回、单层撤回、读档恢复和清空激活规则时同步重建控制锁，并通知 `PlayerSystem` 复核当前受控对象。
- `PlayerSystem` 拒绝把不可玩家控制的角色设为当前控制对象；如果当前受控角色被规则锁定，则优先回退到仍可控的玩家实例，否则清空输入目标。
- `PlayerController` 在每帧输入更新和命令执行时检查 `CanBePlayerControlled()`，并用 `EPlayerCommandFailureReason.ControlLocked` 区分控制权锁定和普通动作状态阻断。
- `Invoke-FoundationStaticGate.ps1` 已加入控制权锁相关静态门禁，覆盖规则字段、运行时状态、PlayerSystem 复核和 PlayerController 拦截。

## 边界

本刀只建立“规则可以夺走玩家直接控制权”的最小正式合同。

尚未实现：

- AI 强制接管失控角色。
- 控制组、多选、编队和队伍控制权重分配。
- 远程访客、主机权威、网络 ownership 或 RPC。
- 派系关系、长期仇恨和感染传播策略。
- 失控后装备强制脱装、装备隐藏/失效/保留、尸体容器。

## 验证

本刀验收结果：

- `git diff --check` 定向检查本轮文件通过。
- `scripts/Invoke-FoundationStaticGate.ps1 -AsJson` 通过，新增 `PlayerSystemPlayerControlMissingPatternCount = 0`，并保持 `CharacterAlterationRuleMissingPatternCount = 0 / CharacterBaseAlterationsMissingPatternCount = 0 / CharacterBaseStateApiMissingPatternCount = 0`。
- `npx openspec validate define-fantasyword-foundation-framework --strict` 通过。
- AIBridge `assets-refresh` 成功；Editor 状态为 `isPlaying = false / isCompiling = false / isUpdating = false`；资产刷新后的最近 1 分钟 `Error = [] / Exception = []`。

补充：本轮 Unity 复核曾暴露 `CharacterBase.StateApi.cs` 中一处旧调用形状未跟上 `RefreshFormalTemporalEffectRuleOnStack(runtimeKey, activeEffect, stackedEffect)` 当前签名，已按当前 `runtimeKey` 快照链修正，不改变本刀控制权规则。
