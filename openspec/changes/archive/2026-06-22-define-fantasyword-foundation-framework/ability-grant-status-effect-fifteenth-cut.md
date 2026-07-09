# Ability Grant Status Effect Fifteenth Cut

## Scope

本次第十五刀把“状态效果授予能力”从第十四刀的角色 API 推进到可被效果系统直接使用的正式持续效果类型。目标仍不是实现变形、感染或丧尸化业务模型，而是先让普通 buff/debuff 能在持续期间授予能力，并在结束或读档恢复时按同一来源精确回滚。

## Implemented Shape

- 新增 `TemporalAbilityGrantEffect`：
  - `OnApply()` 调用 `CharacterBase.AddStatusEffectAbility(...)`，按当前 effect runtimeKey 建立 `StatusEffect` 来源。
  - `OnRuntimeStateRestored()` 在读档恢复持续效果时重建能力授予。
  - `OnCompleted()` 调用 `RemoveAllStatusEffectAbilities(...)`，一次性撤回该状态来源授予的所有能力。
  - `TryCapturePersistedState(...)` 保存被授予能力的数据库引用。
  - `RestorePersistedState(...)` 从数据库引用恢复 `AbilitySheet[]`。
- 该效果仍只通过 `CharacterBase` 正式能力来源桶工作，不直接改 GAS `AbilityContainer`，也不直接操作旧 `bonusAbilities` 汇总。
- `Invoke-FoundationStaticGate.ps1` 已将该文件列为必备文件，并检查应用、恢复、完成回滚和数据库引用保存/恢复合同。
- `FormalGasAssetTemplateBootstrap` 已同步补 `正式持续效果模板-能力授予.asset`，并把 `TemporalAbilityGrantEffect` 写入正式能力表模板，避免 formal GAS 映射审计把新增效果判定为未覆盖类型。

## Runtime Meaning

这让以下玩家故事可以走正式链路：

- 临时祝福给角色一个主动能力，祝福结束后只移除祝福给的那一份能力。
- 药剂或诅咒临时让角色获得/失去一种可执行动作，读档后仍能恢复这份临时来源。
- 多个来源授予同一个能力时，状态结束不会误删装备、物品学习、召唤或永久成长授予的同名能力。

## Still Not Implemented

这刀仍不实现以下内容：

- 变形/感染/丧尸化的完整规则资产。
- 状态效果禁用既有能力已由第十六刀 `TemporalAbilitySuppressionEffect` 建立来源化压制合同；但完整变形/感染业务规则和具体内容资产仍未实现。
- 形态变化导致装备禁用、掉落、隐藏或继续生效。
- 背包锁定、掉落、转移、尸体容器化。
- 阵营、AI、控制权、交互权限和命令权限变化。
- 保存/加载端到端 smoke 中实际构造一个带 `TemporalAbilityGrantEffect` 的资产并验证回滚。

## Verification

- `Invoke-FoundationStaticGate.ps1 -AsJson`：通过，`TemporalAbilityGrantEffectMissingPatternCount = 0`，`FormalGasTemplateBootstrapMissingPatternCount = 0`，`FormalGasTemplateAssetMissingPatternCount = 0`。
- `Invoke-FormalGasTemplateBootstrap.ps1 -AsJson`：通过，`CompilationFailed = false`。
- `Invoke-FormalGasMappingAudit.ps1 -AsJson`：第十五刀当轮通过，`HasMissingMappings = false`，`HasCoverageGaps = false`，`TemporalEffectReferenceCount = 7`，`TemporalEffectMappedCount = 7`；第十六刀后正式模板已扩展为 `8 / 8`，见 `ability-suppression-sixteenth-cut.md`。
- `npx openspec validate define-fantasyword-foundation-framework --strict`：通过。
- AIBridge `assets-refresh` 成功；Editor 当前不是播放态、不是编译态；最近 10 分钟 Error/Exception 为空。
