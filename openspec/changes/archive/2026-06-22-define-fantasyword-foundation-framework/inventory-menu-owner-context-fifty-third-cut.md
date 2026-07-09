# Inventory Menu Owner Context: Fifty-Third Cut

## 背景

第五十一刀把能力/角色 UI 从“真实当前 Hero 或玩家主角兜底”收回“真实当前受控 Hero”。继续检查背包/装备菜单后，发现库存菜单的父级 `UIInventory` 已经通过 `InventoryMenuContext` 解析 actor 和 display owner，但子级 `UIInventoryBag` 在分类切换时会调用自己的无参 `UpdateSlots()`。

这个无参刷新会重新按当前受控角色或玩家主角兜底取 owner，导致容器、尸体、转移菜单或未来控制组库存打开时，首次显示可能正确，切换分类后又丢失打开菜单时的 owner 上下文。

## 本刀改动

- `UIInventoryBag` 新增最近一次显示 owner 缓存 `m_currentOwner`。
- `UpdateSlots(InventoryOwnerHandle owner)` 会同步记录当前 owner。
- `SetCategory(...)` 切换分类时不再走无参刷新，而是重画 `m_currentOwner`。
- `Invoke-FoundationStaticGate.ps1` 把该形状纳入 `InventoryMenuContext` 门禁：
  - 必须存在 owner 缓存、owner 赋值和 `UpdateSlots(m_currentOwner)`。
  - `SetCategory(...)` 内禁止回到 `UpdateSlots()` 或 `GetCurrentControlledCharacterOrPlayerInstance()`。

## 明确未完成

- 不实现控制组库存聚合或控制组双栏 UI。
- 不实现独立容器双栏界面。
- 不实现商店、制作站持久库存。
- 不实现非 Hero 装备栏或装备 UI 完整上下文。
- 不改变旧无参 `UpdateSlots()` 兼容入口，只防止分类切换绕过父菜单上下文。

## 验证

- 定向尾随空格搜索无命中。
- `git diff --check` 通过。
- `Invoke-FoundationStaticGate.ps1 -AsJson` 通过，关键结果包括 `InventoryMenuContextMissingPatternCount = 0` 和 `InventoryMenuContextDisallowedPatternCount = 0`。
- `npx openspec validate define-fantasyword-foundation-framework --strict` 通过。
- AIBridge `assets-refresh` 成功，Editor 状态为 `isPlaying = false / isCompiling = false / isUpdating = false`，最近 1 分钟 Console 的 `Error = [] / Exception = []`。
