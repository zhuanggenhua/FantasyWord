# Proposal: introduce-multilevel-terrain-navigation

## Why

当前 `implement-realtime-terrain-navigation` 已能表达户外低地、高台、悬崖和斜坡，但它仍有一个明确边界：同一个 Tilemap 平面格只能存在一个可行走节点。

这个边界无法覆盖项目后续必然出现的场景：

- 桥面可走，桥洞下方也可走。
- 城门上方城墙可走，城门内部也可走。
- 建筑二层、阳台、地下通道和地面在画面投影上重叠。
- 桥面燃烧时，桥洞下方地面不能共享同一份地表状态。
- 玩家、NPC 和实时队伍命令必须能在不同逻辑层之间寻路，而不是通过切换碰撞盒制造视觉假象。

因此需要独立 change，把当前单层规则 Tilemap 升级为多层地形节点和显式跨层连接。该 change 不另造一套地图编辑器，继续以 Unity Grid、Tilemap、场景组件和 `TerrainNavigationMap` 为唯一正式作者入口。

## Project Tier

长期项目。多层地形会同时影响导航、点击目标解析、碰撞、渲染排序、元素地表、交互和存档，不能作为桥洞场景的局部脚本处理。

## Current State Lock

- **问题对象**：`TerrainNavigationMap`、`TerrainNavigationTile`、`TerrainSurfaceSample`、地表运行时状态、角色连续移动闭包，以及 `ClickMoveTest` 中后续新增的桥洞验证区。
- **真相来源**：当前单层导航实现、现有规则 Tilemap、用户提供的桥洞/逻辑高度文章、Godot 楼梯运动投影示例、当前 Unity Layer 与 Sorting Layer 配置。
- **目标入口**：现有 `TerrainNavigationMap` 升级为多层地形统一 owner；现有 Grid/Tilemap 继续承担作者编辑；`Movable` 继续承担连续移动。
- **验收口径**：在 `ClickMoveTest` 内完成一座可从两侧上下、且中间桥洞可穿行的小桥；桥面和桥洞导航、碰撞、点击、遮挡及地表状态彼此独立。

## Scope

本 change 包含：

1. 用“格坐标 + 地形层 ID”唯一标识可行走地形节点。
2. 让一个 `TerrainNavigationMap` 管理多个规则 Tilemap 层，保持单一作者体系。
3. 建立显式跨层连接，表达坡道、楼梯、梯子和其它高度过渡。
4. 将二维 cost map 升级为可表达同格多节点的稀疏导航图。
5. 为移动实体建立当前地形层状态，并同步地形碰撞带与渲染排序带。
6. 建立多候选目标解析，禁止同一点击点存在多个地形节点时静默猜测。
7. 将运行时地表状态与元素反应键迁移到具体地形节点。
8. 在现有 `ClickMoveTest` 内建立桥洞竖切，不新增平行导航测试场景。

## Out Of Scope

- 自由 3D 跳跃、飞行、抛物线落地和完整三维物理。
- 任意数量的同时重叠物理层；首批只保证桥面/桥洞两层闭环，并预留少量可复用碰撞带。
- 大规模 RTS 编队跨层调度、单位拥挤和局部避障。
- 程序化地图生成器或独立于 Unity Tilemap 的自研地图编辑器。
- 地下世界流式加载、室内外无缝分区和完整地形状态持久化。

## Responsibility Verdict

