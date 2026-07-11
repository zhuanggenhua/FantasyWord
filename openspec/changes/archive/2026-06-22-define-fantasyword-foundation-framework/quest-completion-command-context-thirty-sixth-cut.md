# 第三十六刀：任务完成命令带完成者上下文

## 背景

第三十三到第三十五刀已经把一批脚本命令、怪物死亡奖励和玩家死亡动作从“默认玩家主角”或“无 actor 脚本上下文”收回到明确的命令上下文。但任务完成链仍有一个明确缺口：`QuestInteraction.TryExecute(source, target)` 已经知道是谁和 NPC 交互完成任务，后续 `JournalSystem.CompleteQuest(quest)` 与 `Quest.ExecuteOnQuestCompletion()` 却仍用 `GameCommandContext.Script()` 执行任务完成资产命令。

这会让任务奖励、治疗、能力授予、物品增减或其它完成命令在多角色队伍、临时控制、变形/感染失控、尸体搜刮和未来主机权威兼容语境下丢掉“完成任务的是哪个角色”。

## 本刀变更

- `QuestInteraction.TryCompletingQuest(...)` 改为接收交互发起角色 `source`，并在完成对话回调里把任务完成命令上下文传给 `JournalSystem`。
- `JournalSystem.CompleteQuest(...)` 新增显式 `GameCommandContext` 重载，运行时任务完成链使用该上下文执行任务完成命令。
- `Quest.ExecuteOnQuestCompletion(...)` 新增显式 `GameCommandContext` 重载，资产命令不再只能用无 actor 脚本上下文执行。
- `Invoke-FoundationStaticGate.ps1` 新增 `QuestCompletionCommandContextMissingPatternCount / QuestCompletionCommandContextDisallowedPatternCount`，防止 `QuestInteraction -> JournalSystem -> Quest` 回退到无 actor 完成链。

## 上下文语义

- 如果交互发起角色是当前受控角色，任务完成命令使用 `GameCommandContext.LocalPlayer(source)`。
- 如果交互发起角色不是当前受控角色，任务完成命令使用 `GameCommandContext.Unknown(source)`，保留 actor 但不伪造成本地玩家、AI 或远程访客。
- `JournalSystem.CompleteQuest(Quest quest)` 与 `Quest.ExecuteOnQuestCompletion()` 的无参入口保留，继续表达脚本/编辑器/旧调用没有显式 actor 的语义。

## 边界

- 不修改任务完成资产里配置的具体命令。
- 不改变任务完成、重复任务解锁、事件通知或完成音效的既有顺序。
- 不处理任务进度节点 `TalkToNPCTaskProgress.MarkAsCompleted()` 的 actor 语义。
- 不处理对话节点开始/完成生命周期命令；当前对话系统没有保存“是谁发起这段对话”，需要单独设计。
- 不处理 `Persistable.Destroy()` 的销毁来源；持久化对象不一定是角色，不能机械套用当前受控角色。
- 不实现控制组、多选、队友自动接管、远程访客、网络 ownership 或 FishNet 接入。
