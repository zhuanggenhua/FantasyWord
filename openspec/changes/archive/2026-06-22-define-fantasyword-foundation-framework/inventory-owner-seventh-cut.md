# Inventory Owner Seventh Cut

## Scope

本次第七刀把第六刀的 owner 转移 API 接到正式菜单与交互上下文。目标是让容器库存不再只能“打开即自动塞进角色背包”，并清掉背包格子硬绑 `UIInventory` 的复用问题。

## Implemented Shape

- 新增 `InventoryMenuContext`：
  - 普通背包默认显示当前受控角色 owner。
  - 容器/外部 owner 可以用 `TransferToDestination` 模式打开。
  - 菜单上下文显式携带显示 owner、目标 owner、执行角色和转移原因。
- 新增 `InventoryMenuRequestedEvent` 与 `GameRuntimeEvents.RequestInventory(...)`。
- `UIManager` 现在订阅库存菜单请求，并复用已有 `EMenu.Inventory` 对应的 UIKit 面板注册，不新增第二套库存 UI 宿主。
- `UIInventory` 现在读取 `InventoryMenuContext`：
  - 普通模式下继续点击物品并执行使用/装备逻辑。
  - 转移模式下点击背包物品会调用 `InventorySystem.TransferItem(...)`，从显示 owner 转到目标 owner。
  - 显示外部 owner 时仍用执行角色作为装备栏/属性栏目标，避免容器被错误当成角色。
- 新增 `IInventoryBagItemClickHandler`，`UIInventoryBagSlot` 不再硬查父级 `UIInventory`。
- `UIInventory`、`UIShop`、`UICraft` 都实现 `IInventoryBagItemClickHandler`，同一套背包格子可以在普通背包、商店、制作和后续容器菜单里复用。
- `Chest.TryOpen(...)` 行为改为容器化：
  - 首次打开时播放开启和揭示表现。
  - 首次打开时把物品初始化到箱子的 `Container` owner。
  - 金币仍进入共享队伍钱包。
  - 有容器物品时打开库存菜单，点击物品再转给打开者。
  - 关闭后若容器里还有未取走物品，再次交互可以继续打开同一个容器 owner。

## Preserved Compatibility

- 普通 `GameRuntimeEvents.RequestMenu(EMenu.Inventory)` 不传上下文时仍显示当前受控角色背包。
- `UIShop` 和 `UICraft` 继续显示当前受控角色背包，只是背包格子点击改走统一接口。
- 箱子旧存档字段仍只有 `opened`，不改现有 `ChestDataBlock` 结构。
- 箱子金币仍是队伍共享资金，不引入角色私房钱或容器钱包。
- 本刀不新增新 prefab、不移动场景、不接网络框架。

## Why This Is Still Not Full Container UI

当前复用了现有单栏 Inventory 面板。它能显示外部 owner 并点击转移，但还不是 Kenshi / BG 式完整双栏转移界面。

仍未完成的场景：

- 双栏 UI 同时显示角色背包和容器/尸体/地面堆。
- 批量转移、拆分数量、全部拿取、全部放入。
- 角色间转移命令。
- 容器标题、容量、重量、锁、距离和权限反馈。
- 尸体 owner、地面堆 owner 和商店/制作站持久库存。
- 保存/加载后保留“箱子已开但还有未取物品”的完整显示状态，目前只依赖 owner 库存数据和 `opened` 标记。

## Remaining Required Cuts

1. 把库存转移从“点击即转 1 个”升级成正式玩家命令，带发起者、目标、数量和失败原因。
2. 建立双栏库存面板或明确的容器模式布局。
3. 给怪物死亡补尸体 owner / 地面堆 owner 策略。
4. 给角色间转移、队伍控制和未来访客控制建立同一条命令入口。
