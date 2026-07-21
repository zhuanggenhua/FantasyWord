---
name: code-documentation-progress-summary
description: 代码注释与中文化改进工作总进度
metadata:
  type: progress-summary
  last_updated: 2026-07-21
---

# 代码注释与中文化改进工作总进度

## 📊 整体进度概览

| 指标 | 完成情况 |
|------|---------|
| **已完成批次** | 25 / 预计 N |
| **已完成文件** | 90 个文件（89 个代码文件 + 1 个规范文档） |
| **改进项** | 约 2700+ 处 |
| **规范文档** | ✅ 已更新并复核 |
| **核心运行时组件** | 25 个/组（CharacterAbilitySet、CharacterBase、CharacterActor、CharacterPlayerControl、CharacterInventory、CharacterEquipment、CharacterMovement、CharacterButtonActivation、CharacterHandleWeapon、CharacterCommandExecutor、Persistence、ActionStateRuntime、TemporalEffectRuntime、Alterations、AbilitySetRuntime、AttributeBootstrapBuffer、Contracts、CharacterAlterationRule、AIController、AIController.BehaviourRuntime、CombatSolver、AEffect、ATemporalEffect、Temporal*Effect、FormalAbilityInputGateSettings） |
| **运行时合同** | 2 个（PlayerCommandRequest、PlayerOrderRequest） |
| **表现层组件** | 5 个（CharacterEquipmentPresentation、CharacterActionAnimatorDriver、DirectionalSpriteLibraryDriver、MountedCharacterPresentation、EquipmentRenderer） |
| **UI 组件** | 41 个（UISystem、UIMovementIndicator、UICharacterInfo、UIMainMenu、UIGameMenu、UIGameMenuEntry、UISettings、UISettingsVolume、UISettingsMasterVolume、UISettingsChannelVolume、UIEffectDescription、UIEffectIcon、UIEffectList、UIEffectListEntry、UIStatBar、CombatTextDisplay、FloatingTextPool、UIAbility、UIHUDAbilityBar、UIHUDAbilityBarEntry、UIHUDAbilityMessage、UIHUDEffectBar、UIDialogue、UIDialogueChoiceBox、UIDialogueOption、UIDialogueSpeakerBox、UIDialogueMessageBox、UIEventLog、UIEventLogLine、UIItemDetails、UIInventory、UIInventoryBag、UIInventoryBagCategory、UIInventoryBagSlot、UIInventoryEquipment、UIInventoryEquipmentSlot、UIInventoryStats、UIStat、CharacterMenuContext、UICharacter、UICharacterStat） |
| **编辑器工具** | 1 个（EquipmentWorkbenchAnimatorControllerTool） |

## ✅ 已完成的工作

### 批次 1：规范更新 + 初始文件（2026-07-20）

#### 1. 规范文档更新
**文件**：`.spec/knowledge/standards/code-style.md`

**新增内容**：
- ✅ Odin Inspector 使用规范（LabelText、Tooltip、特性顺序）
- ✅ MenuItem 中文化强制要求
- ✅ 详细注释质量标准（适合英语基础一般的团队）
- ✅ 编辑器工具类注释简化策略

**关键规则**：
```markdown
- 运行时核心组件：详细注释（最高优先级）
- 编辑器工具类：简要注释即可
- 特性顺序：约束特性在前，LabelText 在后
- MenuItem 必须中文化
```

#### 2. 编辑器工具类
**文件**：`Assets/Scripts/Presentation/EquipmentSystem/Editor/Utilities/EquipmentWorkbenchAnimatorControllerTool.cs`

**改进内容**：
- ✅ MenuItem 中文化（2 个菜单项）
  - `"Tools/Equipment System/..." → "工具/装备系统/..."`
- ✅ 类级注释
- ✅ 内部类注释（ActionSpec）
- ✅ 关键方法简要注释

#### 3. 核心运行时组件 #1
**文件**：`Assets/Scripts/GameCore/Runtime/Entities/Characters/CharacterAbilitySet.cs`

**改进内容**：
- ✅ 详细类级文档
  - 说明这是项目自定义的角色能力封装层，不是 GAS 官方推荐用法
  - 阐明与 EX-GAS 的 ASC 的关系
  - 说明装备栏系统、技能根节点管理等角色特定功能
- ✅ 字段注释（SerializeField + 运行时数据）
- ✅ 关键方法注释
  - `FireFormalGasAbility()`
  - `FireEquippedAbilityAtIndex()`
  - `TryEquipFormalGasAbilityCodeToSlot()`
  - `FireResolvedAbility()`（详细实现注释）
- ✅ 生命周期方法注释

**详细总结**：`.spec/tasks/code-documentation-batch-1-summary.md`

---

### 批次 2：核心角色基类（2026-07-20）

#### 4. 核心运行时组件 #2（最重要）
**文件**：`Assets/Scripts/GameCore/Runtime/Entities/Characters/CharacterBase.cs`

**改进内容**：
- ✅ **详细类级文档**
  - 核心职责（生命周期、属性系统、行动系统、装备集成等）
  - 设计说明（继承关系、依赖组件、partial class 结构）
  - 关键状态（dead、invincible、currentAlignment）
  - 注意事项（OnDisable 触发场景、延迟死亡机制等）

- ✅ **20+ 个字段注释**
  - 所有 SerializeField 补充中文说明
  - 运行时状态标志位说明用途和触发条件
  - 关键计时器和缓存说明

- ✅ **8 个生命周期方法完整注释**
  - `Awake()`：5 步初始化顺序
  - `OnEnable()`：4 种触发场景 + 执行内容
  - `Update()`：每帧处理逻辑
  - `AdvanceCharacterRuntime()`：运行时推进详解
  - `OnDisable()`：清理逻辑 + 触发场景
  - `OnDeathAnimationEnd()`：防御性措施
  - `OnDeath()`：死亡标记
  - `EnsureFormalAbilitySystemInitializedAfterAwake()`：防御性初始化

- ✅ **15+ 个核心方法详细注释**
  - `ResolveDeathCommandContext()`：死亡归属判断
  - `Revive()`：6 步复活流程
  - `OnInteract()`：死亡/活着状态处理
  - `CanUpdateTargetDirection()`：技能方向锁定
  - `CalculateMoveSpeed()`：速度系数应用
  - `InitializeStats()`：初始属性构建
  - `RefreshResolvedStatsForEquipmentRuntime()`：装备属性刷新
  - `SetResolvedBaseStats()`：属性写回机制（引导窗口详解）
  - `Kill()`：**8 步完整死亡流程**
  - `RequestDeathAfterFormalCurrentValueMutation()`：延迟死亡原理
  - `ProcessPendingActionInterruptAfterFormalDamage()`：延迟打断处理
  - 等等...

**关键改进点**：
1. **延迟处理机制**：详细解释为什么死亡和行动打断需要延迟到 Update 处理
2. **属性初始化流程**：说明属性引导窗口、初始化顺序、防御性措施
3. **死亡流程分解**：8 个步骤逐一说明（反馈、通知、转移物品、转移装备、清除 Buff、打断技能等）
4. **生命周期触发场景**：明确说明 OnEnable/OnDisable 的多种触发可能

#### 5. 装备表现层
**文件**：`Assets/Scripts/Presentation/EquipmentSystem/Runtime/CharacterEquipmentPresentation.cs`

**改进内容**：
- ✅ 优化类级文档（职责、设计原则、注意事项）
- ✅ 补充字段注释（3 个组件）
- ✅ `RefreshFromEquipment()` 流程注释
- ✅ `RefreshMountedRiderEquipmentOverlay()` 说明

**详细总结**：`.spec/tasks/code-documentation-batch-2-summary.md`

---

### 批次 3：角色控制、背包与装备玩法层（2026-07-20）

#### 6. 玩家控制入口
**文件**：`Assets/Scripts/GameCore/Runtime/Entities/Characters/CharacterPlayerControl.cs`

**改进内容**：
- ✅ 补充类级文档，说明它是单角色玩家输入目标，不拥有玩家身份、不直接改写世界状态
- ✅ 说明 `PlayerSystem -> PlayerOrderRequest -> CharacterCommandExecutor` 的正式输入链路
- ✅ 补充字段、属性、公开入口、生命周期和本地控制状态清理注释
- ✅ 将 Inspector 标题和字段显示补成中文

#### 7. 角色背包 owner 配置
**文件**：`Assets/Scripts/GameCore/Runtime/Entities/Characters/CharacterInventory.cs`

**改进内容**：
- ✅ 扩展类级文档，说明组件只解析背包 owner，不存储物品列表
- ✅ 为 `ECharacterInventoryChannel` 枚举值补充说明
- ✅ 补充主背包、武器背包、快捷栏背包的 owner 解析语义
- ✅ 将 `InspectorName` 更新为 Odin `LabelText`

#### 8. 装备玩法层
**文件**：`Assets/Scripts/GameCore/Runtime/Entities/Characters/CharacterEquipment.cs`

**改进内容**：
- ✅ 补充详细类级文档，明确装备槽、初始装备、属性贡献、装备附加 Formal GAS Ability 和事件职责
- ✅ 说明它是玩法层 owner，表现层只通过 `EquipmentLoadoutChanged` 订阅变化
- ✅ 补充穿戴、卸下、恢复、存档快照、强制卸装、属性刷新和能力来源 GUID 说明
- ✅ 补充装备效果压制规则的叠加、移除和生命周期清理注释
- ✅ 移除单字段英文 Header，并补充 `LabelText` / `Tooltip`

**质量检查**：
- ✅ `git diff --check` 通过
- ✅ 确认目标文件中旧英文 Inspector 标题已移除
- ⚠️ 本轮未启动 Unity Editor 编译；改动以注释和 Inspector 特性为主

**详细总结**：`.spec/tasks/code-documentation-batch-3-summary.md`

---

### 批次 4：移动、交互与武器挂点（2026-07-20）

#### 9. 角色移动输入适配
**文件**：`Assets/Scripts/GameCore/Runtime/Entities/Characters/CharacterMovement.cs`

**改进内容**：
- ✅ 补充类级文档，说明它只把命令转换成角色移动意图，不拥有玩家身份、地图真相或导航数据
- ✅ 补充点击移动链路说明：优先走 `TerrainNavigationMap`，没有导航图时回退到 `Movable.NearestValidDestination(...)` 和直线移动
- ✅ 补充方向移动、停止移动、点击移动、切换移动模式和指针朝向更新的职责说明
- ✅ 为序列化字段补充中文 `LabelText` 和 `Tooltip`
- ✅ 将英文 Header `Movement Control` 改为中文分组 `移动控制`

#### 10. 交互目标解析与派发
**文件**：`Assets/Scripts/GameCore/Runtime/Entities/Characters/CharacterButtonActivation.cs`

