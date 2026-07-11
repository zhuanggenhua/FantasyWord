# Tasks: complete-composite-sandbox-character-runtime

## 0. Scope Reset

- [x] 把 `控制组进阶 / RTS 命令链 / GAS 完整合同` 从“归档后续事项”重新登记为当前正式 change 范围。
- [x] 在本 change 中挂接 foundation 归档里的参考矩阵、实施台账和验证证据来源。
- [x] 确认 `formalize-equipment-visual-workbench` 保持已完成，不再误作为当前主线。

## 1. Control Group Runtime

- [x] 复核当前 `PlayerControlGroup`、`PlayerSystem`、`IPlayerInputTarget`、`PlayerController` 现态，列出仍停留在“最小控制组输入目标”的缺口。详见 `current-state-audit.md`。
- [x] 定义控制组正式合同：成员、主控成员、命令分发类别、失控回退、读档恢复和 UI 快照读取面。代码证据为 `PlayerControlGroupSnapshot`、`PlayerSystem.GetCurrentControlGroupSnapshot / TryGetCurrentControlGroupSnapshot`、`TryAddCurrentControlGroupMember` 的单体升格控制组逻辑，以及 `ResolvePendingControlledCharacters / RevalidateCurrentControlledCharacter` 的恢复/收缩链。
- [x] 补齐控制组成员增删、切换主控、死亡/复活/变形/AI 接管后的控制权回收。代码证据为 `PlayerSystem.TryAddCurrentControlGroupMember / TryRemoveCurrentControlGroupMember / TrySetCurrentControlGroupPrimaryMember / RevalidateCurrentControlledCharacter`、`CharacterBase.NotifyCharacterDied/Revived` 和 `CharacterBase.Alterations.RevalidatePlayerControlEligibility`。
- [x] 将当前仍只按单角色处理的命令入口，区分为“主控角色专属”与“控制组批量”两类。代码证据为 `PlayerOrderRequest.TargetScope` 与 `PlayerControlGroup.ExecuteForPrimaryMember / ExecuteForAllMembers`。
- [x] 为控制组运行时补静态门禁，防止回到 UI 直接改内部集合或旁路 `PlayerSystem`。代码证据为 `Invoke-FoundationStaticGate.ps1` 新增的 `ControlGroupBypassHits`，只允许 `PlayerSystem` 与 `PlayerControlGroup` 直接触碰控制组类型。

## 2. RTS Command Runtime

- [x] 基于现有 `GameCommandContext` 和 `PlayerCommandRequest` 盘点缺口，明确正式订单对象与结果对象。已落 `PlayerOrderRequest` / `PlayerOrderResult`。
- [x] 定义停止、覆盖、追加、排队和批量下发的正式合同。代码证据为 `EPlayerOrderQueueMode`、`EPlayerOrderTargetScope`、`PlayerControlGroup.SubmitPlayerOrder` 与 `PendingOrderCount`；当前追加执行仅覆盖可排队移动订单。
- [x] 把当前已存在的多成员命令统一并到正式订单入口。代码证据为 `PlayerSystem.SubmitPlayerOrder`、`IPlayerInputTarget.SubmitPlayerOrder`、`PlayerOrderRequest.WithTargetScope / WithQueueMode / WithSpatialContract` 与 `PlayerControlGroup.ExecuteForAllMembers`；后续若新增拾取/攻击/转移/工作命令种类，也必须继续沿同一订单入口落地，不允许再回到 UI 直改世界。
- [x] 明确队形落点或等价批量落点语义，禁止 UI 或调用方各自硬编码。代码证据为 `PlayerOrderSpatialContract`、`EPlayerOrderSpatialPolicy.DistributedRing` 与 `PlayerControlGroup.ResolveDistributedRingPosition(...)`。
- [x] 为订单链补必要 smoke，证明 UI 回调不再直接改世界真相。代码与入口为 `CompositeRuntimeSmokeValidator` + `Invoke-CompositeRuntimeSmoke.ps1`，正式验收以控制组快照、`PlayerOrderRequest` 分发结果和成员 `MoveOrder.targetPosition` 写入为准。

## 3. GAS Full Contract

- [x] 复核 `attribute-gas-ownership-matrix.md`、`attribute-field-mapping.md` 与现有 `CharacterBase.*` GAS 闭包，列出仍属于 archived 过渡面的代码与存档口。现态结论已回写 `current-state-audit.md`。
- [x] 裁决 archived `Stats/currentStats`、过渡镜像、临时 fallback 和旧 effect/runtime 壳的最终退场边界。当前只保留 `CharacterBase.AttributeBootstrapBuffer` 的 bootstrap 读取窗口、`CharacterBaseDataBlock.currentStats` 的正式当前值存档快照，以及 `CharacterTemporalEffectRuntimeStateData.TryCreateArchivedExecutionShell(...)` 对未完成 formal 化的历史持续效果导入面。
- [x] 补齐属性、冷却、消耗、标签阻断、持续效果、能力授予/压制/替换/撤回的正式唯一运行时链。代码证据为 `CharacterBase.Resources.cs`、`CharacterBase.Abilities.cs`、`CharacterBase.GASRuntime.cs` 中的 `TryEvaluateFormalAbilityActivation / TryApplyFormalAbilityCost / TryApplyFormalAbilityCooldown / BeginFormalAbilityRuleLifecycle / CancelFormalAbilityRuleLifecycle` 与 `TemporalAbilityGrant / Suppression / Replacement / Control / SpeedModifier` formal 恢复链。
- [x] 补齐对象禁用、对象池复用、存档、读档恢复和 detached runtime 跟踪的正式收口。代码证据为 `LoadOwnedTemporalEffects(...)`、`TryRestoreMappedFormalTemporalRuntimeStateWithoutExecutionShell(...)`、`TrackDetachedFormalTemporalRuntime(...)`、`CollapseDetachedFormalTemporalRuntimeAfterRefreshFailure(...)` 与 `ClearLiveFormalTemporalEffectRules()`。
- [x] 为 GAS 替换补静态门禁，禁止 archived 与 formal 双轨重新回潮。验证证据为 `Invoke-FoundationStaticGate.ps1 -AsJson` 中 `GameCoreGasRuntimeReferenceHitCount = 0`、`FormalMutableStatsLeakHitCount = 0`、`CharacterBaseTemporalEffectRuntimeDisallowedPatternCount = 0`、`CharacterBasePersistenceDisallowedPatternCount = 0`。

## 4. Verification

- [x] `npx openspec validate complete-composite-sandbox-character-runtime --strict` 通过。
- [x] Foundation / plugin 边界门禁更新并通过。已复核 `Invoke-FoundationStaticGate.ps1 -AsJson` 与 `Invoke-PluginFacadeBoundaryGate.ps1 -AsJson`。
- [x] 必要 smoke 覆盖控制组、订单链和 GAS 恢复关键路径。当前证据为 `scripts/Invoke-CompositeRuntimeSmoke.ps1` 成功，覆盖控制组建立/切主/收缩、`DistributedRing` 正式落点分发，以及 `TemporalControlEffect` 的保存与读档恢复。
- [x] AIBridge 复核 Unity `isPlaying=false / isCompiling=false / isUpdating=false`。
- [x] 最近窗口 `console-get-logs` 的 Error/Exception 为空。
