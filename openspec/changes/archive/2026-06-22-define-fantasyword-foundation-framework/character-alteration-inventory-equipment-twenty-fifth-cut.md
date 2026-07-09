# Character Alteration Inventory And Equipment Twenty-Fifth Cut

## 目标

第二十五刀只收一个最小合同：变形、感染、丧尸化等 `CharacterAlterationRule` 规则锁定角色动作时，能影响角色主动装备变更和主动背包操作。

这不是完整形态业务。强制脱装、装备隐藏/失效/保留、尸体容器化、背包掉落、控制权转移、阵营改变和 AI 接管仍是后续裁决。

## 用户故事

- 作为玩家，我的角色可能在战斗中变形、感染或丧尸化。某些形态应保留移动或攻击能力，但不能打开背包喝药、从箱子搬东西或更换武器。
- 作为内容作者，我需要在同一条变形/感染规则上声明能力变化和操作限制，而不是分别在 UI、物品、装备和箱子脚本里手写特殊判断。
- 作为未来联机主机权威裁决的准备，玩家输入、AI 命令和菜单操作都应回到同一套角色规则入口，由主机/单机正式系统裁决，而不是由客户端 UI 直接改背包或装备。

## 实现

- `EActionFlags` 新增 `ManageInventory` 和 `ChangeEquipment`。
- `CharacterAlterationRule.lockedActions` 继续作为唯一规则数据入口，规则资产可通过锁定这两个动作位表达背包/装备限制。
- `InventorySystem.TryEquip(...)` 和 `TryUnequip(...)` 会检查来源角色是否还能管理背包、目标 Hero 是否还能变更装备。
- `Hero.TryEquip(...)` / `TryUnequip(...)` 底层也检查 `ChangeEquipment`，防止后续直接调用 `Hero` 绕过系统层。
- `InventoryTransferRequest` 新增 `ActorActionLocked` 失败原因；带 actor 的转移请求会检查 `ManageInventory`。
- `Item.Use(...)` 在物品效果执行前检查来源角色是否还能管理背包，避免药水、卷轴、装备点击等绕过规则。
- `UIInventory` 和 `MenuFeedbackPrompts` 补充动作锁失败反馈。
- `Invoke-FoundationStaticGate.ps1` 新增 `InventoryActionLockMissingPatternCount`，防止这些入口回退。

## 存档与边界

没有新增存档字段。`activeAlterationRules` 仍保存激活规则引用，读档时由规则资产的 `lockedActions` 重建动作锁。

系统发奖、脚本加物品、掉落写入等没有 actor 的库存变化不被这一刀拦截，因为它们不是“角色主动管理背包”。商店、制作、负重、背包容量、尸体和双栏容器仍需要后续专项裁决。
