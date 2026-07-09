# Rationale: refactor-character-ability-inventory-composition

## Purpose

这份文档专门回答 4 个问题：

1. 为什么当前玩家 prefab 不能算已经完成参考 TopDown 的重构。
2. 为什么这次提案优先收口“能力组合结构 + 角色私有背包”，而不是同时重写所有角色系统。
3. 为什么最终不是继续维持单 `Hero` 脚本中心，也不是整套接管 TopDown 生命周期；以及为什么当前实现还没有完成 TopDown 式组件拆分。
4. 为什么当前阶段不切 ECS，也不提前带上联机实现。

## Problem Statement

当前项目已经有一部分正确方向，但它们还没有在玩家 prefab 上形成可检查、可验证、可扩展的正式角色闭包。

现状可以概括成一句话：

- 规则层已经开始支持复杂能力来源和多 owner 背包。
- prefab 层已经直接挂上 `CharacterPlayerControl / CharacterAbilitySet / CharacterMovement / CharacterButtonActivation / CharacterInventory / CharacterHandleWeapon`，旧 `SerializeReference PlayerController` 控制入口已退场；但仍不能把 `Hero` 或 partial 文件拆分当作完整组件化完成证据。
- 此前新增的 `CharacterCompositionProfile` 已判定为无参考迁移层并删除；后续不再把 Profile / fallback 当作正式设计理由。

这会导致两个直接问题：

1. 文档和代码都难以证明“角色是由哪些能力、哪些库存归属、哪些控制入口组合出来的”。
2. 后续要支持变形、感染、装备授予能力、多角色独立背包、AI 接管和未来远程输入边界时，容易继续把更多职责塞回 `Hero`。

## Evidence Summary

### Current project evidence

- `0_Hero_Base.prefab` 里可以直接看到 `Hero` 宿主、`Movable`、动画策略引用、角色 sheet，以及控制、能力、库存、装备等 prefab 可见组件。
- 旧 `PlayerController` 曾经是 `SerializeReference` 控制入口；当前已删除，单角色玩家输入由 `CharacterPlayerControl` 承接。
- `CharacterBase` 已经提供：
  - 能力初始化和运行时更新
  - 变形/感染/状态来源化能力授予与压制
  - 死亡/复活和部分装备联动
- `InventorySystem` 已经提供：
  - `InventoryOwnerHandle`
  - `EInventoryOwnerKind.Character/Container/Corpse/...`
  - 基于角色 owner 的库存查询、加减、转移

### TopDown reference evidence

- `Koala.prefab` 不是单个角色脚本，而是：
  - `Character` 宿主
  - 多个 `CharacterAbility` 组件
  - `CharacterInventory` 组件
- `CharacterAbility` 提供的关键价值不是“具体业务”，而是：
  - 明确的能力边界
  - 统一的阻断/授权表达
  - 组件化的角色拼装方式
- `CharacterInventory` 提供的关键价值不是 TopDown 自己的库存引擎，而是：
  - 角色级库存绑定入口
  - 主背包 / 武器背包 / 快捷栏的显式区分

## Why This Change Focuses On Ability And Inventory First

这不是因为用户只提到了这两个，我才被动去改这两个；而是因为按当前证据复核后，这两个恰好构成了“玩家 prefab 仍未完成组合式角色闭包”的最核心缺口。

原因有 4 个：

1. 它们正好命中产品目标。
   用户故事明确要求：
   - 每个角色独立背包、装备、快捷栏
   - 能力会被变形、感染、装备、状态效果动态保留/替换/压制

2. 它们正好命中 TopDown 最强的参考价值区。
   当前 TopDown 对本项目最直接、最完整、最接近现需求的参考，并不是 manager，而是角色组件化和角色库存组件化。

3. 它们已经在当前项目里有一半地基。
   - 能力侧已有 `CharacterBase` 和来源化能力运行时
   - 背包侧已有多 owner 数据底层
   真正缺的是把这两个“抬升到 prefab 可检查结构”

4. 它们是后续很多系统的前置条件。
   如果角色能力来源和库存 owner 还没明确：
   - 多角色控制
   - 队友 AI
   - 拾取/装备/交易
   - 变形/感染
   - 未来远程输入边界
   都会继续建立在模糊真相源上

## Why Not Keep The Single Hero-Centered Structure

继续维持单 `Hero` 中心结构的问题，不是“代码风格不优雅”，而是它和当前产品目标直接冲突。

### Conflict 1: ability changes are not simple add/remove flags

本项目不是固定职业、固定技能栏的小型 ARPG。

