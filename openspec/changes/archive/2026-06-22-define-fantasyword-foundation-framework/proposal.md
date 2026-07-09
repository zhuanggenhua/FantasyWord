# Proposal: define-fantasyword-foundation-framework

> 状态：当前提案已收口的是“旧冲突清理、单一真相边界和下一阶段替换路线”，不是完整开放世界架构已经完成。旧 `Bootstrapper/RuntimeContext/ModuleInstaller/EventBus` 路线已撤出正式完成口径；UIKit、GAS 等胜出能力必须进入后续框架替换专项，不能被写成无限期候选冻结。当前目标也不是“最小改动先跑起来”，而是直接把成熟参考里更好的那一边推成长期正式真相，为复杂开放世界本体和同项目内卡牌自走棋模式留下干净、可扩展、可维护的框架地基。对 UI 来说，当前已经锁定的正式机制真相是 Yoki `UIKit` 原生模型：`UIRoot + UIPanel + UIKit.OpenPanel/PushPanel/PopPanel`；项目菜单运行时入口当前已并回正式已有的 `UIManager`，不再额外挂任何第二菜单组件。这里的 `UIManager` 不是新的 UIKit 宿主，也不复制 panel 生命周期、缓存、焦点或 stack 真相；它只承接 `EMenu/Shop/Craft`、返回键、`GameState.Menu` 和“等待菜单关闭”这些项目菜单语义。

## Why

`FantasyWord` 是俯视角开放世界像素游戏，需要先搭建可信 Unity 地基，再进入角色、地图、交互、物品、战斗和存档。地基不能靠 AI 自造抽象成立，必须优先来自成熟参考或可复制源码。

本 change 的迁移规则是：当单一成熟参考可直接复制、直译或最小闭包改造时，默认先照搬，再证明哪里必须改。当前可直接作为 Unity 运行时地基参考的是 `2DRPGEngine` 的 `GameManager + AGameSystem`，后续再补 Database、Persistence、Map、Command/Interaction、Entity/Controller 等闭包；`dark-corridor` 只保留 AI 规范、门禁和工程治理来源，不作为运行时实现来源。

## What Changes

