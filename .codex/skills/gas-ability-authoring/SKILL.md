---
name: gas-ability-authoring
description: FantasyWord 项目内 EX-GAS 技能制作与排查流程。用于制作、修改或验收 GAS/EX-GAS Ability、Timeline、TaskApplyEffects、GameplayEffect、GameplayCue、TargetCatcher、普攻、背刺、蓄力攻击、命中范围预览与编辑；也用于避免把 AbilitySheet、旧执行资产、项目侧第二套命中框或自动刷新补丁重新带回正式链路。
---

# FantasyWord GAS Ability Authoring

## 先锁定

动手前先明确四件事：

- **问题对象**：具体是哪一个 Ability Code、Timeline ID、GameplayEffect ID、Cue、TargetCatcher 或打开中的时间轴窗口。
- **真相来源**：优先是 EX-GAS 表、EX-GAS 时间轴窗口、Luban 生成结果、当前打开 Unity 窗口状态和现有测试证据。
- **目标入口**：默认是 `EXTool/EX-GAS/时间轴技能编辑器`、EX-GAS Ability / Timeline / GameplayEffect / Cue 表，以及项目侧已登记的 GAS 扩展。
- **验收口径**：回到用户原始位点验证，例如当前打开窗口、当前预览实例、当前命中帧、当前 SceneView 手柄、真实普攻链路或定向测试。

缺任一项时，只补证据；不要先改代码或补 UI。

## 单一真相

- 技能身份、规则、消耗、冷却、阻断、时间轴、命中帧、伤害、Cue 触发，默认由 EX-GAS 承担。
- 项目侧只能保留已登记的薄扩展：`exgas.abilityGameCore`、`CuePlayGameCoreAnimator`、`CuePlayGameCoreAudio`、`CuePlayGameCoreFeedback`、`CatchAreaPolygon2D`、正式伤害桥等。
- 不恢复 `AbilitySheet`、`ActiveAbilitySheet`、`PassiveAbilitySheet`、`MeleeAbilityExecutionAsset` 或项目侧第二套时间轴作为已迁移技能的正式入口。
- 如果 EX-GAS 缺能力，优先在 GAS 主轴或项目 fork patch 内补正式能力；不要新造并行制作窗口或缓存页。

## 制作流程

1. **Ability**
   - 在 EX-GAS Ability 表中新建或选择 Ability。
   - `AbilityLogic` 选 `ALTimeline`。
   - `AbilityLogic.Param.ID` 指向 Timeline ID。
   - 项目输入、根模式和本地门控放在 `exgas.abilityGameCore`，只引用 EX-GAS Ability Code。

2. **Timeline**
   - 在 EX-GAS Timeline 中配置 `LifeTime` 和轨道。
   - `TaskDoCost` 负责消耗。
   - `TaskPlayCue -> CuePlayGameCoreAnimator` 负责装备系统动作键。
   - `TaskApplyEffects + TargetCatcher` 负责命中帧目标捕获和应用 GameplayEffect。

3. **动画与素材**
   - `CuePlayGameCoreAnimator.AnimationName` 填装备系统动作键，例如 `Attack` 或 `ChargedAttack`。
   - FantasyWord 当前素材组织是角色动作和武器层分离；武器攻击与武器自带特效随装备/武器动作播放。
   - 只有用户拆出正式独立特效素材后，才新增独立特效 Cue；不要用临时特效 Prefab 冒充完成。

4. **命中范围**
   - `TaskApplyEffects.IDs` 填 GameplayEffect ID。
   - `TargetCatcher` 优先用 `CatchAreaPolygon2D` 表达四方向俯视角真实近战范围。
   - `points` 保存多边形顶点；`layer` 保存可命中目标层。
   - 不在场景里手摆武器 Hitbox 子物体作为技能真相。

5. **GameplayEffect**
   - 普通伤害写 `FormalDamage`。
   - 背刺等条件附加伤害写同一个 GE 上的 `FormalConditionalDamage`。
   - 伤害数值不写在 `TaskApplyEffects` 里。
   - 受击反馈、冲击、无敌时间、飘字等表现参数优先在 GE 侧配置。

6. **保存与导出**
   - 时间轴调整后点击 EX-GAS 时间轴窗口原保存按钮。
   - 表入口在 `EX_GAS_Config/ProjectConfigTable/exgas_config/Datas`。
   - Luban 生成结果进入 `Assets/DataGenerated/Luban/Json/GAS`。
   - 不手改生成 JSON。

## 预览与编辑

- 打开 `EXTool/EX-GAS/时间轴技能编辑器`。
- 选择 Timeline，例如普攻 `101`。
- 在 `预览实例` 里指定当前场景角色，例如 `EquipmentSystemDemoCharacter`；不要自动绑定。
- 选中 `TaskApplyEffects -> CatchAreaPolygon2D` 片段。
- 选中后应自动跳到命中帧并刷新预览；SceneView 中显示多边形手柄。
- 拖中心点移动整体，拖顶点调整轮廓，右键插入或删除顶点。
- 调整后仍用 EX-GAS 原保存按钮写回表；不要新增自动保存、自动读表、自动重建缓存或第二套保存入口。

## 排查顺序

1. 当前窗口是否已经打开并选中正确 Timeline。
2. `预览实例` 是否为空。
3. 选中的是否是 `TaskApplyEffects`，不是 GameplayEffect 配置页。
4. 当前 Task 的 TargetCatcher 参数是否为 `CatchAreaPolygon2D` 或已支持的 2D 捕获器。
5. SceneView 手柄能否解析当前时间轴窗口、当前 Inspector 对象和预览实例。
6. Console 是否有 Odin/Unity 兼容错误，例如 `MissingFieldException`、`OdinPropertyException`、`SmartFloatField`、`SmartIntField`。
7. 若是运行时不生效，再查 Ability 激活、Timeline 推帧、TargetCatcher 捕获、GameplayEffect 应用、正式生命值变化。

## 禁止动作

- 不为“页面看起来有数据”增加打开窗口自动读表、构造时读表、自动刷新、自动保存或自动选中。
- 不新造项目侧替代窗口、替代时间轴、替代命中框保存入口。
- 不把 TopDownEngine 的武器 Prefab / CharacterAbility 运行时直接混进 EX-GAS 技能主轴。
- 不把 2DRPGEngine 的时间轴或编辑器当作正式运行时 owner。
- 不把插件小报错止血说成根因修复；必须回到原位点验证。
- 不在未验证当前窗口状态时调用 `ShowWindow()` 重新打开窗口冒充用户原始位点。

## 需要深挖时

- 完整制作流程：`openspec/changes/refactor-melee-ability-authoring/authoring-flow-basic-attack-and-backstab.md`
- GAS 正式边界：`openspec/specs/ability-authoring-foundation/spec.md`
- 插件边界与验证规则：`docs/ai/开发与验收规范.md`
- Unity 自动化：`.codex/skills/aibridge/SKILL.md`
