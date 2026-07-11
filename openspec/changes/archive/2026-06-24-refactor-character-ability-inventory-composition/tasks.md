# Tasks: refactor-character-ability-inventory-composition

## 1. Current-State Audit

- [x] 复核当前玩家 prefab 的宿主结构，明确 `Hero / CharacterBase / Movable / PlayerController` 之间的职责边界。
- [x] 复核 TopDown `Koala.prefab` 的组件清单，确认 `CharacterAbility` 和 `CharacterInventory` 的组件式模式。
- [x] 复核当前 `InventorySystem` 的多 owner 能力、`InventoryMenuContext` 的 UI 入口和 `Hero` 的装备/能力运行时。

## 2. Reference And Gap Matrix

- [x] 记录“我方已有能力”与“TopDown 可吸收模式”的差距。
- [x] 把“每个角色独立背包、装备、快捷栏、能力来源”写成可验收用户故事。
- [x] 把“变形 / 感染 / 丧尸化保留部分能力”写成正式规则合同，而不是临时特例。

## 3. Formal Proposal Closure

- [x] 撤销“本 change 只覆盖提案与验收边界，不进入 prefab 实现”的早期错误口径；当前 change 是完整重构闭环，文档完成只算前置阶段。
- [x] 明确哪些东西只做局部吸收，哪些东西不作为正式真相源。
- [x] 明确未来正式实现时应优先改动的角色 prefab 和库存/UI 闭包。
- [x] 补一份集中式理由文档，说明为什么不是继续单 `Hero` 中心、为什么不是整套 TopDown、为什么现在不切 ECS 或直接带上联机实现。
- [x] 明确“背包后面做/延后做”只代表实施顺序，不代表角色私有背包、装备槽、快捷栏或库存 owner 边界退出当前 change。

## 4. Verification

- [x] 运行 `npx openspec validate refactor-character-ability-inventory-composition --strict`
- [x] 汇报当前结论：早期文档阶段不是实现完成，不能按“提案完成”归档整个 change。

## 5. First Migration Tasks

这些任务原本不属于“提案完成”范围；文档完成只算前置阶段，只有代码、Prefab、验证和留档全部闭环后才能归档。
此前 `Profile / CharacterCompositionProfile / archived fallback` 口径已判定为无参考迁移层，当前实现口径改为对照 TopDown Koala 的正式组件大清洗。

