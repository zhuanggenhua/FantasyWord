# Project World Mode Entity 落地提案

> 本文回答“更符合软件工程的方案到底是什么”，并把它压成当前仓库能执行的实施口径。
> 它不是要求现在就新建 `WorldRuntime/ModeRuntime` 空类；相反，它的目标是防止为了架构名词先造空壳。

## 1. 四层含义

| 层 | 含义 | 当前例子 |
| --- | --- | --- |
| `Project` | 当前整次游戏会话共享的服务、配置、文件层和跨模式长期数据入口 | `GameManager`、`GameConfig`、`DatabaseRegistry`、`InputSystem`、`AudioSystem`、`SaveSystem` 文件层、UI 菜单运行时 |
| `World` | 当前开放世界档位里的地图、区域、出生点、检查点、区域模拟和世界状态 | `MapSystem`、`MapInfo`、检查点栈、未来的区域/派系/经济状态 |
| `Mode` | 当前正在运行的具体玩法模式状态 | 现在只有探索/菜单/对话这类隐式模式；未来会有卡牌自走棋单局模式 |
| `Entity` | 单个角色、怪物、物品、棋盘单位、场景对象自己的局部状态 | `CharacterBase/Hero/Monster`、`Movable`、`PlayerController`、`PickableItem` |

## 2. 先给结论

### 2.1 现在不用新建空类

| 需求 | 当前动作 |
| --- | --- |
| 项目级服务 | 继续留在 `GameManager + AGameSystem` |
| 世界级状态 | 先落在已有 `MapSystem/PersistenceSystem` 相邻正式闭包 |
| 模式级状态 | 没有真实模式前，只做文档裁决和门禁，不建 `ModeRuntime` |
| 实体级状态 | 继续收回 `CharacterBase/Hero/Monster/Movable/...` 正式拥有者 |

### 2.2 什么时候才允许新建真实宿主

| 层 | 触发条件 |
| --- | --- |
| `World` | 当区域/Cell、派系、经济、离线模拟至少有一条正式玩家链路进入实现 |
| `Mode` | 当卡牌自走棋单局、演出模式或其它独立玩法真的开始实现 |

没有真实调用者前，新建 `WorldSystem/ModeRuntime` 只是空占位，不是架构升级。

## 3. 当前代码应该如何归层

| 现有模块 | 正式层级 | 说明 |
| --- | --- | --- |
| `GameManager` 13 个系统快捷入口 | `Project` | 只保留现有白名单，不再扩张 |
| `InputSystem`、`AudioSystem`、`TransitionSystem`、`UISystem` | `Project` | 它们是会话级服务，不拥有世界或实体真相 |
| `MapSystem`、`MapInfo`、检查点、出生点、地图切换 | `World` | 这些描述的是当前世界档位，而不是项目全局工具 |
| `SaveSystem` 文件承载 | `Project` | 文件、槽位、序列化工具是项目级承载 |
| `SaveDataBlock` 内的世界内容 | `World` 或 `Entity` | 数据归属跟内容走，不因文件入口挂在 `SaveSystem` 就变成项目全局 |
| `CharacterBase/Hero/Monster/Movable/PlayerController` | `Entity` | 单个角色或单位自己的状态与规则 |
| `UIManager` 菜单语义入口 | `Project` | 它管理菜单机制，不拥有角色、背包、任务真相 |
| 背包、任务、成长这些当前长期玩家数据 | 当前仍在 `Project/Entity` 过渡地带 | 现阶段沿现有 `InventorySystem/JournalSystem/Hero` 保留，后续按真实共享范围继续收口 |

## 4. 卡牌自走棋如何放进去

| 数据 | 归属层 |
| --- | --- |
| 收藏、卡组、模式解锁、跨模式奖励 | `Project` |
| 某一局牌局的棋盘、回合、站位、单位临时 Buff、商店刷新 | `Mode` |
| 某张卡单位当前血量、当前 Mana、当前位置、临时标签 | `Entity` |
| 若牌局发生在开放世界里的某个地点 | 地点归 `World`，牌局状态仍归 `Mode` |

这也是为什么不能把卡牌系统直接挂成 `GameManager.CardSystem`：

- 收藏和卡组不是世界地图状态。
- 单局棋盘也不是项目全局服务。
- 单位状态更不是全局状态。

## 5. 单例到底怎么用

| 问题 | 裁决 |
| --- | --- |
| `GameManager.Instance` 是否允许 | 允许，当前它就是项目级启动锚点 |
| 任何状态都挂单例是否允许 | 不允许 |
| 更好的方案是什么 | 不是新造服务定位器，而是让状态回到 `Project / World / Mode / Entity` 正式拥有者 |

换句话说：

- 单例适合“项目级唯一服务入口”。
- 不适合“世界状态、模式状态、实体状态全都随手挂上去”。

## 6. 当前剩余问题怎么按四层推进

### 6.1 GAS

| 项 | 应归层 |
| --- | --- |
| `AbilitySystemComponent` | `Entity` |
| 角色属性、冷却、标签、效果 | `Entity` |
| 不允许的做法 | `GameManager.GasSystem`、全局 GAS 管理壳、项目级静态属性真相 |

### 6.2 UI

| 项 | 应归层 |
| --- | --- |
| `UIKit` 菜单机制 | `Project` 工具/服务层 |
| 具体角色属性显示 | 读 `Entity` |
| 具体地图或世界状态显示 | 读 `World` |
| 具体牌局 HUD | 读 `Mode` |

### 6.3 地图与实例

| 项 | 应归层 |
| --- | --- |
| 当前地图、出生点、检查点 | `World` |
| 未来单机实例宿主 | `World` |
| 不允许的做法 | 为了“先有名字”新建空 `WorldSystem` |

## 7. 当前可以直接执行的规则

| 规则 | 说明 |
| --- | --- |
| 不新增第 14 个 `GameManager.*System` | 继续冻结当前 13 个白名单 |
| 新状态先判层级再落代码 | 先问它是 `Project/World/Mode/Entity` 哪一层 |
| 不能判层级时先写矩阵 | 不先写代码 |
| `Mode` 没实现前不造空模式类 | 只保留卡牌模式矩阵和门禁 |
| `World` 没真实调用者前不造空世界类 | 先沿 `MapSystem/PersistenceSystem` 邻近闭包推进 |

## 8. 当前阶段后的下一步

1. `Project` 层继续保持冻结：不新增 `GameManager` 快捷入口。
2. `World` 层下一次真正落代码，应优先从地图实例/出生点分流/区域状态里选一个有真实链路的点进入。
3. `Mode` 层第一次真正落代码，应在卡牌自走棋开始实现时再创建正式模式宿主，而不是现在。
4. `Entity` 层继续保持“撤浅壳、留真容器”的原则，避免把局部状态重新摊回全局。
