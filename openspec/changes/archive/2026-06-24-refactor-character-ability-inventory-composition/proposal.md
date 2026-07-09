# Proposal: refactor-character-ability-inventory-composition

## Why

当前玩家角色已经完成控制、能力、库存和装备的第一轮正式组件落点，并且本 change 已按 OpenSpec 流程归档。

我方当前 `0_Hero_Base.prefab` / `玩家角色.prefab` 已经把玩家输入目标、能力集合、移动、交互、库存和装备拆到 prefab 可见组件；旧 `PlayerController` 序列化控制入口已从玩家 prefab 和代码中移除。TopDown 有参考价值的 formal ability rule / cooldown / lifecycle 入口已收进 `CharacterAbilitySet`；`CharacterBase` 仍保留属性、ASC 宿主和持续效果编排，这部分不属于 Koala 组件化参考能直接裁决的范围。最终 Unity 验证、组合式 smoke 和归档前 prefab 审计已闭环。

更直接地说：现在不能把“运行时已有部分能力规则”误判成“玩家 prefab 已完成组合式角色闭包”。用户明确指出的能力可变形、可感染、可保留部分能力并替换部分能力、以及每个角色自己的背包与快捷栏，都是本次需要单独提案收口的目标。

本 change 的完整取舍理由、与 2DRPG / TopDown / ECS / 联机边界的关系，集中记录在 [rationale.md](./rationale.md)。

## What

本 change 初始是专项提案；后来进入实现闭环并完成归档。文档、用户故事和第一段迁移都只能算阶段产物，不能单独构成完成。

当前完整目标不是“写清楚以后再做”，而是把 TopDown `Koala.prefab` 证明过的角色组合思想，在当前 `GameCore` 真相源上落成可审计的玩家/可控角色 prefab 边界。此前 `Profile / CharacterCompositionProfile / fallback` 口径已判定为无参考迁移层，本 change 的实现口径改为大清洗：只保留有 TopDown 或当前正式真相源支撑的组件边界，不保留自造兼容层作为常态路径。

- 明确玩家/可控角色 prefab 的正式组合目标。
- 明确能力系统与背包系统的角色级归属规则。
- 把 TopDown 的 `Character / CharacterAbility / CharacterInventory / Koala.prefab` 作为组件模式参考，而不是整套生命周期接管参考。
- 把当前 `InventorySystem` 的多 owner 底层、`Hero` 的能力与装备运行时、以及 `CharacterBase` 的变形/感染能力增减接口纳入同一提案边界。

## Scope

本 change 覆盖：

- 玩家 prefab 结构提案。
- 角色能力组件化提案。
- `CharacterPlayerControl / CharacterAbilitySet / CharacterMovement / CharacterButtonActivation / CharacterInventory / CharacterHandleWeapon` 这类对照 TopDown Koala 的 prefab 可见组件边界。
- 角色私有背包、武器背包、快捷栏归属，以及与当前 `InventorySystem` 多 owner 底层之间的正式组件边界。
- 角色装备槽、装备授予/撤回能力、装备存档恢复编排与能力组件之间的正式组件边界。
- 变形、感染、丧尸化、装备授予/撤回能力的保留/替换/压制规则提案。
- 相关验收标准和参考矩阵。
- 对照 TopDown 参考完成实现留档：参考脚本、改前目标脚本、改后落点、差距和验证入口。

本 change 不覆盖：

- 整套替换 TopDown `CharacterAbility` 生命周期或接管当前项目角色生命周期。
- 重写整个 `InventorySystem` 底层数据结构、全部 UI 流程或物品数据库。
- FishNet 或其它联机框架接入。
- TopDown manager、输入根、GUI 根或完整生命周期迁移。
- ECS 化改造。

这些不覆盖项不等于把背包、装备、能力和控制排除出当前 change；它们只表示不照搬整套外部框架、不重写与本次组件化无直接关系的底层系统。

## Acceptance Direction

- 提案必须能解释为什么“单个 `Hero` 主脚本中心”不够。
- 提案必须能说明 TopDown 哪些部分是可吸收的组件模式，哪些部分不能直接成为正式真相源。
- 提案必须把“每个角色自己的背包”和“能力可替换/可压制/可保留”写进用户故事或设计合同。
- 提案必须能区分：底层已有多 owner 背包能力，和玩家 prefab 上可检查的角色级库存闭包并不等价。
- 实现汇报必须区分：`CharacterAbilitySet` 这类入口组件已经挂上，和能力实例集合/执行生命周期已经完全拆出，不是同一件事。
- 归档前必须能证明当前 change 覆盖的控制、能力、库存、装备和留档任务都已完成；只完成文档、第一段迁移、smoke 或 OpenSpec artifact 校验都不能汇报为完成。
