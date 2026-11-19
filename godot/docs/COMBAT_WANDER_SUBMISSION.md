# 战斗游走：控制器提交和安全结果回写

锁定 Unity 源码 `31629d5`。`AIController.BehaviourRuntime.ApplyMovement` 在目标状态刷新后，先用角色当前位置与缓存目标点的距离判定战斗游走；目标短暂不可见时，位置使用最后可见位置，但刚体速度仍取本步的目标值。战斗游走优先于近身追击和路径；没有进入这条分支就不消耗随机或推进游走意图计时。ClickMoveTest 的游走组为 `combat-wander`，范围 3，攻击半径 1，语义半径 5，倍率 1；游走保持原朝向，不使用普通追击的攻击对准覆盖。

`CharacterSteeringRuntime2D.Submit / ApplyLatestResult` 是先提交、再消费已发布结果，不以刚生成的方向分数代替 RVO 输出。提交即时写入句柄的 MaxSpeed，可能与产生上一份安全速度时的 MaxSpeed 不同。速度比使用本次提交的最大速度并设分母下限，按 SafeVelocity 长度钳在 0 至 1；应用推挤修正后写入安全方向。方向是否为零使用 `SteeringResult2D` 的平方长度阈值，和速度比是两个独立判断。动作锁只阻止朝向写入，不撤掉已提交的运动。本模块保留这段契约，使用 Y 向上的坐标；测试检查调用顺序、边界和状态，不运行调度器、RVO 或正式角色移动，不构成原场景追击验收。

独立的原生物理集成测试从实际 Godot 方形碰撞体采样最近点，再用原游走意图生成首选方向：同侧两个近障碍触发换边，一个时不触发。测试只连通意图、检测和首选评分，不向角色提交速度或代替安全求解。

## 原随机源边界

源 `CombatWanderRuntime2D.Tick` 调用同一个 Unity 原生全局随机状态的
`Random.value` 后调用浮点重载 `Random.Range(min,max)`，包含端点。
[Unity 6000.3 Random](https://docs.unity3d.com/6000.3/Documentation/ScriptReference/Random.html)
说明它使用 Xorshift 128、启动时从系统取高熵种子、状态由全局调用共享。
[同版本托管绑定](https://github.com/Unity-Technologies/UnityCsReference/blob/6000.3/Runtime/Export/Random/Random.bindings.cs)
只声明原生入口，不提供种子展开、浮点映射或源场景其它调用的完整时序。
不能把 Godot RNG、临时猜测的同名算法或固定测试抽样当原实现。

游走意图输入缺失、非数字、非有限或越界时，本移植拒绝当拍结果，
不能沿用过期意图或把已选游走分支改成追击。有效缓存未到重抽点时
不额外消费随机样本。有效的有序样本只证明该输入下的源分支与时序；
要核对 Unity 与 Godot 同序列，需同一个原运行的种子/状态及本分支的
按拍有序抽样，并核对双端的步长和其它共享随机消费。此处不接默认随机，
不宣告已从原出生位自然追至普攻。
