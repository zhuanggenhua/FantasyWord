# Proposal: refactor-melee-ability-authoring

## Why

当前近战技能线的主问题不是“再补一个项目侧编辑器”，而是已经出现了同职责双轨风险：

- 项目侧旧链路曾通过 `MeleeAbilityExecutionAsset / MeleeAttackAbility / MeleeAbilityExecutionAssetEditor` 让基础攻击跑通；当前 `AbilityExecutionAsset`、`MeleeAbilityExecutionAsset` 和旧执行资产编辑器已删除，不再承担任何技能的正式作者入口。
- 但 EX-GAS 2.0 本体已经存在 `TimelineAbility / XParamTimeline / AbilityTask / TargetCatcher / GameplayCue Preview`。
- 继续扩张项目自造 `MeleeAbilityTimelineWindow` 会和 GAS 时间轴争夺同一份近战时序、命中框、命中任务和预览职责。

因此本 change 的方向改为：正式技能配置、规则和近战时间轴执行/预览主轴收口到 EX-GAS；项目侧 `AbilitySheet`（已删除） / `ActiveAbilitySheet`（已删除） / `PassiveAbilitySheet`（已删除） 类型已删除，不能继续作为技能身份层或存量资产反序列化入口。项目侧近战执行资产已删除，不能继续拥有同职责真相。

## Current State Lock

当前仓库真实现态：

- `EX-GAS 2.0` 已接入，并提供 `ALTimeline / ALTimelinePlayer / XParamTimeline / Track / TaskClipData`。
- `TaskApplyEffects` 已能通过 `TargetCatcher` 应用 `GameplayEffect`。
- `CatchAreaBox2D` 已能用 `Physics2D.OverlapBoxNonAlloc` 做 2D 盒形捕获，并支持 `OnEditorPreview()` 画盒。
- `TaskPlayCue`、`GameplayCueUnit` 和 `GameplayCueBase.OnPreview()` 已支持 Cue 编辑器预览方向。
- 项目侧旧执行资产自定义 Inspector 已删除；已迁移普攻的命中、时序和表现预览不再从旧执行资产 Inspector 进入，后续冲刺、投射物、召唤迁移也不得恢复旧执行资产作者面。
- 项目自造 `MeleeAbilityTimelineWindow` 已判定为错误扩张方向，已从人类可见入口撤回并删除文件。

## 职责裁决表

| 职责 | 候选来源 | 正式 owner | 本次吸收什么 | 本次明确不吸收什么 | 验证入口 |
| --- | --- | --- | --- | --- | --- |
| 技能配置/身份数据 | `AbilitySheet`（已删除）、EX-GAS Ability 配置 | EX-GAS Ability 配置 | Ability Code、Level、AbilityLogic、Cost、Cooldown、Tags、Timeline、GameplayEffect、Cue；项目 UI、输入、保存恢复、授予/压制和规则绑定必须直接持有 GAS Ability Code 或派生 ability code | 把 `AbilitySheet`（已删除） 保留成第二套技能目录、第二套输入/冷却/描述/执行资产；把已删除的旧能力表反解成 EX-GAS Code；把 TopDown `CharacterAbility/Weapon` 混进同一普攻 | GAS Ability 编辑页、Luban/Json 产物、`FormalAbilityAssetValidation` |
| 规则真相 | EX-GAS、项目侧旧伤害壳 | EX-GAS | Cost、Cooldown、Tags、GameplayEffect、属性/状态/伤害结算 | 项目侧二次扣蓝、二次冷却、动画事件直接扣血 | `FormalDamagePipelineEditModeTests`、`MeleeAttackAbilityEditModeTests` |
| 近战时序/执行数据 | `MeleeAbilityExecutionAsset`（已删除）、EX-GAS `XParamTimeline`、动画事件 | EX-GAS `XParamTimeline + TaskClipData` | 用 GAS 时间轴承载命中窗口、命中任务、Cue 任务；项目执行资产不再保留 | 旧执行资产和 `XParamTimeline` 双写同一命中窗口 | GAS `ALTimelinePlayer`、`TaskClipData` |
| 命中/目标捕获 | 项目侧 `BoxCollider2D` 扫描、EX-GAS `TargetCatcher` | EX-GAS `TargetCatcher` | `CatchAreaBox2D` 作为基础攻击 2D 盒形命中入口 | 角色层级手摆 `MeleeHitbox` 当技能真相 | `TaskApplyEffects`、`CatchAreaBox2D` |
| 作者可视化/预览 | 项目自造时间轴、EX-GAS `AbilityTimelineEditor`、Kybernetik | EX-GAS `AbilityTimelineEditor` | 时间尺、轨道、TaskClip、帧预览、`OnEditorPreview()`；Kybernetik 只作命中框体验验收参考 | 项目自造第二时间轴、工作台、准备链路、测试链路 | `AbilityTimelineEditorWindow.EvaluateFrame()`、`TaskClip.OnTickView()` |
| 表现触发 | `GameplayFeedbackSet`、EX-GAS `GameplayCue` | `GameplayCue` 触发；项目反馈只能作为被调用实现 | `TaskPlayCue` / GE Cue 触发表现和预览；如需复用 `GameplayFeedbackSet`，只能通过唯一 Cue/Task 转发 | Cue 和 FeedbackSet 两边各配一套同职责表现时序 | `TaskPlayCue`、`GameplayCueBase.OnPreview()` |

## Reference Verdict

### EX-GAS 2.0

正式吸收：

