# Current State: refactor-melee-ability-authoring

## 已被当前代码与验证证明的现态

### 1. 基础攻击已进入 EX-GAS Timeline 最小闭环

当前基础攻击不再只是已删除的旧执行资产 流程。

已成立的基础攻击链路：

- 正式能力配置入口：EX-GAS Ability `20001`；已迁移普攻不再保留已删除的旧能力表资产身份根
- 存量旧入口：已迁移普攻的旧 `测试-基础攻击.asset` 已删除。正式授予、运行实例创建、装备槽、触发、保存和规则绑定以 GAS Ability Code 为主键，Prefab、AbilityRootMode 和输入门控已进入 `exgas.abilityGameCore`；正式 RootMode 使用 `EFormalGasAbilityRootMode`，不再复用旧 `AbilitySheet.EAbilityOrientationMode`；运行时代码不再公开旧能力表身份投影；正式 GAS 实例身份只能来自 EX-GAS Ability Code
- 装备槽/触发入口：`CharacterAbilitySlotData.formalGasAbilityCode` 和 `CharacterEquippedAbilityLoadout` 内部槽位现在保存 GAS Ability Code；历史槽位数据如果同时带 `formalGasAbilityCode` 和旧主动能力表引用，只能迁移为 GAS Code 槽位或记录迁移缺口，不能恢复旧对象；玩家 `FireEquippedAbilityAtIndex` / `StopFireEquippedAbilityAtIndex` 会优先按 GAS Code 解析运行时能力实例；已迁移普攻的菜单列表、快捷槽和 HUD 展示通过 `CharacterAbilityMenuEntry` / `CharacterEquippedAbilitySlotView` 投影读取 GAS 身份，`ActiveAbilitySheet`（已删除） 类型已删除，未迁移技能不能继续依赖旧能力表视图
- 能力来源/保存入口：`CharacterAbilitySourceData.formalGasAbilityCode` 和 `CharacterAbilityRuntimeStateData.formalGasAbilityCode` 现在是已迁移能力的新保存真相；新保存数据不会再同时写已删除的旧能力表引用，不再写旧能力表引用；旧存档或未迁移内容必须迁移到 EX-GAS Ability Code 或明确迁移数据
- 运行时容器入口：`CharacterAbilitySetRuntime.GetFormalGasAbilityInstanceEntriesSnapshot()` 只枚举正式 GAS code 实例，`GetAbilityInstanceEntriesSnapshot()` 只枚举已删除的旧能力表实例；`CharacterAbilitySet.CreateAbilityRuntimeStates()` 会把两条快照合并保存，但正式 GAS 状态只写 `formalGasAbilityCode`，不再把正式实例塞进旧 `AbilitySheet = null` 的字典投影。
- 授予/恢复/压制入口：`AddOrRemoveAbility`、`ItemAddAbilityEffect`、`Equipment`、`CharacterAbilitySet.m_additionalFormalGasAbilityCodes`、读档恢复、能力型临时效果、变形/感染规则和召唤附加能力已改为 GAS Ability Code 主键授予/撤回/压制能力；旧 `AbilitySheet[]` 字段已删除；未迁移内容和历史数据只能通过显式迁移数据落到 EX-GAS Ability Code，或记录为待迁移缺口。旧能力表字段、旧 Prefab、旧主动能力表运行容器和项目侧 `FormalGasAbilitySheetResolver` 已删除；已迁移能力不再能通过旧表解析器、旧字段或旧资产身份回到运行时
- 正式规则绑定：`CharacterAbilitySet` 的正式规则绑定表现在以 GAS Ability Code / 派生 ability code 为主键；已迁移基础攻击不再以已删除的旧主动能力表对象身份作为规则绑定真相
- 技能身份显示：`FormalGasAbilityIdentityResolver -> FormalGasAbilityDescriptionGeneratedRuntime -> EX-GAS Ability.Name/Desc`
- EX-GAS Timeline：`101`
- Timeline 推进：`ALTimeline + ALTimelinePlayer`
- 资源支付：当前 `Ability 20001` 表内 `Cost = 0`，`TaskDoCost` 不会从 `AbilitySheet.manaCost` 合成正式消耗
- 动画表现：`TaskPlayCue -> CuePlayGameCoreAnimator`，只下发装备动作键；角色动作由角色层播放，武器攻击和武器自带特效由武器序列帧承载
- 近战命中：`TaskApplyEffects + CatchAreaPolygon2D`
- 规则结算：`GameplayEffect 2003 + FormalDamage`
- 条件附加规则：`GameplayEffect 2003 + FormalConditionalDamage`，当前用于背刺附加伤害

对应证据：

