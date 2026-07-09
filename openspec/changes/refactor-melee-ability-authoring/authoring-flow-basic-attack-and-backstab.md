# 基础攻击、背刺与蓄力攻击制作流程

## 当前结论

基础攻击、背刺和单档蓄力释放当前已经进入 EX-GAS Timeline / GameplayEffect 闭环。

当前基础攻击的正式可用链路是：

1. EX-GAS Ability 配置是基础攻击的正式能力入口。
2. 已迁移普攻不再拥有已删除的旧能力表身份根；已删除的旧能力表入口不得再把已迁移技能反解、授予、装备或触发成 EX-GAS Ability Code。正式输入配置已经迁入 `exgas.abilityGameCore`。
3. EX-GAS Ability 使用 `ALTimeline` 指向 Timeline。
4. Timeline 上用 `TaskDoCost` 支付资源。
5. Timeline 上用 `TaskPlayCue -> CuePlayGameCoreAnimator` 触发装备系统动作键。
6. Timeline 上用 `TaskApplyEffects + TargetCatcher` 在指定帧执行真实 2D 近战判定和目标过滤；当前基础攻击的具体捕获器是项目侧非侵入扩展 `CatchAreaPolygon2D`。
7. 命中后应用 `GameplayEffect 2003 + FormalDamage`，由正式伤害链结算基础伤害。
8. 同一个 GameplayEffect 上可配置 `FormalConditionalDamage`；当前背刺用 `ConditionKind = Backstab` 表达附加伤害。
9. `ALTimelinePlayer` 按帧推进 Timeline。

当前仍未完成的是：

- 基础攻击动画已经收口到 `TaskPlayCue -> CuePlayGameCoreAnimator`，运行时由项目侧 `CuePlayGameCoreAnimator` 把 `AnimationName` 解释为装备系统动作键；角色动作和武器层分离，武器攻击与武器自带特效由装备/武器动作一起承载。`EquipmentSystemDemo` 默认装备使用带 `Attack` 武器序列帧的 `长矛` 作为当前验收资产。基础攻击命中反馈已经收口到 `GameplayEffect 2003 CueOnApply -> CuePlayGameCoreFeedback -> GameplayFeedbackSet`；出手/命中音效当前未配置临时资源，后续正式音效仍走 `TaskPlayCue` 或 GameplayEffect Cue。
- 背刺已经完成正式 GAS Effect 条件表达，当前作为 `GameplayEffect 2003` 的条件化附加伤害配置。
- 蓄力攻击当前采用单档 `HoldRelease` 正式模型：按下进入蓄力态，松手释放独立 EX-GAS Ability `20004 ChargedAttackRelease`。

## 基础攻击制作流程

制作一个基础攻击时，策划只走以下步骤。

1. 新建或选择 EX-GAS Ability 配置
   - 填 Ability Code，例如当前测试基础攻击为 `20001`。
   - 配置 AbilityLogic、规则组件和 Timeline 引用。
   - 不在项目侧 `AbilitySheet`（已删除） 配置命中框、命中帧、伤害细节、冷却、消耗或表现时序。
   - 旧解锁/UI 链路不得再需要 `AbilitySheet`（已删除）；若仍有能力展示或解锁需求，必须单向引用 EX-GAS Ability Code，不能复制一套能力数据；输入触发、缓冲、出手朝向更新等正式输入配置必须继续留在 `exgas.abilityGameCore`。
   - 对已接入 EX-GAS 的基础攻击，不再绑定 `MeleeAbilityExecutionAsset`（已删除）；旧执行资产类型已删除，未迁移近战技能若进入正式范围必须重新制作成 EX-GAS 数据。

2. 在 EX-GAS Ability 数据中登记技能规则入口
   - 新增或选择 Ability，例如 `20001`。
   - `AbilityLogic` 选择 `ALTimeline`。
   - `AbilityLogic.Param.ID` 指向 Timeline ID，例如当前基础攻击指向 `101`。
   - 资源消耗、冷却、阻断标签、激活标签都在 EX-GAS Ability / GameplayEffect 规则侧配置。

