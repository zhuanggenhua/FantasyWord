# Design: implement-element-reaction-foundation

## Runtime Flow

```text
EX-GAS Timeline
  -> TaskApplyEffects -> GameplayEffect -> 角色伤害/Tag/持续状态
  -> TaskApplyWorldElement
     -> 构造地表 ElementApplication
     -> GameManager.TryGetSystem<ElementReactionSystem>
     -> 当前 MapInfo 的 TerrainNavigationMap
     -> 规则格锥形解析 + 层级/坡道合法连接过滤
     -> ElementReactionDefinition 匹配
     -> TerrainCellRuntimeState 变更
     -> 地表查询/路径代价刷新
     -> TerrainSurfacePresentation 刷新临时效果层与结果覆盖层
```

两条 Timeline 轨道可以同时存在，但职责不重叠：EX-GAS 处理角色战斗效果，世界元素链只处理地表与其他未来世界状态。

## Ownership

### ElementReactionSystem

`ElementReactionSystem` 是 `AGameSystem`，负责：

- 从 `DatabaseRegistry` 建立 `ElementReactionDefinition` 规则索引。
- 接收 `ElementApplication`。
- 解析当前活动地图的 `TerrainNavigationMap`。
- 调用地图的合法区域格查询。
- 根据触发类型、元素、基础/有效地表和当前状态匹配规则。
- 以固定模拟步长推进状态剩余时间、周期反应和到期反应。
- 维护当前地图“有计时状态的格子”派生活跃索引，只推进活跃格。
- 产生状态变更结果并提交给地图。

它不负责：

- 保存基础地表。
- 直接修改 Tile 资产。
- 播放特效、声音或动画。
- 保存或推进角色 Burning、Wet 等状态。
- 计算角色伤害、修改角色 Attribute 或替代 EX-GAS GameplayEffect。
- 角色移动或路径执行。
- 每个固定步长扫描完整规则 Tilemap 或完整运行时状态字典。
- 暴露新的 `GameManager.ElementReactionSystem` 静态快捷入口。

调用方使用现有泛型系统注册入口：

```text
GameManager.TryGetSystem<ElementReactionSystem>(out ...)
```

生命周期：

- `OnSystemInit`：加载并验证 `ElementReactionDefinition` 与 `TerrainElementStateDefinition` 索引。
- `OnMapLoaded`：通过正式 `MapSystem` / `MapInfo` 入口绑定当前 `TerrainNavigationMap`，建立空的派生活跃索引。
- `Update`：只有系统已初始化、地图已绑定、未暂停且累积时间达到固定步长时才推进；使用活跃格快照，允许处理过程中增删状态。
- `OnMapUnloading`：停止推进、解绑地图事件并清空派生活跃索引。
- `OnSystemStop`：释放所有订阅；不得依赖脚本执行顺序或场景扫描恢复引用。

活跃索引只是可重建的调度缓存，不是状态真相；真实状态始终在 `TerrainCellRuntimeState`。

### TerrainNavigationMap

`TerrainNavigationMap` 继续是当前地图的统一地表查询和路径数据 owner，负责：

- 从规则 Tilemap 读取基础地表、层级、坡道、阻挡和基础通行代价。
- 保存 `Dictionary<TerrainNodeKey, TerrainCellRuntimeState>`；当前单层地图使用默认层 ID，避免把平面格坐标固化为长期公共键。
- 查询基础地表、有效地表、运行时状态和最终通行代价。
- 按单格状态变化增量刷新 cost map。
- 提供锥形区域内的规则格枚举和合法地形连接过滤。
- 发布单格状态变化事件。

它不负责：

- 决定 Fire + Grass 的结果。
- 推进状态时间。
- 播放视觉效果。
- 保存临时效果 Tilemap 或结果覆盖 Tilemap 引用。
- 直接清空、设置或刷新表现 Tilemap。
- 解释 Ability 或 GameplayCue。

