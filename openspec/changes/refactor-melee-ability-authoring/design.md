# Design: refactor-melee-ability-authoring

## Final Architecture

### A. 技能配置层

正式 owner：EX-GAS Ability 配置

职责：

- Ability Code / Level
- AbilityLogic
- Cost / Cooldown / Tags
- Timeline / Task / GameplayEffect / Cue
- 技能正式规则配置和执行入口

不承担：

- 近战命中窗口真相
- 近战命中框真相
- 项目 UI 技能槽状态
- TopDown 风格 `CharacterAbility/Weapon` 运行时
- 项目侧第二套技能目录真相

迁移口径：

- 项目侧 `AbilitySheet`（已删除） / `ActiveAbilitySheet`（已删除） / `PassiveAbilitySheet`（已删除） 类型已删除；正式 UI、输入、授予、临时效果、作者入口和存档迁移都不得再依赖旧表对象身份。
- 若后续仍需要图标、技能槽、技能树、解锁、保存恢复或临时授予数据，应拆成薄的展示/入口数据，并单向引用 EX-GAS Ability Code；基础攻击的 Prefab、AbilityRootMode、本地输入门控、角色组件附加能力、读档恢复、能力型临时效果和正式规则绑定已迁到 GAS code / ability code 优先路径，不能再回到 `AbilitySheet`（已删除） / `ActiveAbilitySheet`（已删除）。
- 不得继续让 `AbilitySheet`（已删除） 持有冷却、消耗、命中、伤害、时间轴、Cue、执行资产等正式技能真相。
- 运行时容器和保存快照也必须按同一职责边界拆分：正式 GAS 实例以 EX-GAS Ability Code 枚举和保存；已删除的旧能力表实例快照已删除；正式 GAS 实例只能以 EX-GAS Ability Code 枚举和保存。
- TopDownEngine 的 `CharacterAbility` / `Weapon` 只能作为行为参考；采纳其能力语义时，必须重新表达为 EX-GAS Ability / Timeline / GameplayEffect / Cue，不得混用 TopDown 运行时。

### B. 近战时间轴层

正式 owner：EX-GAS `XParamTimeline + ALTimeline`

职责：

- 时间轴总帧数
- 轨道和 TaskClip
- 命中窗口开始/结束帧
- 效果应用任务
- 表现任务
- 未来蓄力段任务

不承担：

- 技能身份与数据库登记
- 项目侧第二套命中扫描真相

### C. 命中捕获层

正式 owner：EX-GAS `TargetCatcher`

职责：

- 2D 盒形命中使用 `CatchAreaBox2D`
- 2D 圆形区域后续使用 `CatchAreaCircle2D`
- 自身/锁定目标使用 `CatchSelf / CatchTarget`
- 编辑器预览走 `TargetCatcher.OnEditorPreview()`

不承担：

- 伤害数值本体
- 技能身份
- 场景层级手工 Collider 配置真相

### D. 规则层

正式 owner：EX-GAS `GameplayEffect / Cost / Cooldown / Tags`

职责：

- 资源消耗
- 冷却
- 标签裁决
- 伤害、治疗、状态、属性变化

不承担：

- 项目侧第二套伤害描述
- 表现系统直接改数值

### E. 表现层

正式触发 owner：EX-GAS `GameplayCue`

项目侧表现实现：`GameplayFeedbackSet` 只能作为被 Cue/Task 调用的唯一反馈实现。

边界：

- `GameplayCue` 可触发特效、音效、动画、飘字等表现。
- `GameplayCue` 不得修改属性、决定命中、支付资源或启动冷却。
- 不得让 `GameplayCue` 和 `GameplayFeedbackSet` 各自拥有同一份表现时序。

## Current Implementation Reality

当前代码现态：

