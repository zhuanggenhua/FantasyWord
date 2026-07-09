# AbilitySheet 执行资产编辑器缓存不同步排查记录

## 症状

- 历史上，`FormalAbilityAssetValidation.InspectAllAbilitySheets()` 偶发报告旧 `AbilitySheet` 测试资产未绑定 `已删除的 AbilitySheet.executionAsset`。
- 当时同一资产的 YAML 与 `SerializedObject.FindProperty("m_executionAsset")` 都能看到执行资产引用。
- 直接调用 `AbilitySheet.TryGetExecutionAsset(...)` 时，运行时字段却返回空，导致审计误判。
- 当前 `测试-变形替换能力.asset` 已删除；变形替换 smoke 的正式身份只保留在 EX-GAS Ability `20002` / `exgas.abilityGameCore` / Timeline `102`，不得再把该旧资产当成当前排查对象。

## 误判风险

- 不能把资产 YAML 里的引用删掉重配当成根因修复；磁盘序列化真相本身没有丢。
- 不能反复用一次性脚本手动重绑同一资产；这只会掩盖 Editor 内存对象字段与序列化视图不同步的问题。
- 不能让 EditMode 测试继续反射修改真实技能资产对象，再依赖 TearDown 恢复；这会扩大资产内存污染面。

## 真实根因

- 已锁定的证据是：同一 `AbilitySheet` 在 Editor 内存对象上 `m_executionAsset` 为空，但 `SerializedObject` 读取到的 `m_executionAsset` 非空。
- 这说明当轮失败不是磁盘资产缺引用，而是 Editor 内存对象字段状态与序列化视图不同步。
- `MeleeAttackAbilityEditModeTests` 过去为了改攻击节奏、消耗和冷却，曾通过反射临时覆盖真实 `AbilitySheet.m_executionAsset`，属于容易污染持久资产对象缓存的测试写法。

## 修复点

- `Assets/Scripts/GameCore/Runtime/Database/Abilities/AbilitySheet.cs`
  - `executionAsset` 与 `TryGetExecutionAsset(...)` 统一走 `ResolveExecutionAsset()`。
  - 在 `UNITY_EDITOR` 下，如果运行时字段为空，会从 `SerializedObject` 的 `m_executionAsset` 回读一次并回填字段。
  - Player 构建不引入 `UnityEditor` 依赖。
- `Assets/Editor/GameCore/Tests/MeleeAttackAbilityEditModeTests.cs`
  - 需要改 execution/cost/cooldown 的用例不再反射写真实基础攻击资产。
  - 测试改为克隆 `MeleeAttackAbilitySheet` 和 `MeleeAbilityExecutionAsset`（已删除）。
  - 测试克隆会注册进克隆版 `DatabaseRegistry`，保证 EX-GAS 正式能力键仍可解析。

## 必查项

- 先看 `SerializedObject.FindProperty("m_executionAsset")` 是否能读到对象引用，再判断是不是磁盘资产真丢引用。
- 搜索测试里是否还存在对真实 `AbilitySheet.m_executionAsset` 的反射覆盖。
- 测试若需要临时技能资产，必须用运行时 clone，并只注册到测试克隆的 `DatabaseRegistry`。
- 不得为了审计通过，把正式验证器改成忽略缺引用错误；真正缺引用仍然是错误。

## 验收口径

- `FormalAbilityAssetValidation.InspectAllAbilitySheets()` 必须返回 `Success = true` 且 `Issues = []`。
- `MeleeAttackAbilityEditModeTests` 必须通过，证明测试克隆仍能跑通 EX-GAS 规则键、消耗、冷却与命中链。
- 旧 `AbilitySheet` 资产不得残留 `m_formalGasAbilityCode`；已迁移或已用 EX-GAS 表表达的能力不能再保留同职责旧表资产入口。
- 当前正式场景不能因为验证残留 dirty。

## 验证记录

- `python .codex/skills/aibridge/bridge.py script-execute '{"csharpCode":"public class Script { public static object Main() { return FantasyWord.GameCore.FormalAbilityAssetValidation.InspectAllAbilitySheets(); } }","bridgeSceneDirtyPolicy":"discard-generated"}'`：Passed，`Success = true`，`Issues = []`。
- `python .codex/skills/aibridge/bridge.py tests-run '{"testMode":"EditMode","testClass":"MeleeAttackAbilityEditModeTests","includeMessages":true,"includeStacktrace":true,"requestId":"melee-execution-asset-resolve-20260702"}'`：Passed，`failedTests = 0`。
- `python .codex/skills/aibridge/bridge.py scene-list-opened`：`Assets/Scenes/ClickMoveTest.unity`，`isDirty = false`。

## 关联文件

- `Assets/Scripts/GameCore/Runtime/Database/Abilities/AbilitySheet.cs`
- `Assets/Editor/GameCore/Tests/MeleeAttackAbilityEditModeTests.cs`
- `Assets/Editor/GameCore/Utils/FormalAbilityAssetValidation.cs`