现有 `m_runtimeSurfaceVisualTilemap` 字段和 `ClearRuntimeSurfaceStates()` 中的表现清理职责在实施时迁移到 `TerrainSurfacePresentation`。地图组件清理状态后只发布一致的状态变化/地图重置信号。

### TerrainSurfacePresentation

`TerrainSurfacePresentation` 是表现消费者，显式引用：

- `TerrainNavigationMap`
- 临时效果 Tilemap
- 最终结果覆盖 Tilemap
- 地表表现配置资产

它订阅单格状态变化并刷新对应格，不保存规则真相。

它同时接管当前 `TerrainNavigationMap.m_runtimeSurfaceVisualTilemap` 的序列化引用与清理职责；实施时必须在正式地形场景重新接线并验证，不能保留 Map 和 Presentation 两个表现 owner。

## Data Model

### ElementApplication

`ElementApplication` 是一次元素施加的不可变输入，至少包含：

| 字段 | 含义 |
| --- | --- |
| `ElementKind` | Fire、Water、Electricity、Oil 等元素输入 |
| `Intensity` | 归一化强度，首批按 `0..1` 使用 |
| `ExposureDuration` | 本次元素暴露语义，不等于最终状态持续时间 |
| `Area` | 点、圆、锥等世界范围；首批实现锥形 |
| `Origin` | 执行帧世界起点 |
| `Direction` | 执行帧正式 2D 朝向 |
| `SourceEntity` | 当前运行时来源角色/实体 |
| `SourceAbilityCode` | EX-GAS Ability Code；非技能来源允许为空 |

`ElementApplication` 是世界空间事件合同，不是通用角色状态容器，不包含 `Grass -> Burning` 或角色 GameplayEffect 结果逻辑。

### TerrainCellRuntimeState

每个发生运行时变化的地形节点保存一个 `TerrainCellRuntimeState`：

| 字段 | 含义 |
| --- | --- |
| `EffectiveSurfaceOverride` | 可选的运行时有效地表覆盖，例如 ScorchedDirt |
| `ActiveStates` | 当前状态实例集合，不再以 Flags 作为唯一真相 |
| `PersistencePolicy` | `Transient` 或未来可持久化；首批全部按 Transient |
| `Revision` | 状态变更版本，用于刷新和调试 |

每个状态实例至少包含：

| 字段 | 含义 |
| --- | --- |
| `StateKind` | Wet、Burning、Oiled、Electrified |
| `Intensity` | 当前强度 |
| `RemainingDuration` | 剩余持续秒数 |
| `Source` | 来源实体与 Ability Code |
| `AppliedRuleId` | 产生该状态的规则稳定引用 |

现有 `ETerrainRuntimeSurfaceState` 位标记可在迁移期保留为查询结果的派生兼容视图，但不得继续作为写入真相。

### TerrainElementStateDefinition

`TerrainElementStateDefinition` 保存状态类型的静态语义：

| 字段 | 含义 |
| --- | --- |
| `StateKind` | Wet、Burning、Oiled、Electrified 等稳定状态类型 |
| `DefaultDuration` | 规则未覆盖时使用的默认持续时间 |
| `MergePolicy` | RefreshDuration、KeepStronger、StackIntensity 或 Reject |
| `TraversalCostMultiplier` | 当前状态对基础通行代价的派生倍率；必须大于 0 |

运行时状态实例引用该定义的稳定 ID，只保存动态值。反应规则可以覆盖本次持续时间或强度，但不得复制或直接改写通行代价。

### TerrainSurfaceSample

统一地表查询结果升级为：

- NodeKey
- Cell
- LayerId
- Elevation
- BaseSurface
- EffectiveSurface
- BaseTraversalCost
- EffectiveTraversalCost
- RuntimeStateFlags（派生兼容）
- RuntimeStateSnapshot（只读快照）

### ElementReactionDefinition

`ElementReactionDefinition` 使用项目现有 `DatabaseEntry` / `DatabaseRegistry`，保证：

