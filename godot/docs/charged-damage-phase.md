# 2004 蓄力释放伤害阶段

## 四项前提

- 对象：技能 20004 命中帧派发的效果 2004，不是新伤害设计。
- 真相：Unity 锁定 `31629d53a110dd4c87d4c85e6ad5a387fbafb931` 的 `exgas_tbgameplayeffect.json` 2004、`FormalGasAbilityDescriptionGeneratedRuntime.CreatePayload`、`FormalGameplayEffectDamageSystem.cs` 和 `EffectCommonTypes.cs`。
- 入口：Godot Gameplay 的 `charged_damage_effect.gd::execute_damage_phase`，由持有真实角色/属性/效果生命周期的调用者接入。
- 验证：显式测试属性拥有者核实扣血、回调顺序、身份、当刻位置、闪避和失败；不作为整场景验收。

## 源与目标对应

源表的物理伤害、固定 7、攻击缩放 1.5、非穿防及默认暴击/闪避映射至已有 Combat 数值核。默认解析来自 CreatePayload 未覆写的结构体字段，不是新随机策略。can_critical、can_miss 与 roll 仍由调用者提供原配置，不在适配器内部偷偷换 RNG。

源 FormalDamageExecutor 先解算来源输出，再读取来源/目标根位置作 SourcePosition 冲击，随后调用已有正式应用流程。适配器不创建第二份目标属性，不写 HP；hooks 是属性拥有者的唯一提交口，成功、失败、闪避顺序沿用现有正式核。无来源时固定 7 且作者 impactData 为零，不能误用缓存来源位置。

PushMode 为 Default、无敌时长为 0；效果桥仅传递冲击向量，不调用 Push，目标 impact hook 才能申请一次。调用者必须把纯核的 source 属性身份映射回其真实 Actor，不把 Dictionary 当新角色。

## 未覆盖

此阶段不是 EX-GAS 实体创建、WipApplyEffect 调度、CueOnApply 20001、效果消费/销毁的替代实现；也不自动授予 20004、生成属性系统或场景演员。返回值来自伤害阶段，不能冒充整个效果请求成功。截图和整项迁移验收仍独立。

## 定向证据

Godot 4.7.2 无头 `tests/test_charged_damage_effect.gd` 13/13：
真实数值公式 220→198；保留来源身份；根坐标差；冲击→挑衅→准备→提交→完成；两次按需随机；缺提交能力不造属性；死亡目标拒绝；闪避有冲击/挑衅但无扣血；空来源固定伤害与零作者原点。测试使用明确注入的状态，不声明正式 GAS 已就绪。