**改进内容**：
- ✅ 补充类级文档，说明它负责交互目标解析和 `IInteractionReceiver` 派发
- ✅ 补充目标筛选规则：显式目标优先，否则按层级、半径、距离和角色朝向筛选
- ✅ 补充父级链派发说明，支持子碰撞体命中但逻辑挂在父对象上的 Prefab 结构
- ✅ 说明 `m_interactedThisFrame` 用于阻止同一输入同时触发交互和技能
- ✅ 为序列化字段补充中文 `LabelText` 和 `Tooltip`
- ✅ 将英文 Header `Interaction` 改为中文分组 `交互配置`

#### 11. 角色武器挂点
**文件**：`Assets/Scripts/GameCore/Runtime/Entities/Characters/CharacterHandleWeapon.cs`

**改进内容**：
- ✅ 补充类级文档，说明它只提供武器挂点和弹丸出生点，不拥有装备槽、武器数据或攻击规则
- ✅ 补充 `WeaponAttachment`、`ProjectileSpawn`、`ProjectileSpawnPosition` 的回退语义
- ✅ 补充查询挂点和解析弹丸出生位置的方法说明
- ✅ 为序列化字段补充中文 `LabelText` 和 `Tooltip`
- ✅ 将英文 Header `Weapon Handling` 改为中文分组 `武器挂点`

**质量检查**：
- ✅ 三份目标文件中旧英文 Header 已移除
- ✅ 三份目标文件没有 UTF-8 BOM
- ✅ `git diff --check` 通过
- ⚠️ 本轮未启动 Unity Editor 编译；改动以注释和 Inspector 特性为主

**详细总结**：`.spec/tasks/code-documentation-batch-4-summary.md`

---

### 批次 5：命令合同与命令执行器（2026-07-20）

#### 12. 角色命令执行器
**文件**：`Assets/Scripts/GameCore/Runtime/Entities/Characters/CharacterCommandExecutor.cs`

**改进内容**：
- ✅ 补充类级文档，说明它是角色侧命令路由层，只负责分发命令和统一失败结果
- ✅ 明确边界：不拥有玩家输入、不拥有移动规则、不拥有交互规则、不直接实现能力规则
- ✅ 为角色引用补充 Odin `LabelText` 和中文 `Tooltip`
- ✅ 补充 `Submit(...)`、`Execute(...)` 和各类命令执行方法的职责说明
- ✅ 补充 actor 校验、同帧交互阻止技能、技能瞄准方向优先级等关键边界注释

#### 13. 玩家命令请求合同
**文件**：`Assets/Scripts/GameCore/Runtime/Controllers/PlayerCommandRequest.cs`

**改进内容**：
- ✅ 为 `EPlayerCommandKind` 和 `EPlayerCommandFailureReason` 枚举值补充中文说明
- ✅ 为命令上下文、方向、世界坐标、技能槽、目标角色和交互目标补充属性注释
- ✅ 补充 `PlayerCommandResult` 成功/失败语义和工厂方法说明

#### 14. 玩家订单请求合同
**文件**：`Assets/Scripts/GameCore/Runtime/Controllers/PlayerOrderRequest.cs`

**改进内容**：
- ✅ 为订单目标范围、队列模式和空间分配策略枚举补充中文说明
- ✅ 补充空间分配合同、分散世界坐标、队列模式和停止订单语义
- ✅ 补充默认解析规则：移动类命令默认作用控制组，点击移动默认使用环形分散落点
- ✅ 补充 `PlayerOrderResult` 立即成功、失败和入队结果说明

**质量检查**：
- ✅ `git diff --check` 通过
- ✅ 三份目标文件没有 UTF-8 BOM，并保留末尾换行
- ✅ 三份目标文件未发现旧 `InspectorName(...)` 或英文 `Header` 回流
- ⚠️ 本轮未启动 Unity Editor 编译；改动以注释和 Inspector 文案为主

**详细总结**：`.spec/tasks/code-documentation-batch-5-summary.md`

---

### 批次 6：角色成长、Sheet 入口与正式 ASC 运行时（2026-07-20）

#### 15. 正式 ASC 运行时
**文件**：`Assets/Scripts/GameCore/Runtime/Entities/Characters/CharacterBase.GASRuntime.cs`

**改进内容**：
- ✅ 移除单字段英文 `Header("GAS")`，改为字段自己的 Odin `LabelText` 和中文 `Tooltip`
- ✅ 补充正式 ASC 初始化、属性读取、当前值写入和事件订阅的中文说明
- ✅ 说明启动期 bootstrap buffer 的边界：只允许初始化窗口短暂回退，不恢复旧 Stats 双轨
- ✅ 补充属性快照写入、当前值变更事件、ASC 委托注销和清除持续效果的失败后果说明

#### 16. 角色成长与运行时快照
**文件**：`Assets/Scripts/GameCore/Runtime/Entities/Characters/CharacterActor.cs`

**改进内容**：
- ✅ 将旧 `InspectorName` 更新为 Odin `LabelText`，并移除两个单字段 `Header`
- ✅ 为 `EEquipmentOperationResult` 枚举值补充中文语义
- ✅ 为 Actor 存档块、运行时快照、装备槽和快捷技能槽字段补充中文说明
- ✅ 补充经验、自由属性点、等级、正式动画驱动、死亡/复活、存档和运行时快照恢复的边界注释

#### 17. 角色 Sheet 入口
**文件**：`Assets/Scripts/GameCore/Runtime/Entities/Characters/CharacterActor.Sheet.cs`

**改进内容**：
- ✅ 移除英文 `Header("Character Settings")`
- ✅ 为 `m_sheet` 补充 Odin `LabelText("角色配置表")` 和中文 `Tooltip`
- ✅ 保留 `[FormerlySerializedAs("m_characterSheet")]`，避免旧 Prefab 或存档引用丢失
- ✅ 为正式配置表入口和旧调用兼容入口补充说明

**质量检查**：
- ✅ `git diff --check` 通过
- ✅ 三份目标文件没有 UTF-8 BOM，并保留末尾换行
- ✅ 三份目标文件未发现旧 `InspectorName(...)`、`Header(...)` 或英文工具菜单回流
- ⚠️ `.spec/tools/spec-lint.mjs` 仍因既有 frontmatter 识别问题失败，失败列表覆盖大量既有 `.spec` 文件，不是本批新增文档单独造成
- ⚠️ 本轮未启动 Unity Editor 编译；改动以注释和 Inspector 文案为主

**详细总结**：`.spec/tasks/code-documentation-batch-6-summary.md`

---

### 批次 7：角色能力、资源与状态 API（2026-07-20）

#### 18. 能力来源与技能槽合同
**文件**：`Assets/Scripts/GameCore/Runtime/Entities/Characters/CharacterBase.Abilities.cs`

**改进内容**：
- ✅ 补充正式 EX-GAS 能力新增/移除的统一收口说明
- ✅ 补充装备、永久成长、状态效果、变形、感染等来源键的撤回和叠加语义
- ✅ 说明来源化能力授予、撤回、压制、移除全部来源规则的边界
- ✅ 补充快捷技能槽触发、停止、装备、清空、存档快照和恢复的合同说明
- ✅ 补充能力 Prefab 实例化和释放的失败后果说明

#### 19. 资源、伤害与属性事件
**文件**：`Assets/Scripts/GameCore/Runtime/Entities/Characters/CharacterBase.Resources.cs`

**改进内容**：
- ✅ 补充资源校验、法力裁剪、攻击速度倍率和受击无敌表现开关说明
- ✅ 补充基础属性/当前属性事件订阅语义：监听者拿到变化前快照
- ✅ 补充 `Damage(...)` 的职责说明：目标校验、伤害解算、推力、挑衅、受击表现和正式 ASC 扣血
- ✅ 补充治疗、回蓝、耗蓝、升级资源恢复和 bootstrap buffer 失败边界

#### 20. 状态 API、控制权与持续效果展示
**文件**：`Assets/Scripts/GameCore/Runtime/Entities/Characters/CharacterBase.StateApi.cs`

**改进内容**：
- ✅ 为运行时事件和来源化字典补充字段级说明
- ✅ 补充 Cleanse、持续效果添加、叠层消费、展示新增/移除和运行时推进的注释
- ✅ 补充移速规则、动作锁、来源化动作锁、玩家控制锁和 AI 控制覆盖的边界
- ✅ 补充阵营覆盖优先级、同优先级稳定排序和正式 GameplayTag 动作门禁说明

**质量检查**：
- ✅ `git diff --check` 通过
- ✅ 三份目标文件没有 UTF-8 BOM，并保留末尾换行
- ✅ 三份目标文件未发现旧 `InspectorName(...)`、英文 `Header` 或英文工具菜单回流
- ⚠️ UnitySkills 编译反馈工具本轮没有直接暴露，只能记录未跑 Unity Editor 编译
- ⚠️ `.spec/tools/spec-lint.mjs` 已知仍因既有 frontmatter 识别问题失败，不是本批新增文档单独造成

**详细总结**：`.spec/tasks/code-documentation-batch-7-summary.md`

---

### 批次 8：存档、动作状态与持续效果注册表（2026-07-20）

#### 21. 存档与运行时快照恢复
**文件**：`Assets/Scripts/GameCore/Runtime/Entities/Characters/CharacterBase.Persistence.cs`

**改进内容**：
- ✅ 补充基础存档块、正式存档和轻量运行时快照的职责说明
- ✅ 明确读档恢复顺序：清旧来源、恢复能力来源和压制、恢复等级/能力运行时、恢复持续效果与当前属性
- ✅ 说明来源化能力和压制只保存正式能力编号、来源类型、来源 ID 和叠层数，不保存运行时实例
- ✅ 补充持续效果读写盘、重建、注册和 runtimeKey 稳定排序的边界说明

#### 22. 动作状态运行时容器
**文件**：`Assets/Scripts/GameCore/Runtime/Entities/Characters/CharacterBase.ActionStateRuntime.cs`

**改进内容**：
- ✅ 为动作启用位、普通动作锁、来源化动作锁、移速倍率和持续效果动作锁补充字段说明
- ✅ 补充普通 key、来源键和 effect runtimeKey 三类句柄的生命周期和失败语义
- ✅ 说明普通动作锁和普通移速倍率 key 不存在时抛错，用于暴露重复释放或生命周期错误
- ✅ 说明持续效果 runtimeKey 必须为正数，用于读档恢复、状态回滚和运行时注册表匹配

#### 23. 持续效果 runtimeKey 注册表
**文件**：`Assets/Scripts/GameCore/Runtime/Entities/Characters/CharacterBase.TemporalEffectRuntime.cs`

**改进内容**：
- ✅ 补充持续效果注册表的 runtimeKey 主键语义
- ✅ 说明同 key 新实例会替换旧实例，并把旧实例交给调用方统一完成退场
- ✅ 补充按 runtimeKey 查询、当前实例判断和 key 快照遍历的边界说明
- ✅ 说明移除接口会对输入 key 去重，并只返回实际移除的 effect 实例

