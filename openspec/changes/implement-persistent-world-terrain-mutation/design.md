# Design: Persistent World Terrain Mutation

## Core Principle

玩家改变的是“世界实例”，不是直接破坏作者模板。作者 Tilemap 继续提供初始底层地表、规则和初始覆盖层；玩家造成的变化写入世界地形变更层。运行时任何系统查询地表/覆盖状态时，都读取合成后的当前世界格状态。

## Data Model

首批建议结构：

| 字段 | 含义 |
|------|------|
| `TerrainNodeKey` | 层 ID + 格坐标，兼容后续多层地形。 |
| `GroundSurface` | 当前底层地表，例如 Dirt、Mud、Stone、ShallowWater。烧草不改变这一层。 |
| `CoverKind` | 当前覆盖/植被类型，例如 GrassCover；没有覆盖时为空。 |
| `CoverState` | 覆盖层状态，例如 Alive、Burning、Removed、Regrowing。 |
| `RegrowRemainingTime` | 草层再生剩余时间；没有再生需求时为 0。 |
| `MutationKind` | 变化来源类型，例如 BurnedCover、Dug、Placed、Frozen。 |
| `Source` | 可选来源，例如技能、物品、角色或环境。 |
| `Revision` | 世界变更版本，用于脏标记和保存。 |

## Runtime Flow

1. `ElementReactionSystem` 仍然根据规则定义裁决 `Fire + grass cover -> Burning`，以及 `Burning grass cover expires -> remove cover / start regrowth`。
2. 如果反应结果属于持久世界变化，则提交到世界地形变更层，记录草覆盖层缺失或再生进度。
3. `TerrainNavigationMap` 查询当前世界格时，先取作者模板中的底层地表和初始覆盖，再叠加玩家改写层。
4. `TerrainSurfacePresentation` 根据当前覆盖状态隐藏/显示草层，让已有底层土壤自然露出；焦痕若需要，只作为短期视觉效果或附加装饰。
5. 保存系统只保存玩家改写层，不复制整张作者模板地图。

## First Vertical Slice

首批只实现一个明确闭环：

```text
喷火 -> 草覆盖层进入 Burning -> Burning 到期 -> 移除草覆盖层并开始再生
     -> 写入玩家改写层 -> 保存 -> 重载 -> 草层仍缺失/再生中，底层土壤仍可见
     -> 再生计时结束 -> 草覆盖层长回
```

## Constraints

- 不把表现 Tilemap 当保存真相。
- 不在 PlayMode 中直接保存修改作者场景 Tilemap。
- 不让喷火技能知道草层销毁、露土或再生结果。
- 不一次性承诺无限区块或多人同步。
- 不把临时 Burning 状态、持久草层缺失和草层再生进度混成同一种保存语义。
