# 0019-主菜单 Cancel 输入监听生命周期 owner 边界

- 日期：2026-07-15
- 状态：已采纳
- 背景：
  - `UIMainMenu` 是主菜单根面板，负责存档入口、设置菜单入口和默认按钮选择。
  - 主菜单原先在 `Start()` 注册 UI Cancel 输入，只在 `OnDestroy()` 注销；如果主菜单对象被临时禁用，仍可能继续消费 Cancel 并驱动设置菜单隐藏。
  - `InputSystem` 是正式 UI 输入真相源，面板只应在自身启用期消费对应输入。
  - 主菜单可能早于 `GameManager` / `InputSystem` 完全就绪，因此注册入口需要具备就绪检查和 `Start` 重试。
- 决策：
  - 主菜单 Cancel 输入监听的 owner 是 `UIMainMenu` 的启用状态，而不是对象创建/销毁状态。
  - `UIMainMenu` 必须在 `OnEnable` 尝试注册 Cancel 输入，`Start` 只作为 `GameManager` / `InputSystem` 稍后就绪的重试入口。
  - `UIMainMenu` 必须在 `OnDisable` 和 `OnDestroy` 退订 Cancel 输入，并使用幂等标记避免重复注册或重复注销。
  - `UIMainMenu` 不直接读取原始 Input Action，仍通过项目 `InputSystem` 的 UI 动作语义入口注册。
- 影响：
  - 禁用主菜单对象后，它不再继续消费 Cancel 输入。
  - `scripts/Invoke-UIRuntimeStaticGate.ps1` 已扩展检查主菜单 Cancel 输入启用/禁用生命周期。
  - 本决策不改变主菜单从存档入口进入游戏场景的现有流程。
- 替代关系：
  - 本决策取代 `UIMainMenu` 中“Start 注册、OnDestroy 注销”的隐式输入监听生命周期。
