# Human 主图动作与身体朝向的显式 owner 接线

锁定源：Unity `31629d53a110dd4c87d4c85e6ad5a387fbafb931`；增量基线 `bf16a6c`。

## 源码依据

- `Movable.MotionRuntime.MoveInDirection` 在 BeginMove 清零成功速度，先尝试整方向，再尝试 X/Y 轴。成功的 TryMove 记录 `direction * speed`，EndMove 后传给 UpdateMovementAnimation。它不是输入意图，也不是物理步回写后的坐标差。
- CharacterActor 的动作驱动已存在时使用该驱动，不再同时调用旧动画策略。原 Idle/Walk 判断平方长度大于 0.0001。
- 朝向由 UpdateFacingFromMovementIntent → owner.SetLookAtDirection 裁决，DirectionalSpriteLibraryDriver 另外监听身体朝向事件并读取初始值。碰壁不等于拒绝身体转向，单轴滑动也不等于身体只朝该轴。
- ClickMoveTest 玩家实例引用玩家角色 prefab，再继承 0_CharacterActor_Base，原 MovementBased=0、idleThreshold=0.05 无对应 override。本适配器不重复实现该策略；注入 owner 负责策略和完整 target/look 关系。测试宿主明确只保留此门禁子集。

## 调用

1. 显式 `entry.start_human_presentation(private_manifest, private_texture_directory)`。
2. `entry.start_human_logic(owner, rules, player_provider, map_provider, map_events, ui_guard)`。
3. owner 提供能力、速度、碰撞、`update_facing_from_intent`，并提供 `get_look_at_direction()->Vector2` 和 `look_at_direction_changed(Vector2)`。不满足就拒绝。

`human_motion_binding` 作为 native body 的显式运动 owner：接受速度只送 Human 动作驱动，意图只送 owner，图集朝向只接 owner 的批准通知。保留原 start_logic 和直接注入接口，不改变默认场景。`accepted_movement` 是单独的观察通知，供其它宿主观察，不重复调用 legacy 动画入口。

逻辑配置成功后才激活初始朝向和订阅；失败不变更图集方向。entry 退出解除订阅。独立使用 binding 必须显式 detach。表现节点消失时不剥夺原 owner 的游戏移动能力，仅停止表现通知。

## 验证与限制

`tests/test_human_motion_binding.gd` 使用原生 AnimatableBody2D、原胶囊参数、原 mask 和真实 StaticBody2D 障碍：
- 斜向受阻、X 回退成功：回调值约 `(2.828427,0)`，回调时姿态仍是 `(0,10)`，Walk 保持获准 NE；下一物理步仅 X 改变。
- 西/南均阻挡：零速度、Idle、获准 SW，订单失败且实际位置不变。
- owner 不采用 MovementBased 时，移动意图不改图集方向；accepted velocity 仍可播放 Walk。
- 缺依赖/重复绑定/失败入口原子性、移动能力门禁、表现消失与解绑。

测试使用明确的合成单像素纹理，不冒充实机视觉验收；私有原 PNG 的独立探针另测。没有迁移完整 PlayerSystem/GAS、target override 策略、装备层或其余动作。这里只把已有源迁移组件通过明确 owner 合同接起来，不虚构生产 owner。