- `测试-基础攻击.asset` 和 `测试-变形替换能力.asset` 均已删除，不再保留已删除的旧能力表资产本体；变形替换 smoke 的正式身份已落在 EX-GAS Ability `20002`、`exgas.abilityGameCore` 和 Timeline `102`。旧能力表类型已删除；旧数据兼容残留不能再转入 GAS Ability Code 路径；正式运行实例创建、授予、装备、触发和规则绑定必须直接使用 GAS Ability Code 与 `exgas.abilityGameCore`。
- `exgas_tbability.json` 中 Ability `20001` 使用 `ALTimeline`，参数指向 Timeline `101`。
- `exgas_tbability.json` 中 Ability `20001` 当前 `Cost = 0`、`Cd = 0`、`CdEffect = 0`；基础攻击不会再从 `AbilitySheet.manaCost` / `AbilitySheet.cooldown` 合成 `CAbilityCost` 或 `CAbilityCooldown`。
- `exgas_tbtimelineability.json` 中 Timeline `101` 包含 `TaskPlayCue -> CuePlayGameCoreAnimator`、`TaskDoCost` 和 `TaskApplyEffects -> CatchAreaPolygon2D`。
- `exgas_tbgameplayeffect.json` 中 GameplayEffect `2003` 包含 `FormalDamage`，当前配置为物理伤害、固定伤害 `4`、攻击缩放 `1`、不忽略防御。
- `exgas_tbgameplayeffect.json` 中 GameplayEffect `2003` 也包含 `FormalConditionalDamage`，当前条件为 `Backstab`、朝向阈值 `-0.35`、附加物理平伤 `3`。
- 已迁移普攻的旧 `测试-基础攻击.asset` 已删除；正式基础攻击运行已通过 `FormalGasAttack_DoesNotRequireLegacyExecutionAssetForRuntime` 验证，不再需要 `AbilitySheet`（已删除） 或 `MeleeAbilityExecutionAsset`（已删除） 运行壳。
- 项目侧 `AbilitySheetEditor` 已删除，`DatabaseWindow` 也不再暴露 `AbilitySheet`（已删除） 页签；已删除的旧能力表类型已删除，不再具备任何技能作者面。基础攻击正式作者入口回到 EX-GAS Ability / `exgas.abilityGameCore` / Timeline / GameplayEffect / Cue。已删除的旧能力表类型和字段本体已删除。
- `AbilitySheet` / `ActiveAbilitySheet` / `PassiveAbilitySheet`（均已删除） 本体和字段已删除；不得再以 `m_legacy*` 旧表字段保留技能身份、图标、Prefab、RootMode、Cost、Cooldown、权限、动作锁、打断门、出手朝向或出手音效。
- `AbilitySheet` / `ActiveAbilitySheet` / `PassiveAbilitySheet`（均已删除） 类型已删除；`AbilityExecutionAsset` / `MeleeAbilityExecutionAsset` 和其它 `*AbilityExecutionAsset` 已删除，Unity 新建菜单不再把这些旧类型作为正式技能作者入口；未迁移能力必须重新表达为 EX-GAS 数据或记录为待迁移缺口。
- `MeleeAttackAbility` 对 GAS Timeline 技能不再创建或执行项目侧本地命中窗口；旧命中窗口字段和旧近战执行分支已从 `MeleeAttackAbility` 删除，命中时序只由 EX-GAS Timeline/Task 承担。
- `MeleeAttackAbility` 对已绑定正式 GAS Ability 的基础攻击，不再从已删除的旧执行资产读取正式前摇和后摇门控；当前由 `FormalGasAbilityTimelineExecutionResolver -> FormalGasAbilityDescriptionGeneratedRuntime -> XLuban` 从 EX-GAS Timeline 派生：首个 `TaskDoCost` / `TaskApplyEffects` 帧作为本地出手前摇，Timeline `LifeTime` 作为本地后摇门控。
- `MeleeAttackAbility` 对已绑定正式 GAS Ability 的近战能力，不再从已删除的旧执行资产读取输入触发、输入缓冲、松手中断、本地连发或弹匣语义；当前本地输入门控已由 `exgas.abilityGameCore` 提供。基础攻击使用普通触发，蓄力释放 `20004 ChargedAttackRelease` 使用 `InputTriggerMode = HoldRelease`：按下进入蓄力态，松手才进入 EX-GAS Timeline 释放段；EX-GAS Timeline 仍负责正式出手时点和规则生命周期。
- `MeleeAttackAbilitySheet`（已删除） 类型已删除，不再存在旧表描述生成路径。已迁移普攻不能再从旧执行资产、旧蓝耗或旧冷却生成说明文本；基础攻击正式说明只能由 EX-GAS Ability / Timeline / GameplayEffect 生成。
- 基础攻击的 Prefab、RootMode、输入缓冲和出手朝向更新只从 `exgas.abilityGameCore` 读取；旧 `AbilitySheet.prefab` / `AbilitySheet.orientationMode` / `ActiveAbilitySheet.updateLookAtDirectionOnFire` 类型成员已删除。
- `CharacterEquippedAbilityLoadout` 已从单纯保存 `ActiveAbilitySheet`（已删除） 改为保存内部槽位条目：已迁移普攻槽位保存 `formalGasAbilityCode`，读档恢复也以 GAS Code 优先；即使混合旧存档同时带已删除的旧主动能力表引用，也不会让旧引用抢回已迁移普攻槽位身份。触发/停止入口优先按 GAS Code 反查运行时能力实例；已删除的旧主动能力表类型已删除，不再作为快捷槽展示真相。
- `MeleeAttackAbility` 对已绑定正式 GAS Ability 的基础攻击，不再用旧 `ActiveAbilitySheet.canInterupt` 判断动作打断是否允许取消；动作打断会提交 EX-GAS cancel request，由 EX-GAS Ability 生命周期处理。
- `MeleeAttackAbility` 对已绑定正式 GAS Ability 的基础攻击，不再用旧 `AbilitySheet.orientationMode` 旋转项目侧能力物体；正式出手朝向由 EX-GAS Timeline、TargetCatcher 和项目 2D 朝向提供者解释。
- `ActiveAbilityBase` 在真实出手点对 GAS 技能重新进入 EX-GAS 规则生命周期，避免前摇期间资源或标签变化后仍然命中。
- `ActiveAbilityBase` 对已绑定正式 GAS Ability 的基础攻击不再通过旧 `ActiveAbilitySheet.disabledActionsWhileCasting` 禁用/恢复角色动作；攻击活动期移动、再次出手和更新瞄准方向的动作锁，改由 EX-GAS `Ability 20001.ActivationOwnedTags = Event.Attacking(3003)` 挂到角色 ASC 后由 `CharacterBase.Can(...)` 解释。
- `FormalAbilityRuntimeBootstrap` 不再用空标签表覆盖 EX-GAS 生成标签表；项目侧启动桥现在显式初始化 `XTag.InitTagList()`，确保 `Event.Attacking`、冷却标签和后续正式标签能按 EX-GAS 标签层级正常匹配。
- `ActiveAbilityBase` / `MeleeAttackAbility` 对已绑定正式 GAS Ability 的基础攻击不再直接播放迁移期 AbilityStart、WeaponUse 或攻击动画 trigger。
- `ALTimelinePlayer.Stop()` 只结束已经开始且尚未结束的 Task，避免未开始 Cue 在 Timeline 收尾时误报。
- 基础攻击作者描述已通过 `FormalGasAbilityDescriptionResolver -> FormalGasAbilityDescriptionGeneratedRuntime -> XLuban` 从 EX-GAS Ability/Timeline/GameplayEffect 正式表生成；当前可读输出为 `造成伤害:4 固定伤害+1 属性缩放伤害 物理 | 造成伤害:3 固定伤害 物理`。描述不再追加 `AbilitySheet.manaCost` / `AbilitySheet.cooldown`，避免旧字段伪装成正式 GAS Cost/Cooldown。
- `AbilitySheet.displayName` / `AbilitySheet.description` 类型成员已删除；不得再通过旧能力表属性解析 EX-GAS 名称或描述。已迁移普攻的 UI 展示只能通过 `CharacterAbilityMenuEntry` / `CharacterEquippedAbilitySlotView` 这类 GAS Ability Code 投影读取 `FormalGasAbilityIdentityResolver -> FormalGasAbilityDescriptionGeneratedRuntime -> XLuban` 的 EX-GAS Ability `Name/Desc`；生成表不可用时投影只显示 GAS 占位，不回退旧表字段。
- `CharacterAbilityMenuEntry` 已作为能力菜单列表投影：已迁移普攻条目只暴露 `formalGasAbilityCode`、GAS 名称、GAS 描述和 GAS 图标解析结果；已删除的旧能力表不再作为任何普攻菜单展示或选择真相；未迁移能力必须进入 EX-GAS 表达或保持为待迁移缺口。
- `FormalGasAbilityDescriptionGeneratedRuntime` 的能力、时间轴和 GameplayEffect 查询已改成安全查询；缺失 GAS ID 时返回解析失败或 GAS 占位显示，不再抛异常，也不回退已删除的旧能力表字段。
- 技能描述的术语读取已改为同一份 `GameConfig` 的安全入口：运行时优先使用当前 `GameManager.Config`，编辑器资产检查没有运行时 `GameManager` 时回退读取正式 `Assets/GameData/GameCore/GameConfig.asset`；未配置术语时显示可读中文回退，不再把 `[INVALID_SHORTNAME]` 暴露给策划。
- `AbilityBase` 不再暴露旧能力表身份投影；正式 GAS 基础攻击实例身份只能来自 EX-GAS Ability Code。
- `CharacterAbilitySet` 按 GAS Ability Code 解析正式运行实例时，已拆成 `TryGetResolvedFormalGasActiveAbility(...)`，不再通过返回 `ActiveAbilitySheet`（已删除） 空 out 参数复用旧表解析接口；已删除的旧主动能力表解析入口已删除。
- `CharacterEquippedAbilityLoadout.RestoreFromSlotData(...)` 已改为 `formalGasAbilityCode` 优先；混合旧存档槽位不能再先解析已删除的旧主动能力表后把已迁移普攻恢复成旧表槽位。

