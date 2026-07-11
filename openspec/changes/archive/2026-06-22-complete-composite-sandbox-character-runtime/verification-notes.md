# Verification Notes: complete-composite-sandbox-character-runtime

## 已验证

- `npx openspec validate complete-composite-sandbox-character-runtime --strict` 通过。
- `scripts/Invoke-FoundationStaticGate.ps1 -AsJson` 通过；并已把门禁签名更新到当前正式订单/点击移动合同。
- `scripts/Invoke-PluginFacadeBoundaryGate.ps1 -AsJson` 通过，`ViolationCount = 0`。
- Unity AIBridge 复核时，编辑器状态满足 `isPlaying=false / isCompiling=false / isUpdating=false`。
- `scripts/Invoke-FoundationBridgeSmoke.ps1` 通过，`AssetsRefresh` 成功，Editor 状态稳定。
- `scripts/Invoke-CompositeRuntimeSmoke.ps1` 通过，正式覆盖控制组 / RTS 订单链 / GAS formal 恢复关键路径。
- `python .codex/skills/aibridge/bridge.py assets-refresh '{"options":"ForceSynchronousImport"}'` 成功。
- `python .codex/skills/aibridge/bridge.py console-get-logs '{"maxEntries":80,"includeStackTrace":true,"lastMinutes":10}'` 返回空数组，没有新的 `Error / Exception`。

## 现态证据

- 控制组正式 owner 已收口到 `PlayerSystem + PlayerControlGroup`。
- 正式订单对象已收口到 `PlayerCommandRequest + PlayerOrderRequest + PlayerOrderResult`。
- 订单分发现在已补批量空间落点合同：`PlayerOrderSpatialContract + DistributedRing` 把点击移动的分布式目标语义收回运行时，调用方不再自己算偏移。
- GAS 侧当前正式结论是“运行时真相已单一，archived 面已压成兼容边界”：属性读写、能力冷却/消耗/标签阻断、持续效果 formal 恢复和 detached runtime 跟踪都已回到 `CharacterBase + ASC` 正式闭包；剩余 archived 面只作为 bootstrap / 存档兼容 / 历史 effect 导入存在。
- `CompositeRuntimeSmokeValidator` 当前正式验收口径是：
  - 控制组建立、主控切换与收缩都必须经由 `PlayerSystem + PlayerControlGroup`。
  - `PlayerOrderRequest` 必须把订单分发给 2 个成员，并把 `MoveOrder.targetPosition` 分别写到主控锚点与 `DistributedRing` 分布点。
  - `TemporalControlEffect` 必须通过正式入口应用，并在保存 / 读档后保持展示快照、`runtimeKey` 与移动锁定状态。
