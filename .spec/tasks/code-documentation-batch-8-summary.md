---
name: code-documentation-batch-8-summary
description: 代码注释与中文化改进第八批总结：存档、动作状态与持续效果注册表
metadata:
  type: task-summary
  batch: 8
  last_updated: 2026-07-20
---

# 代码注释与中文化改进第八批总结

## 本批范围

本批继续处理 `CharacterBase` 核心 partial，重点是存档/运行时快照恢复顺序、动作状态容器，以及持续效果 runtimeKey 注册表。

### 已处理文件

1. `Assets/Scripts/GameCore/Runtime/Entities/Characters/CharacterBase.Persistence.cs`
2. `Assets/Scripts/GameCore/Runtime/Entities/Characters/CharacterBase.ActionStateRuntime.cs`
3. `Assets/Scripts/GameCore/Runtime/Entities/Characters/CharacterBase.TemporalEffectRuntime.cs`

## 改进内容

### 1. 存档与运行时快照恢复

**文件**：`CharacterBase.Persistence.cs`

**改进点**：

- 补充基础存档块、正式存档和轻量运行时快照的职责说明。
- 明确读档恢复顺序：先清旧来源，再恢复能力来源和压制，再恢复等级/能力运行时，最后恢复持续效果与当前属性。
- 说明来源化能力和压制只保存正式能力编号、来源类型、来源 ID 和叠层数，不保存运行时实例。
- 补充持续效果读写盘、重建、注册和 runtimeKey 稳定排序的边界说明。
- 说明旧 effect 在读档前必须先完成退场，避免对象复用时旧副作用残留。

### 2. 动作状态运行时容器

**文件**：`CharacterBase.ActionStateRuntime.cs`

**改进点**：

- 为动作启用位、普通动作锁、来源化动作锁、普通移速倍率、持续效果动作锁和持续效果移速倍率补充字段说明。
- 补充普通 key、来源键和 effect runtimeKey 三类句柄的生命周期和失败语义。
- 说明普通动作锁和普通移速倍率 key 不存在时抛错，用于暴露重复释放或生命周期管理错误。
- 说明来源化动作锁按来源叠层，叠层归零后才删除条目。
- 说明持续效果 runtimeKey 必须为正数，因为它承担读档恢复、状态回滚和运行时注册表匹配职责。

### 3. 持续效果 runtimeKey 注册表

**文件**：`CharacterBase.TemporalEffectRuntime.cs`

**改进点**：

- 补充持续效果注册表的 runtimeKey 主键语义。
- 说明同 key 新实例会替换旧实例，并把旧实例交给调用方统一完成退场。
- 补充按 runtimeKey 查询、当前实例判断和 key 快照遍历的边界说明。
- 说明移除接口会对输入 key 去重，并只返回实际移除的 effect 实例。

## 设计边界

- 本批只新增注释，不改运行时逻辑。
- 存档仍由 `CharacterBase` 编排，运行时实例不直接写盘。
- 动作状态容器仍是 `CharacterBase` 内部实现，不升格为第二套动作系统。
- 持续效果注册表只负责 runtimeKey 到 effect 实例的增删查，完成、展示移除和副作用回滚仍由角色拥有者收口。

## 验证

- ✅ `git diff --check` 通过。
- ✅ 三个目标文件均无 UTF-8 BOM。
- ✅ 三个目标文件均保留末尾换行。
- ✅ 三个目标文件未发现旧 `InspectorName(...)`、英文 `Header` 或英文工具菜单回流。
- ⚠️ UnitySkills 编译反馈工具本轮没有直接暴露，未跑 Unity Editor 编译。
- ⚠️ `.spec/tools/spec-lint.mjs` 已知仍因既有 frontmatter 识别问题失败，不是本批新增文档单独造成。

## 下一步建议

下一批建议继续处理 `CharacterBase.Alterations.cs`、`CharacterBase.AbilitySetRuntime.cs`、`CharacterBase.AttributeBootstrapBuffer.cs`、`CharacterBase.Contracts.cs`，或切到 `AIController.cs`。
