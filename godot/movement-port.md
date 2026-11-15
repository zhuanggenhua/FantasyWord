# 角色移动：方向意图到物理前的阶段

以原版 Unity 提交 `31629d5` 为基线。角色侧命令首先由
[CharacterMovement](../Assets/Scripts/GameCore/Runtime/Entities/Characters/CharacterMovement.cs)
区分方向、点击、停止。之后由
[Movable.MotionRuntime](../Assets/Scripts/GameCore/Runtime/Entities/Movable.MotionRuntime.cs)
处理输入模式、地形坡道、模拟量/归一化选择、闲置阈值和固定帧的加减速。
Godot 的 `motion_filter.gd` 只迁这段计算，不写入坐标、不查找地图、不更新朝向或动画；
坡道规则仍属于地图，由调用者提供已成功解析的方向或空结果。

- [基础角色预制体](../Assets/Prefabs/Entities/Characters/0_CharacterActor_Base.prefab)
  的基础速度 4、自由方向、数字按键、加减速 10、闲置阈值 0.05 是作者参数，
  不是所有角色、状态和装备下的最终速度。测试使用这些值，不将它们硬编码为运行时配置。
- 原点击请求的停止距离为 0.05，但原物理移动执行器取它与
  [基本到达容差 0.1](../Assets/Scripts/GameCore/Runtime/Miscellaneous/Constants.cs) 的最大值。
  两层参数不混写；测试记录了这个边界。
- 零方向时的自然衰减不同于用户释放动作触发的明确停止。实际接线时停止命令要立即清理滤波状态，
  不能仅把下一物理帧方向设零。
- [Unity Vector2 参考实现](https://github.com/Unity-Technologies/UnityCsReference/blob/master/Runtime/Export/Math/Vector2.cs)
  用于区分归一化的极小量与向量相等判定。Godot 回归按数值容差比较，
  未宣称不同引擎所有浮点边界逐位相同，也未宣称真实固定帧频一致。

下一步应在锁定来源的实际场景接入角色运动执行、寻路、碰撞和镜头；
当前无同场景运行对照。原 MoveOrder 的多点顺序、整方向失败后逐轴试走、
坡道查找及动作锁定仍没有完整的 Godot 物理对应端，不用临时便捷移动冒充。
