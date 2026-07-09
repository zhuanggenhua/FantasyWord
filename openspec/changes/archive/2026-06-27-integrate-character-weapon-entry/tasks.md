# Tasks: integrate-character-weapon-entry

## 1. Scope Lock

- [x] 记录 TopDown `CharacterHandleWeapon + ProjectileWeapon` 对当前 change 的直接参考结论。
- [x] 记录当前 `ProjectileAbility` 仍保留独立发射点真相的现态证据。

## 2. Specification

- [x] 新建本 change 的 proposal / design / tasks。
- [x] 为 foundation runtime 增补“角色侧武器入口单一真相源”spec delta。
- [x] 运行 `npx openspec validate integrate-character-weapon-entry --strict`。

## 3. Implementation

- [x] 让 `CharacterHandleWeapon` 正式拥有投射物出生点解析职责。
- [x] 移除 `ProjectileAbility` 的独立正式发射点真相，改为通过 `CharacterHandleWeapon` 获取。
- [x] 更新参考文档和代码参考矩阵，说明当前真实接入只覆盖角色侧挂点/发射点，不假称完整武器系统完成。
- [x] 将角色侧发射点退回逻辑收口到 `CharacterHandleWeapon` 自身 API，而不是留在调用方各自实现。
- [x] 将调用方依赖进一步收口为 `CharacterHandleWeapon` 的正式解析方法，而不是直接依赖其内部字段拼装逻辑。
- [x] 将主动能力里分散的角色 Animator 解析入口收回统一路径，不再让每个能力自己持有一份角色 Animator 真相。
- [x] 将近战能力使用的角色级武器视觉更新入口收回 `CharacterHandleWeapon`，不再让 `MeleeAttackAbility` 自己持有角色级视觉更新器真相。
- [x] 将主动能力子类里重复的 `CharacterHandleWeapon` 缓存进一步收回 `ActiveAbilityBase`，不再让 `ProjectileAbility` 与 `MeleeAttackAbility` 各自维护同一角色级入口解析。

## 4. Validation

- [x] 静态确认 `ProjectileAbility` 不再声明独立发射点正式字段。
- [x] 静态确认 `ProjectileAbility` 发射位置来自 `CharacterHandleWeapon`。
- [x] 静态确认 `0_Hero_Base.prefab` 即使 `m_projectileSpawn` 为空，角色侧武器入口仍有正式退回路径。
- [x] 静态确认 `MeleeAttackAbility` 不再声明角色级 `EquipmentSpriteLibraryUpdater` 正式字段。
- [x] 静态确认 `ProjectileAbility` 与 `MeleeAttackAbility` 不再各自缓存 `CharacterHandleWeapon`，角色级武器入口解析统一经由 `ActiveAbilityBase`。
