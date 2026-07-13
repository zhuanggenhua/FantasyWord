# References: implement-element-reaction-foundation

## Evidence Policy

本文件区分四种证据：

- **项目需求**：证明为什么要做、必须达到什么现实结果。
- **当前项目源码**：证明现在有什么正式入口、缺什么、能从哪里扩展。
- **Unity 官方 API**：只证明引擎能力存在，不替项目决定领域架构。
- **外部开源源码**：用于验证职责拆分、运行时状态和反应表达是否已有成熟先例；许可证不兼容或来源不明时只读设计，不复制代码。
- **外部游戏体验**：只能说明玩法方向，除非有可核验技术资料，否则不能证明内部实现。

## Reference Matrix

| 职责/结论 | 参考来源 | 证据等级 | 本提案采用什么 | 不能由该证据推出什么 |
| --- | --- | --- | --- | --- |
| 元素反应必须是统一规则层 | `.spec/knowledge/features/project/用户故事_复合沙盒RPG角色与队伍系统_2026-06-21.md:70` | 项目正式需求 | 元素状态、地面、天气、材质和技能效果不能散落在技能脚本中互调 | 不直接决定具体 C# 类名、字段或 Tick 间隔 |
| 必须有一个自然样例证明统一规则成立 | `.spec/knowledge/features/project/用户故事_复合沙盒RPG角色与队伍系统_2026-06-21.md:142`、`openspec/changes/plan-core-framework-roadmap/design.md:99` | 项目正式验收方向 | 选择喷火点燃草地作为第一条竖切 | 不表示第一期必须完成所有元素、传播和存档 |
| 地表、技能、天气和材质未来通过统一规则组合 | `openspec/changes/plan-core-framework-roadmap/design.md:85` | 项目架构方向 | `ElementApplication` 保持世界空间来源语义，第一期只实现地形接收；角色效果继续进入 EX-GAS | 不要求本 change 同时实现角色、物体和天气适配器，也不允许另建角色状态框架 |
| 基础地表已有唯一作者入口 | `Assets/Scripts/GameCore/Runtime/Maps/TerrainNavigationTile.cs:9-41` | 当前源码事实 | 规则 Tilemap / `TerrainNavigationTile` 继续拥有基础地表、层级、坡道和代价 | 不允许从视觉 Sprite、颜色或 Sorting 推断玩法规则 |
| 当前运行时地表状态只是 Flags 字典 | `Assets/Scripts/GameCore/Runtime/Maps/TerrainNavigationTile.cs:63-69`、`Assets/Scripts/GameCore/Runtime/Maps/TerrainNavigationMap.cs:46`、`:155-209` | 当前源码事实 | 把字典值升级为 `TerrainCellRuntimeState`，Flags 只保留派生兼容视图 | 不能宣称现有代码已经支持持续时间、强度或反应 |
| 世界坐标可以使用正式 Grid API 转换为规则格 | `C:\Gamedev\Unity\Editor\6000.3.10f1\Editor\Data\Managed\UnityEngine\UnityEngine.GridModule.xml:236` | Unity 6000.3.10f1 官方 API | 使用 `GridLayout.WorldToCell` 作为锥形区域到规则格的转换入口 | 不证明元素应如何跨坡道、悬崖或阻挡；这些是项目规则 |
| Tilemap 可以按格读取作者规则 | `C:\Gamedev\Unity\Editor\6000.3.10f1\Editor\Data\Managed\UnityEngine\UnityEngine.TilemapModule.xml` 中 `Tilemap.GetTile(Vector3Int)` | Unity 6000.3.10f1 官方 API | 规则 Tilemap 可以按 cell 读取 `TerrainNavigationTile` | 不允许把视觉 Tilemap 同时升级为规则真相 |
| Tilemap 可以作为独立运行时表现覆盖层 | 同一官方文件中的 `Tilemap.SetTile(Vector3Int, TileBase)` 与 `Tilemap.RefreshTile(Vector3Int)` | Unity 6000.3.10f1 官方 API | 临时效果层和结果覆盖层可以只刷新变化格 | `SetTile` 能力不表示应该改写作者规则 Tilemap |
| 反应规则可以保存为独立数据资产 | `Assets/Scripts/GameCore/Runtime/Database/DatabaseEntry.cs`、`DatabaseRegistry.cs`；Unity `UnityEngine.CoreModule.xml:53489` 的 `ScriptableObject` 定义 | 当前源码 + Unity 官方 API | `ElementReactionDefinition : DatabaseEntry` 进入项目正式数据库 | 不证明规则字段设计天然正确，仍需本 change 明确条件、优先级和结果 |
| 元素系统适合进入项目系统生命周期 | `Assets/Scripts/GameCore/Runtime/Game/Systems/AGameSystem.cs`、`GameManager.SystemRegistryRuntime.cs` | 当前源码事实 | `ElementReactionSystem : AGameSystem`，使用现有泛型注册入口 | 不新增 `GameManager.ElementReactionSystem` 静态快捷入口 |
| EX-GAS Task 可以持续逐帧执行 | `Assets/Plugins/GAS/Runtime/Ability/AbilityTask/AbilityTaskBase.cs:5-81`、`ALTimelinePlayer.cs:19-125` | 当前插件源码事实 | `TaskApplyWorldElement` 可在 `OnBegin` 首次提交，在 `OnTick` 按间隔重复提交 | 不表示 Task 应拥有地表反应结果 |
| 项目侧 Task 可以进入正式生成链 | `Assets/Plugins/GAS/Editor/CodeGen/BeanUpdater.cs:100-116,289+`、`CodeGeneratorAbilityPart.cs:55-70` | 当前插件源码事实 | 通过扫描 Task/XParam 更新 Bean、Luban 和注册代码 | 不允许手改 `XAbility.gen.cs`、`XLuban.gen.cs` 或生成 JSON |
| Burning 可以影响后续寻路代价 | `TerrainNavigationTile.TraversalCost`、`TerrainNavigationMap.m_cachedCostMap` 与当前 A* cost map 接口 | 当前源码事实 | 状态变化后增量更新对应格的有效代价 | 不表示已执行路线必须在第一期动态重算 |