- 基础攻击正式链路已经迁到 EX-GAS Ability / Timeline / `TaskApplyEffects` / `GameplayEffect` / Cue。
- `MeleeAbilityExecutionAsset` 已删除，不能再作为近战技能、存量测试或旧数据升级线索；普攻命中框、命中窗口、伤害和反馈真相只允许来自 EX-GAS。
- 项目侧 `MeleeAbilityExecutionAssetEditor`、`DashAbilityExecutionAssetEditor`、`ProjectileAbilityExecutionAssetEditor`、`SummoningAbilityExecutionAssetEditor` 已删除；旧执行资产类型已删除，不再提供基础攻击、冲刺、投射物或召唤作者面。
- EX-GAS 已经提供时间轴、任务、目标捕获和 Cue 预览闭包。
- 项目自造 `MeleeAbilityTimelineWindow` 已被判定为同职责第二时间轴，已经撤回。

因此实现顺序改为：

1. 撤回项目自造时间轴入口和正式口径。
2. 补齐 GAS 时间轴编辑器的场景保存守卫。
3. 把基础攻击迁入 EX-GAS `XParamTimeline`。
4. 让基础攻击命中由 `TaskApplyEffects + CatchAreaBox2D + GameplayEffect` 承担。
5. 再判断背刺和蓄力攻击需要新增哪些 GAS Task / XParam。

## Final Authoring Workflow

最终基础攻击制作流程目标：

1. 新建或选择 EX-GAS Ability 配置。
2. 绑定 AbilityLogic 和 Timeline。
3. 在 EX-GAS 时间轴中配置总帧数和轨道。
4. 添加 `TaskApplyEffects` clip。
5. 在该 clip 上配置 `CatchAreaBox2D` 的 offset、size、rotation、layer。
6. 在该 clip 上配置要应用的 `GameplayEffect`。
7. 添加 `TaskPlayCue` 或 GE Cue 配置表现。
8. 保存 GAS 时间轴数据。
9. 若 UI/输入层仍需要图标、显示名或槽位，只能引用 EX-GAS Ability Code，不得复制执行配置。

该流程不允许出现：

- 工作台
- 准备链路
- 修复接线
- 打开测试场景
- 手动摆场景碰撞体
- 第二份项目时间轴
- Excel 文件人工双写

## Legacy Compatibility Boundary

`AbilitySheet` / `ActiveAbilitySheet` / `PassiveAbilitySheet`（均已删除） 与 `AbilityExecutionAsset` / `MeleeAbilityExecutionAsset` 已删除，不再作为运行、作者或兼容入口。历史数据只能通过显式迁移数据落到 EX-GAS Code，或记录为待迁移缺口。

已迁移普攻不得再通过已删除的旧能力表、旧执行资产 Inspector、旧命中框字段或旧反馈字段制作；旧主动技能 API 已删除；不得把旧能力表对象推导或升级成 EX-GAS Ability Code。

## Editor Refactor Direction

正式编辑器基线：EX-GAS `AbilityTimelineEditorWindow`

必须补的项目缺口：

- 场景切换保存守卫：当前 `LoadPreviewScene()` / `BackToScene()` 会直接 `NewScene(Single)` / `OpenScene()`，必须先保存或阻止 dirty 正式场景被弹窗卡住。
- 2D 动画采样：需要让预览对象和动画片段在时间轴帧上可对齐。
- 2D 命中框可视化：优先复用 `CatchAreaBox2D.OnEditorPreview()`，必要时补更适合像素俯视角的可视化。
- 易用性差距：以 2DRPGEngine 的时间尺、轨道、clip 拖拽、缩放/平移、Inspector 联动作为验收参考。

可选优化候选，当前不进入主线完成口径：

- 复位视图：`AbilityTimelineEditorWindow` 提供“复位”按钮和 `Ctrl+0`，把时间轴缩放与横向滚动恢复到默认视图。
- 定位当前帧：`AbilityTimelineEditorWindow` 提供“定位”按钮和 `Home`，把视口滚动到当前选中帧附近。
- 鼠标锚点缩放：`TimerShaftView` 的滚轮缩放围绕鼠标所在帧保持视口锚点，避免长时间轴缩放时丢失关注位置。
- 可拖拽只读视野范围条：`TimerShaftView` 在时间尺顶部显示当前窗口相对整段 Timeline 的位置，拖拽时只修改编辑器 `ScrollView.scrollOffset`，不写技能数据。
- clip 拖拽/缩放边缘自动滚动：`TrackClipVisualElement` 在拖动 clip 主体或左右边界时，如果鼠标靠近轨道可视区边缘，只平移编辑器 `ScrollView.scrollOffset`，不提前写入 `TaskClipData`。

