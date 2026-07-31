# 0072-.spec 结构完整收口裁决

- 日期：2026-07-25
- 状态：已采纳
- 背景：
  - 本轮以 `https://github.com/Go1c/LumioAgent` 作为外部参考，重新核对 FantasyWord 的 `.spec` 结构是否完整。
  - 现状已经有 `.spec` 主入口、硬红线、知识导航、skill、agent、decision、task 和 lint，但还缺少派活模板、feature 文档模板，以及“外部参考取舍”在正式决策层的收口。
  - 将一次性合并审计留在 `knowledge/standards/` 会让长期规范混入历史来源说明，造成“半重构”的执行口径。
- 决策：
  - FantasyWord 正式采用 `.spec` 分层、知识导航、反复错误升级、skill 工作流、reviewer 角色和结构校验。
  - 新增 `.spec/knowledge/standards/dispatch.md` 作为派活、子 agent 交接、reviewer 审查和串并行边界的项目模板。
  - 新增 `.spec/knowledge/features/_TEMPLATE.md` 作为后续功能设计现状文档模板。
  - 外部参考取舍只作为本决策记录和各项目 skill 的内部来源，不再作为日常入口或 standards 文档存在。
  - 不采用外部参考里的默认 worktree 并行、默认提交/PR、全局强 TDD、第二套 `docs/plans/` 计划体系；这些继续服从 FantasyWord 当前红线。
  - `.spec/tools/spec-lint.mjs` 必须把 dispatch 与 feature 模板纳入必需文件，避免结构再次漂移。
- 影响：
  - 日常入口只看 `.spec/AGENTS.md`、`.spec/rules/system.md`、`.spec/knowledge/README.md` 和对应项目 skill。
  - 需要追溯本轮结构取舍时查本决策，不再查 standards 下的一次性冲突矩阵。
  - 文档任务、规范任务、派活任务和功能设计文档都有明确模板与验证路径。
- 替代关系：
  - 本决策取代 `.spec/knowledge/standards/skill-conflicts.md` 的日常用途；历史合并结论已收口到本决策和各项目 skill 正文。

