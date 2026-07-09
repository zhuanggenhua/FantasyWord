# 第三十九刀：角色死亡销毁回调跟随死亡来源上下文

## 背景

第三十八刀只解决了 `DestroyEntity` 这类命令销毁实体时丢失命令上下文的问题。角色死亡仍有另一条独立路径：`Movable.Kill()` 播放死亡动画，动画结束后进入 `Movable.OnDeath()`，再调用 `Persistable.Destroy()`。

由于旧链路调用的是无参 `Destroy()`，角色死亡销毁回调会固定使用 `GameCommandContext.Script()`。这会让“击杀角色后由死亡对象执行的资产命令”丢掉真正的伤害来源，后续奖励、掉落、对话、任务或脚本命令都无法判断是谁导致死亡。

## 本刀变更

- `Movable.OnDeath()` 改为调用 `Destroy(ResolveDeathCommandContext())`。
- `Movable.ResolveDeathCommandContext()` 默认返回 `GameCommandContext.Script()`，普通可移动对象不被误归因到当前玩家。
- `CharacterBase.ResolveDeathCommandContext()` 使用角色已记录的最后有效伤害来源生成上下文。
- 如果最后有效伤害来源是当前受控角色，则使用 `GameCommandContext.LocalPlayer(source)`。
- 如果最后有效伤害来源不是当前受控角色，则使用 `GameCommandContext.Unknown(source)`，保留 actor 但不伪造成 AI、本地玩家或远程访客。
- `Invoke-FoundationStaticGate.ps1` 新增 `CharacterDeathDestroyCommandContextMissingPatternCount / CharacterDeathDestroyCommandContextDisallowedPatternCount`，防止角色死亡销毁回调退回无 actor 脚本来源。

## 上下文语义

- 有最后有效伤害来源的角色死亡：销毁回调跟随该伤害来源。
- 当前受控角色造成死亡：使用 `LocalPlayer(source)`。
- 非当前受控角色造成死亡：使用 `Unknown(source)`，只表达“有这个 actor”，不提前裁决 AI、远程访客或网络 ownership。
- 没有最后有效伤害来源的死亡：继续使用 `Script()`，例如脚本强杀、环境规则或尚未归因的状态死亡。
- 普通 `Movable`：继续使用 `Script()`，除非后续子类明确覆盖死亡来源解析。

## 边界

- 不处理投射物寿命结束、投射物碰撞销毁或爆炸销毁。
- 不处理召唤物清理、召唤者继承来源或召唤物死亡归属。
- 不把普通 `Movable` 死亡默认归因到当前受控角色。
- 不修改伤害数值、奖励数值、掉落表或资产命令配置。
- 不实现控制组、多选、AI 来源分类、远程访客、网络 ownership 或 FishNet 接入。
