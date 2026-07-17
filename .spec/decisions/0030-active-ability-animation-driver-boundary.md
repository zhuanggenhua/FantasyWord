# 0030-主动能力动画驱动 owner 边界

- 日期：2026-07-15
- 状态：已采纳
- 背景：
  - `ActiveAbilityBase` 中保留了旧的 Animator Trigger 辅助方法，会在能力基类里从角色子级自动查找 Animator 并尝试写 Trigger。
  - 全仓搜索确认这些方法没有被任何正式能力子类调用；当前正式动作表现已经由 `ICharacterAnimationDriver` 和 EX-GAS Gameplay Cue 承担。
  - 主动能力基类继续保留 Animator Trigger 死入口，会让能力规则层重新具备表现层查找和参数写入权限，和当前“玩法层只请求语义动作”的边界冲突。
- 决策：
  - 删除 `ActiveAbilityBase` 中未使用的角色 Animator 缓存、子级 Animator 自动查找和 Trigger 写入辅助方法。
  - 主动能力不得直接解析 Animator、遍历 Animator 参数或写 Trigger；需要角色动作时走 `ICharacterAnimationDriver` 语义入口，需要 GAS 时间轴表现时走正式 Gameplay Cue。
  - 新增能力运行时静态门禁，禁止主动能力目录回流 `GetComponentInChildren<Animator>`、`AnimatorControllerParameter`、`SetTrigger` 和旧 Trigger helper。
- 影响：
  - 主动能力基类只保留输入门、冷却、消耗、GAS 规则生命周期和能力上下文职责。
  - 能力表现入口不会绕过当前角色动画驱动和换装表现链路。
  - 未来新增能力如果需要动画，必须显式接入现有语义驱动或 Cue，而不是在能力内部重新找 Animator。
- 替代关系：
  - 本决策补强 `0018-EX-GAS 动画 Cue 驱动 owner 边界` 和 `004-动作 key / AnimationType owner` 模块中形成的表现边界。
