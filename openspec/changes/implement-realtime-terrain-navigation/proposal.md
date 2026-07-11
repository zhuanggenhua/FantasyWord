# Proposal: implement-realtime-terrain-navigation

## Why

`ClickMoveTest` 已经具备自然平原、河流、悬崖、高台和坡道的 Tilemap 视觉地基，但当前点击移动仍然是“朝目标直线移动，碰到阻挡就停止”：

- 它不能像 RTS 一样自动绕过障碍。
- 点击高台时不会自动寻找坡道。
- 画面上的高低差尚未成为移动和地表查询的正式规则。
- 属性地表尚无统一查询入口，后续火、水、油、电等实时反应容易散落到具体技能或场景脚本。

用户已经明确：目标是《红警》类 RTS 语义的即时制、连续坐标移动，不是回合制格子战斗。Tilemap 格子只能作为地图制作、路径采样和地表状态的内部单位，不能成为玩家可感知的逐格行动规则。

## Current State Lock

- **问题对象**：`Assets/Scenes/ClickMoveTest.unity`、`CharacterMovement.HandleClickMove(...)`、`Movable.MotionRuntime`、当前自然平原 Tilemap 层级。
- **真相来源**：当前 Unity 场景层级、现有点击移动运行验证、Unity Tilemap 官方能力、仓库内 `AStar 2D Grid Pathfinding` 插件公开接口。
- **目标入口**：`MapInfo` 持有场景地形导航入口；`CharacterMovement` 继续接收正式玩家移动命令；`Movable` 继续拥有连续物理移动。
- **验收口径**：在 `ClickMoveTest` 中点击另一侧或高台目标，角色能实时计算路线并连续移动；存在坡道时自动经过坡道，不从悬崖正面穿越；不可达目标明确失败；运行时能查询当前地形层级和基础地表类型。

## Scope

本 change 首批实现：

1. 建立 Tilemap 作者面中的游戏规则层，记录可行走、地形层级、坡道和基础地表类型。
2. 将规则 Tilemap 转换成路径计算所需的可行走和代价数据。
3. 复用仓库内 A* 插件作为首批二维路径计算器，不修改第三方插件源码。
4. 扩展现有移动闭包，让同一条正式点击移动命令可以连续执行多个世界坐标路径点。
5. 在 `ClickMoveTest` 完成低地、高台、坡道和悬崖阻挡的即时制移动闭环。
6. 提供基础地表查询和运行时覆盖状态入口，为后续潮湿、燃烧、油污、带电等实时地表反应保留唯一正式入口。

本 change 不包含：

- 回合、行动点、逐格占位或战棋式高度规则。
- 队伍编队、单位避让、拥挤处理和大规模 RTS 性能优化。
- 暂停后排队命令、战术模式和队友 AI。
- 视线、远程命中、高地伤害加成和任务路径。
- 完整元素连锁、地表扩散、持续伤害和最终视觉特效。
- 室内多楼层在同一 XY 坐标重叠的导航。

## Responsibility Verdict

| 职责 | 候选来源 | 正式 owner | 本次吸收什么 | 本次明确不吸收什么 | 验证入口 |
| --- | --- | --- | --- | --- | --- |
| 地形规则作者数据 | 视觉 Tilemap、独立工具、规则 Tilemap | 项目侧规则 Tilemap + `TerrainNavigationMap` | 可行走、地形层级、坡道、基础地表类型 | 从 Sprite 排序猜玩法高度；自造独立地图编辑器 | `ClickMoveTest/自然平原测试地图/地形Grid` |
| 坡道路径语义 | Godot `handle_stairs_top_down`、普通格中心路径 | `TerrainNavigationTile.RampDirection` + `TerrainNavigationMap` | 吸收斜坡运动投影思想，生成方向明确的坡道中心线 | 按瓦片名判断、角色逐帧改速度、固定单一坡向 | 坡道方向 EditMode 测试与 Scene 路径 Gizmos |
| 路径计算 | 当前直线移动、仓库 A* 插件、3D NavMesh | `TerrainNavigationMap` 组织查询；A* 插件只算二维路线 | `AStarPathfinding` 的 bool/cost map 路径结果 | 插件示例场景、示例控制器、3D NavMesh、插件直接接管角色 | 路径验证器与运行时路径结果 |
| 连续移动执行 | A* 插件示例移动、项目 `Movable` | 项目现有 `Movable.MotionRuntime` | 沿多个世界路径点持续使用 `Rigidbody2D.MovePosition` | 新建平行角色控制器；按格瞬移 | 点击移动 PlayMode 验证 |
| 点击命令 | 测试面板、项目输入链、插件点击示例 | `PlayerCommandRequest -> CharacterMovement` | 现有正式点击命令入口 | 插件示例点击脚本；场景脚本绕过订单链 | `ClickMoveTestRuntimeValidator` |
| 属性地表状态 | 视觉 Tile、技能脚本、运行时地表状态 | `TerrainNavigationMap` 的地表查询与覆盖状态 | 基础地表类型、移动代价、运行时覆盖状态接口 | 让技能互相硬调；直接改写第三方原始 Tile | 地表查询 EditMode/PlayMode 验证 |

## Reference Verdict

### Unity Tilemap

采用：

- 同一 Grid 下的多 Tilemap 分层。
- `WorldToCell` / `GetCellCenterWorld` 作为世界坐标与规则格之间的正式转换。
- 自定义 `TileBase` 资产承载规则 Tile 数据。
- Tilemap Renderer、Sorting 和碰撞继续只承担画面与静态阻挡职责。

不采用：

- 把 Sorting Layer 当作玩法高度。
- 让视觉 Tile 的文件名、颜色或 Sprite 自动决定玩法规则。

### AStar 2D Grid Pathfinding

采用：

- `AStarPathfinding.GeneratePath(...)` / `GeneratePathSync(...)` 作为首批二维路径计算函数。
- bool/cost map 输入和坐标路径输出。

不采用：

- 插件示例场景、示例点击控制器和示例单位移动。
- 修改第三方插件源码。
- 把该插件当作地形层级、坡道、地表状态或角色运动 owner。

限制：

- 首批原型只覆盖户外 RTS 式抬高地形，不覆盖同一 XY 重叠楼层。
- 知乎桥洞方案中的 `Height2D`、动态碰撞层、动态排序层和多高度空间已记录为后续升级条件，不属于当前单层原型。
- 当前插件不支持自定义导航边；首批地图必须通过规则层中的不可行走悬崖带和可行走坡道走廊表达合法连接。
- 若后续地图证明二维 cost map 无法表达所需连接，再单独提案升级路径算法，不在本 change 中悄悄替换。

## Acceptance Direction

- 玩家点击可达高台后，路线自动经过坡道。
- 玩家不能从悬崖正面直接走上高台。
- 玩家点击被完全隔离的区域时，命令明确失败且角色不持续顶墙。
- 路径执行保持连续世界坐标移动，不出现逐格瞬移。
- 当前地形层级和基础地表类型可以从角色世界坐标查询。
- 方向移动仍可继续使用，不被点击寻路实现破坏。
- OpenSpec strict validate、Unity 编译、运行时移动验证和真实 GameView 截图全部通过后，才允许声明首批实现完成。
