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
SpinDie 动作的进入时点。受击测试不绑定该 AI 的自主侦测、巡逻路径、转向组、
游走或攻击调用，也不声称移动/攻击、完整销毁流程或 Unity 画面等价。

## 固定步接入边界：实际场景角色的视线与选敌

公开的受击入口仍可独立运行。选敌由正式场景宿主在已绑定实际玩家、活动假人和
碰撞世界之后，通过 `start_training_target_tracking` 连接。只读既有正式属性，
不在碰撞体上伪造初始身份，也不凭空生成地图遮挡。假人取真正会被推移的物理
身体位置，不取一直留在出生点的表现父节点。

原 `AIController.BehaviourRuntime` 先更新固定步冷却再读取上次检测帧；
`ContextSteeringSimulation2D` 的执行顺序 10000 随后才生成检测帧。
ClickMoveTest 指定 128 容量，原配置障碍探测半径 1，训练假人语义半径 5；
感知沿用实际层 3144 的有限视线射线。首步不能凭空获得碰撞结果；已选中目标
使用最新实际坐标和实时视线。失明时保留上次可见点，严格超过 3 秒后失去目标；
超出归位或目标距离 10 则当步归位，原选敌冷却分别为 1 秒和 3 秒。

仅接入已证实可采样的归位、最终靠近和战斗游走距离分支；未知远距寻路时
不生成新帧，不模拟转向。边界来自源路径容差 max(0.2, 0.35, 0.3)，
最终靠近阈值 1.35，战斗游走距离 3。原训练假人预制体明确绑定正式技能
20001（普攻），这里并未接通该技能、巡逻、实际追击或完整世界遮挡。
`test_clickmovetest_training_tracking.gd` 用实际 Entry 和玩家物理身体验证，
测试用的遮挡物和角色摆放不是原场景部署，不能据此宣称双引擎视觉验收。

## 原训练假人普攻 20001

锁定的「测试-训练假人」预制体额外正式能力列表含 20001，角色表的空技能数组
不表示没有普攻。实际 Entry 在接通同一玩家的实时属性和碰撞世界后，可显式接
玩家受击生命周期、逻辑目标方向及随机源；若没有该假人原 Attack 动作则拒绝
装配。玩家受击盒继承自 `0_Character_Base` 的实际子碰撞体，层 128，
矩形 .6×1，Godot 坐标偏移 (0, -0.5)，不是移动胶囊。

自动选敌当步不攻击；随后按视线、距离严格小于 1、方向严格小于 5°、正式
CanFire 决定出手。未对准先设置朝向，下一固定步才可出手。真正命令归属于
同一假人，使用 AI 上下文并复用正式命令的 Stop / Fire 及结果，不以输入门控
的内部缓冲返回值当成正式结果。有效时写源冷却 1 秒。正式 Timeline 101
第 2 帧开始 Attack，第 8 帧从假人真实根和身体朝向查询玩家受击盒，第 24 帧
移除动作。Effect 2003 使用实际双方属性和玩家逻辑方向；源数值正常正面
100→97 无推力，玩家作者命中反馈槽为空，不补造反馈素材。

`extract_training_target_animation.py --include-attack --include-death`
核验原四向库及素材哈希，生成仅供私有复测的训练假人动画合同。使用同一假人动作生成的完整材质合同核实 Attack 的原本体图集、Body/Head
双 UV、时间轴和命中；这些检查不等同 Unity 像素或全录制时序对比。没有把可选
正式接线变成默认完整场景，也没有替代正式全图碰撞、AI 寻路、转向评分和
Unity 同场景画面对比。原图集、私有合同、截图不上传。

## 原出生间距的导航目标

活动假人从 (2.5, -2.75) 观察位于 (0, 0) 的原玩家；相距约 3.72，
因此首次选中实际玩家需要先查询地图，不是直接走向玩家。入口将既有
`TerrainWorldRoute` 传给同一个固定步控制器。锁定的 649 节点默认层
在真实入口返回三点：(0.5, -2.5)、(0.5, -0.5)、(0, 0)。第一点用原
`transit` 组，最后一点用 `predictive-target`，走向中间点时不启用
原最后点才有的到达半径 1。

原路径游标在 .35 容差内跳过已抵达的中间点，不跳过最后一点；目标位移
达到 .5 或 .5 秒计时归零便重算。存在地图却无路径时不生成目标，也不
刷新已发布的探测帧；明确没有活动地图才是原默认组直接目标的独立分支。
原战斗游走距离 3 优先于最终接近 1.35；清目标路径、卸载本地世界及
停止控制器都不把旧光标交给下一目标。

覆盖实际场景入口及锁定路网的选路、重算和行为组决策。此阶段仍未接通
有作者碰撞形状、实际邻居和接触修正的转向模拟；导航描述不是角色已经
追上去，不用直线位移或诊断几何补缺。

## 同一实际玩家受击动作与恢复

原 `CharacterBase.PrepareFormalDamageHit` 先记录有效来源；非静默命中
请求安全阶段打断、调用玩家原 Dmg，再由正式伤害执行器扣血。入口显式
绑定当前玩家原动作与既有行动拥有者，不以空反馈槽或占位帧替代角色动作。
玩家本轮只接非致命正式受击和动作打断，实际属性、死亡和其它能力系统
仍由原调用方负责。

同一实际碰撞的普攻验证确认玩家在 100→97 前进入 Dmg，随后安全阶段
只消费一次行动打断；测试既覆盖静止按原 .5 秒恢复 Idle，也覆盖真实
运动表现绑定在 Dmg 中更新恢复到 Walk 而不提前结束受击。玩家本体与原
双 UV 用独立的玩家作者合同验证，不把假人合同当玩家资源。反馈槽及受击
音源为空，未加假反馈。该阶段尚不等同完整原场景追击与画面对比。

## 同一原场景的普攻死亡诊断

在 `--source-preview --trainer-diagnostic --player-combat-diagnostic` 之后加
`--trainer-death-diagnostic`。需要设定 `FORMAL_TRAINER_ATTACK_DEATH_ANIMATION`
和 `FORMAL_TRAINER_ATTACK_DEATH_MATERIAL`，分别指向同一活动假人含
Idle、Walk、Dmg、Attack、SpinDie 的原动画与材质合同；纹理仍由
`FORMAL_TRAINER_ATTACK_TEXTURES` 指定。动画提取命令增加
`--include-attack --include-death`，材质提取增加 `--training-target --include-attack`。
旧诊断及默认场景入口不变；普通启动保持真实出生和 220 生命。

增加 `--smoke` 会单独布置一击诊断：玩家按原槽 1，实际碰撞结算在普攻第
8 帧使假人归零。原 `CharacterBase.Update` 先消费该角色待决受击/死亡，
再推进其技能；死亡停 AI、重置主动移动、锁定实际 SpinDie、再收尾拥有的攻击。
假人正处在反击第 7 帧时也不得在安全阶段后再命中。验证保留原身体和受击盒、
材料切换到单行身体和头部 UV，以及 12 帧动作结束后保留第 11 号帧。
这不是 Unity 截图验收，也不含掉落、奖励、任务、复活或玩家死亡。
