# 提案完成性审计

本文只审计 `define-skill-authoring-workbench` 当前是否已经满足“彻底完成提案”。它不替代 `tasks.md`，而是把“已完成、未完成、证据强度、外部阻塞”逐项写清。

## 1. 审计口径

完成标准必须同时满足三类要求：

1. `proposal / design / spec / tasks / open-questions` 这些提案工件已经闭环。
2. 提案要求的正式实现地基已经真实落到当前工程，而不是只停留在文档口径。
3. 提案中仍保留为验收前提的参考项，也必须有足够强的现实证据；如果没有证据，只能算未完成，不能靠“理论上应该没问题”过关。

## 2. 已完成项

### 2.1 提案工件闭环

状态：已完成

证据：

- `proposal.md`
- `design.md`
- `open-questions.md`
- `tasks.md`
- `specs/skill-authoring-workbench/spec.md`
- `mainstream-skill-editor-verdict.md`
- `ability-system-reference-verdict.md`
- `2drpg-skill-parity-matrix.md`
- `next-stage-decision-gates.md`
- `formal-skill-implementation-flow.md`

### 2.2 OpenSpec 严格校验

状态：已完成

证据：

- `npx openspec validate define-skill-authoring-workbench --strict`
- 当前结果：`Change 'define-skill-authoring-workbench' is valid`

### 2.3 旧错误作者流撤回

状态：已完成

证据：

- `tasks.md` 第 2、3 节已明确记录撤回
- 当前仓库残留扫描未再发现项目代码/资产中的 `BasicAttackAuthoringWorkbench`、`AbilityComparisonWorkbench`、`BasicAttackTestSceneRuntimeBootstrap` 正式入口
- `.spec/knowledge/features/project/编辑器工具与验证入口.md` 已与当前 change 口径一致

说明：

- `openspec/changes/archive/` 中的历史变更仍可能提到旧名词；那是历史证据，不是当前正式入口。

### 2.4 正式技能单一路径已收口到工程

状态：已完成

证据：

- 统一技能入口：
  - `Assets/Scripts/GameCore/Runtime/Database/Abilities/AbilitySheet.cs`
- 统一执行资产：
  - `Assets/Scripts/GameCore/Runtime/Database/Abilities/Execution/AbilityExecutionAsset.cs`
  - `MeleeAbilityExecutionAsset.cs`
  - `ProjectileAbilityExecutionAsset.cs`
  - `DashAbilityExecutionAsset.cs`
  - `SummoningAbilityExecutionAsset.cs`
  - `SelfCastAbilityExecutionAsset.cs`
- 通用运行时壳：
  - `Assets/Scripts/GameCore/Runtime/Combat/Abilities/Active/MeleeAttackAbility.cs`
  - `ProjectileAbility.cs`
  - `DashAbility.cs`
  - `SummoningAbility.cs`
  - `SelfCastAbility.cs`
- 正式编辑期绑定入口：
  - `Assets/Editor/GameCore/Editors/AbilitySheetEditor.cs`
- 正式技能流程文档：
  - `formal-skill-implementation-flow.md`

### 2.5 主要主动技能族已纳入正式执行资产体系

状态：已完成

证据：

- 近战、投射物、冲刺、召唤、自施法均已有对应执行资产类型
- 对应 Inspector 已存在：
  - `MeleeAbilityExecutionAssetEditor.cs`
  - `ProjectileAbilityExecutionAssetEditor.cs`
  - `DashAbilityExecutionAssetEditor.cs`
  - `SummoningAbilityExecutionAssetEditor.cs`
  - `SelfCastAbilityExecutionAssetEditor.cs`

### 2.6 基础攻击规则结算已收口到 GAS 正式执行入口

状态：已完成

证据：

- `Assets/Scripts/GameCore/Runtime/Combat/Effects/Formal/FormalGameplayEffectImmediateEffect.cs`
- `basic-attack-effect-migration-ledger.md`

结论：

- 当前基础攻击不再走 Cue 扣血口径。

### 2.7 Unity Bridge 基本读取证链路已恢复

状态：已完成

证据：

- `editor-application-get-state` 返回 `isCompiling=false`
- `scene-list-opened` 返回当前唯一打开场景为 `Assets/Scenes/ClickMoveTest.unity`
- 当前该场景 `isDirty=false`

## 3. 当前不再构成阻塞的旧项

### 3.1 `ClickMoveTest` 新一轮 PlayMode smoke

状态：已完成

证据：

- 已按用户授权口径直接丢弃 Unity 内存脏状态，并从磁盘重开 `Assets/Scenes/ClickMoveTest.unity`
- 当前 `scene-list-opened` 返回 `isDirty=false`
- `scripts/Invoke-CompositeRuntimeSmoke.ps1` 已真实执行通过
- 结果文件：`Temp/UnityBridge/results/composite-runtime-smoke.json`
- 结果摘要：`控制组 / RTS 订单链 / GAS formal 恢复 smoke 通过。`

### 3.2 `2DRPGEngine` 真实 Unity 窗口截图

状态：已退出本 change 验收范围

原因：

- 用户已明确澄清：当前不是要照搬 `2DRPGEngine` 流程，也没有要求改技能编辑器 UI；只要直接使用时闭环一致即可。
- 因此，`2DRPGEngine` 在本 change 中只保留为源码级技能族和职责边界参考，不再承担截图对比职责。

### 3.3 `FantasyWord` 与 `2DRPGEngine` 的真实流程截图对比

状态：已退出本 change 验收范围

原因：

- 用户已明确否定“真实内页截图 + 流程对比”作为当前完成前置。
- 当前 change 只需要基于源码参考和正式实现边界判断是否收口正确，不再要求流程 UI 对齐。

## 4. 结论

当前 change 已经完成了：

- 提案与规格闭环
- 正式实现地基落代码
- 单一路径流程收口
- 错误作者流撤回
- 基本 Unity 读取证恢复
- `ClickMoveTest` 新一轮 PlayMode smoke 真实通过

当前 change 不再被 `2DRPGEngine` 截图或流程对比阻塞。

当前仍需审计的一点不是“参考截图”，而是：

1. `tasks.md` 里剩余的“用户后续待确认数据模型问题”是否属于本 change 的未完成项，还是属于下一阶段决策门。

该项现已审计完成：

- 这些问题属于下一阶段内容实现前的决策门。
- 当前 change 的职责是把这些问题明确列出、写明影响边界，并据此约束当前实现不要越界。
- 它不要求用户在本 change 内把所有后续阶段数据模型全部拍板。

## 5. 当前最小下一步

如果要继续把本提案推到真正可归档，下一步应做的是：

1. 以当前 `tasks.md`、`completion-audit.md` 和 `formal-skill-implementation-flow.md` 作为归档前证据。
2. 进入下一阶段时，仅围绕下一小阶段真正会改变结构的数据模型问题继续提问和落实现。
