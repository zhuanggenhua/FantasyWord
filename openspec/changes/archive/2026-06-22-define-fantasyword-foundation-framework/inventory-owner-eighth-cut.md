# Inventory Owner Eighth Cut

## Scope

本次第八刀把“点击容器物品直接调用 `TransferItem(...)`”收成正式库存转移请求和结果合同。目标是让 UI、后续角色间转移、AI 命令和未来主机权威联机都能复用同一条裁决入口。

## Implemented Shape

- 新增 `InventoryTransferRequest`，显式携带：
  - 发起角色 `Actor`
  - 来源 owner `SourceOwner`
  - 目标 owner `DestinationOwner`
  - 物品 `Item`
  - 数量 `Quantity`
  - 转移原因 `TransferType`
- 新增 `InventoryTransferResult`，显式返回：
  - 是否成功 `Succeeded`
  - 实际转移数量 `TransferredQuantity`
  - 失败原因 `FailureReason`
  - 原始请求 `Request`
- 新增 `EInventoryTransferFailureReason`：
  - `InvalidItem`
  - `InvalidQuantity`
  - `InvalidSourceOwner`
  - `InvalidDestinationOwner`
  - `InsufficientQuantity`
- `InventorySystem.ExecuteTransfer(...)` 成为正式裁决入口：
  - 先验证请求。
  - 请求无效时返回失败原因，不修改库存。
  - 来源和目标相同且物品足够时返回成功但转移数量为 0。
  - 有效请求才执行扣除和加入。
- 旧 `InventorySystem.TransferItem(...)` 继续保留为兼容薄入口，内部转调 `ExecuteTransfer(...)`。
- `InventoryMenuContext` 新增 `CreateTransferRequest(...)`，菜单层只负责生成请求，不自己拼底层转移参数。
- `UIInventory` 的容器转移模式改走 `ExecuteTransfer(...)`：
  - 成功时刷新 UI。
  - 失败时记录失败原因并给出最小玩家反馈。
- 新增 `MenuFeedbackPrompts.InventoryTransferFailed`，作为临时玩家可见反馈出口。

## Preserved Compatibility

- 旧 `TransferItem(...)` 和 `TransferAllItems(...)` 调用点继续可用。
- 普通背包、商店、制作、物品使用和装备/卸装路径不受影响。
- 本刀不新增网络框架、不创建网络目录、不改变现有场景或 prefab。
- 不改变旧存档结构；请求/结果是运行时合同，不进入保存数据。

## Why This Is Still Not Full Player Command

当前已经有正式请求/结果合同，但还不是完整 Kenshi/BG 式玩家命令系统。

仍未完成的场景：

- 玩家选择数量、拆堆、全部拿取、全部放入。
- 双栏 UI 中的拖拽/按钮转移。
- 角色 A 到角色 B 的转移命令。
- 控制权、距离、负重、背包容量、锁、阵营权限等失败原因。
- 失败原因到本地化 UI/提示音/按钮禁用的完整反馈。
- 主机权威联机时的输入来源、访客控制权和主机裁决薄适配。

## Remaining Required Cuts

1. 给 `InventoryTransferRequest` 补控制权、距离、容量和权限验证。
2. 建立双栏库存 UI 或明确的容器/角色转移模式布局。
3. 补角色间转移入口，让队伍控制和未来访客控制走同一条请求。
4. 将怪物死亡接到尸体 owner 或地面堆 owner，再复用同一转移请求拿取。
