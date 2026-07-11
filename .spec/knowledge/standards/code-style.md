---
name: code-style
description: 代码与文档风格：说明中文优先、命名、注释、生成物和项目 skill/frontmatter 约定。
metadata:
  type: doc
  status: 已交付
---

# 代码与文档风格

## 语言

- 项目规范、文档、总结默认使用中文。
- Git 提交信息默认使用中文；Conventional Commits 的 type/scope 可保留英文，冒号后的摘要和正文用中文。
- 内部字段、日志标签、代码符号可以保留原名，但给用户解释前必须先说明现实含义。

## 注释

- 注释只写代码表达不了的约束、原因、边界和外部依赖。
- 不写“改了什么”的流水账注释；改动说明放在交付汇报或提交信息。
- Unity Inspector 字段说明和项目侧注释默认中文。
- 需要新增或审查注释时，使用 `.agents/skills/code-comments/SKILL.md`。

## 命名

- `.spec` 目录和 skill 目录使用 kebab-case。
- 项目侧正式玩法资产优先中文命名。
- 第三方原始目录、代码符号和兼容稳定 ID 保留原名，不为美观强行改。

## 生成物

- 生成物不得手改；必须改生成源并重新生成。
- `.meta`、GUID、Unity 资源引用必须作为闭包处理，不得只移动或改主文件。

## Skill frontmatter

- 项目 `.spec/skills/<name>/SKILL.md` 只要求 `name` 和 `description`。
- description 必须写清触发场景，不把完整 SOP 堆在描述里。
- 详细做法放正文，相关细节放 references 或项目 docs。

