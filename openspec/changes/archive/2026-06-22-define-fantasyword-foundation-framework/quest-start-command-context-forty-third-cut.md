# 第四十三刀：任务启动事件跟随接取者上下文

## 背景

第四十二刀后，库存菜单转移请求已经能保留当前受控角色的本地玩家来源。但任务启动仍有两条会改变世界状态的入口没有来源上下文：

- NPC 接任务：`QuestInteraction.TryOfferingQuest(...)` 在玩家接受对话后直接调用 `JournalSystem.StartQuest(quest)`。
- 物品开任务：`ItemStartQuestEffect` 使用物品后直接调用 `JournalSystem.StartQuest(m_questToStart)`。

`StartQuest` 会修改日志系统状态、创建任务进度、发送任务开始事件并播放音效。它不是单纯 UI 展示，所以需要回答“谁发起了任务启动”。当前没有任务开始资产命令，因此本刀不新增任务开始命令，只把来源上下文带到系统状态变化和事件出口。

## 本刀变更

- `JournalSystem.StartQuest(Quest quest)` 保留脚本兼容入口，并委托到新增的 `StartQuest(Quest quest, GameCommandContext context)`。
- `JournalSystem.StartQuest(Quest quest, GameCommandContext context)` 在任务开始事件中透传上下文。
- `QuestStartedEvent` 新增 `CommandContext` 属性；旧构造仍保留并使用 `GameCommandContext.Script()`。
- `GameRuntimeEvents.NotifyQuestStarted(Quest quest)` 保留脚本兼容入口，并委托到新增的 `NotifyQuestStarted(Quest quest, GameCommandContext commandContext)`。
- `QuestInteraction.TryOfferingQuest(...)` 在玩家接受任务时，按交互发起者生成 `LocalPlayer(source)` 或 `Unknown(source)`。
- `AItemEffect.OnUse(...)` 新增 `sourceOwner` 参数，让物品效果能区分“物品来源角色”和“效果目标角色”。
- `ItemStartQuestEffect` 使用 `sourceOwner` 优先生成任务启动上下文；缺失时才回退目标角色，仍缺失则保留 `Unknown()`。
- `Invoke-FoundationStaticGate.ps1` 新增 `QuestStartCommandContextMissingPatternCount / QuestStartCommandContextDisallowedPatternCount`，防止 NPC 接任务、物品开任务或任务开始事件回退到无上下文入口。

## 上下文语义

- 当前受控角色通过 NPC 对话接任务：任务开始事件携带 `LocalPlayer(source)`。
- 非当前受控角色通过交互接任务：任务开始事件携带 `Unknown(source)`，保留 actor 但不伪造玩家或 AI。
- 当前受控角色使用物品开启任务：任务开始事件携带 `LocalPlayer(sourceOwner)`。
- 纯脚本调用旧 `StartQuest(quest)`：继续保留 `Script()` 语义。

## 边界

- 不新增任务开始奖励命令、任务开始条件命令或任务资产协议字段。
- 不改变任务进度、完成、奖励、对话、NPC 图标、日志 UI 或存档结构。
- 不实现任务归属保存、队伍共享/个人任务分流、控制组、多选、远程访客或网络 ownership。
- 不让事件监听者直接裁决任务状态；任务状态真相仍由 `JournalSystem` 持有。
