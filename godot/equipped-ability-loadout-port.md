# 已装备技能槽与命令分派

## 原始依据与边界

锁定 Unity `31629d53a110dd4c87d4c85e6ad5a387fbafb931`：
- `CharacterEquippedAbilityLoadout`：槽位代码、自动分配、移槽、删除与快照恢复。
- `CharacterAbilitySet.FireEquippedAbilityAtIndex / StopFireEquippedAbilityAtIndex`：每次查询当前槽的正代码，然后由运行时解析 `ActiveAbilityBase`。
- `CharacterBase.Contracts.CharacterAbilityFireResult`：未解析返回 `Unknown=4` 和代码 0；已解析但检查失败保留正代码，由外层命令产生拒绝通知。
- `Constants.MaxEquipedAbilityCount=5`；并不由此自动装备某个技能。

本次迁移占位对象和槽位查找，不实现新的 GAS 替代品。正式宿主提供 `resolve_active(code)`，必须同时完成运行时查找与原 `ActiveAbilityBase` 类型判断。不能用原生节点的启用/隐藏状态代替该类型条件，原技能在 Fire 前可能尚未激活。

`fire_resolved(ability, command_context, activation_context)` 接收原能力对象与上下文，可继续由原宿主完成调度，或通过下面的 resolved 入口使用已迁移的顺序。实际效果仍须正式能力宿主实现。停止宿主只执行实际 `StopFire`，槽位分派确认已解析后返回 true。未提供这些宿主不能宣称技能效果已实现。

## 真实接入

`ClickMoveTest.entry.start_human_equipped_abilities` 在现有正式角色入口上绑定唯一的槽位对象与分派实例，继续通过已有 `submit_human_command` 检查当前角色权限，并由已有激活上下文构造器计算角色方向。不会自动在测试场景添加默认装备。
入口保存分派的强引用；重新绑定能力成功或停止角色瞄准/退出时释放旧实例。松手时查询当前槽，因此按下后换槽会停止新槽能力，不缓存旧能力。

## 数据行为

自动分配首个空槽且拒绝重复代码；指定赋值只清第一个其它同码槽。恢复先清空全部，再按顺序写入合法索引的正代码，同槽最后正值覆盖；null、越界与非正值不覆盖，跨槽重复代码不自动去重。删除代码则删除全部重复。快照不共享原数组/字典，不需要数据库来延迟解析代码。

宿主须先把存档解码成原槽位形状。原字段 `slotIndex`、`formalGasAbilityCode` 必须为整数；未知形状返回 false 且不改已有状态，不能强制转成索引 0。此形状校验是原强类型 DTO 的边界适配，不是新存档格式或宽松兼容解析器。

## 验证

`test_equipped_ability_loadout.gd` 验证槽位状态、快照及实际 ClickMoveTest 命令入口，包括空槽与未解析实例不通知能力拒绝、解析后冷却拒绝保留代码、激活上下文继续生效以及换槽后 Stop 的当前槽查询。
能力对象及运行时解析为显式测试宿主，不是实际技能效果、原配置全部加载、菜单装备流程、Unity/Godot 配对截图或整项迁移验收。

## 已解析能力的原 Fire 顺序

新增可选入口 `start_human_resolved_equipped_abilities`，直接复用同一槽位分派、命令执行器与角色 owner，没有第二份方向或能力状态。四项前提：问题对象为 `CharacterAbilitySet.FireResolvedAbility`；真相为锁定源码 663–720 行及 `Movable` 519–569 行、`CharacterBase.CanUpdateTargetDirection`；目标为云端原生 ClickMoveTest；验收为真实角色命令入口和显式能力宿主调用顺序，不把测试替身当实际技能。

源码与原生流程对应：
1. 调用实际 `can_fire(ability)`，非 Valid 原样返回，之后所有更新都不执行。
2. 激活上下文的 Unity XY 平方长度大于原 float32 0.0001 阈值才独立归一，并调用角色 `set_target_direction`。目标 gate（销毁、行动权限、技能输入锁）和 TargetBased 副作用仍由现有 owner 负责，不重实现、不跳过。
3. 若实际 `should_update_look_at_direction_on_fire(ability)` 为真，先读 owner 当前目标，再以本次有效请求覆盖局部方向，非零才写 look。即使 target 写入被 gate 拦住，本次请求仍能独立更新 look；即使该 flag 为假，TargetBased 的 setter 副作用仍保留。
4. 自动模式先调用 `set_ability_active(ability,true)`，再 `fire(ability,command_context,activation_context,completion)`；结束关闭同一实例，不按当前槽重新查找。手动模式不调用 active 操作，传显式 null 回调。
5. Stop 仍重新读当前槽并调用实际 `stop_fire`。

宿主边界共六个方法：`can_fire`、`should_update_look_at_direction_on_fire`、`uses_automatic_runtime_state_management`、`set_ability_active`、`fire`、`stop_fire`，每个首参均为实际已解析能力对象。宿主提供真实能力状态与效果；此处不把 visible、process_mode 或伪造布尔值当 Unity GameObject 生命周期，不生成 GAS、不默认绑定占位能力。实际 CanFire 内部计算、能力 flags 来源、技能效果与原资产加载仍未迁移验收。

角色与能力宿主须在绑定期间保持有效；Node 宿主销毁前必须停止/解绑角色技能入口，不能在有效角色命令入口下释放依赖。独立的自动结束回调仅弱引用原能力与宿主，避免原生 RefCounted 能力保存结束回调时形成循环；已释放对象不再执行关闭，不解析替代实例。这是原生对象寿命适配，不是伪成功 Fire 或 Stop。

`test_resolved_ability_fire.gd` 的 21 项检查通过真实入口覆盖检查拒绝、原上下文、自动顺序、换槽后的旧实例回调、阻止瞄准但独立朝向、TargetBased、手动 null、纯 Z/XY 阈值、已释放能力回调、当前角色权限及 Stop。公开素材夹具与私有原 nav/atlas 均只作逻辑验证，不是 Unity/GameView 视觉验收。
