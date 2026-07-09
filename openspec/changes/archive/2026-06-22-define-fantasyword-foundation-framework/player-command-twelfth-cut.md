# Player Command Twelfth Cut

## Scope

本次第十二刀把 `InputSystem -> IPlayerInputTarget -> PlayerController` 从直接方法调用收成玩家命令请求。目标是让本地玩家输入先形成可返回结果的命令对象，再交给当前受控目标执行，为后续控制组、AI 和未来远程访客入口留出同一条裁决路径。

## Implemented Shape

- 新增 `PlayerCommandRequest`，显式携带：
  - 命令上下文 `GameCommandContext`
  - 玩家命令类型 `EPlayerCommandKind`
  - 移动或点击位置向量 `Vector`
  - 能力槽位 `AbilityIndex`
- 新增 `PlayerCommandResult`，显式返回：
  - 是否成功 `Succeeded`
  - 失败原因 `FailureReason`
  - 原始请求 `Request`
- `IPlayerInputTarget` 现在只暴露：
  - `TryGetControlledCharacter(...)`
  - `ExecutePlayerCommand(PlayerCommandRequest request)`
- `InputSystem` 的交互、菜单、方向移动、停止移动、点击移动、切换移动模式、施法和停止施法回调，统一构造 `PlayerCommandRequest`，再调用 `inputTarget.ExecutePlayerCommand(...)`。
- `PlayerController` 现在按 `EPlayerCommandKind` 分发到内部执行方法，并把失败原因返回给调用侧。
- `PlayerNavigationRuntime` 的方向移动、停止移动、点击移动和切换移动模式改为返回 `bool`，让 `PlayerController` 能把执行失败转换为 `PlayerCommandResult`。
- `ClickMoveTestRuntimeValidator` 已改走正式 `ExecutePlayerCommand(...)`，不再调用旧点击移动入口。
- `Invoke-FoundationStaticGate.ps1` 已同步要求新玩家命令请求、输入目标接口和控制器分发形状，并在输入层禁止回到旧 `Handle*` 直调。

## Preserved Compatibility

- 没有新增 FishNet、RPC、NetworkObject、网络目录或网络 SDK 抽象。
- 没有改变 `PlayerController` 的 Inspector 序列化字段。
- 没有把移动、交互、施法的真实业务规则迁到 `InputSystem`；输入层只负责读输入和生成请求。
- 没有伪造距离、容量、负重、锁、阵营或控制权验证；这些仍等待真实模型和正式命令裁决合同。

## Why This Is Still Not Full Player Command

当前只收口了“本地玩家输入到当前受控角色”的入口，不代表 Kenshi/BG/RTS 式完整命令系统完成。

仍未完成的场景：

- 多选角色和控制组下发同一命令。
- AI、脚本和未来远程访客复用同一命令入口。
- 移动、攻击、拾取、装备、转移、使用物品和施法统一到同一种请求/结果协议。
- 订单队列、追加命令、停止命令、阵型落点和批量下发。
- 控制权、距离、容量、重量、锁、阵营、偷窃、状态限制和失败反馈。

## Remaining Required Cuts

1. 把当前单角色命令入口扩展为控制组/多选命令入口。
2. 为 AI 和未来远程访客定义同源命令上下文，而不是复制玩家输入路径。
3. 将拾取、装备、物品使用、库存转移、攻击和能力释放统一到正式命令裁决合同。
4. 在真实玩法模型存在后补控制权、距离、容量、重量、锁、阵营和状态失败原因。
