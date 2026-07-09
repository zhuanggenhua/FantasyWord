# Inventory Owner Second Cut

## Scope

本次第二刀把“当前玩家正在查看/操作的角色”接进背包 UI、物品使用、装备/卸装和箱子奖励链路。它仍不是完整多角色背包系统，不处理角色间转移、容器 UI、商店库存、制作站库存、任务物品条件或怪物击杀来源。

## Implemented Shape

- `UIInventoryBag` 支持传入 `CharacterBase owner`，背包格读取该 owner 的物品快照。
- `UIInventory` 使用 `PlayerSystem.GetCurrentControlledCharacterOrPlayerInstance()` 作为当前库存 owner。
- `Item.Use(...)` 新增 `sourceOwner + target + location` 入口；旧 `target + location` 入口保留，并默认来源就是目标自己。
- `IItemEffect.TryUse(...)` 新增 `sourceOwner` 参数。
- `AItemEffect` 消耗物品时从 `sourceOwner` 背包扣除，不再默认扣队伍背包。
- `ItemEquipOrUnequip` 装备/卸装时使用 `sourceOwner` 作为物品来源或回收目的地，目标必须是 `Hero`。
- `InventorySystem` 新增显式装备 API：
  - `TryEquip(CharacterBase sourceOwner, Hero targetHero, Equipment equipment)`
  - `TryEquip(InventoryOwnerHandle sourceOwner, Hero targetHero, Equipment equipment)`
  - `TryUnequip(CharacterBase destinationOwner, Hero targetHero, EEquipmentType type)`
  - `TryUnequip(InventoryOwnerHandle destinationOwner, Hero targetHero, EEquipmentType type)`
  - `GetEquipment(Hero hero, EEquipmentType type)`
- `ChestInteraction` 把交互发起者传给 `Chest.TryOpen(source)`；箱子物品奖励进入打开者背包。

## Preserved Compatibility

- `InventorySystem.TryEquip(Equipment)`、`TryUnequip(EEquipmentType)`、`GetEquipment(EEquipmentType)` 仍保留旧入口，继续以默认队伍背包作为物品来源或回收目的地。
- `Item.Use(CharacterBase target, EItemLocation location)` 仍保留旧入口。
- `Chest.TryOpen()` 仍保留旧入口，回退到当前受控角色。
- `InventoryDataBlock.money/items` 旧存档镜像字段不变。
- 队伍金币仍是默认共享钱包；箱子金币和地面金币继续进入队伍钱包。

## Explicit Non-Changes

- 怪物掉落仍进入默认队伍背包。当前 `Monster.Kill()` 没有击杀者、伤害来源或奖励接收者上下文，直接改成当前受控角色会把 AI、召唤物、陷阱或远程延迟击杀算错。
- 商店仍读写默认队伍背包和钱包。后续需要先设计买卖发起者、商店 owner、队伍钱包和角色私人物品之间的交易规则。
- 制作仍读写默认队伍背包。后续需要先设计制作站 owner、输入材料来源、产物归属和多角色协作制作。
- 任务条件仍读取默认队伍背包。后续需要裁决任务物品是队伍共享检查、当前角色检查，还是指定 owner 检查。
- 容器 UI、尸体库存、地面物品堆和角色间转移尚未实现。

## Remaining Required Cuts

1. 战斗/伤害链路需要携带击杀者或奖励接收者，怪物掉落才能进入正确角色或队伍库存。
2. 角色背包、装备栏、快捷栏和能力来源需要进入角色存档结构，而不是只靠 `InventorySystem` owner 数组。
3. UI 需要支持当前角色、控制组、容器、尸体、商店和制作站之间切换查看。
4. 商店、制作、任务条件需要分别裁决读取队伍共享库存、角色库存还是指定库存 owner。
5. 角色间转移需要正式命令入口，带来源、目标、数量、距离/控制权/负重裁决和反馈。
