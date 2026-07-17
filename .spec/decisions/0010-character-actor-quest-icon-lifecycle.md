# 0010-角色任务浮标监听生命周期 owner 边界

- 日期：2026-07-15
- 状态：已采纳
- 背景：
  - CharacterActor 需要根据任务解锁、可接取、进行中、达成和完成事件刷新头顶任务浮标。
  - 2DRPGEngine 的 NPC 使用 `Start()` 注册任务事件，并在 `OnDestroy()` 中注销；参考实现甚至有一处可接取事件注销误写成再次 AddListener。
  - FantasyWord 角色可能被禁用、复活、池化或随场景生命周期暂停；禁用期间继续响应任务事件会让不可见或失效对象继续读 JournalSystem 并刷新表现。
- 决策：
  - 角色任务浮标事件监听的 owner 是 CharacterActor 当前启用状态；监听必须跟随 `OnEnable/OnDisable`。
  - 注册和注销必须幂等，避免重复启用导致重复监听，销毁只作为兜底停止。
  - `OnEnable` 可能早于 GameManager/JournalSystem 完全就绪，刷新任务浮标前必须先确认系统存在。
- 影响：
  - `CharacterActor.Quest` 已从 `Start/OnDestroy` 改为 `OnEnable/OnDisable` 启停任务事件监听。
  - 新增 `m_questStatusListening` 防重复注册和重复注销。
  - `UpdateFloatingIcon()` 在 GameManager 或 JournalSystem 未就绪时直接返回，不把启动时序问题变成空引用。
  - 新增 `scripts/Invoke-CharacterActorRuntimeStaticGate.ps1`，覆盖 Start 绑定回流、缺少 OnDisable 注销、非幂等监听和浮标刷新缺少系统就绪检查。
- 替代关系：
  - 本决策保留 2DRPGEngine 的 NPC/任务浮标职责形状。
  - 本决策取代参考工程中“任务浮标监听只绑定创建/销毁”的实现细节；FantasyWord 的正式角色表现监听以启用状态为准。
