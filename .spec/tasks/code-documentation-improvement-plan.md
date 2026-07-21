---
name: code-documentation-improvement-plan
description: 代码注释与中文化系统性改进计划
metadata:
  type: task-plan
  status: 待执行
  created: 2026-07-20
---

# 代码注释与中文化系统性改进计划

## 目标

对 FantasyWord 项目的核心模块进行系统性的注释补充和 Inspector 中文化，提升代码可维护性和内容制作效率。

## 规范依据

- `.spec/knowledge/standards/code-style.md` - 代码风格规范
- 使用 Odin Inspector 的 `LabelText`、`Tooltip` 等特性进行中文化
- MenuItem 菜单统一使用中文路径

## 执行原则

1. **不影响运行时逻辑**：只添加注释和 Inspector 特性，不改变业务逻辑
2. **分模块渐进**：按模块分批执行，每个模块独立验证
3. **保持代码符号英文**：字段名、方法名保持英文，只中文化 Inspector 显示和注释
4. **特性顺序正确**：约束特性（`Min`/`Range`）在前，`LabelText` 在后

## 核心模块清单

### 阶段 1：装备系统（Equipment System）

**优先级**：🔴 高（当前已打开文件）

#### 文件列表

1. **编辑器工具**
   - `Assets/Scripts/Presentation/EquipmentSystem/Editor/Utilities/EquipmentWorkbenchAnimatorControllerTool.cs` ⭐当前文件
   - `Assets/Scripts/Presentation/EquipmentSystem/Editor/FrameDataEditor.cs`
   - `Assets/Scripts/Presentation/EquipmentSystem/Editor/EquipmentAnimSequenceEditor.cs`
   - `Assets/Scripts/Presentation/EquipmentSystem/Editor/BlackOutlineCleanupWindow.cs`
   - `Assets/Scripts/Presentation/EquipmentSystem/Editor/PixelSkinMapWindow.cs`
   - `Assets/Scripts/Presentation/EquipmentSystem/Editor/Utilities/MountSampleAssetGenerator.cs`
   - `Assets/Scripts/Presentation/EquipmentSystem/Editor/Utilities/MiniFantasyPixelImportTool.cs`
   - `Assets/Scripts/Presentation/EquipmentSystem/Editor/Utilities/MiniFantasyHumanoidFrameDataSyncTool.cs`

2. **运行时组件**
   - `Assets/Scripts/Presentation/EquipmentSystem/Runtime/` 下的核心脚本
   - 装备槽位、装备管理器、换装逻辑等

3. **配置资产**
   - `EquipmentSystemGenerationSettings.cs`
   - `EquipmentWorkbenchCatalog.cs`
   - 相关 ScriptableObject 配置类

#### 改进要点

- ✅ MenuItem 改为中文（如 `Tools/Equipment System/...` → `工具/装备系统/...`）
- ✅ 补充编辑器工具类注释（说明工具用途、操作对象、风险点）
- ✅ SerializeField 补充 `[LabelText]` 和 `[Tooltip]`
- ✅ 公开方法补充 XML 文档注释
- ✅ 复杂算法补充设计思路说明

### 阶段 2：角色能力系统（Character Ability System）

**优先级**：🔴 高（核心游戏逻辑）

#### 文件列表

1. **核心组件**
   - `Assets/Scripts/GameCore/Runtime/Entities/Characters/CharacterAbilitySet.cs` ⭐当前文件
   - `Assets/Scripts/GameCore/Runtime/Entities/Characters/CharacterBase.cs`
   - `Assets/Scripts/GameCore/Runtime/Entities/Characters/CharacterController.cs`

2. **能力相关**
   - GAS（Gameplay Ability System）集成代码
   - 技能激活、冷却、消耗相关逻辑

#### 改进要点

- ✅ 补充类级别注释（说明 CharacterAbilitySet 的职责和生命周期）
- ✅ 内部方法补充职责说明
- ✅ SerializeField 补充 `[LabelText]` 和 `[Tooltip]`
- ✅ 关键状态转换补充注释

