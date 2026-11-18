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
