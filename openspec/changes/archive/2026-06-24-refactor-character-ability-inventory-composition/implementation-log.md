# Implementation Log: refactor-character-ability-inventory-composition

## Purpose

本文件用于防止再次把“文档阶段完成”或“第一段迁移完成”误报成整个 change 完成。

每个后续实现项都必须记录：

- 参考目标：具体 TopDown prefab 或脚本。
- 改前目标：当前 FantasyWord 的具体脚本、Prefab 或字段职责。
- 改后落点：当前项目正式组件、脚本、Prefab 或系统入口。
- 吸收方式：整段对齐、局部吸收、仅作为负证据。
- 未覆盖差距：还不能勾选完成的原因。
- 验证入口：静态核对、OpenSpec 校验、Unity 编译、AIBridge smoke 或 prefab 审计。

## Scope Guard

当前 change 仍覆盖以下实现项：

| Area | Reference target | Current target | Required outcome | Status |
|---|---|---|---|---|
| Control boundary | TopDown `Character.cs`, `CharacterMovement.cs`, `TopDownController2D.cs`, Koala prefab control/ability composition | `CharacterPlayerControl`, `CharacterMovement`, `CharacterButtonActivation`, `PlayerControlGroup`, `0_Hero_Base.prefab`, `玩家角色.prefab` | 控制入口、移动控制、交互激活已从隐藏 `SerializeReference` 推进到 prefab 可检查组件边界 | Verified |
| Ability boundary | TopDown `CharacterAbility.cs`, `CharacterHandleWeapon.cs`, `Weapon.cs`, Koala prefab ability component list | `CharacterAbilitySet`, `CharacterBase.Abilities.cs`, `CharacterBase.GASRuntime.cs`, `Hero.cs` | 能力实例、主动能力执行、技能槽、装备授予/撤回、formal ability rule/cooldown/lifecycle 和存档恢复已从单宿主拆到组件边界 | Verified |
| Inventory boundary | TopDown `CharacterInventory.cs`, Koala prefab `CharacterInventory` component | `CharacterInventory`, `InventorySystem`, inventory UI context | 角色级主背包、武器/装备背包、快捷栏 owner 绑定成为 prefab 可审查边界；不重写整个 `InventorySystem` | Implemented |
| Equipment boundary | TopDown `CharacterInventory.cs`, `CharacterHandleWeapon.cs`, `Weapon.cs` | `CharacterHandleWeapon`, `Hero` compatibility API, `InventorySystem` equipment transfer | 装备槽、装备授予能力和存档恢复从 `Hero` 唯一宿主迁到 prefab 可见装备/库存边界 | Implemented |
| Prefab audit | `Assets/Plugins/TopDownEngine/Demos/Koala2D/Prefabs/PlayableCharacters/Koala.prefab` and source reference `C:/Gamedev/Unity/Engine/TopDown Engine/TopDown Engine v4.1/Assets/TopDownEngine/Demos/Koala2D/Prefabs/PlayableCharacters/Koala.prefab` | `Assets/Prefabs/Entities/Characters/Heroes/0_Hero_Base.prefab`, `Assets/Prefabs/Entities/Characters/Heroes/玩家角色.prefab` | 归档前能直接审查控制、能力、库存、装备和表现边界 | Verified |

## Current Evidence By Area

### Control boundary

- 参考目标：TopDown `Character.cs` 负责角色身份和 ability 查询；`CharacterMovement.cs` 与 `TopDownController2D.cs` 拆出移动执行；Koala prefab 通过多个组件组合角色能力。
- 改前目标：`Assets/Scripts/GameCore/Runtime/Controllers/PlayerController.cs` 原本同时承载方向移动、点击移动、指针朝向、交互和能力命令路由；基础 prefab 里曾有 `Hero.m_controller` 的 `SerializeReference PlayerController`。
- 改后落点：`CharacterPlayerControl.cs`、`CharacterMovement.cs`、`CharacterButtonActivation.cs` 已挂在 `Assets/Prefabs/Entities/Characters/Heroes/0_Hero_Base.prefab`；`CharacterPlayerControl` 现在直接实现 `IPlayerInputTarget` 并承接玩家命令分发；`PlayerController.cs` 已删除，玩家 prefab 的 `Movable.m_controller` 已清空。
- 未覆盖差距：无 TopDown 参考范围内控制边界缺口。
- 验证入口：静态检查 `0_Hero_Base.prefab` 的正式角色组件、`CharacterPlayerControl` 是否成为输入目标，以及 `PlayerController` 是否已从代码和 prefab 退场；本轮 Unity 导入/编译、Console Error 和组合式 smoke 均通过。

### Ability boundary

- 参考目标：TopDown `CharacterAbility.cs` 定义 ability 组件合同、授权和阻断；`CharacterHandleWeapon.cs` 拆出武器持有和切换；`Weapon.cs` 拆出武器执行状态。
- 改前目标：`CharacterBase.Abilities.cs`、`CharacterBase.GASRuntime.cs` 和 `Hero.cs` 曾集中承载能力实例、技能槽、装备授予能力、formal cancel 和存档恢复编排。
- 改后落点：`CharacterAbilitySet.cs` 已挂在 `0_Hero_Base.prefab`，现在直接持有 formal ability rule roster、cooldown cache、生命周期桥接、能力运行时快照/恢复和技能槽底层；`CharacterBase` 继续承担身份、属性、ASC 宿主、状态和持续效果编排。
- 未覆盖差距：没有 TopDown/Koala 同级参考的持续效果 archived/fallback 执行壳不在本次组件化范围内硬拆。
- 验证入口：静态检查 `CharacterAbilitySet`、`CharacterBase.Abilities.cs`、`CharacterBase.GASRuntime.cs` 和 `CharacterBase.Persistence.cs` 调用链；归档前还要跑 Unity 编译、组合式 smoke 和 prefab 审计。

