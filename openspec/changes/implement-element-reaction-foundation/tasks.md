# Tasks: implement-element-reaction-foundation

## 1. Preconditions And Dependency

- [x] 确认 `ClickMoveTest` 已具备本 change 所需的规则 Tilemap、层级、坡道、阻挡和基础地表接线；`implement-realtime-terrain-navigation` 自身未完成项不得由本 change 代为宣称完成
- [x] 确认地形测试入口可以稳定查询基础地表和合法层级连接
- [x] 确认 EX-GAS 当前 BeanUpdater、Luban 和 Ability 注册生成链可正常运行
- [x] 确认喷火角色命中继续使用现有 `TaskApplyEffects` / GameplayEffect，不新增第二套角色状态或伤害入口
- [x] 记录喷火端到端使用的正式 Ability Code `20010`、Timeline ID `20010`、`ClickMoveTest` 玩家角色和元素地表运行时验收入口

## 2. Element Contracts And Rule Data

- [x] 新增仅面向世界空间/地表的 `ElementApplication`、元素类型、范围和来源上下文
- [x] 新增 `ElementReactionDefinition` 数据库资产类型
- [x] 新增 `TerrainElementStateDefinition`，集中保存默认持续时间、合并策略和通行代价倍率
- [x] 定义规则触发、条件、优先级和结果操作
- [x] 通过 `DatabaseRegistry` 建立稳定规则索引
- [x] 配置 Fire、Water、Electricity、Oil 和 Burning 到期的首批规则资产
- [x] 清理 `DatabaseRegistry.asset` 中 11 个元素资产的重复登记；序列化文本中每个 GUID 仅保留一条 key 和一条对象引用
- [x] 运行 `ProjectElementAssets_AreValidAndRegistered`，验证 4 个状态、6 个反应、表现配置和正式注册完整性
- [x] 验证重复规则稳定 ID 会明确失败，同优先级规则按稳定 ID 确定顺序

## 3. Terrain Cell Runtime State

- [x] 新增可兼容默认层的 `TerrainNodeKey`，避免长期以 `Vector3Int` 作为运行时地表状态公共键
- [x] 将运行时地表字典升级为 `Dictionary<TerrainNodeKey, TerrainCellRuntimeState>`
- [x] 保存有效地表覆盖、状态强度、剩余时间、来源和持久化策略
- [x] 运行时状态实例引用状态定义稳定 ID，不复制静态通行代价配置
- [x] 保留 `ETerrainRuntimeSurfaceState` 为只读派生兼容视图，停止把 Flags 当写入真相
- [x] 扩展 `TerrainSurfaceSample`，同时返回基础/有效地表和基础/有效通行代价
- [x] 确认运行时状态不会修改共享 `TerrainNavigationTile` 资产

## 4. ElementReactionSystem

- [x] 新增 `ElementReactionSystem : AGameSystem`
- [x] 使用现有泛型系统注册入口，不增加 GameManager 静态快捷属性
- [x] 实现元素施加、规则匹配、原子状态变更和状态变化事件
- [x] 实现固定模拟步长的持续时间推进
- [x] 维护只包含计时状态格的派生活跃索引，禁止固定步长扫描完整地图
- [x] 使用 `OnMapLoaded` / `OnMapUnloading` 显式绑定和解绑地图，`Update` 增加初始化、地图、暂停守卫
- [x] 实现重复状态刷新/强度合并
- [x] 实现 `OnStateExpired` 到期反应
- [x] 地图卸载时清理瞬态状态，不接入 SaveSystem

## 5. Terrain Area And Navigation Integration

- [x] 实现世界锥形范围到规则格的转换
- [x] 在锥形内按同层/坡道合法连接展开
- [x] 拒绝跨悬崖、Blocked、无规则 Tile 和非法层级边
- [x] 状态变化时从基础 Tile 代价和当前状态定义重新派生对应格 cost map
- [x] 配置 Burning 的 `4x` 高移动代价
- [x] 验证重复刷新 Burning 不会累计放大代价，Burning 清除后代价精确恢复
- [x] 验证新路径倾向绕开 Burning，且已执行路线首批不自动重算

