# Tasks: composite-sandbox-character-foundation

## P0: Scope And Truth Ownership

- [x] 更新主 proposal/design/spec，明确 `2DRPGEngine` 不是总框架，TopDown/GAS/RTS 在各自职责上是正式参考。
- [x] 把旧“Networking Is Not A Current Foundation Target”口径修正为“当前不实现联机，但重构必须带主机权威兼容边界”。
- [x] 建立角色闭包参考矩阵：TopDown `Character/CharacterAbility/TopDownController2D/CharacterInventory/CharacterPersistence/CharacterSwitch/Swap`、当前 `CharacterBase/Hero/Movable/PlayerController`、GAS ASC、RTS 命令链。

## P0: Inventory Ownership

- [x] 设计库存 owner 合同：角色、容器、地面物品、尸体、商店、制作站、队伍钱包。
- [x] 裁决 `InventorySystem` 新职责：库存服务/转移服务/查询服务/事件出口，而不是全局背包真相。
- [x] 设计角色背包、装备栏、快捷栏和能力来源的存档结构：角色存档记录背包 owner 绑定，背包物品数量仍由 `InventorySystem` owner 数据块持有；Hero 存档新增显式装备槽和快捷栏槽位；能力来源新增来源类型、来源 id 和叠层数量，旧汇总字段保留兼容。详见 `character-persistence-thirteenth-cut.md`。
- [x] 列出必须迁移的调用点：拾取、掉落、奖励、商店、制作、任务物品条件、物品使用、装备/卸装、UI 背包。
- [x] 第一刀实现：`InventorySystem` 增加显式 owner API，`ItemPickable` 写入执行拾取角色 owner，旧无 owner API 保留为默认队伍 owner 入口。详见 `inventory-owner-first-cut.md`。
- [x] 第二刀实现：背包 UI、物品消耗、装备/卸装和箱子物品奖励接入当前操作角色 owner；怪物掉落、商店、制作和任务条件保留为后续带上下文裁决。详见 `inventory-owner-second-cut.md`。
- [x] 第三刀实现：商店买卖、制作材料/产物和脚本物品命令接入当前受控角色 owner；队伍金钱继续共享。详见 `inventory-owner-third-cut.md`。
- [x] 第四刀实现：任务条件和物品收集任务新增显式库存查询范围，旧资产默认队伍库存，新资产可选当前受控角色库存。详见 `inventory-owner-fourth-cut.md`。
- [x] 第五刀实现：角色记录最后有效伤害来源，怪物掉落优先进入伤害来源角色背包，无来源时回退玩家实例。详见 `inventory-owner-fifth-cut.md`。
- [x] 第六刀实现：`InventorySystem` 增加 owner 间转移 API，库存/金钱事件携带 owner，箱子先落到容器 owner 再转给打开者，任务条件和日志按 owner 过滤。详见 `inventory-owner-sixth-cut.md`。
- [x] 第七刀实现：库存菜单新增 owner 上下文，背包格子改为通用点击处理接口，箱子物品保留在容器 owner 并通过库存菜单点击转移给打开者。详见 `inventory-owner-seventh-cut.md`。
- [x] 第八刀实现：库存 owner 转移新增 `InventoryTransferRequest/Result` 和失败原因，`UIInventory` 容器转移改走正式裁决入口。详见 `inventory-owner-eighth-cut.md`。
- [x] 第九刀实现：库存转移请求新增 Actor 参与者验证，带 Actor 的转移必须让发起角色参与来源或目标 owner。详见 `inventory-owner-ninth-cut.md`。
- [x] 第十刀实现：`GameCommandContext` 接入正式命令执行链，`CommandInteraction/CommandTrigger/CommandHandler/ExecuteCommand*` 透传来源上下文，库存和角色状态命令开始按 actor 裁决目标。详见 `inventory-owner-tenth-cut.md`。
- [x] 第十一刀实现：剩余运行时命令类全部收进 `IContextualCommand` 协议，旧无参执行统一委托到 `Script` 来源上下文。详见 `command-context-eleventh-cut.md`。
- [x] 第十二刀实现：`InputSystem -> IPlayerInputTarget -> PlayerController` 改为玩家命令请求/结果入口，本地输入不再直接调用玩家控制器旧 `Handle*` 方法。详见 `player-command-twelfth-cut.md`。
- [x] 第十三刀实现：角色长期存档结构补齐背包 owner 绑定、显式装备槽、显式快捷栏槽和能力来源桶。详见 `character-persistence-thirteenth-cut.md`。
- [x] 第十四刀实现：状态效果、变形和感染授予能力接入正式来源键与按来源回滚 API；暂不实现具体变形/感染业务规则。详见 `ability-source-fourteenth-cut.md`。
- [x] 第十五刀实现：新增 `TemporalAbilityGrantEffect`，让持续状态效果能真实授予能力、读档恢复授予并在完成时按 `StatusEffect` 来源回滚；正式 GAS 模板资产链也已覆盖该第 7 个持续效果类型。详见 `ability-grant-status-effect-fifteenth-cut.md`。
- [x] 第十六刀实现：新增来源化能力压制/禁用合同，`TemporalAbilitySuppressionEffect` 可在状态持续期间压制既有能力、读档恢复压制并在完成时按 `StatusEffect` 来源精确撤回；正式 GAS 模板资产链已覆盖第 8 个持续效果类型。详见 `ability-suppression-sixteenth-cut.md`。
- [x] 第十七刀实现：新增来源化能力替换执行壳，`TemporalAbilityReplacementEffect` 可同时压制旧能力并授予替代能力，读档恢复替换并在完成时只撤回该 `StatusEffect` 来源；正式 GAS 模板资产链已覆盖第 9 个持续效果类型。详见 `ability-replacement-seventeenth-cut.md`。
- [x] 第二十一刀实现：新增 `CharacterAlterationRule` 规则资产，用 DatabaseRegistry 中登记的资产 GUID 作为变形/感染来源 id，统一描述规则生效期间授予和压制的能力，并按同一来源撤回；不实现完整形态/感染业务。详见 `character-alteration-rule-twenty-first-cut.md`。
- [x] 第二十二刀实现：`CharacterBase` 新增激活规则运行时和存档字段 `activeAlterationRules`，应用/撤回规则资产时维护激活列表，读档只恢复列表本身，能力来源和压制仍由来源桶恢复，避免双重叠加。详见 `character-alteration-runtime-twenty-second-cut.md`。
- [x] 第二十三刀实现：`CharacterAlterationRule` 新增叠层策略、互斥组和优先级，`CharacterBase` 用激活计数字典记录规则层数，并支持单层撤回；存档继续用 `activeAlterationRules` 数组重复引用表达层数。详见 `character-alteration-stacking-twenty-third-cut.md`。
- [x] 第二十四刀实现：`CharacterAlterationRule` 新增来源化动作锁，规则可按来源锁定移动、交互、施法等 `EActionFlags`，读档时从 `activeAlterationRules` 重建动作锁；玩家输入和 AI 行为会通过 `CharacterBase.Can(...)` / `CanMove()` 受影响。详见 `character-alteration-action-lock-twenty-fourth-cut.md`。
- [x] 第二十五刀实现：`EActionFlags` 新增主动背包和装备变更动作位，`CharacterAlterationRule.lockedActions` 可阻断角色主动使用物品、容器转移和装备/卸装；系统发奖、掉落写入、强制脱装、尸体容器、控制权转移和 AI 接管仍未裁决。详见 `character-alteration-inventory-equipment-twenty-fifth-cut.md`。
- [x] 第二十六刀实现：`CharacterAlterationRule` 新增来源化阵营覆盖，变形/感染/丧尸化规则可在生效期间临时改变 `CharacterBase.currentAlignment`，从而影响 `CombatSolver` 和 `AIController` 的敌我判断；控制权转移、强制 AI 接管、派系关系和长期仇恨仍未裁决。详见 `character-alteration-alignment-twenty-sixth-cut.md`。
- [x] 第二十七刀实现：`CharacterAlterationRule` 新增玩家直接控制锁，变形/感染/丧尸化规则可让角色暂时不能接玩家输入；`PlayerSystem` 会拒绝选择不可控角色，并在当前受控角色失控时回退到仍可控的玩家实例或清空输入目标；强制 AI 接管、控制组、多选、远程访客和网络 ownership 仍未裁决。详见 `character-alteration-player-control-twenty-seventh-cut.md`。
- [x] 第二十八刀实现：`CharacterAlterationRule` 新增装备效果失效规则，变形/感染/丧尸化可让装备物品继续留槽但暂不贡献属性和装备授予能力；换装时会同步新旧装备能力的来源化压制，规则撤回后按来源恢复。强制脱装、装备视觉隐藏、尸体容器、装备损坏和非 Hero 装备栏仍未实现。详见 `character-alteration-equipment-effects-twenty-eighth-cut.md`。
- [x] 第二十九刀实现：角色死亡时把角色背包物品从 `Character` owner 迁到同一角色的 `Corpse` owner；复活时把 corpse owner 剩余物品迁回角色 owner，并为角色/怪物死亡入口补上重复触发防护。该刀当时不实现可交互尸体实体、尸体双栏 UI、装备强制脱装、装备掉落和死亡后 AI 接管。详见 `character-death-corpse-inventory-twenty-ninth-cut.md`。
- [x] 第三十刀实现：死亡后仍存在于场景中的角色被交互时，会把它的 `Corpse` owner 作为外部库存打开，并把物品转移给交互者；该入口复用现有 `InventoryMenuContext.TransferToCharacter(...)` 和库存转移裁决。独立尸体实体、怪物尸体保留、尸体双栏 UI、装备掉落和死亡后 AI 接管仍未实现。详见 `character-corpse-loot-interaction-thirtieth-cut.md`。
- [x] 第三十一刀实现：当前受控角色死亡后，`PlayerSystem` 会主动重校验当前输入目标；玩家主角复活且当前没有输入目标时，会恢复默认控制到玩家主角。该刀不实现控制组、多选、队友自动选择优先级、死亡后强制 AI 接管、远程访客或网络 ownership。详见 `character-death-player-control-thirty-first-cut.md`。
- [x] 第三十二刀实现：Hero 死亡时会强制卸下已装备物品、移除装备属性和装备授予能力，并把卸下的装备写入同一角色 `Corpse` owner；复活只会把 corpse owner 剩余物品带回角色背包，不自动重新穿回。非 Hero 装备栏、怪物装备、独立尸体实体、尸体双栏 UI、装备损坏和网络 ownership 仍未实现。详见 `character-death-equipment-corpse-thirty-second-cut.md`。
- [x] 第三十三刀实现：脚本/交互命令在没有显式 actor 时默认作用于当前受控角色或当前受控 Hero，`ExecuteCommandList` 的动作锁和 `IsAbilityUnlocked` 条件也改跟随当前受控目标；长期玩家主角语义仍保留给存档、地图穿越和玩家档案类入口。控制组、多选、远程访客和网络 ownership 仍未实现。详见 `command-current-controlled-target-thirty-third-cut.md`。
- [x] 第三十四刀实现：怪物死亡资产命令不再用无 actor 脚本上下文，而是跟随 `Monster` 已解析出的奖励接收者执行；击杀者/奖励接收者不是当前受控角色时仍保留 actor，但不伪造本地玩家来源。任务、对话和全局玩家死亡回调仍未裁决。详见 `monster-death-command-context-thirty-fourth-cut.md`。
- [x] 第三十五刀实现：玩家主角死亡动作不再用无 actor 脚本上下文，而是由 `PlayerSystem.NotifyHeroKilled(hero)` 把死亡玩家 Hero 作为 `LocalPlayer(hero)` 上下文传给 `GameConfig.ExecutePlayerDeathAction(...)`。任务、对话和持久化对象死亡回调仍未裁决。详见 `player-death-command-context-thirty-fifth-cut.md`。
- [x] 第三十六刀实现：任务完成资产命令不再由 `QuestInteraction -> JournalSystem -> Quest` 链路丢掉完成者上下文；当前受控角色完成任务时使用 `LocalPlayer(source)`，非当前受控角色完成任务时保留 `Unknown(source)` actor，不伪造 AI、远程访客或本地玩家来源。对话节点生命周期、持久化对象销毁、任务进度节点 actor、控制组、多选和网络 ownership 仍未裁决。详见 `quest-completion-command-context-thirty-sixth-cut.md`。
- [x] 第三十七刀实现：对话节点开始/完成命令不再由 `DialogueChannel -> DialogueNode` 链路强制使用无 actor `Script()`；交互对话跟随交互发起者，命令对话跟随命令上下文，宝箱掉落展示对话跟随打开者，纯 UI/系统提示仍保留 `Script()` 语义。持久化对象销毁、控制组、多选和网络 ownership 仍未裁决。详见 `dialogue-lifecycle-command-context-thirty-seventh-cut.md`。
- [x] 第三十八刀实现：`DestroyEntity` 命令销毁实体时不再丢弃命令上下文，`Persistable.Destroy(GameCommandContext)` 会用传入上下文执行对象销毁回调；旧无参 `Destroy()` 仍保留为脚本入口。角色死亡、投射物寿命结束、召唤物清理、控制组、多选和网络 ownership 仍未裁决。详见 `persistable-destroy-command-context-thirty-eighth-cut.md`。
- [x] 第三十九刀实现：角色死亡动画结束后的销毁回调不再固定使用无 actor `Script()`；`Movable` 保留脚本默认语义，`CharacterBase` 基于最后有效伤害来源生成 `LocalPlayer(source)` 或 `Unknown(source)` 上下文。投射物寿命结束、召唤物清理、脚本强杀来源归因、控制组、多选和网络 ownership 仍未裁决。详见 `character-death-destroy-command-context-thirty-ninth-cut.md`。
- [x] 第四十刀实现：投射物寿命结束、碰撞终止和销毁动画结束后的销毁回调不再固定使用无 actor `Script()`；`Projectile` 基于发射来源 `m_source` 生成 `LocalPlayer(m_source)` 或 `Unknown(m_source)` 上下文，来源缺失时保留脚本语义。召唤物清理、脚本强杀来源归因、控制组、多选和网络 ownership 仍未裁决。详见 `projectile-destroy-command-context-fortieth-cut.md`。
- [x] 第四十一刀实现：召唤能力主动打断和数量超限清理召唤物时，召唤物死亡销毁回调不再固定使用无 actor `Script()`；`SummoningAbility` 基于召唤者/能力拥有者 `m_character` 生成 `LocalPlayer(m_character)` 或 `Unknown(m_character)` 上下文，召唤者缺失时保留脚本语义。普通伤害死亡、环境死亡、脚本强杀、控制组、多选和网络 ownership 仍未裁决。详见 `summon-cleanup-command-context-forty-first-cut.md`。
- [x] 第四十二刀实现：默认库存菜单和简化外部库存转移入口不再把当前受控角色的转移请求降级成 `Unknown(actor)`；`InventoryMenuContext` 会在创建转移请求时把当前受控角色解析为 `LocalPlayer(actor)`，非当前受控角色仍保留 `Unknown(actor)`。该刀不改变库存 owner、物品数量、装备槽、双栏 UI、控制组、多选、远程访客或网络 ownership。详见 `inventory-menu-command-context-forty-second-cut.md`。
- [x] 第四十三刀实现：NPC 接任务和物品开任务不再直接调用无上下文 `StartQuest(...)`；`JournalSystem.StartQuest(quest, context)` 会把接取者上下文透传到 `QuestStartedEvent`，纯脚本废弃入口仍保留 `Script()`。该刀不新增任务开始命令、不改任务资产协议、任务归属保存、队伍共享/个人任务分流、控制组、多选或网络 ownership。详见 `quest-start-command-context-forty-third-cut.md`。
- [x] 第四十四刀实现：主动能力释放入口不再在玩家和 AI 之间混用无上下文 `FireAbility(sheet)`；本地玩家释放能力透传 `PlayerCommandRequest.CommandContext`，AI 攻击释放能力透传 `AI(actor)`，主动能力基类保存释放时上下文并让投射物、读档恢复后的投射物销毁回调和召唤能力主动清理沿用该来源。该刀不改变 GAS 规则层、被动伤害、持续 Tick、控制组、多选、远程访客或网络 ownership。详见 `active-ability-command-context-forty-fourth-cut.md`。
- [x] 第四十五刀实现：`Movable` 支持主控制器加额外控制器，变形/感染/丧尸化规则可通过 `forceAIControl` 来源化切到同一角色已配置的 `AIController`；规则撤回、单层撤回、读档恢复和清理都会回滚控制器覆盖。没有 `AIController` 的角色只会失去玩家直接控制，不伪造 AI。该刀不新增 AI 行为树、控制组、多选、远程访客或网络 ownership。详见 `character-alteration-ai-control-forty-fifth-cut.md`。
- [x] 第四十六刀实现：`IPlayerInputTarget` 新增当前受控角色快照，`PlayerControlGroup` 作为本地玩家控制组输入目标进入正式闭包，`PlayerSystem.SetCurrentControlGroup(...)` 可把多角色切成同一输入目标。移动类命令分发给所有仍可控成员，交互、菜单和能力命令仍只交给主控角色。该刀不实现框选、阵型、订单队列、导航 Provider、拾取/攻击多成员分发、远程访客、网络 ownership 或 ECS。详见 `player-control-group-forty-sixth-cut.md`。
- [x] 第四十七刀实现：`PlayerController.OnUpdate()` 的前台刷新判定改成按 `PlayerSystem.IsCurrentControlledCharacter(m_subject)` 识别主控角色，保证控制组下主控成员仍能刷新交互目标、指针朝向和能力前台状态。该刀不新增第二输入系统、交互多成员分发、阵型、队列、远程访客、网络 ownership 或 ECS。详见 `player-control-group-primary-update-forty-seventh-cut.md`。
- [x] 第四十八刀实现：`PlayerSystem` 新增 `IsCurrentControlledMember(...)`，`GameCommandContext.ResolveForActor(...)` 改用当前受控成员判断；对话、命令交互、任务开始/完成、宝箱、尸体搜刮、怪物奖励和库存菜单默认 actor 上下文统一改走 `ResolveForActor(...)`。这让控制组里的非主控成员在作为动作 actor 时仍可归因为本地玩家；主控刷新仍继续使用 `IsCurrentControlledCharacter(...)`。该刀不新增框选、阵型、订单队列、拾取/攻击多成员分发、远程访客、网络 ownership 或 ECS。详见 `player-control-group-member-command-context-forty-eighth-cut.md`。
- [x] 第四十九刀实现：本地玩家命令失败结果不再被 `InputSystem` 输入回调静默丢弃；失败会通过 `LocalPlayerCommandFailedEvent` 进入现有 HUD 提示组件，并只显示没有可控角色、actor 不在控制组、控制锁、交互无目标、菜单/施法状态阻断和快捷栏空槽等离散失败。该刀不实现距离、负重、容量、背包满、目标非法、阵营权限、多成员拾取/攻击分发、RTS 队列、远程访客、网络 ownership 或 ECS。详见 `player-command-failure-feedback-forty-ninth-cut.md`。
- [x] 第五十刀实现：交互命令失败原因新增 `InteractionLocked`，角色因变形、感染、丧尸化或其它动作锁不能交互时，HUD 显示“现在不能交互”，不再误报为“没有可交互目标”。无目标或没有交互接收者仍保留原来的无目标反馈。该刀不实现距离、自动靠近、目标合法性、负重、背包满、阵营权限、多成员交互分发、RTS 队列、远程访客、网络 ownership 或 ECS。详见 `player-command-interaction-failure-reason-fiftieth-cut.md`。
- [x] 第五十一刀实现：`PlayerSystem` 的当前受控 Hero 事件不再回退到玩家主角；能力 HUD、能力菜单快捷栏、能力菜单和角色面板改读真实当前受控 Hero。控制非 Hero 或没有受控 Hero 时，这些 UI 会清空，不再误显示玩家主角能力/属性。该刀不实现控制组能力栏合并显示、非 Hero 能力菜单、队伍级技能栏、远程访客 UI、网络 ownership 或 ECS。详见 `current-controlled-hero-ui-fifty-first-cut.md`。
- [x] 第五十三刀实现：`UIInventoryBag` 的分类切换不再绕过 `InventoryMenuContext`，而是沿用父菜单最近一次传入的 `InventoryOwnerHandle` 重画当前分类；容器、尸体、转移菜单和后续角色 owner 菜单不会因切分类回退到当前受控角色或玩家主角。该刀不实现控制组库存聚合、双栏容器、商店/制作站持久库存、非 Hero 装备栏或装备 UI 完整上下文。详见 `inventory-menu-owner-context-fifty-third-cut.md`。
- [x] 第五十四刀实现：商店和制作菜单请求新增 `GameCommandContext`，交互和资产命令打开菜单时会把发起角色上下文传到 `UIShop/UICraft`，交易、出售和制作不再因菜单打开期间切换当前控制对象而漂移到另一个角色背包。该刀不实现商店/制作站持久库存、个人钱包裁决、控制组批量交易、远程访客 UI 或网络 ownership。详见 `shop-craft-menu-command-context-fifty-fourth-cut.md`。

