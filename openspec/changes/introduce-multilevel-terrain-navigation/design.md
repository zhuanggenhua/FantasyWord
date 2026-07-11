# Design: introduce-multilevel-terrain-navigation

## Runtime Flow

```text
玩家点击屏幕
  -> 世界坐标 / 选择遮罩命中
  -> TerrainDestinationResolver 收集同格候选地形节点
  -> 结合当前实体层、可见优先级和可达性选出唯一目标节点
  -> TerrainNavigationMap 查询 TerrainNavigationGraph
  -> 图 A* 经过同层边与 TerrainTransitionLink
  -> 生成普通地面路径点 + 过渡中心线路径点
  -> Movable.MotionRuntime 连续执行
  -> 到达过渡提交点时 TerrainLayerState 原子切换节点层、碰撞带和表现带
```

## Authoring Model

### One Grid, Multiple Rule Layers

继续使用当前 Unity Grid 和 Tilemap 作者流程：

```text
地形Grid
  视觉_地面
  视觉_桥面
  视觉_桥前景
  碰撞_地面带
  碰撞_桥面带
  规则_地面
  规则_桥面
  选择_地面
  选择_桥面
  跨层连接
```

`TerrainNavigationMap` 显式持有 `TerrainNavigationLayerSource[]`。每个来源至少包含：

| 字段 | 含义 |
| --- | --- |
| `LayerId` | 逻辑地形层稳定 ID，例如 `ground`、`bridge-deck` |
| `RuleTilemap` | 该层的可行走、地表和基础代价作者数据 |
| `Elevation` | 该层相对玩法高度，用于过渡校验和调试 |
| `CollisionBand` | 该层使用的可复用地形碰撞带 |
| `PresentationBand` | 该层实体渲染排序基带 |
| `DestinationMask` | 可选的点击选择遮罩或选择碰撞入口 |

多个规则 Tilemap 属于同一个 `TerrainNavigationMap` 作者体系，不构成第二套地图真相。

### Current Single-Layer Migration

现有 `m_ruleTilemap` 迁移为一个 `LayerId = default` 的来源：

- 原有 `TerrainNavigationTile` 资产继续有效。
- 原有 `Elevation`、`RampDirection`、`SurfaceKind` 和 `TraversalCost` 保持语义。
- 迁移工具或序列化兼容代码只负责把旧引用包进默认层，不复制 Tile 数据。

## Data Model

### TerrainNodeKey

```text
TerrainNodeKey
  Cell: Vector3Int
  LayerId: TerrainLayerId
```

它表示一个具体可行走表面。桥面和桥洞可以拥有相同 `Cell`，但 `LayerId` 不同，因此导航、地表状态和调试信息不会混在一起。

`TerrainLayerId` 使用可审计稳定值，不使用 Tilemap 数组下标、GameObject 名称或 Unity Layer 编号。

### TerrainNavigationNode

运行时稀疏节点至少保存：

- `TerrainNodeKey`
- `Elevation`
- 基础地表和基础通行代价
- 当前有效通行代价
- 同层邻接边
- 跨层连接边索引

只为实际存在规则 Tile 的位置建立节点，不为每个平面格分配高度字典。

### TerrainTransitionLink

跨层连接是唯一正式高度切换 owner，至少保存：

| 字段 | 含义 |
| --- | --- |
| `FromNode` / `ToNode` | 两端地形节点 |
| `Kind` | Ramp、Stairs、Ladder、Drop 等 |
| `Bidirectional` | 是否允许双向通过 |
| `WorldWaypoints` | 入口、中心、出口等连续路径点 |
| `CommitPoint` | 实体正式切换逻辑层的位置 |
| `TraversalCost` | 过渡附加代价 |

当前由坡道格推断高度变化的逻辑在迁移后收口为链接数据。`RampDirection` 继续用于作者校验和中心线生成，但不再单独拥有跨层边的解释权。

## Navigation Graph

### Node And Edge Rules

- 同层相邻规则格生成普通边。
- 同一 `Cell` 的不同层不会自动连接。
- 只有 `TerrainTransitionLink` 可以生成跨层边。
- 动态地表状态修改节点代价，不修改节点身份。
- Blocked 或不存在规则 Tile 的位置不生成节点。

### Pathfinder Owner

当前第三方 A* 只接受二维 cost map，不能表达：

- 同一个格坐标的多个节点。
- 显式跨层边。
- 每条边不同的方向与中心线路径。

因此正式多层路线由项目侧 `TerrainNavigationGraph` 执行图 A*。不修改第三方插件源码，也不把二维矩阵与多层图长期保留成两个正式路径 owner。

### Path Output

图路径转换为连续世界路径：

- 普通边使用规则格中心或压缩后的转折点。
- 过渡边使用 `TerrainTransitionLink.WorldWaypoints`。
- 路径点携带可选的层切换提交标记。
- `Movable` 继续只执行世界路径点，不负责寻找图节点。

## Destination Resolution

### Candidate Collection

一个世界点击点可以得到多个 `TerrainNodeKey` 候选。解析顺序：

1. 优先使用命中的 `DestinationMask` 确定可见表面。
2. 若没有明确遮罩命中，优先当前实体所在 `LayerId`。
3. 若当前层没有节点，从剩余候选中选择唯一可达节点。
4. 多个候选都可达且没有明确可见优先级时，拒绝命令并在 Scene Gizmos 中显示候选，不固定取最高层或最低层。

多单位命令首批按单位当前层分别解析，不实现跨层编队整体最优解。

## Entity Layer State