## 6. Presentation

- [x] 新增 `TerrainSurfacePresentation`
- [x] 将 `TerrainNavigationMap.m_runtimeSurfaceVisualTilemap` 引用和 Tilemap 清理职责迁移到 `TerrainSurfacePresentation`
- [x] 重新接线正式地形场景，确认 Map 不再直接写入或清空表现 Tilemap
- [x] 将地表元素表现收敛为临时效果层；草燃尽不再使用最终结果覆盖 Tilemap
- [x] 创建首批地表元素表现配置资产
- [x] 移除前序自造的 `TerrainElementOverlays.png` 和湿润/油污/导电/蒸汽/焦土占位 Tile；首批只保留用户提供的火焰序列帧表现
- [x] 表现配置只填充 Burning -> 用户提供火焰序列帧；Wet/Oiled/Electrified/Steam 没有正式素材时不得配置占位表现
- [x] 为 Burning 火焰序列帧导入设置、动画 Tile 和表现配置稳定引用补资产合同测试；`TerrainElementPresentationTiles_UseProvidedFireSpriteSheetOnly` 已纳入 EditMode 复测
- [x] 重新进行真实 GameView / PlayMode 验收：验证 Burning 火焰临时效果、Grass 覆盖层移除或隐藏、底层 Dirt 自然显露；验收目标是运行时世界状态闭环，截图只作为辅助视觉证据
- [x] Burning 添加/移除时只刷新对应格临时效果
- [x] 禁止 Dirt/焦土写入结果覆盖层；Burning 清除后只允许清除火焰临时效果
- [ ] Water + Burning 的 Steam 表现等待正式蒸汽素材；当前只能验证规则信号，不配置占位图
- [x] 缺少表现资产时明确记录配置缺口，不修改规则结果

## 7. EX-GAS Timeline Task

- [x] 新增项目侧 `XParamApplyWorldElement`
- [x] 新增项目侧 `TaskApplyWorldElement`
- [x] `OnBegin` 立即提交，`OnTick` 按 `IntervalFrames` 重复提交
- [x] 明确 Begin/Tick 帧边界，保证开始帧不会被重复施加
- [x] 每次提交读取执行帧角色位置和正式 2D 朝向
- [x] Task 只构造 `ElementApplication`，不包含地表反应结果
- [x] Task 不处理角色伤害、角色 Tag 或角色持续状态；这些继续由 `TaskApplyEffects` / GameplayEffect 承担
- [x] 通过 BeanUpdater 更新原始 Bean 定义
- [x] 通过 Luban 生成 C# 与 JSON
- [x] 通过 EX-GAS 代码生成更新 Task 注册
- [x] 确认没有手改 `XAbility.gen.cs`、`XLuban.gen.cs` 或生成 JSON

## 8. Flamethrower Vertical Slice

- [x] 锁定地图正式来源场景为 `Demo - Forgotten Plains (Rule + Animated Tiles).unity`；来源 `Ground` 为 900 个有效格（830 格草坪视觉、70 格 Dirt），`GroundDecoration` 为 Unity 加载后的 267 个有效格（YAML 302 条记录包含重复/陈旧项）
- [x] 新建通用 `地表覆盖` Tilemap：617 格低地规则格基础层均为现有 Dirt，仅将 Git 迁移前确实显示草坪的 547 格原 Tile 逐格原样移动到同坐标覆盖层，保留原本 70 格裸 Dirt；不按规则名统一铺 Grass、不改变布局、不创建任何美术素材
- [x] 保持 `地表装饰` 与来源 `GroundDecoration` 的 267 个有效格逐格一致；元素拆层不得重命名、迁出或删除装饰层 Tile
- [x] 将 `TerrainNavigationMap` 从单一覆盖 Tilemap 升级为“地表语义来源层”：`地表覆盖` 作为 `SurfaceCover` 来源，`地表装饰` 作为 `Decoration` 来源；玩法是否可燃由 Tile 映射决定，不由层名决定
- [x] `TerrainNavigationMap` 在存在有效“地表语义来源层”时不再回落到旧单覆盖字段；旧字段仅服务没有新来源层的旧地图兼容
- [x] 将 `TerrainSurfacePresentation` 改为根据运行时样本里的来源 ID 隐藏/恢复真实来源 Tilemap；燃尽露土仍不使用 Dirt/焦土结果覆盖 Tilemap
- [x] 当前只把纯草类来源映射为 Grass 可燃/可销毁：`地表装饰` 的 `Rule Tiles/Grass.asset`、`地表装饰` 的标准 `Grass19_Minifantasy_ForgottenPlainsTiles_3.asset`，以及 `悬崖顶部装饰` 的 `Rule Tiles/Grass.asset`；`CobblestoneGrass Combo`、`LakeGrass`、`CliffGrass` 等复合 Tile 暂不接入可烧，避免整块隐藏石路、水岸或崖草
- [x] 高台规则资产明确保留为永久 `Grass` 结构地表，`CliffGrass` 复合 Tile 不进入可销毁覆盖层；未来若要支持高台草燃烧，必须先有正式可拆分素材再另做迁移，禁止 AI 造图或占位通过

