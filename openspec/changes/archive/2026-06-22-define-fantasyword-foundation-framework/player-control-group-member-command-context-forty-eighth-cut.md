# 第四十八刀：控制组成员命令来源归因

## 问题

第四十六刀已经让本地玩家控制组可以把移动类命令分发给多个成员，第四十七刀又把主控成员的前台刷新修正回来。但代码里仍有一批命令来源解析把“当前主控角色”等同于“本地玩家控制的角色”。

这会导致控制组中的非主控成员在后续拾取、交互、尸体搜刮、奖励接收、物品开任务或对话命令等路径中，容易被降级成 `Unknown(actor)`。对 Kenshi / 博德之门式多角色队伍来说，这是错误的：非主控成员如果仍在本地控制组里，它的动作来源仍应能回答为本地玩家，而不是未知来源。

## 本刀改动

- `PlayerSystem` 新增 `IsCurrentControlledMember(CharacterBase character)`：
  - `IsCurrentControlledCharacter(...)` 继续只表达当前主控角色，用于相机、UI、交互目标刷新等前台语义。
  - `IsCurrentControlledMember(...)` 表达角色是否在当前输入目标的受控成员快照里，用于命令来源归因和控制组生命周期复核。
- `GameCommandContext.ResolveForActor(...)` 改用 `IsCurrentControlledMember(...)` 判断本地玩家来源。
- 以下入口不再各自手写“当前主控角色则 LocalPlayer，否则 Unknown”的判断，统一改走 `ResolveForActor(...)`：
  - 对话上下文：`Entity`
  - 命令交互：`CommandInteraction`
  - 任务开始/完成：`QuestInteraction`、`ItemStartQuestEffect`
  - 宝箱和尸体搜刮：`Chest`、`CharacterBase`
  - 怪物死亡奖励命令：`Monster`
  - 库存菜单默认 actor 上下文：`InventoryMenuContext`
- `PlayerSystem.NotifyCharacterDied(...)` 改为任意当前受控成员死亡都会触发控制目标重校验，而不是只在主控角色死亡时重校验。
- `Invoke-FoundationStaticGate.ps1` 同步更新门禁，要求来源归因走 `ResolveForActor(...)`，并要求 `GameCommandContext` 使用 `IsCurrentControlledMember(...)`。

## 边界

本刀不实现框选、追加选择、阵型、订单队列、拾取/攻击多成员分发、真实距离/容量/权限失败反馈、远程访客、FishNet、网络 ownership 或 ECS。

当前控制组仍只有移动类命令分发给全体成员；交互、菜单和能力命令仍只落到主控成员。此次只是保证一旦某个非主控成员通过正式链路成为动作 actor，它不会因为不是主控而丢失本地玩家来源。

## 验证

- `git diff --check` 通过。
- `powershell -ExecutionPolicy Bypass -File .\scripts\Invoke-FoundationStaticGate.ps1 -AsJson` 通过，关键计数包括：
  - `GameCommandContextMissingPatternCount = 0`
  - `PlayerSystemPlayerControlMissingPatternCount = 0`
  - `MonsterDeathCommandContextMissingPatternCount = 0`
  - `QuestCompletionCommandContextMissingPatternCount = 0`
  - `QuestStartCommandContextMissingPatternCount = 0`
  - `CharacterDeathDestroyCommandContextMissingPatternCount = 0`
  - `InventoryMenuContextMissingPatternCount = 0`
- `npx openspec validate define-fantasyword-foundation-framework --strict` 通过。
- AIBridge `assets-refresh` 成功；随后 `editor-application-get-state` 返回 `isPlaying = false / isCompiling = false / isUpdating = false`，最近 1 分钟 Console 的 `Error = [] / Exception = []`。
