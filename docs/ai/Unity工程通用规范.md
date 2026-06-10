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
- 输入：Unity Input System
- UI：UGUI / TextMesh Pro 资源存在
- Addressables：当前未检测到正式配置
- asmdef：旧 UnityMCP 安装器 asmdef 已退出正式入口；项目侧运行时代码尚未形成 asmdef 边界

## 包与插件边界

- 正式 Unity Editor 自动化统一迁移到 `com.aibridge.unity`。
- 旧 `com.ivanmurzak.unity.mcp` / UnityMCP 不再作为正式自动化入口。
- 第三方包接入必须记录：包名、来源 URL、版本或 commit、UPM path、依赖、旧入口迁移范围和本项目调用方式。
- 插件本体与项目玩法代码要分层；玩法代码不要散落直接依赖第三方 API，优先通过项目侧门面或服务接入。
- 插件迁移前先核实授权、Unity 版本、依赖、命名冲突、`.meta`/GUID 和无关业务耦合。

## 运行时架构约束

- 俯视角玩家控制、相机、交互、地图和战斗是本项目的正式方向。
- 关键玩法状态应集中在可测试、可序列化、可保存的系统或数据对象中，不写死在 UI 组件或单个场景对象里。
- 若后续进入联机评估，核心规则要先能区分输入、命令、世界状态和表现层。
- 不提前搭建空的网络框架；只有当联机进入明确目标时再建立 `Networking` 正式目录。

## 资源、序列化与场景

- 关键配置优先使用 ScriptableObject、JSON、YAML、C# 常量/record 等可审计载体。
- 场景、Prefab、Inspector 负责对象层级、组件挂载、静态引用关系、视觉配置和初始显示状态。
- 脚本负责运行时状态推进、交互路由、规则与行为逻辑。
- 修改 Prefab、场景层级或组件挂载后，要回读核对重复组件、同职责副本和 prefab override。
- 正式资产迁移默认保留 `.meta`，避免无意改变 GUID。

## 自动化与验证

- 本地自动化默认使用 AIBridge 连接当前唯一正常 Unity Editor。
- 不默认启动第二个 Unity Editor。
- 不把 `Unity.exe -batchmode` 当日常验证入口；batchmode 仅用于 CI、当轮明确授权或无 Editor 构建场景。
- 自动化默认不抢 Unity 前台、不聚焦窗口、不切走用户输入焦点。
- 文档、包配置和静态目录调整优先用静态验证；只有需要证明 Unity 导入、编译或场景状态时才升级到 AIBridge。

## Inspector、注释与可维护性

- 项目侧 C# 公开/受保护/内部类型、ScriptableObject 配置、序列化字段、编辑器菜单、验证入口和生命周期/协程/事件/物理/存档等非显然逻辑要写必要中文注释。
- Inspector 暴露字段应显示中文名称和必要说明；如果后续接入 NaughtyAttributes，优先使用 `[Label("中文名")]`、`[BoxGroup("中文分组")]` 等。
- 不为简单赋值和自说明代码堆空话注释。
