# 战斗纯规则迁移边界

## 锁定对象与依据

原版提交：`31629d53a110dd4c87d4c85e6ad5a387fbafb931`。

- `Assets/Scripts/GameCore/Runtime/Combat/CombatSolver.cs`：同阵营、敌我、中立、自作用、死亡和无敌判断。
- `Assets/Scripts/GameCore/Runtime/Combat/DamageSolver.cs`：攻击缩放、防御、暴击、闪避及两个伤害描述阶段。
- `Assets/Scripts/GameCore/Runtime/Combat/CombatStatSnapshot.cs`：物理/魔法攻防、敏捷、幸运六项快照。
- `Assets/Scripts/GameCore/Runtime/Combat/DamageDescriptor.cs`：伤害标记、随机策略及未知来源分支。
- `Assets/Scripts/GameCore/Runtime/Entities/Characters/CharacterBase.Contracts.cs`：Good / Evil / Neutral 的枚举值。
- `Assets/Scripts/GameCore/Runtime/Combat/FormalGameplayEffectDamageSystem.cs`：正式 `FormalDamageExecutor` 在目标检查和伤害结算处直接消费这两个 Solver；随后通过正式 GAS 资源 Modifier 提交生命变化。本次没有替换这条提交链。

迁移实现只有 `game_core/combat/combat_rules.gd`。测试与实现分开，测试本身不成为运行时属性源。字典只作为纯切片的显式输入/输出，不是新角色模型或新属性数据库。

## 保留的非直觉语义

- 无攻击者时原版只传平伤、伤害类型、silent；不继承 ignoreDefense、missBehavior，也不进行缩放、暴击或目标防御减伤。
- `CanTarget(DamageOutputDescriptor, ...)` 的来源角色解析失败分支直接返回 true。它不等于另一重载的“目标必须活着”；按源码迁移，没有用注释推翻代码。
- 无敌角色可以作用于自己，不能凭两个对象字段相等判定是同一角色。
- Neutral 与其他阵营是不同阵营，但不算主动敌对。
- 全局开关优先于 Always；Never 和 Always 分支不消耗随机数。
- 暴击使用严格小于，闪避使用严格大于；整数随机取值是 1 到 99，而非 0 到 99 或 1 到 100。
- 暴击与闪避标记可以同时保留，闪避仅把最终伤害变为零。
- 来源属性缓存为深复制快照，不随后续攻击者属性改动变化。
- 单精度中间量通过 PackedFloat32Array 收窄；中点舍入单独保持取偶数，不使用 GDScript 的普通 round 代替。

## 验证与未覆盖项

`tests/test_combat_rules.gd` 在官方 Godot 4.7.2 无窗口运行。当前 248 项断言覆盖枚举组合、随机门限、强制/禁止解析、抽样次数、未知来源、自作用身份和快照隔离。

这些是源码驱动的纯规则用例，不是运行 Unity 后采样的差分结果，也不是可玩战斗验收。当前没有调用 Godot 默认随机数生成器冒充 Unity 随机序列；调用方必须显式提供同范围抽样入口。

未宣称支持：32 位整数溢出、非有限数值、使除数为零的防御/敏捷值、Unity 销毁对象与 PersistableReference 解析生命周期、运行中属性事件重入、EX-GAS 表/生成代码、技能时间轴与 Cue、碰撞选敌、正式扣血、输入、动画、音效、死亡与存档。字段缺失属于调用合同错误，不自动填默认角色或属性。后续应在正式角色和 GAS owner 移植后接入本切片，不把这些字典变成第二套属性真相。
