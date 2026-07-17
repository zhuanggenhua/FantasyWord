---
name: Unity工程通用规范
description: 项目知识：Unity工程通用规范.md：Unity工程通用规范。
metadata:
  type: doc
  status: 已交付
---

# Unity 工程通用规范

## 工程探测

涉及 Unity 工程、包、资源、场景或构建时，先检查：

- `ProjectSettings/ProjectVersion.txt`
- `Packages/manifest.json`
- `Packages/packages-lock.json`
- `ProjectSettings/GraphicsSettings.asset`
- `ProjectSettings/ProjectSettings.asset`
- `ProjectSettings/InputManager.asset`
- `Assets/**/*.asmdef`
- `Assets/**/*.inputactions`
- `Assets/**/AddressableAssetSettings.asset`

汇报时至少明确：Unity 版本、渲染管线、输入方案、UI 系统、资源加载方案、是否使用 asmdef、是否使用 Addressables、目标平台和构建入口。

## 当前检测基线

- Unity：`6000.3.10f1`
- 渲染：URP 2D
- 输入：Unity Input System；当前正式资产入口仍是 `Assets/InputSystem_Actions.inputactions`，并已对齐回 `2DRPGEngine` 参考所需的 `Gameplay / UI / None` 动作图
- UI：UGUI / TextMesh Pro 资源存在
- Addressables：已接入官方包；当前已用于 Chris 资源/Mod 最小地基的外部 catalog 加载，官方玩法数据和全部资源管理尚未迁入 Addressables
- asmdef：当前仓库已经存在插件本体、`GameCore`、编辑器工具和测试程序集边界；这是现状，不等于后续项目侧还应继续扩张 asmdef。业务代码默认不新建、不保留项目侧 asmdef，避免 AI 漏加引用。

## 包与插件边界

- 正式 Unity Editor 自动化统一迁移到 `com.aibridge.unity`。
- 旧 `com.ivanmurzak.unity.mcp` / UnityMCP 不再作为正式自动化入口。
- 当前包与插件台账以 `.spec/knowledge/features/project/第三方插件接入清单.md` 为准；常用正式工具至少包括 `Assets/Plugins/GAS`、`Assets/Plugins/YokiFrame`、`Assets/Plugins/Demigiant/DOTween`、`Packages/com.cysharp.unitask`、`Assets/Plugins/MackySoft.SerializeReferenceExtensions`、`Assets/Plugins/azixMcAze.SerializableDictionary`、`com.ami.broaudio`、`com.aibridge.unity` 与相关 Unity 官方包。
- 当前 UPM Git 插件：`com.ami.broaudio`，来源 `https://github.com/man572142/Bro_Audio.git?path=/Assets/BroAudio#3.1.3`。
- 当前 BroAudio 项目级配置资源：`Assets/Plugins/BroAudio`，来自参考项目同路径，包含 `Resources/AudioPlayer.prefab`、`SoundManager.prefab`、`BroAudioMixer.mixer`、`BroRuntimeSetting.asset`、`GlobalPlaybackGroup.asset` 和 Editor Resources；它不是 BroAudio 包源码本体。
- 当前 Unity 官方依赖：`com.unity.addressables`，当前用于 UniTask Addressables 模块，并已作为 `GameCore/Runtime/Resources` 与 `GameCore/Runtime/Mods` 的外部 catalog 加载基础；是否把官方玩法资源整体迁到 Addressables 仍需另行评估。
- `Packages/packages-lock.json` 只能由 Unity Package Manager 重新解析后更新；若它暂时未包含 `manifest.json` 新增包，不手写伪造锁文件，等统一 Unity 导入验证时刷新。
- BroAudio 项目级资源中的脚本 GUID 来自 `com.ami.broaudio` 包源码；静态扫描若只看 `Assets` 和嵌入包，会暂时显示这些 GUID 缺失，必须等 Unity Package Manager 解析 Git 包后再判定。
- 第三方包接入必须记录：包名、来源 URL、版本或 commit、UPM path、依赖、废弃入口迁移范围和本项目调用方式。
- 插件本体与项目玩法代码要分层；玩法代码不要散落直接依赖第三方 API，应由项目正式拥有者闭包统一接入，不额外再造 facade、wrapper 或 adapter。
- 导入且能编译的插件默认可以按插件自身职责使用；如果某个职责已有插件能承担，优先使用插件原能力或公开扩展点，不要另造项目侧重复实现。需要进入核心玩法真相、数据真相、地图/导航真相、场景加载真相、作者入口或长期运行时生命周期时，要写清楚插件承担哪一段正式 owner、项目从哪里调用、旧项目侧替身如何退场以及怎么验收没有第二套状态。
- 插件不是绝对不可改，但插件改动只能解决插件原入口的真实缺陷，例如 Unity 版本兼容崩溃、插件窗口自身空引用、UXML 错误默认值或官方流程无法继续的明确 bug。若只是项目数据没刷新、表没导出、缓存没生成或用户还没点原插件刷新按钮，必须回到原流程操作，不得用自动刷新、启动注册、替代窗口或项目侧缓存页补丁掩盖。
- BroAudio 包本体通过 Package Manager 接入；项目级 Resources 配置可放 `Assets/Plugins/BroAudio`，音频玩法代码继续只走 `GameCore` 正式音频闭包。
- 插件迁移前先核实授权、Unity 版本、依赖、命名冲突、`.meta`/GUID 和无关业务耦合。

