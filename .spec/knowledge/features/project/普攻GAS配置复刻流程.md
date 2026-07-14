---
name: 普攻GAS配置复刻流程
description: 项目知识：普攻GAS配置复刻流程.md：普攻GAS配置复刻流程。
metadata:
  type: doc
  status: 已交付
---

# 普攻 GAS 配置复刻流程

> 本文只记录当前 FantasyWord 普攻 `20001 Attack` 的可复刻配置流程。目标是让人能按 Unity 菜单、GAS 中心、时间轴编辑器和源表路径复刻当前链路，不靠口头记忆。

## 当前结论

- 普攻正式能力 ID：`20001`
- 普攻时间轴 ID：`101`
- 普攻伤害效果 ID：`2003`
- 普攻命中反馈 Cue ID：`20001`
- 普攻攻击中标签：`3003 Event.Attacking`
- 当前正式链路：`EX-GAS Ability -> ALTimeline -> TaskPlayCue/TaskApplyEffects -> CatchAreaPolygon2D -> GameplayEffect -> GameplayCue -> GameCore Feedback`
- 当前素材组织口径：角色动作和武器/挥砍特效是分开的；当前 GAS 配置只触发角色动画 `Attack` 和命中反馈 Cue，独立武器特效 Cue 等素材拆出后再接，不把武器漂浮攻击当成普攻标准。

## 入口位置

### 1. GAS 中心

Unity 顶部菜单：

```text
EXTool / EX-GAS / GAS中心管理器
```

打开后左侧常用页：

- `GameplayAbility技能`
- `GameplayEffect效果buff`
- `GameplayCue演出提示`
- `ASC预设`
- `Setting基本设置`

注意：GAS 中心保留原插件设计语义。进入某页后如果没有看到数据，先点该页上方 `刷新`，不要靠“打开页时自动读表/自动选中”来伪装正确。

### 2. 时间轴技能编辑器

Unity 顶部菜单：

```text
EXTool / EX-GAS / 时间轴技能编辑器
```

用于编辑 `#exgas.timelineAbility.xlsx` 对应的 TimelineAbility 数据，例如当前普攻时间轴 `101 普通攻击`。

### 3. 配置源表

源表目录：

```text
EX_GAS_Config/ProjectConfigTable/exgas_config/Datas/
```

当前普攻用到的表：

```text
#exgas.ability.xlsx
#exgas.timelineAbility.xlsx
#exgas.gameplayEffect.xlsx
#exgas.gameplayCue.xlsx
#exgas.abilityGameCore.xlsx
#exgas.gameplayTags.xlsx
```

生成后的 JSON 在：

```text
Assets/DataGenerated/Luban/Json/GAS/
```

对应文件：

```text
exgas_tbability.json
exgas_tbtimelineability.json
exgas_tbgameplayeffect.json
exgas_tbgameplaycue.json
exgas_tbabilitygamecore.json
exgas_tbgameplaytags.json
```

## 配置步骤

### 步骤 1：配置标签

入口：

```text
GAS中心管理器 -> GameplayTag标签
```

源表：

```text
EX_GAS_Config/ProjectConfigTable/exgas_config/Datas/#exgas.gameplayTags.xlsx
```

当前普攻需要确认这两条：

| id | Name | Desc |
| --- | --- | --- |
| `2003` | `Ability.Attack` | 技能：攻击 |
| `3003` | `Event.Attacking` | 事件：正在攻击 |

用途：

- `Ability.Attack` 是攻击类技能标签。
- `Event.Attacking` 是普攻激活期间拥有的“正在攻击”标签，用来阻止前摇期间重复出手。

操作：

1. GAS 中心左侧点 `GameplayTag标签`。
2. 点 `刷新`。
3. 确认能看到 `Ability.Attack` 和 `Event.Attacking`。
4. 如果改过源表，点 `导出更新Json表`。

### 步骤 2：配置 GameplayAbility 技能身份

入口：

```text
GAS中心管理器 -> GameplayAbility技能
```

