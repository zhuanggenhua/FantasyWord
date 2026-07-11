# Ability Suppression Sixteenth Cut

## Scope

本次第十六刀只建立“来源化能力压制/禁用”合同，用来支撑变形、感染、丧尸化、沉默、诅咒等临时规则在持续期间禁用能力，并在来源结束时精确恢复。它不是完整变形/感染/丧尸化业务模型，也不裁决装备、背包、控制权、AI 或阵营变化。

## Implemented Shape

- `CharacterBase` 新增来源化能力压制 API：
  - `AddStatusEffectAbilitySuppression(...) / RemoveAllStatusEffectAbilitySuppressions(...)`
  - `AddTransformationAbilitySuppression(...) / RemoveAllTransformationAbilitySuppressions(...)`
  - `AddInfectionAbilitySuppression(...) / RemoveAllInfectionAbilitySuppressions(...)`
- `CharacterAbilitySetRuntime` 新增 `m_suppressedAbilitySources`，按 `AbilitySheet + CharacterAbilitySourceKey` 保存压制层数。
- `CharacterBaseDataBlock` 新增 `abilitySuppressions`，保存/读档恢复时与能力来源一样使用数据库引用、来源类型、来源 id 和层数。
- 新增 `TemporalAbilitySuppressionEffect`：
  - 应用和读档恢复时按 `StatusEffect` 来源压制能力。
  - 完成时只移除该状态效果来源的压制层。
  - 持久化保存被压制 `AbilitySheet` 的数据库引用。
- `FormalGasAssetTemplateBootstrap` 已创建 `正式持续效果模板-能力压制.asset`，并把 `TemporalAbilitySuppressionEffect` 写入正式能力表模板第 8 个持续效果位。

## Runtime Meaning

- 压制不作为正式入口保留能力实例，也不作为正式入口保留能力来源；它只在运行时把能力暂时变成不可用。
- 主动能力通过 `ActiveAbilityBase.PermitAbility(false)` 进入不可触发状态，并在压制开始时打断当前动作。
- 被动能力通过禁用能力 GameObject 停止 Unity `Update/FixedUpdate`。
- 多个来源同时压制同一个能力时，移除其中一个来源不会误恢复；只有最后一个压制来源撤回后，能力才回到默认激活状态。
- 如果压制来源先于能力实例存在，后续创建能力实例时也会立即应用压制状态。

## Still Not Implemented

- 完整变形/感染/丧尸化规则资产。
- 形态变化导致装备禁用、隐藏、掉落、继续生效或背包锁定的裁决。
- 控制权、AI、阵营、交互权限和命令权限变化。
- 变形/感染的稳定业务 id、叠层优先级和 UI 提示。
- 保存/加载端到端 smoke 中实际构造一个带 `TemporalAbilitySuppressionEffect` 的资产并验证恢复。

## Verification

- `Invoke-FoundationStaticGate.ps1 -AsJson`：通过，`TemporalAbilitySuppressionEffectMissingPatternCount = 0`，`FormalGasTemplateBootstrapMissingPatternCount = 0`，`FormalGasTemplateAssetMissingPatternCount = 0`，`CharacterBaseAbilitiesMissingPatternCount = 0`，`CharacterBaseAbilitySetRuntimeMissingPatternCount = 0`，`CharacterBasePersistenceMissingPatternCount = 0`。
- `Invoke-FormalGasTemplateBootstrap.ps1 -AsJson`：通过，`CompilationFailed = false`。
- `Invoke-FormalGasMappingAudit.ps1 -AsJson`：通过，`HasMissingMappings = false`，`HasCoverageGaps = false`，`TemporalEffectReferenceCount = 8`，`TemporalEffectMappedCount = 8`。
- `npx openspec validate define-fantasyword-foundation-framework --strict`：通过。
- AIBridge `assets-refresh` 成功；Editor 当前不是播放态、不是编译态、不是导入态；最近 10 分钟 Error/Exception 为空。
