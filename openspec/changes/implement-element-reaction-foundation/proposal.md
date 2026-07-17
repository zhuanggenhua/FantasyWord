# Proposal: implement-element-reaction-foundation

## Why

本提案发起时，项目已经为属性地表预留了正式入口，但还没有形成可称为“元素反应框架”的闭环：

- `TerrainNavigationTile` 已定义 `Grass / Dirt / Stone / ShallowWater / Mud` 基础地表。
- `TerrainNavigationMap` 已定义 `Wet / Burning / Oiled / Electrified` 临时标记，并按规则格保存运行时字典。
- 提案发起时的状态只有位标记，没有持续时间、强度、来源、反应规则、到期转化、传播、表现刷新或存档语义。
- `m_runtimeSurfaceVisualTilemap` 只有引用和清空入口，没有状态变化驱动的正式刷新闭环。
- 技能系统已经收口到 EX-GAS Timeline / Task / GameplayEffect / GameplayCue，但还没有“向世界提交元素”的正式 Timeline Task。

如果继续让具体技能直接写“草覆盖层销毁”、直接设置地表标记或直接改 Tile，元素规则会散落到技能、场景脚本和表现脚本中，后续水灭火、油助燃、潮湿导电、天气修正和 Mod 扩展都会出现多份真相。

本 change 建立第一条元素地表规则竖切：喷火技能只提交火元素，统一元素系统根据规则 Tilemap 和反应配置决定草覆盖层燃烧、持续、提高移动代价，并在燃尽后进入“草覆盖层被销毁、底层土壤显露、草层可再生”的后续世界变更语义。视觉上的“露出土壤”必须通过移除草覆盖/植被层露出原本存在的土壤底层实现，不允许盖一张 Dirt/焦土结果 Tile 冒充。

## Current State Lock

- **问题对象**：`TerrainNavigationTile` 的基础地表与临时状态定义、`TerrainNavigationMap` 的单格状态字典、EX-GAS Timeline Task 扩展入口、地表运行时表现层。
- **真相来源**：
  - `Assets/Scripts/GameCore/Runtime/Maps/TerrainNavigationTile.cs`
  - `Assets/Scripts/GameCore/Runtime/Maps/TerrainNavigationMap.cs`
  - `Assets/Scripts/GameCore/Runtime/Elements/`
  - `Assets/Scripts/GameCore/Runtime/Database/Elements/`
  - `Assets/Scripts/GameCore/Runtime/Game/Systems/ElementReactionSystem.cs`
  - `Assets/Scripts/GameCore/Runtime/Presentation/TerrainSurfacePresentation.cs`
  - `Assets/Scripts/GameCore/Runtime/Combat/GAS/TaskApplyWorldElement.cs`
  - `Assets/Scripts/GameCore/Runtime/Combat/Abilities/Active/TimelineActiveAbility.cs`
  - `Assets/Prefabs/Abilities/World/喷火.prefab`
  - `Assets/GameData/Elements/`
  - `openspec/changes/implement-realtime-terrain-navigation/`
  - EX-GAS `AbilityTaskBase`、`ALTimelinePlayer`、BeanUpdater、Luban 与 `XAbility.gen.cs` 生成链。
- **目标入口/环境**：
  - 规则 Tilemap 继续是基础地表、层级、坡道和通行规则的作者真相。
  - `ElementReactionSystem` 作为世界地表元素施加与反应裁决入口，不替代 EX-GAS 的角色状态与伤害管线。
  - 角色伤害、角色 Burning/Wet 等战斗状态继续由 EX-GAS `GameplayEffect`、GameplayTag 和 Attribute 承载。
  - EX-GAS Timeline 通过正式 `TaskApplyWorldElement` 提交世界元素。
  - GameplayCue 只负责喷射火焰、声音和即时反馈。
- **验收口径**：在现有地形测试入口完成“持续喷火 -> 合法草覆盖格燃烧 -> 燃烧期间显示火焰、提高移动代价并对站在燃烧地表上的角色造成伤害 -> 到期清除 Burning -> 移除 Grass 上层覆盖 -> 露出作者已经铺好的 Dirt 底层 -> 清除火焰临时层 -> 不写 Dirt/焦土结果覆盖 Tile”的真实世界状态闭环，并证明技能代码没有写死草层销毁、露土或再生逻辑。截图只能作为辅助视觉证据，不能替代运行时格状态、覆盖层生命周期、伤害和导航代价验证。本 change 验证的是瞬时运行时草覆盖层移除和露土闭环；草覆盖层再生进度、保存/加载和开放世界持久化由后续 `implement-persistent-world-terrain-mutation` 承接。

## Dependency

本 change 独立于 `implement-realtime-terrain-navigation`，但依赖它先提供以下正式能力：

1. 规则 Tilemap 已在验收场景中完成基础地表、层级、坡道和阻挡绘制。
2. `TerrainNavigationMap` 能按世界坐标/格坐标查询基础地表和合法层级连接。
3. 路径代价数据允许按单格运行时状态更新。

本 change 不回写、收窄或代替地形导航 change 的未完成任务；若导航场景尚未完成，只允许先实现和验证元素规则合同，不得宣称喷火端到端完成。

## Reference Basis

本提案的详细参考矩阵见 [`references.md`](references.md)。

参考按证据强度分为四层：

1. **项目需求依据**：项目用户故事和核心路线已经明确要求“元素状态、地面、天气、物品材质和技能效果通过统一规则组合”，并要求至少一个样例证明反应不是技能脚本互相硬调。
2. **当前源码依据**：现有地形状态入口、`AGameSystem` 生命周期、`DatabaseRegistry` 数据资产、EX-GAS Timeline Tick 和 Bean/Luban/注册生成链共同决定本提案可以落在哪些正式入口上。
3. **Unity 版本能力依据**：当前安装的 Unity `6000.3.10f1` 官方 API 元数据确认 `WorldToCell`、`GetTile`、`SetTile`、`RefreshTile` 和 `ScriptableObject` 能支撑规则格查询、独立表现 Tilemap 和数据资产。
4. **外部源码职责先例**：
   - Mindustry 验证元素/状态组合适合由集中 transition/affinity 规则表达。
   - Cataclysm: DDA 验证单格场状态需要类型、强度、年龄/剩余时间、来源，并由独立地图处理器推进。
   - OpenXcom 验证格子火焰可以保存寿命、可燃性和燃料，并由导航、照明、视线、伤害等消费者读取。
   - 三者均只用于只读设计参考，不复制其 GPL/CC BY-SA 代码；FantasyWord 的正式 owner 仍由当前项目源码和职责裁决表决定。

