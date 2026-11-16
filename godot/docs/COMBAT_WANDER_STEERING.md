# 战斗游走方向评分

源码锁定为 Unity `31629d53a110dd4c87d4c85e6ad5a387fbafb931`。对应 `Assets/ProjectPlugins/ContextSteering2D/Runtime/` 中的 `CombatWanderSteeringBehaviour2D.cs`、`SteeringContext2D.cs`、`ContextSteeringSolver2D.cs` 和 `Defaults/DefaultContextSteeringProfile2D.asset`。

`combat-wander` 组依次求障碍规避、战斗游走、邻居分离，权重均为 1。复用 `transit_steering.gd` 的障碍与分离贡献，不使用其综合结果、目标趋近或侧步贡献。方向表从 Unity 的 +Y 起顺时针排列，共 16 个采样。输入保持 Unity XY，Y 轴换向由物理边界负责。

有缓存游走意图和非重合目标才计算游走贡献。切向为 `(radial.y, -radial.x) * side_sign`。障碍用最近点计算距离和邻近权重；各危险向量之和的模长严格大于 1 才在两侧中选危险较低的一侧，危险相同时仍用原侧。同侧一个完全邻近的障碍不能单独触发换侧。

超过跟随距离时增加径向兴趣，权重为 `(distance - max(follow_distance, 0.0001)) / max(follow_distance, 0.0001)`。同一行为的各采样取切向与径向最大值，不相加。行为组按顺序累加，先钳兴趣和约束，再以 `interest * (1 - constraint)` 求剩余分数。采样方向按分数加权；最大剩余分数用于计算首选速度。该组没有减速或停车半径贡献。

`test_combat_wander_steering.gd` 覆盖 27 项，包括空输入、跟随距离、求和规则、换侧阈值、组成员、速度和输入不变。这里证明的是方向评分，不证明原版浮点逐位等价、RVO 的安全速度、角色移动、原场景或画面。不得把首选速度直接写回为安全速度。