源表：

```text
EX_GAS_Config/ProjectConfigTable/exgas_config/Datas/#exgas.ability.xlsx
```

当前普攻 `20001 Attack` 配置：

| 字段 | 当前值 | 含义 |
| --- | --- | --- |
| `ID` | `20001` | 普攻稳定能力 ID |
| `Name` | `Attack` | 能力名 |
| `Desc` | `玩家普通攻击` | 描述 |
| `Cost` | 空 / `0` | 当前无消耗 |
| `CdEffect` | 空 / `0` | 当前无冷却 GE |
| `Cd` | 空 / `0` | 当前无冷却时长 |
| `ActivationOwnedTags` | `3003` | 激活期间给自己加“正在攻击” |
| `ActivationBlockedTags` | `0;0;3003` | 自己有 `3003` 时禁止再次激活 |
| `AbilityLogic` | `ALTimeline` | 走 EX-GAS 时间轴能力 |
| `AbilityLogic` 参数 1 | `101` | 绑定 TimelineAbility ID `101` |

操作：

1. GAS 中心左侧点 `GameplayAbility技能`。
2. 点 `刷新`。
3. 在 `当前Ability` 下拉里选择 `20001`。
4. 确认名字是 `Attack`。
5. 确认 `技能逻辑类型` 是 `ALTimeline`。
6. 确认 Timeline 参数 ID 是 `101`。
7. 确认激活期间获得标签 `3003`，阻止激活标签包含 `3003`。
8. 修改后点 `保存`。

不要做：

- 不要新建 `AbilitySheet` 来表达同一个普攻身份。
- 不要在页面构造时自动读表或自动选中第一条 Ability。
- 不要把 `AbilitySheet` 当成普攻正式身份入口；正式普攻的身份入口是 EX-GAS Ability `20001`。

### 步骤 3：配置 TimelineAbility 时间轴

入口：

```text
EXTool / EX-GAS / 时间轴技能编辑器
```

源表：

```text
EX_GAS_Config/ProjectConfigTable/exgas_config/Datas/#exgas.timelineAbility.xlsx
```

当前普攻时间轴 `101 普通攻击`：

| 字段 | 当前值 |
| --- | --- |
| `ID` | `101` |
| `Name` | `普通攻击` |
| `LifeTime` | `30` |
| `ManualEndAbility` | `false` |

轨道 1：动画轨道

| 字段 | 当前值 |
| --- | --- |
| 轨道名 | `动画轨道` |
| Clip 开始帧 | `2` |
| Clip 结束帧 | `24` |
| Clip 名 | `播放攻击动画` |
| Task 类型 | `TaskPlayCue` |
| Cue 类型 | `CuePlayGameCoreAnimator` |
| AnimatorNodePath | 空字符串 |
| AnimationName | `Attack` |

轨道 2：GE 轨道

| 字段 | 当前值 |
| --- | --- |
| 轨道名 | `GE轨道` |
| Clip 1 开始/结束帧 | `1 / 1` |
| Clip 1 名称 | `消耗` |
| Clip 1 Task | `TaskDoCost` |
| Clip 2 开始/结束帧 | `8 / 8` |
| Clip 2 名称 | `造成伤害` |
| Clip 2 Task | `TaskApplyEffects` |
| 施加效果 IDs | `2003` |
| TargetCatcher 类型 | `CatchAreaPolygon2D` |
| isWorldSpace | `false` |
| points | `0.175,-0.25;1.125,-0.25;1.125,0.55;0.175,0.55` |
| layer | `128` |

操作：

1. 打开 `EXTool / EX-GAS / 时间轴技能编辑器`。
2. 打开或选择 TimelineAbility `101 普通攻击`。
3. 检查总长度 `30` 帧。
4. 检查动画轨道第 2 到 24 帧触发 `TaskPlayCue -> CuePlayGameCoreAnimator -> Attack`。
5. 检查 GE 轨道第 1 帧执行 `TaskDoCost`。
6. 检查 GE 轨道第 8 帧执行 `TaskApplyEffects`，效果 ID 是 `2003`。
7. 检查目标捕获是 `CatchAreaPolygon2D`，数值为 `points 0.175,-0.25;1.125,-0.25;1.125,0.55;0.175,0.55`、`layer 128`。

