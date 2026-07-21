---
name: code-documentation-batch-10-summary
description: 代码注释与中文化改进第十批总结：变身规则资产、角色合同与 AI 行为运行时
metadata:
  type: task-summary
  batch: 10
  last_updated: 2026-07-20
---

# 代码注释与中文化改进第十批总结

## 本批范围

本批继续收口角色系统剩余高优先级文件，重点处理变身/感染规则资产的 Inspector 中文化、角色运行时合同数据，以及 AI 行为运行时的寻敌、视线、攻击对准和 steering 路径说明。

### 已处理文件

1. `Assets/Scripts/GameCore/Runtime/Database/Characters/CharacterAlterationRule.cs`
2. `Assets/Scripts/GameCore/Runtime/Entities/Characters/CharacterBase.Contracts.cs`
3. `Assets/Scripts/GameCore/Runtime/Controllers/AIController.BehaviourRuntime.cs`

## 改进内容

### 1. 变身/感染规则资产

**文件**：`CharacterAlterationRule.cs`

**改进点**：

- 将旧 `InspectorName` 更新为 Odin `LabelText`，并补齐 `using Sirenix.OdinInspector`。
- 移除只有 2 个字段的 `Header("UI 设置")` 和 `Header("能力变化")`，保留 3+ 字段的中文分组。
- 按规范调整 `SerializeField` 与 `LabelText/Tooltip` 的顺序。
- 补充规则资产职责说明：规则不持有角色运行时状态，只通过来源键写入 `CharacterBase` 容器。
- 补充能力编号校验、来源键创建、能力授予/压制、非能力效果写入/撤回和叠层撤回的合同说明。
- 说明数据库注册键是来源 ID 的真相源，未登记规则不能安全生成来源键。

### 2. 角色运行时合同数据

**文件**：`CharacterBase.Contracts.cs`

**改进点**：

- 补充 `CharacterAbilitySourceKey` 的来源归一化、来源大类和稳定 ID 说明。
- 补充能力来源运行时条目和存档条目的字段语义，说明 ability code、source、stackCount 的边界。
- 补充能力释放结果、技能槽展示快照和能力菜单条目的 UI 兼容命名语义。
- 为角色存档块和局部运行时快照补充字段说明，覆盖等级、控制器数据、属性、变身规则、能力来源和持续效果状态。
- 补充正式能力运行时状态、持续效果恢复快照、冷却展示快照和持续效果展示快照的字段合同。
- 说明持续效果恢复失败语义：类型缺失、实例化失败或未实现运行时状态接口时返回 false，不生成半残效果。

### 3. AI 行为运行时

**文件**：`AIController.BehaviourRuntime.cs`

**改进点**：

- 为行为运行时字段补充说明，包括 steering 适配器、路径游标、战斗游走、追踪位置、重算路径计时器和攻击对准门禁。
- 补充初始化、停止、释放、挑衅处理和固定步 Tick 的顺序约束。
- 补充视线检测、目标搜索、冷却推进、目标刷新、攻击尝试和攻击前对准的合同说明。
- 补充追击停止、目标位置更新、战斗游走优先级、近身最终行为组和远距离地形导航的边界。
- 补充朝向解析、身体朝向应用、路径目标解析、路径重算节流、容差解析和 steering 行为组校验说明。

## 设计边界

- 本批不改运行时逻辑、寻敌优先级、攻击触发条件或转向/寻路算法。
- `CharacterAlterationRule` 只做 Inspector 中文化和合同注释，不改序列化字段名，不迁移资产数据。
- `CharacterBase.Contracts` 只补合同说明，不改变任何数据块字段结构。
- `AIController.BehaviourRuntime` 只解释现有 FixedUpdate 行为节奏，不引入仇恨表、全局目标系统或第二套视线层规则。

## 验证

- ✅ `git diff --check` 通过。
- ✅ 本批目标文件均无 UTF-8 BOM，并保留末尾换行。
- ✅ 本批目标文件未发现旧 `InspectorName(...)`、英文 `Header` 或英文工具菜单回流。
- ⚠️ UnitySkills 编译反馈工具本轮没有直接暴露，未跑 Unity Editor 编译。
- ⚠️ `.spec/tools/spec-lint.mjs` 已知仍因既有 frontmatter 识别问题失败，不是本批新增文档单独造成。

## 下一步建议

下一批建议切入战斗系统：优先处理伤害/效果/命中范围相关文件，例如 `CombatSolver`、持续效果 `Temporal*Effect`、`Gas2DTargetCatchers` 或伤害数据结构。
