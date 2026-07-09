# Design: integrate-character-weapon-entry

## Reference Baseline

本 change 只对齐两段参考：

1. `TopDownEngine/Common/Scripts/Characters/CharacterAbilities/CharacterHandleWeapon.cs`
2. `TopDownEngine/Common/Scripts/Characters/Weapons/ProjectileWeapon.cs`

这两段参考共同证明的不是“必须搬 TopDown 整套武器系统”，而是：

- 角色侧存在独立的武器处理组件。
- `ProjectileSpawn` 是这个组件的正式入口之一。
- 武器执行相关的角色级绑定入口，应优先收在这个组件边界，而不是散在每个能力脚本各自绑定。
- `ProjectileSpawn` 可以为空；真正的武器执行闭包需要在正式入口内部提供等价退回路径，而不是把第二个入口散落回业务调用者。

## Current Gap

当前项目现态：

- `CharacterHandleWeapon` 已存在，但还没有承接真实调用。
- `ProjectileAbility` 仍自己持有 `m_projectileSpawnPoint`。
- `0_Hero_Base.prefab` 上 `CharacterHandleWeapon.m_projectileSpawn` 当前为空，因此如果直接硬切成“必须显式配置发射点”，会让已有角色 prefab 配置失效。

## Design Decision

### 1. CharacterHandleWeapon owns projectile spawn resolution

`CharacterHandleWeapon` 继续作为角色侧武器处理边界。

它的正式职责改为：

- `WeaponAttachment`：角色武器挂载入口。
- `ProjectileSpawn`：角色投射物出生点入口。
- `WeaponVisualUpdater`：角色武器视觉覆盖入口。

其中 `ProjectileSpawn` 的解析顺序为：

1. 显式 `m_projectileSpawn`
2. `WeaponAttachment`
3. 角色自身 `transform`

这样做的原因不是“加兜底兼容层”，而是把 TopDown 里“空发射点时由武器闭包继续退回自身正式入口”的行为，收口进当前项目唯一的角色侧武器入口。

### 2. CharacterHandleWeapon also owns weapon visual override entry

当前近战能力会在出手前临时覆盖角色武器外观，这属于角色级武器表现入口，不应该散在单个能力脚本里各自绑定。

因此这一轮继续把这类入口收回 `CharacterHandleWeapon`：

- `MeleeAttackAbility` 不再持有 `EquipmentSpriteLibraryUpdater` 作为角色级正式引用。
- 角色级视觉更新器的解析、缓存和空值处理统一收在 `CharacterHandleWeapon`。
- 能力脚本只表达“这次是否请求武器视觉覆盖”，不再自己拥有角色级视觉更新器真相。

### 3. ProjectileAbility removes its private spawn truth

`ProjectileAbility` 不再拥有独立的正式发射点真相。

它在运行时只做一件事：

- 通过 `CharacterHandleWeapon.TryResolve(...)` 获取角色侧武器入口。
- 使用该入口解析出的 `ProjectileSpawn.position` 生成投射物。

如果角色缺少 `CharacterHandleWeapon`，则退回角色自身 `transform`，并将其视为 prefab 组件配置缺口，而不是能力级真相入口。

### 4. Single truth-source rule becomes explicit

当前项目已经有“不制造第二套同职责真相源”的原则，但这一轮争议说明它还不够落在“参考吸收后的角色组件化”这一类场景里。

因此这次补成明确约束：

- 一旦某项职责已经选定正式角色组件或正式系统 owner，业务调用者不得再各自保留同职责序列化字段。
- 允许的退回路径必须收在同一个正式 owner 内部，不能散落在外部调用者上。

### 5. Active abilities reuse one character-side weapon entry path

虽然 `ProjectileAbility` 和 `MeleeAttackAbility` 已经不再各自持有独立的发射点或角色级视觉更新器真相，但如果它们继续分别缓存一份 `CharacterHandleWeapon`，本质上仍然是在能力子类里重复维护同一个角色级入口解析。

因此这一轮继续收口：

- 主动能力基类 `ActiveAbilityBase` 统一提供角色级 `CharacterHandleWeapon` 解析入口。
- `ProjectileAbility` 和 `MeleeAttackAbility` 只通过这个统一入口访问角色侧武器 owner。
- 这样做的目标不是额外抽象，而是继续对齐 TopDown 那种“能力复用角色已绑定入口”的结构，避免每个能力子类再各自长一份相同解析逻辑。

## Why Not More

本 change 故意不扩成完整 TopDown 武器系统重构，因为当前还没有：

- 当前武器真相
- 武器切换闭包
- 远程武器库存/轮换业务
- 武器表现模型接线

这些都属于下一批“武器处理深化”，不能在这一刀里靠空字段和未接业务的 API 伪装成完成。
