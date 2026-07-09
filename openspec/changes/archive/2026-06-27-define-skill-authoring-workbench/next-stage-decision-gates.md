# 下一阶段决策门禁

本文只记录 `define-skill-authoring-workbench` 在基础攻击最小闭包之后的最小待决问题。它不定义正式职业、技能树、正式技能内容或默认构筑模板。

## 当前已完成的安全边界

- 基础攻击当前可通过 `FireAbility1` 触发，命中判定仍由 `MeleeAttackAbilitySheet.hitWindow` 与 `MeleeAttackAbility` 承担。
- 基础攻击伤害当前通过 GAS-backed 正式规则入口结算：`GameplayEffectAsset.Executions -> FormalInstantDamageExecution -> CharacterBase.Damage(...)`。
- 当前基础攻击已经不再依赖 Cue 扣血；EX-GAS `GameplayCue` 只保留表现提示，不修改属性或玩法结果。
- `DatabaseRegistry / DatabaseEntryReference` 是当前稳定 ID 和数据库引用真相源。
- `CharacterAbilitySet / CharacterAbilitySourceKey / CharacterBase.Persistence` 是当前能力授予、撤回、来源追踪和存档恢复真相源。
- `GameRuntimeEvents / UIHUDAbilityMessage` 是当前最小运行时失败提示挂接点。
- 当前没有正式可视化判定框编辑器；普通 `AbilitySheet` Inspector 只是迁移期样例数据入口。
- 当前单一路径流程文档已补齐：`formal-skill-implementation-flow.md`。
- 当前 AIBridge 已恢复只读取证能力，已确认 Unity `isCompiling=false`。
- `ClickMoveTest` 已从内存脏状态重开回磁盘版本，当前 `isDirty=false`。
- 当前正式执行资产审计已有真实通过证据；`ClickMoveTest` / composite PlayMode smoke 也已真实补跑通过。
- Kybernetik Platformer Game Kit 的 melee hit boxes 文档已登记为判定框作者参考；进入正式判定框编辑器实现前，必须先补参考矩阵和差距闭环。
- 旧“工作台 / 准备链路 / 修复接线 / 测试角色保活器”已判定为错误方向，不再属于正式技能实现流程。

## 进入蓄力攻击 / 背刺前必须确认

### 1. 冷却和节奏

- 问题：蓄力攻击和背刺是否需要独立冷却，还是只跟武器执行节奏走？
- 影响：如果需要独立冷却，必须把对应 `AbilityAsset.Cooldown` 和标签组纳入 GAS 规则；如果只跟执行节奏走，仍由动作执行层控制，不新增正式冷却资源。

### 2. 背刺判定来源

- 问题：背刺判定只看攻击者与目标朝向夹角，还是还要纳入隐蔽、未被发现、武器类型或状态标签？
- 影响：只看朝向可继续放在动作命中闭包；若纳入状态标签或隐蔽条件，必须接入 GAS 标签或角色状态规则，不得在命中盒里写死。

### 3. 蓄力输入合同

- 问题：蓄力攻击是按住同一个攻击键释放，还是单独按键？
- 影响：同键蓄力会改变 `FireAbility1 / StopFireAbility` 的输入语义；单独按键会改变能力槽与测试入口。第一阶段不做技能栏 UI，但仍会影响运行时命令合同。

### 4. 蓄力数值来源

- 问题：蓄力倍率来自蓄力时长曲线、固定阶段，还是 GAS 属性/标签？
- 影响：曲线/阶段更适合放在执行数据里；属性/标签则必须成为 GAS 规则输入。

## 进入正式角色构筑前必须确认

### 1. 职业结构

- 问题：职业是固定主职业、可多职业，还是允许转职？
- 影响：决定角色构筑快照是单职业字段、多职业列表，还是带职业历史和转职规则的结构。

### 2. 技能树归属

- 问题：技能树按职业独占，还是允许跨职业共享？
- 影响：决定技能树资产是职业子资产、职业组引用，还是独立公共树。

### 3. 技能获取方式

- 问题：技能通过升级点、职业解锁、装备授予、剧情授予、状态授予中的哪些路径获得？
- 影响：决定正式来源类型、授予入口与撤回规则。

### 4. Respec

- 问题：角色构筑是否允许 respec；如果允许，是完全重置、部分重置，还是受消耗/地点限制？
- 影响：决定已学技能回退、来源账本撤回、存档迁移和编辑器校验策略。

### 5. 玩家炼金式法术配置 UI

- 问题：第一版玩家法术配置 UI 是槽位式、链式，还是需要自由节点图？
- 影响：决定作者面是否只做受限配方录入，还是要引入高级可视化编排界面。

## 回答前允许继续做的事

- 修复基础攻击链路的真实 bug，只要不扩大到蓄力、背刺或正式职业内容。
- 补充 `AbilitySheet -> AbilityExecutionAsset -> 通用运行时壳 -> GAS 规则 -> 表现反馈` 的单一路径文档和校验。
- 补充判定框作者工具参考矩阵，比较 Kybernetik Platformer、EX-GAS Timeline/TargetCatcher、TopDown 武器闭包和当前样例链路的差距。
- 补充或准备后续技能的正式规则执行入口，继续保持 Cue 只触发表现。
- 保留中性样例资产作为 smoke 证明，但不得再把样例维护步骤写成人类作者流程。

## 回答前禁止做的事

- 不实现正式职业资产模型、技能树资产结构、默认职业或默认流派。
- 不把蓄力攻击、背刺或复杂技能写成正式内容。
- 不新增技能栏 UI。
- 不为未确认问题新建第二套构筑、授予、冷却或技能树真相源。
- 不因为当前混合链路已经可跑，就默认扩大混合实现面积；混合必须继续证明比 EX-GAS 推荐闭包更适合。
- 不回退到 `FormalInstantDamageCue` 这类 Cue 扣血模式。
- 不把只读检查、命令行 smoke、普通 `AbilitySheet` Inspector 或定位资产菜单包装成正式技能编辑器。
- 不在参考矩阵闭合前实现新的判定框 UI、正式判定框资产模型或第二套命中盒真相。
