# ClickMoveTest: training actor lethal hit

This slice follows locked Unity `31629d53a110dd4c87d4c85e6ad5a387fbafb931`.
The active training target inherits `0_CharacterActor_Base`, 220 HP and the
regular Human directional libraries. The inherited formal death key is
`SpinDie`, not a generic `Death` fallback.

* `CharacterBase.dead` is the live formal HP-zero test; its invincibility
  includes that result immediately. Marking the body as dead in the host is
  later. A second ordinary sourced attack does not apply another hit in this gap.
  The original unresolved/no-source executor branch is not changed.
* CurrentHealth changes of the attached attributes (not just one damage hook)
  drive the positive-to-zero event. The safe stage interrupts actions first,
  rereads HP and destruction, then commits once. The target terminates its
  current voluntary move and uses the authored no-voluntary-movement-after-death
  rule. `ResetMovement` does not invent a cancellation of an already-applied push.
* With the explicitly loaded original trainer contract, the same target's
  AnimationPlayer locks nonlooping SpinDie, then the existing host death callback
  runs without waiting for the animation. There is no fallback animation and no
  automatic removal of the body. Earlier Dmg-only appearance fixtures may still
  be mounted; they do not certify death visuals.
* `tools/extract_training_target_animation.py --include-death` validates the
  inherited state, source clip, original asset metadata and external LFS bytes.
  Verified SpinDie: 1.5 s, 8 fps, 12 original frames per direction and terminal
  repeated key at 1.5 s. The contract and artwork stay private.

Verification: `test_clickmovetest_training_damage.gd` stages a living target
one hit from death and then uses the existing normalized charged attack,
timeline task, real hit area, and formal effect phase. It tests HP-zero admission,
same-phase repeat rejection, safe ordering, movement reset, and single callback.
`FORMAL_TRAINER_DEATH` additionally checks actual original atlas animation and
terminal lock. This does not add the original corpse inventory, reward/kill
notifications, buff cleansing or the full controller/ability teardown, which
still belong to the formal host. No Unity pixel parity is implied.

## 原训练假人的 SpinDie 材质

以锁定提交的 `ClickMoveTest.unity` 活动训练假人为入口，沿预制体继承核实
`EquipmentRenderer` 启用、没有材质覆盖，使用原「人类帧数据」「基础人形外观」，
初始装备为空。原本体图集与两张生成 UV 图都是 384×32。四个名义方向库
的 SpinDie 引用同一组 12 个精灵；源 `SyncFromSprite` 根据实际贴图高度算出的
采样行始终是第 0 行。帧资产还留有 30 条第 1～3 行的记录，运行时不可达；
第 0 行 12 帧齐全，不裁去末帧外观，也不补造方向图。

1. 保留原 PNG、对应原 `.meta` 与验证合同在私有目录。执行
   `tools/extract_formal_human_material.py --training-target --repo <Unity仓库> --human <原图集目录> --generated-uv <私有UV目录> --appearance-dir <私有外观目录> --output <私有目录>/material-trainer-death.json`。
   提取器核实同一训练假人的继承关系、原动作、帧、贴图导入选项及 LFS 哈希，
   只输出运行时实际采样的作者帧。
2. 调用 `start_training_target_presentation` 时可传入含
   `data`、`uv_directory`、`appearance_directory` 的第三个参数，显式安装
   同一活动假人的基础外观材质。材质包不匹配或缺少源帧即不装配，
   不把原图直显冒充材质接入。两参数入口仍可单独验证原图集和动作。
3. 将 `FORMAL_TRAINER_DEATH`、`FORMAL_TRAINER_DEATH_MATERIAL` 一同设为含动画
   和材质合同的私有目录。实际受击测试确认死前外观存在、进入 SpinDie 后
   本体和双 UV 同步、切四个方向保持精灵引用、原末帧继续使用该材质。

本阶段复用已有基础外观着色器，覆盖原始双 UV、头部外观和帧驱动；未据此
验收完整 Unity 着色器（如外围描边、地面阴影）或宣称两引擎画面一致。

## 活动假人控制器：挑衅与死亡退出

锁定 Unity `31629d53` 的 `ClickMoveTest.unity` 实例 `735002000000000003`：
假人覆写 `m_controller` 为 `AIController` 托管引用 `4536545658951696519`，
不是静态占位物，也不是另一个停用的假人。Godot 在既有
`start_training_damage_target` 产生的同一个活动假人上接入其启动与停止，
未改变现有公开入口、角色属性、碰撞或美术。

- `AIController.OnStart` 订阅挑衅。普攻、蓄力、喷火的实际角色命中，
  以及地表结算识别得到的正式角色来源，使用已解析角色对象，不以属性快照、
  命中位置或控制输入对象顶替。没有正式角色来源时，不触发 AI 的挑衅事件。
- `FormalDamageExecutor` 仍在冲击之后、扣血之前通知；不以静默、正伤害
  或视野作为挑衅事件门槛。选敌仍要求无当前目标、重选冷却为零，
  且 `CombatSolver.IsJudiciousTarget` 对当前双方状态成立。
- 安全阶段先完成既有动作打断；随后 `Movable.Kill` 停止活动控制器。
  停止先将运行状态关闭、取消订阅并清导航重算及攻击对准等待，
  不清当前目标和重选冷却；再标记死亡、重置移动并进入原 SpinDie。
  正在结算的外部推力不由此取消，原宿主 OnDeath 回调仍在动作锁定之后。

`test_clickmovetest_training_damage.gd` 从实际归一化动作、时间轴、命中盒
进入非致命和致命伤害，验证扣血前获得真实角色、死亡安全阶段的顺序、
目标与冷却保留及退订。挂接已有私有动画与材质合同时也检查真实
SpinDie 动作的进入时点。尚未接入该 AI 的侦测、巡逻路径、转向组、
游走或攻击调用，也不声称移动/攻击、完整销毁流程或 Unity 画面等价。