**质量检查**：
- ✅ `git diff --check` 通过
- ✅ 三份目标文件没有 UTF-8 BOM，并保留末尾换行
- ✅ 三份目标文件未发现旧 `InspectorName(...)`、英文 `Header` 或英文工具菜单回流
- ⚠️ UnitySkills 编译反馈工具本轮没有直接暴露，只能记录未跑 Unity Editor 编译
- ⚠️ `.spec/tools/spec-lint.mjs` 已知仍因既有 frontmatter 识别问题失败，不是本批新增文档单独造成

**详细总结**：`.spec/tasks/code-documentation-batch-8-summary.md`

---

### 批次 9：角色变更、能力容器、属性缓冲与 AI 控制器（2026-07-20）

#### 24. 变身/感染规则运行时
**文件**：`Assets/Scripts/GameCore/Runtime/Entities/Characters/CharacterBase.Alterations.cs`

**改进内容**：
- ✅ 补充激活规则字典职责，说明它只记录规则资产和叠层数
- ✅ 明确规则应用需要稳定来源键，保证撤回、读档和叠层匹配同一来源
- ✅ 补充 Unique/Stackable、整条规则移除和单层叠层移除的区别
- ✅ 补充互斥组优先级裁决、存档快照和读档恢复边界

#### 25. 能力集合运行时容器
**文件**：`Assets/Scripts/GameCore/Runtime/Entities/Characters/CharacterBase.AbilitySetRuntime.cs`

**改进内容**：
- ✅ 为永久解锁、临时授予、压制来源和能力实例表补充字段说明
- ✅ 说明临时授予返回值代表是否创建新实例，不等同于叠层是否增加
- ✅ 说明临时授予撤回返回值代表是否应释放实例
- ✅ 补充压制、解除压制、快照、tick、重置、打断和 RuntimeAbilityKey 的边界说明

#### 26. 属性启动缓冲
**文件**：`Assets/Scripts/GameCore/Runtime/Entities/Characters/CharacterBase.AttributeBootstrapBuffer.cs`

**改进内容**：
- ✅ 说明基础/当前属性快照只服务启动窗口，不作为正式 ASC 长期镜像真相
- ✅ 补充清理旧快照、基础属性差额同步和当前属性保留边界
- ✅ 为 getter 和 snapshot 创建入口补充副本语义说明

#### 27. AI 控制器主入口
**文件**：`Assets/Scripts/GameCore/Runtime/Controllers/AIController.cs`

**改进内容**：
- ✅ 将旧 `InspectorName` 更新为 Odin `LabelText`
- ✅ 移除单字段 `Header("引用")`，保留多字段中文分组
- ✅ 按规范调整 `SerializeField/Min/Range` 与 `LabelText/Tooltip` 的顺序
- ✅ 补充目标、冷却、初始点、视线计时、行为运行时和生命周期入口说明

**质量检查**：
- ✅ `git diff --check` 通过
- ✅ 本批目标文件未发现旧 `InspectorName(...)` 或英文 `Header` 回流
- ✅ `AIController.cs` 已去掉单字段 `Header("引用")`
- ⚠️ UnitySkills 编译反馈工具本轮没有直接暴露，只能记录未跑 Unity Editor 编译
- ⚠️ `.spec/tools/spec-lint.mjs` 已知仍因既有 frontmatter 识别问题失败，不是本批新增文档单独造成

**详细总结**：`.spec/tasks/code-documentation-batch-9-summary.md`

---

### 批次 10：变身规则资产、角色合同与 AI 行为运行时（2026-07-20）

#### 28. 变身/感染规则资产
**文件**：`Assets/Scripts/GameCore/Runtime/Database/Characters/CharacterAlterationRule.cs`

**改进内容**：
- ✅ 将旧 `InspectorName` 更新为 Odin `LabelText`
- ✅ 移除 2 字段 `Header("UI 设置")` 和 `Header("能力变化")`，保留 3+ 字段中文分组
- ✅ 补充规则资产职责、来源键创建、能力授予/压制、非能力效果和叠层撤回合同说明
- ✅ 说明数据库注册键是来源 ID 的真相源，未登记规则不能安全生成来源键

#### 29. 角色运行时合同数据
**文件**：`Assets/Scripts/GameCore/Runtime/Entities/Characters/CharacterBase.Contracts.cs`

**改进内容**：
- ✅ 补充能力来源键、运行时来源条目和存档来源数据的字段合同
- ✅ 补充能力释放结果、技能槽展示快照和能力菜单条目的 UI 兼容语义
- ✅ 补充角色存档块、局部运行时快照、能力运行时状态和持续效果恢复快照字段说明
- ✅ 说明持续效果恢复失败时不会生成半残效果

#### 30. AI 行为运行时
**文件**：`Assets/Scripts/GameCore/Runtime/Controllers/AIController.BehaviourRuntime.cs`

**改进内容**：
- ✅ 为 steering 适配器、路径游标、战斗游走、追踪位置和攻击对准门禁补充字段说明
- ✅ 补充初始化、停止、释放、挑衅处理和固定步 Tick 的顺序约束
- ✅ 补充视线检测、目标搜索、冷却推进、攻击尝试、攻击前对准和追击停止说明
- ✅ 补充战斗游走优先级、近身行为组、远距离导航、路径重算节流和 steering 行为组校验边界

**质量检查**：
- ✅ `git diff --check` 通过
- ✅ 本批目标文件均无 UTF-8 BOM，并保留末尾换行
- ✅ 本批目标文件未发现旧 `InspectorName(...)`、英文 `Header` 或英文工具菜单回流
- ⚠️ UnitySkills 编译反馈工具本轮没有直接暴露，只能记录未跑 Unity Editor 编译
- ⚠️ `.spec/tools/spec-lint.mjs` 已知仍因既有 frontmatter 识别问题失败，不是本批新增文档单独造成

**详细总结**：`.spec/tasks/code-documentation-batch-10-summary.md`

---

### 批次 11：战斗判定、效果底座与持续效果配置（2026-07-20）

#### 31. 战斗目标判定入口
**文件**：`Assets/Scripts/GameCore/Runtime/Combat/CombatSolver.cs`

**改进内容**：
- ✅ 补充类级文档，说明它是伤害、目标捕获、AI 选敌和效果筛选共用的最小判断入口
- ✅ 为可命中、敌我关系和主动敌对关系补充中文合同说明
- ✅ 移除英文行内注释，补充无敌、自作用、死亡和中立阵营边界

#### 32. 战斗效果底座
**文件**：`Assets/Scripts/GameCore/Runtime/Combat/Effects/AEffect.cs`

**改进内容**：
- ✅ 为目标分组、打断策略、表现屏蔽和失败概率补充 Odin `LabelText` / 中文 `Tooltip`
- ✅ 为效果基础数据补充中文作者入口说明
- ✅ 补充目标分组判断、随机失败、可应用性、运行时目标绑定、来源初始化、冲击向量解析和效果应用注释
- ✅ 明确运行时直接引用只服务当前实例，长期恢复仍以可持久化引用为准

#### 33. 持续效果基类
**文件**：`Assets/Scripts/GameCore/Runtime/Combat/Effects/Temporal/ATemporalEffect.cs`

**改进内容**：
- ✅ 为持续时间、叠加 ID、叠加策略和持续效果数据补充 Odin `LabelText` / 中文 `Tooltip`
- ✅ 补充应用、完成、叠加、展示分类和逐帧推进的合同说明
- ✅ 明确 runtimeKey 首次应用生成、失败回滚和 deltaTime 非负裁剪边界

#### 34. EX-GAS 正式伤害桥与持续效果配置
**文件**：`FormalGameplayEffectDamageBridge.cs`、`Temporal*Effect.cs`（9 个持续效果文件）

**改进内容**：
- ✅ 将旧 `InspectorName` 统一更新为 Odin `LabelText`
- ✅ 保留原有中文 `Tooltip` 和存档/恢复合同
- ✅ 补齐 `using Sirenix.OdinInspector;`
- ✅ 不改 tick、叠加、读档恢复、伤害桥或能力来源撤销逻辑

**质量检查**：
- ✅ `git diff --check` 通过
- ✅ 本批 13 个目标文件没有 UTF-8 BOM，并保留末尾换行
- ✅ 本批目标文件未发现旧 `InspectorName(...)`、乱码问号、英文 `Header` 或英文工具菜单回流
- ⚠️ 本轮未启动 Unity Editor 编译；改动以注释和 Inspector 文案为主

**详细总结**：`.spec/tasks/code-documentation-batch-11-summary.md`

---

### 批次 12：正式 GAS 输入门控配置（2026-07-20）

#### 35. 正式 GAS 输入门控配置
**文件**：`Assets/Scripts/GameCore/Runtime/Combat/Abilities/FormalAbilityInputGateSettings.cs`

**改进内容**：
- ✅ 补充 `EFormalAbilityInputTriggerMode` 和 `EFormalAbilityInputGateState` 的中文 XML 注释
- ✅ 为 `FormalAbilityInputGateConfig` 的 7 个序列化字段补齐 Odin `LabelText`
- ✅ 为 `FormalAbilityInputGateSettings` 的 17 个序列化字段补齐 Odin `LabelText`
- ✅ 保留 `输入`、`节奏`、`连发`、`弹匣` 四个 3+ 字段中文分组，符合“小块不要过度分组”的口径
- ✅ 为 `CreateTimelineGate(...)` 补充 Timeline 门控合同说明，明确本地门控不覆盖 EX-GAS Timeline 正式技能结构
- ✅ 本批没有修改 `Assets/Plugins`、第三方插件源码、参考工程或 Luban 生成物

**质量检查**：
- ✅ `git diff --check -- Assets/Scripts/GameCore/Runtime/Combat/Abilities/FormalAbilityInputGateSettings.cs` 通过
- ✅ 目标文件无 UTF-8 BOM，并保留末尾换行
- ✅ 目标文件未发现旧 `InspectorName`、英文 `Header`、`Tools/` 菜单路径或乱码问号
- ✅ `[SerializeField]` 24 处，`LabelText` 24 处
- ⚠️ 本轮未启动 Unity Editor 编译；改动以注释和 Inspector 文案为主

**详细总结**：`.spec/tasks/code-documentation-batch-12-summary.md`

---

### 批次 13：装备表现运行时与 Header 规范复核（2026-07-20）

#### 36. 角色动作 Animator 驱动
**文件**：`Assets/Scripts/Presentation/EquipmentSystem/Runtime/CharacterActionAnimatorDriver.cs`

