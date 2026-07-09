# Character Death Corpse Inventory Twenty-Ninth Cut

## 目标

第二十九刀只收一个最小合同：角色死亡时，它的角色背包物品从 `Character` owner 迁到同一角色标识下的 `Corpse` owner；如果角色复活，尚未被转走的 corpse owner 物品迁回角色 owner。

这不是完整尸体系统。它不创建可交互尸体实体，不做尸体双栏 UI，不强制脱装，也不改变怪物掉落奖励的归属规则。

## 用户故事

- 作为玩家，我的队员可能死亡、被感染或之后被复活。死亡时角色随身背包里的物品不应继续被当成活人背包使用；复活时如果这些物品还在尸体归属下，应回到这个角色的背包。
- 作为 Kenshi / 博德之门 / ToME4 风格复杂效果的基础，死亡、丧尸化、复活和搜刮都需要先有稳定的库存归属事实。后续尸体实体和尸体 UI 可以消费 `Corpse` owner，而不是重新发明一套掉落表。
- 作为系统设计者，我需要死亡流程具备幂等防护。重复触发死亡不应重复迁移背包、重复发奖励或重复播放同一套死亡收益逻辑。

## 实现

- `EItemTransferType` 新增 `Corpse`，用于标记角色背包物品在死亡/复活归属迁移中的转移来源。
- `InventorySystem` 新增 `GetCorpseOwner(CharacterBase)`，使用角色持久化标识或运行期 scene instance id 构造 `EInventoryOwnerKind.Corpse` owner。
- `InventorySystem.TransferCharacterInventoryToCorpse(...)` 将角色 `Character` owner 的全部物品迁到同一角色的 `Corpse` owner。
- `InventorySystem.TransferCorpseInventoryToCharacter(...)` 将同一角色 `Corpse` owner 的剩余物品迁回 `Character` owner。
- `CharacterBase.Kill()` 在死亡表现通知后、父类死亡销毁流程前迁移角色背包物品到 corpse owner。
- `CharacterBase.Revive()` 在父类恢复后把 corpse owner 的剩余物品迁回角色背包，避免 Hero 这类不销毁死亡对象复活后背包永久留在 corpse owner。
- `CharacterBase.Kill()` 和 `Monster.Kill()` 都在入口处检查已销毁标记，避免重复死亡触发重复迁移、重复死亡表现或重复怪物奖励。
- `Invoke-FoundationStaticGate.ps1` 新增 `InventoryCorpseOwnershipMissingPatternCount` 门禁，覆盖 corpse owner API、死亡迁移、复活迁回和怪物死亡防重。

## 存档与边界

没有新增存档字段。`InventoryDataBlock.inventories` 已经按 `EInventoryOwnerKind + ownerId` 保存不同 owner 的物品，因此 `Corpse` owner 会沿用现有 owner 数据块保存。

本刀只迁移背包物品，不迁移 owner 钱包。当前怪物死亡奖励仍按 `MonsterDrop` 和金钱奖励发给击杀者或默认玩家实例；怪物自身如果未来拥有角色背包，该背包物品会走 corpse owner，奖励掉落仍是另一条来源。

本刀尚未实现：

- 可交互尸体实体、尸体点击、尸体高亮或尸体生命周期。
- 尸体双栏 UI、搜刮权限、搜刮距离和搜刮反馈。
- 装备强制脱装、装备掉落、装备损坏、装备视觉隐藏。
- 死亡后 AI 接管、丧尸化复生、控制组剔除、多选联动或远程访客 ownership。
- 非持久临时怪物尸体跨读档稳定恢复。没有持久化标识的角色仍只能使用运行期 scene instance id。

## 验证

本刀验收结果：

- `git diff --check` 定向检查本轮 C#、脚本和 OpenSpec 文件通过。
- `scripts/Invoke-FoundationStaticGate.ps1 -AsJson` 通过，`InventoryCorpseOwnershipMissingPatternCount = 0`。
- `npx openspec validate define-fantasyword-foundation-framework --strict` 通过。
- AIBridge `assets-refresh` 成功；Editor 状态为 `isPlaying = false / isCompiling = false / isUpdating = false`；资产刷新后的最近 1 分钟 `Error = [] / Exception = []`。
