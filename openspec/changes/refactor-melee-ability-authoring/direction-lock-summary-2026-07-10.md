# 普攻单次激活方向上下文收口记录（2026-07-10）

## 背景

本轮最终目标是把“输入请求方向”和“任务执行姿态”分开：普通攻击在命中帧读取施法者当前姿态，闪现、突进等技能可以在 Timeline 中改变位置与朝向，同时不让运行数据覆盖 GAS 作者配置参数。

这不是演示场景默认装备问题。`EquipmentSystemDemo` 只能作为手动观察入口，不能作为普攻 GAS 链路、武器素材或测试通过的真相来源。

## 已完成

- GAS fork 新增 `AbilityActivationContext`，把单次激活的起点、可选方向和可选主目标与 AbilityLogic 作者参数分离。
- `AbilitySpec.TryActivate(context)` 只提交本次运行上下文；成功激活时提交，失败时丢弃，结束或取消时清理。
- `TaskApplyEffects` 把当前激活上下文交给 TargetCatcher，并把可选主目标作为 `CatchTarget` 等捕获器的输入。
- `ActiveAbilityBase` 在开火前记录当前有效方向；没有方向时仍可创建激活上下文，因此自疗、全屏 Buff 等无方向能力不被错误阻断。
- `CatchAreaBox2D`、`CatchAreaCircle2D`、`CatchAreaPolygon2D` 只从激活上下文读取运行时方向；缺少方向时明确报错并拒绝方向型命中，不读取角色实时方向兜底。
- `Movable` 不再持有角色级 Ability 方向锁；实时移动、瞄准和朝向仍由其原职责处理。
- 近战判定仍保持一份本地多边形，不新增 `Attack_Up/Down/Left/Right` 四方向 GAS 配置，也不为四方向保存四份判定。
- 动画仍由开火时角色朝向和正式攻击状态维持；当前没有声称动画 Cue 直接读取 `AbilityActivationContext`。
- 素材测试只验证被测武器视觉资产自身配置 `Attack` 武器序列帧，不要求或修改 `EquipmentSystemDemo` 默认装备。

## 不做

- 不用演示场景默认装备修普攻链路测试。
- 不恢复 `AbilitySheet`、旧执行资产或项目侧第二套命中框真相。
- 不把 GAS 表拆成四方向动作名。
- 不把攻击方向做成所有 Ability 的必填参数。
- 不自动刷新、不自动保存、不新增替代 UI 或缓存页。
- 不在缺少方向时静默读取角色实时方向或默认向右。

## 验收结果

- 执行测试时 Unity Editor 状态：`isPlaying = false`、`isCompiling = false`，没有真实 C# 编译错误阻止测试。
- `AbilityActivationContext_AllowsDirectionlessAbilities`：通过。
- `Fire_DoesNotBakeFacingDirectionIntoGasActivationContext`：通过。
- `CatchAreaBox2D_UsesOwnerFacingAtHitFrameWithoutTransformRotation`：通过。
- `CatchAreaPolygon2D_UsesOwnerPoseAtHitFrame_AfterTeleport`：通过。
- `MeleeAttackAbilityEditModeTests` 类级回归：`passedTests = 57`、`failedTests = 0`。
- `npx openspec validate refactor-melee-ability-authoring --strict`：通过。
- `git diff --check`：最终补丁需在文档落盘后再复查一次。

验证期间曾出现测试运行器返回旧断言文本；根因是外部修改后的 C# 尚未同步到 Unity SourceAssetDB。通过 GAS/Unity Bridge 正式 `assets-refresh` 入口强制同步后，同一定向测试和类级回归均使用最新程序集通过。该过程没有修改业务逻辑或增加运行时兜底。