这些改造曾作为候选实现验证，但因会改变 GAS 插件原生时间轴窗口观感，已从当前工作区撤回并保留为可选 patch 证据；后续是否采用需要单独做 UI/体验评审。当前主线只承认：继续使用 EX-GAS 原生 `AbilityTimelineEditorWindow`，不创建第二时间轴，不修改技能作者数据真相。

明确删除/撤回：

- 项目自造 `MeleeAbilityTimelineWindow`
- Inspector 上“打开近战时间轴”入口
- 把静态 Inspector 说成正式时间轴作者流
- 项目侧旧执行资产自定义 Inspector，包括 `MeleeAbilityExecutionAssetEditor`、`DashAbilityExecutionAssetEditor`、`ProjectileAbilityExecutionAssetEditor`、`SummoningAbilityExecutionAssetEditor`

## Runtime Flow

### 1. Activate

- 玩家输入或 AI 决策解析到 EX-GAS Ability Code。
- EX-GAS 检查资源、冷却和标签。

### 2. Execute

- `ALTimelinePlayer` 读取 `XParamTimeline`。
- 按帧推进各 `TaskClipData`。

### 3. Hit Detection

- `TaskApplyEffects` 调用 `TargetCatcher`。
- 基础近战命中用 `CatchAreaBox2D`。

### 4. Resolve

- 命中后应用正式 `GameplayEffect`。
- 伤害、状态、属性变化都由 EX-GAS 处理。

### 5. Present

- `TaskPlayCue` 或 GE Cue 触发表现。
- 若复用 `GameplayFeedbackSet`，必须通过唯一 Cue/Task 转发。

## Concrete Asset Direction

基础攻击：

- 固定时间轴。
- 一个 `TaskApplyEffects` 命中 clip。
- 一个 `CatchAreaBox2D` 参数。
- 一个或多个 `GameplayEffect`。
- 可选 `GameplayCue`。

背刺：

- 仍是同一近战时间轴模型上的条件化附加效果。
- 具体条件缺口不得塞回项目第二壳；需要评估新增 GAS Task、TargetCatcher 或 Effect 条件组件。

蓄力攻击：

- 暂不实现正式模型；当前属于设计前提未锁定。
- 释放方式、结果形态、档位数、提前松手行为、蓄力期间控制和表现分组都会改变运行时状态机与资产模型。
- 后续应表达为时间轴上的蓄力段和释放段，而不是单独系统。
- 未确认上述前提前，不得把默认蓄力行为硬写进项目侧旧执行资产、GAS Task 或 Timeline 数据；当前项目侧旧执行资产类型已删除。

## Cleanup Verdict

以下内容属于错误方向：

- 项目自造第二时间轴
- 测试链路写进制作步骤
- 场景里的临时碰撞体摆放当技能配置
- 工作台 / 准备链路 / 修复接线
- Excel 文件和 Unity 时间轴双写同一数据

## Implementation Direction

下一步实现不是补多窗口到项目自造窗口，而是：

1. 清理项目自造时间轴残余引用。
2. 补 GAS 时间轴编辑器场景保存守卫。
3. 建立基础攻击到 GAS Timeline 的最小映射。
4. 保持现有基础攻击回归测试通过。
5. 背刺已落到 `FormalConditionalDamage`；蓄力需要先确认最小必要问题，再评估 GAS Task / Timeline 扩展点。
6. 继续在 EX-GAS 原生编辑器内补齐真实画面验收、2D 动画采样和命中盒编辑体验；时间轴导航/观感增强只作为可选优化候选，未经过体验评审不得并入主线；不得回到项目自造工作台。
