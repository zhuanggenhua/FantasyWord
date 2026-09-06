---
name: framework-layering
description: 框架分层规范：裁决 YokiFrame、GameCore、Gameplay 的职责边界、依赖方向和迁移落点。
metadata:
  type: doc
  status: 已交付
---

# 框架分层规范

本文件是 FantasyWord 的三层框架唯一口径。涉及 YokiFrame、GameCore、Gameplay、目录重切、代码迁移、外部参考吸收或具体业务落点前，先读这里，再读对应项目事实文档。

## 三层职责

依赖方向只能是：

```text
Gameplay -> GameCore -> YokiFrame
```

反向依赖不得出现：YokiFrame 不知道 GameCore / Gameplay，GameCore 不知道 FantasyWord 的具体业务、具体剧情、具体美术或具体玩法内容。

### YokiFrame

YokiFrame 是底座层，只承载无游戏业务语义的基础设施：

- 生命周期、事件、异步、场景、资源、UI、存档、对象池、输入绑定等通用工具原语。
- 能离开 FantasyWord 或任一具体游戏独立成立的框架能力。
- 插件自身公开 API、生成器和工具链入口。

YokiFrame 不承载开放世界、角色成长、队伍、派系、基地生产、物品规则、装备规则、技能规则、剧情、MiniFantasy 美术语义、Mod 内容规则或任何玩家可见业务规则。若为了某个游戏把业务概念塞进 YokiFrame，说明层级判断错误。

### GameCore

GameCore 是通用游戏框架层，基于 YokiFrame 组合出多个游戏可复用的能力：

- 存档槽位、资源门面、输入门面、音频门面、UI 面板栈、对象池接入、内容身份、数据库 / 索引、场景切换、游戏状态、命令 / 请求、通用实体和通用 RPG 闭包。
- 可被不同游戏配置或扩展的作者源、接口、抽象基类、数据容器、验证入口和失败语义。
- 与具体游戏无关的生命周期、加载 / 释放、版本、持久化、诊断和编辑器支撑边界。

GameCore 可以提供扩展点，但不能内置 FantasyWord 的开放世界具体规则、具体队伍 / 派系 / 经济数值、具体剧情、具体 UI 文案、MiniFantasy 资源地址、单个场景流程或一次性玩法样板。

当前 `Assets/Scripts/GameCore` 里仍有从 `2DRPGEngine`、TopDownEngine 和项目吸收来的 RPG 世界规则闭包；这些现态不自动证明后续具体业务还应继续写进 GameCore。新增或重构时，必须重新判断它是跨游戏合同，还是应该迁入 Gameplay。

### Gameplay

Gameplay 是 FantasyWord 具体游戏业务层，承载玩家可见规则、本项目作者内容和产品取舍：

- 开放世界区域 / Cell、队伍、派系、AI 日程、经济 / 生产、基地、探索、剧情、任务事件、角色成长、装备表现、战斗内容和局内卡牌 / 小玩法模式。
- FantasyWord 自己的玩家可见效果、具体业务规则、内容数据、资源地址、场景入口和验收链。
- 具体 ScriptableObject 内容、Prefab、场景、资源配置、运行时表现和项目 UI。

只要规则需要提到 FantasyWord、MiniFantasy、某个角色 / 队伍 / 派系 / 区域 / 剧情、某个具体 UI 面板、某个项目素材或单个玩法模式，它就默认属于 Gameplay 或项目事实文档，不下沉到 GameCore，更不能下沉到 YokiFrame。

## GameCore 特化裁决

当感觉“GameCore 需要游戏特化”时，不默认提到 YokiFrame。按下面顺序裁决：

1. **无游戏语义的基础设施**：可直接离开任何游戏成立，放 YokiFrame。
2. **跨游戏通用能力**：至少能用同一小合同服务两个不同游戏形态，放 GameCore；特化点用接口、策略、作者源或数据模块暴露。
3. **本游戏业务规则**：依赖 FantasyWord 产品、玩家可见语义、内容数值、场景或资源形态，放 Gameplay。
4. **证据不足**：先写文档裁决和替换清单，不写代码、不建空接口、不加兼容壳。

正确模式是 **GameCore 暴露稳定扩展点，Gameplay 提供具体实现 / 数据 / 策略**。只有扩展点本身已经抽象到无游戏语义，才考虑继续下沉到 YokiFrame。

