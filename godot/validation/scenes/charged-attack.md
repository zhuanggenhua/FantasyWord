# 蓄力释放：已经获准释放后的真实物理诊断

这不是完整游戏或充能输入实现。入口 begin_accepted_release / 命令参数 --diagnose-attack
仅注入已经获准的释放事件，不是作者按键绑定，更不表示按下 Fire 就播放释放。
原实际回归是 Fire 进入 Charging、持续按住不命中、StopFire 才触发释放；这层状态机不在本切片。

## 原始依据

锁定 Unity 源提交 31629d53a110dd4c87d4c85e6ad5a387fbafb931。
- 生成 Ability 20004 → Timeline 20004：life36，命中帧12，TaskApplyEffects 2004。
- CatchAreaBox2D：局部 offset(.75,.15)、size(1.15,.95)、rotation0、layer128；
  Gas2DTargetCatchers.cs 的 TryResolveRelativePose 读取当前 runtime facing，
  同时旋转偏移和查询框。命中目标按身份去重并排除自己。
- Effect2004：物理 flat7、scale1.5、不忽略防御、SourcePosition 冲击、Default 推力。
  不是基本攻击的 Polygon，不附加基本攻击背刺。
- MeleeAttackAbilityEditModeTests 的 charged 回归目标 (.75,.2)、50 HP、防御2，
  攻击10，所以非暴击非闪避输出22、防御结算21、剩29。最大HP不改。
- FormalGameplayEffectDamageSystem 冲击在挑衅和正伤害扣血之前。
  Movable.TryPush / GameConfig 允许普通、暴击、闪避推力，不允许 silent；
  Default 使用 Push(direction) 的5/10默认参数，不拿效果中0/0替换默认值。

## 原生链路与验证

查询真实 Area2D 子 Hitbox；冲击通过 damage_push_policy 申请 NativeMotionBody 推力，
由已有 fixed-step 原生运动链路提交并在物理步回写身体位置。
子 Hitbox 直接附属于移动 body，防止身体与命中框脱离。
诊断 owner 字典和回调明确替代完整属性拥有者，不宣称正式 ECS/GAS 全部迁移。

run.sh 包含17项集成断言：命中前不扣血、一次命中/去重、扣21、
最大HP保持、调用顺序、真实位移和命中框跟随、自我/范围外排除、
当前朝向、取消、36帧结束。闪避仍用 DEFAULT，输入结算固定roll99，
输出暴击判定固定roll50，验证不扣血但依旧推力。

直接场景：
Godot --headless --path godot res://validation/scenes/charged_attack_fixture.tscn -- --diagnose-attack --verify-attack

未验收：实际输入充能、技能授予/标签/费用、完整GAS属性、动画Cue、
原美术、Unity原生截图一致性、非矩形命中体、64候选溢出与跨引擎接触边界精度。

## 共用的命中帧入口与角色接线边界

`gameplay/combat/charged_attack_hit.gd` 把本诊断原来的查询/逐目标派发提取为
`run(world, caster, source_position, facing, resolve_target, apply_effect)`。
它是 20004 的内部协作者，不建立另一个时间轴、属性池、角色或效果系统。

- 原 `TaskApplyEffects.OnBegin` 负责每次重新交给 catcher 当前 owner/context，
  再对每个唯一目标应用 2004；本入口保留该查询/派发顺序。
- 原 `Gas2DTargetCatchers.cs/CatchAreaBox2D` 的相对模式使用**命中帧**施法者的位置和
  当前朝向，不使用激活时缓存的目标点。调用方必须在帧 12 当场取值，坐标为 Unity Y 向上。
- 实际 ClickMoveTest 接线处应传入该角色当前 World2D、实际 caster 身份、位置和朝向；
  `resolve_target(collider)` 由碰撞体解析真实业务 owner，`apply_effect(caster,target,2004)`
  交给既有角色效果入口。缺少效果入口会返回 `ok=false` 和中文 `error`，调用方须报错并停止此项。
- 诊断的 `_apply_effect` 继续调用已有 `Combat.solve_damage_output`、
  `formal_damage_application` 和目标 `hooks()` 的 `damage_push_policy`。
  合成属性、固定随机样本、生命写入、默认推力和伤害生命周期仍只属于诊断角色。
  不因为抽出了共用查询就宣称实际 ClickMoveTest 已拥有正式 GAS 属性或目标身份。
- 返回的 `targets` 是本次真实查询结果，`application_count` 是派发次数；
  `ok=true` 不是未闪避、效果成功或整个迁移完成的判据。

本切片现有原生测试扩为 22 项，增加实际 caster/target/2004 派发身份、无属性代持、
动态位置、缺失效果入口拒绝和共用查询结果的断言。原 64 项上限、无缩放矩形子框、
跨引擎边界与原生 Unity 截图等未验收项保持不变。完整效果实体创建、CueOnApply20001
及正式属性系统不在这个提取步骤中实现，不能用诊断回调替代这些未完成项。
