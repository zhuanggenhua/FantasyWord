---
name: code-documentation-batch-9-summary
description: 代码注释与中文化改进第九批总结：角色变更、能力容器、属性启动缓冲与 AI 控制器
metadata:
  type: task-summary
  batch: 9
  last_updated: 2026-07-20
---

# 代码注释与中文化改进第九批总结

## 本批范围

本批继续处理高优先级运行时组件，重点是角色变身/感染规则运行时、能力集合容器、属性 bootstrap 缓冲，以及 AI 控制器主入口的 Inspector 中文化和生命周期说明。

### 已处理文件

1. `Assets/Scripts/GameCore/Runtime/Entities/Characters/CharacterBase.Alterations.cs`
2. `Assets/Scripts/GameCore/Runtime/Entities/Characters/CharacterBase.AbilitySetRuntime.cs`
3. `Assets/Scripts/GameCore/Runtime/Entities/Characters/CharacterBase.AttributeBootstrapBuffer.cs`
4. `Assets/Scripts/GameCore/Runtime/Controllers/AIController.cs`

## 改进内容

### 1. 变身/感染规则运行时

**文件**：`CharacterBase.Alterations.cs`

**改进点**：

- 补充激活规则字典的字段说明：只记录规则资产和叠层数，派生效果仍由对应运行时容器持有。
- 说明规则应用必须先解析稳定来源键，否则后续撤回、读档和叠层无法匹配同一来源。
- 补充 Unique 与 Stackable 的入口边界，明确整条规则移除和单层叠层移除的差别。
- 补充互斥组优先级裁决：高优先级阻止低优先级覆盖，低优先级或同优先级规则会先整条退场。
- 补充存档快照和读档恢复说明：可叠层规则按层数重复写入引用，读档只恢复非能力派生效果和叠层状态。

### 2. 能力集合运行时容器

**文件**：`CharacterBase.AbilitySetRuntime.cs`

**改进点**：

- 为永久解锁集合、临时授予来源表、压制来源表和能力实例表补充字段职责说明。
- 说明临时授予返回值代表是否创建新实例，不等同于来源叠层是否增加。
- 说明临时授予撤回返回值代表是否应释放实例，永久解锁能力不会因临时来源退场被释放。
- 补充能力压制/解除压制的返回值语义：只在压制状态发生整体变化时返回 true。
- 补充来源快照、实例快照、冷却推进、重置、打断和 RuntimeAbilityKey 的边界说明。

### 3. 属性启动缓冲

**文件**：`CharacterBase.AttributeBootstrapBuffer.cs`

**改进点**：

- 说明基础/当前属性快照只服务启动窗口，不作为 Awake 后正式 ASC 的长期镜像真相。
- 补充清理旧快照的必要性，避免读档或对象复用时污染 ASC 初始值。
- 说明基础属性替换会把差额同步到当前属性快照，避免配置刷新时硬重置当前生命/法力。
- 为 getter 和 snapshot 创建入口补充边界说明，强调外部拿到的是副本而不是内部可变引用。

### 4. AI 控制器主入口

**文件**：`AIController.cs`

**改进点**：

- 引入 Odin `LabelText`，把旧 `InspectorName` 更新为项目当前 Inspector 中文化口径。
- 移除单字段 `Header("引用")`，保留追踪、转向、攻击等多个字段组成的中文分组。
- 按规范调整约束特性顺序：`SerializeField/Min/Range` 在前，`LabelText/Tooltip` 在后。
- 为当前目标、重新选敌冷却、攻击冷却、初始点、失去视线计时和行为运行时补充字段说明。
- 补充初始化、启动、停止、销毁、挑衅处理、固定步 tick、存档读取和保存的生命周期说明。

## 设计边界

- 本批只补注释和 Inspector 文案，不改 AI 寻敌、转向、攻击或角色状态逻辑。
- `CharacterBase.Alterations.cs` 不改规则应用顺序，只把现有互斥、叠层和存档恢复边界写清楚。
- `CharacterAbilitySetRuntime` 仍是 `CharacterAbilitySet` 持有的唯一能力实例容器，不引入第二套实例仓库。
- `AttributeBootstrapBuffer` 继续只作为启动窗口兼容缓冲，不恢复旧 Stats 双轨。
- `AIController.cs` 只处理主文件；`AIController.BehaviourRuntime.cs` 仍可作为后续批次继续细化。

## 验证

- ✅ `git diff --check` 通过。
- ✅ 本批目标文件未发现旧 `InspectorName(...)` 或英文 `Header` 回流。
- ✅ `AIController.cs` 已去掉单字段 `Header("引用")`，保留多字段中文分组。
- ⚠️ UnitySkills 编译反馈工具本轮没有直接暴露，未跑 Unity Editor 编译。
- ⚠️ `.spec/tools/spec-lint.mjs` 已知仍因既有 frontmatter 识别问题失败，不是本批新增文档单独造成。

## 下一步建议

下一批建议继续处理 `CharacterBase.Contracts.cs`、`CharacterAlterationRule.cs`，或补 `AIController.BehaviourRuntime.cs` 的寻敌、视线、攻击对准和转向行为注释。