## asmdef 策略

- 第三方插件自带 asmdef 维持原状，不把“项目侧少用 asmdef”误解成去拆第三方插件程序集。
- 项目侧 `Assets/Scripts` 默认不新增 asmdef；AI 开发链更容易漏引用，除非已经证明该目录必须独立编译，否则优先放回主项目程序集。
- 只有以下几类情况默认允许项目侧新建或保留 asmdef：
  - Unity Test Framework 测试程序集
  - `Assets/Editor` 下必须隔离为编辑器程序集的工具代码
  - 明确要与第三方插件形成长期稳定边界，且已有真实编译价值证明的独立模块
- “候选模块”“演示模块”“试验功能”“为了看起来更分层”都不是新增 asmdef 的充分理由。
- 若某个项目侧 asmdef 只是为了给候选目录分层、没有稳定对外边界、且持续造成 AI 漏引用风险，应优先记为待收敛对象，而不是继续照此扩张。
- `Assets/Scripts/Presentation/EquipmentSystem` 是正式换装表现业务目录，但不再保留项目侧 asmdef；换装表现业务代码跟随主项目程序集编译，第三方插件、框架层和必要编辑器/测试程序集按各自边界处理。

## 仓库配置

- `.gitignore` 负责排除 Unity 缓存、本地 AI 缓存、构建产物和生成文件。
- `.gitattributes` 负责 Unity 文本归一、YAML 合并标记、GitHub 语言统计降噪和素材类大文件 LFS 标记。
- `scripts/Invoke-WorkspacePreflight.ps1` 是静态预检入口，只检查正式目录里的空目录和禁用废弃入口；它不启动 Unity、不修改 Library、不修复资产数据库。
- `scripts/Invoke-FoundationStaticGate.ps1` 是 foundation 静态门禁入口；当前检查 `GameManager + AGameSystem + GameConfig + DatabaseRegistry + ICommand + GameRuntimeEvents + MapInfo/Checkpoint + Persistence 数据合同` 最小闭包、启动场景的新接线、项目侧关键 asmdef 边界与正式包依赖声明，并拒绝旧 `Bootstrapper/ModuleInstaller` 场景接线，同时禁止旧 `NotificationSystem` 回归。
- 预检允许保留有 `.meta` 且仍有参考/GUID 价值的占位目录，例如 MiniFantasyUV、EquipmentSystem 工具/Shader 预留目录和像素素材来源目录；不要把这类目录当成垃圾删除。
- 涉及 Library、PackageCache、SourceAssetDB 或 Unity 进程的恢复脚本不默认迁入，也不作为日常迁移步骤；需要时先说明目标、影响和是否会移动缓存数据。

## 临时代码与测试代码

- 自动化测试、回归测试、合同测试一律放 `Assets/Tests`，不要因为“是测试代码”就塞回业务脚本目录。
- `Assets/Scripts/test` 只用于项目侧临时验证、试验性脚本、一次性运行时探针，或已经完成流程理由文档并获得用户批准的临时试做代码。
- `test` 在本项目里表示“临时代码/试验代码”，不是 Unity Test Framework 自动化测试目录；自动化测试仍以 `Assets/Tests` 为正式入口。
- 若同职责正式闭包和参考已经存在，不得把 `Assets/Scripts/test` 当成并行实现缓冲区；验证应直接回到正式闭包。
- 若某段 `Assets/Scripts/test` 代码后续被证明要长期保留，先回到参考矩阵和正式闭包判断是否应直接并回正式目录；不要把 `test` 目录当成长期半正式模块。

## 运行时架构约束

- 俯视角玩家控制、相机、交互、地图和战斗是本项目的正式方向。
- 关键玩法状态应集中在可测试、可序列化、可保存的系统或数据对象中，不写死在 UI 组件或单个场景对象里。
- 核心规则要能区分输入、命令、世界状态和表现层；这是复杂单机机制、Mod 兼容和确定联机目标共同需要的维护要求。
- 不提前搭建空的网络框架；当前不建立 `Networking` 正式目录，也不接入 FishNet 包。FishNet 作为后续联机阶段有限人数主机权威合作的首选评估框架。

