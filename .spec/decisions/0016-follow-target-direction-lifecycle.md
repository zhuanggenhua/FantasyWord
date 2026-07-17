# 0016-朝向跟随表现监听生命周期 owner 边界

- 日期：2026-07-15
- 状态：已采纳
- 背景：
  - `Movable` / `CharacterBase` 是角色目标朝向的真相源，通过目标朝向变化事件通知外部表现组件。
  - `FollowTargetDirection` 是挂在子对象上的朝向跟随表现组件，负责按角色目标方向翻转 Sprite、反向缩放或旋转局部表现。
  - 该组件原先在 `Awake()` 注册目标朝向事件，但没有在禁用或销毁时注销；对象禁用后仍可能响应角色朝向变化。
  - 表现组件启用时还应立即应用一次当前目标方向，不能只等待下一次方向变化事件。
- 决策：
  - 朝向跟随表现组件的监听 owner 是组件启用状态。
  - `FollowTargetDirection` 必须在 `OnEnable` 尝试注册目标朝向事件，`Start` 只作为目标稍后就绪或 Unity 时序重试入口。
  - `FollowTargetDirection` 必须在 `OnDisable` 和 `OnDestroy` 退订目标朝向事件，并使用幂等标记避免重复注册或重复注销。
  - 成功绑定目标后必须立即读取并应用 `GetTargetDirection()`，确保启用时表现和角色当前朝向一致。
- 影响：
  - `FollowTargetDirection` 不再在 `Awake()` 注册事件，只在启用期监听目标朝向。
  - 新增 `scripts/Invoke-AnimationRuntimeStaticGate.ps1`，检查该组件的注册/注销生命周期和启用时当前方向同步。
- 替代关系：
  - 本决策不改变 `Movable` 的朝向真相源和事件 API。
  - 本决策取代朝向跟随表现组件中“Awake 注册、无退订”的隐式生命周期。
