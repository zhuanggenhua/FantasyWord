# Verification Notes: integrate-character-weapon-entry

## 已验证

- `npx openspec validate integrate-character-weapon-entry --strict` 通过。
- 静态搜索确认 `ProjectileAbility` 不再声明独立投射物出生点正式字段：`rg -n "m_projectileSpawnPoint" Assets/Scripts/GameCore/Runtime/Combat/Abilities/Active/ProjectileAbility.cs` 无命中。
- 静态搜索确认 `ProjectileAbility` 的投射物出生点改为通过 `CharacterHandleWeapon` 解析：
  - [ProjectileAbility.cs](C:/Gamedev/Unity/Project/FantasyWord/Assets/Scripts/GameCore/Runtime/Combat/Abilities/Active/ProjectileAbility.cs) 中 `ResolveProjectileSpawnPosition()` 调用 `ResolveCharacterHandleWeapon()`，再调用 `handleWeapon.ResolveProjectileSpawnPosition()`。
- 静态搜索确认主动能力子类不再各自缓存角色级武器入口，统一经由 [ActiveAbilityBase.cs](C:/Gamedev/Unity/Project/FantasyWord/Assets/Scripts/GameCore/Runtime/Combat/Abilities/Active/ActiveAbilityBase.cs) 的 `m_characterHandleWeapon` 与 `ResolveCharacterHandleWeapon()` 收口。
- 静态搜索确认角色级 Animator 解析入口同样统一经由 [ActiveAbilityBase.cs](C:/Gamedev/Unity/Project/FantasyWord/Assets/Scripts/GameCore/Runtime/Combat/Abilities/Active/ActiveAbilityBase.cs) 的 `m_characterAnimator` 与 `ResolveAndValidateCharacterAnimator(...)` 收口。
- 静态搜索确认 `MeleeAttackAbility` 不再声明角色级 `EquipmentSpriteLibraryUpdater` 正式字段；角色级武器视觉覆盖改为通过 `ResolveCharacterHandleWeapon()` 调用 `TryApplyWeaponVisualOverride(...) / ResetWeaponVisualOverride()`。
- Prefab 复核确认 [0_Hero_Base.prefab](C:/Gamedev/Unity/Project/FantasyWord/Assets/Prefabs/Entities/Characters/Heroes/0_Hero_Base.prefab) 上 `CharacterHandleWeapon.m_projectileSpawn` 当前为空，但 [CharacterHandleWeapon.cs](C:/Gamedev/Unity/Project/FantasyWord/Assets/Scripts/GameCore/Runtime/Entities/Characters/CharacterHandleWeapon.cs) 的正式解析顺序仍会退回到 `WeaponAttachment`，再退回到角色自身 `transform`，没有把退回逻辑散到调用方。

## 现态证据

- [CharacterHandleWeapon.cs](C:/Gamedev/Unity/Project/FantasyWord/Assets/Scripts/GameCore/Runtime/Entities/Characters/CharacterHandleWeapon.cs) 当前正式拥有：
  - `WeaponAttachment`
  - `ProjectileSpawn`
  - `WeaponVisualUpdater`
  - 以及这三类角色侧武器入口的解析与退回逻辑
- [ProjectileAbility.cs](C:/Gamedev/Unity/Project/FantasyWord/Assets/Scripts/GameCore/Runtime/Combat/Abilities/Active/ProjectileAbility.cs) 当前只保留投射物业务本身，不再持有第二套角色侧出生点真相。
- [MeleeAttackAbility.cs](C:/Gamedev/Unity/Project/FantasyWord/Assets/Scripts/GameCore/Runtime/Combat/Abilities/Active/MeleeAttackAbility.cs) 当前只表达“请求角色级武器视觉覆盖/重置”，不再自己拥有视觉更新器真相。
- [ActiveAbilityBase.cs](C:/Gamedev/Unity/Project/FantasyWord/Assets/Scripts/GameCore/Runtime/Combat/Abilities/Active/ActiveAbilityBase.cs) 当前已经成为主动能力子类共享的角色级 `Animator` 与 `CharacterHandleWeapon` 正式解析入口。

## 当前结论

- `integrate-character-weapon-entry` 当前完成的是“角色侧武器挂点 / 投射物出生点 / 角色级武器视觉覆盖 / 主动能力共享角色入口解析”这一层收口。
- 这不等于 TopDown 完整 `CurrentWeapon / Shoot / Reload / WeaponRotation / WeaponInventory` 业务已经整体迁入。
- 这轮结论只证明：角色侧武器入口已经停止分散在 `ProjectileAbility`、`MeleeAttackAbility` 等调用方各自维护，当前正式 owner 已收口到 `CharacterHandleWeapon + ActiveAbilityBase`。