### 2. 基础攻击多边形命中范围现在能在 GAS 时间轴预览和编辑

当前 `TaskApplyEffects.OnEditorPreview(...)` 会转发到 `CatchAreaPolygon2D.OnEditorPreview(...)`，并由项目侧 SceneView 扩展在原 EX-GAS 时间轴窗口选中该 Task 时显示可拖拽顶点。

效果：

- 在 EX-GAS 时间轴编辑器选择对应 Timeline。
- 绑定预览对象。
- 拖到 `TaskApplyEffects` 所在命中帧。
- 编辑器用多边形范围显示当前 `CatchAreaPolygon2D` 命中轮廓；可拖中心点移动整体多边形，拖顶点改轮廓，右键插入或删除顶点。

这不是项目自造工作台，也不是场景子物体碰撞盒真相；它是 EX-GAS Timeline Task 自己的 `TargetCatcher` 参数预览和编辑。

### 3. 基础攻击动画表现已进入 GAS Timeline

当前基础攻击 Timeline 已有动画轨道：

- Task：`TaskPlayCue`
- Cue：`CuePlayGameCoreAnimator`
- 参数：`AnimatorNodePath = ""`，`AnimationName = "Attack"`

`AnimatorNodePath` 为空时，项目侧 `CuePlayGameCoreAnimator` 会把 `AnimationName` 当作装备系统动作键。基础攻击使用 `Attack`，蓄力释放使用 `ChargedAttack`；角色动作由角色层播放，武器攻击和武器自带特效由装备/武器层同一动作承载。`EquipmentSystemDemo` 默认装备已接到带 `Attack` 武器序列帧的 `长矛`，用来验收“角色动作分离、武器攻击和特效同属武器序列帧”的素材组织。`Attack` / `ChargedAttack` 现在被视为必须进入装备系统的动作键：如果装备系统不能播放这些动作，运行时会拒绝回退普通角色 `Animator` 并输出警告，避免角色动作与武器攻击/特效脱节。不再覆盖 EX-GAS 内置 `CuePlayAnimator`，也不再依赖 `MeleeAbilityExecutionAsset`（已删除） 里的旧动画触发字段。

当前已经证明“基础攻击动画表现”和“基础攻击命中反馈”都走 EX-GAS Cue；项目正式音频 Cue 桥已经接入生成链，但基础攻击正式音效资源尚未选择和配置，特效和其它受击表现也尚未全部配置完成。

当前还补齐了正式 GAS 技能的旧反馈门禁：基础攻击不再从已删除的旧执行资产 播放打断、换弹不足、换弹开始或换弹完成反馈。项目侧旧执行资产反馈路径已删除；正式 GAS 基础攻击的这些表现需要继续通过 `TaskPlayCue` 或 GameplayEffect Cue 配置。

当前还补了一个开发期诊断：`CuePlayGameCoreFeedback` 触发后，如果目标 `GameplayFeedbackSet` 对应槽位没有配置 MMFeedbacks，会在编辑器/开发构建里给出明确警告。这不等于已经补了音效或特效资产，只是让策划能区分“Cue 链路没走通”和“正式反馈槽位还没配表现资产”。

角色资产 Inspector 也已前移同类提示：`HeroSheetEditor` 和 `MonsterSheetEditor` 会在角色正式 `GameplayFeedbackSet.HitDamageable` 槽位为空时提示策划补角色反馈资产，而不是回到旧近战执行资产补第二套反馈。

当前还补了正式 GAS 近战配置审计：`FormalAbilityAssetValidation` 会读取 EX-GAS 生成 JSON，并只沿当前基础攻击自己的 Timeline / GameplayEffect Cue 链路判断是否存在可用的 `CuePlayGameCoreAudio` / `CuePlaySound`。对 `CuePlayGameCoreAudio`，校验器不再只看类型名，必须同时满足 `AudioResolverGuid` 非空、且能从正式 `GameConfig.asset` 的数据库注册表解析到 `AudioClipResolver`。`CueMountPrefab` 不再是当前普攻完成门槛；如果未来把正式独立特效素材拆出，才作为明确新增 Cue 接入，并且仍必须满足 `PrefabPath` 能加载到真实 Prefab。

当前还补了项目正式音频 Cue 桥：`CuePlayGameCoreAudio` 只从 EX-GAS Cue 接收 `AudioResolverGuid`，运行时通过 `GameManager.Database.GUIDToDatabaseEntry<AudioClipResolver>(...)` 找到项目音频资源，再发布 `GameRuntimeEvents.RequestAudioPlayback(...)` 交给 `AudioSystem`。缺少 `AudioResolverGuid` 或 GUID 解析不到 `AudioClipResolver` 时，编辑器/开发构建会给出明确警告，避免“有 Cue 但没声音”被误判成链路没触发。这避免基础攻击回到迁移期 `ActiveAbilitySheet.fireAudio`，也避免直接使用 EX-GAS 内置 `CuePlaySound` 绕过项目 `AudioClipResolver` 闭包。当前仓库只发现 UI/交互类 `Assets/Database/Audio/ISFX/*.asset`，未锁定可作为基础攻击出手音效的正式资源，所以暂不写入 EX-GAS 表数据。

当前也补了 `CuePlayAnimator.OnPreview` 的安全采样：

- 缺预览对象、缺 `Animator`、缺 `RuntimeAnimatorController` 或找不到 `AnimationName` 时，会给出明确编辑器警告。
- 命中零长度帧段时不再除以 0，而是按最小 1 帧计算采样比例。
- 预览采样只在需要时进入 Unity `AnimationMode`，继续服务 EX-GAS Timeline 的动画预览。

当前还补了 `CatchAreaPolygon2D` 的 2D 朝向解析：

- GAS 运行时新增 `IGas2DFacingProvider`，由项目角色移动基类 `Movable` 暴露当前 2D 目标朝向。
- `CatchAreaPolygon2D` 运行时捕获和编辑器预览共用同一套相对位姿解析；当来源对象实现 `IGas2DFacingProvider` 时，用角色朝向旋转本地点。
- 对未实现该接口的对象，仍回退到原有 Transform 位置/旋转逻辑，避免破坏插件默认 3D/Transform 用法。

这解决的是基础攻击命中盒随俯视角 2D 角色朝向旋转的问题。当前已重新取得 EX-GAS 时间轴截图证据：`Temp/CodexEvidence/refactor-melee-ability-authoring/ex-gas-timeline-basic-attack-window-readable.png`。

### 4. EX-GAS 时间轴编辑器继续使用插件原生窗口

当前 `AbilityTimelineEditorWindow` 在打开预览场景前会检查 dirty 场景，并调用保存入口。

目标：

- 避免时间轴编辑器 `NewScene/OpenScene` 触发 Unity 保存弹窗。
- 避免自动化或人工流程卡在保存确认框。

这只解决“切预览场景前不弹保存确认框”的问题，不等于所有 Unity 场景自动保存策略都已完成。