**改进内容**：
- ✅ 补充 `using Sirenix.OdinInspector;`
- ✅ 扩展类级文档，说明它只负责 GameCore 动作请求到 Animator 状态的映射，不拥有身体朝向、SpriteLibrary 方向变体或装备材质合成
- ✅ 为动作数据库、默认/移动/受击/死亡动作键、Animator、阴影和调试字段补充中文 `LabelText` / `Tooltip`
- ✅ 移除 2 字段 `Header("运行时依赖")`，保留 5 字段中文分组 `Header("动画配置")`
- ✅ 补充动作切换、锁定、预览、数据库替换和自动恢复的中文合同说明

#### 37. 四向 SpriteLibrary 驱动
**文件**：`Assets/Scripts/Presentation/EquipmentSystem/Runtime/DirectionalSpriteLibraryDriver.cs`

**改进内容**：
- ✅ 补充 `using Sirenix.OdinInspector;`
- ✅ 扩展类级文档，说明它只切 SE/SW/NE/NW 方向库，不拥有移动或目标方向真相
- ✅ 为 5 个序列化字段补齐中文 `LabelText` / `Tooltip`
- ✅ 补充启用监听、四向库设置、方向切换和 SpriteLibrary 写入的中文说明

#### 38. 坐骑角色表现
**文件**：`Assets/Scripts/Presentation/EquipmentSystem/Runtime/MountedCharacterPresentation.cs`

**改进内容**：
- ✅ 补充 `using Sirenix.OdinInspector;`
- ✅ 将旧 `InspectorName` 统一替换为 Odin `LabelText`
- ✅ 删除单字段 `Header("未骑乘默认值")`
- ✅ 保留多字段中文分组 `Header("运行时依赖")`、`Header("调试")`
- ✅ 为坐骑资产、骑手层、动作回退、帧索引和普通装备叠加字段补充中文 `LabelText` / `Tooltip`
- ✅ 补充坐骑切换、装备叠加刷新、动作请求、逐帧推进、帧应用和原版 Sprite 直显材质的中文说明

#### 39. Header 规范复核补丁
**文件**：`.spec/knowledge/standards/code-style.md`、`CharacterAbilitySet.cs`、`CharacterBase.cs`

**改进内容**：
- ✅ 修正规范示例：`SerializeField/Min/Range` 在前，`LabelText/Tooltip` 在后
- ✅ 规范示例不再给 1 个字段单独套 `TitleGroup`，只在 3 个同职责字段上展示分组
- ✅ 将 `CharacterAbilitySet.cs` 的英文 `Header("Ability Composition")` 改为中文 `Header("能力组合")`
- ✅ 将 `CharacterBase.cs` 的英文 `Header("Character Base Settings")` 改为中文 `Header("角色基础设置")`
- ✅ 为上述两处遗留序列化字段补充中文 `LabelText` / `Tooltip`

**质量检查**：
- ✅ `git diff --check` 通过
- ✅ 第 13 批 3 个表现层目标文件无 UTF-8 BOM，并保留末尾换行
- ✅ 第 13 批 3 个表现层目标文件未发现旧 `InspectorName`、英文 `Header` 或 `Tools/` 菜单路径
- ✅ `[SerializeField]` / `LabelText` 覆盖关系已核对：8/9、5/5、16/16（多出的 1 个来自 public Inspector 字段 `animDatabase`）
- ✅ 复核补丁目标文件未发现旧 `InspectorName`、英文 `Header` 或 `Tools/` 菜单路径
- ✅ `Assets/Plugins`、`ReferenceSources`、`EX_GAS_Config/ProjectConfigTable/Tools`、`Packages` 无本轮 diff
- ⚠️ 本轮未启动 Unity Editor 编译；改动以注释和 Inspector 文案为主

**详细总结**：`.spec/tasks/code-documentation-batch-13-summary.md`

---

### 批次 14：装备渲染器与表现层刷新链路（2026-07-20）

#### 40. 装备渲染器
**文件**：`Assets/Scripts/Presentation/EquipmentSystem/Runtime/EquipmentRenderer.cs`

**改进内容**：
- ✅ 补充 `using Sirenix.OdinInspector;`
- ✅ 扩展类级文档，说明它只负责把角色帧数据、当前动作帧、外观和装备资产写入私有换装材质
- ✅ 明确方向和动作真相来自 Animator / 动作驱动 / 工作台预览覆盖，本组件不创建动作状态，也不拥有装备玩法槽位
- ✅ 将顶部 4 个单字段 `Header` 收口为中文 `Header("基础配置")`
- ✅ 移除 2 字段 `Header("运行时依赖")`，改用字段自己的 `LabelText` / `Tooltip`
- ✅ 保留 5 字段中文分组 `Header("运行时状态（只读）")`
- ✅ 为公开 Inspector 字段、序列化依赖和运行时调试字段补充中文 `LabelText` / `Tooltip`
- ✅ 将运行时调试字段改为 Odin `ReadOnly`
- ✅ 补充生命周期、动作同步、工作台/坐骑预览入口、装备入口、材质路径、刷新链路、武器缓存、外观颜色和防误用过滤的中文合同说明

**边界说明**：
- ✅ 没有修改装备、卸装、动作同步、UV 更新、Shader 参数、武器渲染、阴影计算或运行时对象清理逻辑
- ✅ 没有修改 `EquipmentUV.shader`、渲染 Feature、第三方插件、参考工程或生成物
- ✅ 第三方插件暂时不纳入本轮注释补充与 Inspector 中文化范围
- ✅ 临时占位 Sprite 仍只作为内部预览兜底，不写回正式装备资产

**质量检查**：
- ✅ `git diff --check -- Assets/Scripts/Presentation/EquipmentSystem/Runtime/EquipmentRenderer.cs` 通过
- ✅ 目标文件无 UTF-8 BOM，并保留末尾换行
- ✅ 目标文件未发现旧 `InspectorName`、英文 `Header` 或 `Tools/` 菜单路径
- ✅ 目标文件仅保留两个中文 `Header`：`基础配置`、`运行时状态（只读）`
- ✅ `SerializeFieldLike=7`、`LabelText=11`；多出的 4 个来自 public Inspector 暴露字段
- ✅ `Assets/Plugins`、`ReferenceSources`、`EX_GAS_Config/ProjectConfigTable/Tools`、`Packages` 无本轮 diff
- ⚠️ 本轮未启动 Unity Editor 编译；改动以注释和 Inspector 文案为主

**详细总结**：`.spec/tasks/code-documentation-batch-14-summary.md`

### 批次 15：项目侧 UI 小文件与 region 规范补丁（2026-07-20）

#### 41. 点击移动目标点指示器
**文件**：`Assets/Scripts/GameCore/Runtime/UI/UIMovementIndicator.cs`

**改进内容**：
- ✅ 补充 `using Sirenix.OdinInspector;`
- ✅ 移除英文 `Header("References")` 和 `Header("Settings")`
- ✅ 为目标移动体、指示器 Sprite、自动隐藏和淡入淡出速度补充中文 `LabelText` / `Tooltip`
- ✅ 为淡入淡出速度补充 `Min(0f)` 约束
- ✅ 补充类级说明和 `Start` / `Update` 生命周期合同，明确它只负责目标点显示，不拥有移动命令或路径真相

#### 42. UI 系统入口
**文件**：`Assets/Scripts/GameCore/Runtime/Game/Systems/UISystem.cs`

**改进内容**：
- ✅ 补充 `using Sirenix.OdinInspector;`
- ✅ 移除单字段英文 `Header("References")`
- ✅ 为 UI 根预制体补充中文 `LabelText` / `Tooltip`
- ✅ 将原英文行内注释改成中文 XML 注释
- ✅ 补充系统启动、存档载入后显示、创建/显示 UI 根节点和隐藏 UI 根节点的职责说明

#### 43. 角色信息面板
**文件**：`Assets/Scripts/GameCore/Runtime/UI/UICharacterInfo.cs`

**改进内容**：
- ✅ 补充 `using Sirenix.OdinInspector;`
- ✅ 将英文 `Header("References")` 改为中文 `Header("引用")`
- ✅ 为名称文本、生命滑条、魔力滑条、状态图标根节点、状态图标预制体、状态图标池容量和目标角色补充中文 `LabelText` / `Tooltip`
- ✅ 为状态图标池容量补充 `Min(0)` 约束
- ✅ 补充资源刷新、名称刷新、效果图标租用/归还、目标监听订阅/注销和模板缓存的中文合同说明

#### 44. #region 规范补丁
**文件**：`.spec/knowledge/standards/code-style.md`

**改进内容**：
- ✅ 新增 `#region 折叠区块规范`
- ✅ 明确 `#region` 是结构折叠和导航标记，不替代 XML 注释、字段注释或关键逻辑注释
- ✅ 明确大文件、多职责块、3 个以上同职责成员可用中文 `#region`
- ✅ 明确不为 1-2 个字段或 1 个普通方法单独套 `#region`
- ✅ 明确第三方插件、参考工程和生成物不因本规范强制修改 `#region`

**质量检查**：
- ✅ `git diff --check` 通过
- ✅ 第 15 批 3 个目标脚本无 UTF-8 BOM，并保留末尾换行
- ✅ 第 15 批 3 个目标脚本未发现旧 `InspectorName`、英文 `Header` 或 `Tools/` 菜单路径
- ✅ `[SerializeField]` / `LabelText` 覆盖关系已核对：4/4、7/7、1/1
- ✅ `Assets/Plugins`、`ReferenceSources`、`EX_GAS_Config/ProjectConfigTable/Tools`、`Packages` 无本轮 diff
- ⚠️ 本轮未启动 Unity Editor 编译；改动以注释、Inspector 文案和规范文档为主

**详细总结**：`.spec/tasks/code-documentation-batch-15-summary.md`

---

### 批次 16：菜单与设置 UI 小文件（2026-07-20）

#### 45. 主菜单入口
**文件**：`Assets/Scripts/GameCore/Runtime/UI/Menus/UIMainMenu.cs`

**改进内容**：
- ✅ 补充 `using Sirenix.OdinInspector;`
- ✅ 移除英文 `Header("Settings")` 和 `Header("References")`
- ✅ 为默认选中按钮、设置菜单、存档槽位和擦除按钮补充中文 `LabelText` / `Tooltip`
- ✅ 补充主菜单职责说明，明确它只负责存档槽展示、场景载入入口和设置菜单取消键监听
- ✅ 补充启用/禁用/销毁、存档刷新、设置菜单打开、取消键、读档/新游戏和监听注册的中文合同说明

#### 46. 游戏暂停菜单
**文件**：`Assets/Scripts/GameCore/Runtime/UI/Menus/UIGameMenu.cs`

