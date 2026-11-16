# 战斗转向：原生物理检测输入

源码锁定为 Unity `31629d53a110dd4c87d4c85e6ad5a387fbafb931`。对应 `Assets/ProjectPlugins/ContextSteering2D/Runtime/SteeringDetectionScheduler2D.cs` 的 `BuildFrame`、`CollectRegisteredNeighbours` 和 `AgentSpatialIndex2D.Collect`。

- 原生物理重叠按障碍探测和语义查询较大半径，使用原控制器的 `7752 | 256` 掩码，不含触发器。缓冲区至少 8 个；在自身过滤前达到容量即拒绝本帧，不按截断结果继续。
- 已注册对象仍可进入语义候选，但包括未激活注册对象在内，都不作为普通障碍。合适的未注册障碍使用碰撞体的最近点、零半径及静态标记；源联合查询没有额外的距离过滤。
- 邻居来自注册表而非重叠检测，保留邻居半径内活动、非自身的角色层对象。网格按 Y、X 遍历，格内按注册顺序。调用者应提供原网格尺寸和同一仿真步的登记信息。登记键为 `body`、`colliders`、`agent_id`、`active`、`radius`、`velocity`、`mass`、`priority`。
- 障碍输出为 `{point, radius, is_static}`；邻居为 `{agent_id, position, radius, velocity, mass, priority}`。仅在进出物理接口时翻转 Y。普通 `StaticBody2D` 映射源静态，`AnimatableBody2D` 不算静态。

障碍仅支持单个启用的矩形或均匀缩放圆。矩形支持旋转和正交的非均匀缩放；在内部则返回查询点本身。遇到倾斜或退化变换、多形状、非均匀圆、胶囊、多边形或复合碰撞，明确返回失败，不猜最近点、不默默漏障碍。本阶段以一个 Godot 对象对应一个 Unity 碰撞体，多碰撞体身份、原生重叠返回顺序和精确浮点边界未验收。

`test_steering_detection.gd` 使用 Godot 原生物理验证最近点、零半径、过滤、活动邻居及顺序、原生矩形与圆边界、拒绝不支持几何及满缓冲。还未接正式场景的注册生命周期、时间步、RVO 或角色玩法；不能以此替代既有的选敌感知或宣告完整迁移。