时间轴导航/观感增强不再计入当前主线完成项。曾验证过的复位视图、定位当前帧、鼠标锚点缩放、时间尺横向平移、只读视野范围条和 clip 靠边自动滚动已撤回为可选优化候选，原因是它们会改变 GAS 插件原生窗口观感；后续是否采用需要单独 UI/体验评审。

当前可确认的正式方向是：继续使用 EX-GAS 原生 `AbilityTimelineEditorWindow`、原生预览闭包和项目侧已验证的 GAS Timeline / Cue 数据，不新增项目工作台，不新增第二套技能时间轴，也不修改 `XParamTimeline` / Excel / Luban 的正式作者数据。

第三方插件边界：`Assets/Plugins/GAS` 按 EX-GAS 2.0 上游包处理，当前 change 不允许继续直接修改插件源码、UXML、USS、图标或生成器本体。若发现 EX-GAS 原生行为问题，只能记录为上游 patch 候选或项目侧公开扩展点适配；真正修改插件源码需要用户另行明确批准 fork patch。

### 5. 项目自造近战时间轴已撤回

已完成：

- 删除 `Assets/Editor/GameCore/EditorWindows/MeleeAbilityTimelineWindow.cs`
- 删除 `Assets/Editor/GameCore/EditorWindows/MeleeAbilityTimelineWindow.cs.meta`
- 删除 `MeleeAbilityExecutionAssetEditor` 上的人类可见“打开近战时间轴”按钮
- 删除项目侧 `Assets/Editor/GameCore/Editors/MeleeAbilityExecutionAssetEditor.cs` 和 `.meta`
- 扫描技能线残留，未发现新的基础攻击工作台、准备链路、修复接线或判定资产入口

原因：

- 该窗口与 EX-GAS `AbilityTimelineEditor + XParamTimeline + TargetCatcher/Task` 争夺同一职责。
- 继续保留会形成第二套近战时序和命中框作者真相。
- 当前没有证据证明项目自造窗口优于改造 GAS 时间轴。

### 6. 当前仍存在的旧兼容边界

项目侧 `MeleeAbilityExecutionAssetEditor`、`DashAbilityExecutionAssetEditor`、`ProjectileAbilityExecutionAssetEditor` 和 `SummoningAbilityExecutionAssetEditor` 均已删除。`DashAbilityExecutionAsset`、`ProjectileAbilityExecutionAsset`、`SummoningAbilityExecutionAsset` 本体也已删除；旧执行资产类型已全部删除，不再作为未迁移旧近战技能、存量测试或旧数据升级线索存在，也不再有人类可见自定义作者面。

对已迁移基础攻击，旧能力表类型和旧执行资产类型已删除，不再显示、创建或保留迁移期运行壳；基础攻击的正式前摇、后摇、输入触发、输入缓冲、松手中断、本地连发、弹匣门控、命中窗口、命中框、伤害、背刺和反馈只来自 EX-GAS。

旧能力表本体已删除：`AbilitySheet`（已删除）、`ActiveAbilitySheet`（已删除）、`PassiveAbilitySheet`（已删除） 及其旧字段不再承担旧资产读取或正式 GAS 能力作者入口。

当前编辑器提示与校验口径已同步到 EX-GAS 主轴：

- 项目侧 `AbilitySheetEditor` 已删除；不得再通过已删除的旧能力表Inspector 维护技能身份、图标、输入、消耗、冷却、命中、伤害或表现时序。
- 旧执行资产自定义 Inspector 已删除；已迁移能力不再存在项目侧旧执行资产 Inspector 作者入口。
- `FormalAbilityAssetValidation` 对已迁移 EX-GAS 的近战技能，会把旧执行资产字段解释为旧兼容残留，并提示正式目标筛选、命中框、伤害和背刺应回到 EX-GAS Timeline / GameplayEffect。
- `MeleeAttackAbility`、`MeleeAttackAbilitySheet`（已删除）、`FormalAbilityAssetValidation` 和相关 EditMode 测试中的残留文案已清理：`MeleeAbilityExecutionAsset` 已删除，相关文案不再称其为基础攻击正式执行资产或未迁移兼容入口。

对尚未迁入 EX-GAS 的旧技能，旧资产字段仍可被反序列化和审计，但不再提供项目侧自定义编辑器来继续扩张旧作者流。
- 目标层和命中重复提示

限制：

- 不再把它称为正式技能编辑器。
- 不再把它写进基础攻击正式制作主流程。
- 后续如果同职责字段已完全迁入 GAS Timeline，应继续降级或删除。

### 7. EX-GAS 原始配表工程已进入导表闭环

当前仓库已经存在：

- `EX_GAS_Config/ProjectConfigTable/exgas_config`
- `EX_GAS_Config/ProjectConfigTable/exgas_config/Datas/#exgas.ability.xlsx`
- `EX_GAS_Config/ProjectConfigTable/exgas_config/Datas/#exgas.timelineAbility.xlsx`
- `EX_GAS_Config/ProjectConfigTable/exgas_config/gen.bat`
- `Assets/Scripts/Gen/XAbility.gen.cs`
- `Assets/Scripts/Gen/XLuban.gen.cs`

因此“完全缺少原始配表工程”的旧结论已经过期。

当前已完成从 `#exgas.timelineAbility.xlsx` / `#exgas.gameplayEffect.xlsx` 到 `Assets/DataGenerated/Luban/Json/GAS` 的导表回归：

- 原始 Excel 中 Timeline `101` 已保存为 `TaskPlayCue -> CuePlayGameCoreAnimator`、`TaskDoCost`、`TaskApplyEffects -> CatchAreaPolygon2D`。
- 原始 Excel 中 GameplayEffect `2003` 已保存为 `FormalDamage`，不再靠基础攻击旧执行资产描述伤害。
- Luban 导表产物与正式 Unity JSON 已一致。
- `TaskPlayCue` 的 `RequiredTags` / `ImmunityTags` 在 JSON 中显示为 `[0]`，这是 EX-GAS 流式 Excel 配置对空标签的占位表达，不是正式标签。
- `TagHelper.FilterInvalidTags` 已过滤 `null`、空数组和 `<= 0` 的标签，运行时会把 `[0]` 收口为真正空标签。

### 8. 背刺已进入 GAS Effect 条件表达

背刺不再写在基础攻击正式路径的项目侧 `TaskMeleeHit2D` 里。

当前 `TaskMeleeHit2D` 清退结果：

- 基础攻击正式 Timeline `101` 只使用 EX-GAS `TaskApplyEffects + CatchAreaPolygon2D`，不再由项目扩展 `TaskMeleeHit2D` 承载命中。
- `TaskMeleeHit2D` / `XParamMeleeHit2D` 已从项目侧运行时代码、生成注册代码、旧表反序列化兼容代码和 Luban 生成产物中清退；基础攻击、背刺和后续正式近战技能不得再回到该旧并行命中任务。
- 现有近战技能资产里，已迁移普攻的旧 `测试-基础攻击.asset` 已删除；变形替换 smoke 的旧 `测试-变形替换能力.asset` 也已删除，正式入口保留 EX-GAS Ability `20002`。已删除的旧执行资产只作为历史参考，不作为存量资产读取或蓄力模型入口。
- 蓄力释放已落地为 EX-GAS Ability `20004 ChargedAttackRelease`：运行配置来自 `exgas.abilityGameCore`，`InputTriggerMode = HoldRelease`，按下进入蓄力态，松手进入 Timeline `20004` 触发装备系统动作键 `ChargedAttack`，命中帧通过 `TaskApplyEffects + CatchAreaPolygon2D` 应用 `GameplayEffect 2004`；当前完成单档松手释放协议，后续不得恢复 `TaskMeleeHit2D` 作为过渡兼容入口。