《神界：原罪 2》等商业游戏的地表交互只可作为玩法体验类比。本提案当前没有取得可核验的官方实现源码或技术文档，因此不把它们列为架构 owner，也不宣称照搬其内部实现。

## Reference Comparison Verdict

外部参考与当前项目按同职责比较后的结论如下：

1. **EX-GAS 不整体重构**：Mindustry、Cataclysm: DDA 和 OpenXcom 没有提供能在当前 Unity、EX-GAS 作者流程和项目生成链约束下证明“技能、角色状态、伤害和 Cue 整体优于 EX-GAS”的证据。角色侧继续使用现有 GAS 正式入口。
2. **世界地表缺口需要新增正式能力**：当前项目和 EX-GAS 都没有丰富的单格地表生命周期、地貌转化和导航代价闭环，因此建立 `ElementReactionSystem`、`TerrainCellRuntimeState` 和地表表现消费者是补真实缺口，不是重复造 GAS。
3. **吸收静态定义与运行时实例分离**：参考 Cataclysm: DDA 的 `field_type / field_entry` 职责拆分，增加 `TerrainElementStateDefinition`，避免每条反应重复保存 Burning 合并策略和通行代价。
4. **吸收活跃状态调度**：固定步长只推进存在计时状态的格子；活跃索引是可重建缓存，不扫描整张规则地图，也不成为第二份状态真相。
5. **吸收派生消费原则**：参考 OpenXcom 的格状态/消费者分离，路径代价从基础 Tile 与当前状态定义重新派生，表现由独立 `TerrainSurfacePresentation` 消费，不由反应规则直接累加 cost 或由 Map 组件写表现 Tilemap。
6. **不吸收传播和回合制算法**：气体扩散、风向、随机传播、回合制火焰数值、外部单位状态框架和无许可证 C# 样本均不进入首批实现。

这里的“EX-GAS 优先”表示：在 Ability、Timeline、角色命中、伤害、Tag、Attribute、角色状态和 GameplayCue 这些同职责比较中，EX-GAS 是当前正式 owner 和比较基线；它不是不可重构的豁免项。若外部方案能在同一职责、同一作者流程和同一验收口径下证明净收益覆盖迁移、回归、双轨过渡和长期维护成本，本提案允许另立 change 重构或替换。当前参考没有提供这样的证据，因此保留 EX-GAS；世界规则格生命周期则是 EX-GAS 未覆盖的独立职责，由元素反应系统补齐。

## 2026-07-11 Proposal Update Verdict

对比外部成熟实现并核对当前源码后，结论是：**提案需要保留已经吸收的结构性修订，但不需要推翻重写；当前应按既定架构继续收口，不再发起整体重构。**

1. **主架构保持不变**：EX-GAS 继续拥有技能时序、角色命中、伤害、Tag、Attribute、角色状态和 GameplayCue；`ElementReactionSystem` 只补齐世界规则格状态、地表反应、地貌覆盖和导航代价。
2. **“择优参考”和“保留 GAS”不冲突**：
   - 择优比较的单位是具体职责，不是整套框架的名气、代码量或概念统一程度。
   - 在 Ability、Timeline、角色命中、伤害、角色状态和 Cue 职责上，EX-GAS 是当前正式 owner 和比较基线；外部参考尚未证明整体替换后的净收益能够覆盖迁移、回归、双轨过渡和维护成本，因此本次保留。
   - 在世界规则格生命周期、地表反应和地貌覆盖职责上，EX-GAS 没有现成闭包，因此由 `ElementReactionSystem` 补齐，而不是为了“GAS 优先”把地表状态硬塞进角色 GameplayEffect。
   - 如果后续参考方案在同一职责、同一作者流程和同一验收口径下被证明确实更好，可以另立 change 重构；GAS 不享有免比较特权。
3. **已经吸收且不再回退的改进**：
   - 静态状态定义与单格运行时实例分离。
   - 固定步长只推进有计时状态的活跃格。
   - 路径代价和表现从状态派生，不保存第二份可变真相。
   - 使用 `TerrainNodeKey = LayerId + Cell`，当前单层明确拒绝非默认层。
   - 当前正式 owner 只是比较基线；未来若出现净收益明确更高的同职责方案，仍允许另立 change 重构。
4. **技能运行桥已去除错误语义复用**：喷火使用独立 Prefab 和通用 `TimelineActiveAbility` 运行桥，不再复用 `MeleeAttackAbility` Prefab。通用桥只负责 EX-GAS Timeline 输入门控和中断，不拥有喷火规则、伤害、元素反应或 Cue。
5. **首批范围不扩大**：锥形内的相邻格展开只是本次元素输入的合法命中解析，不是火焰自行传播；天气、物体材质、液体流动、导电网络、存档和网络同步继续留在后续 change。
6. **重新打开架构裁决的条件**：只有当剩余实施证明当前 owner 无法满足原验收，或新的参考方案在同职责下以可核验证据证明收益覆盖迁移、兼容、回归和长期维护成本时，才重新比较；不能因为实现尚未接线就推翻已通过合同验证的结构。

截至 `2026-07-11`，元素合同、规则解析、富运行时状态、`TerrainNodeKey`、`ElementReactionSystem`、`TerrainSurfacePresentation` 和 `TaskApplyWorldElement` 已进入项目源码。首批 4 个状态资产、6 个反应资产和 1 个表现配置资产已经创建，Burning 通行代价已配置为 `4x`。

## 2026-07-11 Persistent World Correction

用户已明确项目目标是“玩家行为对世界产生持久影响的开放世界，类似 Minecraft”。因此，本 change 中“首批不接地图持久化、场景重载恢复原状”的说法只能作为当前实现阶段的限制，不能作为产品目标或最终验收方向。

修正后的架构口径：

1. **规则反应系统仍然成立**：喷火技能不能直接写“草覆盖层销毁”“露出土壤”或“草层再生”；地表/覆盖层变化仍由 `ElementReactionSystem` 根据数据化规则裁决。
2. **草烧掉后应自然露出土壤**：正式方向不是把 Grass 地表转换成 Dirt 地表，而是把草作为可移除、可再生覆盖/植被层处理；燃尽后移除草覆盖层，露出下面原本存在的土壤。当前不再允许用结果覆盖 Tilemap 冒充露土。正式开放世界应把“草覆盖层被移除和再生进度”写入可保存的世界地形变更层；测试场景必须具备真实土壤底层和可移除草覆盖层。
3. **作者基础地图不是永久不可变世界**：作者绘制的规则 Tilemap 是初始世界模板，不是玩家世界存档的唯一真相。正式运行时应读取“模板地形 + 玩家改写层/区块存档”得到当前世界地貌。
4. **持久化不是表现层责任**：`TerrainSurfacePresentation` 只显示当前状态；保存、加载、区块脏标记、撤销/重建、多人同步边界应由独立世界地形变更机制承担。
5. **本 change 不伪装完成持久世界**：当前已完成的是元素反应基础竖切，不是 Minecraft 式世界修改闭环。持久地貌变更必须作为后续 change 实现和验收。