3. 在 EX-GAS Timeline 中配置动作时序
   - 新增或选择 Timeline，例如 `101`。
   - 设置 `LifeTime`。
   - 按轨道组织动画、音效、特效、规则任务。
   - 当前基础攻击最小链路至少需要：
     - `TaskDoCost`：在出手前或出手点支付技能消耗。
     - `TaskPlayCue -> CuePlayGameCoreAnimator`：在攻击动画轨道触发装备系统动作键。
   - `TaskApplyEffects`：在命中帧调用目标捕获器并应用 GameplayEffect。
     - `CatchAreaPolygon2D`：作为项目侧注册到 GAS 的 2D `TargetCatcher`，配置四方向俯视角真实近战判定范围。

4. 配置 `TaskPlayCue -> CuePlayGameCoreAnimator`
   - 在动画轨道新增 `TaskPlayCue`。
   - `CueLogic` 选择 `CuePlayGameCoreAnimator`，不要通过覆盖 EX-GAS 内置 `CuePlayAnimator` 来实现项目侧装备动画语义。
   - `AnimatorNodePath` 留空时，从当前技能宿主根节点向子级查找装备动画控制器。
   - `AnimationName` 填装备系统动作键，例如当前基础攻击为 `Attack`，蓄力释放为 `ChargedAttack`。
   - 角色动作和武器层分离；武器攻击和武器自带特效必须跟随装备/武器动作，不在当前普攻里单独挂临时特效 Prefab 冒充正式完成。
   - 当前普攻验收场景默认装备 `长矛`，它必须配置 `Attack` 武器序列帧；如果换成其它武器，也必须满足同一素材组织合同。
   - `Attack` / `ChargedAttack` 属于装备系统动作键；如果运行时找不到装备系统动作，必须显式失败或报警，不得回退到普通角色 `Animator`，避免角色动作播放了但武器攻击和武器特效没有同步。
   - 对已绑定正式 GAS Ability 的基础攻击，不再从项目侧旧执行资产触发同一攻击动画。

5. 配置 `TaskApplyEffects`
   - `IDs`：填要应用的 GameplayEffect ID，例如当前基础攻击为 `2003`。
   - `TargetCatcher`：选择项目侧非侵入扩展 `CatchAreaPolygon2D`。
   - 不在这里直接写伤害数值；伤害数值属于 GameplayEffect。

6. 配置 `CatchAreaPolygon2D`
   - 该捕获器通过 GAS 公开的 `TargetCatcher` 注册入口接入，不修改 `Assets/Plugins/GAS` 插件源码，也不把场景中手摆的武器/Hitbox 对象作为技能真相。
   - 角色是像素动画攻击，不是 TopDownEngine 那类武器漂浮攻击；TopDownEngine 只参考出手门控、短持续伤害区和反馈组织，不套用其 `CharacterAbility` / `Weapon` 运行时或武器 prefab 动画模式。
   - `isWorldSpace`：基础近战通常为 `false`，表示跟随施放者。
   - `points`：多边形顶点，基础攻击当前为 `0.175,-0.25;1.125,-0.25;1.125,0.55;0.175,0.55`。
   - `layer`：可命中的目标层，例如当前 Hitbox 层为 `128`。
   - Scene 视图可视化手柄只在 EX-GAS 时间轴窗口当前选中 `TaskApplyEffects -> CatchAreaPolygon2D` 时出现；拖中心点移动整体多边形，拖顶点调整轮廓，右键插入或删除顶点，最终仍由 EX-GAS 时间轴原保存按钮写回表。
   - 运行时性能边界：多边形最多 16 点；先用外接盒做 `OverlapBoxNonAlloc` 候选粗筛，再对候选 Collider 做真实形状与多边形的精筛，不做全场扫描，不在热路径分配临时数组。

7. 配置 `GameplayEffect + FormalDamage`
   - 新增或选择 GameplayEffect，例如当前基础攻击为 `2003`。
   - `FormalDamage.DamageType`：伤害类型，例如物理伤害为 `1`。
   - `FormalDamage.FlatDamage`：固定伤害，例如当前基础攻击为 `4`。
   - `FormalDamage.ScalingFactor`：攻击属性缩放，例如当前基础攻击为 `1`。
   - `FormalDamage.IgnoreDefense`：是否忽略目标防御。
   - `VisualFlags`、`ImpactDataType`、`ImpactData`、`PushMode`、`PushIntensity`、`PushResistance`、`InvincibilityDuration` 用于受击表现和冲击参数。