- [x] 新增通用 `TimelineActiveAbility`，并保留 `MeleeAttackAbility` 为近战语义子类
- [x] 新增喷火独立 Prefab，使用 `TimelineActiveAbility` 而不是复用近战 Prefab
- [x] 新增 `FormalGasAbilityCodes.Flamethrower = 20010`
- [x] 在 EX-GAS 原始表建立喷火 Ability Code `20010` 和 Timeline ID `20010`
- [x] 在 `#exgas.abilityGameCore.xlsx` 将 `20010` 绑定到喷火独立 Prefab
- [x] 使用现有 `TaskApplyEffects` / GameplayEffect `2003` 配置 7 个角色命中帧
- [x] 在持续片段配置 `TaskApplyWorldElement` 的 Fire、强度、间隔和锥形参数
- [x] 完成正式生成后核对 Ability/Timeline `20010` 的生成 C#、JSON、Task 注册和运行时数据一致
- [x] 配置 GameplayCue 播放攻击动画和四方向喷火流视觉
- [x] 验证喷火 Cue 在正式 Ability 激活期间挂载到角色、读取正式朝向并在 Timeline 结束后销毁
- [x] 选择并导入 CC0 正式喷火音频，记录来源审计，创建并注册 `Flamethrower_AudioResolver.asset`，并通过 EX-GAS 原始表与 Luban 生成 JSON 接入 `CuePlayGameCoreAudio`
- [x] 修正 Timeline 音频片段 `1–1` 帧导致同帧 Begin/Finish、Cue 在消费前销毁的问题；在原始源表将结束帧改为 `60` 并通过正式 Luban 流程重新生成，未手改生成物
- [x] 验证正式 Ability 激活时 `CuePlayGameCoreAudio` 实际消费目标 Resolver 并播放 `Flamethrower_FireSpell03_CC0`；`Temp/ElementReactionAudioE2E.txt` 已记录 `resolverMatched=True`、`matchingSourceCount=1`、`playingMatchingSourceCount=1`
- [x] 用 `AudioPlaybackRequestedEvent` 探针记录持续喷火的音频请求次数与时间，并配对调用 `StopFireFormalGasAbility(20010)`；`Temp/ElementReactionAudioHoldProbe.txt` 记录请求发生在 1.050 秒和 3.253 秒，3.603 秒停止后新增请求为 0，确认第二次播放属于 `Auto` 输入门控的合法持续施法重启，不是单次 Ability 重复 Cue
- [x] 确认 GameplayCue 不修改 Tile、状态或地表类型
- [x] 地图恢复并通过来源逐格审计后，重新验证 Grass 覆盖命中后进入 Burning 并显示火焰覆盖；`test-results/evidence-runtime-validation/element-surface/clickmove-element-surface-q-wide-visual-runtime-20260713.json` 为 Success
- [x] 地图恢复并通过来源逐格审计后，重新验证悬崖另一侧高台不会被直接点燃；定向测试 CollectAffectedCells_RejectsHighGroundAcrossCliff 通过
- [x] 地图恢复并通过来源逐格审计后，重新验证合法坡道连接范围内的 Grass 可以被点燃；定向测试 CollectAffectedCells_ReachesHighGroundThroughRamp 通过
- [x] 地图恢复并通过来源逐格审计后，重新验证 Burning 到期后移除 Grass 覆盖层并露出原本存在的 Dirt 底层；q-wide PlayMode 验证 6 格草覆盖隐藏、底层 Dirt 可见且无结果覆盖 Tile
- [ ] 草覆盖层再生流程、再生进度和保存/加载由 `implement-persistent-world-terrain-mutation` 承接
- [x] 无草覆盖层的土壤格不会再次匹配有草覆盖可燃规则；q-wide 二次 Q 探针证明目标格保持 Dirt + 覆盖 Removed，`ReapplyBurningCellCount = 0`
- [x] 地图恢复并通过来源逐格审计后，重新验证场景重载后当前实现会恢复原始 Grass，并明确这只是首批未接持久化的限制；退出 PlayMode 后，地表覆盖 547 格均可见、临时/结果覆盖层均为空