- ScriptableObject 可审计、可 diff。
- 通过资产 GUID 获得稳定引用。
- 元素系统初始化时从正式数据库建立索引。
- 后续 Mod 数据可以围绕同一稳定入口扩展。

规则至少包含：

| 类别 | 字段 |
| --- | --- |
| 触发 | OnElementApplied、OnStateExpired；首批不实现传播触发 |
| 输入条件 | ElementKind、最小强度 |
| 地表条件 | BaseSurface、EffectiveSurface |
| 状态条件 | Required、Forbidden |
| 优先级 | 显式整数，保证确定顺序 |
| 结果 | 添加/刷新状态、移除状态、修改强度、设置有效地表、发送表现信号 |

规则执行不得保存任意 C# 回调或场景对象引用。

## Rule Resolution

### Deterministic Order

1. 按触发类型筛选规则。
2. 按元素、地表和状态条件筛选。
3. 按 `Priority` 从高到低排序。
4. 相同优先级按规则稳定 ID 排序。
5. 将结果转换为一组状态变更操作。
6. 在同一格上原子提交，提交后只发布一次状态变化事件。

### State Merge

同一种临时状态每格只保留一个实例。

- 重复施加默认刷新剩余时间并取更高强度。
- 规则可以选择叠加强度、只刷新时间或拒绝覆盖。
- Fire + Oiled 的“强燃烧”通过规则输出修改 Burning 强度/持续时间，不写在技能中。
- Water + Burning 通过同一规则操作移除 Burning、添加/刷新 Wet，并发送一次蒸汽表现信号。

### Expiration

- `ElementReactionSystem` 使用可配置固定模拟步长推进状态。
- 每次状态提交后，根据是否仍存在计时状态更新派生活跃格索引；永久覆盖但无计时状态的 ScorchedDirt 不留在 Tick 集合。
- 固定步长对活跃格坐标做快照后推进，避免到期反应修改集合时破坏枚举。
- 游戏暂停或 `Time.timeScale == 0` 时，首批元素计时随游戏时间停止。
- 状态到期先触发 `OnStateExpired` 规则，再移除状态。
- `Burning Grass expires -> ScorchedDirt` 在同一原子变更中完成：
  - 移除 Burning。
  - 设置 EffectiveSurfaceOverride = ScorchedDirt。
  - 恢复或重算通行代价。
  - 发布一次格状态变化。

## Terrain Area Resolution

### Cone Query

`TaskApplyWorldElement` 不直接计算格子列表，只提交世界锥形参数。

`TerrainNavigationMap`：

1. 使用规则 Tilemap `WorldToCell` 取得施法者起始格。
2. 根据锥形包围盒取得候选规则格。
3. 过滤不在锥形几何范围内的格。
4. 从起始格在锥形范围内做有限距离相邻格展开。
5. 每条相邻边复用导航的层级连接语义：
   - 同层允许。
   - 层级差为 1 时必须经过 Ramp。
   - Blocked、无 Tile 或非法层级边拒绝。
6. 只返回同时满足几何范围和合法连接的格。

这样可以阻止火焰跨悬崖直接点燃高台，同时允许火焰沿合法坡道覆盖可达格。

这里的有限相邻格展开只是一次 `ElementApplication` 的命中合法性解析，不是 Burning 状态的自动传播算法。首批不会在后续固定步长中把火焰从一个燃烧格扩散到相邻格。

首批不使用 Physics2D 碰撞结果代替地形规则，也不从视觉 Tilemap 推断层级。

## Traversal Cost

运行时代价由基础代价和状态修正组合：

```text
EffectiveTraversalCost =
  BaseTraversalCost
  * Product(ActiveStateDefinition.TraversalCostMultiplier)
```

- Burning 首批配置为高代价但仍可行走。
- 首批 ScorchedDirt 只改变有效地表与视觉，不额外修改基础通行代价；未来若需要地貌代价表，另由明确的地表定义承担。
- 状态变化时只更新对应 cell 的 cost map。
- cost map 更新始终从基础 Tile 代价重新派生，不在旧值上连续乘除，避免重复施加和清除后的累计误差。
- 新路径请求读取最新 cost map。
- 已经执行中的路径首批不自动重新寻路。
- 元素系统不直接控制角色移动。