8. 如需背刺，配置同一个 GameplayEffect 上的 `FormalConditionalDamage`
   - `ConditionKind`：填 `1`，表示 `Backstab`。
   - `FacingDotThreshold`：背刺朝向阈值，例如当前基础攻击为 `-0.35`。
   - `DamageType`：附加伤害类型，例如物理伤害为 `1`。
   - `FlatDamage`：附加固定伤害，例如当前背刺附加平伤为 `3`。
   - `ScalingFactor`：附加攻击属性缩放，当前背刺为 `0`。
   - `IgnoreDefense`：是否忽略目标防御，当前为 `false`。
   - 其它 `VisualFlags`、`ImpactDataType`、`ImpactData`、`PushMode`、`PushIntensity`、`PushResistance`、`InvincibilityDuration` 与 `FormalDamage` 同义。
   - 这不是第二个命中框，也不是第二条项目侧近战逻辑；它只是在同一个 GE 命中结果上追加条件化正式伤害。

9. 在 EX-GAS 时间轴编辑器中预览命中帧
   - 打开 `EXTool/EX-GAS/时间轴技能编辑器`。
   - 选择对应 Timeline。
   - 绑定预览对象。
   - 可用“复位”“定位”、鼠标锚点缩放、时间尺横向平移、可拖拽视野范围条和 clip 拖拽/缩放靠边自动滚动来操作长时间轴；这些都只改变编辑器视口，不修改技能数据。
   - 拖到 `TaskPlayCue` 所在帧，确认动画能从预览对象上找到 `Animator`。
   - 选中 `TaskApplyEffects -> CatchAreaPolygon2D`，拖到命中帧。
   - 当前会绘制 `CatchAreaPolygon2D` 多边形命中范围和可拖拽顶点，用来确认并调整真实命中轮廓。
   - 调整命中范围后点击 EX-GAS 时间轴窗口原保存按钮；不得新增自动保存、自动读表或第二套命中框保存入口。

10. 保存 GAS 时间轴数据
   - 通过 EX-GAS 时间轴编辑器保存。
   - 原始表入口位于 `EX_GAS_Config/ProjectConfigTable/exgas_config/Datas`。
   - 保存后通过 Luban 导表生成 `Assets/DataGenerated/Luban/Json/GAS` 下的正式 Unity JSON，不手改生成 JSON。
   - `TaskPlayCue` 没有需求标签或免疫标签时，表格里使用 `0` 作为空标签占位；生成 JSON 里的 `[0]` 会在运行时过滤成真正空标签。
   - 不再通过项目自造工作台、准备链路、修复接线或测试场景按钮保存技能。

11. 在角色上测试
   - 角色、玩家输入或 AI 决策最终解析到对应 EX-GAS Ability Code。
   - 当前阶段直接按键触发，不做技能栏 UI。
   - 已删除的旧能力表不再承载已迁移普攻身份；正式能力检查、标签、资源、冷却和命中帧推进都由 EX-GAS 承担。

## 背刺制作流程

背刺当前已经作为基础攻击同一条 EX-GAS Timeline / GameplayEffect 链路上的条件附加伤害表达。

制作背刺时，不新建项目侧命中任务，不回到 `TaskMeleeHit2D`，也不在项目侧旧执行资产里编辑正式背刺。

当前步骤：

1. 继续使用基础攻击的 EX-GAS Ability Code 和 Timeline；已删除的旧能力表不再作为背刺或基础攻击的入口桥。
2. 继续使用同一个 `TaskApplyEffects + CatchAreaPolygon2D` 命中入口。
3. 在命中后应用的 GameplayEffect 上填写 `FormalDamage` 作为基础伤害。
4. 在同一个 GameplayEffect 上填写 `FormalConditionalDamage` 作为背刺附加伤害。
5. `ConditionKind` 填 `Backstab`，当前表格值为 `1`。
6. `FacingDotThreshold` 控制“是否处于目标背后”，当前基础攻击为 `-0.35`。
7. 背刺表现若需要特殊音效、特效或飘字，后续应继续走 GE Cue 或 `TaskPlayCue`，不能回退到迁移期执行资产 feedbacks。

当前验证：

