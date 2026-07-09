# Tasks: refactor-melee-ability-authoring

## 1. Structure Realignment

- [x] 将近战技能配置、时间轴、命中、规则、表现五层按最新裁决对齐
  - [x] 已重新裁决：EX-GAS Ability 配置是正式技能配置/执行 owner；项目侧 `AbilitySheet`（已删除） / `ActiveAbilitySheet`（已删除） / `PassiveAbilitySheet`（已删除） 类型已删除；技能身份、图标、输入、执行配置、授予、装备、保存、规则和作者入口必须由 EX-GAS Ability Code / `exgas.abilityGameCore` / Timeline / GameplayEffect / Cue 承担
  - [x] 清退基础攻击对 `AbilitySheet`（已删除） 中冷却、消耗、出手音效、执行资产、描述伤害等同职责字段的正式依赖
  - [x] 已接入 EX-GAS 的基础攻击显示名和主描述只通过 GAS Ability Code 投影读取：`CharacterAbilityMenuEntry` / `CharacterEquippedAbilitySlotView` -> `FormalGasAbilityIdentityResolver` -> `FormalGasAbilityDescriptionGeneratedRuntime` -> EX-GAS Ability `Name/Desc`；`AbilitySheet.displayName` / `AbilitySheet.description` 本体已退回旧字段，不再替 GAS 解析身份
  - [x] 基础攻击 Prefab、AbilityRootMode、输入桥和本地输入门控已迁入 EX-GAS 项目侧扩展表 `exgas.abilityGameCore`，不再由 `AbilitySheet`（已删除） / `ActiveAbilitySheet`（已删除） 同职责字段承载正式配置；正式 RootMode 已使用 `EFormalGasAbilityRootMode`，不再复用旧 `AbilitySheet.EAbilityOrientationMode`
  - [x] 基础攻击装备槽、菜单列表、HUD 展示和玩家触发入口已改为 GAS Ability Code 优先：`CharacterAbilitySlotData.formalGasAbilityCode` / `CharacterEquippedAbilityLoadout` 内部槽位先保存并解析 `formalGasAbilityCode`，历史槽位数据如果同时带 GAS Code 和旧主动能力表引用，只能迁移为 GAS Code 槽位或记录迁移缺口，不能恢复旧对象；`CharacterAbilityMenuEntry` / `CharacterEquippedAbilitySlotView` 按 GAS Code 投影名称、描述和图标，`FireEquippedAbilityAtIndex` / `StopFireEquippedAbilityAtIndex` 优先按 GAS Code 查找运行时能力实例；`ActiveAbilitySheet`（已删除） 类型已删除，未迁移技能不能继续依赖旧能力表视图
  - [x] 已迁移普攻的菜单列表和装备选择入口不再暴露已删除的旧能力表作为展示或选择真相；缺失 GAS 身份配置时只显示 GAS 占位，不回退旧字段
  - [x] `AbilitySheet` / `ActiveAbilitySheet` / `PassiveAbilitySheet`（均已删除） 类型和字段已删除；不得再以 `m_legacy*` 旧表字段保留技能身份、图标、Prefab、RootMode、Cost、Cooldown、权限、动作锁、打断门、出手朝向或出手音效作者入口
  - [x] 角色能力来源记录和能力运行时状态已新增 `formalGasAbilityCode` 正式字段；已迁移能力的新保存数据只写 GAS Ability Code，不再写旧能力表引用；历史存档兼容必须另走显式迁移数据或直接迁到 EX-GAS Ability Code
  - [x] 角色运行时能力容器只以 EX-GAS Ability Code 枚举和保存正式 GAS 实例；旧能力表实例快照已删除，正式 GAS 保存只写 `formalGasAbilityCode`
  - [x] 脚本命令、道具授予、装备授予、角色组件附加能力、读档恢复、能力型临时效果、变形/感染规则入口已改成 GAS Ability Code 优先；`AddOrRemoveAbility`、`ItemAddAbilityEffect`、`Equipment`、`CharacterAbilitySet.m_additionalFormalGasAbilityCodes`、`TemporalAbilityGrant/Suppression/ReplacementEffect`、`CharacterAlterationRule` 可以只凭 GAS Code 授予/撤回/压制能力；历史数据里的旧能力字段只能作为迁移输入，迁移结果必须是 EX-GAS Ability Code 或明确失败记录；项目侧 `FormalGasAbilitySheetResolver` 已删除，已迁移能力不再反向解析旧表；旧 `SummoningAbilityExecutionAsset` 已删除，不再作为召唤能力兼容入口
  - [x] 正式规则绑定表已从旧主动能力表对象键迁移到 ability code 键；正式能力使用 EX-GAS Ability Code，未迁移能力必须重新表达为 EX-GAS 数据或记录为待迁移缺口
  - [x] 已删除会把装备槽 GAS 能力反向解析成已删除的旧主动能力表的触发/停止旧 out 参数接口；已迁移能力的玩家失败事件、快捷槽 UI 和 HUD 槽位只通过 GAS Ability Code 投影，已删除的旧主动能力表入口已删除，未迁移能力必须重新表达为 EX-GAS Ability 或单独记录为待迁移缺口
  - [x] 已修正快捷槽读档恢复优先级：混合旧数据里如果 `formalGasAbilityCode` 和旧 `ability` 引用同时存在，恢复结果必须是 EX-GAS Code 槽位，旧引用不得抢回已迁移能力身份
  - [x] 图标字段已在 `exgas.abilityGameCore` 保留，菜单列表/快捷槽/HUD 已改为从 GAS 图标路径解析；基础攻击 `Ability 20001` 已配置临时正式图标 `HumanBaseAttack.png` 到 `IconPath/IconGuid`，不得为了补图标把 `AbilitySheet.m_icon` 扩回正式入口
  - [x] TopDownEngine / 项目旧 `Ability` 行为已由 EX-GAS Ability、Timeline、GameplayEffect 和 Cue 重新表达；当前正式链路不混用 TopDown `CharacterAbility` / `Weapon` 或项目侧 `ActiveAbilitySheet`（已删除） 运行时作为正式能力系统
  - [x] 规则结算已继续收口到 `EX-GAS`
  - [x] 主动技能 Mana Cost 只允许由 `EX-GAS CAbilityCost` 扣减；当前基础攻击 `Ability 20001` 表内 `Cost = 0`，不再由 `AbilitySheet.manaCost` 合成 Cost
  - [x] 主动技能 Cooldown 只允许由 `EX-GAS CAbilityCooldown + GrantedTags` 阻断；当前基础攻击 `Ability 20001` 表内 `Cd = 0 / CdEffect = 0`，不再由 `AbilitySheet.cooldown` 合成 Cooldown
  - [x] 已接入 EX-GAS 的基础攻击不再使用 `AbilitySheet.permission` 作为正式激活门；阻断只能回到 EX-GAS Ability 的激活标签/消耗/冷却等正式规则
  - [x] 已接入 EX-GAS 的基础攻击不再使用 `ActiveAbilitySheet.disabledActionsWhileCasting` 作为正式动作锁；攻击活动期动作锁由 EX-GAS `Ability 20001.ActivationOwnedTags = Event.Attacking(3003)` 进入角色 ASC 标签后解释
  - [x] 已确认 EX-GAS 存在 `XParamTimeline / Track / TaskClipData`
  - [x] 已确认 EX-GAS 存在 `TaskApplyEffects + TargetCatcher`
  - [x] 已确认 EX-GAS 存在 `TaskPlayCue + GameplayCue.OnPreview`
  - [x] 已撤回项目自造 `MeleeAbilityTimelineWindow` 的人类可见入口
  - [x] 基础攻击已迁入 EX-GAS Timeline：普攻不再保留已删除的旧能力表身份根；正式授予、创建、装备、触发、保存和规则绑定均按 `Ability 20001 -> ALTimeline 101` 的 GAS Ability Code 执行
  - [x] 当前仓库已存在基础攻击运行所需的 EX-GAS 生成 JSON/C# 产物
  - [x] 当前仓库已存在 EX-GAS 原始配表工程（`EX_GAS_Config/ProjectConfigTable/exgas_config`）和 `XAbility/XLuban` 生成产物
  - [x] `MeleeAbilityExecutionAsset`（已删除） 已从项目侧运行时和资产结构中删除
  - [x] 基础攻击 `AbilitySheet`（已删除） 已删除执行资产字段，正式运行不再存在 `已删除的 AbilitySheet -> AbilityExecutionAsset` 路径
  - [x] 项目侧 `AbilitySheetEditor` 已删除，`DatabaseWindow` 也不再暴露已删除的旧能力表页签；绑定正式 GAS Ability 的基础攻击不再通过已删除的旧能力表自定义 Inspector 或正式数据库窗口维护作者入口
  - [x] `AbilitySheet` / `ActiveAbilitySheet` / `PassiveAbilitySheet`（均已删除） 类型已删除；`AbilityExecutionAsset`（已删除） / `MeleeAbilityExecutionAsset`（已删除） 已删除，不能继续作为新技能作者入口
  - [x] 基础攻击动画表现已映射到 `TaskPlayCue -> CuePlayGameCoreAnimator`，不再由迁移期执行资产 feedbacks 触发；该 Cue 只下发装备动作键，角色动作和武器攻击序列分开播放
  - [x] `MeleeAbilityExecutionAsset` 中同职责序列化字段已随旧执行资产类型删除
  - [x] `GameplayCue` / `GameplayFeedbackSet` 的唯一桥接方式已落地：基础攻击命中反馈走 `GameplayEffect 2003 CueOnApply -> CuePlayGameCoreFeedback -> GameplayFeedbackSet`

