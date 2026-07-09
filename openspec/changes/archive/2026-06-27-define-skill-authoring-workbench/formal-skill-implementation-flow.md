# 正式技能实现流程

本文只定义 `define-skill-authoring-workbench` 当前已经成立的“单一路径”技能实现流程。它不把普通 Inspector、诊断入口、测试场景修补、工作台或截图桥冒充成正式编辑器。

## 1. 当前正式单一路径

当前技能实现必须收口到：

`AbilitySheet -> AbilityExecutionAsset -> 通用运行时壳 -> GAS 规则 -> GameplayFeedbackSet / GameplayCue 表现`

这五层的职责边界如下。

### 1.1 `AbilitySheet`

统一技能入口，回答“这是什么技能、如何被授予和显示”。

- 技能稳定 ID、名字、图标、描述
- 技能 prefab / 运行时壳引用
- `AbilityExecutionAsset` 正式引用
- 正式 GAS `AbilityAsset` 映射
- 通用成本、冷却、显示、目标入口、反馈入口

当前代码依据：

- `Assets/Scripts/GameCore/Runtime/Database/Abilities/AbilitySheet.cs`
- `Assets/Editor/GameCore/Editors/AbilitySheetEditor.cs`

### 1.2 `AbilityExecutionAsset`

统一执行真相，回答“这个技能在动画窗口、命中框、投射物、区域、召唤和触发链上怎么执行”。

- 近战：命中框尺寸、偏移、命中窗口、背刺附加效果
- 投射物：投射物 prefab、速度、数量、散射、爆炸参数
- 冲刺：强度、阻力
- 召唤：召唤对象、跟随与附加能力
- 自施法：执行时序与表现挂点

当前代码依据：

- `Assets/Scripts/GameCore/Runtime/Database/Abilities/Execution/AbilityExecutionAsset.cs`
- `MeleeAbilityExecutionAsset.cs`
- `ProjectileAbilityExecutionAsset.cs`
- `DashAbilityExecutionAsset.cs`
- `SummoningAbilityExecutionAsset.cs`
- `SelfCastAbilityExecutionAsset.cs`

### 1.3 通用运行时壳

运行时壳只消费 `AbilitySheet + AbilityExecutionAsset`，不把具体技能逻辑写死进角色 prefab、测试场景或临时菜单。

当前已正式接入的主动技能族：

- `MeleeAttackAbility`
- `ProjectileAbility`
- `DashAbility`
- `SummoningAbility`
- `SelfCastAbility`

当前代码依据：

- `Assets/Scripts/GameCore/Runtime/Combat/Abilities/Active/MeleeAttackAbility.cs`
- `ProjectileAbility.cs`
- `DashAbility.cs`
- `SummoningAbility.cs`
- `SelfCastAbility.cs`

### 1.4 GAS 规则层

GAS 负责正式规则结果，不负责项目侧动作命中扫描。

- 属性读取
- GameplayEffect 执行
- 成本 / 冷却 / 标签
- 持续状态与规则结算

当前基础攻击的正式规则转交入口：

- `FormalGameplayEffectImmediateEffect`
- `FormalInstantDamageExecution`

代码依据：

- `Assets/Scripts/GameCore/Runtime/Combat/Effects/Formal/FormalGameplayEffectImmediateEffect.cs`

### 1.5 表现层

项目侧表现反馈真相源仍是 `GameplayFeedbackSet`；`GameplayCue` 只做 GAS 侧表现触发，不拥有伤害、治疗、资源或位移结算。

## 2. 当前作者步骤

当前可以成立的正式制作步骤只有：

1. 新建一个 `AbilitySheet` 资产。
2. 选择匹配的技能族 prefab / 运行时壳。
3. 在 `AbilitySheet` 上填写技能身份信息与正式 GAS `AbilityAsset` 映射。
4. 通过 `AbilitySheetEditor` 创建并绑定对应的 `AbilityExecutionAsset`。
5. 在执行资产上填写该技能族的执行数据。
6. 在 `AbilitySheet.m_effects` 或正式 GAS 规则资产上绑定规则结果。
7. 通过现有运行时输入入口做 smoke 验证。

中间不应出现：

- 准备链路
- 修复接线
- 打开内部工作台
- 手动给角色 prefab 加测试技能
- 依赖测试场景保活器

## 3. 基础攻击当前怎么配置

当前基础攻击只是样例链路，不是正式技能内容。

样例资产现态：

- `Assets/GameData/GameCore/AbilitySamples/AbilitySheets/测试-基础攻击.asset`
- `Assets/GameData/GameCore/AbilitySamples/AbilityExecutions/测试-基础攻击-执行.asset`
- `Assets/GameData/GameCore/AbilitySamples/GameplayEffects/测试-基础攻击-伤害.asset`
- `Assets/GameData/GameCore/AbilitySamples/GameplayExecutions/测试-基础攻击-伤害Execution.asset`

这条样例链路的现实含义是：

1. `AbilitySheet` 声明“这是一个基础攻击技能”，并引用正式 `MeleeAbilityExecutionAsset`。
2. `MeleeAbilityExecutionAsset` 保存近战命中框、命中窗口、背刺附加效果等执行数据。
3. `MeleeAttackAbility` 在运行时按执行资产生成/维护命中盒并扫描命中目标。
4. 命中后由 `FormalGameplayEffectImmediateEffect` 把这次命中转交给 GAS `GameplayEffectAsset`。
5. `FormalInstantDamageExecution` 决定正式伤害结果。

## 4. 当前不是正式编辑器的东西

以下东西当前都不能宣称是“正式技能编辑器”：

- 普通 `AbilitySheet` Inspector
- 只读审计入口
- 命令行 smoke
- `ClickMoveTest` 测试场景
- 任何截图取证脚本

它们最多分别属于：

- 资产录入入口
- 审计入口
- 运行时验证入口
- 参考取证入口

## 5. 当前已完成与未完成

当前已经成立：

- 正式执行资产层已落地，并接入主要主动技能族
- `AbilitySheetEditor` 已能创建并绑定对应执行资产
- 运行时壳已对正式执行资产做门禁
- 正式审计入口 `FormalAbilityExecutionAudit` 已存在

当前仍未完成：

- 正式可视化判定框编辑器

## 6. 对后续阶段的约束

- 蓄力攻击、背刺进入下一小阶段前，仍要先过用户确认门禁。
- 火球、陨石、闪电链、追踪剑、吸血、抽魂等复杂技能，不得绕开这条单一路径另造运行时真相。
- 未来若引入时间轴面板或节点图，也只能是 `AbilityExecutionAsset` 的不同编辑面，不能变成第二套技能语义。
