# Proposal: implement-persistent-world-terrain-mutation

## Why

FantasyWord 的长期目标是玩家行为能对开放世界产生持久影响，类似 Minecraft。当前 `implement-element-reaction-foundation` 已经证明喷火可以通过统一元素规则让草地进入 Burning，但旧方案把“草被烧掉”误写成地表转换，且曾尝试用表现覆盖层冒充最终露土结果。

这不符合当前确认的世界模型。草不是地表本体，而是土壤上方的可销毁、可再生覆盖/植被层。烧毁草层后应自然露出下面原本存在的土壤；草层缺失、再生计时、挖掘、铺地、冻结水面、泥化等玩家造成的世界变化，应成为当前世界实例状态的一部分，能够保存、加载、参与导航和后续元素反应。

## Current State Lock

- **问题对象**：玩家造成的世界格变化，例如 `Burning grass cover -> remove grass cover / expose underlying soil / schedule regrowth`，以及后续挖掘、铺地、冻结、泥化等世界格改写。
- **真相来源**：
  - `TerrainNavigationMap` 当前基础规则 Tilemap 查询。
  - `TerrainCellRuntimeState` 当前临时状态和旧有效地表覆盖；后续需要拆出草覆盖层状态，避免继续用有效地表占位表达草层销毁。
  - `ElementReactionSystem` 当前元素反应裁决。
  - `TerrainSurfacePresentation` 当前临时效果层和独立覆盖道具显隐；结果覆盖层不得再作为露土真相。
  - `ClickMoveTest` 中喷火烧草的可运行竖切。
- **目标入口/环境**：
  - 作者底层地表/规则 Tilemap 是初始世界模板，土壤层本来存在。
  - 草覆盖/植被层是可被元素和工具销毁、可再生、可保存的世界层；它既可能来自 Tilemap 来源，也可能来自花、长草等独立 `SpriteRenderer` 场景道具。
  - 世界地形变更层保存玩家对覆盖层和地表层的改写，不直接破坏作者模板。
  - 运行时查询得到“底层地表 + 草覆盖层当前状态 + 已保存玩家改写”的当前世界格状态。
  - 表现层只消费当前世界格状态，不拥有保存数据。
- **验收口径**：玩家在测试场景中烧掉草层，保存/重载同一个世界后，该格草覆盖层仍处于已移除或再生中，底层土壤可见；未再生前不再按有草地块进入 Burning；导航和表现读取同一份当前世界格状态。

## Scope

本 change 负责：

1. 定义可持久化世界地形变更数据结构。
2. 定义作者模板 Tilemap 与玩家改写层的合成规则。
3. 让“草覆盖层被烧毁、底层土壤显露、草层等待再生”这类结果进入保存/加载闭环。
4. 保证元素反应、导航代价和表现层都读取同一份当前世界格状态。
5. 在测试场景完成“烧草 -> 保存 -> 重载 -> 草层仍缺失/再生中 -> 土壤仍露出”的闭环。

本 change 不负责：

1. 完整 Minecraft 式体素区块系统。
2. 无限世界生成。
3. 多人同步协议。
4. 编辑器地图制作工具重写。
5. 全部地形交互类型一次性完成。

## Design Direction

采用“作者模板 + 玩家改写层”的结构。当前 Tilemap 分层先按职责拆清楚，不按 Fire/Wet/Electricity 等元素反应类型继续开新 Tilemap：

| 层级 | 说明 |
|------|------|
| 寻路规则层 | `地形规则` / `TerrainNavigationTile` 定义可行走、层级、坡道、基础地表和基础通行代价；它不负责视觉，也不负责 Unity 物理碰撞。 |
| 物理碰撞/阻挡层 | 当前沿用作者场景做法：墙体、水体、悬崖等视觉 Tilemap 自带 `TilemapCollider2D + CompositeCollider2D + Rigidbody2D`；暂不新增独立 Collision Tilemap，除非后续阻挡语义需要脱离视觉 Tile。 |
| 基础视觉层 | `基础地面`、水、墙体、悬崖等作者绘制 Tilemap 负责初始画面和排序；不能从 Sprite 名称反推可燃、可挖或可再生语义。 |
| 地表语义来源层 | `TerrainSurfaceLayerSource` 把多个作者/表现 Tilemap 的特定 Tile 映射为草、花、苔藓、道路覆盖等玩法覆盖语义；花、长草等植被必须先进入统一 Tilemap / Palette 作者入口，再由映射决定是否参与元素反应，不走散落 `SpriteRenderer` 特例。 |
| 玩家改写层 | 保存按 `TerrainNodeKey`、来源 ID 记录的地表改写、覆盖层移除/再生状态、必要来源和版本；不直接破坏作者模板 Tilemap，也不能遗漏统一植被 Tilemap 来源。 |
| 当前世界格状态 | 运行时由底层地表、地表语义来源和玩家改写层合成，供元素反应、导航、脚步声和表现查询。 |
| 运行时表现层 | 临时火焰、蒸汽等只消费当前状态刷新 Tilemap；不保存、不裁决，也不靠结果覆盖 Tile 冒充露土。 |

首个竖切只要求“火烧毁草覆盖层、露出底层土壤、草层可再生”可持久化。后续再扩展 Mud/FrozenWater/建造铺地等结果。

当前 `ClickMoveTest` 已接线五条 Tilemap 地表语义来源：`sourceId=0` 的 `地表覆盖` 映射 547 格低地 Grass 覆盖；`sourceId=10` 的 `地表装饰` 映射纯 `Rule Tiles/Grass.asset` 和标准 `Grass19_Minifantasy_ForgottenPlainsTiles_3.asset`；`sourceId=20` 的 `悬崖顶部装饰` 映射纯 `Rule Tiles/Grass.asset`；`sourceId=30` 的 `地表植被覆盖` 映射花和长草 Tile；`sourceId=31` 的 `地表植被阴影` 映射对应阴影 Tile，使燃尽隐藏时同格阴影也一起退场。`CobblestoneGrass Combo`、`LakeGrass`、`CliffGrass` 等复合 Tile 暂不接入可烧，因为整块隐藏会同时烧掉石路、水岸或崖草这类复合视觉内容。

`2026-07-14` 的 `cover-props-fix` 证据已因临时独立道具通道废弃而降为历史背景，不能作为最终设计验收。`2026-07-15` 正向重构后，花和长草已回到统一 Tilemap 作者入口；同日 q-wide E2E 已证明正式 Q/EX-GAS 喷火仍能让目标 Grass 覆盖格进入 Burning，燃尽后隐藏所有映射为地表覆盖语义的真实来源层并露出底层 Dirt，二次 Q 不让已移除目标格复燃。这仍不是保存/加载闭环；本 change 的首要任务是把上述“覆盖层被移除”写入玩家世界改写层，并覆盖所有 Tilemap 地表语义来源。

## Acceptance

1. 喷火烧草后，目标格草覆盖层被移除或进入再生中，底层土壤可见。
2. 保存当前世界地形变更后重载，目标格仍保持草层缺失或再生进度，土壤仍露出。
3. 重载后再次施加 Fire，未再生草层的格子不再按“有草覆盖”进入 Burning。
4. 导航、移动代价和表现读取同一个当前世界格状态。
5. 作者模板 Tilemap 文件不被 PlayMode 直接改写。
6. 没有技能脚本直接写死“草层销毁”“露出土壤”或“草层再生”。
