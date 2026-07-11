# Character Persistence Thirteenth Cut

## Scope

本次第十三刀补齐角色级长期数据的正式存档结构。目标不是一次性实现变形、感染、丧尸化或完整控制组，而是先让角色背包归属、装备槽、快捷栏和能力来源都有可保存、可迁移、可审计的结构。

## Implemented Shape

- `CharacterBaseDataBlock` 新增 `inventory`：
  - 保存角色对应的 `InventoryOwnerHandle`，只记录 owner 类型和 owner id。
  - 背包物品和金钱仍由 `InventorySystem.InventoryDataBlock.inventories` 作为唯一物品数量真相，角色存档不复制物品清单。
- `CharacterBaseDataBlock` 新增 `abilitySources`：
  - 每条记录保存能力引用、来源类型、来源 id 和叠层数量。
  - 来源类型当前覆盖 `ArchivedBonus / Script / ItemUse / Equipment / Summon / StatusEffect / Transformation / Infection`。
- `CharacterAbilitySetRuntime` 的加成能力运行时从“能力到总数”改为“能力到来源桶再到数量”。
- `HeroDataBlock` 新增 `equipmentSlots`：
  - 每条装备记录显式保存槽位类型和装备引用。
  - 旧 `equipments` 数组继续写出，作为旧档兼容镜像。
- `HeroDataBlock` 新增 `quickAbilitySlots`：
  - 每条快捷栏记录显式保存槽位索引和主动能力引用。
  - 空槽继续用空 guid 引用表达，避免槽位压缩。
  - 旧 `equippedAbilities` 数组继续写出，作为旧档兼容镜像。
- 装备授予能力现在使用装备数据库 GUID 作为来源 id；卸装只移除该装备来源授予的能力。
- 脚本命令、物品学习和召唤附带能力也写入来源键，避免全部混成不可区分的 bonus ability。
- `Invoke-FoundationStaticGate.ps1` 已加入第十三刀门禁：
  - 角色存档必须保留 `inventory / abilitySources`。
  - `Hero` 必须保留 `equipmentSlots / quickAbilitySlots`。
  - 两个 loadout helper 必须保留显式槽位快照和恢复入口。

## Historical Note

- `2026-06-21` 第十八刀后，角色正式存档协议已不再保留 `bonusAbilities` 兼容镜像；当前角色能力来源只认 `abilitySources`。
- `equipments / equippedAbilities` 的旧镜像是否继续保留，属于 `Hero` 装备/快捷栏协议的单独问题，不由本条扩写。
- 背包物品数量没有复制进角色数据块，避免 `CharacterBaseDataBlock` 和 `InventorySystem` 双真相。
- 没有新增网络框架、RPC、NetworkObject、网络目录或网络 SDK 抽象。

## Why This Is Still Not Full Transformation Or Inventory Gameplay

这刀只建立可保存的长期结构，不等于以下内容已经完成：

- 变形、感染、丧尸化如何替换/保留能力、装备和控制权。
- 状态效果授予能力的具体资产配置和端到端验收。
- 角色间背包转移、双栏 UI、尸体/商店/制作站持久库存。
- 保存/加载端到端 smoke 中同时验证背包、装备、快捷栏、能力来源和状态效果。

## Remaining Required Cuts

1. 用第十四刀的临时来源 API 实现变形/感染/丧尸化的能力保留、替换和回滚业务规则。
2. 把具体状态效果资产接到 `StatusEffect` 来源，而不是只停留在角色 API 合同。
3. 补保存/加载 smoke，覆盖角色背包、装备槽、快捷栏、能力来源和状态效果恢复。
4. 让 UI 技能栏和背包视图进一步切到角色或控制组上下文。
