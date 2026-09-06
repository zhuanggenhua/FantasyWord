---
name: knowledge
description: FantasyWord 项目知识导航：查规范、项目事实、设计现状、经验教训时先从这里定位。
metadata:
  type: index
  status: 已交付
---

# Knowledge（项目知识库导航）

本文件回答“遇到某类任务先读哪里”。`.spec/knowledge/features/project/` 是当前 FantasyWord 项目知识库正式入口。

## standards（长期规范）

| 文档 | 何时查 |
|------|--------|
| [`standards/framework-layering.md`](standards/framework-layering.md) | 裁决 YokiFrame、GameCore、Gameplay 的职责边界、依赖方向和迁移落点时查。 |
| [`standards/gameplay-architecture.md`](standards/gameplay-architecture.md) | 裁决 FantasyWord 具体业务对象、领域 owner、目录组织、Mod 与未来联机扩展边界时查。 |
| [`standards/code-design.md`](standards/code-design.md) | 做代码职责拆分、设计模式选择、反模式审查、防护性架构裁决时查。 |
| [`standards/runtime-implementation-boundaries.md`](standards/runtime-implementation-boundaries.md) | 写运行时逻辑、配置真相、依赖入口、UI、资源或性能热路径时查。 |
| [`standards/unity-serialization-safety.md`](standards/unity-serialization-safety.md) | 修改 Unity 场景、Prefab、资源、材质、动画、`.meta` 或 ProjectSettings 前查。 |
| [`standards/debugging-evidence.md`](standards/debugging-evidence.md) | 排查 bug、回归、资源缺失、表现异常、日志和证据链时查。 |
| [`standards/workflow.md`](standards/workflow.md) | 做开发流程、提交、验证、知识沉淀、规范维护时查。 |
| [`standards/testing.md`](standards/testing.md) | 做测试、验收、bug 修复、TDD 策略和验证证据时查。 |
| [`standards/code-style.md`](standards/code-style.md) | 写代码、写注释、建文档、命名和生成物处理时查。 |
| [`standards/skill-conflicts.md`](standards/skill-conflicts.md) | 查看外部 workflow、上游 skill 与项目 `.spec/skills` 的合并和已收口结果时查。 |

## project docs（已迁入的 FantasyWord 知识库）

| 任务 | 继续读取 |
|------|----------|
| 进入 FantasyWord 项目事实目录、先找当前专项入口 | `.spec/knowledge/features/project/README.md` |
| 不确定先读哪篇 | `.spec/knowledge/features/project/文档索引.md` |
| Unity 工程目录、代码落点、Prefab/Scene/Asset | `.spec/knowledge/features/project/项目目录与入口.md` |
| ProjectSettings、Packages、URP、Input System、场景、Prefab、序列化、构建 | `.spec/knowledge/features/project/Unity工程通用规范.md` |
| YokiFrame / GameCore / Gameplay 分层、代码迁移落点 | `.spec/knowledge/standards/framework-layering.md` |
| Gameplay 具体业务、开放世界、队伍、派系、经济、表现或模式 owner | `.spec/knowledge/standards/framework-layering.md`、`.spec/knowledge/standards/gameplay-architecture.md` |
| 代码设计、职责拆分、抽象、反模式、防护性架构 | `.spec/knowledge/standards/code-design.md` |
| 运行时配置真相、依赖入口、UI/资源/性能边界 | `.spec/knowledge/standards/runtime-implementation-boundaries.md` |
| Unity YAML、Prefab、场景、`.meta`、ProjectSettings 写入安全 | `.spec/knowledge/standards/unity-serialization-safety.md` |
| GameCore、输入、世界状态、表现层、运行时边界 | `.spec/knowledge/standards/framework-layering.md`、`.spec/knowledge/features/project/框架与运行时入口.md` |
| 对照 CardLoop 的通用文档结构、内容结构和代码框架同步裁决 | `.spec/knowledge/standards/framework-layering.md`、`.spec/knowledge/standards/gameplay-architecture.md` |
| EX-GAS、技能/属性/效果规则、GameCore 与 GAS 生成配置集成边界 | `.spec/knowledge/features/project/Unity架构与GAS规范.md`、`.spec/knowledge/features/project/EX-GAS-2.0重评估.md` |
| UI、UGUI、UI Toolkit、Canvas、TMP | `.spec/skills/unity-ui-development/SKILL.md` |
| 2D Tilemap、Grid、Tile Palette、RuleTile、TilemapCollider2D | `.spec/skills/unity-tilemap-2d/SKILL.md` |
| FishNet、联机、Mod 边界 | `.spec/knowledge/features/project/联机与Mod边界.md`、`.spec/knowledge/features/project/项目定位与迁移边界.md` |
| 参考、复用、旧工程、插件迁移 | `.spec/knowledge/features/project/参考源映射.md` |
| 测试、验证、bug 修复、排查 | `.spec/knowledge/standards/debugging-evidence.md`、`.spec/knowledge/features/project/开发与验收规范.md` |
| UnitySkills、Unity Editor 自动化、场景、资源、Prefab、测试 | `.spec/skills/unity-skills/SKILL.md` |
| Unity CLI 查询、打开项目、无头验证候选 | `.spec/skills/unity-cli/SKILL.md` |
| UPM 包查询、安装、移除、升级和包边界裁决 | `.spec/skills/unity-package-management/SKILL.md`、`.spec/knowledge/features/project/第三方插件接入清单.md` |
| AIBridge、既有自动化验证链、Console、截图 | `.spec/knowledge/features/project/AIBridge常用命令.md` |
| 新增、保留或重写项目侧 C# | `.spec/knowledge/features/project/代码参考矩阵.md` |
| 玩家输入朝向、AI 追击转向、攻击前对准、战斗游走朝向、武器瞄准、四向动画方向 | `.spec/knowledge/features/project/角色移动与朝向参考矩阵.md` |
| 像素素材、Sprite、动画、装备表现 | `.spec/knowledge/features/project/素材与表现规范.md` |
| 当前普通换装系统、动作/方向驱动、Shader 合成、装备槽、坐骑边界和阴影职责 | `.spec/knowledge/features/project/换装系统现状说明.md` |
| 换装功能、坐骑原版素材接入、装备工作台、FrameData 帧编辑器、Body/Head UV、Idle/Walk/Attack、完整截图验收 | `.spec/skills/equipment-system-workflow/SKILL.md` |
| 坐骑素材规律、坐骑动作语义、通用逐帧播放器、动物/载具骑手层对接 | `.spec/knowledge/features/project/坐骑动画素材规律.md` |
| 换装动画流程、SpriteLibrary 方向变体、资源路径、Yoki/YooAsset 边界 | `.spec/knowledge/features/project/换装动画与资源流程对照.md` |
| 俯视角角色素材、MiniFantasy、装备层素材 | `.spec/knowledge/features/project/角色素材处理工作流.md` |
| 2D 移动与场景组织专项事实、候选排序和已收口结论 | `.spec/knowledge/features/project/2D移动与场景组织找参考清单.md`、`.spec/knowledge/features/project/2D移动与场景组织缺口矩阵.md` |
| spec、proposal、change、阶段拆分 | `openspec/AGENTS.md` |

