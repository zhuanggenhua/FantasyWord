# FantasyWord AI 规范中心

本目录是 FantasyWord 项目的 AI 规范主入口。根目录 `AGENTS.md` 只负责进入 `.spec/`；实际规则、知识、skill 和任务组织都收口到 `.spec/`。

## 项目定位

- Unity 工程根目录：`C:\Gamedev\Unity\Project\FantasyWord`。
- 当前 Unity 版本：`6000.3.10f1`；渲染管线：URP 2D；输入方案：Unity Input System。
- 当前游戏定位：单机优先、有限人数主机权威合作为未来方向的俯视角开放世界像素游戏。
- 当前阶段：不接入网络框架，不创建网络空壳；先做稳单机核心、内容数据化、稳定 ID、可审计与可迁移。
- 当前美术基线：MiniFantasy。

## 每轮必读核心

1. `AGENTS.md`：根目录入口，只负责指向这里。
2. `.spec/AGENTS.md`：本文件，说明调度结构和项目边界。
3. `.spec/knowledge/README.md`：知识导航，决定任务应该继续读哪些规范。
4. `.spec/rules/system.md`：硬红线，任何任务都不得绕过。

## 结构分工

| 位置 | 职责 |
|------|------|
| `.spec/rules/` | 强制红线，只写必须做、不得做、只能做什么。 |
| `.spec/knowledge/standards/` | 长期规范和做法，回答“这类事该怎么做”。 |
| `.spec/knowledge/features/` | 功能现状、系统设计和项目事实，回答“这个功能现在怎么设计”。 |
| `.spec/knowledge/features/project/` | 已吸收的 FantasyWord 长期项目知识库，是当前唯一正式项目知识入口。 |
| `.spec/knowledge/lessons.md` | 反复踩坑的候选经验池，第二次出现收录，稳定复用后升级为正式规范。 |
| `.spec/decisions/` | 架构、流程、规范层决策记录，只新增不改写历史。 |
| `.spec/skills/` | 项目内可复用工作流，从 LumioAgent 吸收后已按本项目红线改写。 |
| `.spec/agents/` | 需要隔离上下文才有价值的职能 agent；当前只登记 reviewer 角色说明。 |
| `.spec/tasks/` | 进行中任务卡；完成后删除，历史交给 git。 |
| `openspec/` | 功能 proposal/change/spec，不和 `.spec/decisions/` 混用。 |

## 调度核心

- 小而清楚的任务：直接按 `.spec/skills/before-you-code` 加载上下文后实施。
- 创造性或设计性任务：先做设计共识，再写计划，再实施；如果用户明确要求“先不执行”，只能停在方案或计划。
- 大设计或方向不清的任务：先用 `.spec/skills/brainstorming` 收敛方案，不直接进入实现。
- Bug、测试失败、异常行为：先用 `.spec/skills/systematic-debugging` 找根因；没有锁定原始症状和真相源前不得修。
- 装备换装、帧编辑器、Body/Head UV、Idle/Walk/Attack 换装错位或截图验收：先用 `.spec/skills/equipment-system-workflow` 锁定对象、配置流程和端到端证据。
- 多步骤或多模块任务：用 `.spec/skills/task-breakdown` 拆任务；同一文件集重叠的任务必须串行。
- 需要子 agent 执行时：用 `.spec/skills/subagent-driven-development`，并显式要求 `gpt-5.4` + `high`。
- 收口前：用 `.spec/skills/verification-before-completion`，必须有新鲜验证证据，不能只说“应该好了”。
- 新增或更新规范、skill、知识文档：用 `.spec/skills/spec-steward` 判断落点并同步索引。

## 子 Agent 约束

- 使用子 agent 做代码分析、设计、重构、实现、修复、测试等与改代码直接相关的任务时，必须显式使用 `gpt-5.4` + `high`。
- 子 agent 只能执行被派发的任务，不得继续派生子 agent。
- reviewer 类审查只在需要隔离审查价值时使用；普通小改动不用为了形式派审。
- 未经用户当轮明确许可，不创建、切换、重建或删除分支、tag、worktree。
- worktree 相关需求只能先用 `.spec/skills/using-git-worktrees` 做确认和安全检查；不得自动创建。

## 项目验收口径

- 文档或规范任务：至少验证 `.spec` 链接、索引、frontmatter、skill 路由和根入口一致。
- `.spec` 结构改动后运行：`node .spec/tools/spec-lint.mjs`。
- 代码任务：按任务涉及范围选择静态检查、Unity Editor 自动化、PlayMode、测试或截图验收。
- Bug 修复：必须回到用户原始症状验收；如果只做了止血、降噪、跳过或兜底，必须明确说只是缓解，不是根因修复。
- Unity 场景或资产任务：不得把最近打开的场景、最近日志或自动化最后操作对象脑补为目标；必须锁定对象、真相来源、目标入口/环境、验收口径。

## LumioAgent 吸收结果

- 采用它的 `.spec` 结构、知识导航、经验升级、skill 工作流和结构校验思想。
- `.spec/knowledge/features/project/` 的 62 个文档是当前项目知识入口。
- 重复 skill 的处理结果记录在 `.spec/knowledge/standards/skill-conflicts.md`，当前已按“直接吸收，不再等待决策”处理。
- 不采用默认 worktree/分支策略；本项目继续遵守“未获许可不创建或切换分支、tag、worktree”。
- 不采用强制全量 TDD 作为全局铁律；本项目保留“高风险逻辑、bug 修复、关键合同优先补测试，小改动不机械补同粒度测试”的务实策略。
