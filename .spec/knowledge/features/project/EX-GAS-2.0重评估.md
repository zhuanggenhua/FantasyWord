---
name: EX-GAS-2.0重评估
description: 项目知识：EX-GAS-2.0重评估.md：EX-GAS-2.0重评估。
metadata:
  type: doc
  status: 已交付
---

# EX-GAS 2.0 重评估

> 本文回答当前仓库里的真实问题：项目已经引入本地 `EX-GAS 2.0.0` 后，技能正式链该如何收口，哪些旧判断已经失效。

## 当前项目现态

- Unity：`6000.3.10f1`
- 渲染管线：`URP 17.3.0`
- 输入：`Input System 1.18.0`
- 当前本地 EX-GAS 包版本：`2.0.0`
  - 证据：`Assets/Plugins/GAS/package.json`
- 当前项目已接入 `com.unity.entities`
  - 证据：`Packages/manifest.json`
- 当前项目已接入 `com.unity.collections / com.unity.burst / com.unity.mathematics`
  - 证据：`Packages/packages-lock.json`

## 已确认事实

- 当前仓库里的 GAS 已经不是旧 `1.x`。
- 当前 GAS 本体明确带有：
  - `AbilityConfig`
  - `GameplayCueConfig`
  - `TimelineAbility`
  - `Unity.Entities`
  - `Luban` 相关生成链
- 因此任何仍把当前项目描述成“还停在旧 EX-GAS 1.1.8 判断前提”的文档，都是过时真相。

## 当前与上游对齐状态

- 当前本地 `Assets/Plugins/GAS` 已按官方 `No78Vino/gameplay-ability-system-for-unity` 的 `EX-GAS-2.0` 分支对齐。
- 当前本地 `Assets/Plugins/Sirenix` 已补回上游随包携带的正式依赖闭包；不再使用项目侧伪 `Odin` 占位脚本替代正式依赖。
- 当前 `GAS` 装配定义已从悬空 GUID 依赖改为当前项目真实存在的正式程序集名依赖：
  - `com.exhard.exgas.runtime`
    - `Unity.Burst`
    - `Unity.Collections`
    - `Unity.Entities`
    - `Unity.Mathematics`
    - `Sirenix.OdinInspector.Modules.UnityMathematics`
  - `com.exhard.exgas.editor`
    - `com.exhard.exgas.runtime`
    - `Unity.Entities`
    - `Sirenix.OdinInspector.Modules.UnityMathematics`
- 当前保留的项目侧差异不是第二套功能，而是少量稳定性补丁：
  - `Runtime/General/GASManager.cs`
  - `Runtime/General/Helper/EntityHelper.cs`
  - `Runtime/Ability/AbilitySpec.cs`
  - `Runtime/Effect/GameplayEffectSpec.cs`
  - `Editor/GASPlayModeLifecycle.cs`
- 这些补丁只处理 Unity Editor 反复进出 PlayMode、World 已销毁后静态状态残留、以及 `IsValid` 在 World 已失效时仍访问 `EntityManager` 的稳定性问题。
- 除这些补丁外，不再保留“本地私有 EX-GAS 分叉能力”叙事。
- 先前本地对 `com.exhard.exgas.editor.asmdef` 追加的 `EX_GAS_ENABLE_EDITOR` 隐藏开关已撤回，当前 EX-GAS 官方编辑器装配回到上游默认开启状态。
- 先前项目里那份 `Assets/Plugins/GAS/General/Sirenix/OdinInspectorStubs.cs` 伪兼容层已删除；后续若再遇到 EX-GAS / Odin 编译问题，只允许补正式依赖或直接对齐参考，不允许再次引入假属性、假 Editor 基类或其它伪装配层。

## 当前真正要回答的问题

不是“要不要从 1.x 升到 2.0”，而是：

1. 当前项目已经有 EX-GAS 2.0，本地正式规则层是否继续由它承担。
2. 项目侧 `AbilitySheet / AbilityExecutionAsset` 是否还能承担技能正式职责。
3. `GameplayCue`、时间轴、旧项目侧兼容壳分别放在哪一层最稳。