用户故事要求：

- 变形时保留一部分能力
- 感染时替换一部分能力
- 装备授予能力并在卸下时撤回
- 多种来源对同一能力叠加或压制

如果继续把这些都塞在单 `Hero` 宿主里，短期能做，长期会让角色结构越来越不可审计。

### Conflict 2: inventory ownership must be actor-level, not UI fallback-level

当前项目目标更接近：

- 博德之门式角色独立背包
- Kenshi 式多角色队伍物品流转

这要求“谁拥有物品、谁能装备、谁在拾取、谁在交易”必须是角色级真相，而不是默认队伍背包 + 当前受控角色回退逻辑。

### Conflict 3: prefab review must be possible

以后任何人看玩家 prefab，都应该能回答：

- 控制入口在哪
- 能力组合入口在哪
- 库存 owner 绑定在哪
- 装备/快捷栏入口在哪

如果这些都继续隐藏在一个大宿主里，文档和 prefab 都无法成为验收证据。

## Why Not Adopt TopDown Wholecloth

整套接管 TopDown 也不成立，原因同样很具体。

### Reason 1: TopDown manager and lifecycle are not this project's truth source

本项目已经明确保留：

- `2DRPGEngine / GameCore` 的世界规则、数据库、地图、命令、存档语义
- 项目侧已有 `CharacterBase`、`PlayerSystem`、`InventorySystem`

如果整套接管 TopDown：

- 输入根会变成 TopDown 语义
- GUI 根会变成 TopDown 语义
- 角色生命周期会分裂出第二套真相

这和项目既有裁决冲突。

### Reason 2: TopDown inventory semantics are only partially useful

`CharacterInventory` 值得吸收的是“角色级库存绑定模式”，不是它背后的整个库存系统与 UI 生命周期。

本项目已经有多 owner 底层、容器/尸体/商店 owner、现有命令系统和持久化语义，不能为了 prefab 组件化把这些全抛掉。

### Reason 3: TopDown does not solve open-world RPG truth ownership by itself

TopDown 强在：

- 动作表现
- 角色能力组件
- 武器和战斗样板
- 相机、反馈、交互区

它不负责：

- 开放世界长期状态真相
- 多角色队伍 CRPG 式库存语义
- 当前项目的数据库/存档 owner 设计

所以它应该是“俯视角表现层参考”，不是“项目总 runtime 替换源”。

## Why The Cleanup Uses Component Boundaries

当前实现不应被解释为“现有单宿主设计优于 TopDown 组件设计”。之前没有继续拆，不是因为不该拆，而是因为直接把 `CharacterBase / Hero / PlayerController` 一次性替换成 TopDown 生命周期会碰到存档、数据库、UI、命令和能力来源规则的连锁风险；所以正确路线是按参考逐段拆。但这里的逐段拆必须落到正式组件，不能再靠 `Profile`、包装层或常态 fallback 维持旧结构。

本轮已经把能力根节点、玩家额外能力配置、能力实例集合容器，以及玩家技能槽的查询/开火/停火/UI 快照和槽位底层所有权抬到 `CharacterAbilitySet`，这比只做查询/触发门面更接近 TopDown `Koala.prefab` 的可审查组件形态。`Hero` 现在保留公开 API 转发和部分存档编排，不再直接持有技能槽底层。进一步地，主动能力触发、换弹、冷却、formal cancel、formal ability rule/cost/cooldown 和规则生命周期桥接也已经迁到 `CharacterAbilitySet` 的正式入口；装备槽底层已迁到 `CharacterHandleWeapon`。`CharacterBase.GASRuntime.cs` 仍保留属性、ASC 宿主和持续效果编排，这些不是 Koala 组件参考能直接裁决的对象，不能为了“全拆”再造无参考组件。

核心裁决是：

- `CharacterBase` 保留为身份、属性、状态、规则真相 owner。
- TopDown 提供角色组件化和角色库存绑定模式参考。
- `InventorySystem` 继续做底层数据 owner 真相。
- 玩家 prefab 必须显式暴露能力、库存、装备、控制边界。

这条组件化清洗路线存在，是因为它同时满足 4 个短期目标：

1. 不丢当前已经有价值的 `GameCore` 规则真相。
2. 吸收 TopDown 在角色结构上的强项。
3. 对齐用户故事里的多角色 CRPG + RTS + Roguelike 复杂能力目标。
4. 给未来 Mod 和有限联机留下清晰 owner 边界。

