# FantasyWord AI 规范入口

> 本文件是入口，只负责把 AI 引导到 `.spec` 规范中心；不要再把长期规则、详细 SOP 或项目知识直接追加到这里。

## 必读顺序

1. `.spec/AGENTS.md`：项目 AI 规范中心。
2. `.spec/rules/system.md`：硬红线。
3. `.spec/knowledge/README.md`：知识导航。
4. 按任务类型继续读取 `.spec/knowledge/features/project/`、`openspec/` 或对应 skill。

## 当前项目事实

- Unity 工程根目录：`C:\Gamedev\Unity\Project\FantasyWord`。
- Unity 版本：`6000.3.10f1`。
- 渲染管线：URP 2D。
- 输入方案：Unity Input System。
- 当前定位：单机优先、未来有限人数主机权威合作的俯视角开放世界像素游戏。
- 当前阶段：不接入网络框架，不创建网络空壳。

## 正式入口

- 项目知识库唯一正式入口是 `.spec/knowledge/README.md` 与 `.spec/knowledge/features/project/`。
- 现有 `.codex/skills`、`.agents/skills` 只作为任务型 skill 使用，不承载项目长期知识入口。
- 需要新增或更新规范、skill、长期规则时，先用 `.spec/skills/spec-steward/SKILL.md` 判断落点。