## 2. Melee Model Landing

- [x] 将基础攻击从迁移期旧执行资产模型迁到 EX-GAS Timeline 模型
  - [x] 当前基础攻击迁移期旧执行资产模型已删除，不再保留兼容路径
  - [x] 背刺当前已复用迁移期同一近战模型
  - [x] 基础攻击时序已映射为 `XParamTimeline` / Timeline `101`
  - [x] 基础攻击最小近战判定参数已改成 EX-GAS 标准 `XParam + BeanField` 形态，具备进入 Bean/Luban 管线的前提
  - [x] 基础攻击真实判定已迁到 EX-GAS `TaskApplyEffects + TargetCatcher` 扩展点，当前由项目侧非侵入 `CatchAreaBox2D` 提供 2D 盒形捕获
  - [x] 基础攻击命中后效果已通过 `GameplayEffect 2003 + FormalDamage` 进入正式伤害链
  - [x] 基础攻击动画表现已通过 Timeline `TaskPlayCue` 播放项目侧自定义 `CuePlayGameCoreAnimator`，不再覆盖或依赖 EX-GAS 内置 `CuePlayAnimator`
  - [x] 基础攻击已改成 EX-GAS `TaskApplyEffects + TargetCatcher` 组合，并由项目侧 `CatchAreaBox2D` 承载 2D 真实判定；不再由项目扩展 `TaskMeleeHit2D` 承载基础攻击命中
  - [x] 基础攻击命中反馈已映射为 GE Cue：`CueOnApply 20001 -> CuePlayGameCoreFeedback`
  - [x] 背刺附加伤害已迁入 `GameplayEffect 2003 + FormalConditionalDamage`，不再由基础攻击正式路径的 `TaskMeleeHit2D` 判断
  - [x] 基础攻击作者描述已改为从 EX-GAS Ability/Timeline/GameplayEffect 正式表生成，不再从旧 `MeleeAbilityExecutionAsset.damageSettings` 读取正式伤害说明
  - [x] 基础攻击作者描述不再从 `AbilitySheet.manaCost` / `AbilitySheet.cooldown` 追加消耗或冷却；当前 `Ability 20001` 无 Cost/CD，因此描述只显示 EX-GAS 表里的伤害内容
  - [x] `MeleeAttackAbilitySheet` 类型已删除；基础攻击不再存在旧表描述生成路径，普攻说明文本只能由 EX-GAS Ability / Timeline / GameplayEffect 生成
  - [x] 基础攻击出手节奏门控已由 EX-GAS Timeline 派生：首个玩法 Task 帧决定本地出手前摇，Timeline `LifeTime` 决定本地后摇门控；已删除的旧执行资产 `delayBeforeUse` / `timeBetweenUses` 不再决定正式 GAS 基础攻击出手点
  - [x] 项目正式音频 Cue 桥已接入生成链，但当前基础攻击不配置临时出手/命中音效；正式音效素材选定后只能通过 Timeline `TaskPlayCue` 或 GameplayEffect Cue 接入，不回退旧能力表
  - [x] 基础攻击表现口径已改为角色动作和武器层分离：EX-GAS Timeline 只触发装备动作键 `Attack`，角色动作由角色层播放，武器攻击和武器自带特效由装备/武器层同一动作承载；`EquipmentSystemDemo` 默认装备已接到带 `Attack` 武器序列帧的 `长矛`；当前不再把独立特效 `CueMountPrefab` 当作普攻完成条件
  - [x] 蓄力释放能力已落地为独立 EX-GAS Ability `20004 ChargedAttackRelease`：数据从原始 Excel 导出到 Unity JSON，运行时通过 `InputTriggerMode = HoldRelease` 按下进入蓄力、松手释放，再由 Timeline `20004` / `TaskApplyEffects` / `CatchAreaBox2D` / `GameplayEffect 2004` / Cue 路径命中目标；当前完成单档松手释放协议，蓄力档位和提前松手分支仍按后续深化处理

