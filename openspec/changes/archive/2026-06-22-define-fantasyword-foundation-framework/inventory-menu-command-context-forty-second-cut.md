# 第四十二刀：库存菜单请求跟随当前受控角色上下文

## 背景

第四十一刀后，召唤物主动清理链路已经能跟随召唤者上下文。但库存菜单仍有一个更贴近日常操作的来源降级点：默认背包菜单通过 `InventoryMenuContext.CurrentControlledCharacter()` 跟随当前受控角色显示和操作，实际生成 `InventoryTransferRequest` 时却会在没有显式 actor 的情况下回退成 `GameCommandContext.Unknown(ResolveActor())`。

这会让本地玩家正在操作当前受控角色背包时，转移请求只保留 actor，却丢掉“这是本地玩家发起”的来源分类。对单机来说它暂时还能通过 actor 参与者校验；但对后续控制组、AI、远程访客和主机权威兼容边界来说，这会把“谁发起动作”和“哪个角色参与背包转移”混在一起。

## 本刀变更

- `InventoryMenuContext` 新增 `ResolveCommandContextForActor(...)`。
- 默认当前受控角色菜单在真正创建转移请求时，如果解析出的 actor 是当前受控角色，则返回 `GameCommandContext.LocalPlayer(actor)`。
- actor 存在但不是当前受控角色时，仍返回 `GameCommandContext.Unknown(actor)`，保留 actor 但不伪造 AI、远程访客或本地玩家来源。
- actor 缺失时继续返回 `GameCommandContext.Unknown()`。
- `TransferToCharacter(destination, ...)` 这个简化入口也改走同一解析逻辑，避免调用方只传目标角色时默认降级成 Unknown。
- 已显式传入的上下文继续优先保留；例如宝箱、尸体搜刮和命令对话链路传入的上下文不会被库存菜单重新猜测。
- `Invoke-FoundationStaticGate.ps1` 新增 `InventoryMenuContextMissingPatternCount / InventoryMenuContextDisallowedPatternCount`，防止默认库存菜单回退到 `GameCommandContext.Unknown(destination)` 或 `GameCommandContext.Unknown(ResolveActor())`。

## 上下文语义

- 当前受控角色打开自己的默认背包并触发库存转移：请求来源是 `LocalPlayer(actor)`。
- 当前受控角色打开宝箱或尸体库存并转移到自己：沿打开入口传入的 `LocalPlayer(actor)`。
- 非当前受控角色作为目标或操作者：保留 `Unknown(actor)`，只说明动作关联到该 actor，不替 AI、远程访客或网络 ownership 下判断。
- 无 actor 的系统脚本或错误入口：继续保留 Unknown 或显式传入的非 actor 上下文。

## 边界

- 不改变库存 owner、物品数量、金钱、装备槽或存档结构。
- 不实现双栏容器 UI、队伍背包 UI、控制组库存、多选库存分配或角色间拖拽转移。
- 不实现 AI 背包决策、远程访客控制、网络 ownership 或 FishNet 接入。
- 不把库存菜单变成权限裁决者；库存转移裁决仍由 `InventorySystem.ExecuteTransfer(...)` 负责。
