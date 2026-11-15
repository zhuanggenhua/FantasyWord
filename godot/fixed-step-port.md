# 固定物理步长移植

基线 Unity `31629d5` 的 [TimeManager](../ProjectSettings/TimeManager.asset)
保存 Fixed Timestep 为计数 2822399，速率 141120000/1 个刻度每秒。
按 [Unity RationalTime](https://docs.unity3d.com/6000.0/Documentation/ScriptReference/Unity.IntegerTime.RationalTime.html)
转为秒，结果约为 0.0199999929138322；转换到原玩法 `Time.fixedDeltaTime`
的 float 精度是 `0.019999992102384567`。
[Movable.MotionRuntime](../Assets/Scripts/GameCore/Runtime/Entities/Movable.MotionRuntime.cs)
将这个步长用于加减速、碰撞位移预算和 MovePosition。

[Godot 的物理步频](https://docs.godotengine.org/en/stable/classes/class_projectsettings.html#class-projectsettings-property-physics-common-physics-ticks-per-second)
只能用整数。将原生场景与 PhysicsServer 从默认 60 Hz 改到最接近的 50 Hz，
原生回调约 0.02 秒；诊断对象的移动数学明确传入原序列化的 float 步长，
而非拿 0.02 秒当成完全相同的数。其他场景仍须显式接入。
时标 1 下已验证实际 Godot 固定回调和场景运行；不声明 Unity 追帧上限、
暂停/时间缩放、Physics2D 接触求解或原生回调顺序等价。
