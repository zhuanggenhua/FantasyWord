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
- 不写"改了什么"的流水账注释；改动说明放在交付汇报或提交信息。
- 项目侧新增或改写注释必须使用中文；第三方源码、生成代码、外部协议/API 名称、稳定 ID 和引用原文可保留英文，但项目侧语义说明不能只写英文。

### 必须补注释的代码

以下类型的代码必须补充中文注释说明职责、契约和边界：

- **运行时核心组件**（重点）：游戏逻辑、角色控制、能力系统、战斗系统等运行时代码
- **ScriptableObject 配置类**：说明配置用途、配置者身份（策划/美术/程序）、错误配置的影响范围
- **公开 API 方法**：说明职责、参数约束、返回值语义、失败后果和副作用
- **复杂算法**：说明设计思路、边界条件、性能考虑和已知限制
- **生命周期方法**（`Awake`/`Start`/`OnEnable`/`Update` 等）：说明在什么时机做什么、依赖什么前提、对其他组件的影响
- **协程和异步方法**：说明执行时机、取消条件、异常处理
- **事件和回调**：说明触发时机、参数含义、调用顺序
- **物理和碰撞**：说明碰撞层、触发条件、预期行为
- **存档相关**：说明持久化字段、加载时机、版本兼容

**编辑器工具类**：只需补充类级注释、MenuItem 中文化和关键方法的简要说明，内部实现细节可省略（因为不常修改）

### Inspector 中文化规范（强制）

**当前项目已引入 Odin Inspector**，所有 Inspector 暴露配置必须使用中文标签。

#### 推荐用法（Odin Inspector）

```csharp
using Sirenix.OdinInspector;
using UnityEngine;

public class ExampleConfig : ScriptableObject
{
    [SerializeField, Min(1)]
    [LabelText("生命值上限"), Tooltip("角色的最大生命值，死亡时重置为此值")]
    private int maxHealth = 100;

    [SerializeField, Range(0f, 10f)]
    [LabelText("移动速度"), Tooltip("单位：米/秒")]
    private float moveSpeed = 5f;

    [SerializeField]
    [LabelText("可装备武器类型"), Tooltip("留空表示可装备所有类型")]
    private WeaponType[] allowedWeapons;

    [TitleGroup("战斗配置")]
    [SerializeField, Min(0)]
    [LabelText("基础攻击力")]
    private int baseAttack = 10;

    [TitleGroup("战斗配置")]
    [SerializeField, Min(0f)]
    [LabelText("攻击间隔秒数"), Tooltip("单位：秒，越小攻击越频繁")]
    private float attackIntervalSeconds = 0.8f;

    [TitleGroup("战斗配置")]
    [SerializeField]
    [LabelText("受击效果"), Tooltip("角色受到有效伤害时播放的表现效果")]
    private EffectConfig hitEffect;
}
```

#### 特性使用规则

- **字段命名**：字段符号本身继续使用英文代码命名（如 `maxHealth`、`moveSpeed`），保持代码可读性
- **必须使用 `LabelText`**：所有 `[SerializeField]`、`public` 暴露字段、ScriptableObject 配置字段都必须补 `[LabelText("中文名")]`
- **推荐使用 `Tooltip`**：存在配置风险、单位、取值范围、引用 owner 或旧数据兼容影响时，必须同步写中文 `[Tooltip("说明")]`
- **分组使用中文**：配置项较多，或者存在多个清晰职责块时，使用 `[TitleGroup("中文分组名")]`、`[BoxGroup]`、`[FoldoutGroup]` 等
- **避免小块过度分组**：只有 1-2 个字段时，优先使用字段自己的 `[LabelText]` 和 `[Tooltip]`；不要额外加 `[Header]` 或独立 Group。只有当该位置需要分隔后续 3 个以上同职责字段，或字段本身是下方多个配置块的语义入口时，才使用分组标题
- **兼容 Unity 内置特性**：`[Min]`、`[Range]`、`[Space]` 等 Unity 内置特性可以正常使用；`[Header]` 只用于明确的 Inspector 区块分隔，不用于 1-2 个字段的小块装饰

#### 特性顺序规则（重要）