- [x] 设计正式角色能力/控制/库存/装备组件结构，删除无参考的 `CharacterCompositionProfile`，不再把自造 Profile 当作正式组合入口。
- [x] 改造 `0_Hero_Base.prefab`；`玩家角色.prefab` 继续通过 prefab 继承该组合入口，让能力、库存、装备和控制边界在玩家角色上可检查。
- [x] 让库存菜单默认入口、装备目标解析和物品装备/卸下入口走显式角色上下文，而不是只靠隐式当前 `Hero` 回退。
- [x] 让能力菜单、角色菜单和能力条也切到显式角色上下文，不再只靠隐式当前 `Hero`。
- [x] 放宽 `PlayerSystem` 的“场景里必须只有一个 Hero”硬假设；长期玩家实例继续显式绑定到 `m_playerInstance`，只有缺失绑定时才回退场景 `Hero` 搜索。
- [x] 让默认装备入口先跟随当前受控角色，再通过正式 `CharacterHandleWeapon` 装备组件解析装备宿主，而不是直接短路到当前 `Hero` 或自造组合 Profile。
- [x] 让能力增减事件带上 `Hero` owner，避免多角色能力变化只剩“哪个能力变了”而丢失角色归属。
- [x] 补最小验证：两个角色独立背包、能力保留/替换/压制、容器/尸体转移、当前受控角色切换。
- [x] 新增 `CharacterPlayerControl` 并挂到 `0_Hero_Base.prefab`，让玩家输入目标通过 prefab 可见控制组件解析，而不是藏在 `Movable.m_controller` 的 `SerializeReference` 字段里。
- [x] 新增 `CharacterAbilitySet` 并挂到 `0_Hero_Base.prefab`，让外部能力查询、触发、冷却查询和授予/撤回入口优先通过 prefab 可见能力组件解析。
- [x] 新增 `CharacterMovement` 与 `CharacterButtonActivation` 并挂到 `0_Hero_Base.prefab`，把方向/点击移动控制、指针朝向和交互激活拆到 prefab 可见组件。
- [x] 把能力根节点和玩家额外能力配置抬到 `CharacterAbilitySet`；`CharacterBase` 不再保留同职责能力根节点和额外能力字段作为常态兼容路径。
- [x] 把能力实例集合、来源计数、压制计数和实例更新/重置/中断容器改由 `CharacterAbilitySet` 持有；缺少 `CharacterAbilitySet` 是 prefab 配置错误，不再回退到 `CharacterBase` 私有能力仓库。
- [x] 把玩家技能槽底层所有权、技能槽查询、技能槽开火/停火、能力栏槽位快照和能力菜单装备/卸下入口迁到 `CharacterAbilitySet`，让输入组件、能力 UI 和 `Hero` 都不再直接读取或操作技能槽底层实现。
- [x] 继续把主动能力触发、换弹、规则生命周期桥接和 GAS 执行中断从 `CharacterBase.Abilities.cs / CharacterBase.GASRuntime.cs` 往能力组件边界拆；现在 `CharacterAbilitySet` 直接解析能力实例并驱动开火/停火/换弹/冷却查询，`ActiveAbilityBase` 的生命周期、冷却、消耗和 formal cancel 反向中断也先经过能力组件入口。
- [x] 把角色级库存/背包边界做成 prefab 可检查组件或同等级正式组件边界；`CharacterInventory` 已按 TopDown `CharacterInventory` 的主背包/武器背包/快捷栏角色绑定思路落到基础玩家 prefab，`InventorySystem.GetOwner(CharacterBase)` 优先从该组件解析主库存 owner。
- [x] 把 `Hero` 的装备槽、装备授予能力和相关存档编排继续拆到 prefab 可见装备/库存边界；`CharacterHandleWeapon` 已按 TopDown `CharacterInventory + CharacterHandleWeapon` 的角色装备/武器组件边界落到基础玩家 prefab，装备槽容器、装备授予/撤回能力、装备效果压制和装备存档快照已由该组件持有，`Hero` 仅保留原公开 API 的兼容转发。
- [x] 把 TopDown 能力组件化能裁决的 formal ability rule、cooldown、cost、lifecycle 和能力运行时存档入口从 `CharacterBase / Hero` 集中职责里拆到 `CharacterAbilitySet`；`CharacterBase` 只保留属性、ASC 宿主、持续效果和角色状态编排。持续效果 archived/fallback 壳没有 Koala 同级参考，不作为本次 TopDown 组件化强拆对象。
- [x] 删除 `PlayerController` 委托壳并清空 `0_Hero_Base.prefab` 上的 `Movable.m_controller` 玩家控制序列化入口；单角色输入由 `CharacterPlayerControl` 承接，控制组通过 `PlayerControlGroup` 分发到成员 `IPlayerInputTarget`。
- [x] 补 `implementation-log.md`：逐项记录 TopDown 参考脚本/Prefab、改前目标脚本、改后落点、仍未覆盖差距和验证入口；没有这份留档不得归档。
- [x] 做一次归档前 prefab 审计：`0_Hero_Base.prefab / 玩家角色.prefab` 必须能直接证明控制、能力、库存、装备和表现边界已达到本提案定义的 TopDown 参考吸收目标；否则不得归档。

## 6. Verification Notes

