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
| [`standards/workflow.md`](standards/workflow.md) | 做开发流程、提交、验证、知识沉淀、规范维护时查。 |
| [`standards/testing.md`](standards/testing.md) | 做测试、验收、bug 修复、TDD 策略和验证证据时查。 |
| [`standards/code-style.md`](standards/code-style.md) | 写代码、写注释、建文档、命名和生成物处理时查。 |
| [`standards/dispatch.md`](standards/dispatch.md) | 派发子 agent、触发 reviewer、写交接提示或判断串并行边界时查。 |

## project docs（FantasyWord 项目知识）

| 任务 | 继续读取 |
|------|----------|
| 新增功能设计现状文档 | `.spec/knowledge/features/_TEMPLATE.md` |
| 不确定先读哪篇 | `.spec/knowledge/features/project/文档索引.md` |
| Unity 工程目录、代码落点、Prefab/Scene/Asset | `.spec/knowledge/features/project/项目目录与入口.md` |
| ProjectSettings、Packages、URP、Input System、场景、Prefab、序列化、构建 | `.spec/knowledge/features/project/Unity工程通用规范.md` |
| GameCore、输入、世界状态、表现层、运行时边界 | `.spec/knowledge/features/project/框架与运行时入口.md` |
| EX-GAS、GameplayEffect、属性作者源与当前资源属性边界 | `.spec/knowledge/features/project/Unity架构与GAS规范.md`、`.spec/decisions/0071-formal-gas-resource-modifier-and-damage-owner.md`、`.spec/decisions/0073-ex-gas-attribute-authoring-single-source.md` |
| UI、UGUI、UI Toolkit、Canvas、TMP | `.agents/skills/unity-ui-development/SKILL.md` |
| 2D Tilemap、Grid、Tile Palette、RuleTile、TilemapCollider2D | `.codex/skills/unity-tilemap-2d/SKILL.md` |
| FishNet、联机、Mod 边界 | `.spec/knowledge/features/project/联机与Mod边界.md`、`.spec/knowledge/features/project/项目定位与迁移边界.md` |
| 参考、复用、旧工程、插件迁移 | `.spec/knowledge/features/project/参考源映射.md` |
| 测试、验证、bug 修复、排查 | `.spec/knowledge/features/project/开发与验收规范.md` |
| AIBridge、Unity Editor 自动化、Console、截图 | `.spec/knowledge/features/project/AIBridge常用命令.md` |
| AI 读图、OCR、截图核对、SpriteSheet | 已暂停：`.codex/skills/safe-image-reading/SKILL.md` 不再作为当前入口 |
| 新增、保留或重写项目侧 C# | `.spec/knowledge/features/project/代码参考矩阵.md` |
| 玩家输入朝向、AI 追击转向、攻击前对准、战斗游走朝向、武器瞄准、四向动画方向 | `.spec/knowledge/features/project/角色移动与朝向参考矩阵.md` |
| 像素素材、Sprite、动画、装备表现 | `.spec/knowledge/features/project/素材与表现规范.md` |
| 当前普通换装系统、动作/方向驱动、Shader 合成、装备槽、坐骑边界和阴影职责 | `.spec/knowledge/features/project/换装系统现状说明.md` |
| 换装功能、坐骑原版素材接入、装备工作台、FrameData 帧编辑器、Body/Head UV、Idle/Walk/Attack、完整截图验收 | `.spec/skills/equipment-system-workflow/SKILL.md` |
| 坐骑素材规律、坐骑动作语义、通用逐帧播放器、动物/载具骑手层对接 | `.spec/knowledge/features/project/坐骑动画素材规律.md` |
| 换装动画流程、SpriteLibrary 方向变体、资源路径、Yoki/YooAsset 边界 | `.spec/knowledge/features/project/换装动画与资源流程对照.md` |
| 俯视角角色素材、MiniFantasy、装备层素材 | `.spec/knowledge/features/project/角色素材处理工作流.md` |
| spec、proposal、change、阶段拆分 | `openspec/AGENTS.md` |

## skills（项目工作流）

| Skill | 职责 |
|-------|------|
| `.spec/skills/spec-steward` | 判断规范、知识、skill、任务卡和决策记录的正确落点，并同步索引。 |
| `.spec/skills/brainstorming` | 设计或需求未收敛时，先形成方案和决策点，再进入实施。 |
| `.spec/skills/before-you-code` | 动手前锁定问题对象、真相来源、目标入口/环境和验收口径。 |
| `.spec/skills/systematic-debugging` | 处理 bug、测试失败和异常行为，强调原始症状保真和根因定位。 |
| `.spec/skills/verification-before-completion` | 收口前取得新鲜验证证据，避免只用推测声明完成。 |
| `.spec/skills/equipment-system-workflow` | 处理 FantasyWord 换装功能、帧编辑器 UV 配置和运行时截图验收。 |
| `.spec/skills/task-breakdown` | 拆解多步骤或多模块任务，并约束同一文件集重叠任务串行执行。 |
| `.spec/skills/subagent-driven-development` | 管理子 agent 派发、模型规格、审查边界和禁止二次派生。 |
| `.spec/skills/using-git-worktrees` | 仅在用户明确授权时进入受控 worktree 检查与创建流程。 |
| `.spec/skills/writing-plans` | 将长期计划路由到 `D:\codex-home\skills\planning-with-files\SKILL.md`，避免第二套计划真相源。 |
| `.spec/skills/test-driven-development` | 使用项目务实 TDD 策略，不强制所有小改动补同粒度测试。 |
| `.spec/skills/receiving-code-review` | 处理 review 反馈，先核实问题再修改。 |

## agents（职能角色）

| Agent | 何时查 |
|-------|--------|
| [`.spec/agents/reviewer.agent.md`](../agents/reviewer.agent.md) | 需要隔离上下文做完整交付审查时查；普通小改动可不派审。 |

## lessons（反复错误升级池）

| 文档 | 何时查 |
|------|--------|
| [`lessons.md`](lessons.md) | 同类错误第二次出现、用户纠偏、review 反复退回时查；第三次左右升级为正式规范或 skill。 |