### 步骤 3.1：在 Scene 视图里预览和调整多边形命中

当前命中编辑仍然只使用 EX-GAS 原时间轴入口，不新增项目侧技能窗口。

操作：

1. 打开 `EXTool / EX-GAS / 时间轴技能编辑器`。
2. 选择 TimelineAbility `101 普通攻击`。
3. 在顶部 `PreviewInstance` 绑定一个带角色朝向逻辑的预览对象，例如当前场景里的玩家或带 `Movable` 的角色对象。
4. 在时间轴里选中第 8 帧的 `TaskApplyEffects` clip。
5. 确认该 Task 的 `TargetCatcher` 是 `CatchAreaPolygon2D`。
6. 切到 Scene 视图，会看到绿色多边形命中范围和顶点手柄。
7. 拖多边形中心点整体移动，拖顶点调整具体轮廓；右键边可插入顶点，右键顶点可删除顶点，至少保留 3 点，最多 16 点。
8. 调完后回到时间轴窗口，点击 EX-GAS 原生保存按钮；不要依赖打开窗口自动保存。
9. 如需重新从表读取配置，回到 EX-GAS 原入口执行刷新/重新打开，不要新增自动读表补丁。

注意：

- 这个手柄只在当前选中 `TaskApplyEffects -> CatchAreaPolygon2D` 时出现；不选中该 Task 时不会编辑命中范围。
- 手柄直接改同一个 `XParamCatchAreaPolygon2D.points` 参数对象，保存仍走 EX-GAS 时间轴原保存流程。
- `layer` 仍在参数 Inspector 里填；Scene 视图手柄只负责多边形顶点。
- 如果预览对象没有绑定，或者当前选中的不是 `CatchAreaPolygon2D`，Scene 视图不会显示可编辑手柄。

说明：

- 当前命中范围不是一个单独旧项目 `MeleeAbilityExecutionAsset` 判定框资产。
- 它是 EX-GAS `TaskApplyEffects` 的 `TargetCatcher` 参数。
- `CatchAreaPolygon2D` 是项目侧接入 EX-GAS TargetCatcher 扩展点的 2D 目标捕获器。
- 当前可视化编辑已经补在原 EX-GAS 时间轴/TargetCatcher 作者面上，不再新造第二套普攻编辑 UI。
- 运行时不是只画多边形：先用多边形外接盒做 `Physics2D.OverlapBoxNonAlloc` 粗筛，再用候选 Collider 的真实形状与多边形做精筛，避免外接盒误命中。

### 步骤 4：配置 GameplayEffect 伤害

入口：

```text
GAS中心管理器 -> GameplayEffect效果buff
```

源表：

```text
EX_GAS_Config/ProjectConfigTable/exgas_config/Datas/#exgas.gameplayEffect.xlsx
```

当前普攻伤害效果 `2003 基础攻击正式伤害`：

| 字段 | 当前值 |
| --- | --- |
| `ID` | `2003` |
| `Name` | `基础攻击正式伤害` |
| `Desc` | `基于攻击者物攻和目标物防的基础攻击伤害` |
| `CueOnApply` | `20001` |

`FormalDamage` 当前值：

| 字段 | 当前值 |
| --- | --- |
| `DamageType` | `1` |
| `FlatDamage` | `4` |
| `ScalingFactor` | `1` |
| `IgnoreDefense` | `false` |
| `VisualFlags` | `0` |
| `ImpactDataType` | `0` |
| `ImpactData` | `0,0` |
| `PushMode` | `0` |
| `PushIntensity` | `0` |
| `PushResistance` | `0` |
| `InvincibilityDuration` | `0` |

`FormalConditionalDamage` 当前值：

