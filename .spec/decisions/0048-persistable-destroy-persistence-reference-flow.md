# 0048-持久化对象销毁参考流程边界

- 日期：2026-07-16
- 状态：已采纳
- 背景：
  - 本轮继续按 `0046-参考流程优先的 GameManager 系统访问审计边界` 复核 `TryGetSystem` 调用面。
  - 2DRPGEngine 同职责流程中，`Persistable.Destroy()` 会先标记对象已销毁，再通过正式通知链让 `PersistenceSystem` 记录自动持久化对象的销毁状态；它不是“存档系统没就绪时跳过”的表现流程。
  - FantasyWord 当前已经把全局通知改成 `PersistableDestructionSnapshot -> PersistenceSystem.NotifyPersistableDestroyed(...)`，这是合理的项目适配；但旧实现通过 `GameManager.Exists()` / `TryGetSystem<PersistenceSystem>()` 查询失败后直接返回，会把正式持久化销毁结果静默吞掉。
- 决策：
  - `Persistable.NotifyPersistenceSystemAboutDestruction()` 必须直接使用 `GameManager.PersistenceSystem.NotifyPersistableDestroyed(...)`。
  - 缺少正式 `PersistenceSystem` 时应暴露配置错误，不能把自动持久化对象的销毁状态丢掉后继续销毁 GameObject。
  - `PersistableReference<T>.TryResolve(...)` 仍可保留非抛错查询语义，因为它表达的是“保存引用当前能否解析到活对象”，不是销毁结果写入。
- 影响：
  - 这不是“单例更好”的结论；它只是参考同职责销毁流程证明该路径属于正式存档结果，不能使用 `TryGetSystem` 静默跳过。
  - 后续审计保存、地图、任务、奖励等结果链时，必须继续先看参考同职责流程，再判断是否允许失败返回。
- 替代关系：
  - 本决策是 0046 在持久化对象销毁同职责流程上的落地案例。
