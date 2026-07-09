# FantasyWord Unity 版 AI 主规范

> 本文件是 `C:\Gamedev\Unity\Project\FantasyWord` 的 AI 主入口。
> 当前游戏定位是单机优先、确定会做有限人数联机合作的俯视角开放世界像素游戏，强调高自由度、可扩展内容系统与长期 Mod 支持；联机方向确定为 FishNet 优先评估的主机权威合作，但当前阶段不接入网络框架、不创建网络空壳。

## 全局规则

- 始终使用中文沟通、写文档和写总结。
- Git 提交信息默认使用中文；若沿用 Conventional Commits，类型和 scope 可保留英文，冒号后的摘要与正文必须使用中文。
- 修改代码和做规划前，先读本文件；按需求再读 `docs/ai/` 对应分册。
- 多方面参考不等于“全都要”。默认动作必须先把当前问题切成职责，再只比较这些职责直接相关的候选参考；不相关参考、或已在别的职责上定过正式 owner 的来源，不得为了显得全面再强行入场。
- “各取所需”里的“需”只指当前职责缺口，不指对某个参考的主观偏好。若两个来源竞争的是同一份作者数据、同一份运行时解释权、同一份技能时间轴、同一份命中框数据或同一份规则结算入口，就必须只留一个正式 owner，其它来源只能降级为局部证据、仅观察或待迁移候选。
- 多参考择优的执行顺序固定为：先裁决职责，再选正式 owner，再按该 owner 落实现；不得先把几个参考的同职责代码、数据格式或作者流程拼起来，再事后解释成“各取所需”。
- 多参考分析的默认写法必须先按`职责`组织，而不是按`参考项目名`组织。若结论仍是“这个参考抄一点、那个参考再抄一点”的巡礼式写法，视为尚未完成职责裁决，不能进入实现。
- 若单一参考已经完整承载当前职责，默认先整体对齐该参考，再证明哪些地方因本项目硬约束必须偏离；不得因为其它参考在局部也“有可取处”，就把同一职责拆成多源正式实现。
- 先判断当前问题到底属于“单一参考整体对齐”还是“多参考按职责分治”。只有当不同参考各自命中的职责边界清晰、且这些职责之间不争夺同一份正式数据或解释权时，才允许“各取所需”；否则默认整体对齐当前最完整的单一参考。
- “择优”不是按新旧、名气或个人熟悉度选，而是按当前职责的 `覆盖完整度`、`闭包完整度`、`与项目硬约束的贴合度`、`可直接落地性`、`后续维护成本` 排序；没有按这套口径比较，就不能宣称已经完成择优。
- 若决定采用“各取所需”，实现和文档都必须能回答 3 个问题：`这一块职责到底是什么`、`为什么只能由这个参考当 owner`、`其它参考在这块里为什么被排除`。回答不清就视为还没裁决完，不能继续落代码。
- “各取所需”落地后，每个职责都必须只剩一个正式落点：`作者数据入口`、`运行时解释入口`、`编辑/预览入口` 各自都只能有一个 owner。其它参考若被吸收，只能沉淀为该 owner 的约束、交互要求、验收要求或局部实现细节，不得继续保留同职责壳、并行菜单、并行资产格式或并行流程。
- 参考择优的默认汇报格式固定为 3 件事：`当前在裁决什么职责`、`这个职责谁是正式 owner`、`其它候选为什么这次不采用`。不要把“多方面参考”落实成全量参考巡礼或同职责混编。
- 涉及 proposal、design、重构说明或阶段方案时，只要结论依赖“多方面参考”“各取所需”“择优吸收”，就必须同步给出职责裁决结果；没有裁决结果，只能继续分析，不能直接进入实现或宣称架构已定。
- 当用户当前主任务已经明确锁定为`替换/重构/实现/继续做某个正式能力`时，规范、proposal、design、说明文档都只能算辅助交付，不能替代主任务本身。除非用户本轮明确改口为“先只改文档/先只改规范”，否则不得把文档更新汇报成该任务的主要完成结果。
- 若主任务是正式实现，而过程中发现规范缺口，默认动作是：先做最小必要规范补丁防止继续跑偏，再立刻回到主实现；不得停在“规范已补完”就汇报完成。
- 当用户说“继续”“继续你的任务”“开始重构/替换到某方案”时，默认指向上一轮已经锁定的主实施目标，而不是衍生出来的文档整理、说明补写或规范修订。若实际产出只动了文档、没推进主实施目标，必须明确说明“这不是主任务完成，只是辅助修正”。
- 当本轮主任务已经明确为`切到某个正式技术主轴`，例如“切到 EX-GAS / 改到 GAS / 替换到某插件正式链”，完成口径必须是：正式代码、正式数据入口或正式运行入口已经实际迁移，并至少有一条对应的真实验证证据；只改 `docs/ai/`、`openspec/`、proposal、变更说明或注释，最多只能算辅助动作，不能汇报成该主任务已完成。
- 不使用 `git reset`、`git revert`、强制 `git checkout` 到旧提交等回滚/撤销历史操作。确需撤销时，先说明目标、影响和最小风险方案，等待用户确认。
- 未经用户当轮明确许可，不创建、切换、重建或删除分支、tag、worktree。
- 当前项目不是旧 `FantasyWorld` 恢复任务的延续；旧 `task_plan.md`、`findings.md`、`progress.md`、`RecoveryNotes/` 与 `MigrationStaging/` 只作为历史参考，不承载新游戏目标。
- 当前用户故事重新定义；旧恢复任务中的换装测试、单场景目标、旧主线剧情和旧任务验收不得自动继承到新项目。
- 迁移彻底完成前，不主动提交、不推送；只有用户当轮明确允许提交时，才执行 `git commit`。
- 需求未明确不得擅自扩写；当目标对象、影响范围、完成标准、是否实际落地等关键前提不清时，只能补证据或提出最小问题。
- 前提未锁定不得实施。准备修改代码、配置、数据、资源、场景或包配置前，必须确认问题对象、真相来源、目标入口/环境和验收口径。
- 当前对话目标必须以用户在本轮上下文里明确讨论的对象为准；如果同时存在多个可能对象、场景或报错来源，必须先问最小确认问题。不得把最近打开的场景、最近出现日志的场景、自动化最后操作过的场景，直接当成用户当前要修的目标。
- 如果本轮问题对象、目标入口和验收场景已经锁定，且正式场景是在本轮自动化验证、截图、修复、PlayMode、场景恢复或同一条验证链中被弄脏的，默认直接保存该目标场景并继续验证；不得再向用户追问“是否保存 / 是否恢复 / 要不要更新规范”。保存前后必须做场景状态取证；若 dirty 场景不是当前目标场景，或来源不能证明来自本轮同一目标链路，才停在只读取证。
- 测试、验证和 bug 修复默认先看静态证据和必要 smoke；只有高风险合同缺口才补少量关键测试，不为每个小需求机械补同粒度测试。
- 清理、移动、复用第三方插件/素材、参考工程和项目业务资源前，先分清正式链路、归档参考、真正垃圾，并锁定来源、引用和 `.meta`/GUID 闭包。
- 未经用户当轮明确许可，禁止直接修改第三方插件源码、插件编辑器界面、插件内置样式、插件示例文档或插件生成器本体。第三方插件应优先按上游文档、包管理入口和公开扩展点接入；若发现插件能力不足，只能先提出项目侧扩展方案或 fork patch 提议，写清修改对象、依据、风险、回退方案和验证入口，得到确认后再实施。
- 不制造第二套同职责真相源。用户已允许改正式实现时，优先直接改正式代码、插件或参考来源本体；并行包装层、临时控制器、临时测试场景必须先有证据、流程理由和用户同意。
- 尊重原版设计。接入、修复或重构第三方插件、参考工程、原有项目系统、编辑器工具和既有运行时链路时，必须先识别原设计的正式入口、数据来源、加载时机、缓存策略、保存/刷新语义和验收位置；不得把“看起来正确”当成目标，擅自增加自动加载、自动选中、自动保存、重建缓存、替代窗口、替代菜单、包装入口或并行流程来绕开原设计。
- 原系统已有明确操作语义时，先按原操作说明或触发原操作。若问题只是没有执行原系统已有的刷新、导出、选择、保存、加载、生成或切换操作，应先告诉用户正确入口和操作，自动化验证也只能触发一次对应原入口；不得写补丁伪装成已修。只有在证据确认原入口本身因版本兼容、崩溃或真实缺陷无法使用时，才允许在原入口做最小兼容修复，或登记为明确的 fork patch / 项目侧适配，并写清偏离原设计的原因、影响和回退方式。
- 正式玩法链路的项目侧资产默认优先中文命名；第三方原始目录、代码符号和兼容性稳定 ID 可保留原名。
- 涉及 Unity / 包 / SDK / CLI / 云服务文档查询时，按用户全局 ctx7 规则先用 `npx ctx7@latest library ...`，再用 `npx ctx7@latest docs ...`。
- 使用子 agent 做代码分析、设计、重构、实现、修复、测试等与改代码直接相关的任务时，必须显式使用 `gpt-5.4` + `high`。