### 阶段 3：元素反应系统（Elemental Reaction System）

**优先级**：🟡 中

#### 文件范围

- `Assets/Scripts/GameCore/Runtime/ElementalSystem/` 目录下所有文件
- 元素交互、反应规则、效果表现

#### 改进要点

- ✅ 元素类型枚举补充中文说明
- ✅ 反应规则配置 SO 补充 `[LabelText]`
- ✅ 反应计算逻辑补充算法说明
- ✅ MenuItem（如果有）改为中文

### 阶段 4：水面倒影系统（Water Reflection System）

**优先级**：🟡 中

#### 文件列表

- `Assets/Scripts/Presentation/WaterReflection/Runtime/` 下的运行时脚本
- `Assets/Scripts/Presentation/WaterReflection/Editor/` 下的编辑器工具
- `Assets/Scripts/Presentation/WaterReflection/Editor/ClickMoveTestWaterReflectionInstaller.cs`

#### 改进要点

- ✅ 倒影算法补充原理说明
- ✅ 性能优化相关参数补充说明
- ✅ 编辑器工具 MenuItem 改为中文
- ✅ SerializeField 补充 `[LabelText]`

### 阶段 5：UI 系统（UI System）

**优先级**：🟡 中

#### 文件范围

- `Assets/Scripts/Presentation/UI/` 目录
- HUD、菜单、对话框等 UI 组件

#### 改进要点

- ✅ UI 组件字段补充 `[LabelText]`（如"血条长度"、"淡入时间"等）
- ✅ UI 动画参数补充说明
- ✅ 布局规则补充注释

### 阶段 6：输入与控制（Input & Control）

**优先级**：🟢 低

#### 文件范围

- `Assets/Scripts/GameCore/Runtime/Input/` 目录
- 玩家输入处理、摄像机控制

#### 改进要点

- ✅ 输入映射补充说明
- ✅ 控制参数补充单位和范围说明

### 阶段 7：数据与配置（Data & Configuration）

**优先级**：🟢 低（自动生成代码除外）

#### 文件范围

- `Assets/Scripts/GameCore/Runtime/Database/` 目录
- ScriptableObject 配置类
- **排除**：`Assets/DataGenerated/` 下的自动生成代码（如 Luban）

#### 改进要点

- ✅ 配置 SO 补充 `[LabelText]` 和 `[Tooltip]`
- ✅ `[CreateAssetMenu]` 的 `menuName` 改为中文
- ✅ 配置字段补充取值范围和影响范围说明

## 执行检查清单

每个模块完成后需要检查：

### 代码质量检查

- [ ] 所有公开类型有类级别注释
- [ ] 所有公开方法有 XML 文档注释（`<summary>`、`<param>`、`<returns>`）
- [ ] 编辑器工具类有用途、操作对象、风险点说明
- [ ] 复杂算法有设计思路和边界条件说明
- [ ] SerializeField 有 `[LabelText]` 和必要的 `[Tooltip]`

### 中文化检查

- [ ] MenuItem 使用中文路径（项目代码，插件除外）
- [ ] SerializeField 使用 `[LabelText("中文名")]`
- [ ] Tooltip 使用中文说明
- [ ] CreateAssetMenu 的 menuName 使用中文

### 特性顺序检查

- [ ] 约束特性（`Min`/`Range`）在 `[SerializeField]` 行
- [ ] `[LabelText]` 在约束特性之后的独立行
- [ ] 没有"LabelText 在前导致约束失效"的情况

### 编译与运行检查

- [ ] 代码编译通过
- [ ] Unity Editor 无警告
- [ ] Inspector 显示正确
- [ ] MenuItem 菜单可正常访问

## 进度跟踪

