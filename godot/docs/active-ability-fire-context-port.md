# 主动能力 Fire 上下文替换切片

## 对象与依据

锁定 Unity 提交 `31629d53a110dd4c87d4c85e6ad5a387fbafb931`：

- `ActiveAbilityBase.Fire` 先保存完成回调、命令、激活上下文，再调用既有门控 `RequestUse`。
- `GameCommandContext.Recreate` 重建缺失角色的命令，保留来源类型对应规则。
- `TerminateCasting` 总是先清激活上下文；正在施法才置为结束、调用当前回调，然后清回调；命令保持不变。
- `FormalAbilityInputGateRuntime` 的 HoldRelease 忙碌时拒绝新序列，但原 Fire 没有因此撤销上述替换。

目标是同一 Godot 能力实例及它已有的 20004 输入门控，不是另建状态机或重写技能效果。

## 实现与入口

`game_core/combat/active_ability_fire_context.gd` 承载原基类的实例上下文和 casting 标志。实际技能宿主持有它，绑定自己已有的门控，在 `host.fire` 中调用 `fire`，在实际 USE 回调读取当前命令、激活上下文。现有 resolved 调度与角色命令入口不变。

宿主必须先连接原序列开始/结束的业务回调，再配置上下文对象，确保正式结束业务先于 `TerminateCasting`。配置不允许重复绑定。`fire` 的 bool 只用于诊断门控是否接受，不能覆盖已返回 Valid 的命令预检结果。

既有可执行场景 `validation/scenes/ability_slot_fixture.gd` 已接入同一对象：Q/2 的按下与释放通过它驱动原 charge_gate。该场景原有“诊断装备、资格断言和 Timeline”边界不变，不宣称这是正式存档默认装备或完整 GAS。

命令参数限于已解码的 `actor / issuer_kind / issuer_id` 字典投影。有角色则复制命令值；无角色按原 Recreate 赋实际 owner。本地/AI 标识分别固定 local/ai，Unknown 清标识，未知枚举降为 Script，Script/Remote 保留非空白标识。激活上下文维持原对象引用，null 同样覆盖旧值。初始 Script 值只对应基类字段初值；InitRuntime.ResolveForActor 的完整玩家/AI 查询未覆盖，接入路径首先执行 Fire，不能把未启动对象的初值当成实际来源。

## 本轮验证

`tests/test_active_ability_fire_context.gd` 经同一原生角色、命令执行器、槽位和 resolved 调度驱动真实 HoldRelease：

- A 起手后 B 在 Charging 期间再 Fire，预检 Valid、不重查规则、不另起序列，但 B 覆盖命令及激活上下文。
- StopFire 释放原序列，只在真实 USE 时消费 B；后摇结束清激活上下文，关闭同一实例且保留命令。
- null 完成回调删除 A 回调；非空 B 回调替换 A；角色补齐与来源规则、结构值拷贝、激活引用、重复结束通知均覆盖。
- 同一测试可带私有原始导航和角色图集运行。私有素材不进入本提交。

## 尚未验收

未实现完整技能宿主、GAS 生命周期 Begin/Commit/Cancel/End、出手点资格检查、默认激活上下文构造、Reset、所有重入场景或 Unity/Godot 双引擎画面对比。测试 USE 消费端仅记录上下文，不伪造伤害、消耗或费用。整个项目未完成验收。
