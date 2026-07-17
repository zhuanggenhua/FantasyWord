# 0021-Transform 抖动协程 owner 边界

- 日期：2026-07-15
- 状态：已采纳
- 背景：
  - `TransformShaker` 是通用局部位置抖动工具，当前被 `CameraShake` 和 `UIStatBar` 使用。
  - 该工具原先通过 `GameManager.Instance.StartCoroutine()` 承载协程，导致一个纯表现抖动的生命周期挂到全局 GameManager 上。
  - 调用组件禁用时，应立即停止自己的抖动并恢复目标位置；不能依赖全局协程继续跑完。
- 决策：
  - `TransformShaker.Shake()` 必须接收显式 `MonoBehaviour owner`，由发起抖动的组件承载协程。
  - `TransformShaker` 不得直接访问 `GameManager.Instance` 或其它全局协程 runner。
  - `CameraShake` 和 `UIStatBar` 必须在 `OnDisable` 中停止当前抖动；`UIStatBar` 在 `OnDestroy` 中也保留兜底停止。
  - 抖动协程必须在目标 Transform 已销毁时安全退出，不能继续写空目标。
- 影响：
  - 镜头抖动和资源条抖动的协程生命周期跟随各自组件。
  - 禁用对应组件会中断抖动并恢复启动时局部位置。
  - `scripts/Invoke-AnimationRuntimeStaticGate.ps1` 已扩展检查显式协程 owner 和调用点清理合同。
- 替代关系：
  - 本决策取代 `TransformShaker` 中“用全局 GameManager 承载表现协程”的隐式生命周期。