## Presentation Layers

### Temporary Effect Layer

用于：

- Burning 火焰
- Wet 湿润
- Electrified 电流
- Water + Burning 的短暂蒸汽

状态移除或短暂信号结束时清除。

### Result Override Layer

用于：

- ScorchedDirt 焦土
- 后续 Mud、FrozenWater 等最终运行时地貌

临时状态清除时不得清除最终结果覆盖。

### GameplayCue Boundary

喷火 Ability 的 GameplayCue 只负责：

- 角色喷火动画。
- 喷口/锥形火焰表现。
- 音效、震动和即时反馈。

每格 Burning、蒸汽、电流和焦土由 `TerrainSurfacePresentation` 根据世界状态驱动。GameplayCue 不调用 `SetTile`，不写地表状态，不决定反应结果。

## Evidence-Based Owner Decision

当前正式 owner 是对比基线，但不是不可重构的前提。执行顺序固定为：

1. 先按职责确认当前正式 owner、真实能力和已知缺陷。
2. 外部参考必须在同一职责、同一项目约束和同一验收入口下与当前 owner 比较。
3. 若参考方案的功能闭包、正确性、作者流程、测试性和长期维护收益明确覆盖迁移、兼容、许可证与回归成本，可以提出重构或替换。
4. 若没有证明确实更好，保留当前 owner；只对当前未覆盖缺口择优吸收。
5. 跨系统结果通过窄桥接进入各自 owner，不为了统一概念合并两套状态真相。

按这个顺序，本 change 的职责裁决为：

- Ability 激活、消耗、冷却、Timeline 时序、角色目标捕获、角色伤害、角色持续状态、GameplayTag、Attribute 和 GameplayCue 的当前正式 owner 是 EX-GAS；本次调研没有发现能在当前项目约束下证明整体替换 EX-GAS 更优的参考实现，因此不重构该职责。
- 世界规则格状态、地表反应、地貌覆盖和导航代价当前没有 GAS owner，由 `ElementReactionSystem` 补齐。
- 喷火同时命中角色与草地时，角色侧走既有 `TaskApplyEffects -> GameplayEffect`，草地侧走 `TaskApplyWorldElement -> ElementReactionSystem`。
- `TerrainCellRuntimeState` 只保存地形格状态，不镜像、不缓存角色上的 GAS 状态。
- 未来若燃烧地面需要对站立角色施加伤害，应由地表接触适配器调用正式 GAS GameplayEffect 入口；元素系统不自行保存角色伤害周期或角色状态持续时间。
- 外部参考当前只在世界地表缺口上提供了明确增益；若未来出现可证明整体优于 EX-GAS 某项职责的方案，应另做同职责对比和迁移裁决，而不是被“GAS 已存在”永久排除。

## EX-GAS Integration

### Ability Runtime Bridge

项目侧主动技能 Prefab 使用通用 `TimelineActiveAbility` 作为 EX-GAS Timeline 输入门控和中断桥：

- 喷火使用独立 `Assets/Prefabs/Abilities/World/喷火.prefab`，不能复用 `MeleeAttackAbility` Prefab。
- `TimelineActiveAbility` 只解析正式 GAS Ability Code 对应的 Timeline 输入门控、使用间隔和中断。
- 技能时序、消耗、冷却、角色命中、伤害、元素施加和 Cue 仍由 EX-GAS 数据与 Task 拥有。
- `MeleeAttackAbility` 只保留为通用桥的近战语义子类，维持原近战 Prefab 和脚本 GUID，不把近战名称扩散到其他 Timeline 技能。
- 通用桥不得出现 Fire、Grass、Burning、ScorchedDirt、GameplayEffect `2003` 或喷火锥形参数。

这项拆分只消除喷火复用近战组件的错误语义，不创建第二套 Ability 执行框架。

