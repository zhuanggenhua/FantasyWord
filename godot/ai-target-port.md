# AI 目标状态迁移切片（不是已接入的 NPC）

锁定原项目 Unity 提交 `31629d53a110dd4c87d4c85e6ad5a387fbafb931`；基底 Godot `f8355f329c29f48aba9d23ff568662f05eb5a415`。

## 本轮范围

`game_core/ai/ai_target_lifecycle.gd` 对应 `Assets/Scripts/GameCore/Runtime/Controllers/AIController.BehaviourRuntime.cs`：

- `TryHandleProvoked`（约 93 行）：没有目标、重新选敌冷却为零且来源为合理目标才接管。不另加敌对/可见门槛。
- `UpdateCooldowns`（约 157 行）：选敌、攻击、寻路三项定时器使用固定步 float32 减法并下限钳零。
- `RefreshTarget` / `FindTarget`：当前目标死亡或不合理则清理；按检测列表先后找第一个敌对且可见目标，不改为最近目标。获取新目标的当步不攻击、不做距离越界检查。
- `TryAttackTarget` 仅保留调用接缝，先于 `CheckIfTargetOutOfRange`；不伪造正式 GAS 攻击资格或提交。
- `StopChase`：清目标/等待朝向、设置冷却、清寻路定时器并通知路径缓存失效。
- `UpdateTargetPosition`：可见时更新位置和清丢失计时；不可见时用原方法的 `Time.deltaTime` 累加，不偷换为冷却使用的 `fixedDeltaTime`。严格大于超时才丢目标。丢视线当步仍保持最后位置，下一无目标步才用归位点；越界清目标则同一步归位。

目标字典是宿主提供的适配边界，包含 `position/dead/judicious/hostile/visible`。检测排序、射线遮挡、阵营关系、目标销毁引用语义仍须由正式宿主提供；这里没有自行生成世界规则。`tick` 的攻击回调必须传入，避免把空接缝解释成已实现战斗。

## 原场景不是“无 AI 依据”

`Assets/Scenes/ClickMoveTest.unity` 约 56042–56248 行对 `测试-训练假人.prefab` 实例（GUID `dca23ea6afacc0647bfd10c5cefa4099`）显式设置 AIController（managed reference `4536545658951696519`），覆盖如下：

| 配置 | 原场景值 |
|---|---|
| 位置 | (2.5, -2.75) |
| 检测半径 / 攻击触发半径 / 攻击冷却 | 5 / 1 / 1 |
| 战斗游走 | 开启，范围 3，倍率 1，组 `combat-wander` |
| 通行 / 追击组 | `transit` / `predictive-target` |
| 近身环绕 | 关闭 |
| 寻路间隔 / 目标移动阈值 / 路径容差 | 0.5 / 0.5 / 0.2（运行时最低容差另见原方法 0.3） |
| 归位和目标重置半径 | 都为 10 |
| 越界选敌冷却 / 丢视线冷却 / 丢视线超时 | 3 / 1 / 3 |
| 目标/主控期望距离 | 都为 1 |

其 steering 配置 GUID `b64a77e6e17043179c24817be9b35bde` 对应 `Assets/ProjectPlugins/ContextSteering2D/Runtime/Defaults/DefaultContextSteeringProfile2D.asset`，实际有 default/transit/predictive-target/orbit/combat-wander 五组、16 个采样方向。**Godot 诊断场景的目标当前被动，不等于原 Unity 配置被动。** 此处仅确认序列化配置；实际敌对关系、控制器启动与正式能力仍需一起验证。

因此不能拿直线追玩家或随机走动代替 ContextSteering2D 的正式评分、避障、导航、游走与移动提交。本轮没有更改诊断场景，也没有声称 NPC 追击已经可玩。

## 验证与未验收

新增 `tests/test_ai_target_lifecycle.gd` 30 项，覆盖选择顺序、首次获取延迟攻击、死亡/资格失效、越界边界、回调时序、三种计时器、挑衅资格、最后可见点与超时步差、动态归位点、float32 运算。运行 `GODOT=/path/to/godot bash godot/tests/run.sh`，本切片 32 个测试脚本全部通过。

尚未接入真实碰撞检测列表、阵营和视线、攻击朝向门禁、GAS 攻击、ContextSteering2D、实体生命周期/存档、原图形/动画。该通过结果只说明目标状态切片与既有诊断回归，没有整体迁移或完整游戏验收结论。没有上传原资源、原截图或原第三方代码。

## 进一步确认的初始阵营资产

训练假人 prefab 的 `m_sheet` 绑定 `测试-训练假人配置.asset`，其
`m_alignment: 1` 对应源 `EAlignment.Evil`；玩家 prefab 的 `m_sheet`
绑定 `玩家角色配置.asset`，其 `m_alignment: 0` 对应 `Good`。
这证明了锁定项目的默认角色配置具备敌对关系的输入事实，不证明运行时没有
状态/阵营覆盖，也不证明实际 Unity AI 已选择目标或成功出手。仍需接原转向策略和场景状态。