后续 change：`implement-persistent-world-terrain-mutation`，首批目标改为“火烧毁草覆盖层、露出底层土壤、草层可再生且可保存/加载”。

## 2026-07-12 Acceptance Purpose Lock

本次竖切的测试目的不是“截图里能看到火”，也不是“存在一张火焰 Tile”。正式目的必须按玩家行为造成的世界状态变化闭环验收：

1. 玩家或正式 Ability 向世界提交 Fire，而不是测试脚本直接改 Tile。
2. 命中格在作者模板上必须是 `Dirt` 底层 + `Grass` 上层覆盖，且 Grass 覆盖具有可燃/可销毁属性。
3. Fire 由 `ElementReactionSystem` 按规则把 Grass 覆盖格推进到 Burning；技能、Cue 和截图脚本不得写死草层移除或露土。
4. Burning 期间必须同时验证三类消费者：临时火焰表现出现、移动代价提高、站在燃烧地表上的角色受到正式伤害链处理。
5. Burning 到期后必须验证 Grass 上层覆盖被移除或隐藏，当前有效覆盖为 `None`，底层仍为作者已有的 `Dirt`。
6. 燃尽后不得出现 Dirt/焦土结果覆盖 Tile；露土必须来自草覆盖层消失后露出底层土壤。
7. 截图和 PureRef 展示只用于给人看最终状态，不能作为“状态变化已经正确”的唯一证据；必须配套运行时结果 JSON 或等价状态采样。
8. 当前场景重载恢复原 Grass 只能说明尚未接持久化；开放世界目标仍要求后续保存玩家造成的草层移除与再生状态。

以下为历史证据摘录（已被后续 `2026-07-13 Evidence Correction` 取代，不再作为当前完成口径单独引用）：

- Unity `6000.3.10f1` 已完成脚本编译；最新 `FantasyWord.GameCore.EditModeTests` 整组结果为 67/67 通过，失败和跳过均为 0，覆盖元素核心、元素系统、地形导航和世界元素 Task 合同。
- 资产合同已经验证 4 个状态、6 个反应和 1 个表现配置均能通过 `DatabaseRegistry` 正式反序列化与唯一注册；Burning 正式配置的通行代价为 `4x`。
- `地表元素表现-首批.asset` 当前只包含 Burning -> 用户提供火焰序列帧映射；Wet/Oiled/Electrified/Steam/Dirt 结果没有正式素材时不得配置占位映射。
- 已删除前序自造的 `TerrainElementOverlays.png` 与湿润/油污/导电/蒸汽/焦土占位 Tile。`TerrainElementPresentationTiles_UseProvidedFireSpriteSheetOnly` 只锁定用户提供的火焰序列帧 `Assets/Art/元素/地表/火焰/32x32火3.png` 和 Burning 动画 Tile；其它元素效果等待正式素材后再接。
- 已新增通用 `TimelineActiveAbility`，原 `MeleeAttackAbility` 收口为它的近战语义子类；喷火使用独立 `Assets/Prefabs/Abilities/World/喷火.prefab`，并由 `FormalGasAbilityCodes.Flamethrower = 20010` 提供稳定代码。
- EX-GAS BeanUpdater、Luban、Ability 注册与配置生成链已经按正式入口执行。生成 C#、生成 JSON、`XAbility.gen.cs` 和 `XLuban.gen.cs` 均已包含 `TaskApplyWorldElement` / `XParamApplyWorldElement` 与 Ability `20010`。
- 通过 `XLauncher.InitCache()`、`XLuban.LoadTablesForEditor()` 读取的真实生成数据确认：Timeline `20010` 生命周期为 65 帧，包含 1 条 1–60 帧世界火元素任务、7 条正式 `TaskApplyEffects` 角色命中任务、1 条攻击动画 Cue、1 条 1–60 帧 `CueMountPrefab` 喷火流 Cue，以及 1 条 1–60 帧 `CuePlayGameCoreAudio` 音频 Cue；世界任务参数为 Fire、强度 1、暴露 0.1 秒、每 3 帧提交、锥形距离 3.5、半角 30 度。
- `ClickMoveTest` 场景实例已经确认：玩家角色保留 `20001` 并追加 `20010`；`TerrainNavigationMap`、`ElementReactionSystem`、`TerrainSurfacePresentation` 各只有一个；临时效果 Tilemap 引用正确；结果覆盖 Tilemap 不再作为露土验收入口。退出 PlayMode 后从磁盘重新打开场景，场景为 clean；运行时临时效果 Tilemap 的已用 Tile 数量为 0，`size` 均为 `(0, 0, 1)`。

正式 PlayMode 证据已经补齐核心喷火闭环：

- 通过玩家正式入口 `FireFormalGasAbility(20010, LocalPlayer)` 激活喷火，返回 `Valid`；不是直接调用元素系统或测试专用入口伪造结果。
- 8 个 Grass 规则格进入 Burning，临时火焰层出现 8 格，运行时通行代价均为 `4x`。
- 旧实现曾在 Burning 到期后把 8 格逻辑有效地表临时写成 Dirt，并清空临时火焰层；该结果只能作为旧版占位逻辑证据，不能再作为正式“烧草露土”验收口径。
- 再次对同一露土区域施加 Fire 后，Burning 数量保持为 0；在新语义下，这应改为验证“无草覆盖层的土壤格不再按有草覆盖可燃”。
- 重载 PlayMode 后，运行时状态和临时覆盖均为 0，目标格恢复 `Grass / Grass`，通行代价恢复为 1；这只证明当前实现尚未接入世界地形持久化，不代表开放世界最终目标应恢复原状。
- 燃烧前路径可直接到达目标；燃烧后重新寻路会绕到高代价格之外，证明 Burning 代价已被正式寻路消费。首批仍不要求正在执行中的旧路线自动重算。
- 悬崖验证中，低地 Grass `(-5, 0)` 进入 Burning 且代价为 4；同一几何锥形内的高台 Grass `(-4, 3)` 保持无状态且代价为 1。
- 坡道验证中，从低地 `(1, 3)` 朝左施放正式 Ability，经合法坡道命中高地 `(-2, 3)`，两格均进入 Burning 且代价为 4。
- 坡道首次验证失败的原因是玩家输入组件在后续帧覆盖测试朝向；运行态临时禁用 `CharacterPlayerControl` 后，正式 Ability / Timeline / Task 链通过验证。该处理只用于锁定测试输入，没有修改生产逻辑。

