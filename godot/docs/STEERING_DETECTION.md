# 战斗转向：原生物理检测输入

源码锁定为 Unity `31629d53a110dd4c87d4c85e6ad5a387fbafb931`。对应 `Assets/ProjectPlugins/ContextSteering2D/Runtime/SteeringDetectionScheduler2D.cs` 的 `BuildFrame`、`CollectRegisteredNeighbours` 和 `AgentSpatialIndex2D.Collect`。

- 原生物理重叠按障碍探测和语义查询较大半径，使用原控制器的 `7752 | 256` 掩码，不含触发器。缓冲区至少 8 个；在自身过滤前达到容量即拒绝本帧，不按截断结果继续。
- 已注册对象仍可进入语义候选，但包括未激活注册对象在内，都不作为普通障碍。合适的未注册障碍使用碰撞体的最近点、零半径及静态标记；源联合查询没有额外的距离过滤。
- 邻居来自注册表而非重叠检测，保留邻居半径内活动、非自身的角色层对象。网格按 Y、X 遍历，格内按注册顺序。调用者应提供原网格尺寸和同一仿真步的登记信息。登记键为 `body`、`colliders`、`agent_id`、`active`、`radius`、`velocity`、`mass`、`priority`。
- 障碍输出为 `{point, radius, is_static}`；邻居为 `{agent_id, position, radius, velocity, mass, priority}`。仅在进出物理接口时翻转 Y。普通 `StaticBody2D` 映射源静态，`AnimatableBody2D` 不算静态。

障碍仅支持单个启用的矩形或均匀缩放圆。矩形支持旋转和正交的非均匀缩放；在内部则返回查询点本身。遇到倾斜或退化变换、多形状、非均匀圆、胶囊、多边形或复合碰撞，明确返回失败，不猜最近点、不默默漏障碍。本阶段以一个 Godot 对象对应一个 Unity 碰撞体，多碰撞体身份、原生重叠返回顺序和精确浮点边界未验收。

`test_steering_detection.gd` 使用 Godot 原生物理验证最近点、零半径、过滤、活动邻居及顺序、原生矩形与圆边界、拒绝不支持几何及满缓冲。还未接正式场景的注册生命周期、时间步、RVO 或角色玩法；不能以此替代既有的选敌感知或宣告完整迁移。

## ClickMoveTest：单活动假人 Transit 接线

`Entry.start_training_transit_steering()` 是显式开关，要求已绑定实际玩家、原地图路径和正式朝向拥有者；不会启动占位 AI。当前只接原活动假人的非终点 Transit 路点。原 `AIController.BehaviourRuntime.ApplyMovement` 先提交意图，读取上一拍转向结果；当前的 `CharacterSteeringRuntime2D.Submit` 最大速度来自实际角色解析速度（原基础预制体默认 4，受正式速度系数影响）。移动后才进行本拍原生重叠与四项 Transit 评分，产物供下一固定步消费。原方向由方向评分提供，原 `FaceTarget` 转向独立朝向最后确认的目标；无敌人时使用运动方向。既有原生身体仍处理移动门禁、输入平滑和地形查询。

`ContextSteeringSimulation2D` 把这一角色送入 RVO 与接触解算。原锁定场景中只有活动假人注册此类控制器，玩家只是语义层候选，不是 RVO 邻居。单人、零约束时，原 `linearProgram2` 保留优选速度并约束到提交最大速度；没有另一角色就不存在成对位置纠正。普通障碍照常进入原生检测与 Transit 评分，并未借零 RVO 邻居跳过碰撞查询。检测无法验证、世界退出或切到未迁移组时不借用旧速度；将方向置零后既有移动输入仍按原衰减处理。未接其他行为的输出（含 Combat Wander、Predictive Target 与默认组）、跨多个活动角色的 RVO、Unity 原生画面对照和真实输入验收均不由此阶段证明。

`test_singleton_transit_steering.gd` 验证真实物理层、近点、语义/注册分离、上一拍安全速度除以本拍最大速度及注销；`test_clickmovetest_trainer_transit.gd` 验证原 Entry 的自动选敌、第一路点生成和实际身体移动。两者的无头运行均不是视觉验收。

### 原最终路点 Predictive Target

同一单人转向入口也接锁定的 Predictive Target。游走距离内仍由游走
分支优先认领，不通过 Predictive 冒充原游走；没有活动地图时的默认组
也不替换。原最终路点传入到达半径 1；前进预测用实际玩家身体在本步
新指令之前可读的线速度，反转 Y 成 Unity 坐标，不用键盘意图或画面
节点速度。原位置用于到达减速，预测位置只用于方向评分。先消费上拍
安全结果再产生本拍结果，延续已有原生角色移动链。

`test_clickmovetest_trainer_predictive.gd` 在同一个真实 Entry 验证非零
原生玩家物理速度进入预测、实际方向与无预测不同，以及下一拍驱动
假人身体。私有版本移动玩家以隔离原地图中游走范围外的末路点；
这不是从双方原始出生坐标自然进入战斗的验收。无私有地图时使用明确
的单路点边界夹具。此处不承诺两引擎固定步物理速度逐位相同。