当同时使用 Odin 特性和 Unity 内置约束特性（如 `Min`、`Range`）时，**约束特性必须写在前面**，`LabelText` 写在后面：

```csharp
// ✅ 正确：约束特性在前，LabelText 在后
[SerializeField, Min(0.5f)]
[LabelText("生成间距"), Tooltip("两株草之间的基础距离")]
private float spawnSpacing = 4f;

// ❌ 错误：LabelText 在前会导致 Min 约束失效
[LabelText("生成间距"), Tooltip("两株草之间的基础距离")]
[SerializeField, Min(0.5f)]  // ❌ Min 约束会失效
private float spawnSpacing = 4f;
```

**原因**：Unity PropertyDrawer 机制限制，自定义 PropertyDrawer 会接管字段绘制。将约束特性写在前面可以确保 Odin 在渲染时仍能正确处理 Unity 内置约束。

**注意**：`[Header]` 和 `[Space]` 是 `DecoratorDrawer`，不受上面“约束特性在前”的顺序限制；`[Header]` 是否该用仍按分组规则判断。

#### MenuItem 中文化规范（强制）

项目侧所有 `[MenuItem]` 必须使用中文菜单路径：

```csharp
// ✅ 正确
[MenuItem("工具/装备系统/重建 SpriteLibrary 动画框架")]
public static void Rebuild() { }

[MenuItem("工具/装备系统/创建动画生成设置")]
public static void CreateSettingsAsset() { }

[MenuItem("工具/装备系统/审计 Creatures 像素导入设置")]
public static void AuditCreaturesImportSettings() { }

// ❌ 错误：项目代码不应使用英文菜单
[MenuItem("Tools/Equipment System/Rebuild SpriteLibrary Animation Framework")]
public static void Rebuild() { }
```

**第三方插件例外**：`Assets/Plugins/` 下的第三方插件菜单可以保持英文，不强制修改。

#### Odin 常用特性参考

```csharp
// 分组
[TitleGroup("基础设置")]
[BoxGroup("高级选项")]
[FoldoutGroup("调试工具")]

// 条件显示
[ShowIf("@enableDebug")]
[HideIf("@!isActive")]

// 值选择
[ValueDropdown("GetWeaponOptions")]
[EnumToggleButtons]

// 按钮
[Button("重置为默认值")]
[InlineButton("Validate", "验证")]

// 列表
[ListDrawerSettings(ShowIndexLabels = true, ListElementLabelName = "名称")]

// 只读
[ReadOnly]
[DisableInPlayMode]

// 信息提示
[InfoBox("这是一个重要提示")]
[PropertyTooltip("详细说明")]
```

### #region 折叠区块规范

`#region` 是代码结构折叠标记，不替代 XML 文档注释、字段注释或关键逻辑注释。它主要用来让大文件更好导航，尤其适合装备编辑器、FrameData、渲染器、运行时 partial 或算法集中类。

#### 什么时候用

- 文件较大，或者一个类里有多个清晰职责块时使用，例如字段、初始化、公共入口、刷新链路、渲染辅助、编辑器绘制、数据保存/加载、算法辅助。
- 某一段包含 3 个以上同职责字段、方法或内部类型时，可以用一个中文 `#region` 收起来。
- 已经形成稳定职责边界的工具类或编辑器大文件，可以用 `#region` 帮助快速定位。

#### 怎么写

```csharp
#region 武器渲染辅助

/// <summary>配置旧预览路径使用的武器子 SpriteRenderer；正式运行图像仍由 Shader 武器参数决定。</summary>
void ConfigureWeaponPreviewRenderer(SpriteRenderer renderer) { }

/// <summary>启用或关闭 Shader 武器槽。关闭时同步清空贴图、锚点、旋转、深度和手部遮挡参数。</summary>
void SetWeaponShaderEnabled(int slot, bool enabled) { }

#endregion
```

#### 使用边界