喷火 GameplayCue 已完成视觉侧正式接入：

- 新增 `FlamethrowerCueVisual`，只读取父级 `Movable.GetTargetDirection()`，负责四方向旋转与 8 帧 Sprite 动画；不引用 `ElementReactionSystem`、`TerrainNavigationMap`、Tilemap 或任何地表状态。
- 新增项目自有 `FlamethrowerJet.png` 和 `喷火-火焰表现.prefab`，由 Timeline `20010` 的 `CueMountPrefab` 在 1–60 帧挂载到施法角色并随宿主销毁。
- `Temp/ElementReactionCueE2E.txt` 记录正式 Ability 激活返回 `Valid`，喷火视觉运行中实例数为 1、父级为玩家角色、渲染帧为 `FlamethrowerJet_3`，Timeline 结束后实例数恢复为 0。
- 轻量截图核验确认喷火流方向、长度和销毁正常。Burning 表现改为用户提供的真实火焰序列帧；Wet/Oiled/Electrified/Steam 和露土视觉仍需正式素材与作者层级后再验收。

喷火 GameplayCue 的音频运行闭环已经建立，原始失败原因和修正路径均已锁定：

- 正式音频使用 `Assets/GameData/Elements/Audio/Flamethrower_FireSpell03_CC0.ogg`，来源为 OpenGameArt `80 CC0 RPG SFX` 的 `spell_fire_03.ogg`，许可证为 CC0；来源、时长、采样率与 SHA-256 已记录在同目录 `README.md`。
- `Assets/GameData/Elements/Audio/Flamethrower_AudioResolver.asset` 已创建并通过 `DatabaseRegistry` 注册，Resolver GUID 为 `3b7e4c26c0a18a74ea6711d1d29f0312`，频道为 `GameplaySoundFX`。
- 最初失败不是 Resolver、数据库或音频资源缺失，而是 Timeline 音频片段被配置为 `1–1` 帧；同一帧内完成 Begin/Finish 后，Cue 在显示系统消费前已经销毁。
- 已将 EX-GAS Timeline 原始源表 `Sheet1!H17` 的结束帧从 `1` 改为 `60`，再通过正式 Luban 流程重新生成 JSON；未手改生成物。修改前源表备份位于 `Temp/ElementReactionAudioCandidates/#exgas.timelineAbility.before-audio-duration-fix.xlsx`。
- `Temp/ElementReactionAudioE2E.txt` 已记录正式 Ability 激活返回 `Valid`，`lastResolver=Flamethrower_AudioResolver`、`resolverMatched=True`、`matchingSourceCount=1`、`playingMatchingSourceCount=1`，目标 `AudioSource` 正在播放 `Flamethrower_FireSpell03_CC0`。
- `Temp/ElementReactionAudioTimelineE2E.txt` 显示 0.5 秒时正常播放，2.5 秒附近同一音效再次开始，约 4.4 秒时已经停止。随后 `Temp/ElementReactionAudioHoldProbe.txt` 通过正式输入门控完成精确裁决：`FireFormalGasAbility(20010)` 在 1.000 秒返回 `Valid`，目标 Resolver 请求分别发生在 1.050 秒和 3.253 秒；3.603 秒调用 `StopFireFormalGasAbility(20010)` 后，后续新增请求为 0。第二次播放来自 `Auto` 输入模式在 Timeline 间隔结束后的合法持续施法重启，不是单次 Ability 内重复 Cue。

本轮 PlayMode 证据保存在：

- `Temp/ElementReactionE2E.txt`
- `Temp/ElementReactionPathE2E.txt`
- `Temp/ElementReactionElevationE2E.txt`
- `Temp/ElementReactionRampFormalE2E.txt`
- `Temp/ElementReactionAudioE2E.txt`

持续施法音频语义和最终收口均已完成：

- 正式 Ability 已经通过 `CuePlayGameCoreAudio -> AudioSystem` 实际消费目标 Resolver 并播放目标音效；“音频不执行”已解决。持续施法探针进一步证明：第二次请求由 `FormalAbilityInputGateRuntime` 的 `Auto + triggerHeld` 分支启动下一轮 Ability，正式停止入口会释放输入并阻止后续重启；该行为不需要修改生产代码。
- 前序六格占位图集和 Tile 已移除。当前只允许 Burning 使用用户提供火焰序列帧；其它元素表现和露土视觉不能在缺素材/缺作者层级时宣称完成。
- `ClickMoveTest.unity` 的大规模差异审计已经完成。当前磁盘哈希为 `E6A4BFE7CE5B221164C68E34081022E10487065BEF5A98A5148B0C5013810E11`；与旧备份相比只新增 20 个预期对象，没有删除旧对象，旧对象仅有 5 处明确变化。约 899 格规则 Tilemap 数据可以解释主要新增序列化行；运行时临时效果 Tilemap 为空，没有证据表明 Burning 或其它运行态 Tile 被保存；Dirt/焦土结果覆盖已从验收口径移除。
- 本轮退出 PlayMode 后，场景曾因测试残留显示 dirty，但磁盘哈希未变化；从磁盘重新打开 `ClickMoveTest` 后恢复 clean，两层运行时覆盖 Tilemap 的已用 Tile 数量均为 0。该现象属于未保存的编辑器运行残留，不是场景文件污染。
- 历史摘录曾声称完整 `FantasyWord.GameCore.EditModeTests` 最终运行状态为 `Passed`；该说法已被 `2026-07-13` 新鲜结果取代，当前完整 GameCore 不能称为全量通过。
- 元素职责静态搜索确认 Ability、Task 和音频 Cue 没有 Grass、Dirt 或 Tilemap 写入硬编码；没有新增 `GameManager.ElementReactionSystem` 快捷入口，也没有运行时场景搜索兜底。生成 C#、注册与 JSON 均包含 `TaskApplyWorldElement` / `XParamApplyWorldElement` / Ability `20010`。
- 插件边界门禁已经登记 `ActiveAbilityBase`、`TimelineActiveAbility`、`TaskApplyWorldElement`、`CharacterBase.Abilities` 和 `CharacterCommandExecutor` 这组正式 GAS 薄桥，最终 `EX-GAS` 越权数为 0。门禁全局仍报告 1 个与本 change 无关的 `EquipmentSystem/CharacterAppearance` 菜单路径问题，本 change 未借机修改装备系统。
- 最终最近 1 分钟 Unity Console 的 Error 和 Exception 均为空；Editor 已退出 PlayMode、未暂停、未编译，`ClickMoveTest` 为 clean。场景内 `TerrainNavigationMap`、`ElementReactionSystem`、`TerrainSurfacePresentation` 各一个，两张运行时覆盖 Tilemap 均为 0 格，磁盘哈希保持 `E6A4BFE7CE5B221164C68E34081022E10487065BEF5A98A5148B0C5013810E11`。
- `npx openspec validate implement-element-reaction-foundation --strict` 与 `.spec` lint 均通过。完整 `git diff --check` 已执行，唯一失败来自 Unity 为场景空字符串字段写出的历史尾随空格；不能为通过文本门禁手改场景 YAML。排除 `ClickMoveTest.unity` 后的 tracked 文本检查和本 change 未跟踪 C#/Markdown/JSON 文本检查均通过。
- 已审计误导出的 `C:\Gamedev\Unity\Project\Assets\DataGenerated\Luban`：目录共 108 个既有/生成文件，其中 14 个文件时间戳命中本轮 Luban 生成。该目录位于当前 Unity 工程和 git 仓库之外，且没有可恢复的旧版本真相，因此未删除整个目录或猜测回滚；它不参与 `FantasyWord` 当前正式生成物加载。
- `implement-realtime-terrain-navigation` 的实际场景已经满足本 change 所需的规则 Tilemap、基础地表和层级连接，但其自身 `tasks.md` 仍有未完成项；本 change 不替它宣称导航 change 已完成。