| 阶段 | 模块 | 状态 | 完成时间 | 备注 |
|------|------|------|----------|------|
| 1 | 装备系统 | 🟡 进行中 | - | 已完成编辑器工具核心文件 + 表现层 |
| 2 | 角色能力系统 | 🟡 进行中 | - | 已完成 CharacterAbilitySet + CharacterBase |
| 3 | 元素反应系统 | ⚪ 待开始 | - | |
| 4 | 水面倒影系统 | ⚪ 待开始 | - | |
| 5 | UI 系统 | ⚪ 待开始 | - | |
| 6 | 输入与控制 | ⚪ 待开始 | - | |
| 7 | 数据与配置 | ⚪ 待开始 | - | |

### 批次完成情况

#### 第一批次（2026-07-20）
**已完成文件**：
1. ✅ `.spec/knowledge/standards/code-style.md`（规范文档）
2. ✅ `EquipmentWorkbenchAnimatorControllerTool.cs`（编辑器工具 - MenuItem 中文化 + 简要注释）
3. ✅ `CharacterAbilitySet.cs`（核心运行时组件 - 详细注释）

**改进统计**：约 50+ 处改进  
**详细总结**：见 `.spec/tasks/code-documentation-batch-1-summary.md`

#### 第二批次（2026-07-20）
**已完成文件**：
1. ✅ `CharacterBase.cs`（角色核心基类 - 完整注释：类级文档 + 20+ 字段 + 8 生命周期 + 15+ 方法）
2. ✅ `CharacterEquipmentPresentation.cs`（装备表现层 - 优化注释）

**改进统计**：约 50+ 处改进  
**详细总结**：见 `.spec/tasks/code-documentation-batch-2-summary.md`

#### 累计进度
- **文件数**：5
- **改进项**：约 130+ 处
- **核心类完成度**：CharacterBase（✅ 完整）、CharacterAbilitySet（✅ 完整）

## 注意事项

1. **不修改第三方代码**：`Assets/Plugins/` 下的第三方插件代码保持原样
2. **不修改自动生成代码**：`Assets/DataGenerated/` 下的 Luban 生成代码不添加注释
3. **保持向后兼容**：只添加特性和注释，不改变序列化字段名
4. **分批提交**：每完成一个模块提交一次，便于代码审查
5. **验证 Inspector**：每个模块完成后在 Unity Editor 中验证 Inspector 显示

## 参考示例

### 改进前

```csharp
public class EquipmentManager : MonoBehaviour
{
    [SerializeField] private int maxSlots = 10;
    [SerializeField, Range(0f, 1f)] private float equipSpeed = 0.5f;
    
    public void EquipItem(Item item) { }
}
```

### 改进后

```csharp
using Sirenix.OdinInspector;

/// <summary>
/// 装备管理器：负责角色装备的穿戴、卸下和槽位管理
/// </summary>
public class EquipmentManager : MonoBehaviour
{
    [LabelText("最大槽位数")]
    [Tooltip("角色可装备的最大装备数量，超过此数量无法继续装备")]
    [SerializeField, Min(1)]
    private int maxSlots = 10;
    
    [LabelText("装备速度"), Tooltip("装备动画播放速度，0.5 表示正常速度的一半")]
    [SerializeField, Range(0f, 1f)]
    private float equipSpeed = 0.5f;
    
    /// <summary>
    /// 装备物品到空闲槽位
    /// </summary>
    /// <param name="item">要装备的物品，必须是可装备类型</param>
    /// <returns>装备是否成功</returns>
    public bool EquipItem(Item item) 
    {
        // 实现...
        return true;
    }
}
```

## 下一步行动

1. ✅ 更新 `.spec/knowledge/standards/code-style.md` 规范文档
2. ⏭️ 开始阶段 1：补充装备系统的注释和中文化
3. ⏭️ 验证装备系统改进效果
4. ⏭️ 继续后续模块

---

**文档版本**：v1.0  
**最后更新**：2026-07-20  
**维护者**：AI Assistant