### Project-side Runtime Types

新增项目侧：

- `TaskApplyWorldElement : AbilityTaskBase<XParamApplyWorldElement>`
- `XParamApplyWorldElement : XParam`

Task 行为：

1. `OnBegin` 立即提交一次。
2. `OnTick` 仅在 `frameIndex > startFrame` 且 `(frameIndex - startFrame) % IntervalFrames == 0` 时重复提交，避免开始帧被 Begin/Tick 双重施加。
3. 每次提交重新读取执行帧的角色位置和正式 2D 朝向。
4. 缺少来源实体、正式朝向、当前地图、规则 Tilemap 或 `ElementReactionSystem` 时明确报错并跳过本次提交。
5. 不直接读取或修改 Grass、Burning、ScorchedDirt。

参数首批包含：

- ElementKind
- Intensity
- ExposureDuration
- IntervalFrames
- ConeRange
- ConeHalfAngle

首批 Task 语义固定为 Terrain，不提前增加角色/物体目标枚举。角色命中继续配置 `TaskApplyEffects`。

### Generation Flow

新增 Task 后必须使用现有正式生成链：

1. EX-GAS BeanUpdater 扫描项目侧 Task 与 XParam。
2. 更新原始 `__beans__.xlsx` / Luban 定义。
3. 运行 Luban 生成 C# 与 JSON。
4. 运行 EX-GAS Ability 代码生成，自动更新 Task 注册。
5. 在 Timeline 原始数据中配置 `TaskApplyWorldElement`。

禁止手改：

- `Assets/Scripts/Gen/XAbility.gen.cs`
- `Assets/Scripts/Gen/XLuban.gen.cs`
- `Assets/DataGenerated/Luban/CSharp/*`
- `Assets/DataGenerated/Luban/Json/GAS/*`

### Timeline Cue Lifetime

- 需要被显示系统、音频系统或其他异步消费者实际处理的 GameplayCue，Timeline 原始片段必须拥有可消费的非零生命周期；不得用同一帧 Begin/Finish 的 `1–1` 片段证明运行时 Cue 已接入。
- Cue 时长、Ability 时长和持续施法重启语义都以 EX-GAS 原始表为作者真相；发现时长错误时先修原始表，再通过 Luban 正式生成，不修改生成 JSON 止血。
- 正式喷火音频使用 `1–60` 帧 Cue 片段。单次 Ability 的音频请求次数通过 `AudioPlaybackRequestedEvent` 观察；若按住输入会启动下一轮 Ability，应通过 `StopFireFormalGasAbility` 验证停止后不再产生新请求，不能只凭时间采样把合法重启误判成重复 Cue。

## Initial Rule Set

首批规则资产至少覆盖：

| 触发 | 条件 | 结果 |
| --- | --- | --- |
| Fire applied | EffectiveSurface = Grass，且没有不可燃覆盖 | 添加/刷新 Burning |
| Water applied | 当前有 Burning | 移除 Burning，添加/刷新 Wet，发出 Steam 信号 |
| Electricity applied | 当前有 Wet | 添加/刷新 Electrified |
| Fire applied | 当前有 Oiled | 按规则增强 Burning |
| Burning expired | BaseSurface = Grass，且有效地表仍可烧毁 | 设置 ScorchedDirt |

具体持续秒数、强度倍率和移动代价倍率属于数据调参，不写死在 Ability Task。

## Directory Direction

建议落点：

- 系统宿主：`Assets/Scripts/GameCore/Runtime/Game/Systems/ElementReactionSystem.cs`
- 数据资产：`Assets/Scripts/GameCore/Runtime/Database/Elements/`
- 元素输入与规则合同：`Assets/Scripts/GameCore/Runtime/Elements/`
- 地图运行时状态：`Assets/Scripts/GameCore/Runtime/Maps/`
- EX-GAS 项目扩展：`Assets/Scripts/GameCore/Runtime/Combat/GAS/`
- 地表表现：`Assets/Scripts/GameCore/Runtime/Presentation/`
- 规则与表现资产：`Assets/GameData/Elements/`
- 验证：复用现有地形测试入口，不新建第二套地图真相或平行导航场景。

