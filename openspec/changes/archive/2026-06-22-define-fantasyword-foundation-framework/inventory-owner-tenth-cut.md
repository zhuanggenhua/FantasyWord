# Inventory Owner Tenth Cut

## Scope

本次第十刀把库存转移已经使用的 `GameCommandContext` 接进正式 `ICommand` 执行链。目标不是完成完整玩家命令系统，而是先保证命令执行时可以携带“谁发起、由什么来源发起”的运行时上下文。

## Implemented Shape

- `2026-06-22` 更正：
  - 第三十三刀之后，`AddOrRemoveAbility`、`AddOrRemoveMana`、`HealOrDamagePlayer`、`ApplyEffectsToPlayer`、`RevivePlayer` 和 `MovePlayer` 的无 actor 默认目标，已经继续从“玩家实例默认目标”收口到“当前受控角色”。
  - `AddExperience` 的无 actor 默认目标也已继续收口到“当前受控 Hero”；actor 不是 `Hero` 时不再假转给玩家主角。

- `ICommand` 保持原有无参 `Execute()`，避免破坏现有 `[SerializeReference]` 命令资产。
- 新增 `IContextualCommand`，提供 `Execute(GameCommandContext context)` 作为可选上下文入口。
- 新增 `CommandExecutionExtensions.Execute(ICommand, GameCommandContext)`：
  - 命令实现 `IContextualCommand` 时走带上下文入口。
  - 旧命令未实现时继续走旧无参入口。
  - 空命令安全返回，不再让生命周期回调因空命令直接报空引用。
- `CommandInteraction` 会在当前受控角色交互时生成 `LocalPlayer` 上下文，否则保留带 actor 的 `Unknown`。
- `CommandTrigger` 会区分玩家触发和脚本触发：
  - 玩家碰撞、进入、交互触发当前受控角色时使用 `LocalPlayer(actor)`。
  - `Start/Enable/Update/Condition` 等系统触发使用 `Script(currentControlledCharacter, "CommandTrigger")`。
- `CommandHandler`、`ExecuteCommandHandler`、`ExecuteCommandList`、`ExecuteCommandIf` 已透传同一份上下文。
- 对话节点、对象销毁、玩家死亡收口、怪物死亡命令和任务完成命令现在都走 `Script` 上下文。
- 已消费上下文的角色状态命令：
  - `AddOrRemoveItem`：有 actor 时写 actor 背包，无 actor 时保留旧的当前受控角色行为。
  - `AddOrRemoveAbility`、`AddOrRemoveMana`、`HealOrDamagePlayer`、`ApplyEffectsToPlayer`、`RevivePlayer`：有 actor 时作用到 actor；该文档之后的第三十三刀已把无 actor 默认目标继续收口到当前受控角色。
  - `AddExperience`：有 Hero actor 时给该 Hero 经验；actor 不是 Hero 时不假转给玩家；该文档之后的第三十三刀已把无 actor 默认目标继续收口到当前受控 Hero。
  - `MoveCharacterBase`、`ToggleController` 已接入上下文接口，但默认仍要求资产显式目标，不把缺失引用偷偷兜底成当前角色。

## Preserved Compatibility

- 旧命令资产仍只需要实现 `ICommand.Execute()`，不强制重写或重序列化。
- 无上下文调用仍保留旧默认目标：
  - 物品命令默认当前受控角色。
  - 玩家生命、法力、经验、能力和复活动作默认玩家实例。
- 本刀不新增 FishNet、RPC、NetworkObject、网络目录或网络抽象。
- 本刀不新增距离、负重、容量、容器锁、偷窃、阵营和控制权校验；这些仍必须等对应模型成立后再接入，不能写假验证。

## What This Enables

- 箱子容器转移、菜单转移和命令触发现在可以共享 `GameCommandContext`。
- 后续角色间转移、AI 命令、脚本命令和未来远程访客命令可以复用同一条 `IContextualCommand` 入口。
- 组合命令不再丢失来源信息，后续失败原因可以回到“本地玩家/AI/脚本/远程访客”的输入来源上。

## Remaining Required Cuts

1. 建立正式玩家命令对象，覆盖移动、拾取、交互、装备、转移、使用物品和施法。
2. 建立控制权验证：本地玩家、AI、脚本和未来远程访客分别能不能控制目标角色或控制组。
3. 把角色间转移、双栏 UI、尸体 owner 和地面堆 owner 都接入同一套转移请求。
4. 在真实模型存在后，再补距离、容量、重量、锁、阵营、偷窃和状态限制。