| 字段 | 当前值 |
| --- | --- |
| `ConditionKind` | `1` |
| `FacingDotThreshold` | `-0.35` |
| `DamageType` | `1` |
| `FlatDamage` | `3` |
| `ScalingFactor` | `0` |
| `IgnoreDefense` | `false` |
| 其它冲击字段 | `0 / false` |

操作：

1. GAS 中心左侧点 `GameplayEffect效果buff`。
2. 点 `刷新`。
3. 在 `当前Effect` 选择 `2003`。
4. 确认 `CueOnApply` 有 `20001`。
5. 如果 GAS 中心当前页面没有显示 `FormalDamage / FormalConditionalDamage` 扩展字段，就不要新造 UI；直接编辑源表 `#exgas.gameplayEffect.xlsx` 中对应列，再导出。
6. 修改后点 `保存`，或保存源表后回到 GAS 中心点 `导出更新Json表`。

说明：

- `FormalDamage` 和 `FormalConditionalDamage` 是项目侧正式伤害扩展数据。
- 它们通过项目侧运行时桥接追加进 EX-GAS `GameplayEffectConfig`。
- 伤害结算是玩法规则，不放在 `GameplayCue` 里。

### 步骤 5：配置 GameplayCue 命中反馈

入口：

```text
GAS中心管理器 -> GameplayCue演出提示
```

源表：

```text
EX_GAS_Config/ProjectConfigTable/exgas_config/Datas/#exgas.gameplayCue.xlsx
```

当前命中反馈 Cue `20001 基础攻击命中反馈`：

| 字段 | 当前值 |
| --- | --- |
| `ID` | `20001` |
| `Name` | `基础攻击命中反馈` |
| `Desc` | `基础攻击命中可受伤目标时触发目标角色 GameplayFeedbackSet.HitDamageable` |
| `CueLogic` | `CuePlayGameCoreFeedback` |
| `Kind` | `6` |
| `Target` | `0` |

操作：

1. GAS 中心左侧点 `GameplayCue演出提示`。
2. 点 `刷新`。
3. 选择 Cue `20001`。
4. 确认 Cue 逻辑是 `CuePlayGameCoreFeedback`。
5. 确认它只触发表现反馈，不做伤害、冷却、标签或目标选择。

当前素材限制：

- 当前命中 Cue 是“命中反馈”入口。
- 武器攻击特效和独立特效 Cue 还没有按最终素材拆出配置。
- 你的素材组织是“角色动作”和“武器攻击/特效”分开，后续应新增独立 Cue 或扩展现有 Cue 参数来触发武器层/特效层，而不是把普攻做成 TopDownEngine 那种漂浮武器 prefab 攻击。

### 步骤 6：配置项目侧 AbilityGameCore 输入和图标

源表：

```text
EX_GAS_Config/ProjectConfigTable/exgas_config/Datas/#exgas.abilityGameCore.xlsx
```

当前 `20001` 配置：

| 字段 | 当前值 | 含义 |
| --- | --- | --- |
| `ID` | `20001` | 对应 EX-GAS Ability |
| `PrefabPath` | `Assets/Prefabs/Abilities/Melee/测试-基础攻击.prefab` | 项目侧运行时能力 prefab |
| `IconPath` | `Assets/Art/KrishnaPalacio/MINIFANTASY - Dungeon/Sprites/Animations/Human/HumanBaseAttack.png` | 当前图标 |
| `AbilityRootMode` | `1` | Polydirectional，四方向/多方向能力根 |
| `InputTriggerMode` | `0` | SemiAuto，半自动按一下触发 |
| `BufferInput` | `true` | 忙碌时允许输入缓冲 |
| `NewInputExtendsBuffer` | `true` | 新输入刷新缓冲时间 |
| `MaximumBufferDuration` | `0.25` | 缓冲 0.25 秒 |
| `DelayBeforeUseReleaseInterruption` | `true` | 前摇松开可中断输入门控 |
| `TimeBetweenUsesReleaseInterruption` | `true` | 后摇松开可结束本地输入门控 |
| `UpdateLookAtDirectionOnFire` | `false` | 出手时不刷新朝向，按角色当前朝向执行 |