判断口诀：**特化不是下沉理由；通用合同才是 GameCore，游戏语义回 Gameplay，无游戏原语才回 YokiFrame。**

## 常见裁决示例

| 需求 | 默认落点 | 理由 |
| --- | --- | --- |
| 存档槽位、文件版本、原子写入、模块容器 | GameCore | 多个游戏都需要同一文件层能力；具体保存哪些 FantasyWord 事实由 Gameplay 或项目内容模块提供。 |
| 输入 action 绑定、重绑定存储、输入启停 | GameCore | 属于多游戏可复用的输入门面；具体“采集”“互动”“指挥队伍”“打开某个项目面板”的解释在 Gameplay。 |
| EventKit、SceneKit、SaveKit、ResourceSystem、UIKit 和对象池的原始插件能力 | YokiFrame | 无具体游戏语义，是底座原语；GameCore / Gameplay 只保留调用点和项目配置。 |
| 资源加载门面、场景切换门面、UI 面板栈、音频播放门面 | GameCore | 如果只统一生命周期、错误语义、句柄释放和跨游戏接口，可作为通用游戏框架；具体资源地址、场景名单、面板文案和素材属于 Gameplay / 项目事实。 |
| 背包 / 容器基础数据结构 | GameCore 候选 | 如果只表达物品集合、容量、增删和快照，可通用；若包含 FantasyWord 装备规则、制作规则、掉落表、经济数值或剧情条件，规则部分必须在 Gameplay。 |
| 开放世界区域 / Cell、队伍、派系、基地生产、区域经济和剧情事件 | Gameplay | 这些是 FantasyWord 玩家可见规则和产品取舍，不属于通用游戏框架。 |
| 角色成长、装备表现、MiniFantasy 资源地址、具体 UI 文案、测试场景 | Gameplay / 项目事实 | 这些依赖当前产品、作者内容和素材链，不能进入 GameCore。 |
| GameCore 对 YokiFrame 的薄封装 | GameCore 或删除 | 只有增加生命周期、错误语义、项目配置、跨游戏统一接口或验证入口时才保留；纯转发应删除，不下沉成新的底座能力。 |

## 目录落点

新建或重构项目侧运行时代码时，默认按下面落点裁决：

| 层级 | 默认落点 | 说明 |
| --- | --- | --- |
| YokiFrame | `Assets/Plugins/YokiFrame` 或后续明确的包入口 | 插件 / 底座能力保持来源边界；未经许可不直接改插件本体。 |
| GameCore | `Assets/Scripts/GameCore`、`Assets/Editor/GameCore` | 通用游戏框架、编辑器支撑和已吸收的 RPG 世界规则闭包。 |
| Gameplay | `Assets/Scripts/Gameplay/Runtime/<领域>`、`Assets/Editor/Gameplay/<领域>`、项目内容资产目录 | FantasyWord 具体业务层；领域可包括 `World`、`Characters`、`Items`、`Combat`、`Presentation`、`Modes` 等。 |
| 生成物 | `Assets/Scripts/Gen` 或生成器指定目录 | 生成物不手改，改作者源或生成源。 |
| 临时验证 | `Assets/Scripts/test` 或当轮任务文档指定位置 | 只能作一次性探针或获批试做，不得成为长期第二实现。 |

`Assets/Scripts/Gameplay` 不为了好看空建。只有具体业务、作者源、运行时 owner 和验收入口已经锁定时才创建对应领域目录。

## 现有代码迁移口径

- `Assets/Scripts/GameCore` 当前仍是已接入通用游戏框架闭包，不能因为分层口径更新就直接搬目录；搬迁必须走逐项合同迁移，保留 `.meta` / GUID，并验证 Unity 编译与引用。
- `Assets/Scripts/Gameplay/Runtime/Presentation/EquipmentSystem` 当前属于 FantasyWord 具体表现业务，已进入 Gameplay 表现领域；相关编辑器工具落在 `Assets/Editor/Gameplay/Presentation/EquipmentSystem`。
- `Assets/Scripts/World`、`Assets/Scripts/Characters`、`Assets/Scripts/Items`、`Assets/Scripts/Combat` 这类顶层产品目录不再作为新建默认。新业务优先放到 Gameplay 领域目录；旧文档里提到的顶层目录只作为迁移期历史目标候选，不能直接覆盖本文件。
- 对已经存在的 GameCore 代码，判断标准不是“现在在哪个目录”，而是现实职责：它服务底座原语、通用游戏框架，还是 FantasyWord 玩家规则。
- 如果一个文件同时回答出两个层级的职责，默认先拆职责或删除浅包装，不保留混合层。

