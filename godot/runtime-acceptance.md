# 场景运行验收（待接线）

锁定原版提交 `31629d53a110dd4c87d4c85e6ad5a387fbafb931`。
以下取自原仓库的 PlayMode 验证器，不是本分支已经通过的场景测试。

| 入口 | 原版验收判据 | Godot 当前边界 |
| --- | --- | --- |
| [点击移动](../Assets/Editor/GameCore/Automation/ClickMoveTestRuntimeValidator.cs) | 点击位于画面宽 75%、高 50%；不是 UI 命中；直接发角色命令后立刻产生 MoveOrder。观察 120 帧，角色与相机各移动至少 0.1 世界单位，两者位移方向的点积至少 0.9。 | 还未通过真实相机投影、地图和角色位移。原验证器也直接发命令，真实设备点击另测。 |
| [航点转角](../Assets/Editor/GameCore/Automation/ClickMoveTestContextSteeringWaypointValidator.cs) | 转角半径 0.65 内保持 transit，最低速度 0.05；静态路径和实际轨迹均不能切过不可行走格，静态采样不穿正式碰撞体；终点需切到 predictive-target，并观察 preferred/safe velocity。 | 命令完成与逐轴试走并不证明 NPC 航点转角、寻路或避障等价。 |
| [GAS 普攻](../Assets/Editor/GameCore/Automation/ClickMoveTestGasBasicAttackValidator.cs) | 装备真实 Ability、实际扣血并可击杀；观察攻击、受伤和浮动伤害文字。 | 当前只有可运行的战斗计算测试。旧脚本还要求地形过滤包含 Character，与锁定的 GameConfig 及 ContextSteering 测试冲突，不把该断言移为地形要求。 |

## 地形查询的引擎边界

- 原 [GameConfig](../Assets/GameData/GameCore/GameConfig.asset) 的地形过滤掩码为 7752
  （Unity 零起算索引 3、6、9、10、11、12），排除触发器；角色邻居掩码为 256（索引 8）。
  [原 ContextSteering 回归](../Assets/Editor/GameCore/Tests/ContextSteering2DEditModeTests.cs)
  指定角色接触由 RVO2 与 PBD 单独处理，地形查询不得再次处理 Character。
- 原 `Movable.MotionRuntime.IsInWall` 按附着碰撞形状查询，前探距离为
  `速度 × 固定步长 + 0.02`。被拒绝的整向查询仍保留碰撞对象，即便后续轴向滑动成功。
- `test_terrain_query_contract.gd` 在 Godot 4.7.2 的真实 PhysicsServer 上用测试形状跑四种情况：
  地形实体命中、Character 过滤、同层 Area 过滤、起点重叠。起点重叠时
  `cast_motion` 返回 [1, 1]，`intersect_shape` 才找到重叠。后续适配不能仅凭扫掠比例
  判定原版 [Rigidbody2D.Cast](https://docs.unity3d.com/cn/current/ScriptReference/Rigidbody2D.Cast.html)
  的结果；其 API 还要求排除同一 Rigidbody 上的形状，并提供命中对象。
  不能用这四例代替实际场景回归。

接正式角色时，以[基础角色 prefab](../Assets/Prefabs/Entities/Characters/0_Character_Base.prefab)
的根节点为起点：Character 层、非触发竖向胶囊，尺寸 (0.78, 0.86)，从原点向 Unity Y 正向
偏移 0.42；独立的 Hitbox 子节点另有触发盒和刚体，不要把它算作根身体形状。
接实际角色仍需先核查派生 prefab 是否覆写这些参数。

正式镜头不能只挂一个无条件跟随节点：
[PlayerCameraRig](../Assets/Scripts/GameCore/Runtime/Presentation/PlayerCameraRig.cs) 区分当前控制目标、
地图目标覆写与地图边界；这些尚未接入，独立于点击命令验收中的相机位移和方向阈值。

## 原场景玩家绑定，不自动补绑

锁定版本的两份场景都实例化了
[玩家角色](../Assets/Prefabs/Entities/Characters/Heroes/玩家角色.prefab)，继承
[CharacterActor 基础预制体](../Assets/Prefabs/Entities/Characters/0_CharacterActor_Base.prefab)
和上面的根碰撞体；这一继承链没有覆写根胶囊尺寸或偏移。场景的正式玩家绑定不能仅凭名称推断。
[ClickMoveTest](../Assets/Scenes/ClickMoveTest.unity) 的 `m_primaryPlayerCharacter` 指向场景内的
实例组件；[SampleScene](../Assets/Scenes/SampleScene.unity) 的相同字段在文件中则指向外部玩家 prefab。
[PlayerSystem](../Assets/Scripts/GameCore/Runtime/Game/Systems/PlayerSystem.cs) 启动时明确检查
玩家属于已加载场景；SampleScene 虽也摆了玩家实例，仍须运行验证其引用能否满足这项检查。
这里不自动搜索、不新建替代玩家，也未宣称 Unity 已出现运行错误。

ClickMoveTest 的 `MapInfo` 实际绑定了
[TerrainNavigationMap](../Assets/Scripts/GameCore/Runtime/Maps/TerrainNavigationMap.cs)。
该场景的导航矩形格大小为 (1, 1)，规则 Tilemap 之外还有独立表层配置；
因此无地图的直线后备路径不等于 ClickMoveTest 的正式点击移动，不能用身体移动联测替代该场景验收。
