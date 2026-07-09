# 第四十九刀：本地玩家命令失败反馈出口

## 本刀目标

本刀把本地玩家输入命令的失败结果从“返回后被输入回调丢弃”推进到“统一发布为 HUD 可消费的表现事件”。

这一步服务于 Kenshi / 博德之门 / ToME4 方向下的复杂控制链：当角色因变形、感染、丧尸化、动作锁、快捷栏空槽或当前没有可控对象而拒绝玩家命令时，输入层不能只静默失败。后续距离、负重、背包满、目标非法和控制权不足等更具体裁决，都可以沿同一命令结果出口继续扩展。

## 代码落点

- `GameRuntimeEvents.Presentation.cs`
  - 新增 `LocalPlayerCommandFailedEvent`。
  - 新增 `NotifyLocalPlayerCommandFailed(PlayerCommandResult result)`，且成功结果不会发布事件。
- `InputSystem.cs`
  - `ExecuteLocalPlayerCommand(...)` 不再把失败结果直接返回给空调用者。
  - 新增 `NotifyLocalPlayerCommandResult(...)`，失败时统一通知 `GameRuntimeEvents`。
- `UIHUDAbilityMessage.cs`
  - 在现有 HUD 提示组件上订阅 `LocalPlayerCommandFailedEvent`。
  - 只把离散、玩家需要知道的失败转为短提示。
  - 过滤持续移动失败、停止施法失败和已经由 `PlayerAbilityFireFailedEvent` 处理的能力规则拒绝，避免重复刷屏。
- `Invoke-FoundationStaticGate.ps1`
  - 新增对命令失败事件、输入结果处理和 HUD 订阅/过滤的静态门禁。

## 当前支持的玩家可见失败

- 当前没有可控角色。
- 命令 actor 不在当前控制组。
- 当前角色被变形、感染、丧尸化或其它规则锁住直接控制。
- 交互没有有效目标。
- 菜单或施法被当前状态阻断。
- 快捷栏槽位没有可释放能力。

## 明确不包含

- 距离、负重、容量、背包满、目标非法、阵营权限、偷窃权限和容器锁的完整裁决。
- 多成员拾取、攻击、交互或施法分发。
- 失败提示本地化、提示音、冷却节流或分角色消息队列。
- 框选、阵型、订单队列、追加命令、停止命令或 RTS 导航 Provider。
- 远程访客、FishNet、网络 ownership、RPC、NetworkObject 或 ECS。

## 选择理由

当前 `PlayerCommandResult` 已经由 `PlayerController` 和 `PlayerControlGroup` 返回，说明命令裁决入口存在；缺口是输入系统没有把失败结果交给表现层。直接在 `InputSystem` 发布强类型事件，能保持输入层只负责玩家意图和命令结果转交，不把 HUD 文案写进输入系统，也不让 HUD 反向参与命令裁决。

复用 `UIHUDAbilityMessage` 是为了继续沿现有 HUD 失败提示组件和 `EventKit.Type` 事件链走，不新增第二套反馈系统。能力具体规则失败仍保留 `PlayerAbilityFireFailedEvent`，通用命令失败只补充它没有覆盖的控制权、空槽和状态阻断等失败。
