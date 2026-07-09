# Tasks: plan-core-framework-roadmap

## 1. User Story Capture

- [x] 更新复合沙盒 RPG 用户故事，记录玩家主控+队友、可暂停即时战斗、战术模式、视野侦查、涌现式交互、元素反应、GOAP/Utility AI、生活系统、任务和对话目标。
- [x] 在用户故事中登记参考来源和非复制边界。

## 2. Roadmap Definition

- [x] 定义核心基本框架阶段路线。
- [x] 明确第一阶段是基础角色自然实现案例，技能编辑是其中的内容生产面。
- [x] 补充 2D 地形高低差为横跨移动、视野、交互、AI 和任务路径的框架轨道。
- [x] 把高风险实验项从核心必做闭包中分离出来。
- [x] 明确没有行为树或正式等价 AI 框架时，不做敌人 AI 最小占位实现。

## 3. Next Step Setup

- [x] 用户确认阶段路线后，新开 `define-skill-authoring-workbench`，并在正式规范中收口为 `ability-authoring-foundation`。
- [x] 在新 change 中定义正式玩家角色、技能编辑器、角色构筑、规则资产生产流和最小 smoke。

## 4. Verification

- [x] `npx openspec validate plan-core-framework-roadmap --strict` 通过。