上述历史结论已被 `2026-07-13 Evidence Correction` 取代；不得再引用其中“六种地表表现”“完整 GameCore 通过”或旧场景哈希作为当前完成口径。

## 2026-07-13 Evidence Correction

当前完成口径只基于 `2026-07-13` 重新生成并已固化到 `test-results` 的证据：

- `test-results/evidence-runtime-validation/element-surface/tilemap-source-audit-20260713.json` 确认 `ClickMoveTest` 当前可见地面与来源 `Ground` 对比为 `900/900` 且差异 `0`，`地表装饰` 与来源 `GroundDecoration` 对比为 `267/267` 且差异 `0`；当前基础层 900 格、Dirt 底层 617 格、Grass 覆盖 547 格，临时效果层和结果覆盖层均为 0。
- `test-results/evidence-runtime-validation/element-surface/clickmove-element-surface-q-wide-visual-runtime-20260713.json` 确认正式 Q 槽 `20010` 通过 EX-GAS `TaskApplyWorldElement` 提交 Fire，没有使用直接元素系统兜底；6 个 Grass 覆盖目标格进入 Burning、临时火焰为 6 格、通行代价为 `4x`，燃尽后 6 格 Grass 覆盖隐藏，底层 Dirt 保持可见，结果覆盖 Tile 为 0。
- 同一 q-wide 运行还确认二次 Q 复验确实再次触发世界元素 Task：`ReapplyWorldElementTaskSubmitCountDelta = 1`；6 个已移除目标格保持 `Dirt + Removed`，`ReapplyBurningCellCount = 0`。第二次喷火的 `SuccessfulApplyCountDelta = 1` 只说明锥形范围内其它仍有草覆盖的格可被命中，不能作为“目标格复燃”的失败条件。
- `test-results/evidence-image-validation/clickmove-element-surface-q-wide/result.json` 与 `contact-sheet.png` 只作为图面辅助证据：燃烧图能看到同一区域 6 格火焰，燃尽图能看到同一区域 Grass 覆盖消失并露出 Dirt；状态正确性仍以运行时 JSON 为主证据。
- 元素相关 EditMode 类级复测已通过：`editmode-ElementReactionSystemEditModeTests-20260713.json`、`editmode-TerrainNavigationMapEditModeTests-20260713.json`、`editmode-TerrainSurfaceDamageSystemEditModeTests-20260713.json` 均为 `Passed`，覆盖 Fire->Grass、Bare Dirt 不燃、燃尽移除覆盖、悬崖隔断、坡道连通与 Burning 正式伤害链。
- 完整 `FantasyWord.GameCore.EditModeTests` 当前不能称为全量通过：`gamecore-editmode-20260713-element-surface.json` 记录 `MeleeAttackAbilityEditModeTests.FormalGasAttackRuntimeInstance_UsesGasContextNotMigrationSheetFlag` 失败。该失败属于近战/GAS 朝向合同，不是元素地表 q-wide 目标格复燃失败；因此本 change 只能声明“元素相关验收通过，完整 GameCore 仍有无关失败待处理”。
- Wet、Electrified、Steam 等其它元素表现没有正式素材时继续保持未验收，不能用占位图或旧六状态联系表宣称完成；草覆盖层再生、再生进度和保存/加载由 `implement-persistent-world-terrain-mutation` 承接。

## 2026-07-14 Surface Layering Lock

本轮先收口 Tilemap 分层；用户随后明确允许端到端后，已完成新分层 PlayMode E2E 验收。

