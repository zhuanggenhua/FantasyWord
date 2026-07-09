# Shop And Craft Menu Command Context: Fifty-Fourth Cut

## 背景

库存菜单第 53 刀修正了背包分类切换时的 owner 上下文丢失。继续检查商店和制作菜单后，发现它们打开时只携带 `Shop` 或 `CraftingStation`，没有携带交互发起者或资产命令上下文。

这会导致菜单已经由角色 A 打开，但交易、出售、制作时重新读取当前受控角色；如果菜单打开期间控制对象变化，物品归属会漂移到角色 B。

## 本刀改动

- `ShopRequestedEvent` 和 `CraftRequestedEvent` 新增 `GameCommandContext`。
- `GameRuntimeEvents.RequestShop(...)` 和 `RequestCraft(...)` 新增带 `GameCommandContext` 的重载，旧无上下文入口保留兼容。
- `ShopInteraction` / `CraftInteraction` 用交互发起者 `source` 解析上下文后打开菜单。
- `OpenShopMenu` / `OpenCraftMenu` 把资产命令收到的 `GameCommandContext` 传给菜单请求。
- `UIGameMenuEntry` 的随身制作入口在打开制作菜单前锁定当前操作角色，不再走无上下文制作请求。
- `UIManager` 打开商店/制作面板时把上下文作为第二个打开参数传入。
- `UIShop` / `UICraft` 保存打开时的上下文，并用 `m_commandContext.ResolveActorOrCurrentControlledCharacter()` 解析背包 owner。
- `Invoke-FoundationStaticGate.ps1` 新增 `ShopCraftMenuContextMissingPatternCount / ShopCraftMenuContextDisallowedPatternCount`，防止该链路退回只传商店/制作站本体。

## 明确未完成

- 不实现商店持久库存、商店 owner、价格规则重构或个人/队伍钱包裁决。
- 不实现制作站持久库存、制作站材料缓存或工作台队列。
- 不改变队伍金钱仍共享的现态。
- 不实现控制组批量买卖/制作、多成员交易分发、远程访客 UI 或网络 ownership。

## 验证

- 定向尾随空格搜索无命中。
- `git diff --check` 通过。
- `Invoke-FoundationStaticGate.ps1 -AsJson` 通过，关键结果包括 `MissingFileCount = 0`、`ShopCraftMenuContextMissingPatternCount = 0` 和 `ShopCraftMenuContextDisallowedPatternCount = 0`。
- `npx openspec validate foundation-runtime --strict` 通过；原 `define-fantasyword-foundation-framework` change 已归档，当前 OpenSpec CLI 不再把它识别为可直接验证的 change item。
- AIBridge `assets-refresh` 成功；`editor-application-get-state` 返回 `isPlaying = false / isCompiling = false / isUpdating = false`；最近 1 分钟 Console 的 `Error = [] / Exception = []`。
