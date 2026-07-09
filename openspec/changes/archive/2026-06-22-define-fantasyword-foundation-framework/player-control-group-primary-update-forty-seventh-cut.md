# Player Control Group Primary Update Forty Seventh Cut

## 背景

第 46 刀把输入目标扩成了本地控制组，但主控角色的 `PlayerController.OnUpdate()` 仍在用“我是不是当前输入目标对象本身”判断是否刷新交互目标和指针朝向。

这会让控制组下的主控角色在逻辑上被当成“非当前输入目标”，从而丢掉交互刷新和能力朝向更新。移动命令仍能分发，但主控角色的实时表现已经不完整。

## 本刀变更

- `PlayerController.OnUpdate()` 的门控从 `IsCurrentInputTarget(this)` 改为 `IsCurrentControlledCharacter(m_subject)`。
- `Invoke-FoundationStaticGate.ps1` 增加对此语义的正式门禁，并把旧输入目标对象比较形状记为回归违禁。

## 当前语义

- 单角色模式下，当前受控角色仍然是 `PlayerController` 自己的 `m_subject`。
- 控制组模式下，主控角色继续刷新交互目标、指针朝向和能力相关的前台状态。
- 非主控成员仍不会把自己当作前台输入目标来刷新这类状态。

## 明确边界

本刀不新增：

- 额外的输入系统。
- 控制组内多角色交互分发。
- 阵型、队列、导航 Provider。
- 远程访客、网络 ownership、FishNet、ECS。

## 当前判断

这是对第 46 刀的必要修正，不是新的玩法扩张。没有这一步，控制组只能保证移动分发，不能保证主控角色的交互和朝向仍然活着，因此第 46 刀的闭包是不完整的。
