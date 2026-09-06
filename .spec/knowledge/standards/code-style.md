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
- 除专业术语、代码符号、API 名、命令、路径、唯一 ID、外部协议键和引用原文外，项目侧文档、任务卡、规范、注释、用户汇报和提交摘要使用中文，不用英文泛词或整句英文占位。
- Git 提交信息默认使用中文；Conventional Commits 的 type/scope 可保留英文，冒号后的摘要和正文用中文。
- 内部字段、日志标签、代码符号可以保留原名，但给用户解释前必须先说明现实含义。

## 注释

- 注释只写代码表达不了的约束、原因、边界和外部依赖。
- 不写“改了什么”的流水账注释；改动说明放在交付汇报或提交信息。
- 项目侧新增或改写注释必须使用中文；第三方源码、生成代码、外部协议/API 名称、稳定 ID 和引用原文可保留英文，但项目侧语义说明不能只写英文。
- 项目侧 C# 的公开/受保护/内部类型、ScriptableObject 配置、编辑器工具、验证入口、生命周期/协程/事件/物理/存档等非显然逻辑，必须补中文注释说明职责、契约和边界。
- Unity Inspector 暴露配置必须补中文 `InspectorName` / `Tooltip` / `Header`，说明这个值影响什么、由谁配置、错误配置会怎样；目标已经由 Odin Inspector 绘制，或字段所在文件已有 `Sirenix.OdinInspector` 依赖时，可使用 `LabelText` / `Tooltip` / `Header` 等 Odin 中文特性；不得引入未登记的 Inspector 辅助插件。
- 这里的“Inspector 暴露配置”包括 `[SerializeField]` 字段、会显示在 Inspector 的 `public` 字段、ScriptableObject 配置字段、编辑器窗口参数、验证工具参数和其它给内容作者直接调整的字段。
- 新增或改写暴露字段时，字段符号本身继续使用英文代码命名；至少用中文 `InspectorName` 或 Odin `LabelText` 表达字段现实含义。存在配置风险、单位、取值范围、引用 owner 或旧数据兼容影响时，必须同步写中文 `Tooltip`。有分组时使用中文 `Header`。
- NaughtyAttributes 当前没有正式落点，不得按可用依赖使用；若后续重新接入 NaughtyAttributes 或同类 Inspector 辅助插件，必须先登记插件落点，再使用其中文标签能力。
- 简单赋值、自说明字段和一眼能懂的私有方法不强行补注释，避免把代码翻译成中文。
- 需要新增或审查注释时，使用系统 skill `D:\codex-home\skills\code-comments\SKILL.md`。

## 命名

- `.spec` 目录和 skill 目录使用 kebab-case。
- GameCore 作为通用游戏框架时，运行时默认值、编辑器入口、作者菜单、存档目录、输入绑定 key、配置文件名和生成物默认名使用 `GameCore` 或职责名；不得使用当前 Unity 工程名、未来游戏名或来源工程名。当前工程名只允许出现在仓库路径、项目事实、迁移记录、验证记录等说明当前工作区的位置。
- FantasyWord 具体业务层统一使用 `Gameplay` 作为层名，新增业务代码优先落到 `Assets/Scripts/Gameplay/Runtime/<领域>` 和 `FantasyWord.Gameplay.<领域>`；历史拼写 `GamePlay` 不得新增。`Assets/Scripts/Gameplay/Runtime/Presentation/EquipmentSystem` 是当前正式换装表现业务路径。
- Gameplay 内部命名优先表达玩家可感知对象和生命周期，例如 `World`、`Characters`、`Factions`、`Economy`、`Items`、`Combat`、`Presentation`、`Modes`；`Solver`、`Resolver`、`Projector`、`Validator`、`Index` 只能作为父级对象的内部协作者，不能用这些技术名替代领域主结构。
- 项目侧正式玩法资产、素材文件、Prefab、ScriptableObject、Sprite Library、场景实例和正式测试场景入口优先中文命名；尤其是给策划、关卡、技能或表现作者直接选择的 SO 资产，文件名和 Inspector 显示名都应使用中文表达现实含义。
- `CreateAssetMenu` 的 `menuName`、`fileName` 等作者入口优先使用中文；只有稳定 ID、外部协议键、跨工具 ASCII 键或第三方来源名需要保留英文。
- C# 类名、结构体名、接口名、枚举名、方法名、字段符号、属性符号、事件符号和命名空间必须按项目现有英文符号风格保持稳定；中文通过 Inspector 特性、菜单名、资产名、注释和文档承载，不把运行时代码符号强行改成中文。
- 第三方原始目录、代码符号和兼容稳定 ID 保留原名，不为美观强行改。

