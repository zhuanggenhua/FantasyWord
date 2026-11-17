# 已装备技能槽与命令分派

## 原始依据与边界

锁定 Unity `31629d53a110dd4c87d4c85e6ad5a387fbafb931`：
- `CharacterEquippedAbilityLoadout`：槽位代码、自动分配、移槽、删除与快照恢复。
- `CharacterAbilitySet.FireEquippedAbilityAtIndex / StopFireEquippedAbilityAtIndex`：每次查询当前槽的正代码，然后由运行时解析 `ActiveAbilityBase`。
- `CharacterBase.Contracts.CharacterAbilityFireResult`：未解析返回 `Unknown=4` 和代码 0；已解析但检查失败保留正代码，由外层命令产生拒绝通知。
- `Constants.MaxEquipedAbilityCount=5`；并不由此自动装备某个技能。

本次迁移占位对象和槽位查找，不实现新的 GAS 替代品。正式宿主提供 `resolve_active(code)`，必须同时完成运行时查找与原 `ActiveAbilityBase` 类型判断。不能用原生节点的启用/隐藏状态代替该类型条件，原技能在 Fire 前可能尚未激活。

`fire_resolved(ability, command_context, activation_context)` 接收原能力对象与上下文，仍由原宿主完成 `CanFire`、朝向更新、自动/手动生命周期和效果。停止宿主只执行实际 `StopFire`，槽位分派确认已解析后返回 true。未提供这些宿主不能宣称技能效果已实现。

## 真实接入

`ClickMoveTest.entry.start_human_equipped_abilities` 在现有正式角色入口上绑定唯一的槽位对象与分派实例，继续通过已有 `submit_human_command` 检查当前角色权限，并由已有激活上下文构造器计算角色方向。不会自动在测试场景添加默认装备。
入口保存分派的强引用；重新绑定能力成功或停止角色瞄准/退出时释放旧实例。松手时查询当前槽，因此按下后换槽会停止新槽能力，不缓存旧能力。

## 数据行为

自动分配首个空槽且拒绝重复代码；指定赋值只清第一个其它同码槽。恢复先清空全部，再按顺序写入合法索引的正代码，同槽最后正值覆盖；null、越界与非正值不覆盖，跨槽重复代码不自动去重。删除代码则删除全部重复。快照不共享原数组/字典，不需要数据库来延迟解析代码。

宿主须先把存档解码成原槽位形状。原字段 `slotIndex`、`formalGasAbilityCode` 必须为整数；未知形状返回 false 且不改已有状态，不能强制转成索引 0。此形状校验是原强类型 DTO 的边界适配，不是新存档格式或宽松兼容解析器。

## 验证

`test_equipped_ability_loadout.gd` 验证槽位状态、快照及实际 ClickMoveTest 命令入口，包括空槽与未解析实例不通知能力拒绝、解析后冷却拒绝保留代码、激活上下文继续生效以及换槽后 Stop 的当前槽查询。
能力对象及运行时解析为显式测试宿主，不是实际技能效果、原配置全部加载、菜单装备流程、Unity/Godot 配对截图或整项迁移验收。