## 当前结论

### 1. 规则层继续收口到 EX-GAS 2.0

- 资源、冷却、标签、属性变化、持续状态、授予/移除能力这类规则结果，继续以 EX-GAS 为正式真相。
- 这比把同职责逻辑继续散落在项目侧 `IEffect` 残留里更稳。

### 2. 正式技能不再保留 `已删除的 AbilitySheet -> AbilityExecutionAsset` 正式链

- 对正式技能，技能身份、输入、消耗、冷却、规则、时间轴、命中、伤害和表现必须回到 EX-GAS Ability / Timeline / GameplayEffect / Cue。
- `AbilitySheet` 只保留旧资产兼容标记和旧存档/旧数据升级线索。
- `AbilityExecutionAsset` 已删除，不再保留旧技能执行资产兼容层，也不得承载普攻的动作时序、命中窗口、命中框、伤害或表现真相。

### 3. `GameplayCue` 仍不是项目侧第二套反馈系统

- EX-GAS `GameplayCue` 可以继续作为规则触发表现的入口。
- 但项目侧反馈真相仍收口到 `GameplayFeedbackSet` 或其唯一正式替代者。
- 不把 `GameplayCue` 扩成第二套表现主模型，也不让它承担玩法结算。

### 4. 当前不再使用旧 `FormalInstantDamageExecution` 叙事

- 活跃代码、资产和自动化正式入口已经不再围绕 `FormalInstantDamageExecution` 组织。
- 当前技能正式链更接近：
  - EX-GAS Ability
  - EX-GAS Timeline
  - EX-GAS GameplayEffect
  - EX-GAS GameplayCue / 项目 Cue 桥
  - 项目侧运行配置和必要的 2D 扩展点
- 因此后续评估、实现和文档都不再把 `FormalInstantDamageExecution` 当作当前主线前提。

## 当前仍未完成的点

- 当前基础攻击的正式伤害已经收口到 `GameplayEffect -> FormalDamage / FormalConditionalDamage` 这条链；项目侧 `MeleeAbilityExecutionAsset`（已删除） 不再是基础攻击正式执行壳。
- 当前 2D 目标捕获通过项目侧 `CatchAreaBox2D` 扩展接入 EX-GAS TargetCatcher；可视化作者体验仍未完全闭合。
- 当前复杂法术执行面、时间轴作者面和玩家可配置配方层还未完成正式裁决。

## 当前实施口径

- 正式技能继续沿 `EX-GAS Ability -> Timeline -> GameplayEffect -> Cue -> 项目必要扩展点` 这条单一路径重构。
- 不回退到旧 `FormalGasMappingAudit / Bootstrap` 思路。
- 不再把当前问题表述成“先决定要不要升级到 EX-GAS 2.0”。
- 当前项目处于起步期；同职责旧规则残留若与 EX-GAS 正式链冲突，默认允许直接替换，不为历史包袱保留长期兼容层。
- 当前生命/法力资源变化按 `0071-正式 GAS 资源 Modifier 与伤害 owner` 收口：`Health` / `Mana` 是当前资源属性，`MaxHealth` / `MaxMana` 是上限属性；伤害、治疗、回蓝和耗蓝统一通过 `FormalGameplayEffectResourceModifier` 进入 EX-GAS Modifier 链，项目侧禁止直接写 `CAttributeData.CurrentValue`。
- 游戏尚未发布，旧存档兼容不作为 GAS 属性架构约束；后续若拆分 `当前资源 / 上限资源` 双属性，直接重写或迁移存档结构。
- EX-GAS 2.0 的可视化编辑器与 Excel/Luban 工作流是当前正式技能的正式作者数据来源；项目侧只能补运行配置、资源桥和必要扩展点。
- 当前真正要做的是：在已经存在的 EX-GAS 2.0 前提下，把项目侧旧能力作者流和执行流从正式技能里清干净。
