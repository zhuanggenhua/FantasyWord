# 20004 单技能延迟激活切片

## 已锁定来源

Unity `31629d53a110dd4c87d4c85e6ad5a387fbafb931`：

- 生成表 `exgas_tbability.json` 的 20004：Cost/Cd/CdEffect 均为零，ALTimeline 20004，Owned 与 Blocked.None 为 3003。
- `XLuban.gen.cs.ParseTagRequirement` 会删除 All/Any 中的零，所以生成后的两组为空；不是要求持有不存在的标签0。
- `exgas_tbgameplaytags.json` 的 3003 是 Event.Attacking。本切片只接入该确切标签，不声称支持完整父子标签树。
- `AbilityUtil.CanActivateAbility` 先检查已有 active，再检查标签，然后消耗/冷却；上述作者数据没有消耗/冷却组件。
- `AbilitySpec.TryActivate` 只保存 pending 与请求标记。之后 `STryActivateAbility` 再检查；成功调用 ALTimeline.Play，失败只 RejectPendingActivationContext。
- `STryCancelAbility` 排在激活后，`STryEndAbility` 排在取消后。无 active 时只消耗请求，不调用逻辑/通知。
- `AbilityLogicBase` 拒绝 pending 时保留之前的 ActivationContext；取消/结束才清两者。
- `ALTimelinePlayer` 完成且 ManualEndAbility=false 时投递 TryEndSelf。20004 的配置是36帧、ManualEndAbility=false，命中帧12。

## 实现边界

`gameplay/combat/charged_timeline_spec.gd` 是该已核实单技能的运行时持有者，不是泛用 GAS 世界。它保存同一 spec 的请求标记、pending/active 上下文、active 状态，以及角色这一个3003标签的固定与来源临时记录。技能来源清除不影响其他来源或固定标签。

`process_update` 表示独立的后续能力系统更新边界，不意味着固定等一个墙钟帧或物理帧。顺序为 Activate → Cancel → End。事件发生在逻辑处理之后、相应 active/请求结构标记提交之前，符合当前单 spec 的原顺序。回调仅允许观察，不支持重入或通知中追加请求。

同一个对象实现之前出手点编排的规则宿主接口。起手、dry-check、Begin请求和独立Commit均读取这个实际状态；没有测试布尔值代替标签判断，也没有虚构mana扣费。Begin与同步Commit成功不会立即播放。后续更新若新增3003，真实拒绝pending；若成功，才启动已经存在的Timeline命中时钟。

`validation/scenes/delayed_charge_fixture.tscn` 是可直接运行的独立诊断入口，沿用原槽位/Q/2输入、实际角色、原生碰撞和现有Timeline，不自动修改正式存档装备。父槽位场景只抽出构造方法；原有多技能组合诊断保持原默认行为，不能把它冒充本单技能链路。继承的 `--diagnose-attack` 也改走Fire/Release/请求，不能绕过到直接播放。

## 验证内容

`tests/test_delayed_charge_activation.gd` 在真实原生场景内：
- 实际 Q/2 松开只入队；改变固定3003后，下一更新拒绝，无播放/命中/扣血。
- 清标签后下一次成功，在结果通知时观察原提交顺序；第12帧真实命中、HP 50→29。
- 活跃中再次申请失败只清新pending，保留旧活动上下文。
- Interrupt只入队，之后Cancel真实停止；其后的End不重复通知。
- 同时有Activate/Cancel/End标记时保持先激活再取消；他源3003不被删除。
- 忙碌Fire B替换上下文，后续真正激活提交B。
- 拒绝其他技能代码；空闲Cancel/End无逻辑回调。

## 未覆盖

未迁移完整ECS、多技能相互阻止/取消、通用标签继承、真实GASEventCenter、实体失效全部生命周期、事件重入、Cue/动画与每类Timeline任务。当前场景伤害沿用原有明确标注的诊断属性与固定随机样本，不等于正式属性系统完成。源Timeline中的TaskDoCost在当前作者配置没有cost组件，不构造虚假消耗。

不声称已经完成 Unity/Godot 同屏验收或整项交付；这是已接入运行路径的单技能逻辑切片。
