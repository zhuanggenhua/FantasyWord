---
name: before-you-code
description: 动手前的前提锁定与上下文加载协议；写代码、改配置、改资源、改规范或执行会改变结果的命令前使用。
---

# Before You Code（动手前协议）

## 四项前提

动手前必须锁定：

1. 问题对象：具体文件、场景、资源、记录、规范或 skill。
2. 真相来源：用户指定、本仓文件、Unity 状态、测试输出、日志、外部参考。
3. 目标入口/环境：当前项目、Unity Editor、`.spec`、`.spec/knowledge/features/project`、`openspec`、全局 `D:\codex-home`。
4. 验收口径：完成后用什么回到原始目标验证。

任一缺失，不得实施，只能继续查证或问最小问题。

## 读取顺序

1. 根 `AGENTS.md` 指针。
2. `.spec/AGENTS.md`。
3. `.spec/rules/system.md`。
4. `.spec/knowledge/README.md`。
5. 按任务类型读取 `.spec/knowledge/features/project/` 或对应 skill。

## 规模判断

- 小任务：1 个文件或单一文档块，读直接相关规范后可直接改。
- 中任务：2-5 个文件或跨模块，先列改动清单，再逐项实施。
- 大任务：多模块、多阶段、有设计分歧，先用 `task-breakdown` 或 planning-with-files。

## 禁止

- 不把最近打开的 Unity 场景、最近日志或相似文件当成目标。
- 不为推进进度自行假设目标。
- 不顺手重构、不夹带新功能、不改任务外文件。