操作：

1. 当前这张表不是 GAS 中心原生页的主编辑入口，按源表编辑。
2. 修改后保存 Excel。
3. 回 Unity 执行 `EXTool / EX-GAS / 生成脚本 / GAS表配置` 或在 GAS 中心点相关 `导出更新Json表`。
4. 确认生成 `Assets/DataGenerated/Luban/Json/GAS/exgas_tbabilitygamecore.json`。

Prefab 当前状态：

```text
Assets/Prefabs/Abilities/Melee/测试-基础攻击.prefab
```

Prefab 上挂的是：

```text
FantasyWord.GameCore.MeleeAttackAbility
```

注意：

- 这个 prefab 是项目侧运行时桥，不是旧 `AbilitySheet` 真相。
- 未来命名应从 `测试-基础攻击` 改成正式中文资产名，但重命名前要确认 `.meta` / GUID 引用闭包，不能随手改。

### 步骤 7：把普攻挂到角色

当前角色侧入口在：

```text
Assets/Scripts/GameCore/Runtime/Entities/Characters/CharacterAbilitySet.cs
```

关键配置字段：

```text
m_additionalFormalGasAbilityCodes
```

用途：

- 给角色额外挂 EX-GAS Ability ID。
- 当前普攻应挂 `20001`。

复刻方式：

1. 选中需要拥有普攻的角色 prefab 或场景角色。
2. 找到 `CharacterAbilitySet` 组件。
3. 在 `Additional Formal Gas Ability Codes` 数组里加入 `20001`。
4. 确认该角色有能力根节点：
   - Static root
   - Polydirectional root
   - Horizontal root
5. 当前普攻 `AbilityRootMode = 1`，所以需要 Polydirectional 能力根可用。
6. 保存 prefab 或场景。

注意：

- 如果角色是通过装备/装载逻辑获得技能，也要确保最终运行时进入 `CharacterAbilitySet` 的正式 EX-GAS ability code 是 `20001`。
- 不要再通过旧 `AbilitySheet.executionAsset` 表达普攻执行真相。

### 步骤 8：导出和生成

改完任何 GAS 源表后执行：

```text
EXTool / EX-GAS / 生成脚本 / GAS表配置
```

或在 GAS 中心对应页面点：

```text
导出更新Json表
```

必须确认生成文件更新：

```text
Assets/DataGenerated/Luban/Json/GAS/exgas_tbability.json
Assets/DataGenerated/Luban/Json/GAS/exgas_tbtimelineability.json
Assets/DataGenerated/Luban/Json/GAS/exgas_tbgameplayeffect.json
Assets/DataGenerated/Luban/Json/GAS/exgas_tbgameplaycue.json
Assets/DataGenerated/Luban/Json/GAS/exgas_tbabilitygamecore.json
```

如果新增了 Task / Cue / Effect 扩展类型，还需要确认：

```text
Assets/Scripts/Gen/XAbility.gen.cs
Assets/Scripts/Gen/XLuban.gen.cs
```

如果新增的是 `TargetCatcher`、`AbilityTask`、`GameplayCue`、`GameplayEffect` 组件、`MMC` 或新的 `XParam` 参数类，必须走 EX-GAS 原生成链路，不允许用项目侧启动注册绕过：

```text
EXTool / EX-GAS / 生成脚本 / 更新Bean定义
配置表工程 gen.bat
EXTool / EX-GAS / 生成脚本 / 生成所有
EXTool / EX-GAS / 生成脚本 / GAS表配置
```

完成后检查：

```text
Assets/Scripts/Gen/XAbility.gen.cs
Assets/Scripts/Gen/XLuban.gen.cs
Assets/DataGenerated/Luban/Json/GAS/
```

