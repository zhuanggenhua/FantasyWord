# Design: refactor-character-ability-inventory-composition

## Current Facts

- 当前玩家 prefab 已从单纯 `Hero / CharacterBase / Movable` 宿主中心推进到 prefab 可见组件组合，但仍不能把 `Hero` 或 partial 文件拆分当作完成证据。
- `0_Hero_Base.prefab` 的玩家输入目标已落到 `CharacterPlayerControl`，旧 `PlayerController` 序列化控制入口已从玩家 prefab 和代码中移除；归档前还必须通过 Unity 验证证明运行链正常。
- `CharacterBase` 已经承载能力运行时、变形/感染相关的能力增减接口、死亡/复活合同和部分装备规则。
- `InventorySystem` 已经具备 `InventoryOwnerHandle`、`EInventoryOwnerKind.Character`、`GetOwner(CharacterBase)`、`GetBagEntries(owner)`、`TransferItem(...)` 这类多 owner 底层。
- `CharacterInventory` 已把角色级主背包、武器背包和快捷栏归属提升成 prefab 可审计结构，但背包 UI 和完整库存玩法扩展仍不能因此宣称完成。
- 当前实现已经清掉 `CharacterCompositionProfile` 这类无参考迁移层，正式目标是对照 TopDown `Koala.prefab` 继续收敛为控制、能力、库存、装备都能直接审查的组件边界。

## Reference Matrix

| Source | Role | Evidence | Current Project Fit | Gap |
|---|---|---|---|---|
| TopDown `Koala.prefab` | 组件式角色样板 | `CharacterAbility` 多组件，`CharacterInventory` 独立组件 | 参考组合模式 | 我方 prefab 仍偏单宿主 |
| TopDown `Character.cs` | 能力宿主 | 缓存/遍历 abilities，统一调用能力生命周期 | 参考宿主-能力分离 | 我方能力运行时还在 `Hero/CharacterBase` 中心化 |
| TopDown `CharacterAbility.cs` | 能力组件合同 | `AbilityPermitted`、阻断状态、生命周期钩子 | 参考权限与阻断表达 | 不照搬 TopDown 生命周期 |
| TopDown `CharacterInventory.cs` | 角色库存能力 | `PlayerID + Main/Weapon/HotbarInventoryName` | 参考角色私有库存绑定 | 我方还没把 prefab 闭包显式落成同等级结构 |
| 当前 `CharacterBase` / `Hero` | 正式运行时真相 | 变形/感染/装备/能力增减已存在 | 仍是身份、属性、状态、ASC 和持续效果 owner，但不是组件拆分完成证据 | 已把有 TopDown 参考价值的能力规则入口收进 `CharacterAbilitySet`；剩余持续效果编排不按 Koala 组件化范围硬拆 |
| 当前 `InventorySystem` | 背包数据真相 | 已支持多 owner 数据与转移 | 可作为底层真相 | 还需角色级入口和 UI/Prefab 闭包 |

## Proposed Formal Direction

1. `CharacterBase` 继续作为角色身份、属性、状态和规则真相 owner。
2. 能力与控制边界最终应以 prefab 可见的组件/子组件边界表达，而不是只停留在 `Hero` 上的集中 runtime 行为；`CharacterPlayerControl / CharacterAbilitySet / CharacterMovement / CharacterButtonActivation` 是当前正式组件边界，不再把 `Profile` 或 `CharacterCompositionProfile` 当作迁移桥。当前 `CharacterAbilitySet` 已经不只是入口门面，它也承担了主动能力执行、换弹、冷却查询、GAS 规则桥接和武器状态阻断的正式组件入口。
3. 背包不再只被 UI 当作“当前受控角色的默认库存”，而要显式绑定到角色 owner，并在 prefab 或同等级正式组件上能审查“这个角色的主背包、装备/武器背包、快捷栏归属怎么进入当前 `InventorySystem`”。
4. 装备槽不应长期只由 `Hero` 集中承载；装备授予/撤回能力、装备槽存档恢复和装备可用性裁决要继续向 prefab 可见装备/库存边界迁移。
5. 变形、感染、装备授予/撤回的规则必须支持“保留部分能力、压制部分能力、替换部分能力、保留或转移部分库存归属”。
6. TopDown 只吸收“组件式角色 + 角色级库存绑定”的模式，不吸收 `InputManager / GUIManager / LevelManager / CharacterAbility` 的整套生命周期作为正式真相源。