## P0: Ability And Status Ownership（归档后续事项，不计入当前 foundation change）

- [x] 固定 GAS 与动作执行分工：GAS rule spec 不执行动作，GameCore/TopDown 吸收闭包执行动作。当前正式路径里，`GameplayEffectAsset / GameplayEffectSpec` 只负责规则和映射；实际动作后果由 `TemporalAbilityGrantEffect`、`TemporalAbilitySuppressionEffect`、`TemporalAbilityReplacementEffect`、`TemporalControlEffect`、`TemporalSpeedModifierEffect` 这组 `GameCore` 效果类和 `CharacterBase` 正式拥有者执行，不由 GAS 规则对象直接执行。详见 `verification-notes.md`。
- 后续扩展：变形/感染/丧尸化对能力、装备、背包、控制权和 AI 的完整合同，以及装备授予能力、状态授予能力、角色永久能力和临时能力的最终优先级/存档策略，已确认为后续 gameplay change 的来源，不再作为当前 foundation change 的归档门禁。

> 说明：从这里开始，后续 P0 / P1 中那批明显属于具体玩法扩展、控制组进阶、RTS 化或未来访客控制的条目，按当前用户要求不再作为 foundation 完成门禁；它们保留为后续 gameplay change 的来源，不再夹进当前框架收口。

## P0: Command And Control（归档后续事项，不计入当前 foundation change）

- 后续扩展：完整正式命令入口、多选/控制组/远程访客控制关系，以及 RTS Starter Kit 风格的选择、订单队列、停止命令、阵型落点和批量下发职责，已确认为后续 gameplay change 的来源，不再作为当前 foundation change 的归档门禁。

## P1: UI And Feedback（归档后续事项，不计入当前 foundation change）

- 后续扩展：角色/控制组/容器视角的背包 UI、控制组上下文技能栏，以及更完整的命令失败玩家反馈，已确认为后续 gameplay change 的来源，不再作为当前 foundation change 的归档门禁。

## P1: Networking Readiness Without Networking（归档后续事项，不计入当前 foundation change）

- 后续扩展：完整命令上下文覆盖、远程访客来源区分，以及无网络接入前提下更严格的联机就绪性收口，已确认为后续 gameplay change 的来源，不再作为当前 foundation change 的归档门禁。

## P2: Validation（归档后续事项，不计入当前 foundation change）

- 后续扩展：多角色背包/拾取/转移、控制组多成员命令，以及保存/加载后更完整角色闭包恢复的端到端 smoke，已确认为后续 gameplay change 的来源，不再作为当前 foundation change 的归档门禁。