当前正式表达为：

- `GameplayEffect 2003.FormalConditionalDamage`
- `ConditionKind = Backstab`
- `FacingDotThreshold = -0.35`
- 背刺附加伤害：物理平伤 `3`

运行时由 `SExecuteFormalDamageEffectsManaged` 在 GE 应用阶段读取 Source / Target 的角色朝向并判断背刺条件；条件满足时才执行附加正式伤害。验证覆盖：

- 目标背对攻击者时，基础攻击应用基础伤害 + 背刺附加伤害。
- 目标面向攻击者时，基础攻击只应用基础伤害。
- 两条路径都仍走同一个 `TaskApplyEffects + CatchAreaPolygon2D + GameplayEffect 2003`。

## 当前仍未完成

- 基础攻击动画已经走 `TaskPlayCue -> CuePlayGameCoreAnimator`，基础攻击命中反馈已经走 `GameplayEffect 2003 CueOnApply -> CuePlayGameCoreFeedback -> GameplayFeedbackSet`，背刺附加伤害已经走 `GameplayEffect 2003 + FormalConditionalDamage`。
- 音效、特效和其它受击表现还没有全部收口到唯一 Cue/Task 路径。
- 已完成正式资源缺口审计：当前数据库里可解析的 `AudioClipResolver` 主要是 UI / 交互类音效，尚未发现可直接作为基础攻击正式出手音效的项目侧素材；`Assets/Prefabs/Abilities/Melee/测试-基础攻击.prefab` 是能力预制体，不是正式特效 Prefab；TopDownEngine / MoreMountains demo 资源未完成职责裁决，不能冒充正式基础攻击素材。
- GAS 时间轴编辑器尚未补完整项目 2D 动画采样和角色姿态对齐。
- 2DRPGEngine / CLineActionEditor 的时间轴导航体验只保留为可选优化参考；相关 GAS 插件 UI/导航增强已撤回，不再作为当前完成项或验收证据。
- 基础攻击已清掉 `AbilitySheet.m_executionAsset` 旧引用；`MeleeAbilityExecutionAsset.inputGate` 不再提供基础攻击或蓄力释放的正式前摇、后摇、输入触发、输入缓冲、松手中断、本地连发或弹匣门控。旧执行资产字段已随类型删除；蓄力释放已经直接用 EX-GAS 表达。
- 当前蓄力攻击协议已落地到最小正式口径：单档 `HoldRelease`，按住进入蓄力态，松手释放；档位数、提前松手弱蓄力/取消分支、蓄力期间更细的移动/转向/打断策略和蓄力开始/蓄满反馈分组仍是后续深化项，不阻塞本轮 EX-GAS 主轴验收。

## 后续深化项

本轮已锁定并实现的蓄力协议是：单档松手释放。还没有纳入本轮完成口径的深化项如下：

1. 是否增加轻蓄/满蓄等多档。
2. 未达阈值提前松手时，是否打出弱蓄力、取消，或退回普通攻击。
3. 蓄力期间更细的移动、转向、受击打断策略。
4. 蓄力开始、蓄满、释放是否拆成独立 Cue/Feedback 表现节点。

这些属于下一阶段能力设计扩展，不再作为“基础攻击、背刺、单档蓄力释放迁到 EX-GAS 主轴”的阻塞项。

## 当前验证状态

已验证：