- 当前分层支持俯视角 Tilemap 游戏：基础视觉、Unity 物理碰撞、寻路规则、地表语义、运行时表现和未来玩家改写层分开承担职责。
- 当前不新增独立 Collision Tilemap。原版 MiniFantasy 场景和当前 `ClickMoveTest` 都是在墙体、水体、悬崖等视觉 Tilemap 上挂 `TilemapCollider2D + CompositeCollider2D + Rigidbody2D`；Unity 官方 Tilemap Collider 2D 也支持直接从 Tilemap 生成 2D 碰撞形状。后续只有当阻挡语义需要脱离视觉 Tile 时，才另开专用碰撞层。
- 当前寻路不靠 Collider。`地形规则` / `TerrainNavigationTile` 继续作为可行走、层级、坡道、基础地表和通行代价的玩法真相源。
- `地表覆盖` 不再等同于“所有可烧物”。`TerrainSurfaceLayerSource` 允许多个作者/表现 Tilemap 的特定 Tile 映射为覆盖语义，所以 `地表装饰` 不被忽略，但也不会整层都被标成可烧。
- 新来源层存在时，`TerrainNavigationMap` 不再回落到旧单覆盖字段；旧单覆盖字段只保留给没有配置 `TerrainSurfaceLayerSource` 的旧地图兼容，避免新地图同时有两套覆盖真相。
- 当前 `ClickMoveTest` 只把纯草类来源映射为 Grass 可燃/可销毁：`地表装饰` 的 `Rule Tiles/Grass.asset`、`地表装饰` 的标准 `Grass19_Minifantasy_ForgottenPlainsTiles_3.asset`，以及 `悬崖顶部装饰` 的 `Rule Tiles/Grass.asset`；`CobblestoneGrass Combo`、`LakeGrass`、`CliffGrass` 等复合 Tile 暂不接入可烧，避免燃烧时误隐藏石路、水岸或崖草整块视觉。
- 不按 Fire/Wet/Electrified/Steam 等元素类型开 Tilemap。元素类型属于规则和状态，Tilemap 只按作者层、语义来源和运行时表现职责拆分。
- 新来源层相关 EditMode 覆盖已落到源码并复测通过：`test-results/evidence-runtime-validation/element-surface/editmode-ElementReactionSystemEditModeTests-20260714-surface-layer.json` 为 `Passed`，覆盖装饰层 Grass 映射、新来源层压过旧兼容字段、旧地图无新来源层时仍可走旧字段。
- 场景审计 `test-results/evidence-runtime-validation/element-surface/clickmove-scene-surface-layer-audit-20260714.json` 确认 `ClickMoveTest` 当前为 clean，旧单覆盖字段为空，`TerrainSurfaceLayerSource` 有两条有效来源：`sourceId=0` 的 `地表覆盖` 映射 `Cliff5_Minifantasy_ForgottenPlainsTiles_239 -> Grass / Flammable, Destructible, Regrowable`；`sourceId=10` 的 `地表装饰` 映射 `Grass -> Grass / Flammable, Destructible`。临时效果层和结果覆盖层均为 0 格。
- 用户指出 `20260714-surface-layer` 截图中燃烧格数和露土格数视觉不一致后，确认旧通过口径存在缺口：目标格同时存在 `地表覆盖` Grass 与 `地表装饰` Grass，旧表现层只隐藏一个来源层，导致装饰 Grass 仍可见。该旧证据不得再单独作为视觉露土完成证据引用。
- 修正后新分层 PlayMode E2E 证据 `test-results/evidence-runtime-validation/element-surface/clickmove-element-surface-q-wide-visual-runtime-20260714-visual-layer-fix.json` 为 `Success`：正式 Q 槽 `20010` 通过 EX-GAS `TaskApplyWorldElement` 提交 Fire，6 个目标格进入 Burning，燃烧期间临时火焰 6 格，燃尽后 6 格 Grass 覆盖隐藏、底层 Dirt 可见、结果覆盖 Tile 为 0，且 `VisibleMappedSurfaceCoverSourceCountAfterExpiration = 0`。
- 同一 E2E 复验二次 Q：`ReapplyWorldElementTaskSubmitCountDelta = 1`、`ReapplyWorldElementTaskSuccessfulApplyCountDelta = 0`、`ReapplyBurningCellCount = 0`，证明已移除目标格不会复燃；新的红框对比图 `test-results/evidence-image-validation/clickmove-element-surface-q-wide-visual-layer-fix/target-six-cells-overlay.png` 显示左侧 6 格火焰、右侧同 6 格露出褐色 Dirt。
- 用户追问残留花/草后，重新扫描目标区与全场景植被候选，确认目标格内的“花/草”来自 `地表装饰` 的 `Grass` RuleTile 变体，已经纳入映射；另补入两个纯草漏项：`地表装饰` 的标准 `Grass19_Minifantasy_ForgottenPlainsTiles_3.asset` 与 `悬崖顶部装饰` 的 `Rule Tiles/Grass.asset`。复扫证据 `test-results/evidence-runtime-validation/element-surface/full-scene-vegetation-mapping-audit-20260714-after-pure-grass-mapping.json` 记录纯草疑似漏映射为 0，剩余 297 个未映射疑似项均为 `LakeGrass`、`CliffGrass`、`CobblestoneGrass` 复合视觉，不应通过单条草映射整块烧掉。
- 补映射后重跑 q-wide PlayMode E2E：`test-results/evidence-runtime-validation/element-surface/clickmove-element-surface-q-wide-visual-runtime-20260714-pure-grass-mapping.json` 为 `Success`，6 个目标格 Burning、燃烧期间火焰 6 格、燃尽后 6 格 Grass 覆盖隐藏并露出 Dirt、所有映射覆盖来源残留为 0、二次 Q 不复燃；视觉核验结果为 `test-results/evidence-image-validation/clickmove-element-surface-q-wide-pure-grass-mapping/result.json`，预览相册为 `http://8.148.71.102:18080/#/fantasyword/element-surface-q-wide-pure-grass-mapping`。
- 用户继续指出目标区仍残留一朵花后，确认旧验收范围仍缺一类真实对象：目标格 `(4, 12, 0)` 的 `Flower (6)` 是手摆 `SpriteRenderer` 场景道具，不是 Tilemap 瓦片。上一轮“独立道具隐藏”临时路线已废弃，不再作为正式方案或证据口径；本轮已将 `ClickMoveTest` 中 23 朵花和 10 处长草从手摆 `SpriteRenderer` 迁入统一 `地表植被覆盖` / `地表植被阴影` Tilemap，并通过 `TerrainSurfaceLayerSource` 明确映射为植被覆盖来源。
- 2026-07-15 重构后最终审计 `test-results/evidence-runtime-validation/element-surface/clickmove-vegetation-tilemap-audit-20260715.txt` 确认 `地表植被覆盖=33`、`地表植被阴影=33`、手摆花草对象 0、花草 `SpriteRenderer` 0、缺脚本 0、`TerrainSurfaceLayerSource` 来源数 5，且植被覆盖/阴影排序为 -8/-7；旧的独立覆盖道具通道、单字段覆盖道具列表和截图前隐藏花草遮挡物的验证字段均不再作为代码或场景入口。
- 2026-07-15 重构后 q-wide PlayMode E2E `test-results/evidence-runtime-validation/element-surface/clickmove-element-surface-q-wide-visual-runtime-20260715-tilemap-vegetation.json` 为 `Success`：正式 Q/EX-GAS `TaskApplyWorldElement` 提交 Fire，6 个目标格进入 Burning，燃烧期间临时火焰 6 格，燃尽后 6 格 Grass 覆盖隐藏并露出 Dirt，所有映射覆盖来源可见残留为 0，二次 Q 有提交但 `ReapplyBurningCellCount = 0`；最终截图已上传到 `http://8.148.71.102:18080/#/fantasyword/element-surface-q-wide-tilemap-vegetation`。
- 该 E2E 只证明新分层下的运行时烧草闭环；草覆盖层再生、保存/加载仍属于 `implement-persistent-world-terrain-mutation`，Wet/Electrified/Steam 等其它表现仍等待正式素材，完整 `FantasyWord.GameCore.EditModeTests` 也仍不能称为全量通过。

## Architecture Options

### Option A: 技能直接修改 Tile 或地表状态

拒绝。

