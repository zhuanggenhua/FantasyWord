---
name: workflow
description: 开发与规范治理流程：说明任务前提、执行边界、提交限制、知识沉淀和 LumioAgent 结构吸收方式。
metadata:
  type: doc
  status: 已交付
---

# 开发与规范治理流程

## 工作前提

动手前必须锁定：

- 问题对象：本轮到底处理哪个文件、系统、场景、记录或规范。
- 真相来源：来自本仓文件、Unity Editor 状态、测试输出、日志、用户明确指定，还是外部参考。
- 目标入口/环境：在当前项目根、Unity Editor、`.spec/knowledge/features/project/`、`openspec/`、`.spec/` 还是全局 `D:\codex-home`。
- 验收口径：完成后回到哪里验证，使用什么证据证明。

## 执行边界

- 根 `AGENTS.md` 是入口，只放指针，不再堆项目细节。
- `.spec` 是规范结构主入口。
- `.spec/knowledge/features/project/` 是当前项目知识库正式入口；废弃目录不得作为规范入口继续引用。
- `openspec` 承载 proposal/change/spec，不混进 `.spec/decisions`。
- `.codex/skills` 和 `.agents/skills` 的现有项目 skill 继续可用；重复 skill 已在 `skill-conflicts.md` 收口。

## LumioAgent 吸收边界

采用：

- `.spec` 结构分层。
- `spec-steward` 维护规范落点。
- `lessons.md` 作为反复错误升级池。
- “完成声明必须有验证证据”的收口门禁。
- “主 Agent 调度、skill 是方法、`.md` 是规则”的结构思想。

不采用：

- 默认创建或使用 git worktree 的流程。
- 未经用户确认的分支、提交、发布、PR 流程。
- 所有生产代码都必须严格 TDD 的一刀切规则。
- “设计文档必须提交”的默认动作。

## Git 与提交

- 不使用回滚/撤销历史操作。
- 不擅自创建、切换、重建或删除分支、tag、worktree。
- 不主动提交、不推送，除非用户当轮明确允许。
- 工作区已有无关改动时，只触碰本轮目标文件。

## 知识沉淀

- 新长期规则：先判断落点，再写入 `.spec/rules/`、`.spec/knowledge/standards/`、`.spec/skills/`、`.spec/knowledge/features/project/`、`openspec/` 或全局 `D:\codex-home`。
- 反复错误：第二次写入 `.spec/knowledge/lessons.md`，第三次左右升级。
- 项目事实或 Unity 入口：优先更新 `.spec/knowledge/features/project/` 对应分册，再由 `.spec/knowledge/README.md` 导航。
- 可复用 workflow：写入 `.spec/skills/` 或既有项目 `.codex/.agents/skills`，不要把详细 SOP 塞进根 AGENTS。
- 废弃入口：不得重建、引用或新增旧项目知识库目录作为规范目录；发现该目录存在时必须删除或说明具体外部占用。

## 结构校验

`.spec` 结构、索引、skill 或 agent 变化后，运行：

```powershell
node .spec/tools/spec-lint.mjs
```

该脚本只检查规范结构，不启动 Unity、不修改资产。