## 9. Verification

- [x] 为规则顺序、状态合并、到期转化和灭火/导电补最小关键合同测试
- [x] 为悬崖/坡道锥形格解析补最小关键合同测试
- [x] 为动态路径代价补最小关键合同测试
- [x] 为活跃格调度、地图卸载停止 Tick 和代价精确恢复补最小关键合同测试
- [x] 为 `TerrainNodeKey` 补默认层兼容、跨层不相等、非默认层拒绝和旧 `Vector3Int` 查询一致性测试
- [x] 验证 EX-GAS Task 的间隔提交和无地表硬编码
- [x] 验证没有新增平行角色状态容器，角色元素效果仍走 EX-GAS
- [x] 在清理注册重复和填充表现映射后，重新运行四组定向 EditMode 测试并保存新鲜结果
- [x] 运行编译敏感搜索并检查生成物一致性
- [x] 地图恢复后重新在正式地形测试入口完成真实喷火端到端；新鲜结果 `test-results/evidence-runtime-validation/element-surface/clickmove-element-surface-q-wide-visual-runtime-20260713.json` 为 Success，旧截图和旧运行结果不作为通过证据
- [x] 重新审计 `ClickMoveTest.unity` 地图来源差异：`test-results/evidence-runtime-validation/element-surface/tilemap-source-audit-20260713.json` 记录当前可见地面以 `基础地面 + 地表覆盖` 组合对比来源 `Ground` 为 900/900 且差异 0，`地表装饰` 对比来源 `GroundDecoration` 为 267/267 且差异 0；此前“无需恢复旧场景”的旧审计结论废弃
- [x] 地图恢复后重新进入 PlayMode，验证正式 Q/EX-GAS 喷火、Burning 火焰、Grass 移除、Dirt 露出和场景重载恢复；运行时目标来自 547 格正式低地草覆盖，不依赖旧 6 格补丁
- [x] 地图恢复后重新生成元素地表视觉证据；新鲜图 clickmove-element-surface-q-wide-burning.png / clickmove-element-surface-q-wide-expired.png 已生成并通过轻量联系表核验
- [x] 新来源层相关 EditMode 覆盖已落到源码并复测通过：`ApplyFireToMappedDecorationLayer_AddsBurning`、`ConfiguredSurfaceLayerSources_DoNotFallbackToLegacyCover`、`LegacySurfaceCoverFallback_WorksWhenNoSurfaceLayerSourcesConfigured`；结果固化到 `test-results/evidence-runtime-validation/element-surface/editmode-ElementReactionSystemEditModeTests-20260714-surface-layer.json`
- [x] 用户指出视觉数量不一致后，修正表现层和验证器并重跑新分层 PlayMode 端到端：`test-results/evidence-runtime-validation/element-surface/clickmove-element-surface-q-wide-visual-runtime-20260714-visual-layer-fix.json` 为 Success，正式 Q/EX-GAS `TaskApplyWorldElement` 提交 Fire，6 个目标格 Burning，燃尽后 6 格 Grass 覆盖隐藏、底层 Dirt 可见，所有映射为地表覆盖语义的来源层可见残留为 0，二次 Q 提交 delta 为 1 且目标格 `ReapplyBurningCellCount = 0`
- [x] 用户追问残留花/草后，补全纯草映射并复验：`test-results/evidence-runtime-validation/element-surface/full-scene-vegetation-mapping-audit-20260714-after-pure-grass-mapping.json` 记录纯草疑似漏映射为 0，剩余未映射疑似项均为 `LakeGrass`、`CliffGrass`、`CobblestoneGrass` 这类复合视觉；`test-results/evidence-runtime-validation/element-surface/clickmove-element-surface-q-wide-visual-runtime-20260714-pure-grass-mapping.json` 为 Success，6 格 Burning、6 格露 Dirt、映射覆盖残留 0，预览相册已上传到 `http://8.148.71.102:18080/#/fantasyword/element-surface-q-wide-pure-grass-mapping`
- [x] 用户继续指出目标格仍有花后，确认该花不是 Tilemap 瓦片，而是手摆 `SpriteRenderer` 场景道具 `Flower (6)`，位于 q-wide 目标格 `(4, 12, 0)`；上一轮“独立道具隐藏”临时路线已废弃。本轮已将 `ClickMoveTest` 中 23 朵花和 10 处长草整体迁入统一 `地表植被覆盖` / `地表植被阴影` Tilemap，删除手摆自然植被对象，后续燃烧验收只消费 Tilemap 来源层和映射，不再保留独立花草特例。
- [x] 新分层场景审计已固化：`test-results/evidence-runtime-validation/element-surface/clickmove-scene-surface-layer-audit-20260714.json` 确认 `ClickMoveTest` clean、旧单覆盖字段为空、`地表覆盖` 与 `地表装饰` 两条来源有效，临时效果层和结果覆盖层均为 0 格
- [x] 2026-07-15 重构后最终审计：`test-results/evidence-runtime-validation/element-surface/clickmove-vegetation-tilemap-audit-20260715.txt` 确认 `地表植被覆盖=33`、`地表植被阴影=33`、手摆花草对象 0、花草 `SpriteRenderer` 0、缺脚本 0、`TerrainSurfaceLayerSource` 来源数 5，且植被覆盖/阴影排序为 -8/-7
- [x] 2026-07-15 重构后 q-wide PlayMode E2E 已复验通过：`test-results/evidence-runtime-validation/element-surface/clickmove-element-surface-q-wide-visual-runtime-20260715-tilemap-vegetation.json` 为 Success，正式 Q/EX-GAS `TaskApplyWorldElement` 提交 Fire，6 个目标格 Burning，燃烧期间临时火焰 6 格，燃尽后 6 格 Grass 覆盖隐藏并露出 Dirt，映射覆盖来源可见残留为 0，二次 Q 提交 delta 为 1 且 `ReapplyBurningCellCount = 0`
- [x] 2026-07-15 最终验收截图已生成并上传预览站：`Assets/Screenshots/ElementSurfaceE2E/clickmove-element-surface-q-wide-burning.png` 与 `Assets/Screenshots/ElementSurfaceE2E/clickmove-element-surface-q-wide-expired.png` 均为 1920x1080；预览相册为 `http://8.148.71.102:18080/#/fantasyword/element-surface-q-wide-tilemap-vegetation`
- [ ] Wet/Electrified/Steam 等其它元素表现等待正式素材后再验收，不能用占位图通过
- [ ] 新分层后的最终全量收口尚未完成：元素相关 EditMode 类级测试已通过，但完整 `FantasyWord.GameCore.EditModeTests` 当前仍因 `MeleeAttackAbilityEditModeTests.FormalGasAttackRuntimeInstance_UsesGasContextNotMigrationSheetFlag` 失败，不能称全量通过；结果保存在 `test-results/evidence-runtime-validation/element-surface/gamecore-editmode-20260713-element-surface.json`
- [x] 运行 `npx openspec validate implement-element-reaction-foundation --strict`
