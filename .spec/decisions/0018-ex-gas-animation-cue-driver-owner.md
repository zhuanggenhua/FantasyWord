# 0018-EX-GAS 动画 Cue 驱动 owner 边界

- 日期：2026-07-15
- 状态：已采纳
- 背景：
  - EX-GAS 插件通用 `CuePlayAnimator` 使用 `AnimatorNodePath` 字符串定位子节点上的 Animator。
  - FantasyWord 正式角色动画已经收口到 `ICharacterAnimationDriver`，由角色 Prefab 显式提供动作播放、默认动作恢复和编辑器预览能力。
  - 当前正式 `CuePlayGameCoreAnimator` 数据中的 `AnimatorNodePath` 全为空；继续保留运行时路径解析只会留下隐藏层级 owner 和硬编码路径回流入口。
  - 参考工程中“按路径找到 Animator 再播放状态”的流程只适合简单整套 Animator 播放，不适合作为 FantasyWord 角色动作、武器表现和换装表现的正式入口。
- 决策：
  - FantasyWord 正式 EX-GAS 动画 Cue 的表现 owner 是目标对象树上的 `ICharacterAnimationDriver`，不是 EX-GAS 表里的 Animator 子节点路径。
  - `CuePlayGameCoreAnimator` 必须从目标对象及其子级解析 `ICharacterAnimationDriver`，不得读取 `AnimatorNodePath`，也不得使用 `transform.Find()` 按字符串路径定位正式表现节点。
  - EX-GAS 时间轴数据中 `CuePlayGameCoreAnimator.AnimatorNodePath` 必须保持为空；若未来需要多个动画驱动，必须新增显式语义 owner 或 Prefab 接线，不得恢复层级路径字符串。
  - 插件通用 `CuePlayAnimator` 可作为外部插件能力保留，但不得被 FantasyWord 正式 GameCore 动画 Cue 当作当前规范。
- 影响：
  - `CuePlayGameCoreAnimator` 只依赖目标对象树中的 `ICharacterAnimationDriver`。
  - `scripts/Invoke-FormalGasResourceStaticGate.ps1` 严格模式已扩展检查非空 `AnimatorNodePath` 和正式 Cue 运行时代码中的路径解析回流。
  - 现有 EX-GAS 生成数据不需要迁移，因为当前正式值均为空。
- 替代关系：
  - 本决策细化 `0001-EX-GAS 资源身份 owner`，把 EX-GAS 动画 Cue 的表现节点身份也纳入“正式 owner 不依赖编辑器路径/层级路径字符串”的边界。