## User Story Additions

- 作为玩家，我希望每个队伍角色都有自己的背包、装备、技能槽和快捷栏，这样我在切换角色时不会误把全队物品当成一个共享袋子。
- 作为玩家，我希望角色被变形、感染或丧尸化时，系统能保留一部分能力、替换一部分能力、禁用一部分装备，而不是把整个角色状态粗暴清空。
- 作为玩家，我希望角色 prefab 上能直接看出它是怎样组合出能力、库存和装备归属的，而不是只看到一个大而全的 `Hero` 宿主脚本。
- 作为设计者，我希望能力和背包变化能通过稳定 ID 和规则层表达，以便未来 Mod、内容扩展和有限联机都能复用同一套合同。

## Implementation Boundary

- 当前阶段允许实现 `CharacterAbilitySet` 这种能力入口组件，把外部能力查询、触发、冷却查询和授予/撤回入口统一导到 prefab 可见组件。
- 当前阶段允许把能力根节点和额外能力配置也抬到 `CharacterAbilitySet`，让玩家 prefab 能从能力组件上直接审查能力组合配置；`CharacterBase` 不再保留同职责能力根节点和额外能力字段作为常态兼容路径。
- 当前阶段允许把 `CharacterAbilitySetRuntime` 能力实例集合、来源计数、压制计数和实例更新/重置/中断容器交给 `CharacterAbilitySet` 持有；缺少 `CharacterAbilitySet` 是 prefab 配置错误，不再用 `CharacterBase` 私有仓库兜底。
- 当前阶段允许把玩家技能槽查询、开火/停火、HUD/菜单能力栏快照、装备/卸下入口和技能槽底层所有权收进 `CharacterAbilitySet`；外部控制器、UI 和 `Hero` 自身不应再直接持有或读写技能槽底层实现。
- 当前阶段已经把主动能力触发、换弹、规则生命周期桥接、GAS 执行中断、formal ability rule、冷却和成本入口迁到 `CharacterAbilitySet` 这层正式组件入口；`CharacterBase` 保留属性、状态、ASC 宿主和持续效果编排，不再保留同职责 ability rule 复制实现。
- 当前阶段已经实现 `CharacterPlayerControl` 这种控制入口组件，把玩家输入目标解析从隐藏 `SerializeReference` 字段抬到 prefab。
- 当前阶段已经把方向/点击移动、指针朝向和交互激活拆成 `CharacterMovement / CharacterButtonActivation`，对应 TopDown `CharacterMovement / CharacterButtonActivation` 的 prefab 可见职责。
- 当前阶段已删除 `PlayerController` 委托壳；单角色输入由 `CharacterPlayerControl` 承接，控制组仍通过 `PlayerControlGroup` 分发到成员的 `IPlayerInputTarget`。

## Non-Goals

- 不在本 change 里重写整个 `InventorySystem`。
- 不在本 change 里把 TopDown 生命周期、输入、GUI 或管理器接入正式项目真相源。
- 不在本 change 里切 ECS。

这些 Non-Goals 只限制“不要整套替换或深改无关底层”，不允许被解释成“背包/装备不属于本 change”。当前 change 仍必须完成角色级库存组件边界、装备槽/能力授予组件边界和对应 prefab 审计。

## Decision Framing

当前做法不是为了联机预留，也不是再做一层迁移桥；它是为了复杂单机角色组合、变形/感染/装备能力来源和未来内容扩展，把 TopDown 已证明的组件化边界落到当前正式真相源上。

换句话说：

- 合理的部分：保留 `CharacterBase` 作为身份与规则 owner，继续吸收 TopDown 的组件模式和 `CharacterInventory` 式角色库存绑定。
- 需要纠正的部分：不能把“有几个能力运行时接口”或“挂了一个自造 Profile”当成“prefab 已组合化完成”。
- 需要补齐的部分：prefab 层的角色能力/库存闭包、显式角色 owner 绑定、以及变形/感染下的能力保留和库存归属规则。
- 需要继续推进的部分：把控制器、能力执行和角色宿主边界往 TopDown 那种“组件可审查”的方向拆，而不是长期停在单宿主 + 若干 partial helper。

更完整的比较理由见 [rationale.md](./rationale.md)。