## 渐进式披露入口

- 不确定先读哪篇文档：读 `docs/ai/文档索引.md`。
- 需求涉及 Unity 工程目录树、代码落点、Prefab/Scene/Asset 入口：读 `docs/ai/项目目录与入口.md`。
- 需求涉及 ProjectSettings、Packages、URP、Input System、场景、Prefab、序列化、构建：读 `docs/ai/Unity工程通用规范.md`。
- 需求涉及 GameCore、输入、世界状态、表现层、单机运行时边界和运行时目录边界：读 `docs/ai/框架与运行时入口.md`。
- 需求涉及 UGUI、UI Toolkit、Canvas、RectTransform、LayoutGroup、GridLayoutGroup、ScrollRect 或 TextMeshPro：用 `.agents/skills/unity-ui-development`；移动端适配再叠加 `.codex/skills/unity-ugui-mobile-adaptation`。
- 需求涉及 FishNet、联机、主机权威、访客控制角色、网络同步、Mod 联机兼容或卡牌局内对战：读 `docs/ai/联机与Mod边界.md`、`docs/ai/框架与运行时入口.md` 和 `docs/ai/项目定位与迁移边界.md`。
- 用户说“参考”“复用”“直接复制模块”“按旧项目做”“查旧工程”“插件迁移”：先读 `docs/ai/参考源映射.md`。
- 需求涉及测试、验证、bug 修复、排查：读 `docs/ai/开发与验收规范.md`。
- 需求涉及 AIBridge、Unity Editor 自动化、测试、截图或 Console：读 `docs/ai/AIBridge常用命令.md`。
- 需求涉及 AI 自己读取本地图片、截图、裁图、图集、SpriteSheet、OCR 或看图验收：先用 `.codex/skills/safe-image-reading`，再按素材或验收场景读 `docs/ai/素材与表现规范.md`、`docs/ai/开发与验收规范.md`。
- 需求涉及新增、保留或重写项目侧 C#：读 `docs/ai/代码参考矩阵.md`。
- 需求涉及像素素材、Sprite、动画、装备表现、导入设置：读 `docs/ai/素材与表现规范.md`。
- 需求涉及俯视角角色 SpriteSheet、MiniFantasy 角色动画、装备层素材处理：读 `docs/ai/角色素材处理工作流.md`。
- 需求涉及 spec、proposal、change、阶段拆分或验收标准：先读 `openspec/AGENTS.md`。
- 其它低频专题，例如 GAS、TDD、编辑器工具、素材工具、用户故事、组件库、测试场景、迁移边界和 Mod 细节，先读 `docs/ai/文档索引.md` 再按需展开。

