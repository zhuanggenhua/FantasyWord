---
name: code-documentation-batch-7-summary
description: 代码注释与中文化改进第七批总结：角色能力、资源与状态 API
metadata:
  type: task-summary
  batch: 7
  last_updated: 2026-07-20
---

# 代码注释与中文化改进第七批总结

## 本批范围

本批继续处理 `CharacterBase` 剩余核心 partial，重点是角色对外公开合同：能力来源、资源/伤害、动作锁、控制权和持续效果展示。

### 已处理文件

1. `Assets/Scripts/GameCore/Runtime/Entities/Characters/CharacterBase.Abilities.cs`
2. `Assets/Scripts/GameCore/Runtime/Entities/Characters/CharacterBase.Resources.cs`
3. `Assets/Scripts/GameCore/Runtime/Entities/Characters/CharacterBase.StateApi.cs`

## 改进内容

### 1. 能力来源与技能槽合同

**文件**：`CharacterBase.Abilities.cs`

**改进点**：

- 补充正式 EX-GAS 能力新增/移除的统一收口说明。
- 说明能力来源键的用途：装备、永久成长、状态效果、变形、感染等来源分别可撤回和叠加。
- 补充来源化能力授予、撤回、压制、移除全部来源规则的边界注释。
- 说明压制状态会同步取消技能槽生命周期、打断能力并禁用实例。
- 补充快捷技能槽触发、停止、装备、清空、存档快照和恢复的合同说明。
- 补充能力 Prefab 实例化和释放的失败后果：配置缺失时直接报错，不创建半成品能力实例。

### 2. 资源、伤害与属性事件

**文件**：`CharacterBase.Resources.cs`

**改进点**：

- 补充受击无敌表现开关、资源校验、法力裁剪和攻击速度倍率说明。
- 补充基础属性/当前属性事件订阅语义：监听者拿到的是变化前快照。
- 补充 `Damage(...)` 的职责说明：目标校验、伤害解算、推力、挑衅、受击表现和正式 ASC 扣血。
- 补充治疗、回蓝、耗蓝和升级恢复资源的边界说明。
- 补充正式 ASC 写入、启动期 bootstrap buffer 回退和失败报错的说明。
- 说明战斗最小属性快照只提取伤害系统真正需要的字段。

### 3. 状态 API、控制权与持续效果展示

**文件**：`CharacterBase.StateApi.cs`

**改进点**：

- 为运行时事件和来源化字典补充字段级说明，明确事件参数、叠层语义和 owner。
- 补充 Cleanse、持续效果添加、叠层消费、展示新增/移除和运行时推进的注释。
- 补充普通移速规则、持续效果移速规则、动作锁、来源化动作锁的 key/叠层边界。
- 补充玩家控制锁、AI 控制覆盖和装备效果压制的用途说明。
- 补充阵营覆盖优先级和同优先级稳定排序规则。
- 补充正式 GameplayTag 动作门禁：攻击中、眩晕、定身和沉默等标签会覆盖本地动作运行时。

## 设计边界

- 本批只新增注释，不改运行时逻辑。
- `CharacterBase` 仍然是角色状态与公开 API owner；UI、AI、技能和表现层只拿快照或订阅事件。
- 能力实例、来源化规则、持续效果和动作锁都保持原有 owner，不引入新的状态存储。
- 启动期属性缓冲只作为初始化窗口回退，不恢复旧 Stats 双轨。

## 验证

- ✅ `git diff --check` 通过。
- ✅ 三个目标文件均无 UTF-8 BOM。
- ✅ 三个目标文件均保留末尾换行。
- ✅ 三个目标文件未发现旧 `InspectorName(...)`、英文 `Header` 或英文工具菜单回流。
- ⚠️ UnitySkills 编译反馈工具本轮没有直接暴露，只能记录未跑 Unity Editor 编译。
- ⚠️ `.spec/tools/spec-lint.mjs` 已知仍因既有 frontmatter 识别问题失败，不是本批新增文档单独造成。

## 下一步建议

下一批建议继续处理 `CharacterBase.Persistence.cs`、`CharacterBase.ActionStateRuntime.cs`、`CharacterBase.TemporalEffectRuntime.cs`，或者切到 `AIController.cs` 的 AI 追踪、转向和攻击门禁。
