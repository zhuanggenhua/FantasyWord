# 换装动作来源与刷新入口迁移边界

## 真相源与范围

锁定 Unity `31629d53a110dd4c87d4c85e6ad5a387fbafb931` 的 `EquipmentRenderer.cs`：`CacheValidAnimParams`、`SyncAnimationName`、`LateUpdate`、`SyncCurrentSpriteAndRefresh` 及下一帧同步请求。沿用 `equipment_frame_runtime.gd` 和原帧游标/刷新 owner，不新增材质、装备槽位或视觉策略。原 `late_sync` / `sync_current_sprite` 已解析动作键入口保持兼容。

## 对应规则

- 新 `sync_animation_owner`：覆盖键非空白优先，其次代码动作键，其次 Animator 原参数顺序中的首个激活且被动作数据库认可的 Bool。无激活 Bool 仅在 Animator 存在时选择 Idle；无 Animator 不改变当前动作。
- `animation_database_keys` 来自 `AnimationTypeDatabase` 非空条目的 `name`，不能从现有 body 帧数据键反推。认可的动作缺 body 数据时仍选择该键，清空旧 UV，不改成 Idle。
- `animation_context_override_key` 表示源中已存储的覆盖字段；源公开 setter 的 Trim/同值短路不是此字段赋值接口提供的能力。调用方若迁移该 setter，应先按源规范化，再使用本入口。代码动作键只判空白，不 Trim 非空字符串。
- `animator_parameters` 是源参数顺序快照，`type="bool"` 只标识源 Bool，实时 Bool 值单独传入 `animator_bool_values`。合法参数列表首次使用时缓存；`invalidate_animation_owner_cache` 对应源 `SetFrameData` 的参数缓存失效步骤，不冒充完整帧数据切换方法。更新参数描述不自动失效，换帧数据的调用方必须执行该步骤。
- `late_sync_from_owner` 在原图直显时仅保持原材质；否则先解析动作、立即写 UV，再由原游标只在 Sprite 引用变化时刷新槽位。因此同一 Sprite 切动作会立即更新 UV，但不会凭空追加槽位刷新。
- `sync_current_sprite_from_owner` 在 Sprite 非空时解析动作并显式采样；空 Sprite 只 Refresh，保留动作、坐标及上次 Sprite。直显模式的显式入口与 LateUpdate 不同，仍遵循这条流程。
- `request_sync_after_next_sample` 拒绝未启用组件请求，重复请求合并为一项。调用方必须在下一帧 Animator 采样完成后调用 `sync_after_next_sample`，该入口消费一次最新动作/Sprite。这里不拥有场景帧调度，也不声称实现 Unity 协程/组件禁用销毁的完整生命周期。

## 验证与未验收

新增 `test_equipment_action_owner.gd` 通过真实运行时 UV/Refresh 回调验证优先级、参数缓存、未知动作清空、同引用只更新 UV、显式空 Sprite、原图直显区别和延迟请求边界。多 Bool 顺序是合成合同测试，不声称正式 Controller 有多个激活 Bool。锁定正式共享 Controller 的参数数组为空，相关分支仅验证 Animator 存在时的 Idle 选择。

本阶段是无头运行时接口合同，不是正式角色实例或工作台已接入证明；不包含原始素材，不包含 Unity/GameView 或 Godot 原生 GPU 截图，不代表整项一比一迁移验收完成。下一项仍需正式角色/工作台接线、真实帧采样时序与完整视觉对照。