- 将 foundation 正式入口改为 `GameManager + AGameSystem + GameConfig`。
- 明确 `GameManager` 现有静态 system 快捷入口不是天然错误：它们可以保留为当前 2DRPG 地基的快速实现入口；问题只在于无边界扩张、跨领域滥用和让同职责第二真相继续存活。
- 建立“真相所有权冲突”实施提案：事件、UI、属性/GAS、输入、存档、地图/开放世界、背包/角色目标、游戏内卡牌模式、TopDown manager 链和 Yoki 工具层都必须登记保留/替换/融合/退场动作。
- `2026-06-18` 已开始把 GAS 专项从文档推进到正式代码：`FormalGameplayAttributeSet` 先固定正式属性字段形状，`CharacterBase.GASRuntime` 先把 ASC 所有权固定在角色实体，并把旧 Stats 快照同步进 ASC；随后第二刀又把 `CharacterBase` 的正式属性读取口、资源写入口和最小战斗快照优先切到 ASC；第三刀继续把属性通知、零血死亡判定与当前值存档/读档收回 `CharacterBase` 正式拥有者。当前仍不是最终完成态，因为旧 `AttributeBootstrapBuffer` 还没有彻底退场，持续效果与能力规则也还没切完。
- 明确“不夹带具体业务”不等于“不替换成熟框架系统”：背包、属性、能力、UI 菜单运行时、存档文件层、对象池、输入绑定和事件派发都属于框架地基；具体物品、具体技能、具体商店、具体任务链和具体菜单流程才是业务内容。
- `2026-06-21` 起范围进一步收口为“框架系统 + 代表性最小案例”。背包、任务、对话、商店、制作、技能/效果、存档、地图、UI 菜单、GAS/Yoki/UIKit 接入仍属于开放世界 RPG 地基；旧工程带入的成批具体物品、具体存档角色、具体商店库存、具体配方、具体任务链、NPC 台词和非代表性 demo 流程不再因为系统存在而自动保留。当前用户已允许删除确认无正式引用、无第三方来源边界、且不属于代表性案例的项目侧旧业务内容。
- 新增 `game-manager-static-access-policy.md`，明确 `GameManager.XxxSystem` 的工程裁决：在移除旧通知中心后，现有 13 个 2DRPG 快速访问入口保留，问题不在快速实现本身，而在无边界扩张、绕过所有者和保留同职责第二真相；后续新增开放世界与卡牌模式状态必须进入明确的 `World/Mode` 所有权层级。
- 明确单例策略：`GameManager.Instance` 可以作为当前 Unity 场景里的项目启动锚点和系统收集器，但单例不是默认领域模型；开放世界状态、卡牌自走棋单局状态、实体局部状态、UI 栈和属性真相不得因为访问方便而挂成全局单例。
- 将后续更符合软件工程的方案固定为 `Project / World / Mode / Entity` 四层所有权，而不是新增服务定位器、兼容层或把 13 个静态入口一次性拆掉。
- 将地图加载、地图卸载和存档载入这 5 个框架生命周期事件，从旧 `NotificationSystem` 调用面迁到 `GameRuntimeEvents` 正式入口；`GameManager` 只继续负责 `AGameSystem` 生命周期分发，并在系统回调之后发布 Yoki `EventKit.Type` 强类型事件。
- 撤出旧 `Bootstrapper/RuntimeContext/ModuleInstaller/EventBus/ModuleAsset` 自造链路的完成口径。
- 建立参考矩阵，记录 `2DRPGEngine`、Unity 官方 API、插件和后续可选 UE 范式证据。
- 静态门禁只保护新的最小闭包和旧链路反向禁止项。
- 第三方插件和参考工程自带素材只做留档和矩阵，不因 foundation 清理被删除；MiniFantasy 素材包是正式美术来源，其自带 demo 场景、Prefab 和示例脚本只作为来源证据与接线参考。
- 对 `uMMORPG Remastered - MMORPG Engine [2.41]` 的使用方式收口为“局部源码证据源”，不是整体替换源：当前已固定 6 条移动/场景组织源码证据；进入运行时代码的是对现有 `Movable / MapSystem / Teleporter` 闭包的合同、规则和健壮性补强，包括移动重置/传送合法落点/停止半径、直接方向驱动取消旧路径、失效保存位置回退和子碰撞体回溯正式玩家实体。这里不是重复搬运 `uMMORPG` 的同职责实现；实例宿主/出生点分流宿主仍只停留在职责证据，不进入代码。缺的仍是 4 个一级框架参考位，即单机/本地 2D 导航 Provider、2D 点击移动执行闭包、单机/本地场景实例宿主参考和单机/本地出生点分流宿主参考。

这里的 4 个一级框架参考位，只描述 `2D 移动与场景组织` 当前还缺什么正式参考，不代表开放世界模拟层也已被同一组缺口完整覆盖。

## 当前下一阶段正式重构范围

当前活跃 change 不再把“旧冲突已清理”误写成“框架已经完成”。从现在开始，下一阶段正式重构只看下面 5 条主线；它们都是框架真相替换，不是业务内容补完：

当前 active change 的剩余工作也已经收窄到旧资源、共享构件、历史口径和门禁追平；不再存在新的“菜单第二宿主替换设计分支”。`patched-parity-matrix.md` 当前也已把 runtime patched 项收口到 `暂留 = 0`，不再存在“同职责真相已经拍板，但提案台账还把它挂成待决”的遗留。

1. `UIKit` 菜单运行时收口：Yoki `UIKit` 原生入口已经是正式 UI 机制真相。项目菜单运行时入口当前已并回 `UIManager`，只允许负责 `EMenu/Shop/Craft -> PanelType` 路由、`GameState.Menu`、返回键和 `TaskCompletionSource` 关闭语义；迁移期守卫、独立注册表、第二套路由和额外菜单组件既然已经删除，就不得再以任何壳层形式回潮。下一步只继续清理旧 `AUIMenu/IUIMenu` 资源残留和共享构件落点，避免菜单运行时入口继续生长成第二真相。
   当前补充：本轮已继续收口正式 `Resources/Art/UIPrefab` 菜单 prefab 的内部对象名，`Character Menu / Inventory Menu / Journal Menu / Save Menu / Settings Menu / Shop Menu / Craft Menu / Game Menu` 这类旧壳命名不再应留在正式资源里充当现态说明。