若现有 asmdef 依赖不允许该目录关系，实施前先按当前程序集边界调整文件位置；不得为了目录好看新建循环依赖或平行 facade。

## Failure Handling

- 缺少 `ElementReactionSystem`：Task 明确报错，本次元素不生效。
- 缺少活动 `MapInfo` / `TerrainNavigationMap`：明确报错，不回退到场景扫描。
- 来源位置不在有效规则格：本次地形元素失败，不猜最近格。
- 规则配置为空或重复冲突：系统初始化失败并列出规则稳定 ID。
- 状态定义缺失、重复或通行倍率非法：系统初始化失败，不用默认倍率继续运行。
- 同一个元素状态、反应或表现资产在 `DatabaseRegistry` 重复登记：视为数据完整性失败；先清理到每个资产只登记一次，再运行资产合同和系统初始化验证。
- 表现配置缺失：规则状态继续成立，记录表现缺口；不得回滚世界状态或自动找替代 Tile。
- 表现配置资产存在但状态、地表或短暂信号映射为空：只能视为配置骨架存在，不得进入真实视觉验收。
- 生成产物缺少 `TaskApplyWorldElement`：视为 EX-GAS 接入失败，不手改生成代码止血。
- EX-GAS 原始表已存在 `20010` 或 `TaskApplyWorldElement` 行，但生成 C#、JSON 或注册仍缺失：只能视为作者数据已录入，不得宣称运行时接入完成。

## Validation

### Static

- 搜索 Ability、Task、Cue 和表现层，确认没有 `Grass -> Burning/ScorchedDirt` 直接分支。
- 搜索生成目录，确认没有手工修改标记或旁路注册。
- 确认规则 Tile 资产不被 `SetTile` / 替换 API 修改。
- 确认不新增 `GameManager.ElementReactionSystem` 静态快捷入口。
- 确认没有新增角色状态容器、角色元素 Tick 或绕过 GameplayEffect 的角色伤害入口。
- 确认喷火 Prefab 使用 `TimelineActiveAbility` 而不是 `MeleeAttackAbility`，且通用桥不包含喷火或地表反应规则。

### Focused Contracts

仅为高风险核心合同补少量测试：

- 规则优先级和稳定顺序。
- 重复状态的刷新/合并。
- Burning 到期转化 ScorchedDirt。
- Water 灭火和 Electricity + Wet。
- 锥形格查询不能跨悬崖，能经过合法坡道。
- Burning 状态变化会更新对应格路径代价。
- EX-GAS Task 按片段帧间隔提交，且不包含地表结果逻辑。
- 同一喷火 Timeline 的角色命中仍通过 `TaskApplyEffects` / GameplayEffect，世界元素 Task 不处理角色状态。
- 首批 4 个状态、6 个反应和 1 个表现配置资产均可验证，且在 `DatabaseRegistry` 中每个资产只登记一次。
- Burning 正式状态资产的通行代价倍率为 `4x`，表现配置包含状态、焦土和蒸汽映射。

### End-to-End

在完成规则 Tilemap 接线的正式地形测试入口：

1. 给角色配置喷火 EX-GAS Ability / Timeline；角色命中使用现有 `TaskApplyEffects`，地表命中使用 `TaskApplyWorldElement`。
2. 对低地 Grass 持续喷火。
3. 观察合法锥形格进入 Burning。
4. 确认高台不会被跨悬崖点燃。
5. 确认合法坡道连接的格可以被覆盖。
6. 对比燃烧前后的新路径选择。
7. 等待燃烧结束，确认火焰层清除、焦土层保留。
8. 再次喷火，确认焦土不重新燃烧。
9. 重载场景，确认恢复作者 Grass。
10. 检查 Console、场景 dirty 状态和生成数据一致性。