## 3. Runtime Realignment

- [x] 将近战运行时执行主轴从项目壳迁到 EX-GAS Timeline
  - [x] 旧角色表、旧附加能力列表和旧授予/压制 API 如果收到已删除的旧能力表，只能按旧数据读取或拒绝旧表路径，不能再提升成 GAS Ability Code；正式授予、压制、装备、触发和保存必须显式使用 GAS Ability Code
  - [x] 当前命中结果已进入 EX-GAS 正式规则链
  - [x] 输入缓冲/自动重复出手前的 EX-GAS 激活门已覆盖
  - [x] 基础攻击真实出手点已有 EX-GAS 二次提交保护
  - [x] 基础攻击已由 `ALTimelinePlayer` 推进
  - [x] 基础攻击已由 EX-GAS `TaskApplyEffects + TargetCatcher` 调用项目侧 `CatchAreaBox2D` 捕获目标并应用 `GameplayEffect 2003`
  - [x] 绑定正式 GAS Ability 的基础攻击已从 `MeleeAttackAbility` 删除项目侧旧命中窗口运行态字段和旧近战执行分支，避免旧项目侧执行壳继续参与正式命中判定
  - [x] `ALTimelinePlayer.Stop()` 已只结束真正开始过且尚未结束的 Task，避免未开始 Cue 在收尾时误报
  - [x] 绑定正式 GAS Ability 的基础攻击已停止项目壳直接播放同一动画/weapon-use feedback
  - [x] 基础攻击已改成内置 `TaskApplyEffects` 捕获目标并应用配置表 GameplayEffect
  - [x] 绑定正式 GAS Ability 的基础攻击已停止从迁移期执行资产读取前摇/后摇作为正式出手节奏；本地门控设置由 `FormalGasAbilityTimelineExecutionResolver` 从 EX-GAS Timeline 注册结果派生
  - [x] 绑定正式 GAS Ability 的基础攻击已停止从迁移期执行资产读取输入触发、输入缓冲、松手中断、本地连发和弹匣语义；这些本地输入门控已迁到 `exgas.abilityGameCore`
  - [x] 绑定正式 GAS Ability 的基础攻击已停止从旧 `ActiveAbilitySheet.updateLookAtDirectionOnFire` 读取出手朝向更新；该本地瞄准语义已迁到 `exgas.abilityGameCore.UpdateLookAtDirectionOnFire`
  - [x] 绑定正式 GAS Ability 的基础攻击已停止从旧 `ActiveAbilitySheet.disabledActionsWhileCasting` 禁用/恢复角色动作；移动、再次出手和更新瞄准方向的攻击期锁定由 EX-GAS `Event.Attacking` 激活标签驱动
  - [x] 项目侧 `FormalAbilityRuntimeBootstrap` 已改为初始化 EX-GAS 生成标签表 `XTag.InitTagList()`，不再用空标签表覆盖生成标签，确保 `Event.Attacking` 等正式标签能被 `ASC.HasTag(...)` 正确匹配
  - [x] 绑定正式 GAS Ability 的基础攻击已移除 `AbilitySheet.m_executionAsset` 旧引用，运行时只依赖技能资产、EX-GAS Ability/Timeline/GameplayEffect 和正式 Cue
  - [x] 绑定正式 GAS Ability 的基础攻击已停止读取 `ActiveAbilitySheet.permission` 作为正式激活门，避免旧项目侧权限字段继续与 EX-GAS 激活规则形成第二套门控
  - [x] 基础攻击命中反馈已通过唯一 GE Cue 路径消费结果，不再回退到迁移期执行资产 feedbacks
  - [x] 绑定正式 GAS Ability 的基础攻击已停止从迁移期执行资产播放打断/换弹反馈，避免旧执行资产继续形成第二表现入口
  - [x] 背刺条件已转换为 GAS Effect 条件表达：`FormalConditionalDamage.ConditionKind = Backstab`
  - [x] `CuePlayGameCoreFeedback` 已能在开发/编辑器环境提示“Cue 已触发但目标 `GameplayFeedbackSet` 未配置对应 MMFeedbacks”，避免表现缺失被误判为 Cue 链路没走通
  - [x] `HeroSheetEditor` / `MonsterSheetEditor` 已提示角色正式 `GameplayFeedbackSet.HitDamageable` 未配置，避免策划回到旧近战执行资产补第二套反馈
  - [x] 技能描述生成已支持无运行时 `GameManager` 的编辑器资产检查场景：同一份 `GameConfig.asset` 提供术语来源，缺术语时显示可读回退而非内部占位符
  - [x] `FormalAbilityAssetValidation` 已沿 EX-GAS Ability / Timeline / GameplayEffect / Cue 审计基础攻击图标、音频桥和独立特效入口；当前普攻没有配置临时音效或独立特效，已迁移技能的表现缺口不得回到旧能力表或旧执行资产补第二套入口
  - [x] 项目正式音频 Cue 桥已接入：`CuePlayGameCoreAudio -> AudioClipResolver -> AudioSystem`，并已进入 Bean/Luban/`XCue`/`XLuban` 生成链；基础攻击已清理 2DRPGEngine 临时音效 Cue，资产校验只在 `AudioResolverGuid` 非空且能解析到正式 `AudioClipResolver` 时才认可该音效入口
  - [x] `CueMountPrefab` 不再是当前普攻完成门槛；若未来拆出正式独立特效素材，校验器仍只在 `PrefabPath` 非空且能加载到真实 Prefab 时认可该独立 Cue
  - [x] 绑定正式 GAS Ability 的基础攻击已停止通过 `ActiveAbilitySheet.fireAudio` 播放项目侧第二套出手音效；出手音效只能回到正式 Cue/Task 路径补齐，项目侧优先使用 `CuePlayGameCoreAudio`
  - [x] 项目侧 `AbilitySheetEditor` 已删除，避免策划把旧 `AbilitySheet.m_executionAsset`、`ActiveAbilitySheet.fireAudio` 或其它旧字段当成正式作者入口
  - [x] 绑定正式 GAS Ability 的基础攻击已停止使用 `ActiveAbilitySheet.canInterupt` 作为动作打断门；收到项目侧动作打断时会向 EX-GAS Ability 提交取消请求
  - [x] 绑定正式 GAS Ability 的基础攻击已停止使用 `AbilitySheet.orientationMode` 旋转项目侧能力物体；正式朝向由 EX-GAS Timeline / TargetCatcher / 2D 朝向提供者解释
  - [x] 基础攻击 UI 显示名和主描述已改为从 EX-GAS Ability `Name/Desc` 派生；解析入口只能是 GAS Ability Code 投影，旧 `AbilitySheet.displayName` / `AbilitySheet.description` 本体不再做 GAS 回退或占位
  - [x] 基础攻击能力菜单列表已改为 `CharacterAbilityMenuEntry` 投影：已迁移主动技能只暴露 GAS Ability Code、GAS 名称、GAS 描述和 GAS 图标解析结果；已删除的旧能力表类型已删除，未迁移能力必须改用 EX-GAS Ability Code 展示或保持待迁移缺口
  - [x] GAS 生成运行时的能力、时间轴和 GameplayEffect 查询已改成安全查询；缺失 ID 不再抛异常，也不会让已迁移普攻菜单或槽位回退已删除的旧能力表字段
  - [x] 基础攻击 Prefab、AbilityRootMode、输入桥和本地输入门控已由 `exgas.abilityGameCore` 承载；已删除的旧能力表类型 同职责字段即使被改错，也不再决定正式 GAS 基础攻击的 Prefab、挂载根节点或输入门控；正式 GAS RootMode 已从已删除的旧能力表枚举解耦
  - [x] 基础攻击运行组件已从旧 `ActiveAbility<MeleeAttackAbilitySheet>` 泛型壳拆出；正式 `MeleeAttackAbility` 直接继承 `ActiveAbilityBase`，初始化后 `旧能力表身份投影不存在`；`AbilityBase` 不再暴露 `baseAbilitySheet` 这种像正式身份的旧表命名，由 `FormalGasAttackRuntimeInstance_DoesNotInheritLegacyActiveAbilitySheetRuntimeShell` 回归覆盖
  - [x] 基础攻击装备槽和触发/停止入口已从 `ActiveAbilitySheet`（已删除） 对象身份切到 GAS Ability Code 优先；运行时已删除的旧主动能力表类型已删除，未迁移能力不能继续依赖旧主动能力表视图，正式普攻触发/停止不再通过旧表对象 out 参数回流
  - [x] 基础攻击能力来源、运行时状态、读档恢复、脚本命令、道具授予、装备授予、角色组件附加能力、能力型临时效果、变形/感染规则和召唤附加能力入口已从“必须传已删除的旧能力表对象”继续拆到 GAS Ability Code 优先；新数据保存和恢复时不再把已迁移能力的已删除的旧能力表引用作为身份真相
  - [x] `CharacterAbilitySetRuntime` 的实例枚举职责已拆开：已删除的旧能力表实例枚举不再包含正式 GAS 实例，正式 GAS 运行态保存通过 GAS code 实例快照单独并回，避免把 `AbilitySheet = null` 的旧字典形状继续当作正式能力容器
  - [x] 旧角色表 `m_abilitiesPerLevel`、角色组件 `m_additionalAbilities`、变形/感染规则旧能力字段、状态效果旧能力字段和召唤旧附加能力字段如果仍残留已迁移 `AbilitySheet`（已删除），运行时读取会把它们排除出旧能力列表，但不会再反解或提升成 GAS Ability Code；`CharacterSheet_LegacyAbilityMapMigratedSheet_DoesNotExportLegacyOrGasCode`、`LegacyBonusAbilityApi_MigratedSheet_DoesNotRegisterLegacyOrGasRuntime`、`CharacterAlterationRule_LegacyMigratedAbilityFields_DoNotGrantOrSuppressGasCode`、`TemporalAbilityGrantEffect_LegacyMigratedSheet_DoesNotGrantGasCode`、`TemporalAbilitySuppressionEffect_LegacyMigratedSheet_DoesNotSuppressGasCode` 和 `SummoningExecutionBonusAbilities_LegacyMigratedSheet_DoesNotExposeGasCode` 覆盖该回归
  - [x] 已迁移基础攻击旧能力表路径不再能通过旧授予/压制路径注册成旧运行时能力；角色旧能力表、装备旧能力数组、道具旧 ability 字段、脚本旧 abilitySheet 字段、状态效果旧能力数组、变形/感染旧能力数组和召唤旧附加能力数组都会过滤或拒绝 `MeleeAttackAbilitySheet`（已删除）
  - [x] `MeleeAttackAbilityEditModeTests` 已重新验证旧表切除边界：`totalTests = 75`、`passedTests = 72`、`failedTests = 0`
  - [x] `FormalAbilityAssetValidation` 已删除已迁移普攻的旧结构期望映射：`MeleeAttackAbilitySheet`（已删除） 不再声明应绑定 `MeleeAbilityExecutionAsset`（已删除），也不再声明应实例化 `MeleeAttackAbility` 运行组件
  - [x] 项目侧 `AbilitySheetEditor` 已删除，`DatabaseWindow` 不再暴露已删除的旧能力表页签；已绑定 EX-GAS 的基础攻击不再通过已删除的旧能力表字段维护身份、图标、Prefab、Root、输入、消耗、冷却、权限、动作锁、打断门、出手朝向或音效作者入口
  - [x] 旧技能资产和旧执行资产类型已从 Unity 新建菜单撤下，并由 `LegacyAbilityAssets_DoNotExposeCreateAssetMenusAsAuthoringEntry` 和 `DatabaseWindow_DoesNotExposeLegacyAbilitySheetsAsFormalAuthoringTabs` 回归覆盖，避免新内容继续从已删除的旧能力表/ `AbilityExecutionAsset`（均已删除） 作者入口开始堆积
  - [x] 旧 `DashAbility` / `ProjectileAbility` / `SummoningAbility`、对应 `*AbilitySheet` 和全部 `*AbilityExecutionAsset` 已整块删除；冲刺、投射物、召唤和近战执行数据若进入正式范围，必须由 EX-GAS Ability / Timeline / GameplayEffect / Cue 重新表达
  - [x] 基础攻击正式图标已通过 `exgas.abilityGameCore.IconPath/IconGuid` 闭合；当前基础攻击不配置临时出手/命中音效，正式音效素材选定后只能通过唯一 EX-GAS Cue/Task 路径补齐
  - [x] 基础攻击表现闭环已按当前素材组织收口：角色动作走 `CuePlayGameCoreAnimator -> Attack`，武器攻击和武器自带特效由装备/武器动作承载；`EquipmentSystemDemo` 默认装备使用带 `Attack` 武器序列帧的 `长矛`
  - [x] `FormalAbilityAssetValidation` 不再审计 `已删除的 AbilitySheet.executionAsset`，因为该路径已删除；已迁移技能的执行、命中、表现和出手音效缺口只沿 EX-GAS Ability / Timeline / GameplayEffect / Cue 校验
  - [x] 项目侧旧执行资产自定义 Inspector 已删除；已迁移能力不再存在近战、冲刺、投射物、召唤旧执行资产自定义 Inspector 作者入口
  - [x] 出手/命中音效的唯一正式入口已保留在 EX-GAS Cue/Task 路径；当前基础攻击不再配置临时音效，避免用 2DRPGEngine 或其它参考资源冒充正式素材
  - [x] 基础攻击武器自带特效随武器攻击序列帧播放；其它非普攻受击表现和后续正式音效仍按待迁移表现缺口处理

