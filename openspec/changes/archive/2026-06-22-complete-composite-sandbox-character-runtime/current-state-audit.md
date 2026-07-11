# Current State Audit: complete-composite-sandbox-character-runtime

## Control Group Runtime

### 当前已成立

- `PlayerSystem` 现在显式持有 `m_currentControlGroup`，控制组不再只是 `SetCurrentControlGroup(...)` 里临时 new 出来的匿名输入目标。
- [`PlayerControlGroup`](C:/Gamedev/Unity/Project/FantasyWord/Assets/Scripts/GameCore/Runtime/Controllers/PlayerControlGroup.cs) 当前已把 `成员列表 + 主控成员` 收成同一正式拥有者。
- 控制组现在支持：
  - 显式主控成员 `PrimaryMember`
  - 成员增删
  - 主控切换
  - 以主控优先的快照读取
- [`PlayerSystem`](C:/Gamedev/Unity/Project/FantasyWord/Assets/Scripts/GameCore/Runtime/Game/Systems/PlayerSystem.cs) 当前已补：
  - `TryAddCurrentControlGroupMember(...)`
  - `TryRemoveCurrentControlGroupMember(...)`
  - `TrySetCurrentControlGroupPrimaryMember(...)`
  - `GetCurrentControlGroupPrimaryMember()`
  - `CreateCurrentControlGroupSnapshot()`
  - `GetCurrentControlGroupSnapshot()`
- 控制组重建时会优先保留当前主控角色为新的主控成员；成员失控/死亡后的重校验也会回到 `PlayerSystem`，不再散在 UI 或输入回调里。
- 变形、丧尸化或其它 `CharacterAlterationRule` 导致的玩家控制锁 / AI 接管，会通过 `CharacterBase.Alterations.RevalidatePlayerControlEligibility()` 回到 `PlayerSystem.RevalidateCurrentControlledCharacter()`。
- 控制组成员增删、主控切换和 UI 快照读取面已经回到 `PlayerSystem` 的公开方法，不再要求 UI 直接触碰 `PlayerControlGroup` 内部集合。
- 命令分发类别已经通过 `PlayerOrderRequest.TargetScope` 显式区分为“主控角色专属”和“控制组批量”。
- `Invoke-FoundationStaticGate.ps1` 已新增 `ControlGroupBypassHits` 门禁，只允许 `PlayerSystem` 与 `PlayerControlGroup` 自身直接触碰控制组类型，防止 UI 或旁路系统重新越权。
- 控制组现在具备正式快照投影：`PlayerControlGroupSnapshot` 把 `主控成员 + 成员快照` 收成只读结果，UI / 调试读取不再需要拿内部集合引用。
- 读档恢复现在会同时尝试 `currentControlledCharacters` 和 `currentPrimaryControlledCharacter`，避免旧块只留主控引用时直接丢失恢复目标。
- 控制组在成员只剩 1 个时会自动收缩回单角色输入目标；从单角色升格到控制组也已经收回 `PlayerSystem.TryAddCurrentControlGroupMember(...)`。

### 当前边界

- 本 change 仍不覆盖框选、队伍级 UI 或多组切换；这些不属于本轮“控制组正式拥有者”验收面。

## RTS Command Runtime

### 当前已成立

