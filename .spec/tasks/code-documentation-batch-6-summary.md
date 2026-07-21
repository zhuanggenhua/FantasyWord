---
name: code-documentation-batch-6-summary
description: 代码注释与中文化改进第六批总结：角色成长、Sheet 入口与正式 ASC 运行时
metadata:
  type: task-summary
  batch: 6
  last_updated: 2026-07-20
---

# 代码注释与中文化改进第六批总结

## 本批范围

本批继续处理核心角色运行时，重点是 `CharacterActor` 的成长/存档边界，以及 `CharacterBase` 正式 ASC 属性真相的 partial 文件。

### 已处理文件

1. `Assets/Scripts/GameCore/Runtime/Entities/Characters/CharacterBase.GASRuntime.cs`
2. `Assets/Scripts/GameCore/Runtime/Entities/Characters/CharacterActor.cs`
3. `Assets/Scripts/GameCore/Runtime/Entities/Characters/CharacterActor.Sheet.cs`

## 改进内容

### 1. 正式 ASC 运行时

**文件**：`CharacterBase.GASRuntime.cs`

**改进点**：

- 移除单字段英文 `Header("GAS")`，改为字段自己的 Odin `LabelText` 和中文 `Tooltip`。
- 补充正式 ASC 初始化、属性读取、当前值写入和事件订阅的中文说明。
- 说明启动期 bootstrap buffer 的边界：只允许初始化窗口短暂回退，运行时不允许长期双轨。
- 补充属性快照写入、当前值变更事件、ASC 委托注销和清除持续效果的失败后果说明。
- 说明 Cleanse 使用 runtime key 快照，避免遍历时集合变化。

### 2. 角色成长与运行时快照

**文件**：`CharacterActor.cs`

**改进点**：

- 将旧 `InspectorName` 更新为 Odin `LabelText`，并移除两个单字段 `Header`。
- 为 `EEquipmentOperationResult` 每个枚举值补充中文语义。
- 为 `CharacterActorDataBlock`、`CharacterActorRuntimeStateData`、装备槽和快捷技能槽存档字段补充中文说明。
- 扩展 `CharacterActor` 类级文档，明确它是成长、装备槽恢复和快捷能力槽恢复的玩法 owner。
- 补充经验、自由属性点、等级、正式动画驱动、死亡/复活、存档和运行时快照恢复的边界注释。
- 明确正式动画驱动失败时应报错，不静默回退掩盖 Prefab 接线问题。

### 3. 角色 Sheet 入口

**文件**：`CharacterActor.Sheet.cs`

**改进点**：

- 移除英文 `Header("Character Settings")`。
- 为 `m_sheet` 补充 Odin `LabelText("角色配置表")` 和中文 `Tooltip`。
- 保留 `[FormerlySerializedAs("m_characterSheet")]`，避免旧 Prefab 或存档引用丢失。
- 为正式配置表入口和旧调用兼容入口补充说明。

## 设计边界

- 本批只改注释和 Inspector 中文显示，不改运行时逻辑。
- 单字段分组统一去掉，按新规范让字段自己的 `LabelText` / `Tooltip` 承担语义。
- `CharacterActor` 不直接持有背包物品真相，只保存成长账、装备槽快照和快捷技能槽快照。
- `CharacterBase.GASRuntime` 继续把正式 ASC 作为属性真相，不恢复旧 Stats 双轨模式。

## 验证

- ✅ `git diff --check` 通过。
- ✅ 三个目标文件均无 UTF-8 BOM。
- ✅ 三个目标文件均保留末尾换行。
- ✅ 三个目标文件未发现旧 `InspectorName(...)`、`Header(...)` 或英文工具菜单回流。
- ⚠️ `.spec/tools/spec-lint.mjs` 仍因既有 frontmatter 识别问题失败，失败列表覆盖大量既有 `.spec` 文件，不是本批新增文档单独造成。
- ⚠️ 未启动 Unity Editor 编译；本批改动以注释、XML 文档和 Inspector 文案为主。

## 下一步建议

下一批建议继续处理 `CharacterBase.Abilities.cs`、`CharacterBase.Resources.cs`、`CharacterBase.StateApi.cs` 等剩余 partial，或者转到 `AIController.cs` 的 AI 追踪、转向和攻击门禁注释。