## 当前项目事实

- Unity 工程根目录：`C:\Gamedev\Unity\Project\FantasyWord`。
- 当前 Unity 版本：`6000.3.10f1`；渲染管线：URP 2D；输入方案：Unity Input System。
- 当前美术基线：MiniFantasy；当前主线仍是单机优先的俯视角像素开放世界。
- 联机是确定目标，方向为 FishNet 优先评估的有限人数主机权威合作；当前阶段仍不接入网络框架。Mod 支持是长期目标，当前只保留最小本地 Mod / 资源加载地基。
- 详细包接入、系统边界和验证入口见 `docs/ai/Unity工程通用规范.md`、`docs/ai/框架与运行时入口.md`、`docs/ai/联机与Mod边界.md`。

## 产品边界

- 不是横版平台动作项目，不继承 `dark-corridor` 的横版控制器/相机/测试场景。
- 不是 MMORPG；不做账号服、专用服务器持久世界、大规模 AOI、多人经济或全图多人同步。
- 先把单机核心做稳，再把内容数据化、稳定 ID 化、可审计、可迁移。

## Unity 包接入

- 当前自动化默认通过 AIBridge 连接 Unity Editor，不把 `Unity.exe -batchmode` 当日常验证入口。
- UnitySkills 正式接入方式是 Unity UPM 插件：`com.besty.unity-skills`，当前项目使用本地包依赖 `file:com.besty.unity-skills`，上游来源是 `https://github.com/Besty0728/Unity-Skills.git?path=/SkillsForUnity`。后续凡是需要从对话里操作 Unity Editor、创建或修改 GameObject/脚本/场景/资源、批量编辑、运行测试、读取 Editor 状态或执行编辑器自动化，默认优先通过该插件的 `Window > UnitySkills` 服务入口；`D:\codex-home\skills\unity-skills` 只是配套 AI 调用说明，不得替代插件安装。只有 UnitySkills 插件无法覆盖、项目已有专项流程更贴合，或需要沿用既有 AIBridge 验证链时，才叠加项目本地 `.codex/skills/aibridge`。
- 编辑器顶部 `场景` 菜单的单一真相源是 `Assets/Scenes` 下的 `.unity` 文件；`场景/刷新场景菜单` 必须扫描该目录生成可点击菜单。Build Settings 只负责构建配置，不再作为场景菜单列表来源。
- 插件迁移和包接入先核实包名、来源、版本、依赖和迁移范围；不要把旧入口或测试依赖混进正式链路。
- 第三方插件源码默认先按上游资产处理，但不是绝对禁止修改。只有在证据确认“插件原入口自身存在明确 bug、Unity/Odin 等版本兼容崩溃、或原配置文件带有明显错误默认值”时，才允许在原插件入口做最小 fork patch；补丁必须写清对象、现实症状、原因、修改范围、验证入口和回退方式。禁止用项目侧启动注册、自动刷新、自动补缓存、新造并行窗口或替代菜单来伪装插件流程已经正常。
- 详细包状态、资源来源和正式入口约定见 `docs/ai/Unity工程通用规范.md`、`docs/ai/参考源映射.md`、`docs/ai/素材与表现规范.md`。

