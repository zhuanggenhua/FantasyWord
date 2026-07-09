# Inventory Owner Ninth Cut

## Scope

本次第九刀给库存转移请求补最小参与者验证。目标是让“谁发起转移”不再只是记录字段，而是参与裁决：带 `Actor` 的请求必须让这个角色参与来源或目标 owner。

## Implemented Shape

- `EInventoryTransferFailureReason` 新增 `ActorNotParticipant`。
- `InventorySystem.ExecuteTransfer(...)` 在数量和 owner 合法性之后、实际扣物品之前执行参与者验证。
- 带 `Actor` 的请求必须满足：
  - `Actor` 的角色 owner 等于 `SourceOwner`；或
  - `Actor` 的角色 owner 等于 `DestinationOwner`。
- 不带 `Actor` 的旧兼容请求仍允许通过参与者验证，保证旧 `TransferItem(...)` 薄入口不被破坏。
- `UIInventory` 对 `ActorNotParticipant` 使用独立反馈文案，不把内部失败枚举直接展示给玩家。

## Preserved Compatibility

- 箱子转移仍成立：来源是箱子 `Container` owner，目标是打开者角色 owner，`Actor` 是打开者，因此参与者验证通过。
- 普通旧 `TransferItem(...)` 没有 actor，继续保持旧行为。
- 本刀不新增网络框架、不创建网络目录、不改场景或 prefab。

## Why This Is Not Full Control Validation

这刀只证明“发起角色必须参与这次库存转移”，不等于完整控制权系统已经完成。

仍未完成的控制问题：

- 当前输入来源是不是本地玩家、AI、脚本还是未来远程访客。
- 玩家是否控制该角色或控制组。
- 角色之间是否允许互相拿取物品。
- 距离、视线、容器锁、阵营、偷窃、容量、负重和状态限制。
- 主机权威联机时由谁发送请求、谁裁决、谁接收结果。

## Remaining Required Cuts

1. 将库存转移接入正式玩家命令上下文，区分本地玩家、AI 和未来远程访客。
2. 补距离、容量、重量和权限验证。
3. 为角色间转移和双栏 UI 定义明确的交互入口。
4. 将尸体 owner / 地面堆 owner 接到同一套转移请求。