**改进内容**：
- ✅ 补充 `using Sirenix.OdinInspector;`
- ✅ 将旧英文 `Header("References")` / `Header("Audio")` 收口为中文 `Header("菜单配置与反馈")`
- ✅ 为菜单入口列表、打开时隐藏对象、状态效果列表、暂停音效和恢复音效补充中文 `LabelText` / `Tooltip`
- ✅ 补充类级说明，明确暂停菜单只负责菜单栈进入/退出反馈、面板显隐和默认焦点
- ✅ 补充入栈/出栈、显示/隐藏、默认焦点和选中入口记录的中文合同说明

#### 47. 音量设置面板
**文件**：`Assets/Scripts/GameCore/Runtime/UI/Menus/Settings/UISettings.cs`

**改进内容**：
- ✅ 补充 `using Sirenix.OdinInspector;`
- ✅ 移除英文 `Header("References")` 和 `Header("Settings")`
- ✅ 保留 3 个同职责字段的中文 `Header("音量显示")`
- ✅ 为主音量控件、通道音量控件、显示最大值、显示后缀和调节步长补充中文 `LabelText` / `Tooltip`
- ✅ 为显示最大值补充 `Min(0f)` 约束，为调节步长补充 `Min(0.01f)` 约束
- ✅ 补充按钮回调、默认焦点、音量计算、主音量/通道音量调整和 UI 刷新的中文合同说明

#### 48. 单行音量控件
**文件**：`Assets/Scripts/GameCore/Runtime/UI/Menus/Settings/UISettingsVolume.cs`

**改进内容**：
- ✅ 补充 `using Sirenix.OdinInspector;`
- ✅ 将英文 `Header("References")` 改为中文 `Header("音量控件")`
- ✅ 为数值文本、降低按钮和提高按钮补充中文 `LabelText` / `Tooltip`
- ✅ 补充类级说明，明确该基类只负责数值展示和默认焦点按钮
- ✅ 补充 `UpdateUI` 和 `GetDefaultFocusTarget` 的中文合同说明

**质量检查**：
- ✅ `git diff --check` 通过
- ✅ 第 16 批 4 个目标脚本无 UTF-8 BOM，并保留末尾换行
- ✅ 第 16 批 4 个目标脚本未发现旧 `InspectorName`、英文 `Header` 或 `Tools/` 菜单路径
- ✅ `[SerializeField]` / `LabelText` 覆盖关系已核对：4/4、5/5、5/5、3/3
- ✅ 目标文件仅保留合理中文 Header：`菜单配置与反馈`、`音量显示`、`音量控件`
- ✅ `Assets/Plugins`、`ReferenceSources`、`EX_GAS_Config/ProjectConfigTable/Tools`、`Packages` 无本轮 diff
- ⚠️ 本轮未启动 Unity Editor 编译；改动以注释和 Inspector 文案为主

**详细总结**：`.spec/tasks/code-documentation-batch-16-summary.md`

---

### 批次 17：菜单子控件补丁（2026-07-21）

#### 49. 暂停菜单入口
**文件**：`Assets/Scripts/GameCore/Runtime/UI/Menus/UIGameMenuEntry.cs`

**改进内容**：
- ✅ 补充 `using Sirenix.OdinInspector;`
- ✅ 将旧 `InspectorName` 更新为 Odin `LabelText`
- ✅ 移除 1 个字段的中文 `Header("设置")` 和 2 个字段的中文 `Header("引用")`
- ✅ 为 `EGameMenuAction` 的 9 个枚举选项补充中文 `LabelText`
- ✅ 将旧英文行内注释改为中文边界说明，明确缺少默认随身制作台时隐藏制作入口
- ✅ 补充类级说明和初始化、销毁、焦点、点击请求分发的中文合同说明

#### 50. 主音量设置行
**文件**：`Assets/Scripts/GameCore/Runtime/UI/Menus/Settings/UISettingsMasterVolume.cs`

**改进内容**：
- ✅ 补充类级说明，明确它只绑定主音量增减按钮，不携带音频通道参数
- ✅ 补充 `RegisterCallbacks` 和 `UnregisterCallbacks` 的中文合同说明
- ✅ 保持原按钮监听注册/注销逻辑不变

#### 51. 通道音量设置行
**文件**：`Assets/Scripts/GameCore/Runtime/UI/Menus/Settings/UISettingsChannelVolume.cs`

**改进内容**：
- ✅ 补充 `using Sirenix.OdinInspector;`
- ✅ 移除单字段英文 `Header("Settings")`
- ✅ 为音频通道字段补充中文 `LabelText` / `Tooltip`
- ✅ 补充类级说明、通道属性、回调注册和回调注销的中文合同说明

**质量检查**：
- ✅ `git diff --check` 通过
- ✅ 第 17 批 3 个目标脚本无 UTF-8 BOM，并保留末尾换行
- ✅ 第 17 批 3 个目标脚本未发现旧 `InspectorName`、英文 `Header` 或 `Tools/` 菜单路径
- ✅ `[SerializeField]` / 字段级 `LabelText` 覆盖关系已核对：3/3、0/0、1/1
- ✅ `UIGameMenuEntry.EGameMenuAction` 的 9 个 Inspector 枚举选项已补中文 `LabelText`
- ✅ `Assets/Plugins`、`ReferenceSources`、`EX_GAS_Config/ProjectConfigTable/Tools`、`Packages` 无本轮 diff
- ⚠️ 本轮未启动 Unity Editor 编译；改动以注释和 Inspector 文案为主

**详细总结**：`.spec/tasks/code-documentation-batch-17-summary.md`

---

### 批次 18：效果列表 UI 小文件（2026-07-21）

#### 52. 持续效果详情浮层
**文件**：`Assets/Scripts/GameCore/Runtime/UI/Effects/UIEffectDescription.cs`

**改进内容**：
- ✅ 补充 `using Sirenix.OdinInspector;`
- ✅ 移除英文 `Header("References")` 和 `Header("Settings")`
- ✅ 为说明文本和最大行数补充中文 `LabelText` / `Tooltip`
- ✅ 为最大行数补充 `Min(1)` 约束
- ✅ 补充类级、属性、显示、隐藏和详情文本生成的中文合同说明

#### 53. 持续效果图标显示器
**文件**：`Assets/Scripts/GameCore/Runtime/UI/Effects/UIEffectIcon.cs`

**改进内容**：
- ✅ 补充 `using Sirenix.OdinInspector;`
- ✅ 为图标 Image 字段补充中文 `LabelText` / `Tooltip`
- ✅ 补充类级说明，明确它只负责写入 Sprite 和切换显隐
- ✅ 补充显示和隐藏入口的中文合同说明

#### 54. 持续效果列表面板
**文件**：`Assets/Scripts/GameCore/Runtime/UI/Effects/UIEffectList.cs`

**改进内容**：
- ✅ 补充 `using Sirenix.OdinInspector;`
- ✅ 将英文 `Header("References")` 收口为中文 `Header("效果列表配置")`
- ✅ 为 Buff / Debuff 条目预制体、列表内容根节点、详情面板、条目池容量和目标角色补充中文 `LabelText` / `Tooltip`
- ✅ 为条目池容量补充 `Min(0)` 约束
- ✅ 补充初始化、销毁、显示、隐藏、详情面板、悬停处理、条目租用、对象池配置和条目归还的中文合同说明

#### 55. 持续效果列表条目
**文件**：`Assets/Scripts/GameCore/Runtime/UI/Effects/UIEffectListEntry.cs`

**改进内容**：
- ✅ 补充 `using Sirenix.OdinInspector;`
- ✅ 将旧 `InspectorName` 更新为 Odin `LabelText`
- ✅ 移除单个小块 `Header("引用")`
- ✅ 为图标、文本和按钮字段补充中文 Inspector 标签
- ✅ 补充鼠标进入、选中和失焦回调的中文合同说明

**质量检查**：
- ✅ `git diff --check` 通过（Git 仅提示 LF/CRLF 自动转换）
- ✅ 第 18 批 4 个目标脚本无 UTF-8 BOM，并保留末尾换行
- ✅ 第 18 批 4 个目标脚本未发现旧 `InspectorName`、英文 `Header` 或 `Tools/` 菜单路径
- ✅ `[SerializeField]` / 字段级 `LabelText` 覆盖关系已核对：2/2、1/1、6/6、3/3
- ✅ `Assets/Plugins`、`ReferenceSources`、`EX_GAS_Config/ProjectConfigTable/Tools`、`Packages` 无本轮 diff
- ⚠️ 本轮未启动 Unity Editor 编译；改动以注释和 Inspector 文案为主

**详细总结**：`.spec/tasks/code-documentation-batch-18-summary.md`

---

### 批次 19：HUD 数值条与浮动战斗文本（2026-07-21）

#### 56. HUD 数值条
**文件**：`Assets/Scripts/GameCore/Runtime/UI/HUD/Stats/UIStatBar.cs`

**改进内容**：
- ✅ 补充 `using Sirenix.OdinInspector;`
- ✅ 将英文 Header 改为中文 Inspector 结构，并移除单字段英文小分组
- ✅ 为名称文本、数值滑条、数值文本、目标角色、数值类型和抖动参数补充中文 `LabelText` / `Tooltip`
- ✅ 为抖动幅度和抖动时长补充 `Min(0f)` 约束
- ✅ 补充类级、生命周期、目标绑定、UI 刷新和抖动反馈的中文合同说明
- ✅ 用中文 `#region` 收束 Inspector 配置、目标绑定、UI 刷新与反馈三个职责块

#### 57. 战斗浮字显示器
**文件**：`Assets/Scripts/GameCore/Runtime/UI/FloatingTexts/CombatTextDisplay.cs`

**改进内容**：
- ✅ 补充 `using Sirenix.OdinInspector;`
- ✅ 去除文件 UTF-8 BOM，并修正 using 空行错位
- ✅ 为生命、魔力、颜色、文案和动画参数配置补充中文 `LabelText` / `Tooltip`
- ✅ 将英文 Header 改为中文分组，并移除单字段英文小分组
- ✅ 补充类级、生命周期注册/注销和五类表现事件处理器的中文合同说明
- ✅ 用中文 `#region` 收束 Inspector 配置、生命周期、表现事件处理三个职责块

#### 58. 浮动文字对象池
**文件**：`Assets/Scripts/GameCore/Runtime/UI/FloatingTexts/FloatingTextPool.cs`

**改进内容**：
- ✅ 补充 `using Sirenix.OdinInspector;`
- ✅ 移除英文注释小标题，改为中文字段标签和方法说明
- ✅ 为浮字预制体、对象池容量和最小播放间隔补充中文 `LabelText` / `Tooltip`
- ✅ 为对象池容量和最小播放间隔补充 `Min` 约束
- ✅ 为浮字排队结构字段补充中文说明
- ✅ 将对象池耗尽和预制体配置错误日志改为中文
- ✅ 补充对象池预热、排队播放、租用实例和入队入口的中文合同说明