`TerrainLayerState` 是玩家、NPC 和后续队伍单位共享的逻辑层状态：

- 当前 `TerrainLayerId`
- 当前 `TerrainNodeKey`
- 是否处于跨层过渡
- 当前碰撞带
- 当前表现带

层切换只发生在 `TerrainTransitionLink.CommitPoint`。导航状态、移动碰撞和渲染排序必须在同一次提交中更新，避免角色已经显示在桥上但仍与桥洞碰撞。

## Collision Bands

### Do Not Map Every Elevation To A Unity Layer

Unity 逻辑 Layer 总数有限，当前项目仅使用少量自定义层，但不能为每个海拔永久分配一层。

首批采用少量可复用碰撞带：

- `TerrainBand0`
- `TerrainBand1`
- 后续按实际重叠深度扩展，默认不超过四个

`TerrainLayerSource.CollisionBand` 与 Unity Layer 的映射集中在 `TerrainCollisionBandConfig`。不同地区只要不会在同一物理位置冲突，就可以复用碰撞带。

### Entity Collision Proxy

切换层时只修改角色用于地形阻挡的移动碰撞代理，不修改 Hitbox、Interaction、UI 或其它既有层。实施前必须审计当前角色 Prefab，确认移动 Collider2D 是否能独立放在子对象并保持同一 Rigidbody2D 所有权。

## Rendering

当前项目只有默认 Sorting Layer，首批不为每个地形层新建 Sorting Layer。

使用 `PresentationBand` 分配 Sorting Order 区间：

```text
FinalOrder = PresentationBandBase + SameLayerYSort
```

- `TerrainLayerState` 切层时更新角色 `SortingGroup` 或正式表现入口。
- 桥面、桥体和桥前景仍由视觉 Tilemap 分层。
- 同层实体继续使用现有 Y 排序规则。
- 渲染排序只消费逻辑层状态，不能反向决定导航或碰撞层。

## Element Surface Integration

运行时地表状态键迁移为：

```text
Dictionary<TerrainNodeKey, TerrainCellRuntimeState>
```

当前单层地图统一使用 `TerrainLayerId.Default`。

元素范围解析基于导航图展开：

- 同层元素只沿同层合法边传播。
- 不因同一 `Cell` 重叠而自动影响另一层。
- 是否允许沿楼梯、通风口或落差传播，由元素规则与过渡类型另行判断。
- 桥面 Burning、Wet、ScorchedDirt 与桥洞地面状态完全独立。

## Persistence

实体位置存档最终需要同时保存：

- 世界坐标
- `TerrainLayerId`
- 必要时保存当前过渡链接与进度

首批桥洞竖切至少保证重载后能从配置的检查点恢复到明确层；完整过渡中存档可后置，但不能只保存坐标后猜层。

## Migration Order

1. 新增 `TerrainLayerId`、`TerrainNodeKey` 和默认层兼容。
2. 把现有单层规则 Tilemap 包装成默认 `TerrainNavigationLayerSource`。
3. 将地表运行时状态与查询 API 改为节点键。
4. 建立稀疏图和图 A*，对默认层保持当前路线结果。
5. 新增 `TerrainTransitionLink`，迁移现有坡道中心线。
6. 新增实体 `TerrainLayerState`、碰撞代理和表现带。
7. 新增目的地候选解析与调试绘制。
8. 在 `ClickMoveTest` 建立桥洞验证区。
9. 多层闭环通过后，移除正式运行时对二维 A* cost map 的依赖。

## Bridge Vertical Slice

在现有移动测试场景内搭建：

```text
左侧地面 -> 左坡上桥 -> 桥面 -> 右坡下桥 -> 右侧地面
                    \ 桥洞下方地面直通 /
```

必须验证：

1. 地面到地面路线从桥洞穿过。
2. 地面到桥面路线经过左坡。
3. 桥面到地面路线经过右坡。
4. 桥上护栏只阻挡桥面实体。
5. 桥体前景正确遮挡桥洞中的角色。
6. 同一平面格可查询桥面和桥洞两个节点。
7. 桥面地表状态不影响桥洞。
8. Scene Gizmos 同时显示节点层、目标候选、路径和切层点。

## Failure Handling

- `LayerId` 重复：地图初始化失败并列出冲突来源。
- 同一层同一格出现多个规则来源：初始化失败，不按数组顺序覆盖。
- 过渡端点不存在：该链接无效并明确报错。
- 碰撞带未配置：该层不得进入正式运行，不回退 Default。
- 多候选点击无法裁决：命令失败并显示候选，不静默选择。
- 实体当前层与所在节点不一致：停止路径并报告状态错误，不按坐标猜层。
- 表现带缺失：导航状态保持，报告表现配置缺口；不得修改逻辑层掩盖。

## Validation

### Focused Contracts

- `TerrainNodeKey` 同格不同层不相等。
- 默认层迁移保持当前单层查询结果。
- 同层边不会自动连接同格其它层。
- 只有显式过渡链接允许跨层。
- 过渡路径正反向使用同一中心线。
- 多候选目标按遮罩、当前层和可达性稳定裁决。
- 桥面与桥洞运行时地表状态独立。
- 动态代价更新只修改对应节点。

### Scene Validation

- 复用 `ClickMoveTest`，不创建第二套测试地图真相。
- 验证导航、连续移动、碰撞、渲染排序和元素状态。
- 检查 Scene Gizmos、Console、序列化引用和场景 dirty 状态。
- 端到端截图仍按用户后续指令执行，本提案创建阶段不截图。