## 目录和文档原则

- 项目长期规范放在 `docs/ai/`。
- `docs/ai/` 是类似 skill 的渐进式披露入口，只放长期有效的项目规则、路由索引、职责边界、正式入口和可复用方法；不得把它当成当轮工作台、临时草稿区、证据堆、交接记录或任务流水账。
- 写入 `docs/ai/` 前必须先判断文档类型：
  - 长期规则、入口路由、正式职责边界、可复用验收方法：可以进入 `docs/ai/`。
  - 阶段方案、proposal、change、任务拆分、一次性验收清单：进入 `openspec/`。
  - 旧任务记录、历史恢复证据、过期交接、已完成阶段日志：进入 `docs/archive/`。
  - 具体 bug 复盘：进入 `docs/ai/bugs/`，只在 `Bug排查索引.md` 保留入口。
  - 当轮临时发现、外部参考候选、源码摘录、搜索过程、待办流水：默认不得直接放在 `docs/ai/` 根目录；只有沉淀成长期可复用规范、矩阵或索引后，才允许迁入。
- `docs/ai/文档索引.md` 只做路由，不做全量文件清单。索引应告诉后续 AI “遇到什么任务先读什么”，而不是把所有临时文件、模板、历史台账都提升成正式入口。
- `docs/ai/` 根目录新增文档必须能回答三件事：长期职责是什么、触发它的任务是什么、它替代或约束哪些旧入口。回答不清时，先放到 `openspec/`、`docs/archive/` 或专项目录，不得为了方便直接塞进根目录。
- 正式规格和阶段性 change 放在 `openspec/`；当前只迁入 FantasyWord 自己的空规格框架，不继承 `dark-corridor` 的横版动作 change。
- 静态工作区预检脚本放在 `scripts/Invoke-WorkspacePreflight.ps1`，只检查空目录和已禁用旧入口，不启动 Unity、不修改资产。
- 历史恢复记录、旧任务计划和旧证据默认迁入或保留在 `docs/archive/` 语义下，不得继续作为当前目标入口。
- 新增项目侧 C# 前，先明确来源参考或当前项目正式设计依据；没有依据的临时探针只能短期存在，任务结束后删除或补齐记录。

