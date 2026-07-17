# 0049-角色死亡与控制重算 PlayerSystem 参考流程边界

- 日期：2026-07-16
- 状态：已采纳
- 背景：
  - 本轮继续按 `0046-参考流程优先的 GameManager 系统访问审计边界` 复核 `TryGetSystem` 调用面。
  - 2DRPGEngine 同职责流程中，`Hero.OnDeath()` 直接发布正式玩家死亡通知；玩家死亡不是表现层可跳过事件，而是玩家状态、菜单、对话中断和死亡动作的规则结果。
  - FantasyWord 把原全局通知细化为 `PlayerSystem.NotifyCharacterKilled/Died/Revived` 与当前控制目标重算，这是当前项目的合理适配；但这些入口旧实现通过 `GameManager.Exists()` / `TryGetSystem<PlayerSystem>()` 查询失败后直接跳过，会把玩家死亡动作、当前控制目标回退或变身后的控制资格重算静默吞掉。
- 决策：
  - `CharacterActor.OnDeath()` 必须直接调用 `GameManager.PlayerSystem.NotifyCharacterKilled(this)`。
  - `CharacterBase.NotifyPlayerSystemAboutDeath()` 与 `NotifyPlayerSystemAboutRevive()` 必须直接调用 `GameManager.PlayerSystem` 的对应控制通知。
  - 角色变身、感染或控制资格规则变化后的 `RevalidatePlayerControlEligibility()` 必须直接调用 `GameManager.PlayerSystem.RevalidateCurrentControlledCharacter()`。
  - 缺少正式 `PlayerSystem` 时应暴露场景配置错误，不能把玩家死亡动作或当前控制目标重算静默跳过。
- 影响：
  - 这不是“单例更好”的结论；它只是参考同职责玩家死亡流程证明该路径属于正式玩家控制结果，不能使用 `TryGetSystem` 静默跳过。
  - UI、HUD、镜头、调试面板等监听当前控制角色的显示层仍可保留就绪查询，因为这些路径表达的是“组件启用早于系统时先不订阅/不显示”，不是规则结果写入。
- 替代关系：
  - 本决策是 0046 在角色死亡与玩家控制目标同职责流程上的落地案例。