### Inventory boundary

- 参考目标：TopDown `CharacterInventory.cs` 是明确角色组件，直接暴露 `PlayerID`、`MainInventoryName`、`WeaponInventoryName`、`HotbarInventoryName`，并把角色、主背包、武器背包、快捷栏通过组件绑定。
- 改前目标：`InventorySystem.cs` 已有 `InventoryOwnerHandle`、`EInventoryOwnerKind.Character`、`GetOwner(CharacterBase)`、容器/尸体/转移等多 owner 底层；此前自造的 `CharacterCompositionProfile.cs` 只有 owner 布尔位和解析入口，已判定不是 TopDown `CharacterInventory` 同等级的库存组件并删除。
- 改后落点：`CharacterInventory.cs` 已新增并挂到 `Assets/Prefabs/Entities/Characters/Heroes/0_Hero_Base.prefab`，显式暴露主背包、武器背包和快捷栏是否归属角色；`InventorySystem.GetOwner(CharacterBase)` 已优先从该组件解析主库存 owner。
- 未覆盖差距：当前只把三类库存 channel 映射到当前项目的 `InventoryOwnerHandle`；没有引入 TopDown InventoryEngine 的命名库存、UI 管理器或武器轮换事件，也没有重写 `InventorySystem` 底层。
- 验证入口：静态检查 `InventorySystem.GetOwner(CharacterBase)`、`CharacterInventory`、库存 UI context、`0_Hero_Base.prefab` 和 `玩家角色.prefab`；归档前还要 Unity 编译和 prefab 审计。

### Equipment boundary

- 参考目标：TopDown `CharacterInventory.cs` 通过 `WeaponInventoryName` 和 `HotbarInventoryName` 把武器/快捷栏与角色库存绑定；`CharacterHandleWeapon.cs` 拆出持有武器、初始武器、武器附件和换武器；`Weapon.cs` 承载武器执行状态。
- 改前目标：`Hero.cs` 持有 `HeroEquippedItemLoadout`、装备槽存档数据、装备授予/撤回能力、装备属性刷新、变形/感染压制装备效果等编排。
- 改后落点：`CharacterHandleWeapon.cs` 已新增并挂到 `Assets/Prefabs/Entities/Characters/Heroes/0_Hero_Base.prefab`；装备槽容器、装备授予/撤回能力、装备效果压制和装备存档快照由该正式组件持有。`Hero.cs` 保留 `TryEquip/TryUnequip/TryGetEquipment/GetEquippedItems/ForceUnequipAllEquipmentForLifecycle/OnSave/OnLoad` 公开入口，但内部转发到 `CharacterHandleWeapon`。
- 未覆盖差距：没有引入 TopDown `InventoryEngine`、`Weapon` GameObject 挂接或武器轮换事件；当前只吸收“装备/武器作为角色可见组件边界”的结构目标。`InventorySystem` 仍负责物品转移和背包数据真相，`CharacterAbilitySet` 仍负责能力实例和技能槽真相。
- 验证入口：静态检查 `CharacterHandleWeapon`、`Hero.TryEquip/TryUnequip/OnSave/OnLoad`、`InventorySystem.TryEquip/TryUnequip` 和最终 prefab 组件；本轮批处理编译 `%TEMP%/FantasyWord-Unity-EquipmentProfile-Compile.log` 返回码 0，未出现新的 C# 编译错误。

### Prefab audit

- TopDown 参考 prefab：`Assets/Plugins/TopDownEngine/Demos/Koala2D/Prefabs/PlayableCharacters/Koala.prefab`，本地源码参考路径同上方表格。
- 当前目标 prefab：`Assets/Prefabs/Entities/Characters/Heroes/0_Hero_Base.prefab` 和 `Assets/Prefabs/Entities/Characters/Heroes/玩家角色.prefab`。
- 当前已见组件：`Hero`、`CharacterPlayerControl`、`CharacterAbilitySet`、`CharacterMovement`、`CharacterButtonActivation`、`CharacterInventory`、`CharacterHandleWeapon`。
- 当前审计结果：`0_Hero_Base.prefab` 直接挂载 `CharacterPlayerControl / CharacterAbilitySet / CharacterMovement / CharacterButtonActivation / CharacterInventory / CharacterHandleWeapon`；`Movable.m_controller` 已清空；`玩家角色.prefab` 的 `m_SourcePrefab` 指向 `0_Hero_Base.prefab`，额外能力 override 落到 `CharacterAbilitySet.m_additionalAbilities`。
- 结论：当前 prefab 已完成 TopDown 有参考部分的大清洗正式组件落点，且通过最新 Unity 验证。

## Current Decision

当前实现与验证已闭环，可进入归档流程。

原因不是“文档写完了”，而是当前 change 的有参考实现范围、prefab 审计、OpenSpec 校验、Unity 导入/编译和组合式 smoke 都已经有证据。持续效果 archived/fallback 执行壳没有 TopDown/Koala 同级参考，不作为本次组件化强拆对象；若后续要继续重构，应另行按 GAS/持续效果参考立项。
