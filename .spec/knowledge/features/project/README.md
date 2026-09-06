---
name: project
description: FantasyWord 项目事实入口：进入项目专项知识目录时先读，负责路由到文档索引和三层框架正文。
metadata:
  type: index
  status: 已交付
---

# Project Facts（项目事实入口）

本文件是 `.spec/knowledge/features/project/` 的目录入口，只负责路由，不重复承载正文规则。具体任务仍回到 [`文档索引.md`](文档索引.md)、[`../../README.md`](../../README.md) 和对应专项文档。

## 先读顺序

| 目的 | 继续读取 |
| --- | --- |
| 不确定某类任务该读哪篇 | [`文档索引.md`](文档索引.md) |
| 判断 `YokiFrame / GameCore / Gameplay` 分层、依赖方向和迁移落点 | [`../../standards/framework-layering.md`](../../standards/framework-layering.md) |
| 判断 FantasyWord 具体业务对象、领域 owner、目录组织、Mod 与未来联机边界 | [`../../standards/gameplay-architecture.md`](../../standards/gameplay-architecture.md) |
| 查看 Unity 工程目录、代码落点、Prefab、Scene 和 Asset 当前事实 | [`项目目录与入口.md`](项目目录与入口.md) |
| 查看参考源、第三方插件、旧工程和复用来源边界 | [`参考源映射.md`](参考源映射.md) |

## 当前事实

- FantasyWord 的三层依赖方向是 `Gameplay -> GameCore -> YokiFrame`。
- `YokiFrame` 是底座；`GameCore` 是通用游戏框架；`Gameplay` 是 FantasyWord 具体业务层。
- CardLoop 只作为通用分层和代码框架边界的对照来源；可同步结论已收口进正式 standards，它的卡牌生存业务不进入 FantasyWord。
- `features/project` 根目录只保留长期项目事实入口、职责边界和参考矩阵；阶段取证、源码摘录、迁移台账和模板工具不作为正式入口保留。
- 本文件只是目录门牌，不替代 [`文档索引.md`](文档索引.md) 的完整路由职责。
