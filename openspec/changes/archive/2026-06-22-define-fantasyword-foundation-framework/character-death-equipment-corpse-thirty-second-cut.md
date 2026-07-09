# Character Death Equipment Corpse Thirty Second Cut

## 目标

第三十二刀只收一个最小合同：Hero 死亡时，已装备物品会从装备槽强制卸下并写入同一角色的 `Corpse` owner，让后续尸体搜刮入口能拿到装备。

这不是完整尸体装备系统。它不生成尸体实体，不做尸体双栏 UI，不做装备损坏，也不让复活自动重新穿回死亡前装备。

## 用户故事

- 作为玩家，我希望队员死亡后，尸体可搜刮的不只是背包物品，也包括死亡时身上穿戴的装备。
- 作为 Kenshi / 博德之门 / ToME4 风格复杂规则的基础，死亡、复活、变形和感染会改变装备贡献、能力来源和物品归属；这些变化必须回到同一套 `InventorySystem` owner 事实，而不是让装备槽继续保留一份绕过尸体搜刮的隐藏物品。
- 作为系统设计者，我希望死亡强制脱装复用 `Hero` 自己的装备变更核心逻辑，确保装备属性和装备授予能力一起退场，而不是只把物品复制进 corpse owner。

## 实现

- `Hero.ForceUnequipAllEquipmentForLifecycle()` 会创建当前装备快照，逐件通过 `ApplyEquipmentSlotChange(..., null)` 清空装备槽，移除装备属性和装备授予能力，并返回实际卸下的装备。
- 该入口只服务生命周期强制处理，不走普通 `TryUnequip(...)`，所以不会被死亡后的 `ChangeEquipment / ManageInventory` 动作锁阻断。
- 如果强制脱装发生在已标记死亡的 Hero 上，入口会在刷新装备属性后把当前生命重新校正为 0，避免装备生命加成被移除后把死亡态推成负生命。
- `InventorySystem.TransferCharacterEquipmentToCorpse(...)` 只处理 `Hero`，把强制卸下的装备加入同一角色的 `Corpse` owner。
- `CharacterBase.Kill()` 在角色进入死亡状态后调用 `TransferOwnedEquipmentToCorpseOwner()`，与既有背包 owner 迁移和 corpse owner 搜刮入口共用同一个 owner 合同。
- `Invoke-FoundationStaticGate.ps1` 扩展 corpse owner 门禁，覆盖 Hero 生命周期强制脱装、装备写入 corpse owner 和死亡入口接线。

## 边界

本刀尚未实现：

- 复活后自动重新装备死亡前装备。复活只会把 corpse owner 剩余物品迁回角色背包。
- 非 Hero 装备栏、怪物装备、怪物尸体保留或怪物装备掉落。
- 独立尸体实体、尸体双栏 UI、装备损坏、装备视觉残留或装备隐藏表现。
- 死亡后强制 AI 接管、控制组、多选、远程访客或网络 ownership。

## 验证

本刀验收结果：

- 显式行尾空白检查覆盖本轮 C#、脚本和 OpenSpec 文件，无命中。
- `scripts/Invoke-FoundationStaticGate.ps1 -AsJson` 通过，`InventoryCorpseOwnershipMissingPatternCount = 0 / HeroMissingPatternCount = 0`。
- `npx openspec validate define-fantasyword-foundation-framework --strict` 通过。
- AIBridge `assets-refresh` 成功；Editor 状态回到 `isPlaying = false / isCompiling = false / isUpdating = false`；资产刷新后的最近 1 分钟 `Error = [] / Exception = []`。
