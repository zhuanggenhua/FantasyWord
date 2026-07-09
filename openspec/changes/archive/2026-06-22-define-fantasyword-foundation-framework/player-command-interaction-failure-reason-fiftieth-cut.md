# 第五十刀：交互命令失败原因细分

## 背景

第四十九刀已经让本地玩家命令失败进入 HUD 表现出口，但交互失败仍有一个语义混淆：`PlayerInteractionRuntime.ResolveInteractibleObject()` 在角色不能执行 `Interact` 动作时返回 `null`，`PlayerController.ExecuteInteractCommand(...)` 又把所有失败统一转成 `BlockedByState`。结果是角色被变形、感染、丧尸化或其它动作锁阻断交互时，HUD 只能提示 `Nothing to interact with.`，看起来像前方没有目标。

这不符合当前用户故事：角色能力和动作许可可能随状态实时变化，部分能力保留、部分能力被禁用。玩家需要知道是“目标不存在”，还是“这个角色现在不能交互”。

## 实施

- `PlayerCommandRequest.cs`
  - `EPlayerCommandFailureReason` 新增 `InteractionLocked`。
- `PlayerController.InteractionRuntime.cs`
  - 新增 `CanInteractNow()`，只回答当前角色是否允许执行交互动作。
- `PlayerController.cs`
  - `ExecuteInteractCommand(...)` 先判断控制器运行态，再判断 `interactionRuntime.CanInteractNow()`。
  - 动作锁阻断返回 `InteractionLocked`。
  - 无可交互目标或没有交互接收者仍返回 `BlockedByState`，继续对应“没有可交互目标”。
- `UIHUDAbilityMessage.cs`
  - `InteractionLocked + Interact` 映射到 `I can't interact right now.`。
  - `BlockedByState + Interact` 继续映射到 `Nothing to interact with.`。
- `Invoke-FoundationStaticGate.ps1`
  - 把新失败原因、控制器判断口和 HUD 映射纳入静态门禁。

## 边界

- 不新增交互距离裁决。
- 不新增自动靠近、导航 Provider 或目标合法性系统。
- 不新增背包满、负重、阵营权限、本地化、提示音或节流。
- 不改变 `IInteractionReceiver` 派发合同。
- 不接入 ECS、FishNet、RPC、NetworkObject 或联机 ownership。

## 当前结论

本刀只修正本地玩家交互失败反馈的语义准确性：动作锁导致不能交互和前方没有交互目标已经可区分。它仍不是完整命令失败反馈系统，也不是完整控制组、RTS 订单或联机准备完成。

## 验证

- 本轮触碰文件尾随空格搜索无命中。
- `git diff --check` 通过。
- `powershell -ExecutionPolicy Bypass -File .\scripts\Invoke-FoundationStaticGate.ps1 -AsJson` 通过，关键结果包括 `PlayerCommandRequestMissingPatternCount = 0`、`PlayerControllerMissingPatternCount = 0`、`PlayerControllerInteractionRuntimeMissingPatternCount = 0`、`UIHUDAbilityMessageMissingPatternCount = 0`。
- `npx openspec validate define-fantasyword-foundation-framework --strict` 通过。
- AIBridge `assets-refresh {"options":"ForceSynchronousImport"}` 成功；Editor 状态为 `isPlaying = false`、`isCompiling = false`、`isUpdating = false`；最近 1 分钟 Console 的 `Error = []`、`Exception = []`。