- Unity `assets-refresh` 成功。
- `FantasyWord.GameCore.Tests` EditMode 当前回归通过：`totalTests = 38`、`failedTests = 0`。
- `FormalGasAttack_DoesNotUseLegacyExecutionFeedbacks` 已验证正式 GAS 基础攻击不再播放迁移期执行资产 weapon-use feedback。
- `FormalGasAttack_DoesNotCreateLegacyHitWindowRuntime` 已验证正式 GAS 基础攻击不再创建项目侧旧命中窗口运行态，命中窗口不再由旧项目侧执行壳参与。
- `FormalGasAttack_DoesNotRequestProjectSideFireAudio` 已验证已接入 EX-GAS 的基础攻击不再通过 `ActiveAbilitySheet.fireAudio` 请求项目侧第二套出手音效，音效必须回到正式 Cue/Task 路径。
- `FormalGasAttackEditor_DoesNotProvideProjectSideAbilitySheetAuthoring` 已验证项目侧不再注册 `AbilitySheetEditor`，避免已删除的旧能力表Inspector 继续承担技能作者入口。
- `LegacyAbilitySheetValidation_DoesNotTreatLegacyFieldsAsFormalGasCueSource` 已验证已迁移普攻的旧 `MeleeAttackAbilitySheet`（已删除） 不再进入正式技能审计，且旧执行资产类型已删除；旧 `AbilitySheet.fireAudio` 和旧执行资产表现字段不会被当成 EX-GAS 正式 Cue 来源。
- `FormalGasAttack_DoesNotUseLegacyExecutionInterruptOrReloadFeedbacks` 已验证正式 GAS 基础攻击不再播放迁移期执行资产打断/换弹反馈。
- `FormalGasAttack_TriggersTargetHitFeedbackThroughGameplayCue` 已验证基础攻击命中反馈通过 GE `CueOnApply` 触发目标角色 `GameplayFeedbackSet`，且不回退到迁移期执行资产 feedbacks。
- `Fire_HitsTargetInsideHitbox_AndUpdatesFormalHealth` 已验证基础攻击通过 `TaskApplyEffects + CatchAreaPolygon2D + GameplayEffect 2003` 命中目标并同步正式生命值。
- `Fire_WhenTargetBackFacesAttacker_AppliesFormalGasBackstabBonus` 已验证目标背对攻击者时，`FormalConditionalDamage` 会追加背刺伤害。
- `Fire_WhenTargetFacesAttacker_DoesNotApplyFormalGasBackstabBonus` 已验证目标面向攻击者时，`FormalConditionalDamage` 不会追加背刺伤害。
- `CatchAreaPolygon2D_CatchesOnlyTargetsInsideAuthoredPolygon` 已验证正式多边形捕获能从子物体 Hitbox 找到父级 ASC、过滤施放者、去重，并避免外接盒粗筛误命中。
- `TaskApplyEffects_OnEditorPreviewWithoutCatcher_IsUpstreamPatchCandidate` 已验证 `TaskApplyEffects.OnEditorPreview()` 在未初始化 catcher 时仍会抛出空引用；该项只记录为 EX-GAS 上游可选补丁候选，当前不直接修改插件源码。
- Luban 从原始 Excel 导出的 `exgas_tbtimelineability.json` / `exgas_tbgameplayeffect.json` 与正式 Unity JSON 一致。
- `TaskPlayCue` 的 `[0]` 空标签占位已由运行时过滤，避免把占位值当作有效 GameplayTag。
- 编辑器作者提示和校验文案已清理，不再把 `TaskMeleeHit2D` 或 `MeleeAbilityExecutionAsset`（已删除） 说成已接入 EX-GAS 基础攻击的正式命中/伤害/背刺入口。
- 源码残留口径扫描已通过：不再出现把 `MeleeAbilityExecutionAsset`（已删除） 称为基础攻击正式执行资产的运行时报错、编辑器校验或旧路径测试断言。
- `CuePlayGameCoreFeedback` 缺反馈槽位诊断已通过 `FantasyWord.GameCore.Tests` EditMode 回归，未破坏基础攻击/GAS 流程。
- `CuePlayGameCoreAudio_RequestsGameCoreAudioPlayback` 已验证 EX-GAS GameCore 音频 Cue 能按数据库 GUID 解析 `AudioClipResolver`，并通过项目正式 `GameRuntimeEvents.RequestAudioPlayback` 进入 `AudioSystem` 闭包。
- `CuePlayGameCoreAudio_WarnsWhenAudioResolverGuidIsMissing` 已验证 `CuePlayGameCoreAudio` 缺少 `AudioResolverGuid` 时会给出开发期警告，而不是静默不播放。
- `CuePlayGameCoreAudio_WarnsWhenAudioResolverGuidCannotResolve` 已验证 `CuePlayGameCoreAudio` 的 GUID 无法解析到 `AudioClipResolver` 时会给出开发期警告，而不是静默不播放。
- `FormalGasAttackValidation_AcceptsGameCoreAudioCueAsFormalSoundCue` 已验证资产校验器能把 `CuePlayGameCoreAudio` 识别为正式音效 Cue，而不是只认可 EX-GAS 内置 `CuePlaySound`。
- `FormalGasAttackValidation_RequiresResolvableMountPrefabPath` 保留为未来独立特效 Cue 的门禁测试：只有 `CueMountPrefab.PrefabPath` 能加载到真实 Prefab 时才认可该独立 Cue；空路径或失效路径不会被误判为正式特效入口已完成。
- `FormalGasAttackCueValidation_DoesNotRequireIndependentPrefabCue` 已验证当前基础攻击不要求独立特效 Prefab Cue；角色动作和武器层分离，武器攻击与武器特效由装备/武器动作一起承载。
- `FormalGasAttackEquipmentMaterialChain_UsesWeaponAttackSequenceForBuiltInVfx` 已验证 `长矛` 配置了 `Attack` 武器序列帧，且 `EquipmentSystemDemo` 默认装备包含该武器，避免验收场景只播放角色动作而武器攻击/特效层断线。
- 正式音效/特效资源审计已生成文件化证据：`Temp/CodexEvidence/refactor-melee-ability-authoring/formal-gas-asset-audit.txt`。结论是当前只有 UI / 交互类音效可解析，基础攻击能力 prefab 不是特效 prefab，第三方 demo 资源未裁决前不能作为正式基础攻击表现素材。
- 攻击素材轻量预览已按安全读图流程查看：`Temp/CodexEvidence/attack-sprites/attack-sprites-contact.png`。当前素材组织是角色动作和武器层分离，武器攻击与武器自带特效同属装备/武器动作；基础攻击表现口径改为 EX-GAS Timeline 触发装备动作键 `Attack` / `ChargedAttack`，不套用 TopDownEngine 武器漂浮攻击模式，也不把“未配置独立特效 prefab”当作普攻视觉主阻塞。
- 能力系统口径已重新裁决：TopDownEngine / 项目旧 `Ability` 只能作为行为参考；正式能力必须用 EX-GAS Ability、Timeline、GameplayEffect 和 Cue 重新表达，不得混用 TopDown `CharacterAbility` / `Weapon` 或项目侧 `ActiveAbilitySheet`（已删除） 运行时作为正式能力系统。
- 内置 `CuePlayAnimator` 不再被项目侧重注册覆盖；项目装备动画桥改为显式 `CuePlayGameCoreAnimator`，符合 EX-GAS 自定义 Cue 进入配置和生成映射的方式。
- `HeroSheetEditor` / `MonsterSheetEditor` 角色反馈槽位提示已通过 `FantasyWord.GameCore.Tests` EditMode 回归，未破坏基础攻击/GAS 流程。
- `FormalGasAttackDescription_UsesGasTableWithoutRuntimeGameManager` 已验证编辑器资产检查没有运行时 `GameManager` 时，基础攻击描述仍从 EX-GAS 正式表生成基础伤害与背刺附加伤害，且不显示 `[INVALID_SHORTNAME]`。
- `MigratedAbilitySheet_DoesNotResolveGasIdentityAsLegacyAssetDisplay` 已验证已删除的旧能力表本体不再替 GAS 解析显示名或描述；同一测试也验证已迁移普攻的菜单投影仍会按 GAS Ability Code 从 EX-GAS Ability `Name/Desc` 读取显示名和主描述。
- `FormalGasAbilityRuntimeConfigResolver` 现在用 `EFormalGasAbilityRootMode` 表达正式 GAS 挂载根节点；`FormalGasAttack_UsesFormalRuntimeConfigForPrefabAndRoot_NotLegacyAbilitySheet` 已继续验证正式基础攻击从 `exgas.abilityGameCore` 解析 Prefab 和 RootMode，而不是回读已删除的旧能力表字段或旧枚举。
- `FormalGasAttackRuntimeInstance_DoesNotInheritLegacyActiveAbilitySheetRuntimeShell` 已验证正式基础攻击实例不再继承旧 `ActiveAbility<MeleeAttackAbilitySheet>` 泛型运行壳，且 `旧能力表身份投影不存在`；运行身份只来自 EX-GAS Ability Code。
- `FormalGasAttackDescription_DoesNotUseLegacyAbilitySheetCostOrCooldown` 已验证已绑定 EX-GAS 的基础攻击即使旧 `AbilitySheet.manaCost` / `AbilitySheet.cooldown` 被填值，也不会把它们显示成正式消耗或冷却描述。
- `FormalGasAttack_DoesNotSynthesizeCostOrCooldownFromAbilitySheetFields` 已验证已绑定 EX-GAS 的基础攻击即使旧 `AbilitySheet.manaCost` / `AbilitySheet.cooldown` 被填值，也不会合成 GAS Cost/Cooldown，不会扣蓝、不会进入本地冷却，也不会阻断下一次出手。
- `FormalGasAttack_DoesNotUseLegacyAbilitySheetPermissionAsActivationGate` 已验证已绑定 EX-GAS 的基础攻击即使旧 `ActiveAbilitySheet.permission` 被设置为不允许触发，也不会再被旧项目侧权限字段阻断；正式激活门只能回到 EX-GAS Ability 的激活标签、消耗、冷却等规则。
- `FormalGasAttack_UsesGasTimelineExecutionGate_NotExecutionAssetTiming` 已验证正式 GAS 基础攻击的本地出手门控来自 EX-GAS Timeline，而不是已删除的旧执行资产 `delayBeforeUse` / `timeBetweenUses`。
- `FormalGasAttack_UsesFormalRuntimeConfigInputGate_NotLegacyAbilitySheetOrExecutionSettings` 已验证正式 GAS 基础攻击的输入触发、输入缓冲和松手中断当前来自 `exgas.abilityGameCore`，且不会继承已删除旧执行资产的本地连发、弹匣或输入配置；旧 `ActiveAbilitySheet.m_formalInputGate` 字段已不存在。
- `FormalGasAttack_UsesFormalInputLookDirectionGate_NotLegacyAbilitySheetField` 已验证正式 GAS 基础攻击的出手朝向更新当前来自 `exgas.abilityGameCore.UpdateLookAtDirectionOnFire`，不会再受旧 `ActiveAbilitySheet.updateLookAtDirectionOnFire` 影响；旧 `ActiveAbilitySheet.m_formalInputGate` 字段已不存在。
- `FormalGasAttack_UsesActivationOwnedAttackingTag_NotLegacyDisabledActions` 已验证正式 GAS 基础攻击活动期的移动、再次出手和更新瞄准方向锁定来自 EX-GAS `Event.Attacking` 激活标签，而不是旧 `ActiveAbilitySheet.disabledActionsWhileCasting` 字段；同时验证项目侧启动桥必须保留 EX-GAS 生成标签表，不能覆盖为空标签表。
- `FormalGasAttack_DoesNotRequireLegacyExecutionAssetForRuntime` 已验证基础攻击清掉 `AbilitySheet.m_executionAsset` 后，仍能只依赖 EX-GAS Ability/Timeline/GameplayEffect 正式数据命中并扣血。
- `FormalGasAttack_DoesNotUseLegacyCanInterruptAsActionInterruptGate` 已验证正式 GAS 基础攻击收到项目侧动作打断时会向 EX-GAS 提交取消请求，不再被旧 `ActiveAbilitySheet.canInterupt=false` 阻断。
- `FormalGasAttack_DoesNotUseLegacyOrientationModeToRotateAbilityObject` 已验证正式 GAS 基础攻击不会再用旧 `AbilitySheet.orientationMode` 旋转项目侧能力物体。
- `Fire_WhenBlockedTagAppearsDuringWindup_DoesNotApplyHitOrCooldown` 已验证前摇期间出现 EX-GAS 配置里的正式阻断标签时，项目侧正式入口会拒绝真正出手，不结算命中、不扣蓝、不启动冷却。
- `CharacterEquippedAbilityLoadout` / `CharacterAbilitySet` 已完成更多入口拆分验证：槽位数据新增 `formalGasAbilityCode`，运行时槽位优先按 GAS Code 触发/停止能力；角色组件附加能力新增 `m_additionalFormalGasAbilityCodes`；能力来源、能力运行时状态、读档恢复、临时授予/压制/替换效果、变形/感染规则和召唤附加能力按 GAS Code 保存、恢复或解释，不再为已迁移能力保存旧能力表引用；`AddOrRemoveAbility`、`ItemAddAbilityEffect`、`Equipment` 已验证可只凭 GAS Code 授予基础攻击，历史旧能力字段如果残留旧对象会被过滤或拒绝，不会升级成 GAS Code，也不会注册成旧运行时能力。正式规则绑定字典也已从已删除的旧主动能力表对象键迁到 ability code 键。正式 GAS 实例创建已删除项目侧旧表解析器和迁移缓存链：不再调用 `FormalGasAbilitySheetResolver`，也不再把已删除的旧能力表塞回运行时容器。这表示当前已迁移能力的身份根已经从 `AbilitySheet`（已删除） 拆出；全局旧 AbilitySheet 系统已删除，旧存档和存量资产读取不能再依赖旧能力表对象身份。
- `MeleeAttackAbilityEditModeTests` 已按新边界回归通过：`totalTests = 75`、`passedTests = 72`、`failedTests = 0`。覆盖点包括旧 `AddBonusAbility`、旧装槽 API、旧脚本命令、旧道具能力字段、装备旧能力数组、状态效果旧授予/压制字段、变形/感染旧能力字段、召唤旧附加能力字段，以及混合旧快捷槽数据恢复。
- `FormalGasQuickSlotRestore_PrefersGasCodeWhenLegacySheetReferenceAlsoExists` 已验证混合旧快捷槽数据同时包含 EX-GAS Ability Code 和已删除的旧主动能力表引用时，恢复结果仍以 EX-GAS Ability Code 为唯一槽位真相，`LegacySheet = null`。
- 本轮继续把运行时实例快照拆开：已删除的旧能力表快照已删除，正式 GAS 实例使用 GAS code 快照单独保存；近战 EditMode 回归通过 `totalTests = 73`、`failedTests = 0`，覆盖正式 GAS 菜单、快捷槽、保存、触发和旧技能兼容路径。
- 当前基础攻击 `Ability 20001` 尚未在 EX-GAS 表内配置 Cooldown；如果后续需要普攻冷却，必须在 EX-GAS Ability 表配置 `Cd/CdEffect`，不能回到 `AbilitySheet.cooldown`。如果后续需要“死亡、动作锁、剧情禁用”等能力激活阻断，也必须转成 EX-GAS 激活标签/条件或明确的薄输入桥，不得回到 `ActiveAbilitySheet.permission` 当正式规则。
- `CatchAreaPolygon2D_CatchesOnlyTargetsInsideAuthoredPolygon` 已验证多边形外目标不会被外接盒粗筛误判为命中。
- `FormalGasAttack_DoesNotRequestProjectSideFireAudio` 已验证已接入 EX-GAS 的基础攻击不会再走项目侧 `ActiveAbilitySheet.fireAudio` 第二音效入口；基础攻击自身仍缺可用的正式音效 Cue 配表与素材，不在本条中冒充完成。
- `FormalGasAttackEditor_DoesNotProvideProjectSideAbilitySheetAuthoring` 已验证项目侧不再提供已删除的旧能力表自定义作者面。
- `DatabaseWindow_DoesNotExposeLegacyAbilitySheetsAsFormalAuthoringTabs` 已验证正式数据库窗口不再暴露`AbilitySheet` / `ActiveAbilitySheet` / `PassiveAbilitySheet`（均已删除） 作者页签。
- `LegacyAbilityAssets_DoNotExposeCreateAssetMenusAsAuthoringEntry` 已验证旧技能资产和旧执行资产类型不再暴露 Unity `CreateAssetMenu` 新建入口，防止新能力继续从已删除的旧能力表/ `AbilityExecutionAsset`（均已删除） 开始制作。
- `LegacyAbilitySheetValidation_DoesNotTreatLegacyFieldsAsFormalGasCueSource` 已验证正式审计不再通过旧 `已删除的 AbilitySheet.executionAsset` / `ActiveAbilitySheet.fireAudio` 处理已迁移普攻；正式表现缺口只由 EX-GAS Timeline / GameplayEffect Cue 链路校验。
- `LegacyAbilityExecutionAssetEditors_DoNotExistAsProjectSideAuthoring` 已验证项目侧不再保留近战、冲刺、投射物、召唤旧执行资产自定义 Inspector，避免旧动画触发、旧出手节奏、旧命中窗口、旧命中框、旧伤害和旧反馈字段继续成为作者入口。
- `MigratedBasicAttackSheet_HasNoExpectedLegacyExecutionAssetOrRuntimeComponentMapping` 已验证 `FormalAbilityAssetValidation` 不再把 `MeleeAttackAbilitySheet`（已删除） 映射为必须绑定 `MeleeAbilityExecutionAsset`（已删除） 或实例化 `MeleeAttackAbility`；已迁移普攻的执行资产和运行组件只能从 EX-GAS Ability Code / `exgas.abilityGameCore` 进入。
- `LegacyAbilitySheetAssets_DoNotCarryStaleFormalGasAbilityCodeField` 已验证已删除的旧能力表资产不能再残留 `m_formalGasAbilityCode` 这类已删除 GAS 身份字段；`FormalAbilityAssetValidation` 会把同类残留视为职责错误，防止旧表 YAML 继续伪装成 GAS 身份来源。
- `FantasyWord.GameCore.Tests` EditMode 当前回归通过：新增音频 Cue、特效 Prefab 路径门禁和前摇阻断回归测试后 `totalTests = 38`、`failedTests = 0`。
- 近战运行时收口、正式表现 Cue 缺口校验、正式时间轴出手门控迁移、正式输入门控迁移、基础攻击旧执行资产引用清退、旧执行资产口径收口、项目侧出手音效第二入口运行时隔离、Inspector 旧执行资产/出手音效字段隔离、旧入口残留校验提示、音频 Cue 资源解析门禁、特效 Prefab 路径门禁、前摇期间正式阻断标签回归、已删除的旧能力表编辑入口撤除、以及当前已迁移能力旧字段不再升级成 GAS Code 的回归正在按本轮改动重新验证。
- EX-GAS 原生时间轴编辑器基础攻击预览窗口的可读截图证据已重新取得：`Temp/CodexEvidence/refactor-melee-ability-authoring/ex-gas-timeline-basic-attack-window-readable.png`。
- GAS 时间轴导航/观感增强已撤回为可选优化候选，当前工作区不再修改 `AbilityTimelineEditorWindow`、`TimerShaftView`、`TrackClipVisualElement` 或相关 UXML/USS/图标资源。
- 追加真实画面对照取证时曾生成错误前台截图，实际内容为 `BoardGame` 窗口，不是 Unity / EX-GAS 时间轴；该错误图片已删除，不能作为本 change 证据。随后 Unity Editor / Bridge 已恢复，并已用 `AbilityTimelineEditorWindow` 窗口句柄重新截图。
- 测试后 `Assets/Scenes/ClickMoveTest.unity` 保持 `isDirty = false`。
- `FormalGasChargedAttackRelease_UsesIndependentGasAbilityCodeAndTimeline` 已验证蓄力释放能力有独立项目侧常量 `FormalGasAbilityCodes.ChargedAttackRelease = 20004`，能从 `exgas.abilityGameCore` 加载 Prefab 和蓄力图标，配置为 `InputTriggerMode = HoldRelease`，并且 EX-GAS Ability、Timeline、GameplayEffect 生成 JSON 都包含独立 `20004/2004` 数据。
- `Fire_ChargedAttackRelease_HoldsUntilInputReleaseThenHitsThroughGasTimeline` 已验证蓄力释放能力按下时只进入 `Charging`，推进时间轴也不会提前扣血；松手后才进入 Timeline `20004` 的命中帧并应用 `GameplayEffect 2004` 正式伤害。
- `FormalAbilityAssetValidation.InspectFormalGasAbilities(FormalGasAbilityCodes.BasicAttack, FormalGasAbilityCodes.ChargedAttackRelease)` 当前返回 `Success = true`、`Issues = []`。
- 当前已新增项目侧 SceneView 命中范围手柄：在 EX-GAS 时间轴窗口选中 `TaskApplyEffects -> CatchAreaPolygon2D` 时，Scene 视图可拖中心点移动整体多边形、拖顶点调整轮廓、右键插入或删除顶点；数据仍回写同一个 GAS TargetCatcher 参数，并由 EX-GAS 时间轴原保存按钮持久化。运行时以外接盒粗筛加多边形精筛执行真实命中，不把预览图形当假判定。

