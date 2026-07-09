# 第三十七刀：对话生命周期命令带发起者上下文

## 背景

第三十六刀已经让任务完成资产命令跟随交互完成者，但对话节点自身的开始/完成命令仍由 `DialogueChannel` 调用 `DialogueNode.ExecuteStartCommand()` 和 `ExecuteCompletionCommand()`，节点内部再用 `GameCommandContext.Script()` 执行命令。

这会让对话资产里配置的加物品、加能力、治疗、扣钱、开菜单、触发任务等命令无法知道“是谁触发了这段对话”。在多角色、临时控制、变形/感染、尸体搜刮和未来主机权威兼容语境下，交互触发的对话生命周期命令必须携带交互者上下文。

## 本刀变更

- `DialogueTree` 新增 `GameCommandContext`，默认构造仍使用 `GameCommandContext.Script()` 兼容无显式 actor 的提示/脚本对话。
- `DialogueChannel` 在节点开始和节点完成时，把当前 `DialogueTree.CommandContext` 传给 `DialogueNode`。
- `DialogueNode.ExecuteStartCommand(...)` 与 `ExecuteCompletionCommand(...)` 新增显式 `GameCommandContext` 重载，旧无参入口保留为脚本兼容。
- `DialogueSequence` / `DialogueUtils` 新增带上下文的 `ToDialogueTree(...)` / `CreateDialogueTree(...)` 入口。
- `IInteractionTarget` / `Entity.Say(...)` 新增带 `CharacterBase source` 的说话入口，并用当前受控角色判断生成 `LocalPlayer(source)` 或 `Unknown(source)`。
- `DialogueInteraction`、`ShopInteraction`、`CraftInteraction`、`InnInteraction`、`QuestInteraction` 的交互对话改为传入交互发起者。
- `PlayDialogueSequence`、`PlayDialogueLine` 的命令对话改为传递命令自身收到的 `GameCommandContext`。
- `Chest` 的宝箱掉落展示对话和后续库存转移复用打开者上下文。
- `Invoke-FoundationStaticGate.ps1` 新增 `DialogueLifecycleCommandContextMissingPatternCount / DialogueLifecycleCommandContextDisallowedPatternCount`，防止对话生命周期命令回退到无 actor 运行时调用链。

## 上下文语义

- 交互触发的对话：如果交互发起者是当前受控角色，使用 `LocalPlayer(source)`；否则使用 `Unknown(source)`，保留 actor 但不伪造成本地玩家、AI 或远程访客。
- 命令触发的对话：沿用该命令收到的 `GameCommandContext`。
- 纯 UI/系统提示对话：没有明确 actor 时继续使用 `Script()`，不硬塞当前受控角色。

## 边界

- 不修改任何对话资产里配置的具体命令。
- 不改变对话队列、跳过、选项消息收集或对话结束回调顺序。
- 不把对话系统改成全局当前受控角色模式；上下文只来自明确调用者。
- 不处理 `Persistable.Destroy()` 的销毁来源。
- 不实现控制组、多选、队友自动接管、远程访客、网络 ownership 或 FishNet 接入。
