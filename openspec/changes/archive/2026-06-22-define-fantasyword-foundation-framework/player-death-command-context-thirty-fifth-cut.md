# 第三十五刀：玩家死亡动作带死亡玩家上下文

## 背景

第三十四刀已经让怪物死亡资产命令跟随奖励接收者，但玩家主角死亡链里仍有一个明确丢上下文的位置：`Hero.OnDeath()` 会把死亡的 `Hero` 传给 `PlayerSystem.NotifyHeroKilled(hero)`，随后 `GameConfig.ExecutePlayerDeathAction()` 却用无 actor 的脚本上下文执行配置里的死亡命令。

这会让死亡后的复活、移动、治疗、效果或其它配置命令无法明确知道“死的是哪个角色”。在多角色、临时控制、变形失控或未来有限联机兼容语境下，玩家死亡动作必须带上死亡玩家实体。

## 本刀变更

- `GameConfig.ExecutePlayerDeathAction(...)` 改为接收 `GameCommandContext`。
- `PlayerSystem.NotifyHeroKilled(...)` 在确认死亡对象是玩家主角后，用 `GameCommandContext.LocalPlayer(hero)` 执行玩家死亡动作。
- `Invoke-FoundationStaticGate.ps1` 新增 `PlayerDeathCommandContextMissingPatternCount / PlayerDeathCommandContextDisallowedPatternCount`，防止玩家死亡动作回退到无 actor 的脚本上下文。

## 边界

- 不修改玩家死亡动作资产里配置的具体命令。
- 不改变玩家主角死亡时中断对话、关闭菜单和再次中断对话的既有顺序。
- 不处理任务完成、对话节点生命周期、持久化对象销毁或其它仍未锁定 actor 语义的 `Script()` 入口。
- 不实现控制组、多选、队友自动接管、远程访客或网络 ownership。
