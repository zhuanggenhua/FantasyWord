# 第四十四刀：主动能力释放跟随发起者上下文

## 背景

第四十三刀后，任务启动事件已经能保留接取者上下文，但主动能力释放还有一条更核心的来源丢失链路：

- 玩家输入释放能力时，`PlayerController` 之前只调用 `CharacterBase.FireAbility(sheet)`，能力内部会按当前角色重新猜来源。
- AI 攻击目标时，`AIController` 也调用同一个无上下文入口，AI 施法、射击或召唤在后续投射物/召唤物清理里容易退化成 `Unknown(actor)`。
- `ActiveAbilityBase` 的动画延迟、武器执行状态机和子类 `ExecuteAbilityUse()` 会把真正效果推迟到后续帧，必须在释放瞬间保存命令上下文，不能到发射投射物或清理召唤物时再按当前控制者猜。
- 投射物读档恢复后仍可能触发销毁回调，因此只保存 `source` 角色还不够，还要保存释放时的来源类型。

本刀解决“主动能力是由本地玩家、AI、脚本还是未来远程访客发起”的执行上下文传递问题。它不改变能力规则、伤害结算或 GAS 规则层。

## 本刀变更

- `GameCommandContext` 新增 `Recreate(...)` 和 `ResolveForActor(...)`：
  - 当前受控角色解析为 `LocalPlayer(actor)`。
  - 带 `AIController` 的角色解析为 `AI(actor)`。
  - 其它角色保留 `Unknown(actor)`。
- `CharacterBase.FireAbility(ActiveAbilitySheet sheet)` 保留兼容入口，并委托到 `FireAbility(sheet, GameCommandContext.ResolveForActor(this))`。
- `CharacterBase.FireAbility(ActiveAbilitySheet sheet, GameCommandContext commandContext)` 把上下文传给 `ITriggerableAbility.Fire(...)`。
- `ITriggerableAbility.Fire(...)` 和 `ActiveAbilityBase.Fire(...)` 改为接收 `GameCommandContext`。
- `ActiveAbilityBase` 保存释放瞬间的上下文，并通过 `activeCommandContext` 暴露给具体主动能力子类在动画事件或武器执行阶段使用。
- `PlayerController` 的本地玩家释放能力入口改为传入 `request.CommandContext`。
- `AIController.BehaviourRuntime` 的 AI 攻击入口改为传入 `GameCommandContext.AI(m_owner.m_subject)`。
- `ProjectileAbility` 创建投射物时把 `activeCommandContext` 传给 `Projectile.Throw(...)`。
- `Projectile` 保存释放上下文，销毁回调用发射来源角色重建同一来源类型；`ProjectileDataBlock` 新增 `fireCommandIssuerKind / fireCommandIssuerId`，让读档恢复后的投射物也保留发起者类型。
- `SummoningAbility.ResolveSummonCleanupCommandContext()` 改为直接使用 `activeCommandContext`，召唤物主动清理跟随释放该召唤能力时的上下文，而不是清理瞬间再按当前受控角色猜。
- `Invoke-FoundationStaticGate.ps1` 新增主动能力上下文门禁，防止玩家、AI、主动能力基类、投射物和召唤清理链路退回旧无上下文形状。

## 上下文语义

- 本地玩家输入释放主动能力：能力、投射物和该能力主动清理的召唤物沿用 `LocalPlayer(actor)`。
- AI 控制器释放主动能力：能力、投射物和该能力主动清理的召唤物沿用 `AI(actor)`。
- 旧脚本或其它遗留入口调用 `FireAbility(sheet)`：按 `ResolveForActor(this)` 解析，当前受控角色为本地玩家，有 AI 控制器的角色为 AI，其它角色保留 `Unknown(actor)`。
- 没有 actor 的上下文进入主动能力时，能力基类会把命令来源类型重建到当前能力拥有者上，避免后续帧丢失 actor。
- 投射物读档恢复后，销毁回调会用保存的来源类型和恢复出的 `source` 角色重建上下文；旧存档缺少新增字段时会保守落到 `Unknown(source)`。

## 边界

- 不改变 GAS 规则层、冷却、蓝耗、能力权限、武器执行状态机或效果结算。
- 不改变接触伤害、持续 Tick、环境伤害、陷阱、光环或被动触发来源。
- 不实现控制组、多选、队伍命令、AI 命令队列、强制 AI 接管、远程访客、网络 ownership 或 FishNet 接入。
- 不新增网络目录、RPC、同步字段或网络框架抽象。
- 不把 `AI(actor)` 等同于未来联机所有权；它只表示当前这次单机命令由 AI 控制器发起。
