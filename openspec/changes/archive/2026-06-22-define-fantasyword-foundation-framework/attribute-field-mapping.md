# 属性字段映射表

> 本表只回答一件事：`FantasyWord` 当前正式属性有哪些，它们的稳定 ID、当前真相、存档落点和 UI 读取源分别是什么。
> 这不是 GAS 运行时接入文档；它是替换前必须先锁定的单一映射面。

## 当前正式属性

> `2026-06-18` 当前已先后落 GAS 三刀，所以本表不再只登记旧 Stats 落点，也同步登记“当前正式读取真相”“当前值存档落点”和“正式 AttributeSet 字段名”。
> 当前正式读取口、资源写入口、属性通知、零血死亡判定和当前值存档都已优先切到 `CharacterBase + ASC`；旧 `AttributeBootstrapBuffer` 只剩旧属性缓冲、旧档导入缓冲、正式镜像回填，以及 `Awake` 期间一次性的 bootstrap 读取窗口。

| 稳定 ID | `EStat` | 显示名 | 当前基础真相 | 当前运行时真相 | 当前存档落点 | 当前 UI 读取源 | 当前正式 GAS 字段 | GAS 替换要求 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `core.health` | `Health` | 生命 | `ASC` 上的 `FormalGameplayAttributeSet.Health` 基础值；仅在 `Awake` bootstrap 窗口内允许回退 `AttributeBootstrapBuffer.GetBaseStat(EStat.Health)` | `ASC` 上的 `FormalGameplayAttributeSet.Health` 当前值；仅在 `Awake` bootstrap 窗口内允许回退 `AttributeBootstrapBuffer.GetCurrentStat(EStat.Health)` | `CharacterBaseDataBlock.currentStats[EStat.Health]`，由 `CharacterBase.OnSave() -> CreateCurrentStatsSnapshot()` 写回，并由 `OnLoad() -> ApplySavedCurrentStatsToOwnedAttributeTruth(...)` 恢复 | `CharacterBase.GetMaxHealth()/GetCurrentHealth()` | `FormalGameplayAttributeSet.Health` | 若替换，必须连同显示、结算和存档来源一起切换 |
| `core.mana` | `Mana` | 法力 | `ASC` 上的 `FormalGameplayAttributeSet.Mana` 基础值；仅在 `Awake` bootstrap 窗口内允许回退 `AttributeBootstrapBuffer.GetBaseStat(EStat.Mana)` | `ASC` 上的 `FormalGameplayAttributeSet.Mana` 当前值；仅在 `Awake` bootstrap 窗口内允许回退 `AttributeBootstrapBuffer.GetCurrentStat(EStat.Mana)` | `CharacterBaseDataBlock.currentStats[EStat.Mana]`，由 `CharacterBase.OnSave() -> CreateCurrentStatsSnapshot()` 写回，并由 `OnLoad() -> ApplySavedCurrentStatsToOwnedAttributeTruth(...)` 恢复 | `CharacterBase.GetMaxMana()/GetCurrentMana()` | `FormalGameplayAttributeSet.Mana` | 同上，不能一边 GAS 扣蓝、一边 `Stats` 存档 |
| `core.physical_attack` | `PhysicalAttack` | 物攻 | `ASC` 上的 `FormalGameplayAttributeSet.PhysicalAttack` 基础值；仅在 `Awake` bootstrap 窗口内允许回退 `AttributeBootstrapBuffer.GetBaseStat(EStat.PhysicalAttack)` | `ASC` 上的 `FormalGameplayAttributeSet.PhysicalAttack` 当前值；仅在 `Awake` bootstrap 窗口内允许回退 `AttributeBootstrapBuffer.GetCurrentStat(EStat.PhysicalAttack)` | `CharacterBaseDataBlock.currentStats[EStat.PhysicalAttack]`，由 `CharacterBase.OnSave() -> CreateCurrentStatsSnapshot()` 写回，并由 `OnLoad() -> ApplySavedCurrentStatsToOwnedAttributeTruth(...)` 恢复 | `GetStatValue(FormalAttributeDefinition)`、`GetCurrentStatValue(FormalAttributeDefinition)`、`CreateCombatStatSnapshot()` | `FormalGameplayAttributeSet.PhysicalAttack` | 若替换，装备/Buff/伤害结算必须一起迁 |
| `core.magical_attack` | `MagicalAttack` | 法攻 | `ASC` 上的 `FormalGameplayAttributeSet.MagicalAttack` 基础值；仅在 `Awake` bootstrap 窗口内允许回退 `AttributeBootstrapBuffer.GetBaseStat(EStat.MagicalAttack)` | `ASC` 上的 `FormalGameplayAttributeSet.MagicalAttack` 当前值；仅在 `Awake` bootstrap 窗口内允许回退 `AttributeBootstrapBuffer.GetCurrentStat(EStat.MagicalAttack)` | `CharacterBaseDataBlock.currentStats[EStat.MagicalAttack]`，由 `CharacterBase.OnSave() -> CreateCurrentStatsSnapshot()` 写回，并由 `OnLoad() -> ApplySavedCurrentStatsToOwnedAttributeTruth(...)` 恢复 | `GetStatValue(FormalAttributeDefinition)`、`GetCurrentStatValue(FormalAttributeDefinition)`、`CreateCombatStatSnapshot()` | `FormalGameplayAttributeSet.MagicalAttack` | 同上 |
| `core.physical_defense` | `PhysicalDefense` | 物防 | `ASC` 上的 `FormalGameplayAttributeSet.PhysicalDefense` 基础值；仅在 `Awake` bootstrap 窗口内允许回退 `AttributeBootstrapBuffer.GetBaseStat(EStat.PhysicalDefense)` | `ASC` 上的 `FormalGameplayAttributeSet.PhysicalDefense` 当前值；仅在 `Awake` bootstrap 窗口内允许回退 `AttributeBootstrapBuffer.GetCurrentStat(EStat.PhysicalDefense)` | `CharacterBaseDataBlock.currentStats[EStat.PhysicalDefense]`，由 `CharacterBase.OnSave() -> CreateCurrentStatsSnapshot()` 写回，并由 `OnLoad() -> ApplySavedCurrentStatsToOwnedAttributeTruth(...)` 恢复 | `GetStatValue(FormalAttributeDefinition)`、`GetCurrentStatValue(FormalAttributeDefinition)`、`CreateCombatStatSnapshot()` | `FormalGameplayAttributeSet.PhysicalDefense` | 同上 |
| `core.magical_defense` | `MagicalDefense` | 法防 | `ASC` 上的 `FormalGameplayAttributeSet.MagicalDefense` 基础值；仅在 `Awake` bootstrap 窗口内允许回退 `AttributeBootstrapBuffer.GetBaseStat(EStat.MagicalDefense)` | `ASC` 上的 `FormalGameplayAttributeSet.MagicalDefense` 当前值；仅在 `Awake` bootstrap 窗口内允许回退 `AttributeBootstrapBuffer.GetCurrentStat(EStat.MagicalDefense)` | `CharacterBaseDataBlock.currentStats[EStat.MagicalDefense]`，由 `CharacterBase.OnSave() -> CreateCurrentStatsSnapshot()` 写回，并由 `OnLoad() -> ApplySavedCurrentStatsToOwnedAttributeTruth(...)` 恢复 | `GetStatValue(FormalAttributeDefinition)`、`GetCurrentStatValue(FormalAttributeDefinition)`、`CreateCombatStatSnapshot()` | `FormalGameplayAttributeSet.MagicalDefense` | 同上 |
| `core.agility` | `Agility` | 敏捷 | `ASC` 上的 `FormalGameplayAttributeSet.Agility` 基础值；仅在 `Awake` bootstrap 窗口内允许回退 `AttributeBootstrapBuffer.GetBaseStat(EStat.Agility)` | `ASC` 上的 `FormalGameplayAttributeSet.Agility` 当前值；仅在 `Awake` bootstrap 窗口内允许回退 `AttributeBootstrapBuffer.GetCurrentStat(EStat.Agility)` | `CharacterBaseDataBlock.currentStats[EStat.Agility]`，由 `CharacterBase.OnSave() -> CreateCurrentStatsSnapshot()` 写回，并由 `OnLoad() -> ApplySavedCurrentStatsToOwnedAttributeTruth(...)` 恢复 | `GetStatValue(FormalAttributeDefinition)`、`GetCurrentStatValue(FormalAttributeDefinition)`、`CreateCombatStatSnapshot()` | `FormalGameplayAttributeSet.Agility` | 同上 |
| `core.luck` | `Luck` | 幸运 | `ASC` 上的 `FormalGameplayAttributeSet.Luck` 基础值；仅在 `Awake` bootstrap 窗口内允许回退 `AttributeBootstrapBuffer.GetBaseStat(EStat.Luck)` | `ASC` 上的 `FormalGameplayAttributeSet.Luck` 当前值；仅在 `Awake` bootstrap 窗口内允许回退 `AttributeBootstrapBuffer.GetCurrentStat(EStat.Luck)` | `CharacterBaseDataBlock.currentStats[EStat.Luck]`，由 `CharacterBase.OnSave() -> CreateCurrentStatsSnapshot()` 写回，并由 `OnLoad() -> ApplySavedCurrentStatsToOwnedAttributeTruth(...)` 恢复 | `GetStatValue(FormalAttributeDefinition)`、`GetCurrentStatValue(FormalAttributeDefinition)`、`CreateCombatStatSnapshot()` | `FormalGameplayAttributeSet.Luck` | 同上 |

## 当前代码真相入口

- 正式属性目录：`Assets/Scripts/GameCore/Runtime/Combat/FormalAttributeCatalog.cs`
- 第一刀正式 AttributeSet：`Assets/Scripts/GameCore/Runtime/Combat/FormalGameplayAttributeSet.cs`，`SetName = AS_FantasyWordCore`
- 第一刀实体级 GAS 挂点：`Assets/Scripts/GameCore/Runtime/Entities/Characters/CharacterBase.GASRuntime.cs`
- 正式数组长度来源：`Stats.StatCount => FormalAttributeCatalog.Count`
- 编辑器属性绘制：`Assets/Editor/GameCore/PropertyDrawers/StatsPropertyDrawer.cs`
- 怪物属性预览：`Assets/Editor/GameCore/Editors/MonsterSheetEditor.cs`

## 约束

- 新增正式属性时，必须先改 `FormalAttributeCatalog`，再改 `EStat`、`Stats`、存档、UI 和矩阵。
- 不允许只改 `EStat` 或只加一列 `Stats` 数组就算完成。
- GAS 若胜出，必须继续维护这份稳定 ID，不得让调用方改成直接猜 `AttributeSet` 字段名。
