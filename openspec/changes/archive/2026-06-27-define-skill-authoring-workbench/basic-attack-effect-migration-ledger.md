# 基础攻击效果迁移台账

本台账只记录当前基础攻击样例链路的效果真相和迁移路径，不定义正式技能数值，也不再把任何旧作者流入口写成正式前提。

## 当前状态

| 项 | 当前真相 | 证据 | 结论 |
| --- | --- | --- | --- |
| 命中目标 | `MeleeAttackAbility` 通过能力实例下的 `BoxCollider2D` 做 `Physics2D.OverlapCollider` | `MeleeAttackAbility.ApplyHit()` | 动作执行真相在 GameCore / TopDown 风格闭包 |
| 命中窗口 | `MeleeAttackAbilitySheet.m_hitWindow` + `WeaponHitWindowRuntime` | `测试-基础攻击.asset` 的 `m_hitWindow` | 当前样例只维护一份近战时序与命中窗口数据 |
| 伤害效果 | `AbilitySheet.m_effects` 内的 `FormalGameplayEffectImmediateEffect` 指向 `测试-基础攻击-伤害.asset` | `测试-基础攻击.asset` 与对应 `GameplayEffectAsset / Execution` | 命中后由动作闭包交给 GAS-backed 规则入口 |
| GAS 时间轴效果 | `测试-基础攻击` 的 `ReleaseGameplayEffect: []` | `Assets/GameData/GameCore/AbilitySamples/AbilityAssets/测试-基础攻击.asset` | 当前 GAS 时间轴不负责命中结算 |
| GAS 规则接入 | `AbilitySheet.m_formalAbilityAsset` 指向 `TimelineAbilityAsset` | `AbilitySheet.formalAbilityAsset` | 当前 GAS 参与规则/时间轴可视化/生命周期代理，不是命中执行真相 |

## 迁移目标

正式融合后的目标不是把基础攻击改成纯 EX-GAS，也不是永久保留 `IEffect` 伤害。目标是：

- 动作执行仍由 GameCore / TopDown 风格闭包负责：输入缓冲、前摇/后摇、命中窗口、碰撞盒、背刺方向、击退和表现反馈。
- 规则效果逐步由 GAS-backed 规则承接：基础伤害、属性读取、成本、冷却、标签和持续状态不再长期散落在 `IEffect`。
- 同一次基础攻击只能结算一次：要么当前阶段继续由迁移期 smoke 入口扣血，要么重构后由正式 GAS/规则执行入口扣血，不能两边同时扣。
- EX-GAS `GameplayCue` 只应作为表现提示入口，不应负责伤害、治疗、资源、状态、位移或存档结算。

## 当前阻断门禁

当前需要保留的门禁只有这两条：

- 如果基础攻击 `AbilitySheet` 同时配置 GameCore 命中效果和 GAS `ReleaseGameplayEffect` 命中效果，必须报错或阻断，防止双重结算。
- 如果只配置了 GAS `ReleaseGameplayEffect`，但当前 `MeleeAttackAbility` 尚未把目标快照交给 GAS 正式命中流程，也必须报错，防止误以为 GAS 命中已经接通。

这些门禁属于正式静态校验需求，不再依赖旧 `BasicAttackAuthoringWorkbench` 或任何人类可点击修补入口。

## 已新增最小 GAS-backed 规则入口

当前已新增运行时代码入口，并正式 `测试-基础攻击.asset`：

- `FormalInstantDamageExecution`：挂在 `GameplayEffectAsset.Executions` 上，由 GAS 瞬时效果调用；真正扣血仍走 `CharacterBase.Damage(...)`，不绕过受击动画、击退、无敌帧、死亡和表现反馈，也不让 Cue 承担规则结算。
- `FormalGameplayEffectImmediateEffect`：作为 GameCore 命中后的迁移期执行壳，只负责把一次命中目标转交给指定 `GameplayEffectAsset`；目标快照仍由 `MeleeAttackAbility` 负责。
- 该执行壳禁止同一个 `GameplayEffectAsset` 同时配置 Instant Attribute Modifier 和 `FormalInstantDamageExecution`，避免 modifier 改生命、Execution 又调用 `Damage(...)` 造成双重结算。

## 迁移步骤状态

1. 已为基础攻击创建测试用 `GameplayEffectAsset` 和 `FormalInstantDamageExecution`，表达当前测试伤害语义；这些资产仍明确标记为测试样例，不是正式技能内容。
2. 正式 `测试-基础攻击.asset`：用 `FormalGameplayEffectImmediateEffect` 引用测试 `GameplayEffectAsset`，旧 `ImmediateDamageEffect` 已清掉。
3. 已把伤害执行从 `FormalInstantDamageCue` 模式收口到 `GameplayEffectAsset.Executions -> FormalInstantDamageExecution`。
4. `ClickMoveTest` / composite PlayMode smoke 已重新补跑通过，证明当前正式现态下的场景、控制组、RTS 订单链与 GAS formal 恢复链路没有被本轮重构打断；但它不是“基础攻击命中训练假人扣血”专项验证。

## 明确不做

- 不把当前 `flatDamages: 4` 当作正式基础攻击数值。
- 不为了迁移效果就定义正式职业、技能树、资源池或技能栏 UI。
- 不直接启用 GAS `ReleaseGameplayEffect` 轨道来扫目标，除非先决定 GAS 时间轴接管命中目标真相；当前裁决仍是动作闭包负责目标快照。
- 不复制旧 `FormalInstantDamageCue` 扣血模式到蓄力攻击、背刺、火球、陨石或其它后续技能。
