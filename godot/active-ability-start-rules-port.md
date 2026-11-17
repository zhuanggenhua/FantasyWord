# 主动技能起手规则切片

## 锁定与对应

- 对象：现有 ClickMoveTest 原生角色命令、当前槽位解析、已解析 Fire 流程的起手检查。
- 真相：Unity 31629d53a110dd4c87d4c85e6ad5a387fbafb931；不修改 Unity 主分支。
- ActiveAbilityBase.CanFire：同一能力的输入门控忙碌则返回 Valid，未忙碌才评估启动规则。
- CanStartFormalAbilityInputGateSequence：始终重新评估，不复用先前预检，不走忙碌短路。
- AbilityBase.usesFormalGasAbility：能力实例自己的代码大于零，不是从槽位代码推断。
- EvaluateAbilityStartRules：实际规则调用返回可用时透传全部五种结果；绑定不可用或代码未绑定时返回 Unknown，并分别保留源诊断。
- CharacterAbilitySet.TryEvaluateFormalGasAbilityRuleActivation：角色组合所有权、正式绑定和规则计算仍由外部原规则 owner 提供。本切片没有创造资源、标签、冷却或扣费规则。

## 唯一状态所有者

FormalAbilityInputGateRuntime.isBusy 排除 Idle、Stop、Interrupted，其余源状态包括所有换弹阶段都是忙碌。现有 BasicSemiAutoGate 和 HoldReleaseGate 是已迁移的无弹匣特定配置切片，直接在各自已有状态 owner 添加 is_busy()；两个本地 enum 数字不同，不能跨类型硬套原数字。Start、Use、后摇都忙碌，HoldRelease 的 Charging 也忙碌；不是用 is_charging() 冒充通用忙碌。

本次没有实现通用换弹 gate、没有另建复制 gate 状态的对象。将来通用 gate 必须保持原所有换弹阶段的忙碌语义，不能拿两个无弹匣切片充当完成。

## 入口与生命周期

start_human_resolved_equipped_abilities(..., use_source_start_rules=true) 通过原调度器调用本次迁移的规则。默认 false 保留原显式宿主 CanFire 路径兼容性。

源规则模式宿主提供：
- get_input_gate(ability)：同一已解析能力的实际 gate，可为 null。
- get_formal_gas_ability_code(ability)：实例代码，不以槽位替代。
- evaluate_start_rule(code, ability)：返回 {available: bool, result: int}；available=false 是无可用绑定，不是普通拒绝。
- get_ability_debug_name(ability)、report_start_rule_error(message, ability)：失败时诊断。
- 原有 Fire、Stop、方向标志和生命周期方法不变。

忙碌分支不读取代码、规则或诊断名称；名称仅诊断时延迟查询。不缓存规则或状态。门控的新序列回调必须显式使用 StartRules.can_start，即使外层 Fire 预检通过，也应在 RequestUse 时再次检查。

门控、能力、角色、宿主仍由原创建者持有；释放前按既有入口解绑。不按名称搜索，不自动创建设定或能力。调度器不管理 gate 的 Tick，不伪造完整技能宿主。

## 验收及边界

test_active_ability_start_rules.gd 使用真实原生场景角色和当前槽位已解析命令链，33 项验证五种结果、失败无后续方向/Fire 副作用、槽位与实例代码差异、真实两类 gate 的开始/后摇/打断/停止/空闲、忙碌不重查而新序列独立重评估、两种配置缺失诊断。正式规则结果、Fire 落点是明确的测试宿主，不是可玩伤害和扣费证据。

本次只完成启动资格决策与原生命令接线。完整 EX-GAS 规则计算、正式技能效果、场景作者源装配、Unity 对照视觉及整体游戏验收仍未完成。
