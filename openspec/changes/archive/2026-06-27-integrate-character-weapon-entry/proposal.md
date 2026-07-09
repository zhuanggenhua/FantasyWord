# Proposal: integrate-character-weapon-entry

## Why

`CharacterEquipment` 已经从 `CharacterHandleWeapon` 中拆出，但当前武器处理边界还停留在“名字对齐”的阶段，没有真正开始承载角色侧武器入口职责。

当前直接证据是：

- `CharacterHandleWeapon` 只暴露了 `WeaponAttachment / ProjectileSpawn` 字段，还没有真实业务接入。
- `ProjectileAbility` 仍然自己持有 `m_projectileSpawnPoint`，没有通过角色侧武器组件获取正式发射点。
- 这会形成两个同职责入口：角色组件一套、能力脚本一套，不符合当前项目“参考对齐后必须收口到单一正式真相源”的目标。

TopDown 的参考并不是“每个技能一个组件”，而是“角色侧武器处理入口单独存在，真正用武器或投射物时走这个入口”。因此这次 change 的目标很明确：先把第一批真实调用接进去，并补上单一真相源规则。

## Scope

This change covers:

- 为角色侧武器处理入口补充正式 spec delta。
- 把“吸收参考后必须选单一真相源，不保留并行同职责入口”写成正式约束。
- 让 `ProjectileAbility` 的发射点正式改为从 `CharacterHandleWeapon` 获取。
- 让 `CharacterHandleWeapon` 在 `ProjectileSpawn` 为空时提供和 TopDown 等价的正式退回路径，而不是继续让能力脚本各自保留第二个入口。
- 让近战能力使用的角色级武器视觉覆盖入口也收回 `CharacterHandleWeapon`，不再由 `MeleeAttackAbility` 自己持有角色级视觉更新器引用。
- 按同样原则把主动能力里的角色 Animator 解析入口收回统一路径，不再让多个能力脚本各自持有一份角色 Animator 真相。
- 更新参考文档与代码参考矩阵，明确这次真实接入的范围和边界。

## Out Of Scope

- 不在本 change 中引入 TopDown `CurrentWeapon`、输入缓冲、自动换弹、武器轮换、GUI 或 InventoryEngine。
- 不在本 change 中重做近战武器表现、武器可见模型、武器切换或正式远程武器栏业务。
- 不在本 change 中实现所有主动能力；只先接入已经存在明确发射点概念的 `ProjectileAbility`。

## Success Criteria

- `ProjectileAbility` 不再保留自己的正式投射物出生点真相。
- 角色侧投射物出生点通过 `CharacterHandleWeapon` 解析，且空 `ProjectileSpawn` 不会让现有 prefab 失效。
- 规范中明确记录：吸收参考后，同一职责只能有一个正式真相源；兼容层或并行入口只有在参考本身明确存在且项目明确照搬时才允许。
