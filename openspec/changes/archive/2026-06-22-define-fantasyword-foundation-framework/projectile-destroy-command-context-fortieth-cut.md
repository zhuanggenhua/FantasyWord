# 第四十刀：投射物销毁回调跟随发射来源上下文

## 背景

第三十九刀后，角色死亡销毁回调已经能跟随最后有效伤害来源，但投射物仍有独立销毁链：寿命结束、命中目标或碰撞地形后进入 `Projectile.Terminate(...)`，没有销毁动画时直接 `Destroy()`，有销毁动画时动画结束再由 `OnDestroyAnimationEnd()` 调用 `Destroy()`。

投射物本身已经持有发射来源 `m_source`，爆炸和命中效果也用这份来源结算。如果投射物 prefab 上配置了 `m_executeOnDeath` 销毁回调，旧无参销毁会让这类回调退回 `GameCommandContext.Script()`，丢掉实际发射者。

## 本刀变更

- `Projectile.OnDestroyAnimationEnd()` 改为调用 `Destroy(ResolveDestroyCommandContext())`。
- `Projectile.Terminate(...)` 在没有销毁动画的直接销毁分支也改为调用 `Destroy(ResolveDestroyCommandContext())`。
- `Projectile.ResolveDestroyCommandContext()` 使用 `m_source` 生成上下文。
- 如果 `m_source` 是当前受控角色，则使用 `GameCommandContext.LocalPlayer(m_source)`。
- 如果 `m_source` 存在但不是当前受控角色，则使用 `GameCommandContext.Unknown(m_source)`，保留 actor 但不伪造 AI、远程访客或网络 ownership。
- 如果 `m_source` 缺失或已经无效，则继续使用 `GameCommandContext.Script()`。
- `Invoke-FoundationStaticGate.ps1` 新增 `ProjectileDestroyCommandContextMissingPatternCount / ProjectileDestroyCommandContextDisallowedPatternCount`，防止投射物销毁回调退回无 actor 脚本来源。

## 上下文语义

- 新发射投射物：来源来自 `Projectile.Throw(source, ...)`。
- 读档恢复投射物：来源来自 `ProjectileDataBlock.source.ResolveOrNull()`。
- 来源存在：销毁回调跟随发射者。
- 来源缺失：销毁回调保持脚本来源，不把当前受控角色硬塞进去。

## 边界

- 不改变投射物命中、爆炸、持续时间、速度、效果列表或存档结构。
- 不处理召唤物清理、召唤者继承来源或召唤物死亡归属。
- 不处理环境伤害、陷阱、光环、持续区域或脚本强杀来源归因。
- 不实现控制组、多选、AI 来源分类、远程访客、网络 ownership 或 FishNet 接入。