**质量检查**：
- ✅ `git diff --check` 通过（Git 仅提示 LF/CRLF 自动转换）
- ✅ 第 19 批 3 个目标脚本无 UTF-8 BOM，并保留末尾换行
- ✅ 第 19 批 3 个目标脚本未发现旧 `InspectorName`、英文 `Header` 或 `Tools/` 菜单路径
- ✅ `[SerializeField]` / 字段级 `LabelText` 覆盖关系已核对：9/9、18/18、3/3
- ✅ `Assets/Plugins`、`ReferenceSources`、`EX_GAS_Config/ProjectConfigTable/Tools`、`Packages` 无本轮 diff
- ⚠️ 本轮未启动 Unity Editor 编译；改动以注释、Inspector 文案、中文日志和编码整理为主

**详细总结**：`.spec/tasks/code-documentation-batch-19-summary.md`

---

### 批次 20：HUD 能力栏与状态效果条（2026-07-21）

#### 59. 通用技能图标基类
**文件**：`Assets/Scripts/GameCore/Runtime/UI/Generic/UIAbility.cs`

**改进内容**：
- ✅ 补充 `using Sirenix.OdinInspector;`
- ✅ 移除英文 `Header("References")`
- ✅ 为技能图标字段补充中文 `LabelText` / `Tooltip`
- ✅ 补充类级说明和 `SetAbility` 的中文合同说明
- ✅ 去除文件 UTF-8 BOM，并保留末尾换行

#### 60. HUD 技能栏
**文件**：`Assets/Scripts/GameCore/Runtime/UI/HUD/Abilities/UIHUDAbilityBar.cs`

**改进内容**：
- ✅ 补充类级说明，明确它只展示当前控制角色的装备技能槽，不处理输入或释放判断
- ✅ 补充生命周期、条目初始化、当前控制角色监听、角色绑定和技能槽刷新的中文合同说明
- ✅ 用中文 `#region` 收束生命周期、条目与角色绑定两个职责块
- ✅ 保持原技能栏绑定和刷新逻辑不变

#### 61. HUD 技能栏条目
**文件**：`Assets/Scripts/GameCore/Runtime/UI/HUD/Abilities/UIHUDAbilityBarEntry.cs`

**改进内容**：
- ✅ 补充 `using Sirenix.OdinInspector;`
- ✅ 移除英文 `Header("References")`
- ✅ 为控制器按钮提示、冷却滑条和冷却文本补充中文 `LabelText` / `Tooltip`
- ✅ 补充技能槽绑定、角色绑定、每帧冷却刷新和清空冷却显示的中文合同说明

#### 62. HUD 技能失败提示面板
**文件**：`Assets/Scripts/GameCore/Runtime/UI/HUD/Abilities/UIHUDAbilityMessage.cs`

**改进内容**：
- ✅ 补充 `using Sirenix.OdinInspector;`
- ✅ 去除文件 UTF-8 BOM
- ✅ 移除英文 Header，并为提示文本、淡出参数和技能失败文案字典补充中文 `LabelText` / `Tooltip`
- ✅ 将本地命令失败的硬编码英文提示改为中文短提示
- ✅ 补充生命周期、失败原因解析、显示/淡出协程的中文合同说明
- ✅ 用中文 `#region` 收束 Inspector 配置、生命周期、失败原因解析、显示与淡出四个职责块

#### 63. HUD 状态效果条
**文件**：`Assets/Scripts/GameCore/Runtime/UI/HUD/Effects/UIHUDEffectBar.cs`

**改进内容**：
- ✅ 补充 `using Sirenix.OdinInspector;`
- ✅ 将英文 `Header("References")` / `Header("Settings")` 改为中文分组 `Header("状态图标配置")`
- ✅ 为图标根节点、图标预制体、目标角色和图标池容量补充中文 `LabelText` / `Tooltip`
- ✅ 为图标池容量补充 `Min(0)` 约束
- ✅ 补充生命周期、角色绑定、持续效果图标租用/归还和对象池配置的中文合同说明
- ✅ 用中文 `#region` 收束 Inspector 配置、生命周期、角色绑定、图标对象池四个职责块

**质量检查**：
- ✅ `git diff --check` 通过（Git 仅提示 LF/CRLF 自动转换）
- ✅ 第 20 批 5 个目标脚本无 UTF-8 BOM，并保留末尾换行
- ✅ 第 20 批 5 个目标脚本未发现旧 `InspectorName`、英文 `Header` 或 `Tools/` 菜单路径
- ✅ `[SerializeField]` / 字段级 `LabelText` 覆盖关系已核对：1/1、0/0、3/3、4/4、4/4
- ✅ `Assets/Plugins`、`ReferenceSources`、`EX_GAS_Config/ProjectConfigTable/Tools`、`Packages` 无本轮 diff
- ⚠️ 本轮未启动 Unity Editor 编译；改动以注释、Inspector 文案、本地提示中文化和编码整理为主

**详细总结**：`.spec/tasks/code-documentation-batch-20-summary.md`

---

### 批次 21：对话 HUD 闭包（2026-07-21）

#### 64. 对话 HUD 回调合同
**文件**：`Assets/Scripts/GameCore/Runtime/UI/HUD/Dialogue/IDialogueHudEventReceiver.cs`

**改进内容**：
- ✅ 为消息框跳字完成和选项点击回调补充中文合同说明
- ✅ 明确该接口只服务 `UIDialogue` 闭包

#### 65. 对话 HUD 主控
**文件**：`Assets/Scripts/GameCore/Runtime/UI/HUD/Dialogue/UIDialogue.cs`

**改进内容**：
- ✅ 补充 `using Sirenix.OdinInspector;`
- ✅ 为交互遮挡层、消息框和选项框补充中文 `LabelText` / `Tooltip`
- ✅ 补充生命周期、对话状态同步、跳过输入、运行时接入和游戏状态层管理的中文合同说明
- ✅ 用中文 `#region` 收束六个职责块

#### 66. 对话选项框
**文件**：`Assets/Scripts/GameCore/Runtime/UI/HUD/Dialogue/UIDialogueChoiceBox.cs`

**改进内容**：
- ✅ 补充 `using Sirenix.OdinInspector;`
- ✅ 为选项按钮数组补充中文 `LabelText` / `Tooltip`
- ✅ 补充选项写入、选项名提取、默认焦点和显隐入口的中文合同说明
- ✅ 去除文件 UTF-8 BOM，并保留末尾换行

#### 67. 对话选项按钮
**文件**：`Assets/Scripts/GameCore/Runtime/UI/HUD/Dialogue/UIDialogueOption.cs`

**改进内容**：
- ✅ 补充 `using Sirenix.OdinInspector;`
- ✅ 为选项文本和选项序号补充中文 `LabelText` / `Tooltip`
- ✅ 补充按钮缓存、父级回调接收者、点击分发、显隐和文本刷新的中文合同说明
- ✅ 修正方法之间缺少空行的问题

#### 68. 说话人名称框
**文件**：`Assets/Scripts/GameCore/Runtime/UI/HUD/Dialogue/UIDialogueSpeakerBox.cs`

**改进内容**：
- ✅ 补充 `using Sirenix.OdinInspector;`
- ✅ 为说话人文本补充中文 `LabelText` / `Tooltip`
- ✅ 补充空说话人自动隐藏、显隐入口和文本刷新的中文合同说明
- ✅ 去除文件 UTF-8 BOM，并保留末尾换行

#### 69. 对话消息框
**文件**：`Assets/Scripts/GameCore/Runtime/UI/HUD/Dialogue/UIDialogueMessageBox.cs`

**改进内容**：
- ✅ 补充 `using Sirenix.OdinInspector;`
- ✅ 将英文 Header 收口为中文分组 `Header("消息框表现")`
- ✅ 为显隐动画参数、跳字音效、正文文本、说话人框和继续箭头补充中文 `LabelText` / `Tooltip`
- ✅ 补充生命周期、显隐入口、正文跳字、跳过文本、动画参数写入和协程终止的中文合同说明
- ✅ 用中文 `#region` 收束 Inspector 配置、生命周期、显隐与文本入口、跳字动画四个职责块
- ✅ 去除文件 UTF-8 BOM，并保留末尾换行

**质量检查**：
- ✅ `git diff --check` 通过（Git 仅提示 LF/CRLF 自动转换）
- ✅ 第 21 批 6 个目标脚本无 UTF-8 BOM，并保留末尾换行
- ✅ 第 21 批 6 个目标脚本未发现旧 `InspectorName`、英文 `Header` 或 `Tools/` 菜单路径
- ✅ `[SerializeField]` / 字段级 `LabelText` 覆盖关系已核对：0/0、3/3、1/1、2/2、1/1、5/5
- ✅ `Assets/Plugins`、`ReferenceSources`、`EX_GAS_Config/ProjectConfigTable/Tools`、`Packages` 无本轮 diff
- ⚠️ 本轮未启动 Unity Editor 编译；改动以注释、Inspector 文案和编码整理为主

**详细总结**：`.spec/tasks/code-documentation-batch-21-summary.md`

---

### 批次 22：事件日志与物品详情 HUD（2026-07-21）

#### 70. HUD 事件日志面板
**文件**：`Assets/Scripts/GameCore/Runtime/UI/HUD/EventLog/UIEventLog.cs`

**改进内容**：
- ✅ 补充 `using Sirenix.OdinInspector;`
- ✅ 将 `UIEventSettings` 里的旧 `InspectorName` 更新为 Odin `LabelText`
- ✅ 为全局参数、事件日志模板和物品转移类型过滤配置补充中文 `LabelText` / `Tooltip`
- ✅ 为日志时长、单字打字时长和日志行池大小补充 `Min` 约束
- ✅ 补充对象池缓存、生命周期、事件过滤、角色名兜底、日志格式化和对象池归还的中文合同说明
- ✅ 将英文对象池错误日志改为中文
- ✅ 用中文 `#region` 收束 Inspector 配置、生命周期、事件处理、日志输出与对象池四个职责块

#### 71. HUD 事件日志行
**文件**：`Assets/Scripts/GameCore/Runtime/UI/HUD/EventLog/UIEventLogLine.cs`

**改进内容**：
- ✅ 补充 `using Sirenix.OdinInspector;`
- ✅ 为日志文本字段补充中文 `LabelText` / `Tooltip`
- ✅ 移除英文注释小标题 `Inspector Settings` / `Private Members`
- ✅ 将英文行内注释改为中文，说明最新日志重新挂到父级末尾的原因
- ✅ 补充类级、生命周期、显示入口、逐字播放、协程停止和对象池复用清理的中文合同说明
- ✅ 去除文件 UTF-8 BOM，并保留末尾换行

#### 72. HUD 物品详情浮层
**文件**：`Assets/Scripts/GameCore/Runtime/UI/HUD/ItemDetails/UIItemDetails.cs`

