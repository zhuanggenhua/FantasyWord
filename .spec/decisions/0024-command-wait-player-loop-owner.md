# 0024-等待命令延迟 owner 边界

- 日期：2026-07-15
- 状态：已采纳
- 背景：
  - `Wait` 是数据驱动命令系统中的延迟命令，可能出现在对话、任务、触发器、死亡收口或菜单流程中。
  - 旧实现为了兼容 WebGL 不使用 `Task.Delay`，但把等待协程挂到全局 `GameManager.Instance`；这会让命令等待生命周期由全局对象代持，而不是由命令执行流程本身返回的 `Task` 表达。
  - 项目已经正式安装 UniTask，且本地 API 提供基于 Unity PlayerLoop 的 `UniTask.WaitForSeconds()`，不需要再额外找一个 `MonoBehaviour` 承载协程。
- 决策：
  - `Wait` 命令的延迟等待由 Unity PlayerLoop 驱动，通过 `UniTask.WaitForSeconds()` 返回到命令 `Task` 链。
  - `Wait` 不得启动协程、不得创建 `TaskCompletionSource` 桥接协程、不得依赖 `GameManager.Instance` 作为隐式运行 owner。
  - 等待时长继续使用 Unity 缩放时间语义；负值在运行时按 0 处理，并在 Inspector 中用非负字段约束作者输入。
- 影响：
  - `Wait.Execute(GameCommandContext)` 不再需要 `MonoBehaviour` 参数，也不会因全局 `GameManager` 禁用、销毁或替换影响命令等待。
  - 命令门禁新增 `WaitCommandUsesPlayerLoopDelay`，防止 `Wait` 回退到全局协程 owner 或 `TaskCompletionSource` 协程桥。
  - 本决策只收口等待命令的调度 owner，不改变命令系统的上下文、任务完成等待或后台异常报告合同。
- 替代关系：
  - 本决策延续 `0008-命令异步执行 owner 边界`，细化等待命令的异步调度方式。
  - 本决策取代旧实现中“为了 WebGL 兼容而由 `GameManager.Instance` 启动等待协程”的实现细节。
