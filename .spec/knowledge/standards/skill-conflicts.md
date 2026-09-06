---
name: skill-conflicts
description: 外部 workflow、上游 skill 与项目 `.spec/skills` 的整合矩阵：说明合并、改写和旧入口收口结果。
metadata:
  type: doc
  status: 已交付
---

# Skill 整合与冲突矩阵

本文件记录外部 workflow 和上游 skill 被吸收到 FantasyWord 后，各入口与现有规范的关系。原则：**只吸收有效增量，执行红线以现有系统/项目规则为准**。

## 已合并为项目 `.spec` skill

| LumioAgent skill | 本项目落点 | 处理结果 |
|------------------|------------|----------|
| `spec-steward` | `.spec/skills/spec-steward` | 合并。吸收“放对位置、同步索引、反复错误升级”，并改成本项目五层落点规则。 |
| `before-you-code` | `.spec/skills/before-you-code` | 合并。改为四项前提锁定 + FantasyWord 渐进披露入口。 |
| `systematic-debugging` | `.spec/skills/systematic-debugging` | 合并。叠加“原始 bug 描述不得改写”和“止血不等于修复”。 |
| `verification-before-completion` | `.spec/skills/verification-before-completion` | 合并。保留“证据先于声明”，适配 Unity/文档/资源验收。 |
| `task-breakdown` | `.spec/skills/task-breakdown` | 合并。保留任务拆解，移除自动 worktree 假设。 |
| `writing-plans` | `.spec/skills/writing-plans` | 改写为路由。长期计划仍以 `D:\codex-home\skills\planning-with-files\SKILL.md` 为准。 |
| `test-driven-development` | `.spec/skills/test-driven-development` | 改写。保留 TDD 方法，但不采用全局一刀切强制。 |
| `receiving-code-review` | `.spec/skills/receiving-code-review` | 合并。保留“先核实再改，不表演式认同”。 |
| `brainstorming` | `.spec/skills/brainstorming` | 合并。用于设计/需求未收敛场景，默认先方案后实施。 |
| `subagent-driven-development` | `.spec/skills/subagent-driven-development` | 安全改写。保留任务交接和审查思想；子 agent 模型配置与派发约束由该 skill 统一承载。 |
| `using-git-worktrees` | `.spec/skills/using-git-worktrees` | 安全改写。默认禁止自动创建/切换/删除 worktree，除非用户当轮明确许可。 |

## 已迁入 `.spec/skills` 的项目专项 skill

| 项目专项 skill | 当前落点 | 处理结果 |
|------------|----------|----------|
| `gas-ability-authoring` | `.spec/skills/gas-ability-authoring` | 已迁入。保留 FantasyWord EX-GAS 制作、排查、普攻、背刺和命中范围预览流程。 |
| `unity-tilemap-2d` | `.spec/skills/unity-tilemap-2d` | 已迁入。保留 FantasyWord 2D Tilemap、Grid、Palette、RuleTile 和碰撞链路流程。 |
| `unity-timeline-signal-debug` | `.spec/skills/unity-timeline-signal-debug` | 已迁入。保留 Timeline Signal 到 SignalReceiver 再到业务入口的排查流程。 |
| `unity-ui-development` | `.spec/skills/unity-ui-development` | 已迁入。保留 UGUI、UI Toolkit、TMP、Prefab/场景 UI 与编辑器 UI 的项目裁决入口。 |
| `aibridge` | `Packages/com.aibridge.unity`、`Temp/UnityBridge`、`.spec/skills/unity-skills` | 不作为项目 skill 保留；Unity 编辑器自动化走真实 Unity 包和文件队列通道。 |
| `safe-image-reading` | 无 active 落点 | 已停用且不迁入；项目不保留旧读图前压缩/预算门禁正文或备份目录。 |
| `D:\codex-home\skills\code-comments` | 系统 skill | 保留为跨项目中文注释能力；不是 FantasyWord 项目 skill 副本。 |
| `D:\codex-home\skills\unity-production` | 系统 skill | 保留为跨项目 Unity 工程能力；FantasyWord 项目规则只在 `.spec` 写适配边界。 |
| `D:\codex-home\skills\self-evolving-skills` | 系统 skill | 保留为系统 skill 生命周期能力；`.spec/skills/spec-steward` 只管本仓 `.spec`。 |

## CardLoop 对照裁决

