# Inventory Owner Fourth Cut

## Scope

本次第四刀处理任务条件与任务收集进度的库存查询范围。目标不是把所有任务都硬改成当前角色背包，而是让任务资产显式声明自己查哪个库存范围。

## Implemented Shape

- 新增 `EInventoryQueryScope`：
  - `Party`：查询默认队伍库存，保留旧任务/旧条件语义。
  - `CurrentControlledCharacter`：查询当前受控角色背包。
- `InventorySystem` 新增 owner-aware 查询入口：
  - `GetOwner(EInventoryQueryScope queryScope)`
  - `GetItemCount(EInventoryQueryScope queryScope, Item item)`
  - `HasItemInBag(EInventoryQueryScope queryScope, Item item, int quantity = 1)`
- `IsItemInInventory` 新增 `m_inventoryScope` 字段，不再硬编码默认队伍背包。
- `ItemTask` 新增 `m_inventoryScope` 字段，不再硬编码默认队伍背包。
- 当条件或任务选择 `CurrentControlledCharacter` 时，会监听当前受控角色切换并刷新状态。
- `ItemTaskProgress` 现在同时监听物品增加和移除，避免卖出、制作消耗或转移后进度还显示旧数量。

## Preserved Compatibility

- `m_inventoryScope` 默认是 `Party`，因此旧任务资产和旧条件资产继续按队伍共享库存判定。
- `InventorySystem.GetItemCount(Item)` 与 `HasItemInBag(Item, int)` 继续保留默认队伍 owner 兼容入口。

## Why Not Default Everything To Current Character

任务条件不是普通 UI 背包。开放世界任务有三种常见语义：

- 队伍任务：全队任意角色持有物品即可推进。
- 当前执行者任务：必须由当前交互或当前受控角色持有物品。
- 指定 owner 任务：检查某个容器、NPC、尸体、商店或基地仓库。

当前代码只有队伍与当前受控角色两种可靠上下文。直接把旧任务全部改成当前受控角色，会让已有队伍型收集任务行为漂移，也会在角色切换后改变任务完成状态。因此本刀先显式化范围，并保留旧资产兼容。

## Remaining Required Cuts

1. 交互/命令上下文需要传入“执行者”，任务条件才能支持执行者库存，而不是只能读当前受控角色。
2. 任务系统需要支持指定库存 owner，例如容器、NPC、尸体、商店、制作站或基地仓库。
3. `InventoryItemAddedEvent` / `InventoryItemRemovedEvent` 后续应携带 owner，避免任务和 UI 对无关 owner 变化做全量刷新。
4. 怪物掉落仍需要击杀者或奖励接收者上下文。
