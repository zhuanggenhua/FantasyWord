# Player Control Group Forty Sixth Cut

## 背景

第 45 刀已经让变形、感染、丧尸化这类规则可以按来源锁定玩家直接控制，并在同一角色已配置 `AIController` 时切到 AI。下一块缺口是：玩家输入目标仍只能表达单个角色。

这会阻碍 Kenshi / 博德之门式队伍控制。FantasyWord 需要允许玩家选中多个角色并下发同一移动意图，同时仍保留一个主控角色给 UI、相机、交互、能力栏和菜单上下文使用。当前不能把这个问题绕成第二套输入系统、RTS 静态 `GameController`、网络 ownership 或临时测试控制器。

## 本刀变更

- `IPlayerInputTarget` 新增 `CreateControlledCharacterSnapshot()`，把“当前输入目标可代表哪些角色”从单角色口扩展成显式快照。
- `PlayerController` 作为单角色输入目标，返回自身 `CharacterBase` 快照。
- 新增 `PlayerControlGroup`，作为本地玩家控制组输入目标。
- `PlayerSystem` 新增 `SetCurrentControlGroup(...)`，并把当前输入目标生命周期监听从单个角色扩展到快照里的多个角色。
- `Invoke-FoundationStaticGate.ps1` 增加 `PlayerControlGroup` 文件、接口、分发和越界词门禁。

## 当前语义

- 主控角色仍是控制组快照里的第一个有效成员。
- 相机、UI、菜单、交互和非移动类能力命令仍先跟随主控角色。
- `Move / StopMove / ClickMove / ToggleMovementControlMode` 会分发给控制组内所有仍可玩家控制、且已有 `PlayerController` 的成员。
- 控制组移动命令会遍历所有成员；只要至少一个成员执行成功，整体命令视为成功，但失败成员不会阻断其它成员接收命令。
- 每个成员执行命令时重新构造 `GameCommandContext.LocalPlayer(member)`，避免把主控角色来源错误套到其它成员身上。

## 明确边界

本刀不实现：

- RTS 框选、追加选择、阵型落点、订单队列、右键目标命令或停止队列。
- 导航 Provider、路径规划、绕障或队形移动。
- 拾取、攻击、装备、使用物品、交互等多成员动作分发。
- 远程访客、网络 ownership、FishNet、RPC、`NetworkObject` 或同步字段。
- ECS、DOTS、`WorldSystem`、`UnitSelectionSystem` 或任何并行 RTS 控制器。

## 当前判断

当前选择合理，但只能算“控制组输入目标合同闭合第一刀”，不能算队伍控制完成。

原因是 FantasyWord 的长期目标确实需要多角色、多背包、多能力来源和变形失控；但现阶段最小正确动作不是直接搬 RTS Starter Kit 或引入 ECS，而是先把现有 `InputSystem -> PlayerSystem -> IPlayerInputTarget -> PlayerController` 正式链扩展到“一个输入目标可代表多个角色”。这样既保留当前 2DRPG/GameCore 的运行时真相，又继续吸收 TopDown 的组件化能力/控制器思想，并为后续 Kenshi/BG 式多选控制留下正式入口。