当前 `CatchAreaPolygon2D` 的正确状态是：类型注册出现在 `XAbility.gen.cs`，参数解析出现在 `XLuban.gen.cs`，配置数据已由 `GAS表配置` 导出。不要再新增项目侧 Bootstrap、打开 Unity 自动注册、打开窗口自动补缓存、打开 GAS 中心重建缓存页或其它启动期补丁。

如果按 EX-GAS 原生成链执行后仍然打不开时间轴或下拉没有 ID，先按证据分类处理：

1. 如果只是没有导表、没有生成、没有点原插件刷新按钮，回到原 EX-GAS 流程，不改代码。
2. 如果证据确认是插件原入口自身 bug，例如窗口空引用、UXML 写入错误默认值、Unity/Odin 版本兼容崩溃，可以在 `Assets/Plugins/GAS` 原入口做最小 fork patch。
3. 如果是 FantasyWord 自己新增能力类型、2D TargetCatcher 或项目运行时配置，走 EX-GAS 生成链和项目侧公开扩展点，不靠启动注册或自动补缓存绕过。

插件 fork patch 必须记录现实症状、原因、改动文件、验证入口和回退方式；禁止新造项目侧时间轴窗口、项目侧 Ability 窗口或自动缓存页来替代原设计。

## 验收流程

### 编辑器内肉眼验收

1. 打开 `EXTool / EX-GAS / GAS中心管理器`。
2. `GameplayAbility技能` 点 `刷新`，确认 `当前Ability` 有 `20001 Attack`。
3. 打开 `EXTool / EX-GAS / 时间轴技能编辑器`，确认 `101 普通攻击`。
4. 时间轴里确认第 2 帧播放 `Attack`，第 8 帧 `TaskApplyEffects -> 2003 -> CatchAreaPolygon2D`。
5. `GameplayEffect效果buff` 点 `刷新`，确认 `2003 基础攻击正式伤害`，`CueOnApply = 20001`。
6. `GameplayCue演出提示` 点 `刷新`，确认 `20001 基础攻击命中反馈`。

### 自动化验证

刷新 Unity：

```powershell
python .codex/skills/aibridge/bridge.py assets-refresh '{"bridgeSceneDirtyPolicy":"discard-generated"}'
```

检查编译状态：

```powershell
python .codex/skills/aibridge/bridge.py editor-application-get-state
```

检查 Console：

```powershell
python .codex/skills/aibridge/bridge.py console-get-logs '{"maxEntries":80,"includeStackTrace":true}'
```

近战回归测试当前可用口径：

```powershell
python .codex/skills/aibridge/bridge.py tests-run '{"testMode":"EditMode","testClass":"MeleeAttackAbilityEditModeTests","includePassingTests":true,"includeMessages":true,"includeStacktrace":true}'
```

通过标准：

- Unity `isCompiling=false`。
- Console 没有新的 `Error / Exception`。
- `MeleeAttackAbilityEditModeTests` 通过。
- 基础攻击命中目标时目标生命值下降。
- 前摇期间再次输入不能绕过 `Event.Attacking` 阻断。
- 输入缓冲、冷却/后摇相关测试不回退。

## 常见问题

### GAS 中心打开后 GameplayAbility 页没有 Ability

正确处理：

1. 左侧点 `GameplayAbility技能`。
2. 点该页上方 `刷新`。
3. 看 `当前Ability` 下拉。

不要处理成：

- 构造页面时自动读表。
- 自动选第一条 Ability。
- 打开 GAS 中心时重建全部缓存页。
- 新造项目侧 Ability 查看窗口。

### 时间轴编辑器当前 ID 显示奇怪字符串或没有 ID

现象示例：

