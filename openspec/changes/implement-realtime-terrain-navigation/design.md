# Design: implement-realtime-terrain-navigation

## Runtime Flow

```text
玩家点击世界坐标
  -> PlayerCommandRequest
  -> CharacterMovement.HandleClickMove
  -> 当前 MapInfo 的 TerrainNavigationMap
  -> 世界坐标转换为规则 Tilemap 格
  -> 构建/读取可行走与代价图
  -> AStarPathfinding 计算格路径
  -> 格路径转换为连续世界路径点
  -> Movable.MotionRuntime 连续执行路径点
  -> Rigidbody2D.MovePosition 保持现有物理移动
```

## Authoring Model

### Visual Tilemaps

现有草地、水体、悬崖、墙体、阴影和装饰 Tilemap 继续负责画面与静态碰撞，不作为玩法高度真相。

### Rule Tilemap

在现有 `地形Grid` 下增加一个禁用 Renderer 的规则 Tilemap。该 Tilemap 使用项目侧 `TerrainNavigationTile`：

- `Walkable`：是否可以作为路径节点。
- `Elevation`：地形层级，首批使用非负整数。
- `SurfaceKind`：草地、泥土、浅水、石地等基础地表。
- `TraversalCost`：进入该格的相对路径代价。
- `TransitionKind`：普通地面、坡道、阻挡。
- `RampDirection`：坡道从低层到高层的视觉方向；首批支持东北、西北、东南、西南四种斜坡。

Tilemap 格只用于作者编辑和运行时查询。角色仍使用连续世界坐标移动。

## Scene Ownership

`MapInfo` 增加显式序列化引用：

- 当前场景的 `TerrainNavigationMap`。

`TerrainNavigationMap` 增加显式序列化引用：

- 规则 Tilemap。
- 可选运行时地表表现 Tilemap。

禁止运行时按名称寻找 Grid、Tilemap 或场景对象。

## Path Calculation

首批使用仓库内 `AStarPathfinding`：

- 地图数据按规则 Tilemap 当前边界生成。
- 不可行走格写入 `-1`。
- 可行走格写入至少为 `1` 的代价。
- 基础地表代价与运行时覆盖状态可提高代价，但不能隐式改变角色能力规则。
- 路径格转换为 `GetCellCenterWorld(...)` 世界点。
- 移除起点格，并对连续同方向路径点做简单压缩，减少格子折线感。
- 连续坡道格不直接沿 A* 的正交折线移动，而是按 `RampDirection` 投影为入口、中心、出口三点中心线。
- 正向和反向经过同一坡道时共用同一条中心线，只反转路径点顺序。

地形层级规则：

- 相同层级通过普通可行走格连接。
- 不同层级只能通过画在规则 Tilemap 中、且上坡方向匹配的坡道走廊连接。
- 悬崖正面和侧边在规则 Tilemap 中必须是不可行走带。
- 首批不支持同一 XY 坐标叠加多个可行走层。

## External Reference Absorption

### Godot: handle_stairs_top_down

参考：

- https://github.com/derdrache/tutorial_library/blob/main/2D/handle_stairs_top_down/stair_player.gd

当前直接吸收：

- 楼梯区域需要把普通正交输入或格路径投影到视觉斜坡方向。
- 斜坡方向属于地图作者数据，不属于某个角色控制器的临时判断。

本次不照搬：

- 不通过瓦片名包含 `stair` 判断坡道。
- 不在每个角色的物理帧中读取瓦片名并修改速度。
- 不使用固定 `SPEED / 1.3` 补偿，也不只支持单一坡向。

项目落点：

- `TerrainNavigationTile.RampDirection` 是坡向作者真相。
- `TerrainNavigationMap` 把 A* 正交坡道格转换为连续中心线。
- 玩家、NPC 和后续队伍命令继续消费同一世界路径，不增加角色私有楼梯逻辑。

### 知乎：2D Top-down 高度、桥洞与逻辑楼梯

参考：

- https://zhuanlan.zhihu.com/p/686230441

当前吸收：

- 玩法高度不能从贴图、排序层或角色视觉位置隐式猜测。
- 坡道、楼梯和梯子都应被视为明确的高度过渡连接。

正式记录但不在本阶段实现：

- `Height2D`：实体当前逻辑高度。
- 每个高度拥有独立碰撞层，实体只响应当前高度的碰撞。
- Sorting Layer / Order 随逻辑高度切换。
- “逻辑楼梯”两端触发实体高度切换。
- 同一平面坐标可存在多个高度空间，例如
  `Coordinate { X, Z, Dictionary<int, SpaceType> YSpace }`。

升级条件：

- 桥面与桥洞、城门上下层、室内多楼层等结构会让同一 XY 坐标出现多个可达高度。
- 当前二维 A* cost map 只能表达单层节点，不能正确表示上述结构。
- 后续正式 change 为 `introduce-multilevel-terrain-navigation`，负责多层节点、显式过渡、实体层状态、碰撞带、渲染排序和多候选点击。
- 不得在该 change 实施前把桥洞语义偷偷塞进当前单层原型。

## Movement Execution

`Movable.MotionRuntime` 继续是移动执行 owner：

- 单目标 `MoveTo` 行为保持兼容。
- 新增路径移动入口，内部持有路径点和当前索引。
- 每个 FixedUpdate 朝当前路径点移动。
- 到达当前点后推进到下一点。
- 任一点因碰撞无法继续时，整条路径失败并清理，不持续顶墙。
- 新移动命令覆盖旧路径命令。
- 方向输入覆盖并取消当前点击路径。

路径计算不直接移动 Transform，不接管 Rigidbody2D。

## Surface State

首批只建立唯一状态入口：

- `BaseSurfaceKind` 来自规则 Tile。
- `RuntimeSurfaceState` 来自运行时字典，键为规则 Tilemap 的 `Vector3Int` cell。
- 查询结果由基础地表和运行时覆盖状态组合。

首批允许：

- 查询当前角色脚下的地形层级、基础地表和运行时覆盖状态。
- 让路径代价读取地表结果。

首批不实现：

- 火焰扩散、液体流动、导电传播。
- 伤害、GameplayEffect、Cue 或最终特效。

这些反应后续必须消费同一地表查询，不得另建技能私有地表字典。

## Failure Handling

- 缺少 `TerrainNavigationMap`：点击移动沿用当前直接移动，记录为场景尚未接入导航；正式验收场景不得缺失。
- 缺少规则 Tilemap：明确报错，路径命令失败。
- 起点或目标不可行走：查找有限半径内最近可行走格；找不到则失败。
- A* 返回空路径：命令失败，角色保持原地。
- 路径执行中被新障碍阻断：当前路径失败；首批不做自动重新寻路。

## Validation

1. EditMode：
   - 世界坐标与格坐标转换。
   - 规则 Tile 解析。
   - 不可达目标返回失败。
   - 路径压缩不改变起终点。
   - 地表基础状态与运行时覆盖状态组合。
2. PlayMode / Editor 自动化：
   - 低地到低地绕障碍。
   - 低地到高台经过坡道。
   - 悬崖正面不可穿越。
   - 新命令覆盖旧路径。
   - 方向输入取消点击路径。
3. 画面：
   - 玩家连续移动，不逐格跳动。
   - 相机继续跟随。
   - 测试地图仍使用 MiniFantasy 自然平原画面。
