# 20004 经真实命令入口连接延迟激活

## 锁定前提

- 对象：现有 ClickMoveTest 可选 resolved 装配链与单个 20004，不改默认槽位。
- 真相：Unity `31629d53a110dd4c87d4c85e6ad5a387fbafb931` 的 `ActiveAbilityBase`、`TimelineActiveAbility`、`AbilityBase`、`CharacterAbilitySet.FormalRules` 及 20004 作者数据。
- 入口：`entry.start_human_resolved_equipped_abilities`，云端 Godot 4.7.2。
- 验收：真实命令投递，经同一门控与上下文请求后续激活；标签变化可以在后续更新真实拒绝，不把请求成功当作效果成功。

## 接入与所有权

`gameplay/combat/resolved_charged_ability.gd` 是单个技能对象兼已有 resolved 合同宿主，不是第二套调度系统。调用方显式创建、配置实际原生角色与原有角色逻辑 owner、外部 Timeline，并把 `resolve` 和对象本身交给现有入口。没有作者 20004 默认槽位，必须由调用方明确赋槽。

对象只拥有一个 `ActiveAbilityFireContext`、一个 HoldRelease 门控、一个已有单技能 spec。原 `AbilityBase.UsesAutomaticRuntimeStateManagement` 对正式绑定返回真，因此 resolved 调度在 Fire 前写入 `local_active`，同实例完成回调清除它。它与延迟的 `spec.active` 是两种原有状态，不混为一谈。

`process_requests` 是显式的后续 GAS 请求处理边界；`advance_input` 只更新门控。传入的 Timeline 继续唯一拥有任务执行和 Tick；自然结束时其宿主调用 `request_natural_end`。本对象不隐式添加 `_process`，不假装播放 Cue、伤害或完成多技能 GAS。

spec 的可选位置读取回调直接读取同一实际角色 `get_movement_position`；保留旧诊断 `source_position` 入口，不创建替身角色。已传入的 ActivationContext 仍原样使用。

## 验证及边界

`test_resolved_charged_ability.gd` 在真实 Entry、角色、命令执行器、resolved 调度上验证未赋槽不启动、固定 3003 拒绝、忙碌 Fire 更新上下文、Stop 请求、后续标签拒绝、同实例本地结束、重启后正式激活与原 12 帧任务回调、换槽不改变原实例清理。测试分别用最小夹具与私有原始导航/动画资源运行。

12 帧测试回调只是验证外部时钟抵达任务边界，不声明伤害、Cue 或完整原版战斗已验收。同时验证正式归一化 FireAbility2 performed/canceled 动作经原槽位查询到本对象；不声明设备键盘到战斗的可试玩验收。保持默认原入口行为不变。

## 下一批可试玩目标

优先把同一实际原生角色位置、朝向及角色身体接到已有原版 20004 捕捉器和伤害处理，再验证真实键盘按下/释放、12 帧实体命中、目标受伤和本次结束。Cue `ChargedAttack` 应按作者帧 2 至 30 与已有原始动画语义接入，不能用新动画替代。统一完成后进行一次整批回归，不为该宿主单独发布小提交。

## 同批追加：唯一时钟权限

`take_clock_tick_ownership` 只允许接管配置时的同一个已有 `AttackHitFrame` 时钟，拒绝其他实例和重复接管。接管后调用 `advance_owned_clock`，自然终止只投递 End，请求仍由后续 `process_requests` 处理。门控始终由独立的 `advance_input` 更新，不以时钟 playing 或 GAS active 作门禁，因此蓄力和激活被拒后的后摇不会被冻结。调用方负责按原源时序传入相应 delta，不添加自造暂停规则或第二套自动 Tick。

新增正式归一化动作、唯一时钟接管、自然结束与本地门控结束独立性的验收，合计 25 项，含私有原始资源复验。没有把测试计数器称为目标受伤。