## 集合查询与热路径

- 项目侧运行时热路径新增集合查询时，优先写清楚的无分配循环；不得在 `Update` / `LateUpdate` / `FixedUpdate`、战斗结算、路径 / 目标筛选、资源扫描缓存、批量生成 / 回收、列表高频刷新等位置新增普通 `System.Linq` 查询链。
- 非热路径运行时代码可以按可读性使用 `System.Linq`，但如果该路径会被频繁调用、进入大集合或出现在玩家可感知帧内流程，必须改成手写循环或项目正式引入的零分配集合工具。
- Editor 工具、一次性导入脚本、离线校验和测试代码可以按可读性使用 `System.Linq`，但不得把这类写法复制进运行时热路径。
- FantasyWord 当前未安装 `com.cysharp.zlinq`；CardLoop 的 ZLinq 规则只作为候选参考，不得在本项目代码里直接新增 `using ZLinq;` 或 `.AsValueEnumerable()`。若后续正式引入 ZLinq，必须先走 UPM 包落点和编译验证，再把本节升级为 ZLinq 项目规则。
- FantasyWord 当前也未安装 `com.cysharp.zstring`；项目侧代码不得新增 `Cysharp.Text.ZString` 依赖。热路径字符串拼接优先用 `StringBuilder` 或现有已验证工具入口，只有包声明、程序集引用和 Unity 编译都验证后，才能把 ZString 当成正式工具使用。
- 不启用任何 LINQ drop-in / source generator 作为默认策略；确需启用时必须先单独评估编译影响、第三方兼容和回退方案。

## 作者源身份与局部 key

- 内容唯一 ID 是存档、Mod、编辑器引用和未来联机迁移的正式身份；默认由作者源或正式编辑器工具生成，不把 Unity GUID、YooAsset 地址、资源路径、文件名或运行时实例号并列成第二套身份。
- Unity ScriptableObject 内容资产首次缺少内容 ID 时，应由正式作者工具或迁移脚本使用可读名称片段和稳定种子生成默认 ID；Unity GUID 只能作为生成种子或引用证据，不作为运行时内容 ID 对外暴露。
- 已生成内容 ID 不随文件改名、移动、YooAsset 地址变化自动更新。需要改 ID 时，必须按迁移处理所有引用、存档、测试内容和 Mod 依赖，不允许静默漂移。
- 动作槽位、随机分支、局部生成物索引、临时 UI 投影 key 等只在单个作者资产内部解释的 key，不属于策划业务字段。它们必须由所属资产、创建工具、校验器或编辑器下拉自动维护；Inspector 不得要求作者手打内部字符串。
- 如果一个局部引用可以由上下文唯一推导，作者源应允许省略并由正式提交入口明确解析；如果上下文不唯一，必须通过正式作者工具选择，不能猜测、兜底或默认第一项。
- 每次发现手填内部 key、重复配置、第二套身份或浅包装时，必须横向搜索同职责同类入口。证据明确的同类问题当轮一起删除或重构；暂不能动的必须写进对应模块的吸收 / 重构清单。

## 生成物

- 生成物不得手改；必须改生成源并重新生成。
- `.meta`、GUID、Unity 资源引用必须作为闭包处理，不得只移动或改主文件。

## Skill frontmatter

- 项目 `.spec/skills/<name>/SKILL.md` 只要求 `name` 和 `description`。
- description 必须写清触发场景，不把完整 SOP 堆在描述里。
- 详细做法放正文，相关细节放 references 或项目 docs。