**改进内容**：
- ✅ 补充 `using Sirenix.OdinInspector;`
- ✅ 将英文 `Header("References")` 改为中文 `Header("详情框引用")`
- ✅ 为详情框根节点、图标、名称文本和说明文本补充中文 `LabelText` / `Tooltip`
- ✅ 补充类级、生命周期、事件监听、物品详情写入、装备属性追加和关闭入口的中文合同说明
- ✅ 说明装备属性追加使用不换行空格，避免数值和属性短名被自动换行拆开
- ✅ 去除文件 UTF-8 BOM，并保留末尾换行

**质量检查**：
- ✅ `git diff --check` 通过（Git 仅提示 LF/CRLF 自动转换）
- ✅ 第 22 批 3 个目标脚本无 UTF-8 BOM，并保留末尾换行
- ✅ 第 22 批 3 个目标脚本未发现旧 `InspectorName`、英文 `Header`、英文注释小标题或 `Tools/` 菜单路径
- ✅ `[SerializeField]` / 字段级 `LabelText` 覆盖关系已核对：16/19（含 `UIEventSettings` 3 个公开字段）、1/1、4/4
- ✅ `Assets/Plugins`、`ReferenceSources`、`EX_GAS_Config/ProjectConfigTable/Tools`、`Packages` 无本轮 diff
- ⚠️ 本轮未启动 Unity Editor 编译；改动以注释、Inspector 文案、中文日志和编码整理为主

**详细总结**：`.spec/tasks/code-documentation-batch-22-summary.md`

---

### 批次 23：背包菜单入口与分类 UI（2026-07-21）

#### 73. 背包菜单主面板
**文件**：`Assets/Scripts/GameCore/Runtime/UI/Menus/Inventory/UIInventory.cs`

**改进内容**：
- ✅ 补充 `using Sirenix.OdinInspector;`
- ✅ 为装备栏面板、背包格子面板和属性摘要面板补充中文 `LabelText` / `Tooltip`
- ✅ 补充类级说明，明确它负责协调装备栏、背包格子和属性摘要，不直接持有背包数据
- ✅ 补充面板初始化、打开参数解析、显示/隐藏、默认焦点、UI 刷新、物品点击、异步转移反馈和当前控制角色监听的中文合同说明
- ✅ 将物品转移失败的英文日志改为中文
- ✅ 用中文 `#region` 收束六个职责块
- ✅ 去除文件 UTF-8 BOM，并保留末尾换行

#### 74. 背包物品格面板
**文件**：`Assets/Scripts/GameCore/Runtime/UI/Menus/Inventory/UIInventoryBag.cs`

**改进内容**：
- ✅ 补充 `using Sirenix.OdinInspector;`
- ✅ 移除单字段英文 `Header("References")`
- ✅ 为分类按钮表补充中文 `LabelText` / `Tooltip`
- ✅ 补充类级说明，明确它只从 `InventorySystem` 读取当前 owner 条目，不拥有背包数据
- ✅ 补充格子缓存、当前分类、当前 owner、初始化反转显示顺序、分类重置、格子刷新、清空、填充、导航目标和分类切换的中文合同说明
- ✅ 将格子不足和分类缺失的英文警告改为中文
- ✅ 用中文 `#region` 收束初始化与显隐、格子刷新、导航与分类三个职责块
- ✅ 去除文件 UTF-8 BOM，并保留末尾换行

#### 75. 背包分类按钮
**文件**：`Assets/Scripts/GameCore/Runtime/UI/Menus/Inventory/UIInventoryBagCategory.cs`

**改进内容**：
- ✅ 补充 `using Sirenix.OdinInspector;`
- ✅ 移除两字段英文 `Header("Settings")`，保留三引用字段的中文 `Header("分类按钮引用")`
- ✅ 为选中背景、未选中背景、按钮、分类图标和分类文本补充中文 `LabelText` / `Tooltip`
- ✅ 补充类级、父级缓存、分类写入、高亮切换和点击回调的中文合同说明
- ✅ 将父级缺失断言文案改为中文
- ✅ 去除文件 UTF-8 BOM，并保留末尾换行

**质量检查**：
- ✅ `git diff --check` 通过（Git 仅提示 LF/CRLF 自动转换）
- ✅ 第 23 批 3 个目标脚本无 UTF-8 BOM，并保留末尾换行
- ✅ 第 23 批 3 个目标脚本未发现旧 `InspectorName`、英文 `Header`、英文注释小标题或旧英文日志/断言文案
- ✅ `[SerializeField]` / 字段级 `LabelText` 覆盖关系已核对：3/3、1/1、5/5
- ✅ `Assets/Plugins`、`ReferenceSources`、`EX_GAS_Config/ProjectConfigTable/Tools`、`Packages` 无本轮 diff
- ⚠️ 本轮未启动 Unity Editor 编译；改动以注释、Inspector 文案、中文日志/断言和编码整理为主

**详细总结**：`.spec/tasks/code-documentation-batch-23-summary.md`

---

### 批次 24：背包格、装备栏与属性摘要 UI（2026-07-21）

#### 76. 背包物品格
**文件**：`Assets/Scripts/GameCore/Runtime/UI/Menus/Inventory/UIInventoryBagSlot.cs`

**改进内容**：
- ✅ 补充 `using Sirenix.OdinInspector;`
- ✅ 为物品图标、数量文本和格子按钮补充中文 `LabelText` / `Tooltip`
- ✅ 补充类级说明，明确它只保存当前格子的展示物品，不拥有背包数据
- ✅ 补充清空、读取物品、写入物品、选中/失焦、鼠标悬停、按钮点击和导航 Selectable 的中文合同说明
- ✅ 将父级点击处理器缺失断言文案改为中文
- ✅ 用中文 `#region` 收束 Inspector 配置、格子内容、选择与详情、生命周期与点击四个职责块

#### 77. 背包装备栏面板
**文件**：`Assets/Scripts/GameCore/Runtime/UI/Menus/Inventory/UIInventoryEquipment.cs`

**改进内容**：
- ✅ 补充 `using Sirenix.OdinInspector;`
- ✅ 为装备格列表补充中文 `LabelText` / `Tooltip`
- ✅ 补充类级说明，明确装备数据仍由 `InventorySystem` 和 `CharacterEquipment` 持有，本组件只做 UI 展示和导航入口
- ✅ 补充按角色刷新、按装备组件刷新和默认导航目标的中文合同说明
- ✅ 去除文件 UTF-8 BOM，并保留末尾换行

#### 78. 背包装备格
**文件**：`Assets/Scripts/GameCore/Runtime/UI/Menus/Inventory/UIInventoryEquipmentSlot.cs`

**改进内容**：
- ✅ 补充 `using Sirenix.OdinInspector;`
- ✅ 为装备槽类型、空槽占位图、装备图标和格子按钮补充中文 `LabelText` / `Tooltip`
- ✅ 补充类级说明，明确点击交给父级 `UIInventory`，本组件只负责装备格表现和详情浮层事件
- ✅ 补充鼠标悬停、选中/失焦、装备写入、类型校验、父级缓存、销毁退订和点击入口的中文合同说明
- ✅ 将装备类型错位断言、父级背包菜单缺失断言文案改为中文
- ✅ 用中文 `#region` 收束选择与详情、装备显示、生命周期与点击三个职责块

#### 79. 背包属性摘要面板
**文件**：`Assets/Scripts/GameCore/Runtime/UI/Menus/Inventory/UIInventoryStats.cs`

**改进内容**：
- ✅ 补充 `using Sirenix.OdinInspector;`
- ✅ 移除单字段英文 `Header("References")`
- ✅ 为属性行列表补充中文 `LabelText` / `Tooltip`
- ✅ 补充类级说明，明确具体属性文本和数值格式由 `UIStat` 负责，本组件只维护目标角色绑定
- ✅ 补充重新启用、启动刷新和目标转发的中文合同说明
- ✅ 去除文件 UTF-8 BOM，并保留末尾换行

**质量检查**：
- ✅ `git diff --check` 通过（Git 仅提示 LF/CRLF 自动转换）
- ✅ 第 24 批 4 个目标脚本无 UTF-8 BOM，并保留末尾换行
- ✅ 第 24 批 4 个目标脚本未发现旧 `InspectorName`、英文 `Header`、英文注释小标题或旧英文断言文案
- ✅ `[SerializeField]` / 字段级 `LabelText` 覆盖关系已核对：3/3、1/1、4/4、1/1
- ✅ `Assets/Plugins`、`ReferenceSources`、`EX_GAS_Config/ProjectConfigTable/Tools`、`Packages` 无本轮 diff
- ⚠️ 本轮未启动 Unity Editor 编译；改动以注释、Inspector 文案、中文断言和编码整理为主

**详细总结**：`.spec/tasks/code-documentation-batch-24-summary.md`

---

### 批次 25：角色菜单 UI（2026-07-21）

#### 80. 通用属性数值行
**文件**：`Assets/Scripts/GameCore/Runtime/UI/Generic/UIStat.cs`

**改进内容**：
- ✅ 补充 `using Sirenix.OdinInspector;`
- ✅ 移除两处单字段英文 `Header("References")` / `Header("Settings")`
- ✅ 为数值文本和属性类型补充中文 `LabelText` / `Tooltip`
- ✅ 补充类级、属性入口、正式属性定义解析、目标角色刷新和数值写入的中文合同说明
- ✅ 去除文件 UTF-8 BOM，并保留末尾换行

#### 81. 角色菜单上下文
**文件**：`Assets/Scripts/GameCore/Runtime/UI/Menus/Character/CharacterMenuContext.cs`

**改进内容**：
- ✅ 补充类级说明，明确它只保存查看目标，不持有角色状态，也不直接刷新 UI
- ✅ 补充固定角色、跟随当前控制角色、默认上下文和指定角色上下文的中文说明
- ✅ 补充角色解析入口的边界说明：固定目标优先，否则从玩家系统解析当前控制角色
- ✅ 去除文件 UTF-8 BOM，并保留末尾换行

#### 82. 角色菜单主面板
**文件**：`Assets/Scripts/GameCore/Runtime/UI/Menus/Character/UICharacter.cs`

**改进内容**：
- ✅ 补充 `using Sirenix.OdinInspector;`
- ✅ 将英文 `Header("References")` 改为中文分组 `Header("角色面板引用")`
- ✅ 为职业、等级、经验、自由属性点、货币、属性行列表和应用按钮文本补充中文 `LabelText` / `Tooltip`
- ✅ 补充类级说明，明确本面板只维护本次打开期间的临时加点，真正写回必须通过 `Apply`
- ✅ 补充面板生命周期、临时加点、撤回、应用写回、当前控制角色监听、角色绑定和上下文解析的中文合同说明
- ✅ 将应用按钮英文文案 `Apply {n} points` 改为中文 `应用 {n} 点`
- ✅ 用中文 `#region` 收束六个职责块

