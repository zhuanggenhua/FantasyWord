# 角色移动：方向意图与位移请求

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

## 航点执行边界

`motion_execution.gd` 在角色侧命令之后处理位移。按原 `ExecuteMoveOrder` 在移动前后读取实际位置，
每次只完成一个航点。新有效路线取消旧任务，明确停止或被方向指令打断则是失败而非取消；
空路线自身失败，不替换在途路线。即使宿主的写入只在下一帧生效，也不会提前宣布到达。

整向探测受阻时按 X、Y 顺序试走，保留轴向分量和完整速度，前探使用原 0.02 余量。
地图、碰撞查询和位置写入由宿主提供；测试通过替身验证这一顺序和防止提前到达的边界。
不会把即时替身当作 Unity 的 `Rigidbody2D.MovePosition`，也不指定未知的游戏角色速度。
推力、传送、墙内恢复、真实位置提交时序和正式角色宿主仍未移植；后者接线参考[场景验收](runtime-acceptance.md)。

## Godot 物理地形查询

`terrain_cast.gd` 的输入仍是 Unity 世界单位、Y 向上，测试物理世界取相同单位并反转 Y。
真实画面的像素倍率留到场景层。宿主明确指定凸形状、原偏移、地形层和排除的自身刚体，
适配只查询单个未旋转的凸形状并返回碰撞身体，不修改角色位置；旋转、多附着形状和只有 RID 的身体不在验证范围。
前探方向先归一化、距离保持调用器计算的完整值；
Unity 对非单位方向的原生长度行为仍需同引擎实测。这里的位移向量仍由执行器保留轴分量。

固定的 [GodotPhysics2D 4.7.2 后端](https://github.com/godotengine/godot/blob/4.7.2-stable/modules/godot_physics_2d/godot_space_2d.cpp#L208-L255)
对 `intersect_shape` 使用完整扫掠位移，能同时返回起点重叠与途中命中的身份；
这是固定版本实测，不假设其他后端同样支持。按 RID 去重、分批排除已查到的身体，
可跨过单批 32 返回限制，但不能承诺超出后端 2048 个宽相候选时仍能收集所有对象。
不复用这个查询作为需要 Unity 命中顺序、法线或距离的碰撞接口。
测试以基础角色的竖向胶囊和自建碰撞体跑过多命中、触发器与 Character 排除、自身排除、
起点重叠和整向受阻后的逐轴位移请求。没有把测试宿主的位置请求当作真实角色已经走动。