## 资源、序列化与场景

- 关键配置优先使用 ScriptableObject、JSON、YAML、C# 常量/record 等可审计载体。
- Mod 支持是长期必须目标；新增正式配置、数据库条目、资源引用和存档字段时，默认考虑外部内容包能否追加、覆盖、禁用或缺失回退。
- 正式进入玩法链路的项目侧 `Prefab`、`ScriptableObject`、`Sprite Library`、正式测试场景、场景内正式实例名和 Inspector 暴露名称默认优先中文命名；第三方原始资源目录可保留原名，但项目正式落点不得继续沿用误导性的英文占位名。
- 编辑器顶部 `场景` 菜单的列表真相源固定为 `Assets/Scenes`，不是 Build Settings。新增、删除或移动正式场景时，先保证 `.unity` 文件位于 `Assets/Scenes`，再执行 `场景/刷新场景菜单`；Build Settings 只服务构建，不作为场景菜单过滤器。
- 可被内容引用的数据必须优先使用稳定 ID、数据库引用或资源键；不要让运行时规则依赖不可迁移的场景实例名、临时数组下标、硬编码 Resources 路径或 Inspector 顺序。
- 存档数据需要能处理“Mod 被移除、版本升级、资源缺失、ID 改名”的情况；至少要有可诊断的失败信息和安全回退，不得直接让旧存档崩溃。
- Addressables 当前已经成为本地 Mod 外部 catalog 加载的最小方案；但资源包格式、依赖解析、平台限制、内容校验和官方资源是否整体迁入 Addressables 仍需专项设计，不能把“能加载 catalog”误报为完整 Mod 工作流。
- 场景、Prefab、Inspector 负责对象层级、组件挂载、静态引用关系、视觉配置和初始显示状态。
- 脚本负责运行时状态推进、交互路由、规则与行为逻辑。
- 新增或改写 `[SerializeField]`、Inspector 开关、组名、引用字段时，不得假设 C# 字段初始化值会自动回填已有场景、Prefab 或嵌套序列化控制器；必须检查目标实例的真实序列化值，或提供明确迁移、旧数据默认解析、`OnValidate` 修复和原场景运行验收。
- 修改 Prefab、场景层级或组件挂载后，要回读核对重复组件、同职责副本和 prefab override。
- 正式资产迁移默认保留 `.meta`，避免无意改变 GUID。

## 自动化与验证

- 本地自动化默认使用 AIBridge 连接当前唯一正常 Unity Editor。
- 不默认启动第二个 Unity Editor。
- 不把 `Unity.exe -batchmode` 当日常验证入口；batchmode 仅用于 CI、当轮明确授权或无 Editor 构建场景。
- 自动化默认不抢 Unity 前台、不聚焦窗口、不切走用户输入焦点。
- 文档、包配置和静态目录调整优先用静态验证；只有需要证明 Unity 导入、编译或场景状态时才升级到 AIBridge。

## Inspector、注释与可维护性

- 代码必须优先适合人阅读：目录名、类型名、字段名、Inspector 文案、注释和测试名称都要能让维护者快速判断职责，不用靠猜历史来源。
- 项目侧 C# 公开/受保护/内部类型、ScriptableObject 配置、序列化字段、编辑器菜单、验证入口和生命周期/协程/事件/物理/存档等非显然逻辑要写必要中文注释。
- 注释不能缺，但也不能灌水。必须说明职责、调用契约、边界、为什么这样做、错误配置会怎样；禁止把“给变量赋值”“遍历列表”这类代码表面行为翻译成中文。
- 当代码吸收 `2DRPGEngine`、`TopDownEngine` 或 `YokiFrame` 的能力时，关键类型或正式入口要在注释或文档中说明来源边界和当前项目真相源，避免以后误以为还存在兼容层或双轨实现。
- 新增系统、工具、编辑器窗口、验证脚本、ScriptableObject 和 Inspector 暴露字段时，默认同步补中文注释、中文 `Tooltip` / `Header`；当前不得假设 NaughtyAttributes 已接入。如果后续重新接入对应插件，才允许使用其中文标签能力。
- 需要新增、改写或审查源码注释时，先读全局 `D:\codex-home\skills\code-comments\SKILL.md`；本项目当前没有 `.agents/skills/code-comments/SKILL.md`。
- Inspector 暴露字段应显示中文名称和必要说明；若后续重新接入 NaughtyAttributes 或同类 Inspector 辅助插件，先在插件清单登记落点和用途，再使用 `[Label("中文名")]`、`[BoxGroup("中文分组")]` 等插件能力。
- 不为简单赋值和自说明代码堆空话注释。