## 代码归属审查清单

后续开始代码重构时，每个待移动、删除、改名、拆程序集或改引用的文件先按下表登记；登记不清楚时，只能继续取证，不得实施迁移。

| 项 | 必填问题 |
| --- | --- |
| 当前文件 | 它现在在哪个目录、哪个程序集、由谁调用或被哪些资源引用？ |
| 现实职责 | 它服务的是 YokiFrame 底座原语、GameCore 通用游戏能力，还是 FantasyWord 玩家可见规则 / 作者内容？ |
| 权威状态 | 它是否持有可写状态、内容身份、资源地址或序列化引用；如果有，唯一写入口是谁？ |
| 参考来源 | 它来自 YokiFrame、GameCore、Unity 官方 / 上游 skill、外部候选来源、旧项目吸收，还是 FantasyWord 自有实现？ |
| 目标落点 | 保留在 YokiFrame / GameCore / Gameplay / 参考区 / 移出 active / 删除中的哪一个？ |
| Unity 引用闭包 | 涉及 `.meta`、GUID、Prefab、Scene、ScriptableObject、Animator、Renderer 或 ProjectSettings 时，哪些引用必须保留或同步切换？ |
| 删除或迁移条件 | 被替代入口、消费者切换、验证命令和旧入口负向断言是什么？ |

如果一个文件同时回答出两个层级的职责，默认先拆职责或删除浅包装，不保留混合层；如果它已经被当前资源引用，必须先证明引用闭包可以随迁移保留，不能只按路径美观性处理。

## 参考来源口径

旧来源项目、CardLoop、Unity 官方 skill、第三方插件示例或其它外部资料，只是候选来源和证据，不是 FantasyWord 的第二套真相源。

- 公共能力尽量保持一致：插件公开 API、YokiFrame 基础原语、GameCore 通用合同和参考来源中已经验证成熟的通用能力，优先沿用相同职责和命名。
- 项目特有内容必须剥离：来源工程的世界观、任务记录、测试截图、旧场景、旧流水账、旧业务数据、临时实现和玩家规则不能进入 FantasyWord 框架规范。
- 参考候选要逐项说明：参考了什么通用职责、不参考什么业务内容、FantasyWord 当前 owner 是谁、如果要改代码旧合同由哪个新入口承载、验证回到哪里。
- FantasyWord 有而 CardLoop 没有的材料，先看是否仍承担参考证据、迁移裁决、插件边界或项目业务现实落点；能说明 owner 和触发入口就保留，不能说明再迁出、合并或归档。
- 来源特定长文不进入 active 根级默认入口；需要追溯时看证据目录、归档目录、git 历史或外部来源本体，框架总口径只放本文件和对应 standards。

## CardLoop 参考边界

CardLoop 可同步的通用部分只有三层口径、复用优先、文档先行和同职责不并行。CardLoop 的 Scenario、Tabletop、Actions、Quests、寒夜营地资产、卡牌生存数值和剧本流程都是 CardLoop Gameplay 业务，不进入 FantasyWord。

从 CardLoop 或其它项目吸收结构时，必须逐项说明：

- 参考了什么通用职责。
- 不参考什么业务内容。
- FantasyWord 当前 owner 是谁。
- 如果要改代码，旧合同由哪个新入口承载。
- 用哪条验证证明没有第二套状态、第二套身份或第二套资源真相。

## 文档先于代码

框架、目录、职责或模块 owner 的重构，必须先完成文档收口，再进入代码重构。最低完成条件：

- 本文件或对应 standards 已写清唯一分层口径。
- `.spec/knowledge/README.md` 和 `.spec/knowledge/features/project/文档索引.md` 能路由到唯一正文。
- 旧根级流水账、参考工程专项记录或过期任务卡没有被当作当前代码重构真相源。
- 待重构文件已有代码归属审查清单，能说明保留、迁移、移出 active 或删除的依据。
- `node .spec/tools/spec-lint.mjs` 通过。

文档未收口时，可以继续补证据、改索引、移出 active 入口或删除真正垃圾；不得开始改运行时代码、Prefab、场景或 Unity 配置来抢先完成框架重构。