但它不是整个角色系统终局。若长期把新职责继续塞回 `Hero / CharacterBase / Movable`，本 change 仍然没有完成用户要求的 TopDown 风格组件化。

## Why Splitting Is Required, Not Optional

TopDown `Koala.prefab` 更好的地方不止是“能力很多”。更关键的是：

1. 控制器、角色宿主和能力组件是拆开的，prefab 上能直接审查谁负责接收输入、谁负责角色状态、谁负责某项能力。
2. 每个能力作为组件管理，天然适合启用、禁用、替换、注入和按来源审计。
3. `CharacterInventory` 把角色级库存绑定做成显式组件，而不是靠 UI 或当前玩家回退猜测。
4. 这种结构对变形、丧尸化、感染、装备授予能力、AI 接管和未来远程输入都更自然。

所以当前规范要锁定：TopDown 式组件边界是 FantasyWord 玩家角色重构的目标形态；`CharacterBase` 可以保留身份和规则真相，但不能继续吞下所有控制、能力、装备和库存职责。

## Why TopDown Componentization Is The Better End State

从结构可审计性和长期扩展看，TopDown `Koala.prefab` 的方向更好：

1. 角色 prefab 上能直接看到控制、移动、武器、库存和能力组件，而不是打开一个大宿主脚本追字段和 partial 文件。
2. 每个能力边界独立，后续变形、感染、装备、AI 或 Mod 只需要替换、禁用或注入对应能力组件/能力声明，不必继续加重 `Hero`。
3. 玩家控制器已经不应再回到 `Hero.m_controller` 的 `SerializeReference`；它应该保持为可检查的控制边界，后续才能自然接控制组、AI 接管和未来远程输入。
4. `CharacterBase` 应保留身份、属性、状态和规则 owner，但不应继续吞下所有能力执行、控制响应、装备槽和表现接线。

因此，当前规范应明确：TopDown 式组件拆分是更好的目标形态；现有实现只是先把 owner 和来源规则稳定下来，不能把它写成最终完成。

## Why Not ECS Now

当前不切 ECS，不是因为 ECS 永远没价值，而是因为它现在解决的不是最前面的矛盾。

### ECS can help scale, but it does not replace truth design

ECS 更擅长的是：

- 大量 NPC 的性能
- 区域外模拟的批处理
- 规则执行的结构化数据流

但当前最前面的缺口是：

- 角色能力来源如何组合
- 角色库存 owner 如何表达
- prefab 如何成为正式验收证据

这些在 MonoBehaviour 地基上也必须先说清楚。否则只是把混乱真相搬到另一种技术栈里。

### Premature ECS would increase migration surface

如果现在切 ECS：

- 角色 prefab
- 控制器
- 背包 owner
- 存档
- UI
- 命令链

都会同时进入迁移面，提案就不再是“收口角色组合结构”，而会变成“重起一套 runtime”。

这和当前目标不匹配。

## Why Not Network Implementation Now

当前提案带联机边界，但不带联机实现，原因也很直接：

- 用户故事要求未来联机只是远程输入进入房主裁决
- 这要求先有清晰的：
  - 角色控制权边界
  - 库存 owner 边界
  - 能力裁决边界
  - 存档写入边界

如果这些单机真相都还模糊，就提前加 FishNet / RPC / NetworkObject，只会把问题扩散成网络问题。

## Consequence For Future Implementation

这份提案意味着，后续正式实现不能再用“运行时能用”当完成证据，而必须满足下面 3 条：

1. 玩家 prefab 上能检查出控制、能力、库存、装备边界。
2. 多角色物品归属和能力来源能被显式追踪。
3. 变形/感染/装备变化能按来源规则保留、替换、压制和撤回。

## Final Decision

最终结论不是“只改能力和背包就够了”，也不是“当前单宿主实现更好所以不用拆”，而是：

- 当前最先必须被提案化并稳定下来的缺口，是能力来源规则、角色库存 owner 和控制对象边界。
- TopDown 风格的玩家角色组件拆分仍然是更好的结构目标，尤其是 `CharacterAbility` 式能力组件、可见控制组件和角色库存组件。
- 当前实现只能算过渡闭包：它证明多 owner、能力保留/替换/压制和控制组上下文能跑通，但没有证明玩家 prefab 已经达到 TopDown 同等级组件化。
- 后续实施必须继续防止 `CharacterBase` 和 `Hero` 重新吞回控制、能力、库存和装备职责；已经删除的 `PlayerController` 不应恢复，玩家 prefab 必须能像 `Koala.prefab` 一样被直接审查出组件边界。