2. `Stats/currentStats -> GAS` 替换专项：当前已经把属性、资源语义、战斗最小快照和伤害来源合同收出缝，并已落“实体级 ASC/AttributeSet 挂点 + 正式读取口优先切 ASC + 通知/死亡链/当前值存档回到 CharacterBase”三刀；下一步要继续把持续效果、能力生命周期和最终旧档迁移朝 GAS 胜出方向收口。
3. `Project / World / Mode / Entity` 四层所有权落地：不是新建空系统，而是在继续改现有模块时，把项目级、世界级、模式级和实体级状态收回正确拥有者，禁止继续长到 `GameManager.*`。
4. `2D 移动与场景组织` 参考缺口补齐：当前仍缺 4 个一级参考位，没补前不能脑补完整点击移动、控制组穿越和自动靠近闭包。
5. 单一真相继续收口：存档、输入、UI、属性、战斗、模式和世界状态都继续按“同职责只保留一边”推进，不允许因为“已经有人依赖”就把旧真相保留为长期并行路径。

为避免这两条主线继续停留在口头理解，当前 active change 已补两份实施文档：

- `gas-replacement-implementation-plan.md`：把最终口径收敛为“GAS 持有属性/效果/能力规则真相，TopDown 吸收闭包继续持有动作执行与手感，`GameplayFeedbackSet` 继续持有表现入口”。
- `project-world-mode-entity-implementation-plan.md`：把四层所有权压到当前仓库可执行口径，明确哪些状态继续留在 `Project`，哪些应落回 `World / Mode / Entity`，同时禁止先造空 `WorldSystem/ModeRuntime`。

当前补充：GAS 这条线现已不只是“有计划”。当前代码已经把 `FormalGameplayAttributeSet`、`CharacterBase.GASRuntime`、`CharacterBase.Resources`、`CharacterBase.StateApi` 和 `CharacterBase.Persistence` 这组正式闭包接起来，形成“实体级挂点 + 正式读取口优先走 ASC + 通知/死亡链/当前值存档回到 CharacterBase”的第三刀现态；后续实现必须沿这组实体级挂点继续推进，而不是回头再造项目侧 GAS 宿主或包装层。

这里的“开始重构”，在当前 change 里的精确定义是：继续把成熟参考胜出的那一边推成正式真相，把输的一边退场，而不是为了少改代码保留双轨。

## 二选一裁决摘要

这里的“二选一”不是在 `2DRPGEngine / TopDownEngine / YokiFrame` 里选一个总冠军，而是在同一职责上只保留一个正式真相源。若一个系统被拆成两种职责，则分别裁决；拆分后的公开入口仍只能有一套。