- 技能会同时拥有元素输入、反应规则、地貌转化和表现职责。
- 水、火、电、油之间无法共享统一规则。
- 同一反应会在不同技能中重复实现。
- GameplayCue 容易越权修改世界状态。

### Option B: 把规则、计时、状态和表现全部塞进 TerrainNavigationMap

拒绝。

- 导航组件会同时承担路径、元素规则、状态推进、视觉刷新和技能接入。
- 角色、物体、天气进入元素系统后无法复用。
- 地图状态与表现 Tilemap 再次形成隐式双轨。

### Option C: 专用元素系统 + 地图单格运行时状态 + 独立表现消费者

采用。

- `ElementReactionSystem` 负责元素输入、规则匹配、状态计时和反应结果。
- `TerrainNavigationMap` 只保存当前地图的单格运行时状态，并继续提供统一地表查询与路径代价。
- `ElementReactionDefinition` 作为可审计的数据化反应规则。
- `TerrainSurfacePresentation` 只消费状态变化事件，分别刷新临时效果层和最终地貌覆盖层。
- EX-GAS `TaskApplyEffects` / `GameplayEffect` 继续处理角色命中、伤害和角色状态。
- EX-GAS `TaskApplyWorldElement` 只提交地表 `ElementApplication`，GameplayCue 只播放表现。
- 当前正式 owner 作为比较基线；只有外部方案被证明确实具有更高净价值时才考虑重构。本次没有发现整体替换 EX-GAS 更优的证据，因此只吸收世界地表缺口上的设计点。

## Scope

### 本 change 实现

1. 建立世界空间的 `ElementApplication` 数据，首批只服务地表反应：
   - 元素类型。
   - 强度。
   - 持续/暴露参数。
   - 世界范围。
   - 来源角色。
   - 来源 Ability Code。
2. 建立 `ElementReactionSystem`：
   - 统一接收元素施加。
   - 根据基础地表、有效地表、当前状态和数据化规则裁决结果。
   - 以固定模拟步长推进持续时间和到期反应。
   - 只推进当前存在计时状态的活跃格，不按固定步长扫描完整规则地图。
   - 通过 `AGameSystem` 地图生命周期显式绑定/解绑当前 `TerrainNavigationMap`。
   - 不新增 `GameManager.ElementReactionSystem` 静态快捷入口。
3. 将单格位标记字典升级为 `TerrainCellRuntimeState`：
   - 运行时状态以 `TerrainNodeKey = LayerId + Cell` 作为公共键。
   - 当前单层地图只接受默认层 ID，并保留 `Vector3Int` 到默认层键的兼容查询入口。
   - 在多层地形 change 正式落地前，非默认层键必须明确拒绝，不能伪装成已经支持重叠表面。
   - 有效地表覆盖。
   - 临时状态实例。
   - 强度。
   - 剩余时间。
   - 来源上下文。
   - 是否允许进入未来存档。
4. 建立数据化 `TerrainElementStateDefinition`：
   - 状态稳定类型。
   - 默认持续时间与合并策略。
   - 通行代价倍率。
   - 运行时实例只保存强度、剩余时间、来源和规则引用，不复制静态配置。
5. 建立数据化 `ElementReactionDefinition`，首批至少表达：
   - `Fire + Grass -> Burning`
   - `Water + Burning -> Wet + Extinguish`
   - `Electricity + Wet -> Electrified`
   - `Fire + Oiled -> stronger Burning`
   - `Burning grass cover expires -> remove grass cover / start regrowth`
6. 建立两层地表表现：
   - 临时效果层：当前只接入正式火焰；蒸汽、湿润、电流等状态等待正式素材。
   - 覆盖层结果：草覆盖层被移除后由底层土壤自然显露；不得使用结果覆盖 Tile 冒充。
   - 将现有 `TerrainNavigationMap.m_runtimeSurfaceVisualTilemap` 表现引用迁移到 `TerrainSurfacePresentation`，地图组件不再直接清空或写入表现 Tilemap。
7. 新增 EX-GAS 正式 Timeline Task：`TaskApplyWorldElement`。
   - 项目侧实现 Task 和 XParam。
   - 通过 EX-GAS Bean/Luban/代码生成入口注册。
   - 不手改生成 C#、生成 JSON 或生成 Bean。
8. 完成喷火竖切：
   - 使用独立喷火 Prefab 与通用 `TimelineActiveAbility` 运行桥，不复用近战语义 Prefab。
   - Timeline 片段按配置间隔向角色前方锥形区域提交 Fire。
   - 元素格解析服从规则 Tilemap 的同层和坡道连接。
   - 草覆盖层进入 Burning，燃烧结束后移除草覆盖层并开始再生；视觉露土必须移除草覆盖/植被层。
   - Burning 提高路径代价；新路径倾向绕开，首批不要求已执行路线自动重算。
   - Dirt 不再匹配 Grass 可燃规则。
   - 当前场景重载后会恢复作者绘制的原始地表；这只是首批实现限制，开放世界正式目标必须由后续持久地形变更机制保存“草被烧掉、露出土壤”等玩家造成的地貌变化。

### 本 change 不实现

- 第二套角色元素状态系统；角色伤害、持续状态、Tag 和属性修改继续使用 EX-GAS。
- 物体材质和天气条件的正式适配器；`ElementApplication` 只保留世界空间来源语义，首批只落地地形接收器。
- 火焰跨格自动传播、液体流动、导电网络、冻结和融化。
- 燃烧伤害、角色 GameplayEffect、物体耐久或建筑破坏。
- 地表运行时状态存档、跨地图保留或版本迁移。
- 多人同步、网络预测或联机占位层。
- 完整元素内容库、所有元素技能和最终商业特效。
- 已有路线的动态重新寻路。

## Responsibility Verdict