## 本地 skills

本项目已放入本地 skill：

- 插件优先：`com.besty.unity-skills`（UPM：`file:com.besty.unity-skills`；上游：`https://github.com/Besty0728/Unity-Skills.git?path=/SkillsForUnity`）
- 配套 AI skill：`D:\codex-home\skills\unity-skills`
- `.agents/skills/code-comments`
- `.agents/skills/unity-ui-development`
- `.codex/skills/aibridge`
- `.codex/skills/safe-image-reading`
- `.codex/skills/unity-production`
- `.codex/skills/unity-shader`
- `.codex/skills/unity-timeline-signal-debug`
- `.codex/skills/unity-ugui-mobile-adaptation`
- `.codex/skills/unity-uitoolkit`

使用这些 skill 前仍要先读本文件和对应 `docs/ai/` 分册。涉及 Unity Editor 自动化时，先确认 UnitySkills 插件已在项目包依赖中接入并可通过 `Window > UnitySkills` 启动服务，再读配套 AI skill `D:\codex-home\skills\unity-skills\SKILL.md`，按任务类型补读项目专项 skill。

Unity 通用规则不再单独保留 `.agents/skills/unity` 兜底 skill；其有效部分已收口到本文件：

- 普通 Unity 工程、运行时、场景、Prefab、资源、测试和 Editor 自动化，默认优先使用 UnitySkills 插件；配套 AI skill `unity-skills` 只作为调用说明和模块索引，其中架构、运行时边界、性能和项目工程规范再叠加 `.codex/skills/unity-production`。
- UGUI / UI Toolkit 选择、Canvas、RectTransform、LayoutGroup、GridLayoutGroup、LayoutElement、ContentSizeFitter、ScrollRect、EventSystem、TextMeshPro 和运行时 UI 生成，默认使用 `.agents/skills/unity-ui-development`。
- 移动端 UGUI 适配、安全区、刘海屏、分辨率和横竖屏问题，在 `unity-ui-development` 基础上叠加 `.codex/skills/unity-ugui-mobile-adaptation`。
- UXML、USS、`UIDocument`、`VisualElement` 等 UI Toolkit 专项，使用 `.codex/skills/unity-uitoolkit`。
- ShaderLab、HLSL、URP/HDRP shader 和渲染特性，使用 `.codex/skills/unity-shader`。
- Unity Editor 自动化、PlayMode 验证、场景检查、截图和 Console 取证，使用 `.codex/skills/aibridge`。
- AI 读取本地图片、截图、裁图、图集、SpriteSheet、OCR 或看图验收，使用 `.codex/skills/safe-image-reading`；先做上下文预算门禁，再走轻量预览、局部裁图、OCR 或外部开图。
