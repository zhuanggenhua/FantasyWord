# EX-GAS 动态冷却标签不生效排查记录

## 症状

- 基础攻击能触发第一次开火，但新增 GAS 冷却合同测试后，第二次开火没有稳定被 `EX-GAS` 冷却阻断。
- 进一步检查发现：`CAbilityCooldown` 已配置，`AbilitySpec.GetCooldownTags()` 能返回冷却 tag，但角色 ASC 上没有被 `HasAnyTags(...)` 判定为持有该冷却 tag。

## 误判风险

- 不能把项目侧 `m_remainingCooldownTimer` 变成正式修复；那只会重新制造一套本地冷却真相。
- 不能把测试等待条件写成“等本地剩余时间大于 0”后宣称 GAS 冷却已完成；必须回到 `AbilitySpec.CheckActivation()` 是否返回 `FailCooldown`。
- 不能把 Unity 旧编译缓存报出的旧行号当成当前磁盘源码仍错误；必须读取当前文件确认。

## 真实根因

- `EX-GAS` 的动态冷却 tag 是运行时按能力资产生成的稳定正整数，不一定出现在静态标签树里。
- 旧 `TagHelper.HasTag(int tagA, int tagB)` 和 `SingletonGameplayTagMapExtension.IsTagAIncludeTagB(...)` 只有在两侧 tag 都登记在静态 map 中时才比较层级关系。
- 对于动态 tag，哪怕 `tagA == tagB`，旧逻辑也会因为 map 不含该 tag 而返回 false。
- 结果是冷却 GE 可以配置出 `GrantedTags`，但 ASC 查询冷却 tag 时匹配失败，`AbilitySpec.CheckActivation()` 不能可靠进入 `FailCooldown`。

## 修复点

- `Assets/Plugins/GAS/Runtime/General/Helper/TagHelper.cs`
  - `HasTag(int tagA, int tagB)` 先执行同码命中，再进入静态标签树层级判断。
- `Assets/Plugins/GAS/Runtime/Tag/Component/SingletonGameplayTagMap.cs`
  - `IsTagAIncludeTagB(...)` 同样先执行同码命中，保证 ECS 系统里的动态 tag 查询语义一致。
- `Assets/Scripts/GameCore/Runtime/Combat/Weapons/WeaponExecutionRuntime.cs`
  - `Stop` / `Interrupted` 不再被 `isBusy` 当作真正执行中状态，避免第二次开火绕过 GAS 激活检查。

## 必查项

- 冷却是否配置为 `CAbilityCooldown`，不是只看项目侧本地冷却字段。
- 开火后角色 ASC 是否能通过 `HasAnyTags(abilitySpec.GetCooldownTags())` 读到冷却 tag。
- 第二次开火是否由 `AbilitySpec.CheckActivation()` 返回 `FailCooldown`。
- 若 Unity 报旧行号编译错误，先读取磁盘文件确认是否仍含旧代码，再通过公开刷新/重编译入口让 Editor 重新编译。

## 验收口径

- `MeleeAttackAbilityEditModeTests.Fire_WithCooldown_StartsFormalGasCooldownAndRejectsSecondUse` 必须通过。
- `MeleeAttackAbilityEditModeTests` 全类必须通过，确认基础攻击命中、mana cost、cooldown 与旧入口收口没有互相打坏。
- `FormalDamagePipelineEditModeTests` 必须通过，确认伤害仍进入 EX-GAS 结算链。

## 本次验证

- `MeleeAttackAbilityEditModeTests`：Passed，`passedTests = 9`，`failedTests = 0`。
- `FormalDamagePipelineEditModeTests`：Passed，`passedTests = 4`，`failedTests = 0`。
- `ClickMoveTest` 场景复查为 `isDirty = false`。