- [`GameCommandContext`](C:/Gamedev/Unity/Project/FantasyWord/Assets/Scripts/GameCore/Runtime/Commands/GameCommandContext.cs) 已能表达 `LocalPlayer / AI / Script / RemotePlayer / Unknown`。
- [`PlayerCommandRequest`](C:/Gamedev/Unity/Project/FantasyWord/Assets/Scripts/GameCore/Runtime/Controllers/PlayerCommandRequest.cs) 已把玩家输入从 UI 回调收成正式请求对象。
- [`PlayerOrderRequest`](C:/Gamedev/Unity/Project/FantasyWord/Assets/Scripts/GameCore/Runtime/Controllers/PlayerOrderRequest.cs) 已把正式订单的 `目标范围 + 排队语义` 收成独立对象。
- `PlayerOrderRequest` 现在还显式持有 `PlayerOrderSpatialContract`，并支持 `WithTargetScope / WithQueueMode / WithSpatialContract` 这种同一订单对象上的正式覆写，而不是让脚本/AI 再造第二套订单类型。
- [`PlayerSystem`](C:/Gamedev/Unity/Project/FantasyWord/Assets/Scripts/GameCore/Runtime/Game/Systems/PlayerSystem.cs) 已把本地玩家输入入口上提到正式订单提交面，不再由 `InputSystem` 直接抓取当前输入目标后自行执行。
- [`IPlayerInputTarget`](C:/Gamedev/Unity/Project/FantasyWord/Assets/Scripts/GameCore/Runtime/Controllers/IPlayerInputTarget.cs) 现在只承载 `SubmitPlayerOrder(...)` 合同与控制快照读取面，单角色与控制组共享同一正式订单提交面。
- `PlayerControlGroup` 已能把部分命令分发给全组成员，而不是只允许单角色输入目标。
- `EPlayerOrderQueueMode` 已显式表达 `ReplaceCurrent / Append / StopCurrent`，`PlayerControlGroup.SubmitPlayerOrder(...)` 已支持停止、覆盖和可排队移动追加。
- `PlayerControlGroup.ResolveDistributedRingPosition(...)` 已把批量点击移动的分布式落点语义收成正式运行时合同；当前默认是“主点 + 环形扩散”，不再允许 UI 自己硬编码偏移魔法数。
- 当前已存在的玩家命令种类都已经统一走 `PlayerSystem.SubmitPlayerOrder(...) -> IPlayerInputTarget.SubmitPlayerOrder(...)`；后续若新增拾取/攻击/转移/工作命令，只允许继续扩同一订单入口。

### 当前边界

- `IPlayerInputTarget` 的正式对外合同已经收成订单提交面；低层 `ExecutePlayerCommand(...)` 只保留为具体控制器内部执行细节，不再作为对外接口真相。
- 当前队列执行正式覆盖的是“最小可排队移动订单”闭包；`Append` 不再是空声明，但更复杂订单族若要支持排队，后续也必须继续沿 `PlayerOrderRequest` 扩，不允许再回到 UI 旁路世界。
- 目前默认自动判成“控制组批量”的是 `Move / StopMove / ClickMove / ToggleMovementControlMode`；交互和能力类命令当前仍可通过同一正式订单入口显式指定 `TargetScope`，只是默认群发策略尚未专项扩表。

## GAS Full Contract

### 当前已成立

- `CharacterBase + ASC` 已是正式属性读取、资源写入口、通知、零血死亡判定和当前值存档的优先真相。
- 规则层与执行层已明确分工：`GAS` 管规则，`GameCore` 管动作执行。
- `TemporalAbilityGrant / Suppression / Replacement / Control / SpeedModifier` 这些正式 effect 闭包已存在。
- `archived Stats/currentStats` 当前只剩三类边界：`AttributeBootstrapBuffer` 的 bootstrap 读取窗口、`CharacterBaseDataBlock.currentStats` 的正式当前值存档快照、以及未 formal 化历史持续效果导入所需的 archived execution shell 重建面；它们已不再参与正式运行时读写裁决。
- `ActiveAbilityBase` 当前会把能力前提、消耗、冷却、激活生命周期和取消链优先委托给 `CharacterBase.GASRuntime` 的 `TryEvaluateFormalAbilityActivation / TryApplyFormalAbilityCost / TryApplyFormalAbilityCooldown / BeginFormalAbilityRuleLifecycle / CancelFormalAbilityRuleLifecycle`。
- 已映射 formal GameplayEffect 的持续效果现在优先走 `TryRestoreMappedFormalTemporalRuntimeStateWithoutExecutionShell(...)` 与 detached runtime 跟踪；formal 恢复失败时会主动清理半挂 spec/registry，不再回退成第二条长期 live truth。

### 当前验证证据

- 现在已经有专用 smoke：`CompositeRuntimeSmokeValidator + Invoke-CompositeRuntimeSmoke.ps1`，并已覆盖控制组建立/切主/收缩、正式 `PlayerOrderRequest` 分发、`DistributedRing` 目标写入，以及 `TemporalControlEffect` 的保存/读档恢复。

## 本轮结论

这次 change 已经把 `控制组正式拥有者 + RTS 正式订单链 + GAS 单一真相边界` 推进到正式实现、静态门禁和必要 smoke 层。当前留下的是后续可扩表的命令族与 UI 能力边界，不是这三块框架真相仍未完成。
