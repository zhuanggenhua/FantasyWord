# Inventory Owner Sixth Cut

## Scope

本次第六刀处理库存 owner 的共同转移入口和容器最小闭包。目标不是一次做完整双栏容器 UI，而是先让角色、容器、尸体、地面堆、商店和制作站后续都能走同一条库存转移规则。

## Implemented Shape

- `InventorySystem` 新增 `TransferItem(...)` 和 `TransferAllItems(...)`，把“从哪个 owner 扣、给哪个 owner 加”收成唯一转移入口。
- `InventoryOwnerHandle` 新增 `ForPersistable(...)`，让 `Chest` 这类可持久化世界对象可以用自身持久 ID 或场景实例兜底 ID 形成稳定 owner。
- `InventoryItemAddedEvent`、`InventoryItemRemovedEvent`、`InventoryMoneyAddedEvent` 和 `InventoryMoneyRemovedEvent` 现在携带 `Owner`。
- 旧事件构造和旧通知方法继续保留，默认映射到 `Party:default`，避免破坏已有调用点。
- `InventorySystem.RemoveFromBag(...)` 只在实际移除成功时发送事件，并发送真实移除数量；空物品、非正数量和缺失物品不再制造虚假“移除”事件。
- `Chest.TryOpen(...)` 不再只把物品直接塞给打开者：
  - 先解析该箱子的 `Container` owner。
  - 先把箱子掉落登记到该容器 owner。
  - 再通过 `TransferItem(...)` 转给打开者 owner。
- 箱子金币奖励仍进入共享队伍钱包，但修正为只要 `ChestLoot.HasMoney()` 就发放，不再被 `HasItems()` 分支挡住。
- `ItemTaskProgress` 和 `IsItemInInventory` 监听库存事件时按查询范围过滤 owner：
  - `Party` 只响应队伍 owner。
  - `CurrentControlledCharacter` 只响应当前受控角色 owner。
- `UIEventLog` 只展示 `Party` 和 `Character` owner 的库存/金钱变化，容器内部增减不会显示成玩家得失。
- `UIInventoryBag` 增加 `InventoryOwnerHandle` 更新入口，为后续容器/尸体/地面堆双栏 UI 预留正式调用点。

## Preserved Compatibility

- `AddToBag(item, ...)`、`RemoveFromBag(item, ...)`、旧库存事件构造和旧通知方法仍按默认队伍 owner 工作。
- 现有角色背包 UI、商店、制作、物品使用、装备/卸装和怪物掉落调用点不需要改签名。
- 当前箱子交互的玩家可见结果仍是“打开箱子后物品进入打开者背包、金币进入队伍钱包”，只是内部已经经过容器 owner 和统一转移入口。
- 本刀不新增网络框架、不新增 `Networking` 目录，也不把容器 owner 写成联机同步层。

## Why This Is Still Not Full Container Ownership

当前箱子只是用容器 owner 建立转移地基，打开时仍自动转入打开者背包；它还不是完整容器菜单。

仍未完成的场景：

- 双栏 UI：左侧角色背包、右侧箱子/尸体/地面堆，可手动转移数量。
- 角色间物品转移命令。
- 怪物死亡生成尸体 owner 或地面物品堆 owner，而不是总是直接进入奖励接收者背包。
- 商店库存和制作站库存作为独立 owner 保存和展示。
- 背包容量、重量、容器锁、距离限制、控制权限制和失败反馈。
- 保存/加载后仍保留未取走的容器、尸体或地面堆物品。

## Remaining Required Cuts

1. 做 `InventoryTransfer` 级别的玩家命令入口，覆盖角色间、角色和容器、角色和尸体、角色和地面堆之间的转移。
2. 给箱子/尸体/地面堆补正式 UI 上下文，而不是继续只打开角色背包。
3. 把怪物掉落从“直接发给角色”扩展为可选尸体 owner / 地面堆 owner 策略。
4. 将角色背包、装备栏、快捷栏和能力来源纳入完整存档结构。