尚未验证：

- EX-GAS 时间轴编辑器的基础攻击窗口截图已取得；策划完整使用体验和更细的真实画面对照仍未验收。
- 多档蓄力、提前松手弱蓄力/取消、蓄力开始/蓄满独立表现等深化流程；当前只完成单档 `HoldRelease` 正式流程。
- 出手/命中音效、未来拆分出来的独立特效 Cue，以及其它受击表现；当前武器攻击和武器自带特效随装备/武器动作承载，不作为独立 Cue 完成门槛。

## 下一步安全范围

下一步只做：

1. 基础攻击正式运行入口已经不再依赖 `AbilitySheet`（已删除） / `ActiveAbilitySheet`（已删除） 的身份、图标、Prefab、Root、输入、消耗、冷却、权限、动作锁、打断门、出手朝向或音效字段；这些旧字段已删除，正式 RootMode 也已从已删除的旧能力表枚举解耦。已装备槽、菜单列表、HUD 展示、触发/停止、角色附加能力、读档恢复、临时能力效果和正式规则绑定入口也已改为 GAS Ability Code / ability code 优先解析。项目侧 `AbilitySheetEditor` 和 `FormalGasAbilitySheetResolver` 已删除，已删除的旧能力表/ `AbilityExecutionAsset`（均已删除） 也不再暴露 Unity 新建菜单，不能承担已迁移能力的作者面、运行时反查入口或身份真相。
2. 基础攻击图标字段已迁入 `exgas.abilityGameCore`，菜单列表/快捷槽/HUD 都会从 GAS 图标路径解析；但当前尚未配置正式图标资源，不得为了补图标把 `AbilitySheet.m_icon` 扩回正式入口。
3. `PrefabPath` 当前在编辑器可由 `AssetDatabase` 解析，项目侧也已把资源加载器注册到 EX-GAS `GASResourceLoader`；但当前项目没有 `Assets/AddressableAssetsData`，不能宣称 Player 构建期 Addressables 资源闭环已完成。
4. 后续如果要做多档蓄力、弱蓄力、蓄满提示或提前松手取消，必须继续沿 EX-GAS Ability / Timeline / GameplayEffect / Cue 扩展，不得恢复旧能力表或旧执行资产。
5. 继续把近战出手/命中音效和其它受击表现接入 `TaskPlayCue` 或 GameplayEffect Cue 的唯一触发路径；未来若拆出独立特效素材，再新增独立 Cue，不回退旧能力表或旧执行资产。
6. 蓄力技能继续深化时必须沿用 EX-GAS Ability / Timeline / GameplayEffect / Cue 重新表达，不再读取或拆分已删除的旧执行资产；当前 `20004` 已证明单档松手释放链路，不等于多档蓄力设计已经完成。
7. `TaskMeleeHit2D` / `XParamMeleeHit2D` 已清退；蓄力技能进入正式范围时必须直接使用 EX-GAS Timeline / TargetCatcher / GameplayEffect，不得恢复项目侧第二套命中任务。
8. 继续补 GAS 时间轴编辑器的 2D 动画采样、角色朝向、命中盒编辑体验和真实画面对照；当前命中盒基础拖拽手柄已接入，但策划完整使用体验和截图验收仍需继续补证。
9. 继续把已验证的 `EX_GAS_Config` 导表链纳入后续技能配置流程，避免手改 Unity JSON。

不做：

- 复杂法术。
- 技能栏 UI。
- 职业、技能树、流派。
- 玩家炼金/节点配置。
- 新的项目自造工作台。