```text
System.Collections.Generic.List`1[System.String]
```

现实含义：这是时间轴窗口的 ID 下拉没有被真实 TimelineAbility ID 覆盖，不是一个有效技能 ID。

正确处理：

1. 先确认 `EX_GAS_Config/ProjectConfigTable/exgas_config/Datas/#exgas.timelineAbility.xlsx` 里有数据，例如当前应有 `101`、`102`、`20004`。
2. 如果刚新增了 `TargetCatcher`、Task、Cue、Effect 组件或参数类，先执行上面的 EX-GAS 生成链路。
3. 重新打开 `EXTool / EX-GAS / 时间轴技能编辑器`。
4. 正常状态下 `当前ID` 下拉应显示真实 ID，例如 `101, 102, 20004`。

不要处理成：

- 项目侧 `[InitializeOnLoad]` 启动注册。
- 打开 Unity 自动调用 GAS 生成缓存。
- 打开 GAS 中心自动重建缓存页。
- 打开时间轴窗口时偷偷补 `XLauncher.InitCache()`。
- 构造下拉时填一个看起来正常的默认 ID。
- 新造项目侧时间轴窗口或项目侧 Ability 窗口。

如果证据确认 EX-GAS 原时间轴窗口入口本身存在缺陷，允许做原入口最小 fork patch，但必须满足两个条件：一是改动直接作用于用户看到的原入口症状；二是验证仍回到 `EXTool / EX-GAS / 时间轴技能编辑器`，不能用项目侧替代窗口证明完成。

当前允许保留的 EX-GAS 原入口最小补丁：

- `AbilityTimelineEditorWindow.uxml`：移除 `DropdownField` 上错误序列化出的 `choices="System.Collections.Generic.List\`1[System.String]"`，对应现实症状是时间轴 `当前ID` 显示集合类型名，而不是技能 ID。
- `AbilityTimelineEditorWindow.cs`：把 `CurrentInspectorObject` 从错误的 `TimelineInspector??TimelineInspector.CurrentInspectorObject` 改为安全读取当前检查对象，原因是原表达式在 `TimelineInspector` 非空时返回检查器本身，不返回选中的时间轴任务。
- `GASCenterViewAsc.cs`：绕过 Odin 对 `int level` 的旧内部 Unity 字段访问，改用 Unity 原生 `EditorGUILayout.IntField` 绘制等级；对应现实症状是 Unity 6000/Odin 抛 `EditorGUI.s_RecycledEditor` 缺字段异常。
- `GASCenterViewAbility.cs`：在 Ability 页未加载表数据时给 `SelectedId` 切换加空数据保护；对应现实症状是原插件页生命周期中 `_data` 可能为空，直接 `ContainsKey` 会空引用。

### 改了 Excel 但运行时没变化

检查顺序：

1. 是否保存了 Excel。
2. 是否执行 `导出更新Json表` 或 `生成脚本 / GAS表配置`。
3. `Assets/DataGenerated/Luban/Json/GAS/*.json` 是否变化。
4. Unity 是否完成资源刷新和编译。
5. 运行时是否调用了 `FormalAbilityRuntimeBootstrap` 初始化项目侧 GAS 扩展。

### 普攻没有命中

检查顺序：

1. Timeline `101` 第 8 帧是否有 `TaskApplyEffects`。
2. `TaskApplyEffects.IDs` 是否是 `2003`。
3. TargetCatcher 是否是 `CatchAreaPolygon2D`。
4. `layer` 是否包含目标 Hitbox/受击层，当前值是 `128`。
5. 目标是否能从子物体 Hitbox 找到父级 ASC / 受伤角色。
6. EditMode 测试是否手动推进 GAS Timeline；生产运行时依赖 `Time.deltaTime`。

### 播了动画但没有武器特效

当前是已知未闭合项。

原因：

- 当前 `TaskPlayCue -> CuePlayGameCoreAnimator -> Attack` 只触发角色动画。
- 你的素材组织是角色动作和武器攻击/特效分开。
- 当前还没有把拆出的武器特效接成独立 Cue。

后续正确方向：

- 素材拆出后新增或扩展 Cue。
- 在 Timeline 上增加武器/特效 Cue Clip。
- 仍以 EX-GAS Timeline 作为触发时序真相。
- 不改成漂浮武器 prefab 攻击模式。