- 目标背对攻击者时，基础攻击应用基础伤害 + 背刺附加伤害。
- 目标面向攻击者时，基础攻击只应用基础伤害。
- 背刺条件和附加伤害均来自 GAS GameplayEffect 配置，不来自项目侧第二近战壳。

## 蓄力攻击制作流程

当前只支持单档松手释放，不支持轻蓄/满蓄多档，也不把提前松手拆成弱蓄力或取消分支。制作蓄力攻击时，策划只走以下步骤。

1. 在 EX-GAS Ability 表中新建独立 Ability，例如 `20004 ChargedAttackRelease`。
2. 在 `exgas.abilityGameCore` 中为该 Ability 配置项目侧运行信息，并将 `InputTriggerMode` 设为 `2`，也就是 `HoldRelease`。
3. 在 EX-GAS Timeline 中配置释放段动画 Cue，例如 `TaskPlayCue -> CuePlayGameCoreAnimator -> ChargedAttack`。
4. 在同一 Timeline 的命中帧配置 `TaskApplyEffects + CatchAreaPolygon2D`，目标捕获只作为 GAS TargetCatcher 参数，不再新建项目侧命中任务。
5. 在 GameplayEffect 中配置正式伤害，例如 `GameplayEffect 2004.FormalDamage`。
6. 若已选定正式命中音效，在 GameplayEffect 的 Cue 中配置；当前基础攻击不配置临时音效。当前武器攻击和武器自带特效随装备/武器动作承载；只有后续拆出正式独立特效素材时，才新增独立特效 Cue。

运行时语义固定为：按下技能键后角色进入 `Charging`，不会立即命中；松手时才进入 EX-GAS Timeline 释放段并在命中帧应用效果。

后续如果要做轻蓄/满蓄、多档倍率、蓄满自动释放、提前松手取消或弱蓄力，必须在 EX-GAS Ability / Timeline / GameplayEffect / Cue 上继续扩展，不能恢复旧能力表、旧执行资产或项目侧第二套命中任务。

## 禁止写进制作流程的内容

- 工作台
- 准备链路
- 修复接线
- 测试链路
- 打开测试场景
- 手动摆角色子物体碰撞盒
- 项目自造第二时间轴
- 把旧执行资产自定义 Inspector 当成最终技能编辑器

## 验证入口

验证不是策划制作步骤，只是开发验收。

当前已验证：

- Unity `assets-refresh` 成功。
- `FantasyWord.GameCore.Tests` EditMode 回归通过：`totalTests = 38`、`failedTests = 0`。
- 正式 GAS 基础攻击不再触发迁移期执行资产 weapon-use feedback。
- 原始 `#exgas.timelineAbility.xlsx` 已能导出当前基础攻击 Timeline，且正式 `exgas_tbtimelineability.json` 与导表产物一致。
- 原始 `#exgas.gameplayEffect.xlsx` 已能导出 `GameplayEffect 2003 + FormalDamage`，且正式 `exgas_tbgameplayeffect.json` 与导表产物一致。
- 基础攻击已通过 `TaskApplyEffects + CatchAreaPolygon2D + GameplayEffect 2003` 命中目标并更新正式生命值。
- 背刺已通过 `GameplayEffect 2003 + FormalConditionalDamage` 在 GE 应用阶段判断目标朝向并追加正式伤害。
- EX-GAS 时间轴编辑器的复位、定位、鼠标锚点缩放、时间尺横向平移、可拖拽视野范围条和 clip 拖拽/缩放靠边自动滚动已通过导入与 EditMode 回归验证；这些改造只移动编辑器视口，不提前写入 `TaskClipData`。
- `TaskPlayCue` 空标签占位 `[0]` 已由 `TagHelper.FilterInvalidTags` 过滤，不会作为有效标签参与运行时判断。
- `ClickMoveTest.unity` 测试后保持 `isDirty = false`。

当前不能宣称完成的内容：

- 多档蓄力、弱蓄力、蓄满自动释放、提前松手取消和蓄满独立表现。
- 后续拆分出来的正式独立特效 Cue、以及其它受击表现。当前素材组织是角色动作和武器层分离，武器攻击与武器自带特效随装备/武器动作播放；不再把“未配置独立特效 prefab”当作普攻视觉主阻塞，独立特效素材拆出后仍必须走唯一 Cue/Task 路径接入。