## 4. Editor Landing

- [x] 采用并改造 EX-GAS 正式时间轴编辑面
  - [x] 已确认 `AbilityTimelineEditorWindow` 存在
  - [x] 已确认 `TaskClip.OnTickView()` 会调用 `AbilityTaskBase.OnEditorPreview()`
  - [x] 已确认 `TaskApplyEffects.OnEditorPreview()` 会调用 `TargetCatcher.OnEditorPreview()`
  - [x] 已确认 `CatchAreaBox2D.OnEditorPreview()` 能预览 2D 盒形范围
  - [x] 已确认 `TaskPlayCue` / `GameplayCueBase.OnPreview()` 支持 Cue 预览
  - [x] 已删除项目自造 `MeleeAbilityTimelineWindow` 文件和 `.meta`
  - [x] 已删除 `MeleeAbilityExecutionAssetEditor` 上“打开近战时间轴”按钮，并删除冲刺、投射物、召唤旧执行资产自定义 Inspector，避免旧执行资产继续成为正式作者入口
  - [x] 已补 GAS 时间轴编辑器打开预览场景前的 dirty 场景保存守卫
  - [x] 基础攻击真实判定预览已收口到 EX-GAS `TaskApplyEffects + TargetCatcher` 调用项目侧 `CatchAreaBox2D`
  - [x] 已把基础攻击迁到 EX-GAS Timeline 数据
  - [x] 已把基础攻击动画轨道从占位 Task 改为 `TaskPlayCue -> CuePlayGameCoreAnimator`
  - [x] 当前仓库已补入 EX-GAS Timeline 原始 Excel/Luban 工程入口
  - [x] 已完成从原始 Excel 到 Unity 生成产物的一键导表回归验证
  - [x] 已裁决 `TaskPlayCue` 空标签导表输出：Excel/Luban 使用 `[0]` 作为空标签占位，运行时由 `TagHelper.FilterInvalidTags` 过滤为真正空标签
  - [x] `CuePlayAnimator.OnPreview` 已补空预览对象、空 Animator、空 Controller、找不到动画片段和零长度帧段的明确提示与安全采样
  - [x] `CatchAreaBox2D` 已通过 GAS 侧 `IGas2DFacingProvider` 对齐项目 2D 角色朝向，运行时和预览解析不再只依赖 Transform Z 旋转
  - [x] 已将 GAS 插件 UI/导航源码改动撤回为可选优化候选；当前 change 不再直接修改第三方插件源码、UXML、USS、图标或生成器本体
  - [x] 可选优化候选已从本 change 主线剥离：2DRPGEngine / CLineActionEditor 的时间轴导航体验（复位视图、定位当前帧、鼠标锚点缩放、横向平移、只读视野范围条、clip 靠边自动滚动）不作为近战重构完成门槛；如需并入 GAS 原生编辑器，后续单独走 UI/体验评审或上游 patch 提议
  - [x] 已重新取得 EX-GAS 时间轴编辑器基础攻击可读窗口截图证据：`Temp/CodexEvidence/refactor-melee-ability-authoring/ex-gas-timeline-basic-attack-window-readable.png`

