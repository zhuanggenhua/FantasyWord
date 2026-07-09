# Character Death Player Control Thirty First Cut

## 目标

第三十一刀只收一个最小合同：当前受控角色死亡后，玩家输入目标必须立刻重新校验；玩家主角复活后，如果当前没有输入目标，且主角已重新可控，则恢复默认控制到玩家主角。

这不是控制组系统，也不是死亡后 AI 接管系统。它只补齐死亡/复活生命周期与 `PlayerSystem` 当前输入目标之间的同步缺口。

## 用户故事

- 作为玩家，我不希望当前控制的角色死亡后，输入目标仍然指向一个已经不能操作的死角色，只是在每条命令上被动返回失败。
- 作为 Kenshi / 博德之门 / ToME4 风格复杂规则的基础，角色可能死亡、复活、变形、感染或丧尸化；这些状态会改变一部分能力和控制权，但系统必须始终知道当前谁还能消费玩家输入。
- 作为系统设计者，我希望死亡和复活走同一套 `PlayerSystem` 当前控制对象规则。后续做队伍控制、控制组、多选、AI 接管或远程访客时，可以扩展回退策略，而不是让死亡链路散落在 UI 或输入层。

## 实现

- `PlayerSystem.NotifyCharacterDied(...)` 在死亡角色正是当前受控角色时，调用 `RevalidateCurrentControlledCharacter()`。
- `PlayerSystem.NotifyCharacterRevived(...)` 在当前没有输入目标、复活角色是玩家实例且角色可控时，调用 `SetCurrentControlledCharacter(...)` 恢复默认控制。
- `CharacterBase.Kill()` 在 `base.Kill()` 后通知 `PlayerSystem`。此时角色已进入死亡状态，`CanBePlayerControlled()` 会返回 false，重校验可以回退到仍可控的玩家实例或清空输入目标。
- `CharacterBase.Revive()` 在死亡状态和 corpse owner 迁回后通知 `PlayerSystem`。这只恢复玩家实例，不自动选择任意队友。
- `Invoke-FoundationStaticGate.ps1` 新增 `PlayerControlLifecycleMissingPatternCount` 门禁，覆盖 `PlayerSystem` 死亡/复活通知入口和 `CharacterBase` 生命周期通知点。

## 边界

本刀尚未实现：

- 控制组、多选、队友自动选择优先级或编队回退。
- 死亡后强制 AI 接管、丧尸 AI 接管或阵营长期仇恨。
- 远程访客控制、网络 ownership 或 FishNet 接入。
- 独立尸体实体、怪物尸体保留、尸体双栏 UI、装备强制脱装、装备掉落或装备损坏。
- 死亡菜单、复活菜单、UI 可见反馈或端到端 PlayMode 剧情流程。

## 验证

本刀验收结果：

- `git diff --check` 定向检查本轮 C#、脚本和 OpenSpec 文件通过。
- `scripts/Invoke-FoundationStaticGate.ps1 -AsJson` 通过，`PlayerControlLifecycleMissingPatternCount = 0`。
- `npx openspec validate define-fantasyword-foundation-framework --strict` 通过。
- AIBridge `assets-refresh` 成功；Editor 状态回到 `isPlaying = false / isCompiling = false / isUpdating = false`；资产刷新后的最近 1 分钟 `Error = [] / Exception = []`。