| 职责 | 候选来源 | 正式 owner | 本次吸收什么 | 本次明确不吸收什么 | 验证入口 |
| --- | --- | --- | --- | --- | --- |
| 多层地形作者数据 | 单一规则 Tilemap、自研编辑器、多个规则 Tilemap | `TerrainNavigationMap` 管理的规则 Tilemap 层集合 | 每层独立 `LayerId`、规则格、碰撞带和表现带 | 第二套地图编辑器；从视觉 Sprite 或名称推断玩法层 | `ClickMoveTest/地形Grid` |
| 地形节点身份 | `Vector3Int`、高度字典、稀疏节点键 | `TerrainNodeKey` | 格坐标与逻辑层共同组成稳定节点身份 | 每格分配高度字典；把 Unity Layer 当节点 ID | 单元测试与桥面/桥洞同格查询 |
| 跨层连接 | 坡道 Tile 推断、触发器、显式链接 | `TerrainTransitionLink` | 双向/单向端点、类型、中心线路径点和切层时机 | 角色脚本私自切层；通过碰撞结果猜高度 | 坡道、楼梯、梯子合同测试 |
| 路径计算 | 当前二维 A* cost map、多层图 A*、3D NavMesh | `TerrainNavigationGraph`，由 `TerrainNavigationMap` 构建和查询 | 同格多节点、显式边、动态代价 | 修改第三方 A* 源码；3D NavMesh 接管 2D 地形 | 桥面/桥洞路线测试 |
| 连续移动 | 过渡链接移动器、现有 `Movable` | 现有 `Movable.MotionRuntime` | 消费图路径产生的连续世界路径点 | 新建多层专用角色控制器 | 当前点击移动命令链 |
| 实体当前层 | 角色 Transform、碰撞层、独立逻辑状态 | `TerrainLayerState` | 当前节点层、过渡中状态、碰撞带和表现带切换 | 以 Sorting Order 或 GameObject Layer 作为唯一真相 | 玩家与 NPC 同层状态测试 |
| 地形碰撞 | 每高度一个 Unity Layer、动态 IgnoreCollision、复用碰撞带 | `TerrainCollisionBandConfig` + 层级碰撞 Tilemap | 少量可复用碰撞带，实体只切换移动碰撞代理 | 为每个海拔永久占用一个 Unity Layer | 桥上护栏与桥洞通行 |
| 渲染排序 | 多 Sorting Layer、单层 Y Sort、逻辑表现带 | `TerrainLayerPresentation` | 逻辑层排序带 + 同层 Y 排序 + 前景遮挡层 | 从渲染顺序反推导航层 | 桥洞遮挡与桥面角色显示 |
| 点击目的地 | 单一 `WorldToCell`、当前层优先、选择遮罩 | `TerrainDestinationResolver` | 候选节点集合、可见选择遮罩、当前层与可达性裁决 | 多候选时固定取最高层或最低层 | 同投影点双层点击测试 |
| 地表运行时状态 | `Dictionary<Vector3Int,...>`、每层私有字典、节点键字典 | `TerrainNavigationMap` 的节点状态表 | `TerrainNodeKey -> TerrainCellRuntimeState` | 桥面与桥洞共享状态；技能私有地表字典 | 桥面燃烧不影响桥洞 |

## Reference Matrix

| 参考 | 证据等级 | 命中职责 | 可吸收内容 | 不作为依据的内容 |
| --- | --- | --- | --- | --- |
| 知乎 2D Top-down 高度与桥洞文章：`https://zhuanlan.zhihu.com/p/686230441` | 用户提供完整正文，概念级 | 逻辑高度、分层碰撞、动态排序、桥洞问题 | 明确同一投影点可能存在多个可达表面；高度切换必须是正式状态 | 不直接采用每个坐标的 `Dictionary<int, SpaceType>` 作为运行时地图结构 |
| Godot 楼梯示例：`https://github.com/derdrache/tutorial_library/blob/main/2D/handle_stairs_top_down/stair_player.gd` | 可读取源码，局部实现级 | 坡道内运动投影 | 高度过渡区域需要约束运动方向 | 瓦片名判断、角色逐帧改速度、固定单坡向 |
| 当前 `TerrainNavigationMap` | 当前正式实现 | 作者入口、地表查询、路径查询 | 保留现有 Tilemap 作者流程和连续移动闭包 | 当前二维矩阵不能继续作为多层图正式数据结构 |

## Dependency And Sequencing

1. 当前 `implement-realtime-terrain-navigation` 先完成单层路线、坡道方向和调试绘制验证。
2. `implement-element-reaction-foundation` 在创建丰富地表状态字典时，不得把 `Vector3Int` 固化为长期公共键；应使用可兼容默认层的 `TerrainNodeKey`。
3. 多层图落地后，当前第三方二维 A* 不再承担正式多层路线计算；迁移期间不得长期保留两个正式路径 owner。
4. 桥洞竖切通过后，再评估城门、室内楼层和地下通道，不在首批同时铺开全部场景。

## Acceptance Direction

- 地面单位可以从桥洞穿过，不与桥面护栏或桥面单位的地形碰撞发生冲突。
- 地面单位点击桥面目标时，路线通过合法坡道上桥；桥面单位可以从另一侧下桥。
- 同一平面格的桥面和桥洞返回不同 `TerrainNodeKey`、地表状态和路径节点。
- 多候选点击必须通过选择遮罩、当前层和可达性得到确定结果；仍然歧义时明确拒绝并绘制调试候选。
- 桥面燃烧、潮湿或焦土变化不会修改桥洞下方节点。
- 实体切层时，导航层、移动碰撞代理和渲染排序在同一个过渡提交点更新。
- 当前单层地图通过默认层适配继续运行，不要求重新绘制全部规则 Tile。

