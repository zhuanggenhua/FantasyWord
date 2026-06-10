# FantasyWord Unity 版 AI 主规范

> 本文件是 `C:\Gamedev\Unity\Project\FantasyWord` 的 AI 主入口。
> 当前游戏定位是俯视角开放世界像素游戏，强调高自由度与可扩展内容系统；小规模联机只作为候选方向预留，不作为当前必须实现的 MMORPG 目标。

## 全局规则

- 始终使用中文沟通、写文档和写总结。
- 修改代码和做规划前，先读本文件；按需求再读 `docs/ai/` 对应分册。
- 不使用 `git reset`、`git revert`、强制 `git checkout` 到旧提交等回滚/撤销历史操作。确需撤销时，先说明目标、影响和最小风险方案，等待用户确认。
- 未经用户当轮明确许可，不创建、切换、重建或删除分支、tag、worktree。
- 当前项目不是旧 `FantasyWorld` 恢复任务的延续；旧 `task_plan.md`、`findings.md`、`progress.md`、`RecoveryNotes/` 与 `MigrationStaging/` 只作为历史参考，不承载新游戏目标。
- 当前用户故事重新定义；旧恢复任务中的换装测试、单场景目标、旧主线剧情和旧任务验收不得自动继承到新项目。
- 需求未明确不得擅自扩写；当目标对象、影响范围、完成标准、是否实际落地等关键前提不清时，只能补证据或提出最小问题。
- 前提未锁定不得实施。准备修改代码、配置、数据、资源、场景或包配置前，必须确认问题对象、真相来源、目标入口/环境和验收口径。
- 清理资产、场景、文档或工具前必须先区分三类：正式链路、归档参考、真正垃圾。仍有参考价值但不进入当前正式链路的内容应归档，不直接删除。
- 涉及 Unity / 包 / SDK / CLI / 云服务文档查询时，按用户全局 ctx7 规则先用 `npx ctx7@latest library ...`，再用 `npx ctx7@latest docs ...`。
- 使用子 agent 做代码分析、设计、重构、实现、修复、测试等与改代码直接相关的任务时，必须显式使用 `gpt-5.4` + `high`。

## 渐进式披露入口

- 不确定先读哪篇文档、需要查文档导航：读 `docs/ai/文档索引.md`。
- 需求涉及 Unity 工程目录树、代码落点、Prefab/Scene/Asset 入口：读 `docs/ai/项目目录与入口.md`。
- 需求涉及 ProjectSettings、Packages、URP、Input System、场景、Prefab、序列化、构建：读 `docs/ai/Unity工程通用规范.md`。
- 需求涉及迁移方向、旧项目取舍、用户故事重定：读 `docs/ai/项目定位与迁移边界.md`。
- 用户说“参考”“复用”“直接复制模块”“按旧项目做”“查旧工程”“插件迁移”：先读 `docs/ai/参考源映射.md`。
- 需求涉及测试、验证、bug 修复、排查：读 `docs/ai/开发与验收规范.md`。
- 需求涉及 AIBridge、Unity Editor 自动化、测试、截图或 Console：读 `docs/ai/AIBridge常用命令.md`。
- 需求涉及 `Assets/Editor`、菜单工具、验证器、AI 自动化入口：读 `docs/ai/编辑器工具与验证入口.md`。
- 需求涉及 TDD、EditMode/PlayMode 测试、测试夹具：读 `docs/ai/TDD测试规范.md`。
- 需求涉及新增、保留或重写项目侧 C#：读 `docs/ai/代码参考矩阵.md`。
- 需求涉及像素素材、Sprite、动画、装备表现、导入设置：读 `docs/ai/素材与表现规范.md`。
- 需求涉及测试场景、样例场景、恢复场景或 AI 场景验证：读 `docs/ai/测试场景与AI复用入口.md`。

## 当前项目事实

- Unity 工程根目录：`C:\Gamedev\Unity\Project\FantasyWord`。
- 当前检测 Unity 版本：`6000.3.10f1`。
- 当前渲染管线：URP 2D。
- 当前输入方案：Unity Input System，入口为 `Assets/InputSystem_Actions.inputactions`。
- 当前资源主题：俯视角像素开放世界，已有 MiniFantasy 类像素素材和换装/装备相关试验资产。
- 当前联网方向：只考虑几人小规模联机；在复杂度、成本或玩法收益不匹配时可以放弃。

## 产品边界

- 本项目不是横版平台动作战斗项目，不继承 `dark-corridor` 的 CorgiEngine 横版玩家控制器、横版相机和横版测试场景目标。
- 本项目不是 MMORPG；即便后续加入联机，也优先按小队协作、房主/客户端或轻量会话模型评估。
- 先建立可维护的单机核心：俯视角移动、交互、地图、物品、角色成长、战斗、采集/制作、存档和内容数据流。
- 联机预留只影响架构约束：关键状态集中、输入和世界事件可序列化、不要把核心规则写死在单个场景实例或 UI 回调中。

## Unity 包接入

- 当前自动化目标是迁移到 `AIBridge` 包：`https://github.com/aiseog3121/unity-ai-bridge.git?path=/Packages/com.aibridge.unity`，包名 `com.aibridge.unity`。
- 旧 `UnityMCP` / `com.ivanmurzak.unity.mcp` 不再作为正式自动化入口；相关安装器、配置和 OpenUPM scope 清理前先核实引用，再按归档/垃圾分类处理。
- 本项目自动化默认通过 AIBridge 连接当前唯一正常 Unity Editor；不把 `Unity.exe -batchmode` 当日常验证入口。
- 插件迁移要先做依赖核验：包名、来源 URL、版本/commit、UPM path、依赖、旧入口迁移范围和本项目调用方式。

## 目录和文档原则

- 项目长期规范放在 `docs/ai/`。
- 历史恢复记录、旧任务计划和旧证据默认迁入或保留在 `docs/archive/` 语义下，不得继续作为当前目标入口。
- 新增项目侧 C# 前，先明确来源参考或当前项目正式设计依据；没有依据的临时探针只能短期存在，任务结束后删除或补齐记录。

## 本地 skills

本项目已放入本地 skill：

- `.codex/skills/aibridge`
- `.codex/skills/unity-production`
- `.codex/skills/unity-shader`
- `.codex/skills/unity-timeline-signal-debug`
- `.codex/skills/unity-ugui-mobile-adaptation`
- `.codex/skills/unity-uitoolkit`

使用这些 skill 前仍要先读本文件和对应 `docs/ai/` 分册。
