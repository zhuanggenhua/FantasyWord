# 2026-06-17 2D移动与场景组织交接

## 当前任务边界

这一条线当前只做：

- 参考裁决
- 缺口登记
- 文档和 spec 收口
- 对已有参考结论做最小纠偏，不新增运行时代码

这一条线当前不做：

- 没有参考的实现
- 兼容层、空宿主、并行控制器
- 为了“看起来能跑”先补临时壳子

## 当前任务不是端到端验证

- formal scene 最小 PlayMode smoke 已经补过，它现在只是“当前没有新的即时阻断”的事实留档。
- 这条线当前不以追加端到端、补 Unity 冒烟或继续追场景可玩链作为主任务。
- 只有后续真的新增运行时代码、改正式场景接线，或用户明确要求复核某条玩家链路时，才再决定要不要补新的 smoke。

## 当前已经成立的事实

- 项目里已经有正式移动壳子，不是“没有控制器”：
  - `Movable`
  - `PlayerController`
  - `Directional`
  - `ClickToMove`
- 当前场景组织口径仍是：
  - `Game Manager + 场景级系统对象平铺 + 预摆玩家角色`
- formal scene 最小 PlayMode smoke 已补过；当前不要再把“formal scene 还没重跑”写成总阻塞。
- 当前正确表述是：最小启动链已补证，但 4 个一级缺口仍未闭合。

## 当前还没闭合的 4 个一级缺口

1. 单机/本地 2D 导航 Provider
2. 2D 点击移动执行闭包
3. 单机/本地场景实例宿主参考
4. 单机/本地出生点分流宿主参考

二级缺口继续只登记：

- 控制对象与世界穿越目标统一
- 超距后自动靠近再施法/交互
- 传送入口条件

## 本机参考池当前裁决

- `uMMORPG`：只算局部源码证据源，不是当前项目正式运行时替换源。
- `AStar 2D Grid Pathfinding`：只到 demo 级 2D 求路、grid 映射和路径点跟随，还不是正式导航闭包。
- `TopDownEngine`：拿到了 3D pathfinder、网格步进、单场景入口索引、局部 respawn 样板，但没有拿到可直接搬的 2D 点击移动或单机实例/出生点宿主。
- `RTS Starter Kit`：能补命令链和开局生成路由样板，但移动执行强绑 3D `NavMeshAgent` 与 RTS 业务。

结论：

- 本机现有参考池已经复核到当前边界。
- 如果没有新的源码参考，不应继续在本机旧参考上重复翻找。

## 下一会话正确起手

1. 先读 `.spec/knowledge/features/project/2D移动与场景组织下一步入口.md`
2. 再读 `.spec/knowledge/features/project/2D移动与场景组织现态速查表.md`
3. 若用户给了新参考，再按 `movement-scene-reference-intake.md` 做 intake
4. 若没有新参考，就不要进入实现态

## 不要再犯的前提错误

- 不要再从“项目里没有控制器”开始
- 不要把 `Mirror / NavMeshAgent / 3D CharacterController / MMO 副本流` 误写成当前单机正式参考
- 不要把 demo 级 grid/pathfinding 误写成“一级缺口已经闭合”
