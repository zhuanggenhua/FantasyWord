# Character Alteration Equipment Effects Twenty-Eighth Cut

## 目标

第二十八刀只收一个最小合同：变形、感染、丧尸化等 `CharacterAlterationRule` 规则可以声明“装备效果暂时失效”。

这不是强制脱装，也不是装备视觉隐藏。装备物品仍留在原槽位，背包和装备槽事实不变；失效期间只是不再把装备属性计入角色属性，也不再让装备授予能力实际可用。

## 用户故事

- 作为玩家，我的队员可能变成野兽、丧尸或其他异形状态。它身上的盔甲和戒指仍然属于这个角色、仍在槽位里，但当前形态不应继续吃这些装备的属性加成或装备技能。
- 作为内容作者，我希望同一条变形/感染规则能同时声明能力变化、动作限制、阵营变化、玩家控制锁和装备效果失效，而不是在装备系统、能力系统和 UI 里分别写特殊分支。
- 作为系统设计者，我需要失效和恢复都按来源叠层处理。多个感染/变形来源同时压制装备效果时，撤掉其中一层不应误恢复仍被其他来源压制的装备能力。
- 作为未来 Kenshi / 博德之门 / ToME4 风格复杂效果的基础，角色在失效期间仍可保留背包和装备事实，后续规则可以再裁决强制脱装、尸体容器、视觉隐藏或 AI 接管。

## 实现

- `CharacterAlterationRule` 新增 `suppressEquipmentEffects` 配置。规则生效时按 `CharacterAbilitySourceKey` 写入装备效果压制，撤回或单层撤回时按同一来源移除。
- `CharacterBase.StateApi` 暴露装备效果压制的虚方法。非 Hero 目标默认 no-op，避免当前没有装备栏的角色类型被迫实现空装备语义。
- `CharacterBase.Alterations` 在读档恢复和清空激活规则时清理并重建装备效果压制。该运行时状态不新增存档字段，仍由 `activeAlterationRules` 在恢复时重建。
- `Hero` 维护来源化装备效果压制计数。存在任意有效压制时，`BuildResolvedStats()` 不再合入装备栏属性。
- `Hero` 对装备授予能力使用来源化能力压制，而不是删除装备来源能力实例。规则撤回时只撤自己的压制层，装备来源能力本身仍由装备槽变更负责增删。
- 失效期间更换装备时，旧装备能力先撤掉对应压制再移除能力实例，新装备能力先添加能力实例再补上当前所有装备效果压制。
- 失效期间换装仍检查 `ChangeEquipment` 动作权限，但属性变化校验使用 0 差值，因为装备属性当前不会改变实际角色属性。
- `Invoke-FoundationStaticGate.ps1` 已加入装备效果失效相关门禁，覆盖规则字段、角色状态 API、Hero 属性计算、装备能力压制和压制期间换装校验。

## 存档与边界

没有新增存档字段。装备槽仍由 `HeroDataBlock.equipmentSlots` 保存；规则激活状态仍由 `activeAlterationRules` 保存；装备效果压制运行时由激活规则在读档时重建。

本刀尚未实现：

- 强制脱装或把装备移回背包。
- 装备外观隐藏、替换形态外观或纸娃娃层裁剪。
- 尸体容器、失控角色掉落、装备损坏或装备锁死。
- 非 Hero 角色的装备栏。如果未来 NPC 也有装备，应在对应角色类实现同一组压制接口。
- AI 强制接管、控制组、多选、远程访客、网络 ownership、派系长期仇恨。

## 验证

本刀验收结果：

- `git diff --check` 定向检查本轮文件通过。
- `scripts/Invoke-FoundationStaticGate.ps1 -AsJson` 通过，新增装备效果失效门禁保持 `CharacterAlterationRuleMissingPatternCount = 0 / CharacterBaseAlterationsMissingPatternCount = 0 / CharacterBaseStateApiMissingPatternCount = 0 / HeroMissingPatternCount = 0 / GameCoreGasRuntimeReferenceHitCount = 0`。
- `npx openspec validate define-fantasyword-foundation-framework --strict` 通过。
- AIBridge `assets-refresh` 成功；Editor 状态为 `isPlaying = false / isCompiling = false / isUpdating = false`；资产刷新后的最近 1 分钟 `Error = [] / Exception = []`。
