# Character Corpse Loot Interaction Thirtieth Cut

## 目标

第三十刀只收一个最小合同：死亡后仍存在于场景中的角色，被其他角色交互时，可以把该死亡角色的 `Corpse` owner 作为外部库存打开，并把物品转移给交互者。

这不是完整尸体系统。它不生成尸体 prefab，不改变怪物死亡销毁策略，不做尸体双栏专属 UI，也不处理装备强制脱装或掉落。

## 用户故事

- 作为玩家，我希望队员倒地或死亡后，如果它的尸体仍在场景里，可以由另一个角色搜刮它 corpse owner 里的背包物品。
- 作为 Kenshi / 博德之门 / ToME4 风格复杂规则的基础，死亡、复活、感染和搜刮都应消费同一份 owner 事实，而不是让 UI 绕过 `InventorySystem` 直接读角色字段。
- 作为系统设计者，我希望尸体搜刮先复用现有外部 owner 转移菜单。后续再做尸体实体、双栏 UI、距离反馈或装备掉落时，不需要推翻这条 owner 合同。

## 实现

- `CharacterBase.OnInteract(...)` 在目标已死亡时，先尝试打开 corpse owner 库存。
- 若 corpse owner 没有物品，或没有可用 `InventorySystem` / 交互者，则保持原有角色交互逻辑。
- corpse owner 有物品时，`CharacterBase` 通过 `GameRuntimeEvents.RequestInventory(...)` 打开现有库存菜单，并使用 `InventoryMenuContext.TransferToCharacter(...)` 将 corpse owner 作为展示 owner、交互者作为目标 owner。
- 如果交互者是当前受控角色，命令上下文使用 `GameCommandContext.LocalPlayer(...)`；否则使用 `Unknown(actor)`，继续让库存转移请求按 actor 参与者和动作锁裁决。
- `Invoke-FoundationStaticGate.ps1` 新增 `InventoryCorpseLootInteractionMissingPatternCount` 门禁，覆盖死亡交互分支、corpse owner 读取和库存菜单请求。

## 边界

本刀尚未实现：

- 死亡后生成或保留独立尸体实体。
- 怪物死亡后保留尸体对象。当前怪物仍按原死亡销毁策略处理。
- 尸体双栏 UI、搜刮距离、搜刮提示、尸体空容器反馈或尸体高亮。
- 装备强制脱装、装备掉落、装备损坏或装备视觉隐藏。
- 死亡后 AI 接管、控制组剔除、多选联动、远程访客或网络 ownership。

## 验证

本刀验收结果：

- `git diff --check` 定向检查本轮 C#、脚本和 OpenSpec 文件通过。
- `scripts/Invoke-FoundationStaticGate.ps1 -AsJson` 通过，`InventoryCorpseLootInteractionMissingPatternCount = 0`。
- `npx openspec validate define-fantasyword-foundation-framework --strict` 通过。
- AIBridge `assets-refresh` 成功；Editor 状态为 `isPlaying = false / isCompiling = false / isUpdating = false`；资产刷新后的最近 1 分钟 `Error = [] / Exception = []`。
