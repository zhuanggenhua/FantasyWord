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
- [x] 将临时效果 Tilemap 与最终结果覆盖 Tilemap 分开
- [x] 创建首批地表元素表现配置资产
- [x] 创建项目自有 `TerrainElementOverlays.png`，并将 Burning、Wet、Oiled、Electrified、ScorchedDirt 和 Steam 切分为 6 个正式 Tile 资产
- [x] 填充 Burning、Wet、Oiled、Electrified、ScorchedDirt 和 Steam 的状态/地表/短暂信号表现映射
- [x] 为新地表图集的导入设置、6 个 Sprite 切片和现有 Tile 的稳定引用补资产合同测试；`TerrainElementPresentationTiles_UseStableAtlasSprites` 已通过，相关测试为 7/7
- [x] 在真实 GameView 校准 6 个表现 Tile 的缩放、位置和最终观感；Burning、Wet、Oiled、Electrified、Steam 和 ScorchedDirt 均已完成真实画面核验，同尺度联系表位于 `test-results/evidence-image-validation/element-reaction-terrain-presentation/states-runtime/contact-sheet-six-states.png`
- [x] Burning 添加/移除时只刷新对应格临时效果
- [x] ScorchedDirt 写入结果覆盖层，Burning 清除时不删除焦土
- [x] Water + Burning 能触发一次短暂蒸汽表现信号
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
- [x] Grass 命中后进入 Burning 并显示火焰覆盖
- [x] 悬崖另一侧高台不会被直接点燃
- [x] 合法坡道连接范围内的 Grass 可以被点燃
- [x] Burning 到期后转化为 ScorchedDirt
- [x] 焦土不会再次匹配 Grass 可燃规则
- [x] 场景重载后恢复原始 Grass，明确尚未持久化

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
- [x] 在正式地形测试入口完成真实喷火端到端
- [x] 审计 `ClickMoveTest.unity` 保存后的大规模差异：只新增 20 个预期对象、没有删除旧对象、旧对象仅 5 处明确变化；约 899 格规则 Tilemap 解释主要新增行，两层运行时覆盖 Tilemap 为空，无需恢复旧场景
- [x] 退出 PlayMode 后从磁盘重新打开 `ClickMoveTest`，确认场景 clean、磁盘哈希保持 `E6A4BFE7CE5B221164C68E34081022E10487065BEF5A98A5148B0C5013810E11`，临时效果与结果覆盖 Tilemap 的已用 Tile 数量均为 0 且引用正确
- [x] 生成 Wet、Electrified 和六状态同尺度联系表，完成轻量真实 GameView 图面核验
- [x] 最终收口已完成：完整 GameCore EditMode 状态 `Passed`、失败/跳过为 0；元素职责搜索和 EX-GAS 边界为 0；最近 1 分钟 Console Error/Exception 为空；场景 clean、三类核心组件各一个、两张覆盖 Tilemap 均为空且磁盘哈希不变；完整 `git diff --check` 已执行并确认唯一失败是 `ClickMoveTest.unity` 的 Unity 历史空值尾随空格，排除场景后的 tracked 文本与本 change 未跟踪文本检查通过
- [x] 运行 `npx openspec validate implement-element-reaction-foundation --strict`
