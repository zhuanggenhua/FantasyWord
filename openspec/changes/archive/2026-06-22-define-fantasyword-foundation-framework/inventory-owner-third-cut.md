# Inventory Owner Third Cut

## Scope

本次第三刀继续收窄默认队伍背包的使用面，把商店、制作和脚本物品命令接到当前受控角色的物品背包。队伍金钱仍保留为共享钱包。

## Implemented Shape

- `AddOrRemoveItem` 现在对当前受控角色背包增减物品，不再写默认队伍背包。
- `UIShop` 的玩家背包列表读取当前受控角色 owner。
- 商店购买成功后，物品进入当前受控角色背包；扣钱仍从共享队伍钱包扣。
- 商店出售时，从当前受控角色背包移除物品；收入仍进入共享队伍钱包。
- `Recipe` 新增 owner-aware 入口：
  - `CalculateCraftCapacity(CharacterBase owner)`
  - `CanCraft(CharacterBase owner, out bool hasMoney, out bool hasIngredients, ...)`
- `CraftingStation` 新增 owner-aware 入口：
  - `CanCraft(CharacterBase owner, Recipe recipe, out bool hasMoney, out bool hasIngredients)`
  - `Craft(CharacterBase owner, Recipe recipe)`
- `UICraft` 的背包列表、配方可制作状态、材料数量显示、扣材料和产物归属都使用同一个当前受控角色 owner。
- `UIIngredientEntry` 和 `UIRecipeEntry` 支持显式传入库存 owner。

## Preserved Compatibility

- `Recipe.CalculateCraftCapacity()`、`Recipe.CanCraft(...)`、`CraftingStation.CanCraft(...)`、`CraftingStation.Craft(...)` 废弃入口保留；它们默认解析当前受控角色，若后续没有当前角色则由 `InventorySystem` 的 `null owner -> 默认队伍 owner` 兼容规则兜底。
- `AddOrRemoveMoney` 未改，继续读写共享队伍钱包。
- `UIShop` 和 `UICraft` 的金钱显示继续使用默认队伍钱包。

## Explicit Non-Changes

- `ItemTask` 和 `IsItemInInventory` 仍然是待裁决项。任务/条件到底查队伍共享库存、当前角色库存、指定 NPC/容器库存，还是任务绑定 owner，需要和任务系统上下文一起设计，不能只按当前 UI 角色硬切。
- 怪物掉落仍未迁移，原因同第二刀：当前缺少击杀者或奖励接收者上下文。
- 商店本体仍没有独立 shop owner 库存，当前只是买卖玩家侧物品归属正确化；完整商店库存、进货、限量、偷窃和容器式交易仍未实现。
- 制作站本体仍没有独立 crafting-station owner 库存，当前只是材料来源和产物归属正确化；多人协作制作、工作台缓存材料和基地生产库存仍未实现。

## Remaining Required Cuts

1. 任务/条件增加明确库存查询范围，不能长期靠默认队伍背包。
2. 怪物奖励需要从伤害/击杀链携带 source owner。
3. 商店、容器、尸体和地面物品堆需要独立 owner 与 UI 切换。
4. 制作站、基地生产和工作队列需要区分角色背包、工作站库存和队伍/基地仓库。
