# AI 感知与视线迁移

原版锁定：Unity `31629d53a110dd4c87d4c85e6ad5a387fbafb931`。

本阶段把真实 Godot 物理观测接入已迁移的选敌生命周期，不代表原版 NPC 已完整迁移，也不声称两个引擎的重叠结果顺序一致。

## 原版依据

- `Assets/Scripts/GameCore/Runtime/Controllers/AIController.BehaviourRuntime.cs` 的 CanSee/FindTarget：从控制器位置向角色位置发射有限距离射线，只传视线层掩码，任何命中都阻挡；从碰撞体向父级寻找 CharacterBase，保留检测顺序，不擅自加最近排序、角色去重、死亡筛选或自身豁免。
- `Assets/GameData/GameCore/GameConfig.asset`：视线3144、移动7752、角色语义/邻居256。`ProjectSettings/Physics2DSettings.asset` 的 queriesHitTriggers、queriesStartInColliders 均启用。虽然视线 ContactFilter 序列化 useTriggers=false，实际 CanSee 重载只传掩码，所以射线必须包含触发器和起点内部命中，不能误用语义重叠查询的过滤条件。
- `Assets/ProjectPlugins/ContextSteering2D/Runtime/SteeringDetectionScheduler2D.cs`：重叠查询半径取障碍探测与语义半径最大值，缓冲下限8，满缓冲在所有过滤之前失败；语义加入条件只查层和触发器，不重新核对语义距离。`ContextSteeringAgentHandle2D.CreateUnionFilter` 合并三者掩码，本项目三项过滤均禁止触发器。
- `Assets/Scripts/GameCore/Runtime/Combat/CombatSolver.cs`：复用既有规则，实时取阵营、死亡、无敌状态；中立不主动敌对。每个观察者持有独立感知实例，相对关系不写回共享角色状态。角色移动或离开检测半径后，已持有的目标字典身份保持不变，调用者继续刷新视线。

## 已验证范围

`tests/test_ai_perception.gd` 创建真实物理体、触发区域和角色父节点，执行形状查询与射线，将观测送入目标生命周期，并证明真实遮挡触发原版丢失视线超时与重置。共21项检查，覆盖子碰撞体身份、无角色物体、重复及顺序、掩码、触发器区别、射线起点内部、有限长度、零半径、探测半径扩大与缓冲溢出。

## 未验收边界

当前仅迁移语义观测，不是完整邻居/障碍转向评分。调用者须提供真实控制器位置、附属刚体身份、配置半径及世界缓冲容量；角色节点通过显式元数据适配，禁止按名称猜测。Unity 多子碰撞体共用刚体在 Godot 拆成独立物理体的情况仍需验证身份映射。Godot 与 Unity 的重叠同序未证实；有序观测接口保留输入顺序，当前测试不宣称多目标原生顺序一致。零长度射线、跨引擎边界接触精度未验证。

原版训练假人确有 AI 和正式技能绑定，本阶段没有把它改成被动设计；当前玩家战斗诊断另有明确边界。真实 NPC 转向、技能执行和整场景还原仍需后续接入。
