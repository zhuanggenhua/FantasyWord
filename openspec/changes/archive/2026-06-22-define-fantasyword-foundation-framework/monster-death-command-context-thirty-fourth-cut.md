# 第三十四刀：怪物死亡命令跟随奖励接收者

## 背景

第三十三刀把无显式 actor 的脚本/交互命令默认目标改成当前受控角色。但怪物死亡奖励链里还有一个更具体的事实：`Monster` 已经解析出 `rewardReceiver`，并用它发放掉落、经验、金钱和奖励表现；随后 `MonsterSheet.ExecuteOnDeath()` 却仍用无 actor 的脚本上下文执行资产命令。

这会让怪物死亡命令在多角色、召唤物、AI 队友或非当前受控角色击杀时，可能误落到当前受控角色，而不是奖励接收者。

## 本刀变更

- `MonsterSheet.ExecuteOnDeath(...)` 改为接收 `GameCommandContext`。
- `Monster.GrantKillRewards(...)` 调用死亡命令时，传入由奖励接收者解析出的上下文。
- 如果奖励接收者正是当前受控角色，则使用 `LocalPlayer(receiver)`；否则使用 `Unknown(receiver)`，保留 actor，但不伪造本地玩家或 AI 来源。
- `Invoke-FoundationStaticGate.ps1` 新增 `MonsterDeathCommandContextMissingPatternCount / MonsterDeathCommandContextDisallowedPatternCount`，防止怪物死亡命令回退到无 actor 脚本上下文。

## 边界

- 不修改怪物掉落表、经验表、金钱表或奖励数值。
- 不改变无伤害来源时回退玩家实例作为奖励接收者的旧规则。
- 不处理 `Quest`、`DialogueNode`、`GameConfig` 玩家死亡动作等全局或剧情回调；这些入口需要单独裁决谁是 actor。
- 不实现控制组、多选、AI 来源归类、远程访客或网络 ownership。