- `XParamTimeline + Track + TaskClipData` 作为时间轴数据结构。
- `ALTimelinePlayer` 作为时间轴运行时推进器。
- `TaskApplyEffects + TargetCatcher` 作为命中/目标捕获/效果应用闭包。
- `TaskPlayCue + GameplayCue.OnPreview` 作为表现触发和编辑器预览闭包。
- `AbilityTimelineEditorWindow` 作为正式时间轴编辑器基线。

明确不吸收：

- 当前 `LoadPreviewScene()` / `BackToScene()` 直接切场景的实现，除非先补场景保存守卫。
- 把 Excel 文件暴露成策划人工配置入口。Excel/Luban 只允许作为 GAS 数据持久化/导表层，不是第二套人工真相。

裁决：

- EX-GAS 赢规则、时间轴执行、目标捕获和编辑预览职责。
- 项目侧不再继续扩张同职责时间轴。

### TopDownEngine

正式吸收：

- 只把 `CharacterAbility` / `Weapon` 的能力组织经验作为行为参考：输入触发、出手门控、短持续伤害区、冷却、移动限制和反馈组织。
- 若某个 TopDown 能力值得采用，必须重新表达为 EX-GAS Ability、Timeline、Task、GameplayEffect 和 Cue。

明确不吸收：

- 不吸收 TopDown 的 `CharacterAbility`、`Weapon`、`MeleeWeapon`、`InputManager` 或 prefab hitbox 运行时作为正式实现。
- 不允许同一个普攻同时由 TopDown 风格 MonoBehaviour 能力链和 EX-GAS Ability 链参与。
- 不允许用 TopDown 的武器 prefab 结构替代本项目角色像素动画攻击。

裁决：

- TopDownEngine 不是能力系统 owner，只是行为参考来源。
- 当前项目能力系统必须以 EX-GAS 重新表达 TopDown 值得采用的能力语义。

### 2DRPGEngine / CLineActionEditor

正式吸收：

- 只作为 GAS 编辑器易用性验收参考：时间尺、轨道区、clip 拖拽、缩放/平移、Inspector 联动、切换对象重置视图。

明确不吸收：

- 不吸收其业务数据模型。
- 不用它作为继续自造项目侧时间轴的理由。

裁决：

- 2DRPGEngine 不是当前时间轴 owner，只是体验对照。

### Kybernetik Platformer Game Kit

正式吸收：

- 动画帧命中框作者体验要求。
- 命中框可视化预览要求。
- 运行时消费正式命中数据，而不是让场景 Collider 成为真相。

明确不吸收：

- 不吸收横版平台动作项目结构。
- 不吸收其具体运行时业务实现。

裁决：

- Kybernetik 是命中框体验验收参考，不是数据 owner。

## Formal Refactor Scheme

重构后近战正式结构固定为三层：

1. EX-GAS Ability 配置
- 正式技能配置入口。
- 负责 Ability Code、AbilityLogic、Cost、Cooldown、Tags、Timeline、GameplayEffect、Cue。
- 项目侧 UI 展示、技能栏、输入槽若仍缺承载物，只能做薄桥或视图数据，引用 EX-GAS Ability Code，不得复制技能规则和执行数据。

2. EX-GAS `XParamTimeline`
- 近战时序和命中任务真相。
- 负责动作时序、TaskClip、命中窗口、目标捕获参数、效果应用任务、Cue 任务。

3. EX-GAS runtime
- `ALTimelinePlayer` 推进时间轴。
- `TaskApplyEffects` 调用 `TargetCatcher` 捕获目标并应用 `GameplayEffect`。
- `TaskPlayCue` 或 GE Cue 触发表现。

迁移约束：

- `AbilitySheet`（已删除） / `ActiveAbilitySheet`（已删除） / `PassiveAbilitySheet`（已删除） 类型已删除；历史存档兼容不得再保留旧表对象身份，必须迁移到 EX-GAS Ability Code、显式迁移数据或明确的待迁移缺口。
- 已迁移技能的授予、撤回、压制、保存恢复和正式规则绑定必须以 GAS Ability Code / ability code 为主键；不得再以已删除的旧主动能力表对象身份作为正式规则真相。
- `MeleeAbilityExecutionAsset` 已删除，不再允许作为技能字段暂存地；任何能力进入正式范围时必须重新表达为 EX-GAS 数据。
- 命中窗口、命中框和命中任务不得由项目侧旧执行资产持有真相；正式真相只能是 EX-GAS Timeline / TargetCatcher / GameplayEffect。
- 项目自造 `MeleeAbilityTimelineWindow` 不保留为隐藏入口。

## First Safe Implementation Scope

第一批安全实现只做：

- 把基础攻击用 EX-GAS Timeline 表达一条最小链：Cost/Cooldown、命中窗口、`CatchAreaBox2D`、`GameplayEffect`、Cue/Feedback 触发。
- 给 GAS 时间轴编辑器补场景切换保存守卫，避免 `NewScene/OpenScene` 导致保存弹窗。
- 删除 `MeleeAbilityExecutionAsset`，避免基础攻击同职责字段继续被误当最终真相。
- 保留基础攻击和背刺现有回归，防止迁移打坏已跑通链路。

第一批不做：

- 蓄力攻击正式模型。
- 复杂法术。
- 技能栏 UI。
- 职业、技能树、流派内容。
- 玩家炼金/节点配置。

## Acceptance Direction

- OpenSpec 必须明确 EX-GAS Timeline 是时间轴/命中/预览主轴。
- 项目自造 `MeleeAbilityTimelineWindow` 必须从人类可见入口和正式口径中撤回。
- 基础攻击迁移前，不得宣称 change 完成。
- 验证必须覆盖基础攻击命中、EX-GAS 规则结算、OpenSpec strict validate，并确认没有场景 dirty 残留。