| CardLoop 通用做法 | FantasyWord 处理 |
|------------------|------------------|
| `.spec/skills/unity-skills` 只做项目薄入口，上游资料留在包内 | 已同步为 `.spec/skills/unity-skills`；并由 `spec-lint` 约束不复制上游模块资料。 |
| `.spec/skills/unity-cli` 只裁决 Unity 官方 CLI 能力，不抢 UnitySkills | 已同步为 `.spec/skills/unity-cli`；按 FantasyWord 现状改写为查询 / 打开 / 明确授权无头候选入口。 |
| `.spec/skills/unity-package-management` 单独裁决 UPM 包操作 | 已同步为 `.spec/skills/unity-package-management`；包操作先走 UnitySkills 包模块或 UPM 正式入口，不手写 manifest 作为默认方案。 |
| `.spec/tools/unityskills-ensure.mjs` 检查 UnitySkills 服务且不另起第二个 Editor | 已同步为 FantasyWord 独立脚本；不依赖 CardLoop 的 `unity-verify.mjs`，当前只检查/等待/按显式配置冷启动。 |
| `unity-ui-development` 只做项目薄入口，上游 UI 教程不复制成项目正文 | 已迁入 `.spec/skills/unity-ui-development`；旧宿主目录删除，不保留第二入口。 |
| `gas-ability-authoring` 先读 EX-GAS 插件正式资料和 GameCore 集成边界 | 已迁入 `.spec/skills/gas-ability-authoring`；保留 FantasyWord 普攻、背刺、命中范围预览等项目专项流程。 |
| `.spec/knowledge/features/ai-quick` 用“官方入口 + 项目正式入口”做快速路由 | 不整目录照搬。FantasyWord 已由 `.spec/knowledge/README.md`、`第三方插件接入清单.md`、`框架与运行时入口.md` 和各项目事实文档承载同一查询模式；只有出现反复误路由时，再按 FantasyWord 事实拆项目速查卡。 |
| 独立 GAS 集成程序集承载手写生成配置集成 | 不采用。FantasyWord 生成运行时程序集当前已经正式引用 `FantasyWord.GameCore`，能力身份、运行配置、描述、时间轴和伤害扩展统一收口在 `GAS.Runtime.FormalGasAbilityDescriptionGeneratedRuntime`；不得再新增第二程序集或中转入口。 |
| `.spec/skills` 作为项目 skill 唯一来源 | 已同步。旧宿主 skill 已逐项迁入或停用删除，项目不再保留第二入口。 |
| `.spec/tools/gameplay-static-preflight.mjs` 作为 CardLoop 业务/旧来源残留静态预检 | 暂不照搬。FantasyWord 已有专项 `scripts/Invoke-*.ps1` 和 `.spec/tools/spec-lint.mjs`；若以后需要 Gameplay 业务预检，必须按 FantasyWord 业务对象重新设计。 |
| `.spec/tools/unity-verify.mjs` / `.spec/tools/unity-confirm-scene-reload.mjs` 作为 CardLoop 编辑器流程保护 | 暂不照搬。FantasyWord 已有 AIBridge 专项脚本和 UnitySkills 薄入口；这类会影响 Editor 状态的工具要等出现明确需求再按本项目入口设计。 |
| `.spec/skills/codebase-summary` 架构摘要或 HTML 产物 workflow | 暂不照搬。本轮目标是框架分层和通用执行入口；FantasyWord 当前已有分层 standards 和系统架构审查 skill，若以后要仓库架构产物再单独建项目 skill。 |
| 业务层统一用 `Gameplay`，不再新增 `GamePlay` 或项目名业务命名 | 已由 `code-style.md` 和 `framework-layering.md` 约束；现有历史路径迁移要逐项保留 `.meta` / GUID 后再动。 |

## 已按当前指令收口的原待决策项

| 原冲突点 | 当前处理 |
|----------|----------|
| `.spec/skills/spec-steward` 与 `self-evolving-skills` | 不再等待决策：`.spec/skills/spec-steward` 管本项目 `.spec`；`self-evolving-skills` 继续管系统/自有 skill 生命周期。 |
| LumioAgent 强 TDD 与项目务实测试策略 | 不再等待决策：项目采用务实 TDD；需要强制测试先行的模块以后直接写入对应模块规范。 |
| LumioAgent worktree 并行流程与项目禁止擅自 worktree | 不再等待决策：默认禁止自动 worktree，只有用户当轮明确授权才可走 `using-git-worktrees`。 |
| 项目知识库入口 | 不再等待决策：`.spec/knowledge/features/project/` 是 FantasyWord 项目知识库唯一正式入口。 |
| 根目录 `skills-lock.json` 旧外部 skill 安装锁 | 已删除且不迁入。项目 skill 来源由 `.spec/skills/` 承载，外部来源裁决由本文和 `.spec/knowledge/README.md` 路由；`spec-lint` 与 workspace preflight 阻止该锁文件回流。 |
| 根目录 `_ai_preview_*.jpg` 与 `scripts/Watch-CodexAbort.ps1` | 已删除且不迁入。前者只是本地 AI 预览图，后者只是 Codex 会话诊断脚本，都不承载 FantasyWord 项目规则、知识或正式工具链；`spec-lint` 与 workspace preflight 阻止回流。 |
