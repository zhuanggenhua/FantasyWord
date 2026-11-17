# Timeline 技能出手点请求编排

## 本轮对象与来源

锁定 Unity `31629d53a110dd4c87d4c85e6ad5a387fbafb931`：

- `ActiveAbilityBase.OnInputGateUsePerformed`、`TryValidateAbilityUseAtFirePoint`、`TryCommitAbilityUse` 和序列结束/打断处理。
- `CharacterAbilitySet.FormalRules` 的出手规则、Begin/Cancel/End 请求。
- `AbilitySpec.TryActivate/TryCancel/TryEnd` 与 `STryActivateAbility`。
- `TimelineActiveAbility.ExecuteAbilityUse`：该项目侧方法为空，不能在此直接启动新效果。

目标为现有 20004 HoldRelease 与同一能力上下文 owner。没有创建并行状态机、补默认装备、复制原第三方源码或加入本地“模拟 GAS”。

## 显式宿主接口

在绑定输入门控前调用 `configure_timeline_rules(host, ability_code)`，已有门控的 USE 回调绑定 `perform_timeline_use`。该能力实例仍负责持有它原来的输入门控；规则宿主由角色/能力系统持有，本上下文仅弱引用它，不能用临时对象代替。

宿主提供：
- `validate_fire_point(code)` 与 `commit_rule_use(code)`：分别调用真实规则 owner，返回 `{available,result}`，不能用先前起手结果代替。
- `create_activation_context(pending)`：由真实能力完成原虚方法的上下文创建；null 表示失败。本轮未实现默认位置构造。
- `request_begin(code, context)`：对应尝试激活请求，不是激活完成。
- `request_cancel(code)`、`request_end(code)`：对应原请求，不等价于已经取消/结束效果。
- `get_ability_debug_name()`、`report_error(message)`：正式绑定缺失的诊断。

门控必须提供 request/release/interrupt 方法及 sequence_started/stopped/interrupted 信号。宿主生命周期必须覆盖能力生命周期；未提供规则宿主时原有纯上下文路径保持不变。门控和能力销毁时，拥有者应拆除自己持有的回调，不能把测试脚本里的清理当成正式 ECS 生命周期实现。

## 顺序与失败语义

1. 新序列开始清除“本次已提交”标志。
2. 实际 USE 先做出手点检查，再创建激活上下文。
3. Begin 仅投递激活请求，随后仍做独立 Commit 检查。已提交标志只在 Commit 成功后置位。
4. Timeline 本地 ExecuteAbilityUse 是空方法，因此这里不会直接播放时间轴、扣费或伤害。同步返回 true 仅说明这一轮请求编排与检查完成。
5. 出手点或上下文失败：Interrupt → Cancel 请求 → End 请求 → 清激活上下文 → 完成回调。即使此前没有 Begin，仍发送 Cancel/End。
6. Begin 或 Commit 失败：先直接 Cancel，再 Interrupt 再 Cancel，然后 End 和完成回调。重复 Cancel 保留原代码语义，不擅自合并。
7. 正常后摇结束：End 请求先于完成回调。

原 AbilitySpec 的 TryActivate 只保存 pending 上下文并添加待处理标记；稍后的 STryActivateAbility 还会重新判断资格。它可以失败并拒绝 pending 上下文。因此“Begin 接受 + Commit 返回 Valid”不是最终激活结果。当前项目生成绑定也不是在此自行扣本地费用。真正的 ECS 队列处理、效果和事件通知不在本切片。

## 验证与未验收

`tests/test_timeline_fire_point.gd` 使用实际 Godot HoldRelease/上下文 owner，规则宿主为明确的请求追踪测试接缝：
- 起手成功而出手点各类拒绝；未执行上下文构造、Begin、Commit 或效果。
- 缺失绑定、上下文失败、Begin 失败、Commit 失败保留原顺序及双 Cancel。
- 忙碌 B 覆盖上下文后实际 USE 消费 B；正常结束以及下一序列重新检查。
- 证据是实际调用顺序及请求内容，不是测试中的虚构费用或效果计数；未执行 STryActivateAbility，稍后的激活或拒绝结果均未验收。

没有完成实际 EX-GAS 异步系统、资源支付、冷却规则、所有主动能力子类、持久化/Reset、整套游戏或双引擎画面验收。本轮不改诊断场景的资格断言使之冒充正式 GAS。