- 区块名使用中文，必要时保留稳定英文术语，例如 `UV Map`、`Shader`、`Sprite Library`。
- 不给 1-2 个字段或 1 个普通方法单独套 `#region`；这种情况直接靠 `LabelText`、`Tooltip` 或方法注释说明。
- 不用 `#region` 遮住杂乱代码、临时 TODO、改动流水账或未收口逻辑。区块内部仍要有必要的职责和边界注释。
- 避免多层嵌套；通常只保留一层。编辑器超大文件确实需要二级分区时，先保证区块名清楚、成对收口。
- 第三方插件、参考工程和生成物不因本规范强制改 `#region`。

### 注释质量标准

**核心原则**：详细但不冗余，帮助团队成员（尤其是英语基础一般的成员）理解代码。

#### 何时需要注释

- ✅ **复杂业务逻辑**：算法思路、计算步骤、为什么这样设计
- ✅ **英文 API 解释**：说明 LINQ、Unity API、第三方库的作用
- ✅ **关键决策点**：为什么选择这个方案、有什么限制、注意事项
- ✅ **坐标转换/数学计算**：说明公式含义、坐标系原点、单位
- ✅ **边界条件**：什么情况下会提前退出、异常处理
- ❌ **自解释代码**：简单赋值、一眼能懂的逻辑不需要注释

#### 注释层次

```csharp
/// <summary>
/// 类/方法级注释：说明职责、参数、返回值
/// 用 XML 文档注释格式
/// </summary>
public class Example
{
    // 字段注释：简短说明用途和约束
    private int maxCount = 100;

    public void DoSomething()
    {
        // 关键步骤注释：说明这一段代码在做什么、为什么这样做
        // 帮助理解英文 API 和业务逻辑
        var items = collection
            .Where(x => x.IsActive)  // 只处理激活的项
            .OrderBy(x => x.Priority)  // 按优先级排序
            .ToList();
    }
}
```

#### 注释示例

**❌ 差的注释**（重复代码）：
```csharp
// 设置速度为 5
speed = 5;

// 遍历列表
foreach (var item in items) { }
```

**✅ 好的注释**（说明原因和意图）：
```csharp
// 保持与旧版本兼容，默认速度必须为 5
speed = 5;

// 提前退出：无效输入
if (data == null) return;

// Unity Sprite 的 Y 坐标原点在左下角，需要转换为从上往下的行索引
int row = (textureHeight - sprite.rect.y - sprite.rect.height) / frameHeight;

// 优先使用作者在编辑器中手动指定的帧序列
if (animation.frames != null && animation.frames.Count > 0) { }
```

#### 注释平衡原则

- **详细但有层次**：重要逻辑详细说明，简单代码保持简洁
- **帮助理解不只是翻译**：解释英文 API 的作用，说明业务意图
- **关键决策必须注释**：为什么这样设计、有什么技术限制
- **避免注释淹没代码**：保持代码本身的可读性

需要新增或审查注释时，使用全局 `D:\codex-home\skills\code-comments\SKILL.md`

## 命名

- `.spec` 目录和 skill 目录使用 kebab-case。
- 项目侧正式玩法资产、素材文件、Prefab、ScriptableObject、Sprite Library、场景实例和正式测试场景入口优先中文命名；尤其是给策划、关卡、技能或表现作者直接选择的 SO 资产，文件名和 Inspector 显示名都应使用中文表达现实含义。
- `CreateAssetMenu` 的 `menuName`、`fileName` 等作者入口优先使用中文；只有稳定 ID、外部协议键、跨工具 ASCII 键或第三方来源名需要保留英文。
- C# 类名、结构体名、接口名、枚举名、方法名、字段符号、属性符号、事件符号和命名空间必须按项目现有英文符号风格保持稳定；中文通过 Inspector 特性、菜单名、资产名、注释和文档承载，不把运行时代码符号强行改成中文。
- 第三方原始目录、代码符号和兼容稳定 ID 保留原名，不为美观强行改。

## 生成物

- 生成物不得手改；必须改生成源并重新生成。
- `.meta`、GUID、Unity 资源引用必须作为闭包处理，不得只移动或改主文件。

## Skill frontmatter

- 项目 `.spec/skills/<name>/SKILL.md` 只要求 `name` 和 `description`。
- description 必须写清触发场景，不把完整 SOP 堆在描述里。
- 详细做法放正文，相关细节放 references 或项目 docs。
