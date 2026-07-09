# 第三十八刀：命令销毁持久化对象透传命令上下文

## 背景

第三十七刀后，对话生命周期命令已经能携带发起者上下文，但 `DestroyEntity` 虽然实现了 `IContextualCommand`，执行时仍调用 `m_toDestroy?.Destroy()`，导致被销毁对象上的 `m_executeOnDeath` 回调继续由 `Persistable.Destroy()` 固定使用 `GameCommandContext.Script()`。

这会让“由对话、任务、触发器、命令列表等资产命令销毁实体”的链路再次丢掉 actor。对于多角色、临时控制、变形/感染、未来主机权威兼容来说，命令销毁必须沿用命令自身收到的上下文。

## 本刀变更

- `Persistable.Destroy()` 保留为旧兼容入口，继续表示无显式 actor 的脚本销毁。
- `Persistable.Destroy(GameCommandContext context)` 新增为正式上下文入口，销毁时用传入上下文执行 `m_executeOnDeath`。
- `DestroyEntity.Execute(GameCommandContext context)` 改为调用 `m_toDestroy?.Destroy(context)`，不再丢弃命令链上下文。
- `Invoke-FoundationStaticGate.ps1` 新增 `PersistableDestroyCommandContextMissingPatternCount / PersistableDestroyCommandContextDisallowedPatternCount`，防止命令销毁回退到无 actor 销毁链路。

## 上下文语义

- 命令触发的实体销毁：沿用该命令收到的 `GameCommandContext`。
- 无显式 actor 的旧销毁入口：继续走 `Script()`，不硬塞当前受控角色。

## 边界

- 不改变 `Movable.Kill()`、角色死亡、投射物寿命结束、召唤物清理等非命令销毁来源。
- 不把所有销毁都归因到当前受控角色。
- 不修改任何 prefab、场景或资产命令配置。
- 不实现控制组、多选、AI 来源归类、远程访客、网络 ownership 或 FishNet 接入。