#### 83. 角色属性加点行
**文件**：`Assets/Scripts/GameCore/Runtime/UI/Menus/Character/UICharacterStat.cs`

**改进内容**：
- ✅ 补充 `using Sirenix.OdinInspector;`
- ✅ 移除两字段英文 `Header("References")`，只保留字段自己的中文 `LabelText` / `Tooltip`
- ✅ 为减少按钮和增加按钮补充中文 `LabelText` / `Tooltip`
- ✅ 补充类级、回调登记、回调移除、临时点数显示和默认焦点入口的中文合同说明

**质量检查**：
- ✅ `git diff --check` 通过（Git 仅提示 LF/CRLF 自动转换）
- ✅ `node .spec/tools/spec-lint.mjs` 通过
- ✅ 第 25 批 4 个目标脚本和 2 份任务文档通过自定义尾随空白检查
- ✅ 第 25 批 4 个目标脚本和 2 份任务文档无 UTF-8 BOM，并保留末尾换行
- ✅ 第 25 批 4 个目标脚本未发现旧 `InspectorName`、英文 `Header`、英文注释小标题、`Tools/` 菜单路径或旧英文应用按钮文案
- ✅ `[SerializeField]` / 字段级 `LabelText` 覆盖关系已核对：2/2、0/0、7/7、2/2
- ✅ `Assets/Plugins`、`ReferenceSources`、`EX_GAS_Config/ProjectConfigTable/Tools`、`Packages` 无本轮 diff
- ⚠️ 本轮未启动 Unity Editor 编译；改动以注释、Inspector 文案、中文 UI 文案和编码整理为主

**详细总结**：`.spec/tasks/code-documentation-batch-25-summary.md`

---

## 📋 注释质量标准（已确立）

### 详细但有层次
- **类级**：职责、设计说明、关键状态、注意事项
- **方法级**：职责、参数、返回值、流程步骤
- **行内**：关键决策点、为什么这样做、边界条件

### 说明"为什么"而不是"是什么"
```csharp
// ❌ 差：设置速度为 5
speed = 5;

// ✅ 好：保持与旧版本兼容，默认速度必须为 5
speed = 5;

// ✅ 好：Unity Sprite 的 Y 坐标原点在左下角，需要转换为从上往下的行索引
int row = (textureHeight - sprite.rect.y - sprite.rect.height) / frameHeight;
```

### 帮助理解英文 API 和业务逻辑
```csharp
// 遍历四个方向（SE、SW、NE、NW）
for (int direction = 0; direction < CharacterAnimationDirections.Count; direction++)

// 优先使用作者在编辑器中手动指定的帧序列
if (animation.frames != null && animation.frames.Count > 0)
```

### 复杂流程分步说明
```csharp
/// <summary>
/// 杀死角色
/// 执行完整的死亡流程：
/// 1. 播放死亡反馈效果
/// 2. 通知游戏事件系统
/// 3. 转移背包物品到尸体所有者
/// 4. 调用基类 Kill（播放死亡动画等）
/// 5. 转移装备到尸体所有者
/// 6. 通知玩家系统
/// 7. 清除 Buff/Debuff
/// 8. 打断正在执行的技能
/// </summary>
```

---

## 🎯 下一步建议

### 优先级排序（按重要性）

#### 高优先级：核心运行时组件
1. **角色系统剩余**
   - 角色系统核心本轮已基本收口，后续只按发现的漏项补丁处理

2. **战斗系统**
   - `CombatSolver` / `Temporal*Effect` / 正式输入门控本轮已推进
   - `Gas2DTargetCatchers`、TargetCatcher、EX-GAS 项目侧扩展暂缓，等用户明确纳入范围后再处理

#### 中优先级：表现层组件
3. **装备系统表现层剩余**
   - `EquipmentRenderer.cs` 已完成
   - `UISystem`、`UIMovementIndicator`、`UICharacterInfo`、`UIMainMenu`、`UIGameMenu`、`UIGameMenuEntry`、`UISettings`、`UISettingsVolume`、`UISettingsMasterVolume`、`UISettingsChannelVolume` 已完成
   - 下一步可继续其他 HUD/Menu 小文件，或把 `EquipmentWorkbenchRuntimeUI.cs` 作为单独大文件批次处理
   - 第三方插件、渲染 Feature、参考工程和生成物暂时不纳入范围

4. **元素反应系统**
   - 元素类型定义
   - 反应规则计算
   - 效果表现

5. **水面倒影系统**
   - 倒影算法
   - 性能优化参数

#### 低优先级：UI 和工具
6. **UI 系统**
   - HUD 组件
   - 菜单系统
   - 对话框

7. **编辑器工具剩余**
   - 其他装备系统编辑器工具（可选，只需简要注释）

---

## 📚 参考文档

### 已创建的总结文档
- `.spec/tasks/code-documentation-improvement-plan.md`（总计划）
- `.spec/tasks/code-documentation-batch-1-summary.md`（批次 1 详细总结）
- `.spec/tasks/code-documentation-batch-2-summary.md`（批次 2 详细总结）
- `.spec/tasks/code-documentation-batch-3-summary.md`（批次 3 详细总结）
- `.spec/tasks/code-documentation-batch-4-summary.md`（批次 4 详细总结）
- `.spec/tasks/code-documentation-batch-5-summary.md`（批次 5 详细总结）
- `.spec/tasks/code-documentation-batch-6-summary.md`（批次 6 详细总结）
- `.spec/tasks/code-documentation-batch-7-summary.md`（批次 7 详细总结）
- `.spec/tasks/code-documentation-batch-8-summary.md`（批次 8 详细总结）
- `.spec/tasks/code-documentation-batch-9-summary.md`（批次 9 详细总结）
- `.spec/tasks/code-documentation-batch-10-summary.md`（批次 10 详细总结）
- `.spec/tasks/code-documentation-batch-11-summary.md`（批次 11 详细总结）
- `.spec/tasks/code-documentation-batch-12-summary.md`（批次 12 详细总结）
- `.spec/tasks/code-documentation-batch-13-summary.md`（批次 13 详细总结）
- `.spec/tasks/code-documentation-batch-14-summary.md`（批次 14 详细总结）
- `.spec/tasks/code-documentation-batch-15-summary.md`（批次 15 详细总结）
- `.spec/tasks/code-documentation-batch-16-summary.md`（批次 16 详细总结）
- `.spec/tasks/code-documentation-batch-17-summary.md`（批次 17 详细总结）
- `.spec/tasks/code-documentation-batch-18-summary.md`（批次 18 详细总结）
- `.spec/tasks/code-documentation-batch-19-summary.md`（批次 19 详细总结）
- `.spec/tasks/code-documentation-batch-20-summary.md`（批次 20 详细总结）
- `.spec/tasks/code-documentation-batch-21-summary.md`（批次 21 详细总结）
- `.spec/tasks/code-documentation-batch-22-summary.md`（批次 22 详细总结）
- `.spec/tasks/code-documentation-batch-23-summary.md`（批次 23 详细总结）
- `.spec/tasks/code-documentation-batch-24-summary.md`（批次 24 详细总结）
- `.spec/tasks/code-documentation-batch-25-summary.md`（批次 25 详细总结）
- `.spec/tasks/code-documentation-progress-summary.md`（本文档）

### 规范文档
- `.spec/knowledge/standards/code-style.md`（代码风格规范，含注释标准）
- `.spec/AGENTS.md`（AI 规范入口）
- `.spec/rules/system.md`（硬红线规则）

---

## 💡 继续工作的建议

### 开始新会话时
1. 告诉 AI："继续代码注释补充工作，从 `.spec/tasks/code-documentation-progress-summary.md` 继续"
2. 明确范围："只处理项目侧代码，第三方插件、参考工程和生成物暂不纳入范围"
3. 指定文件（可选）："继续其他 HUD/Menu 小文件，或把 `EquipmentWorkbenchRuntimeUI.cs` 单独作为大文件批次处理"

### 保持注释质量
- 参考 `CharacterBase.cs` 的注释风格（已完成）
- 核心运行时组件：详细注释
- 编辑器工具：简要注释
- 保持"详细但不冗余"的平衡

### 批次大小建议
- 每批次 2-3 个文件
- 优先完成一个模块再切换到下一个
- 每批次结束后创建总结文档

---

## ✅ 当前状态（可直接继续）

- **规范已复核**：Odin Inspector、MenuItem 中文化、注释标准和 `#region` 折叠区块规则已明确；1-2 个字段不再单独加 Header/Group
- **核心角色组件已推进**：CharacterBase 主体、Abilities、Resources、StateApi、Persistence、ActionStateRuntime、TemporalEffectRuntime、Alterations、AbilitySetRuntime、AttributeBootstrapBuffer、Contracts，以及 CharacterActor、CharacterAbilitySet、CharacterPlayerControl、CharacterInventory、CharacterEquipment、CharacterMovement、CharacterButtonActivation、CharacterHandleWeapon、CharacterCommandExecutor、CharacterAlterationRule、AIController 已完成本轮注释补充
- **命令合同已推进**：PlayerCommandRequest、PlayerOrderRequest 已完成本轮注释补充
- **表现层已推进**：CharacterEquipmentPresentation、CharacterActionAnimatorDriver、DirectionalSpriteLibraryDriver、MountedCharacterPresentation、EquipmentRenderer 已完成本轮注释与 Inspector 中文化
- **UI 小文件已推进**：UISystem、UIMovementIndicator、UICharacterInfo、UIMainMenu、UIGameMenu、UIGameMenuEntry、UISettings、UISettingsVolume、UISettingsMasterVolume、UISettingsChannelVolume、UIEffectDescription、UIEffectIcon、UIEffectList、UIEffectListEntry、UIStatBar、CombatTextDisplay、FloatingTextPool、UIAbility、UIHUDAbilityBar、UIHUDAbilityBarEntry、UIHUDAbilityMessage、UIHUDEffectBar、UIDialogue、UIDialogueChoiceBox、UIDialogueOption、UIDialogueSpeakerBox、UIDialogueMessageBox、UIEventLog、UIEventLogLine、UIItemDetails、UIInventory、UIInventoryBag、UIInventoryBagCategory、UIInventoryBagSlot、UIInventoryEquipment、UIInventoryEquipmentSlot、UIInventoryStats、UIStat、CharacterMenuContext、UICharacter、UICharacterStat 已完成本轮注释与 Inspector 中文化
- **注释风格已确立**：详细示例可参考已完成的文件
- **计划已更新**：Inventory 菜单核心小文件和 Character 菜单本批小文件已收口；下一批建议继续 Inventory 剩余接口/上下文小文件，或继续其他 HUD/Menu 残留文件；第三方插件、参考工程和生成物暂不纳入范围

**状态**：✅ 第二十五批已完成，可开始第二十六批

---

**最后更新**：2026-07-21
**完成批次**：25
**已完成文件**：90
**累计改进项**：约 2700+


