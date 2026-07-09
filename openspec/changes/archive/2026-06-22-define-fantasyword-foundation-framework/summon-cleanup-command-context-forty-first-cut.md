# 第四十一刀：召唤物清理回调跟随召唤者上下文

## 背景

第四十刀后，投射物销毁回调已经能跟随发射来源，但召唤物仍有另一条独立清理链：`SummoningAbility.Interrupt()` 会在能力被打断时清理当前追踪的召唤物，`SummoningAbility.MakeSpaceIfNecessary()` 会在召唤数量超限时清理旧召唤物。

这两条链路调用的是召唤物自己的 `Kill()`。它们不是伤害结算，不会写入召唤物的最后有效伤害来源，所以死亡销毁回调仍会退回 `GameCommandContext.Script()`，丢掉“是谁的召唤能力主动清理了这个召唤物”。

## 本刀变更

- `CharacterBase` 新增 `Kill(GameCommandContext context)`，允许调用方为这次死亡销毁回调写入一次性上下文。
- 该上下文不会在 `Kill()` 返回时立即清掉，而是保留到死亡动画结束后的 `ResolveDeathCommandContext()` 消费，避免有死亡动画的召唤物丢失来源。
- `CharacterBase.ResolveDeathCommandContext()` 优先消费这份一次性覆盖；没有覆盖时继续沿第三十九刀的最后有效伤害来源逻辑。
- `SummoningAbility.Interrupt()` 清理召唤物时改为 `summon.Kill(ResolveSummonCleanupCommandContext())`。
- `SummoningAbility.MakeSpaceIfNecessary()` 数量超限清理召唤物时也改为同一入口。
- `SummoningAbility.ResolveSummonCleanupCommandContext()` 使用召唤能力拥有者 `m_character` 生成上下文。
- 如果召唤者是当前受控角色，则使用 `GameCommandContext.LocalPlayer(m_character)`。
- 如果召唤者存在但不是当前受控角色，则使用 `GameCommandContext.Unknown(m_character)`，保留 actor 但不伪造 AI、远程访客或网络 ownership。
- 如果召唤者缺失，则继续使用 `GameCommandContext.Script()`。
- `Invoke-FoundationStaticGate.ps1` 新增 `SummonCleanupCommandContextMissingPatternCount / SummonCleanupCommandContextDisallowedPatternCount`，防止召唤物清理退回无上下文 `summon.Kill()`。

## 上下文语义

- 召唤能力主动打断：被清理召唤物的销毁回调跟随召唤者。
- 召唤数量超限：被替换掉的旧召唤物销毁回调跟随召唤者。
- 普通伤害杀死召唤物：仍按最后有效伤害来源解析。
- 没有明确 actor 的脚本强杀或环境死亡：仍保留 `Script()` 语义。

## 边界

- 不改变召唤、跟随、传送、存档恢复、等级同步、阵营同步或能力授予规则。
- 不把召唤物普通死亡、环境死亡、脚本强杀全部归因给召唤者。
- 不实现召唤物击杀奖励转主人、召唤物击杀归属、召唤物控制权、召唤物独立背包或 AI 来源分类。
- 不实现控制组、多选、远程访客、网络 ownership 或 FishNet 接入。