## skills（整合后的工作流）

| Skill | 来源与处理 |
|-------|------------|
| `.spec/skills/spec-steward` | 吸收 LumioAgent，按本项目五层落点规则改写。 |
| `.spec/skills/brainstorming` | 吸收 LumioAgent，改为“先方案、获确认后再实施”的设计前流程。 |
| `.spec/skills/before-you-code` | 吸收 LumioAgent，改为 FantasyWord 前提锁定与渐进披露入口。 |
| `.spec/skills/systematic-debugging` | 与现有 bug 红线合并，强调原始症状保真和止血口径。 |
| `.spec/skills/verification-before-completion` | 吸收 LumioAgent，作为完成声明前证据门禁。 |
| `.spec/skills/equipment-system-workflow` | 项目新增，用于 FantasyWord 换装功能、帧编辑器 UV 配置和运行时截图验收。 |
| `.spec/skills/task-breakdown` | 吸收 LumioAgent，适配“不擅自 worktree/分支”和项目任务卡。 |
| `.spec/skills/subagent-driven-development` | 吸收 LumioAgent，作为子 agent 派发、模型配置和 worktree 禁止口径的正式 owner。 |
| `.spec/skills/using-git-worktrees` | 吸收 LumioAgent 的安全检查，但改为“默认禁止，需用户明确许可”。 |
| `.spec/skills/writing-plans` | 改为指向 `D:\codex-home\skills\planning-with-files\SKILL.md`，避免第二套长期计划。 |
| `.spec/skills/test-driven-development` | 改成项目务实 TDD 策略，不强制所有小改动 TDD。 |
| `.spec/skills/receiving-code-review` | 吸收 LumioAgent，用于处理 review 反馈。 |
| `.spec/skills/unity-skills` | 对照 CardLoop 补入的项目薄入口，只路由到 `Packages/com.besty.unity-skills/unity-skills~`，不复制上游模块资料。 |
| `.spec/skills/unity-cli` | 对照 CardLoop 补入的项目薄入口，只裁决 Unity 官方 CLI 的安全查询、打开项目和明确授权后的无头候选，不替代 UnitySkills。 |
| `.spec/skills/unity-package-management` | 对照 CardLoop 补入的项目薄入口，只裁决 UPM 包查询、安装、移除、升级和包台账验证，不替代插件业务接入。 |
| `.spec/skills/gas-ability-authoring` | 迁入项目 skill，用于 FantasyWord EX-GAS 技能制作、修改、排查和验收。 |
| `.spec/skills/unity-tilemap-2d` | 迁入项目 skill，用于 FantasyWord 2D Tilemap、Grid、Tile Palette、RuleTile 和碰撞链路。 |
| `.spec/skills/unity-timeline-signal-debug` | 迁入项目 skill，用于 Timeline Signal 到业务入口的链路排查。 |
| `.spec/skills/unity-ui-development` | 迁入项目 skill，用于 UGUI、UI Toolkit、TMP、Prefab/场景 UI 与编辑器 UI 的项目落点裁决。 |

## agents（职能角色）

| Agent | 何时查 |
|-------|--------|
| [`.spec/agents/reviewer.agent.md`](../agents/reviewer.agent.md) | 需要隔离上下文做完整交付审查时查；普通小改动可不派审。 |

## lessons（反复错误升级池）

| 文档 | 何时查 |
|------|--------|
| [`lessons.md`](lessons.md) | 同类错误第二次出现、用户纠偏、review 反复退回时查；第三次左右升级为正式规范或 skill。 |