## 5. Cleanup

- [x] 清理错误方向和过期口径
  - [x] 删除项目自造 `MeleeAbilityTimelineWindow` 文件和 `.meta`
  - [x] 删除 Inspector 上的人类可见入口
  - [x] 删除项目侧 `MeleeAbilityExecutionAssetEditor`、`DashAbilityExecutionAssetEditor`、`ProjectileAbilityExecutionAssetEditor`、`SummoningAbilityExecutionAssetEditor` 文件和 `.meta`
  - [x] 清理文档中“项目自有时间轴窗口是最终目标”的过期口径
  - [x] 清理所有 `MeleeAbilityTimelineWindow` 正向引用
  - [x] 已扫描技能线非法人类可见入口残留，未发现新的基础攻击工作台、准备链路、修复接线或判定资产入口
  - [x] 已清理 `AbilitySheetEditor`、旧执行资产自定义 Inspector 和 `FormalAbilityAssetValidation` 中把 `TaskMeleeHit2D` 或旧执行资产说成正式基础攻击入口的过期提示
  - [x] 已删除项目侧旧近战执行资产自定义面板，避免策划误把旧资产当正式编辑入口
  - [x] 已清理运行时报错、旧路径测试断言和近战校验提示中把 `MeleeAbilityExecutionAsset`（已删除） 称作“正式近战执行资产”的残留口径
  - [x] 已清退项目侧旧并行命中任务 `TaskMeleeHit2D` / `XParamMeleeHit2D`：基础攻击和背刺正式路径只使用 EX-GAS `TaskApplyEffects + TargetCatcher + GameplayEffect`；生成注册、旧表反序列化和源码扫描均不再保留该旧任务类型
  - [x] 已把 `TaskApplyEffects.OnEditorPreview()` 空 catcher 问题降级为上游 patch 候选；当前不直接修改 EX-GAS 插件源码，只通过项目侧测试记录风险

## 6. Final Authoring Flow

- [x] 输出基于 EX-GAS Timeline 的基础攻击正式制作流程
- [x] 输出基于 EX-GAS Timeline 的背刺正式制作流程
- [x] 输出完整蓄力攻击当前正式制作流程：当前版本采用单档 `HoldRelease`，按下进入蓄力态、松手释放 `ChargedAttackRelease`，蓄力档位、提前松手弱蓄力和蓄力反馈分组作为后续深化需求，不阻塞本轮 EX-GAS 主轴验收
- [x] 验证基础攻击、背刺和蓄力释放段最终走同一套 GAS Timeline 作者流；基础攻击与背刺走 `Ability 20001 / Timeline 101 / GameplayEffect 2003`，蓄力释放走 `Ability 20004 / Timeline 20004 / GameplayEffect 2004`，三者均不回到旧 `AbilitySheet` / 旧执行资产 / `TaskMeleeHit2D`
