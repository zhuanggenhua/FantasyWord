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