| 冲突项 | 选择 | 不选 | 选择理由 | 当前边界 |
| --- | --- | --- | --- | --- |
| 启动和系统生命周期 | `2DRPGEngine GameManager + AGameSystem` | 旧自造 `Bootstrapper/RuntimeContext/ModuleInstaller/EventBus`、TopDown manager 链、Yoki 架构层 | `GameManager + AGameSystem` 已有成熟参考，能直接表达项目级系统生命周期；旧自造链没有同职责成熟来源，TopDown manager 会带入第二生命周期，Yoki 架构层不表达 RPG 世界宿主 | 保留现有 13 个快捷入口，但禁止继续把世界、模式、GAS、UIKit 或 TopDown manager 状态挂成新的 `GameManager.XxxSystem` |
| 事件派发机制 | `GameCore` 强类型事件 + Yoki `EventKit.Type` | 旧 `NotificationSystem` | Yoki `EventKit.Type` 已提供强类型派发能力；领域事件类型留在 `GameCore` 可读且可审计；旧 `NotificationSystem` 是宽字段通知中心，容易让任意系统绕过正式所有者 | 只替换旧 notify 调用面；对象或组件内部的局部 `UnityEvent` 继续允许保留，不强制迁入项目总线 |
| 地图、检查点、传送和地图恢复 | `2DRPGEngine MapSystem` | TopDown `LevelManager` 整体接管 | 地图名、检查点栈、传送和存档恢复是长期世界状态，`2DRPGEngine` 更适合当真相源；TopDown 的关卡能力强在边界、出生点、检查点顺序、重生延迟和相机样板 | `MapSystem` 保真相，只吸收 TopDown 关卡表现样板，不接 TopDown `LevelManager/GameManager/GUIManager/Health` |
| 角色动作、能力阻断、武器执行和命中窗口 | TopDown 模式吸收到 `GameCore` | 继续沿用 `2DRPGEngine` 薄动作执行，或整体搬 TopDown 角色生命周期 | 这是瞬时执行和手感问题，TopDown 的能力组合、武器状态机、命中窗口和反馈触点更成熟；但整体搬 TopDown 会带入第二输入根和第二生命周期 | 只吸收动作执行模式，正式角色数据、输入根和生命周期仍归 `GameCore` |
| RPG 世界规则、任务、背包、对话、角色长期数据 | `2DRPGEngine` | TopDown `Inventory/GUI/Health` 等动作框架语义，或 Yoki 工具层 | 这些是长期世界和内容数据真相，`2DRPGEngine` 的数据、任务、背包、对话和存档闭包更贴近 RPG 内容生产；TopDown 更适合动作表现，Yoki 不表达玩法语义 | 系统本身是框架模块，具体物品、商店、任务链、菜单文案和 NPC 流程不因此进入地基范围 |
| 属性、能力和效果规则真相 | 下一阶段必须裁决 `Stats/currentStats` 与 GAS 的职责归属；GAS 在复杂属性集、效果叠层、标签、冷却和能力规则上是正式替换候选 | `Stats` 与 GAS `AttributeSet/GameplayEffect` 并行结算、显示或存档 | 复杂开放世界需要可扩展属性、状态效果和能力规则；如果 GAS 在这层胜出，就必须替换同职责 Stats/Effect/Ability 入口，而不是继续让旧 Stats 因“已被依赖”保留为真相 | 本 change 只保证不双轨；下一阶段 P0 建立 GAS 替换专项，完成属性字段、存档、UI 读取源、能力生命周期和对象池边界裁决 |
| 输入根 | `GameCore InputSystem` | TopDown `InputManager`；Yoki `InputKit` 直接接管玩法输入 | 玩法动作语义必须只有一个输入根；TopDown 输入根会制造第二输入系统，Yoki `InputKit` 更适合做重绑定和配置工具 | `InputSystem` 保玩法语义，`InputKit` 只做重绑定、保存、冲突查询；卡牌模式需要独立输入上下文时另建模式裁决 |
| 存档真相 | `GameCore SaveDataBlock` 聚合世界语义，Yoki `SaveKit` 负责文件层 | SaveKit 直接拥有 RPG 世界语义，或继续只用 2DRPG 薄文件层 | 世界、玩家、背包、任务和未来卡牌长期数据必须由 GameCore 数据块表达；SaveKit 更适合文件读写、槽位、版本和序列化工具 | 不建第二套存档真相；真实场景存档 smoke 后续专项补 |
| UI 菜单运行时 | Yoki `UIKit` 原生模型作为唯一 UI 机制真相；项目侧只允许保留一个把菜单请求接到 `UIKit` 的薄入口，当前落在 `UIManager` | `AUIMenu/UIMenuManager` 与 `UIPanel` adapter 双栈、TopDown `GUIManager`，或项目侧再造第二入口 | Yoki README 和源码已经明确原生推荐入口是 `UIKit.OpenPanel<T>()/PushPanel/PopPanel`，并由 `UIRoot + UIPanel` 承担生命周期、栈、焦点和缓存；项目仍需要一个正式入口来承接 `EMenu`、`Shop/Craft`、关闭任务和 `GameState.Menu` 这些菜单语义，但这个入口不能复制第二套 panel lifecycle、cache 或 stack。当前 `UIManager` 的删除测试也成立：删掉它，`EMenu -> PanelType` 路由、返回键、关闭任务和 `GameState.Menu` 会散回各调用点；删掉 `UIKit`，面板生命周期与缓存机制会整体消失。因此这两者不是同职责双真相，而是“菜单语义 seam”与“panel 机制 seam”的分工。 | 系统菜单与上下文菜单继续走唯一菜单运行时入口；不迁具体业务真相进 UI 机制层；未来非菜单 utility panel 可直接按 `UIPanel + UIKit` 原生方式实现 |
| 对象池、输入绑定、文件存储、UI 缓存等工具 | `YokiFrame` 工具层 | 项目侧重复薄工具，或让 Yoki 架构层接管玩法生命周期 | 这些是通用工具职责，Yoki 已有更完整的对象池、SaveKit、InputKit、UIKit 等工具；但工具层不回答“世界状态是什么” | 工具胜出就直接用稳定工具入口，不再加包装层；`Architecture/SingletonKit` 不接管游戏生命周期 |
| 开放世界区域、Cell、派系、AI 日程、经济和局部模拟 | `FantasyWord` 后续自建世界宿主 | 塞进 `MapSystem`、`GameManager.XxxSystem`、TopDown manager 或 uMMORPG | 三方都没有完整覆盖 Skyrim/Kenshi 目标下的开放世界模拟；硬选任一第三方都会得到伪架构或错层接管 | 本 change 只登记边界，不创建空 `WorldSystem/WorldRuntime`；进入具体玩法规格后再建所有者、保存模型和验收 |
| 游戏内卡牌自走棋模式 | 后续独立 `Mode` 宿主，长期收藏接玩家数据 | 挂到 `GameManager.CardSystem`，或复用开放世界当前角色/地图作为牌局真相 | 卡牌自走棋是游戏的一部分，但单局棋盘、回合、单位状态、模式输入和胜负结算属于模式局部状态，不是开放世界当前地图状态 | 只建立卡牌模式矩阵和空占位门禁；进入实现前先定义模式生命周期、长期数据块和单局状态 |