- [x] `npx openspec validate refactor-character-ability-inventory-composition --strict`
- [x] 静态核对：`PlayerSystem` 已移除“唯一 Hero”断言；HUD 冷却条改由父能力栏显式绑定当前 `Hero`，单个格子不再自行猜当前受控对象。
- [x] 静态核对：默认装备入口不再短路到 `GetCurrentControlledHero()`；能力增减事件已带 `Hero` owner，`IsAbilityUnlocked` 只对当前受控 `Hero` 的目标能力刷新。
- [x] 静态核对：`PlayerSystem.SetCurrentControlledCharacter(...)`、存档恢复和控制组成员过滤都已改为通过 `CharacterPlayerControl.TryResolveInputTarget(...)` 解析输入目标；控制组分发也改为提交到 `IPlayerInputTarget`，不再硬编码要求成员一定暴露 `PlayerController`。
- [x] 静态核对：`0_Hero_Base.prefab` 已新增 `CharacterAbilitySet`，外部 UI/命令/道具/召唤能力的能力查询、触发、冷却查询和授予/撤回入口已优先通过该组件；这仍只是能力入口边界，不代表能力实例集合和生命周期已迁出 `CharacterBase`。
- [x] 静态核对：`0_Hero_Base.prefab` 的能力根节点已同步到 `CharacterAbilitySet`；`玩家角色.prefab` 的额外能力 override 应落在 `CharacterAbilitySet.m_additionalAbilities`，不再以 `CharacterBase` 同职责字段作为常态兼容完成证据。
- [x] 静态核对：`CharacterAbilitySetRuntime` 已从 `CharacterBase` 私有内部类抬成同程序集运行时容器，并由 `CharacterAbilitySet.Runtime` 持有；`CharacterBase.Abilities/Persistence/GAS` 统一通过 `AbilityRuntime` 访问正式组件运行时，缺组件时抛配置错误。
- [x] 静态核对：交互距离、交互音效、点击移动停止距离、指针施法朝向等 Inspector 配置已移动到 `CharacterMovement / CharacterButtonActivation`，并由 `CharacterPlayerControl` 命令路由调用。
- [x] 静态核对：玩家开火/停火、HUD 能力栏快照、能力菜单装备/卸下现在走 `CharacterAbilitySet`，技能槽底层实现也已迁入该组件，不再由 `Hero` 直接持有。
- [x] 静态核对：`CharacterAbilitySet` 不再只是 `FireAbility / StopFireAbility / ReloadAbility / TryGetActiveAbilityCooldownSnapshot` 的门面；它现在直接从自身持有的 `CharacterAbilitySetRuntime` 解析 `ActiveAbilityBase`，并处理开火、停火、换弹、冷却查询和其它能力武器状态阻断。`CharacterBase.Abilities.cs` 同名公开方法只作为公开 API 转发，不再作为缺组件能力仓库回退。
- [x] 静态核对：`ActiveAbilityBase` 的开始/结束/取消、冷却、消耗和读档冷却恢复都已改为先走 `CharacterAbilitySet` 的规则桥接入口；`CharacterBase.GASRuntime` 的 formal cancel 反向中断也改为通过 `CharacterAbilitySet` 的能力快照和实例解析，而不是直接扫 `CharacterBase` 的能力运行时。
- [x] AIBridge 编译核对：`assets-refresh` 成功，随后 `editor-application-get-state` 返回 `isCompiling=false`、`isUpdating=false`，最近 5 分钟 Unity Console Error 为空。
- [x] 前台收口：`UIEventLog` 的能力获得/失去日志已补角色名，不再只显示能力名；`User Interface.prefab` 对应模板已切到 `{角色名} + {能力名}` 双占位，避免多角色下前台提示继续停留在单角色语义。
- [x] Unity 批处理编译：`C:\Gamedev\Unity\Editor\6000.3.10f1\Editor\Unity.exe -batchmode -nographics -quit -projectPath C:\Gamedev\Unity\Project\FantasyWord -logFile %TEMP%\FantasyWord-Unity-Compile.log` 通过；日志包含 `*** Tundra build success` 与 `AssetDatabase: script compilation time`，未出现新的 C# 编译错误。
- [x] Unity 批处理编译：`C:\Gamedev\Unity\Editor\6000.3.10f1\Editor\Unity.exe -batchmode -nographics -quit -projectPath C:\Gamedev\Unity\Project\FantasyWord -logFile %TEMP%\FantasyWord-Unity-ControlProfile-Compile.log` 通过；日志包含 `*** Tundra build success`，未出现新的 C# 编译错误。
- [x] `CompositeRuntimeSmokeValidator` 已补 SkillWorkbench 能力资产回退：当正式 DatabaseRegistry 里暂时没有可实例化能力表时，优先复用现有 `测试-基础攻击 / 蓄力攻击 / 背刺` 能力表与对应 prefab，不再因为正式能力表模板 `m_prefab: 0` 直接判失败。
- [x] AIBridge 组合式运行时 smoke：`powershell -ExecutionPolicy Bypass -File scripts/Invoke-CompositeRuntimeSmoke.ps1` 已在当前 Unity Editor（PID 41680）通过，结果文件确认以下断言全部成立：两个角色 owner 独立、容器/尸体往返转移不污染同伴背包、当前受控角色切换后库存上下文恢复正确、能力基线可解析、变形期间能力保留/替换/压制成立、移除变形后能力恢复正确。
- [x] AIBridge 导入/编译核对：新增 `CharacterInventory` 与 `0_Hero_Base.prefab` 接线后，`assets-refresh {"options":"ForceSynchronousImport"}` 成功，随后 `editor-application-get-state` 返回 `isCompiling=false`、`isUpdating=false`，最近 5 分钟 Unity Console Error 为空。
- [x] Unity 批处理编译：新增 `CharacterHandleWeapon` 与 `0_Hero_Base.prefab` 接线后，`C:\Gamedev\Unity\Editor\6000.3.10f1\Editor\Unity.exe -batchmode -nographics -quit -projectPath C:\Gamedev\Unity\Project\FantasyWord -logFile %TEMP%\FantasyWord-Unity-EquipmentComponent-Compile.log` 返回码 0，日志显示 `CompileScripts` 完成且 `Exiting batchmode successfully now!`；本轮未见新的 C# 编译错误。该历史验证已被本轮大清洗后验证要求覆盖，需要重新跑当前代码。
- [x] 静态核对：`CharacterAbilitySet` 现在直接持有 formal ability rule roster、cooldown cache、生命周期桥接、能力运行时快照/恢复和技能槽底层；`CharacterBase.Abilities/GASRuntime/Persistence` 已通过正式组件运行时访问，不再以缺组件回退作为完成口径。
- [x] 静态核对：`CharacterPlayerControl` 现在直接实现 `IPlayerInputTarget` 并承接玩家命令分发；`PlayerController.cs` 已删除，`0_Hero_Base.prefab` 的 `m_controller` 已清空。
- [x] 静态 prefab 审计：`0_Hero_Base.prefab` 已直接挂载 `CharacterPlayerControl / CharacterAbilitySet / CharacterMovement / CharacterButtonActivation / CharacterInventory / CharacterHandleWeapon`；`玩家角色.prefab` 的 `m_SourcePrefab` 指向 `0_Hero_Base.prefab`，通过 prefab 继承获得这些正式组件。
- [x] 当前验证：删除 `PlayerController` 与清理 `CharacterBase` formal ability rule 复制实现后，已重新跑 Unity `assets-refresh {"options":"ForceSynchronousImport"}`；`editor-application-get-state` 返回 `isPlaying=false / isCompiling=false / isUpdating=false`；最近 10 分钟 Unity Console Error 为空。
- [x] 当前 smoke：`powershell -ExecutionPolicy Bypass -File scripts/Invoke-CompositeRuntimeSmoke.ps1 -StatePollTimeoutSeconds 180 -ResultPollTimeoutSeconds 180` 通过；结果确认两个角色 owner 独立、容器/尸体转移不污染同伴、变形期间能力保留/替换/压制成立、控制组/RTS 订单链通过、GAS formal 恢复通过。
- [x] 当前归档结论：当前 change 的有参考重构、文档、prefab 审计和 Unity 验证均已闭环；可进入归档流程，但归档动作仍需按项目规范单独执行。