## External Source Audit

外部源码只按职责吸收，不成为 FantasyWord 的运行时 owner。由于三个成熟参考项目均使用强 copyleft 或 ShareAlike 许可证，本 change 只采用公开可观察的设计思想和职责边界，不复制、翻译或移植其代码。

当前正式 owner 是基线，不是不可重构的结论；是否替换只看同职责证据：

- 先记录现有正式 owner 的能力、缺陷和原始验收入口，再判断外部方案是否解决了同一个问题。
- 参考方案只有在功能闭包、正确性、作者流程、测试性和长期维护净收益明确高于迁移、兼容、许可证与回归成本时，才可推动重构或替换。
- 本次调研没有发现能够证明整体替换 EX-GAS 的单位状态、技能或伤害框架更优的证据，因此这些职责继续由 EX-GAS 承担；这是一项本次证据结论，不是永久禁止比较。
- 当前明确缺口是世界规则格状态、地表反应、地貌覆盖和导航代价；Mindustry、Cataclysm: DDA 和 OpenXcom 在这些缺口上提供了可验证的设计增益。
- 若未来发现更强候选，必须重新做同职责对比；不能因为“已有 GAS”拒绝真正更好的重构，也不能因为“参考项目成熟”就默认替换。

| 当前职责 | 参考来源与固定版本 | 证据等级/许可证 | 本次吸收什么 | 当前 Unity 落点 | 本次明确不吸收什么 | 验证入口 |
| --- | --- | --- | --- | --- | --- | --- |
| 元素/状态组合反应表 | [Mindustry `439799ce`](https://github.com/Anuken/Mindustry/tree/439799ce8ff1480d1d169c5ba7ff3def422999de)：`core/src/mindustry/content/StatusEffects.java`、`core/src/mindustry/type/StatusEffect.java` | 成熟开源项目；GPL-3.0；只读设计参考 | 状态定义拥有 `affinity`、`opposite` 和 transition handler；`Wet + Shocked`、`Burning + Tarred` 等组合说明反应关系可以集中声明，而不是写进施加技能 | `ElementReactionDefinition` 与 `ElementReactionSystem` 的规则匹配/结果执行 | 不复制 GPL 代码；不把单位状态模型当作地表格模型；不采用其帧时间、伤害值或互斥算法 | 规则合同测试覆盖水灭火、潮湿导电、油助燃和无草覆盖土壤不可复燃 |
| 单格场状态、强度、年龄、来源和独立推进 | [Cataclysm: DDA `df58de99`](https://github.com/CleverRaven/Cataclysm-DDA/tree/df58de992d1a7d279a37cbd5aaf6cb8bd87741d9)：`src/field.h`、`src/field_type.h`、`src/map_field.cpp`、`data/json/field_type.json` | 成熟开源项目；项目代码声明 CC BY-SA 3.0 Unported；只读设计参考 | `field_entry` 保存类型、强度、年龄、来源和存活状态；`field_type` 将静态类型语义与运行时实例分离；地图处理器独立推进场状态 | `TerrainElementStateDefinition`、`TerrainCellRuntimeState`、只推进计时格的派生活跃索引，以及未来可选传播处理器 | 不复制 ShareAlike 代码/JSON；不照搬回合制年龄、气体扩散、风向、天气和随机概率算法；第一期不实现传播 | 状态快照、活跃格调度、到期转化、来源追踪与固定步长确定性测试 |
| 地形格火焰寿命、可燃性、燃料和地图消费 | [OpenXcom `630130c5`](https://github.com/OpenXcom/OpenXcom/tree/630130c5c9ac236b9e1d8496005fb23e84e397ca)：`src/Savegame/Tile.h/.cpp`、`src/Battlescape/TileEngine.h/.cpp` | 成熟开源项目；GPL-3.0；只读设计参考 | `Tile` 明确保存 fire/smoke 剩余回合并读取 flammability/fuel；地图逻辑负责点燃、伤害、照明与视线消费，证明“格状态”和“消费该状态的系统”可以分开 | `TerrainElementStateDefinition` 保存 Burning 静态代价语义，`TerrainCellRuntimeState` 保存动态强度/剩余时间；导航与表现作为状态消费者 | 不复制 GPL 代码；不采用其回合制数值、地形部件结构、存档格式、爆炸传播或单位伤害实现 | 燃烧持续、代价精确恢复、表现刷新、到期露出 Dirt和场景重载恢复测试 |
| Unity/C# 地表管理器直接样本 | [qdnd `b4f963a5`](https://github.com/Interzoneism/qdnd/blob/b4f963a57b3a0265beac871fbf23dbd09e13cf65/Combat/Environment/SurfaceManager.cs) | 低可信补充样本；0 stars；仓库未声明许可证 | 只用于反例检查：确认 C# 项目中常见 surface definition、duration、cell geometry、事件转化和移动代价职责容易被塞进一个大管理器 | 不进入正式 owner；仅用于审查 `ElementReactionSystem` 是否过度膨胀 | 无许可证，不复制任何代码；不以其字符串表、Godot 类型、默认反应表或单体管理器为基线 | 设计审查确认规则、状态存储、区域解析、表现和技能接入没有重新集中成 God object |

## Tutorial Verdict

没有找到一套可以直接覆盖“Unity Tilemap 地表 + 数据化元素反应 + 单格持续状态 + 导航代价 + EX-GAS Timeline 接入”的权威完整教程。教程类资料只用于确认引擎操作，不作为领域架构基线：

- Unity 官方 [Scriptable tiles](https://docs.unity3d.com/Manual/tilemaps/tiles-for-tilemaps/scriptable-tiles/scriptable-tiles.html) 说明可以通过 `TileBase` 和 `GetTileData` 定义可脚本化瓦片外观，但不负责本项目运行时元素状态、反应规则或导航接入。
- 当前安装的 Unity `6000.3.10f1` XML API 元数据确认 `GridLayout.WorldToCell`、`Tilemap.GetTile`、`Tilemap.SetTile`、`Tilemap.RefreshTile` 和 `ScriptableObject` 可用。
- 因此实现路线采用“Unity 官方资料确认能力 + 成熟开源项目确认职责先例 + FantasyWord 当前源码决定正式落点”，而不是照着某篇教程搭一套并行框架。

## Gameplay Inspiration Boundary

Fire、Water、Oil、Wet、Burning、Electrified 和露土等反应语义与《神界：原罪》系列等系统性交互游戏存在体验相似性，但当前没有把任何商业游戏作为代码或数据结构基线：

- 没有取得其可核验的正式源码。
- 没有取得能证明内部 owner、数据结构、Tick、存档或导航接入方式的官方技术文档。
- 因此不使用“某游戏这样做”证明 `ElementReactionSystem`、`TerrainCellRuntimeState` 或两层 Tilemap 表现一定正确。
- 本提案中的首批反应表直接来自用户本轮明确给出的规则样例和项目既有用户故事。

如果后续要宣称对齐某个具体参考项目，必须另补：参考文件、证据等级、职责 owner、差距、当前 Unity 落点和验证入口。

## Source Verdict

本提案不是凭空设计，但也不是照搬某个外部元素系统：

1. **需求方向**来自项目正式用户故事。
2. **可实施边界**来自当前 Terrain、GameSystem、Database 和 EX-GAS 源码。
3. **Tilemap/数据资产能力**由当前 Unity 6000.3.10f1 官方 API 元数据确认。
4. **职责先例**由 Mindustry 的集中反应表、Cataclysm: DDA 的 field runtime state、OpenXcom 的格子火焰生命周期交叉验证。
5. **具体职责划分**仍由当前项目“单一真相、技能不越权、表现不改规则、生成物不手改”的既有边界裁决，外部源码不拥有 FantasyWord 的正式数据或执行入口。
