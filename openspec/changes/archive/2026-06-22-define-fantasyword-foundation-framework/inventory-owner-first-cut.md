# Inventory Owner First Cut

## Scope

本次第一刀只把 `InventorySystem` 从“单一全局背包”推进到“显式 owner 库存服务”的兼容形态，不一次性完成 UI、商店、制作、任务、装备和完整存档 UI 的全链路迁移。

## Implemented Shape

- 新增 `EInventoryOwnerKind`：`Party / Character / Container / GroundPile / Corpse / Shop / CraftingStation`。
- 新增 `InventoryOwnerHandle`：用于表达库存 owner 的类型与稳定 id。
- 新增 `InventoryOwnerDataBlock`：用于保存每个 owner 的金钱和物品。
- `InventoryDataBlock.money/items` 保留为旧存档镜像字段；读旧档时导入默认队伍 owner，写新档时继续镜像默认队伍 owner。
- `InventorySystem` 新增显式 owner API：
  - `GetBagEntries(CharacterBase owner)` / `GetBagEntries(InventoryOwnerHandle owner)`
  - `GetItemCount(CharacterBase owner, Item item)` / `GetItemCount(InventoryOwnerHandle owner, Item item)`
  - `HasItemInBag(CharacterBase owner, Item item, int quantity)`
  - `AddToBag(CharacterBase owner, Item item, int quantity, EItemTransferType source)`
  - `RemoveFromBag(CharacterBase owner, Item item, int quantity, EItemTransferType transferType)`
  - 金钱也有 owner overload，但当前拾取金钱仍走默认队伍钱包。
- 旧无 owner API 仍保留，全部指向默认队伍 owner，保证现有 UI、商店、制作、任务条件和奖励调用面不在第一刀断裂。

## First Runtime Use

- `ItemPickable` 已改为把物品写入执行拾取的 `CharacterBase` owner。
- `MoneyPickable` 继续写默认队伍钱包，因为当前用户故事允许队伍资金共享，且共享钱包不等于共享物品背包。

## Current Call Sites Still On Archived Owner

这些调用点仍使用无 owner 旧接口，后续必须逐步迁移：

- 命令：`AddOrRemoveItem`、`AddOrRemoveMoney`
- 容器奖励：`Chest`
- 怪物奖励：`Monster`
- 任务条件：`IsItemInInventory`、`ItemTask`
- 制作：`Recipe`、`CraftingStation`、`UICraft`、`UIIngredientEntry`
- 物品使用与装备：`AItemEffect`、`ItemEquipOrUnequip`、`InventorySystem.TryEquip/TryUnequip`
- 商店：`UIShop`
- 背包/角色 UI：`UIInventoryBag`、`UIInventoryEquipment`、`UICharacter`
- 存档聚合：`SaveSystem` 仍只调用 `InventorySystem.CreateDataBlock/LoadDataBlock`，但数据块已经兼容 owner 数组。

## Non-Goals

- 不创建 `Networking` 目录、RPC、同步字段或网络对象。
- 不把 TopDown InventoryEngine 接成正式入口。
- 不把每个角色装备栏、快捷栏和能力来源完整迁入 owner 存档；这仍由后续角色存档设计处理。
- 不把商店、容器、尸体和制作站 UI 一次性重写。

## Next Cut

下一刀应优先处理“当前查看/操作对象”：

1. 背包 UI 支持查看当前受控角色 owner。
2. 装备/使用物品 API 显式指定来源 owner 和目标角色。
3. 容器打开时写入容器 owner 或转移到执行者 owner，而不是默认队伍 owner。
4. 任务、制作和商店决定读队伍共享库存、当前角色库存，还是指定容器库存。