| 职责 | 正式 owner | 本次吸收什么 | 本次明确不吸收什么 | 验证入口 |
| --- | --- | --- | --- | --- |
| 基础地表、层级、坡道、阻挡 | 规则 Tilemap + `TerrainNavigationTile` | 作者绘制的 Grass、Dirt、Stone、ShallowWater、Mud 与连接规则 | 从视觉 Sprite、名称、颜色或 Sorting 推断玩法规则 | 地形测试场景规则 Tilemap |
| 元素输入 | `ElementApplication` | 元素、强度、范围、来源角色、来源技能 | 技能私有地表字典；技能直接改 Tile | `ElementReactionSystem.Apply(...)` |
| 反应裁决 | `ElementReactionSystem + ElementReactionDefinition` | 条件匹配、状态增删、强度/时间更新、到期转化 | Timeline、GameplayCue、表现脚本决定规则 | 规则合同验证 |
| 单格运行时状态 | `TerrainNavigationMap` 中以 `TerrainNodeKey` 索引的 `TerrainCellRuntimeState` | `LayerId + Cell` 节点身份、有效地表、临时状态实例、来源、剩余时间、存档策略；当前单层兼容 `Vector3Int -> 默认层` | 继续用 Flags 或平面格坐标作为长期唯一真相；在多层导航落地前假装支持非默认层；直接改共享 Tile 资产 | 节点键合同、地表查询与状态快照 |
| 状态静态语义 | `TerrainElementStateDefinition` | 默认持续时间、合并策略、通行代价倍率 | 每条反应重复保存 Burning 的代价逻辑；反应规则直接修改 cost map 数值 | 状态配置与代价恢复测试 |
| 区域格解析 | `TerrainNavigationMap` 的正式规则查询 | 世界锥形范围、格转换、同层/坡道合法连接过滤 | 物理碰撞层或视觉 Tilemap 猜地形层级 | 悬崖/坡道元素命中验证 |
| 地表表现 | `TerrainSurfacePresentation` | 临时效果 Tilemap、状态变化刷新 | 表现层回写规则状态；GameplayCue 改地表结果；用结果覆盖 Tile 冒充露土 | GameView 与 Tilemap 状态 |
| 角色伤害与角色元素状态 | EX-GAS `TaskApplyEffects` + `GameplayEffect` + Tag/Attribute | 喷火命中角色后的伤害、角色 Burning/Wet 等状态 | 在 `ElementReactionSystem` 或 `TerrainCellRuntimeState` 中保存角色状态；复制外部项目的单位状态框架 | EX-GAS Timeline、GE 配置与角色属性/Tag 变化 |
| 技能时序 | EX-GAS Timeline + `TaskApplyWorldElement` | 按片段与固定间隔提交元素 | 技能脚本写死草层销毁、露土或再生 | EX-GAS Timeline 与运行日志 |
| 喷射表现 | EX-GAS GameplayCue | 喷火动画、音效、喷射视觉和即时反馈 | 命中格裁决、燃烧计时、地表转化 | Cue 预览与真实技能 |
| 路径消费 | `TerrainNavigationMap` cost map | Burning 对新路径的动态代价修正 | 元素系统直接移动角色；首批自动重新寻路 | 路径结果对比 |

## First Vertical Slice

1. 玩家持续喷火，同一 EX-GAS Timeline 可用既有 `TaskApplyEffects` 处理角色命中/伤害，并由 `TaskApplyWorldElement` 在片段开始时立即向地表施加一次 Fire，之后按配置帧间隔重复施加。
2. 每次施加读取执行帧的角色位置与正式 2D 朝向，生成世界锥形范围。
3. `TerrainNavigationMap` 从施法者所在规则格开始，在锥形范围内按合法相邻边展开：
   - 同层格可连接。
   - 相邻层级只能通过坡道连接。
   - 悬崖正面、阻挡格和无规则 Tile 的格子不传播命中。
   - 这里的展开只用于判定本次喷火锥形内哪些格子能被合法命中，不代表 Burning 会自行跨格传播。
4. 命中的 Grass 根据规则进入 Burning；同一状态按规则刷新时间/强度，不创建重复状态真相。
5. 临时效果层显示格子火焰；GameplayCue 同时只显示喷射本体、声音和手感反馈。
6. Burning 存在期间提高该格路径代价；后续寻路结果倾向绕开燃烧区。
7. Burning 到期触发规则，移除 Grass 上层覆盖；底层 Dirt 不是新写入结果，而是作者已经存在的土壤底层。
8. 临时火焰覆盖清除；不得写入 Dirt/焦土结果覆盖。真正露土必须由草覆盖/植被层移除后露出原本存在的土壤底层。
9. 再次施加 Fire 时，无 Grass 覆盖的 Dirt 土壤不匹配 `Fire + GrassCover`，不会重新燃烧。
10. 当前重载场景后不读取元素存档，运行时覆盖清空，恢复规则 Tilemap 的原始 Grass；后续 `implement-persistent-world-terrain-mutation` 必须把“草层被移除后露出 Dirt”这类玩家造成的地貌变化写入世界变更存档。

## Acceptance Direction

- 喷火技能数据和执行代码中没有 `Grass -> Burning/Dirt` 的硬编码地表转化。
- `ElementReactionSystem` 是地表/世界状态元素施加的唯一正式入口，但不是角色 GameplayEffect 的替代入口。
- 角色伤害与角色元素状态继续通过 EX-GAS，项目中没有新增第二套角色状态容器或持续时间推进器。
- 规则 Tilemap 资产和基础 Tile 不被运行时修改。
- 火焰不能跨悬崖直接点燃高台；合法坡道连接范围内可以命中。
- 临时火焰由临时效果层承载；最终露土不是结果覆盖层，而是 Grass 覆盖层消失后露出底层 Dirt，状态清除不会自动恢复草层。
- Burning 的持续时间、强度、来源和剩余时间可从单格运行时状态读取。
- 不同层的同一格坐标不会共享运行时地表状态；当前单层地图只接受默认层，旧 `Vector3Int` 查询映射到同一默认层状态。
- Burning 期间的新路径代价高于普通 Grass；Dirt 不再按 Grass 可燃。
- 运行时代价由基础 Tile 代价和当前状态定义派生，反应规则不保存或累加第二份可变 cost 值。
- 固定步长只处理活跃计时格；地图未加载、正在卸载或游戏暂停时不推进状态。
- `TerrainNavigationMap` 不再拥有运行时表现 Tilemap，表现引用与清理由 `TerrainSurfacePresentation` 负责。
- 场景重载恢复原状只能作为当前限制记录，不能作为最终产品验收；持久开放世界必须另行实现并验证地貌变更存档。
- 首批状态、反应和表现配置在 `DatabaseRegistry` 中每个资产只登记一次；重复 GUID 或重复对象引用必须在运行验收前清理。
- 表现配置首批只要求 Burning 使用用户提供的正式火焰序列帧。Wet/Oiled/Electrified/Steam 和露土视觉没有正式素材或作者层级时必须阻塞，不能用占位图或空口径通过。
- EX-GAS Bean/Luban/注册生成链包含 `TaskApplyWorldElement`，生成文件没有手工修改。
- EX-GAS 原始 Ability/Timeline `20010` 与最终生成 C#、JSON、Task 注册和运行时 Timeline 数据一致。
- 喷火独立 Prefab 使用通用 `TimelineActiveAbility`，不以 `MeleeAttackAbility` 承担喷火语义，且该运行桥不包含元素反应或伤害规则。
- OpenSpec strict validate、编译敏感搜索、必要合同测试和真实喷火端到端全部通过后，才允许声明本 change 实现完成。