## Non-Goals

- 本 change 不要求为了“更符合软件工程”立刻拆掉现有 13 个 `GameManager.XxxSystem` 快捷入口；它们的价值是快速实现和可读调用。当前目标是给它们划边界，并防止新世界/模式/工具职责继续挂上去。
- 本 change 不把“全局访问”本身判为问题；只有当全局访问导致同一职责有两个真相、绕过正式所有者、或把模式/世界/实体局部状态伪装成项目全局状态时，才进入整改。
- 本 change 不引入新的通用服务定位器、兼容层或“为了比 GameManager 更软件工程”的自造框架；更好的方案不是把静态入口包一层，而是按 `Project / World / Mode / Entity` 明确所有权，并让跨层协作走正式方法、命令或强类型事件。
- 本 change 不会因为已经把菜单运行时入口并回 `UIManager`，就默认允许继续造更多 `UIHost/UIKitFacade/UIPanelWrapper` 一类项目层包装。UI 机制的正式真相已经是 `UIKit` 原生 API；项目侧额外类型必须先证明自己只是在承接菜单语义入口，而不是再造第二套菜单运行时。
- 本 change 不新增第二套完整玩家控制器，也不把当前 `Movable + PlayerController` 正式闭包宣告为完整玩法完成；世界地图、战斗系统、背包系统和存档系统同样不在本 change 内实现完成；联机方向已更新为 FishNet 主机权威的有限人数合作候选，但本 change 不接入 FishNet、不创建联网框架或占位层。
- 本 change 不把 `EquipmentSystem` 宣告为正式玩法系统；它只是候选装备/换装表现资产和测试链路。
- 本 change 不把 EX-GAS 或 BroAudio 额外项目侧收口层宣告完成；但 EX-GAS 不能再被写成可有可无候选。若属性/效果/能力规则专项确认 GAS 胜出，必须直接替换同职责旧入口，不允许用额外包装层长期双跑。
- 本 change 不迁入 `dark-corridor` 的横版平台动作控制器或横版测试场景。
- 本 change 不因为“需要点击移动、控制组穿越、入口条件或超距自动靠近”就提前脑补运行时代码。没有正式单机/本地参考时，只登记为框架缺口，不把它们伪装成业务待做项或临时兼容层。
- 本 change 不保留旧 RPG 具体内容库作为“框架完整”的证明。系统框架需要少量代表性案例来验证数据合同；超出代表性案例的旧物品、旧角色存档、旧商店/制作/对话内容和旧 demo 流程应按引用证据直接删除，而不是继续搬运或归档成正式资产。
